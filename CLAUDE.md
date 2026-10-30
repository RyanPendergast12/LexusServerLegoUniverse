# Instructions for Claude Code: install this LEGO Universe server

The owner of this repo wants to run a private **LEGO Universe** server
(Darkflame Universe game server + **Nexus Dashboard** account website +
MariaDB) on their own computer and home network. When they say something like
"look at my repo and install the server", follow this file top to bottom.
Everything runs in Docker via `docker-compose.yml`; the helper scripts
`lu.sh` (Linux/macOS/WSL) and `lu.ps1` (Windows) do the work.

## Ground rules

- **Never download, search for, or link to the LEGO Universe game client.** It is
  copyrighted and not in this repo. The user must already have it. If they don't,
  stop and tell them the server can't run without their own 1.10.64 client.
- Never commit `.env`, the `client/` contents, `server/`, `web/` or `backups/`
  (already in `.gitignore`).
- Ask before anything that needs admin/sudo, changes the firewall, installs
  software, or exposes ports to the internet. Explain why in one line.
- Don't edit `docker-compose.yml` to hard-code secrets; settings go in `.env`.

## Step 1 — Figure out the platform

Detect the OS. Pick the matching path:

| OS | Use | Docker |
|----|-----|--------|
| Windows 10/11 | `powershell -ExecutionPolicy Bypass -File .\lu.ps1 <cmd>` | Docker Desktop (WSL2 backend) |
| Linux | `./lu.sh <cmd>` | Docker Engine + compose plugin |
| macOS | `./lu.sh <cmd>` | Docker Desktop |
| WSL2 shell on Windows | prefer running `lu.ps1` from Windows PowerShell instead | Docker Desktop |

On Linux/macOS make the script executable first: `chmod +x lu.sh`.

## Step 2 — Docker

Run `lu.ps1 doctor` / `./lu.sh doctor`.

- Docker missing → follow `docs/INSTALL-DOCKER.md` for this OS. Ask the user
  before installing. On Windows, after installing Docker Desktop the user
  usually must reboot and start Docker Desktop once (accept the license); wait
  for "Engine running".
- Linux "permission denied" on the docker socket → `sudo usermod -aG docker $USER`,
  then the user must log out/in (or use `newgrp docker`).

## Step 3 — Locate the game client

Ask the user where their LEGO Universe client folder is (the folder containing
`legouniverse.exe`, `res/`, `locale/`). If they don't know, you may search
their drives for `legouniverse.exe` (e.g. on Windows:
`Get-ChildItem -Path C:\,D:\ -Filter legouniverse.exe -Recurse -ErrorAction SilentlyContinue -Depth 6`).

Then either set `CLIENT=<path>` when running install (below), or leave the
client where it is — **do not copy it into OneDrive or synced folders**.
If it's inside OneDrive, ask the user to move it first.

Optional: verify it with the SHA256 checksums in `docs/CLIENT.md` if they still
have the original archive.

## Step 4 — Decide who will play

Ask the user (one question): **only this PC, people on the home network, or
friends over the internet?**

- This PC only → `IP=localhost`
- Home network (default, recommended) → let the script auto-detect the LAN IP
- Internet → LAN install first, then follow `docs/NETWORKING.md` (router port
  forwarding, public IP / DDNS). Remind them the DLU project recommends small,
  trusted groups only.

## Step 5 — Install

Windows (PowerShell, in the repo folder):
```powershell
$env:CLIENT = "D:\Games\LEGO Universe"   # their client folder
# $env:IP = "localhost"                  # only if they chose "this PC only"
powershell -ExecutionPolicy Bypass -File .\lu.ps1 install
```
Linux/macOS:
```bash
CLIENT="/path/to/LEGO Universe" ./lu.sh install
# IP=localhost CLIENT=... ./lu.sh install   # this PC only
```

What install does: creates `.env` with random passwords, sets `CLIENT_PATH`
and `EXTERNAL_IP`, checks the client, pulls the images, starts everything,
waits until the server has converted the client database (first run can take
several minutes), and on Windows adds firewall rules if run as Administrator.

If the Windows install wasn't run as Administrator and other PCs need to
connect, have the user run `.\lu.ps1 firewall` in an **admin** PowerShell.

If anything fails, read `./lu.sh logs darkflameserver` (or `.\lu.ps1 logs darkflameserver`)
and use `docs/TROUBLESHOOTING.md`.

## Step 6 — Admin account

`create-account` is interactive (it asks username, password, GM level), so the
**user must type into it**. Tell them to run it themselves in their terminal:
```
.\lu.ps1 create-account      # Windows
./lu.sh create-account       # Linux/macOS
```
They should choose GM level **9** for their own admin account. Other players
can register on the Nexus Dashboard website instead.

Do **not** pipe answers into `create-account`: the password prompt uses
`getpass`, which drops input typed ahead of time, so piped input silently sets
the wrong password. If the GM level shown afterwards is wrong, run
`set-gm <name> 9`.

If install printed "Nexus Dashboard disabled", the client is packed (no
`res/brickdb.zip` / `res/brickprimitives`). The game still works; accounts
are made with `create-account` only. The dashboard comes back after the client
is unpacked and `COMPOSE_PROFILES=dashboard` is set in `.env`, then `start`.

## Step 7 — Point the client at the server

```
.\lu.ps1 boot-cfg            # edits <client>\boot.cfg, saves boot.cfg.original
./lu.sh boot-cfg
```
For a friend's PC, they edit their own `boot.cfg` (see `docs/CLIENT.md`) with
this server's IP.

Then the user launches `legouniverse.exe` (Linux/macOS: through Wine) and logs in.

## Step 8 — Report back

Tell the user, briefly:
- Server status (`status` command output)
- Dashboard URL: `http://<EXTERNAL_IP>:8000` — they log in there with the
  account from step 6; friends can register there.
- The IP friends should put in `boot.cfg`
- Daily commands: `start`, `stop`, `status`, `logs`, `backup`, `update`
- Containers restart automatically when Docker starts (`restart: unless-stopped`).
  On Windows, enable "Start Docker Desktop when you sign in" for it to come up after reboot.

## Reference

- `README.md` – human-readable overview
- `docs/CLIENT.md` – client checksums, boot.cfg
- `docs/NETWORKING.md` – LAN, port forwarding, ports list
- `docs/ADMIN.md` – GM levels, play keys, useful in-game commands, configs
- `docs/TROUBLESHOOTING.md` – common errors and fixes
- Upstream: https://github.com/DarkflameUniverse/DarkflameServer and
  https://github.com/DarkflameUniverse/NexusDashboard
