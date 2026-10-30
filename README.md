# Lexus LEGO Universe Server

Everything needed to run a private **LEGO Universe** server on your own PC
and home network:

- **Darkflame Universe (DLU)** – the open-source game server emulator
- **Nexus Dashboard** – website for creating accounts and moderating
- **MariaDB** – the database

It all runs in Docker, so setup is the same on Windows, Linux and macOS.

> **You need your own LEGO Universe 1.10.64 game client.** This repo doesn't
> include it and never will. See [`docs/CLIENT.md`](docs/CLIENT.md).

## Easiest way: let Claude Code do it

On the PC that will host the server:

1. Clone this repo: `git clone https://github.com/ryanpendergast12/lexusserverlegouniverse`
2. Open Claude Code in that folder and say:
   **"Read CLAUDE.md and install the LEGO Universe server on this computer."**

Claude will check Docker, find your client, ask who will be playing (just you,
your home network, or friends online), install everything, and walk you
through making your admin account. The instructions it follows are in
[`CLAUDE.md`](CLAUDE.md).

## Doing it yourself

**Windows** (PowerShell in the repo folder):
```powershell
# 1. Install Docker Desktop and start it (docs/INSTALL-DOCKER.md)
$env:CLIENT = "D:\Games\LEGO Universe"    # your client folder
powershell -ExecutionPolicy Bypass -File .\lu.ps1 install
.\lu.ps1 create-account                   # pick GM level 9 for yourself
.\lu.ps1 boot-cfg                         # point your client at the server
```
Run PowerShell **as Administrator** for the install if other PCs on your
network will play (it adds firewall rules), or run `.\lu.ps1 firewall` later as admin.

**Linux / macOS**:
```bash
chmod +x lu.sh
CLIENT="/path/to/LEGO Universe" ./lu.sh install
./lu.sh create-account
./lu.sh boot-cfg
```

Then start `legouniverse.exe` (via Wine on Linux/macOS) and log in.

## After install

| What | Where |
|------|-------|
| Game server | `<your IP>` ports UDP 1001, 2005, 3000-3300 |
| Account website (Nexus Dashboard) | `http://<your IP>:8000` |
| Settings | `.env` (created by install) |
| Server configs (`*.ini`) | `server/config/` |
| Logs | `server/logs/`, `web/logs/`, or `lu logs` |
| Backups | `backups/` |

### Daily commands

| Windows | Linux/macOS | Does |
|---------|-------------|------|
| `.\lu.ps1 start` | `./lu.sh start` | Start the server |
| `.\lu.ps1 stop` | `./lu.sh stop` | Stop it |
| `.\lu.ps1 status` | `./lu.sh status` | Is it running? What IP? |
| `.\lu.ps1 logs` | `./lu.sh logs` | Watch logs |
| `.\lu.ps1 accounts` | `./lu.sh accounts` | List accounts |
| `.\lu.ps1 set-gm name 9` | `./lu.sh set-gm name 9` | Make someone admin |
| `.\lu.ps1 backup` | `./lu.sh backup` | Back up database + configs |
| `.\lu.ps1 update` | `./lu.sh update` | Backup, then update to newest server |
| `.\lu.ps1 set-ip` | `./lu.sh set-ip` | Your PC's IP changed? Fix it |

## Letting friends play

- **Same Wi-Fi/home network:** they set `AUTHSERVERIP=0:<your LAN IP>,` in their
  client's `boot.cfg`, register at `http://<your LAN IP>:8000`, and play.
- **Over the internet:** see [`docs/NETWORKING.md`](docs/NETWORKING.md).

## Docs

- [`docs/INSTALL-DOCKER.md`](docs/INSTALL-DOCKER.md) – installing Docker
- [`docs/CLIENT.md`](docs/CLIENT.md) – the game client and `boot.cfg`
- [`docs/NETWORKING.md`](docs/NETWORKING.md) – LAN, port forwarding, firewall
- [`docs/ADMIN.md`](docs/ADMIN.md) – GM levels, play keys, config files, in-game commands
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) – when things go wrong

## Credits & license notes

The server software is made by the [Darkflame Universe](https://github.com/DarkflameUniverse)
team ([DarkflameServer](https://github.com/DarkflameUniverse/DarkflameServer), AGPLv3;
[NexusDashboard](https://github.com/DarkflameUniverse/NexusDashboard)). This repo
only contains setup scripts and docs and pulls their official Docker images.
LEGO® and LEGO Universe are trademarks of the LEGO Group; this project is not
affiliated with or endorsed by them. DLU recommends hosting for small groups of
friends only, not public servers.
