# LEGO Universe server helper (Windows, Docker Desktop).
# Usage:  powershell -ExecutionPolicy Bypass -File .\lu.ps1 <command> [args]
#         .\lu.ps1 help
param(
    [Parameter(Position = 0)] [string] $Command = "help",
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)] [string[]] $Rest
)
# Native tools (docker) write progress to stderr; with "Stop" Windows PowerShell 5.1
# would treat that as fatal. Exit codes are checked explicitly instead.
$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot
$Root = $PSScriptRoot

function Ok($m)   { Write-Host $m -ForegroundColor Green }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }
function Bad($m)  { Write-Host $m -ForegroundColor Red }
function Die($m)  { Bad "ERROR: $m"; exit 1 }

function Dc { & docker compose @args; if ($LASTEXITCODE -ne 0) { Die "docker compose $($args -join ' ') failed" } }

function RandStr {
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

function EnvGet($key) {
    if (-not (Test-Path .env)) { return "" }
    $line = Get-Content .env | Where-Object { $_ -match "^$key=" } | Select-Object -Last 1
    if ($line) { return $line.Substring($key.Length + 1) } else { return "" }
}

function EnvSet($key, $val) {
    $lines = @(Get-Content .env)
    $found = $false
    $out = foreach ($l in $lines) { if ($l -match "^$key=") { $found = $true; "$key=$val" } else { $l } }
    if (-not $found) { $out += "$key=$val" }
    # UTF-8 without BOM so docker compose reads it cleanly
    [System.IO.File]::WriteAllLines((Join-Path $Root ".env"), [string[]]$out, (New-Object System.Text.UTF8Encoding $false))
}

function LanIp {
    $cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq "Up" } | Select-Object -First 1
    if ($cfg) { return $cfg.IPv4Address.IPAddress } else { return "localhost" }
}

function ClientPath {
    $p = EnvGet "CLIENT_PATH"; if (-not $p) { $p = "./client" }
    if ([System.IO.Path]::IsPathRooted($p)) { return $p } else { return (Join-Path $Root $p) }
}

function DbArgs {
    $u = EnvGet "MARIADB_USER"; if (-not $u) { $u = "darkflame" }
    $d = EnvGet "MARIADB_DATABASE"; if (-not $d) { $d = "darkflame" }
    return @("-u$u", "-p$(EnvGet 'MARIADB_PASSWORD')", $d)
}

function DbExec($sql) { $a = DbArgs; & docker compose exec -T darkflamedb mariadb @a -e $sql }

function Prereqs {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Die "Docker is not installed. Install Docker Desktop: see docs\INSTALL-DOCKER.md" }
    & docker compose version *> $null; if ($LASTEXITCODE -ne 0) { Die "'docker compose' not available. Update Docker Desktop." }
    & docker info *> $null; if ($LASTEXITCODE -ne 0) { Die "Docker Desktop is not running. Start it, wait for 'Engine running', then retry." }
}

function DashboardOk { $c = ClientPath; (Test-Path "$c\res\brickdb.zip") -and (Test-Path "$c\res\brickprimitives") }

function CheckClient {
    $c = ClientPath
    Write-Host "== Checking client at: $c"
    if (-not (Test-Path $c)) { Bad "  Folder does not exist. Put the client there or set CLIENT_PATH in .env"; return $false }
    if (Test-Path "$c\legouniverse.exe") { Ok "  legouniverse.exe found" } else { Warn "  legouniverse.exe not found (is this the client root folder?)" }
    if (-not (Test-Path "$c\res")) { Bad "  res\ folder missing - not a valid client folder"; return $false }
    if (Test-Path "$c\locale") { Ok "  locale\ found" } else { Warn "  locale\ missing" }
    if (Test-Path "$c\res\cdclient.fdb") { Ok "  Unpacked client (res\cdclient.fdb)" }
    elseif ((Test-Path "$c\res\pack") -or (Get-ChildItem "$c\res" -Filter *.pk -ErrorAction SilentlyContinue)) { Warn "  Packed client - the game server works" }
    if (DashboardOk) { Ok "  res\brickdb.zip + res\brickprimitives found - Nexus Dashboard can run" }
    else { Warn "  res\brickdb.zip or res\brickprimitives missing - Nexus Dashboard can't run (needs an unpacked client); use create-account instead" }
    if ($c -match "OneDrive") { Bad "  Client is inside OneDrive - move it out, DLU does not support this"; return $false }
    return $true
}

function Doctor {
    Prereqs; Ok "Docker OK: $(docker --version)"
    if (Test-Path .env) { Ok ".env present" } else { Warn ".env missing (run .\lu.ps1 install)" }
    if (CheckClient) { Ok "All good." } else { exit 1 }
}

function WaitReady {
    Write-Host "== Waiting for first-time setup (converting the client DB can take a few minutes)"
    for ($i = 0; $i -lt 120; $i++) {
        $logs = (& docker compose logs --tail 200 darkflameserver 2>$null) -join "`n"
        if ((Test-Path "server\res\CDServer.sqlite") -and ($logs -match "Starting Auth server|Ready zone")) { return }
        $exited = & docker compose ps --status exited --services 2>$null
        $cid = & docker compose ps -aq darkflameserver 2>$null
        $restarts = 0; if ($cid) { $restarts = [int](& docker inspect -f '{{.RestartCount}}' $cid 2>$null) }
        if (($exited -match "darkflameserver") -or ($restarts -ge 3)) { Bad "darkflameserver keeps crashing (restarted $restarts times). Last logs:"; & docker compose logs --tail 60 darkflameserver; Die "See docs\TROUBLESHOOTING.md" }
        Start-Sleep -Seconds 5
    }
    Warn "Timed out waiting; check: .\lu.ps1 logs darkflameserver"
}

function OpenFirewall {
    # Needs admin. Lets other PCs on your network reach the server.
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { Warn "Not running as Administrator - skipping firewall rules. Re-run '.\lu.ps1 firewall' in an admin PowerShell to let other PCs connect."; return }
    $port = EnvGet "DASHBOARD_PORT"; if (-not $port) { $port = "8000" }
    Get-NetFirewallRule -DisplayName "LEGO Universe Server*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName "LEGO Universe Server (UDP)" -Direction Inbound -Protocol UDP -LocalPort 1001,2005,"3000-3300" -Action Allow -Profile Private,Domain | Out-Null
    New-NetFirewallRule -DisplayName "LEGO Universe Server (Dashboard)" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -Profile Private,Domain | Out-Null
    Ok "Firewall rules added (Private/Domain networks). Make sure your Wi-Fi/Ethernet is set to a Private network."
}

function PullImages {
    for ($i = 1; $i -le 3; $i++) {
        & docker compose pull
        if ($LASTEXITCODE -eq 0) { return }
        Warn "Pull failed (attempt $i/3) - retrying in $($i * 10)s"; Start-Sleep -Seconds ($i * 10)
    }
    Warn "Could not pull images; continuing with any already-downloaded images."
}

function Install {
    Prereqs
    if (-not (Test-Path .env)) {
        Write-Host "== Creating .env with random secrets"
        Copy-Item .env.example .env
        EnvSet "MARIADB_PASSWORD" (RandStr)
        EnvSet "ACCOUNT_MANAGER_SECRET" (RandStr)
        EnvSet "MASTER_PASSWORD" (RandStr)
    } else { Warn "== .env already exists - keeping it" }

    if ($env:CLIENT) { EnvSet "CLIENT_PATH" ($env:CLIENT -replace '\\', '/') }
    if ($env:IP) { EnvSet "EXTERNAL_IP" $env:IP }
    elseif ((EnvGet "EXTERNAL_IP") -in @("", "localhost")) {
        $ip = LanIp; EnvSet "EXTERNAL_IP" $ip; Ok "== EXTERNAL_IP set to your LAN address: $ip (change in .env if needed)"
    }

    if (DashboardOk) { EnvSet "COMPOSE_PROFILES" "dashboard" }
    else { EnvSet "COMPOSE_PROFILES" ""; Warn "== Nexus Dashboard disabled (client is not unpacked). Game server only." }

    foreach ($d in "server\config","server\res","server\dump","server\logs","web\cache","web\logs","backups") { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    if (-not (CheckClient)) { Die "Client check failed. Fix CLIENT_PATH in .env and run .\lu.ps1 install again." }

    Write-Host "== Pulling images"; PullImages
    Write-Host "== Starting containers"; Dc up -d
    WaitReady
    OpenFirewall
    Ok "== Server is up."
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1) .\lu.ps1 create-account     # make your admin account (choose GM level 9)"
    Write-Host "  2) .\lu.ps1 boot-cfg           # point your client's boot.cfg at this server"
    if (DashboardOk) { Write-Host "  3) Dashboard: http://$(EnvGet 'EXTERNAL_IP'):$(EnvGet 'DASHBOARD_PORT')" }
    Write-Host "  4) Friends on other networks: see docs\NETWORKING.md"
}

function SetGm($name, $level) {
    if ($name -notmatch '^[A-Za-z0-9_.-]{1,64}$') { Die "Invalid account name" }
    if ($level -notmatch '^[0-9]$') { Die "GM level must be 0-9" }
    DbExec "UPDATE accounts SET gm_level=$level WHERE name='$name'; SELECT id,name,gm_level FROM accounts WHERE name='$name';"
}

function Backup {
    New-Item -ItemType Directory -Force -Path backups | Out-Null
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $a = DbArgs
    $f = "backups\db-$ts.sql"
    # cmd redirection keeps the dump byte-exact (PowerShell 5 '>' would re-encode it)
    cmd /c "docker compose exec -T darkflamedb mariadb-dump $($a[0]) $($a[1]) --single-transaction $($a[2]) > `"$f`""
    if ($LASTEXITCODE -ne 0) { Die "Backup failed" }
    Compress-Archive -Force -Path server\config, .env -DestinationPath "backups\config-$ts.zip"
    Ok "Backup written: $f and backups\config-$ts.zip"
}

function Restore($file) {
    if (-not $file -or -not (Test-Path $file)) { Die "Usage: .\lu.ps1 restore backups\db-XXXX.sql" }
    Warn "This REPLACES the current database with $file."
    if ((Read-Host "Type yes to continue") -ne "yes") { Die "Aborted" }
    & docker compose stop darkflameserver darkflameweb 2>$null
    $a = DbArgs
    cmd /c "docker compose exec -T darkflamedb mariadb $($a[0]) $($a[1]) $($a[2]) < `"$file`""
    Dc up -d
    Ok "Restored."
}

function BootCfg($client, $ip) {
    if (-not $client) { $client = ClientPath }
    if (-not $ip) { $ip = EnvGet "EXTERNAL_IP" }
    $f = Join-Path $client "boot.cfg"
    if (-not (Test-Path $f)) { Die "No boot.cfg at $f" }
    if (-not (Test-Path "$f.original")) { Copy-Item $f "$f.original" }
    $text = [System.IO.File]::ReadAllText($f)
    $text = [regex]::Replace($text, 'AUTHSERVERIP=0:[^,]*,', "AUTHSERVERIP=0:$ip,")
    $text = [regex]::Replace($text, 'UGCUSE3DSERVICES=7:[0-9]+', 'UGCUSE3DSERVICES=7:0')
    if ($text -notmatch "AUTHSERVERIP=0:$([regex]::Escape($ip)),") { $text += "`r`nAUTHSERVERIP=0:$ip," }
    [System.IO.File]::WriteAllText($f, $text)
    Ok "boot.cfg now points at $ip (original saved as boot.cfg.original)"
    Select-String -Path $f -Pattern "AUTHSERVERIP|UGCUSE3DSERVICES" | ForEach-Object { $_.Line }
}

function Status {
    & docker compose ps
    Write-Host ""
    Write-Host "EXTERNAL_IP=$(EnvGet 'EXTERNAL_IP')   Dashboard: http://$(EnvGet 'EXTERNAL_IP'):$(EnvGet 'DASHBOARD_PORT')"
}

function Usage {
@"
LEGO Universe server helper (Windows)

  .\lu.ps1 install               First-time setup: .env, checks, pull, start, firewall
                                 (optional: `$env:CLIENT='D:\LU'; `$env:IP='1.2.3.4'; .\lu.ps1 install)
  .\lu.ps1 doctor                Check Docker + client
  .\lu.ps1 start|stop|restart    Control the server
  .\lu.ps1 status                Show containers and connection info
  .\lu.ps1 logs [service]        Follow logs (darkflameserver, darkflameweb, darkflamedb)
  .\lu.ps1 create-account        Create a login (interactive; GM 9 = admin)
  .\lu.ps1 accounts              List accounts
  .\lu.ps1 set-gm <name> <0-9>   Change an account's GM level
  .\lu.ps1 boot-cfg [client] [ip]  Point a client's boot.cfg at this server
  .\lu.ps1 set-ip [ip]           Change EXTERNAL_IP (default: detect LAN IP) and restart
  .\lu.ps1 firewall              Add Windows Firewall rules (run as Administrator)
  .\lu.ps1 backup                Dump database + config into backups\
  .\lu.ps1 restore <file.sql>    Restore a database dump
  .\lu.ps1 update                Backup, pull newest images, restart
  .\lu.ps1 uninstall             Remove containers and all server data
"@ | Write-Host
}

switch ($Command) {
    "install"        { Install }
    "doctor"         { Doctor }
    "check-client"   { if (-not (CheckClient)) { exit 1 } }
    "start"          { Dc up -d; Status }
    "stop"           { Dc stop }
    "restart"        { Dc restart }
    "status"         { Status }
    "logs"           { & docker compose logs -f --tail 200 @Rest }
    "create-account" { Write-Host "You'll be asked for username, password and GM level (9 = full admin)."; & docker compose exec -it darkflameserver /app/MasterServer -a; Write-Host ""; DbExec "SELECT id,name,gm_level FROM accounts ORDER BY id;"; Write-Host "If a GM level isn't what you picked, fix it with: .\lu.ps1 set-gm <name> 9" }
    "accounts"       { DbExec "SELECT id,name,gm_level,banned,locked,created_at FROM accounts ORDER BY id;" }
    "set-gm"         { if ($Rest.Count -ne 2) { Die "Usage: .\lu.ps1 set-gm <name> <0-9>" }; SetGm $Rest[0] $Rest[1] }
    "boot-cfg"       { BootCfg ($Rest | Select-Object -Index 0) ($Rest | Select-Object -Index 1) }
    "set-ip"         { $ip = if ($Rest) { $Rest[0] } else { LanIp }; EnvSet "EXTERNAL_IP" $ip; Dc up -d; Ok "EXTERNAL_IP=$ip - restarted. Re-run boot-cfg on clients if the IP changed." }
    "lan-ip"         { LanIp }
    "firewall"       { OpenFirewall }
    "backup"         { Backup }
    "restore"        { Restore ($Rest | Select-Object -Index 0) }
    "update"         { Backup; PullImages; Dc up -d; Ok "Updated to latest images." }
    "uninstall"      {
        Warn "This stops the server and DELETES the database and all server data (client files untouched)."
        if ((Read-Host "Type delete to continue") -ne "delete") { Die "Aborted" }
        Dc down -v; Remove-Item -Recurse -Force server, web -ErrorAction SilentlyContinue; Ok "Removed. .env and backups\ kept."
    }
    default          { Usage }
}
