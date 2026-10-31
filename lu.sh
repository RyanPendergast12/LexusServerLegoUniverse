#!/usr/bin/env bash
# LEGO Universe server helper (Linux / macOS / WSL2).
# Usage: ./lu.sh <command> [args]    — run ./lu.sh help for the list.
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
die()   { red "ERROR: $*"; exit 1; }

dc() { docker compose "$@"; }

randstr() {
    if command -v openssl >/dev/null 2>&1; then openssl rand -hex 24
    else LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 48; fi
}

env_get() { # env_get KEY -> value from .env (empty if unset)
    [ -f .env ] || return 0
    grep -E "^$1=" .env | tail -n1 | cut -d= -f2- || true
}

env_set() { # env_set KEY VALUE -> writes/replaces KEY in .env
    local key="$1" val="$2" tmp
    tmp="$(mktemp)"
    if grep -qE "^$key=" .env; then
        awk -v k="$key" -v v="$val" 'BEGIN{FS=OFS="="} $1==k{print k"="v; next} {print}' .env >"$tmp"
    else
        cat .env >"$tmp"; echo "$key=$val" >>"$tmp"
    fi
    cat "$tmp" >.env; rm -f "$tmp"
}

lan_ip() {
    local ip=""
    if [ "$(uname)" = "Darwin" ]; then
        ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL2: ask Windows for its LAN address (Docker Desktop publishes ports on the Windows host)
        ip="$(powershell.exe -NoProfile -Command \
            "(Get-NetIPConfiguration | Where-Object { \$_.IPv4DefaultGateway -ne \$null } | Select-Object -First 1).IPv4Address.IPAddress" \
            2>/dev/null | tr -d '\r' || true)"
    else
        ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)"
        [ -n "$ip" ] || ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    fi
    echo "${ip:-localhost}"
}

# Packed clients are laid out as <CLIENT_PATH>/client/{legouniverse.exe,res,...}
# plus <CLIENT_PATH>/versions/. game_dir is the folder holding legouniverse.exe.
game_dir() {
    local c; c="$(client_path)"
    if [ -d "$c/client" ] && [ -d "$c/versions" ]; then echo "$c/client"; else echo "$c"; fi
}

client_path() {
    local p; p="$(env_get CLIENT_PATH)"; p="${p:-./client}"
    case "$p" in /*) echo "$p" ;; *) echo "$ROOT/${p#./}" ;; esac
}

db_exec() { # db_exec "SQL"
    local u p d
    u="$(env_get MARIADB_USER)"; u="${u:-darkflame}"
    p="$(env_get MARIADB_PASSWORD)"
    d="$(env_get MARIADB_DATABASE)"; d="${d:-darkflame}"
    dc exec -T darkflamedb mariadb -u"$u" -p"$p" "$d" -e "$1"
}

valid_name() { [[ "$1" =~ ^[A-Za-z0-9_.-]{1,64}$ ]] || die "Invalid account name '$1' (letters, numbers, _ . - only)"; }

# ---------------------------------------------------------------- commands

cmd_doctor() {
    local ok=1
    echo "== Checking prerequisites"
    if command -v docker >/dev/null 2>&1; then green "  docker: $(docker --version)"; else red "  docker: NOT INSTALLED"; ok=0; fi
    if docker compose version >/dev/null 2>&1; then green "  docker compose: $(docker compose version --short)"; else red "  docker compose plugin: NOT AVAILABLE"; ok=0; fi
    if docker info >/dev/null 2>&1; then green "  docker daemon: running"; else red "  docker daemon: NOT RUNNING (start Docker Desktop / 'sudo systemctl start docker')"; ok=0; fi
    if [ -f .env ]; then green "  .env: present"; else yellow "  .env: missing (run ./lu.sh install)"; fi
    cmd_check_client || ok=0
    [ $ok = 1 ] && green "All good." || { red "Fix the items above, then re-run."; return 1; }
}

dashboard_ok() { local c; c="$(game_dir)"; [ -f "$c/res/brickdb.zip" ] && [ -d "$c/res/brickprimitives" ]; }

cmd_check_client() {
    local c; c="$(client_path)"
    echo "== Checking client at: $c"
    [ -d "$c" ] || { red "  Folder does not exist. Put the client there or set CLIENT_PATH in .env"; return 1; }
    [ -d "$c/versions" ] && green "  Packed layout: client/ + versions/ (CLIENT_PATH is the parent folder - correct)"
    if [ ! -d "$c/versions" ] && [ -d "$c/res/pack" ] && [ -d "$c/../versions" ]; then
        red "  Packed client: set CLIENT_PATH to the PARENT folder ($(cd "$c/.." && pwd)), which holds versions/"; return 1
    fi
    c="$(game_dir)"
    [ -f "$c/legouniverse.exe" ] && green "  legouniverse.exe found" || yellow "  legouniverse.exe not found (is this the client root folder?)"
    [ -d "$c/res" ] || { red "  res/ folder missing — this is not a valid client folder"; return 1; }
    [ -d "$c/locale" ] && green "  locale/ found" || yellow "  locale/ missing"
    if [ -f "$c/res/cdclient.fdb" ]; then green "  Unpacked client (res/cdclient.fdb)"
    elif [ -d "$c/res/pack" ] || ls "$c"/res/*.pk >/dev/null 2>&1; then yellow "  Packed client — the game server works"
    else yellow "  Could not tell if packed or unpacked — server will report on start"; fi
    if dashboard_ok; then green "  res/brickdb.zip + res/brickprimitives found — Nexus Dashboard can run"
    else yellow "  res/brickdb.zip or res/brickprimitives missing — Nexus Dashboard can't run (needs an unpacked client); use create-account instead"; fi
    case "$c" in *OneDrive*) red "  Client is inside OneDrive — move it out, DLU does not support this"; return 1 ;; esac
    return 0
}

cmd_install() {
    cmd_doctor_prereqs_only
    if [ ! -f .env ]; then
        echo "== Creating .env with random secrets"
        cp .env.example .env
        env_set MARIADB_PASSWORD "$(randstr)"
        env_set ACCOUNT_MANAGER_SECRET "$(randstr)"
        env_set MASTER_PASSWORD "$(randstr)"
    else
        yellow "== .env already exists — keeping it"
    fi

    if [ -n "${CLIENT:-}" ]; then env_set CLIENT_PATH "$CLIENT"; fi
    if [ -n "${IP:-}" ]; then
        env_set EXTERNAL_IP "$IP"
    elif [ "$(env_get EXTERNAL_IP)" = "localhost" ] || [ -z "$(env_get EXTERNAL_IP)" ]; then
        local ip; ip="$(lan_ip)"
        env_set EXTERNAL_IP "$ip"
        green "== EXTERNAL_IP set to your LAN address: $ip (change in .env if needed)"
    fi

    if dashboard_ok; then env_set COMPOSE_PROFILES dashboard
    else env_set COMPOSE_PROFILES ""; yellow "== Nexus Dashboard disabled (client is not unpacked). Game server only."; fi

    mkdir -p server/config server/res server/dump server/logs web/cache web/logs backups
    cmd_check_client || die "Client check failed. Fix CLIENT_PATH in .env and run ./lu.sh install again."

    echo "== Pulling images"
    pull_images
    echo "== Starting containers"
    dc up -d
    cmd_wait_ready
    green "== Server is up."
    echo
    echo "Next steps:"
    echo "  1) ./lu.sh create-account          # make your admin account (choose GM level 9)"
    echo "  2) ./lu.sh boot-cfg                # point your client's boot.cfg at this server"
    dashboard_ok && echo "  3) Dashboard: http://$(env_get EXTERNAL_IP):$(env_get DASHBOARD_PORT)"
    echo "  4) Friends on other networks: see docs/NETWORKING.md"
}

pull_images() {
    local i
    for i in 1 2 3; do
        dc pull && return 0
        yellow "Pull failed (attempt $i/3) — retrying in $((i * 10))s"; sleep $((i * 10))
    done
    yellow "Could not pull images; continuing with any already-downloaded images."
}

cmd_doctor_prereqs_only() {
    command -v docker >/dev/null 2>&1 || die "Docker is not installed. See docs/INSTALL-DOCKER.md"
    docker compose version >/dev/null 2>&1 || die "'docker compose' plugin not available. See docs/INSTALL-DOCKER.md"
    docker info >/dev/null 2>&1 || die "Docker daemon not running (start Docker Desktop, or: sudo systemctl start docker). If it's a permission error: sudo usermod -aG docker \$USER, then log out/in."
}

cmd_wait_ready() {
    echo "== Waiting for the server to finish first-time setup (converting client DB can take a few minutes)"
    local i
    for i in $(seq 1 120); do
        if [ -f server/res/CDServer.sqlite ] && dc logs --tail 200 darkflameserver 2>/dev/null | grep -qE "Starting Auth server|Ready zone"; then
            return 0
        fi
        local cid restarts
        cid="$(dc ps -aq darkflameserver 2>/dev/null || true)"
        restarts="$( [ -n "$cid" ] && docker inspect -f '{{.RestartCount}}' "$cid" 2>/dev/null || echo 0)"
        if [ "${restarts:-0}" -ge 3 ] || dc ps --status exited --services 2>/dev/null | grep -q darkflameserver; then
            red "darkflameserver keeps crashing (restarted $restarts times). Last logs:"; dc logs --tail 60 darkflameserver; die "See docs/TROUBLESHOOTING.md"
        fi
        sleep 5
    done
    yellow "Timed out waiting; check: ./lu.sh logs darkflameserver"
}

cmd_create_account() {
    echo "Creating an account. You'll be asked for username, password and GM level (9 = full admin)."
    dc exec -it darkflameserver /app/MasterServer -a || true
    echo; cmd_accounts
    echo "If a GM level isn't what you picked, fix it with: ./lu.sh set-gm <name> 9"
}

cmd_set_gm() {
    [ $# -eq 2 ] || die "Usage: ./lu.sh set-gm <account-name> <0-9>"
    valid_name "$1"; [[ "$2" =~ ^[0-9]$ ]] || die "GM level must be 0-9"
    db_exec "UPDATE accounts SET gm_level=$2 WHERE name='$1'; SELECT id,name,gm_level FROM accounts WHERE name='$1';"
}

cmd_accounts() { db_exec "SELECT id,name,gm_level,banned,locked,created_at FROM accounts ORDER BY id;"; }

cmd_backup() {
    mkdir -p backups
    local ts u p d f
    ts="$(date +%Y%m%d-%H%M%S)"
    u="$(env_get MARIADB_USER)"; u="${u:-darkflame}"; p="$(env_get MARIADB_PASSWORD)"; d="$(env_get MARIADB_DATABASE)"; d="${d:-darkflame}"
    f="backups/db-$ts.sql"
    dc exec -T darkflamedb mariadb-dump -u"$u" -p"$p" --single-transaction "$d" >"$f"
    tar -czf "backups/config-$ts.tar.gz" server/config .env
    green "Backup written: $f and backups/config-$ts.tar.gz"
}

cmd_restore() {
    [ $# -eq 1 ] && [ -f "$1" ] || die "Usage: ./lu.sh restore backups/db-XXXX.sql"
    local u p d
    u="$(env_get MARIADB_USER)"; u="${u:-darkflame}"; p="$(env_get MARIADB_PASSWORD)"; d="$(env_get MARIADB_DATABASE)"; d="${d:-darkflame}"
    yellow "This REPLACES the current database with $1."
    read -r -p "Type yes to continue: " a; [ "$a" = "yes" ] || die "Aborted"
    dc stop darkflameserver darkflameweb 2>/dev/null || dc stop darkflameserver
    dc exec -T darkflamedb mariadb -u"$u" -p"$p" "$d" <"$1"
    dc up -d
    green "Restored."
}

cmd_update() {
    cmd_backup
    pull_images
    dc up -d
    green "Updated to latest images."
}

cmd_boot_cfg() {
    # ./lu.sh boot-cfg [path-to-client] [ip]
    local c="${1:-$(game_dir)}" ip="${2:-$(env_get EXTERNAL_IP)}" f
    f="$c/boot.cfg"
    [ -f "$f" ] || die "No boot.cfg at $f"
    [ -f "$f.original" ] || cp "$f" "$f.original"
    sed -i.bak -E \
        -e "s#AUTHSERVERIP=0:[^,]*,#AUTHSERVERIP=0:${ip},#" \
        -e "s#UGCUSE3DSERVICES=7:[0-9]+#UGCUSE3DSERVICES=7:0#" \
        "$f"
    rm -f "$f.bak"
    grep -q "AUTHSERVERIP=0:${ip}," "$f" || echo "AUTHSERVERIP=0:${ip}," >>"$f"
    green "boot.cfg now points at $ip (original saved as boot.cfg.original):"
    grep -E "AUTHSERVERIP|UGCUSE3DSERVICES" "$f" || true
}

cmd_set_ip() {
    local ip="${1:-$(lan_ip)}"
    env_set EXTERNAL_IP "$ip"
    dc up -d
    green "EXTERNAL_IP=$ip — server restarted. Re-run ./lu.sh boot-cfg on each client if the IP changed."
}

cmd_status() {
    dc ps
    echo
    if [[ "$(env_get COMPOSE_PROFILES)" == *dashboard* ]]; then
        echo "EXTERNAL_IP=$(env_get EXTERNAL_IP)   Dashboard: http://$(env_get EXTERNAL_IP):$(env_get DASHBOARD_PORT)"
    else
        echo "EXTERNAL_IP=$(env_get EXTERNAL_IP)   Dashboard: off (packed client) - use create-account"
    fi
}

cmd_uninstall() {
    yellow "This stops the server and DELETES the database and all server data (client files are untouched)."
    read -r -p "Type delete to continue: " a; [ "$a" = "delete" ] || die "Aborted"
    dc down -v
    rm -rf server web
    green "Removed. .env and backups/ were kept."
}

usage() {
    cat <<EOF
LEGO Universe server helper

  ./lu.sh install              First-time setup: .env, checks, pull, start
                               (optional: CLIENT=/path/to/client IP=1.2.3.4 ./lu.sh install)
  ./lu.sh doctor               Check Docker + client
  ./lu.sh start|stop|restart   Control the server
  ./lu.sh status               Show containers and connection info
  ./lu.sh logs [service]       Follow logs (darkflameserver, darkflameweb, darkflamedb)
  ./lu.sh create-account       Create a login (interactive; GM 9 = admin)
  ./lu.sh accounts             List accounts
  ./lu.sh set-gm <name> <0-9>  Change an account's GM level
  ./lu.sh boot-cfg [client] [ip]  Point a client's boot.cfg at this server
  ./lu.sh set-ip [ip]          Change EXTERNAL_IP (default: detect LAN IP) and restart
  ./lu.sh backup               Dump database + config into backups/
  ./lu.sh restore <file.sql>   Restore a database dump
  ./lu.sh update               Backup, pull newest images, restart
  ./lu.sh uninstall            Remove containers and all server data
EOF
}

case "${1:-help}" in
    install)        shift; cmd_install "$@" ;;
    doctor)         cmd_doctor ;;
    check-client)   cmd_check_client ;;
    start)          dc up -d; cmd_status ;;
    stop)           dc stop ;;
    restart)        dc restart ;;
    status)         cmd_status ;;
    logs)           shift; dc logs -f --tail 200 "$@" ;;
    create-account) cmd_create_account ;;
    accounts)       cmd_accounts ;;
    set-gm)         shift; cmd_set_gm "$@" ;;
    boot-cfg)       shift; cmd_boot_cfg "$@" ;;
    set-ip)         shift; cmd_set_ip "$@" ;;
    lan-ip)         lan_ip ;;
    backup)         cmd_backup ;;
    restore)        shift; cmd_restore "$@" ;;
    update)         cmd_update ;;
    uninstall)      cmd_uninstall ;;
    help|-h|--help) usage ;;
    *)              usage; exit 1 ;;
esac
