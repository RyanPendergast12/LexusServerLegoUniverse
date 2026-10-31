# Troubleshooting

Start with `lu status` and `lu logs darkflameserver` (`lu` = `.\lu.ps1` on
Windows, `./lu.sh` elsewhere).

### `docker: command not found` / "Docker Desktop is not running"
Install or start Docker: [`INSTALL-DOCKER.md`](INSTALL-DOCKER.md). On Windows
wait for "Engine running" in Docker Desktop.

### Linux: `permission denied ... docker.sock`
`sudo usermod -aG docker $USER`, then log out and back in.

### `.\lu.ps1 cannot be loaded because running scripts is disabled`
Use `powershell -ExecutionPolicy Bypass -File .\lu.ps1 <command>`, or once:
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

### Server keeps restarting / exits right away
- Logs mention the client or `cdclient.fdb`: `CLIENT_PATH` in `.env` is wrong
  or the folder is incomplete. Run `lu check-client`.
- Windows: Docker Desktop must be allowed to read the drive the client is on
  (Settings → Resources → File sharing, only for older Hyper-V setups).
- Database errors right after first install: wait a minute and run `lu restart`.

### `No "versions" directory found ... packed asset bundle cannot be loaded`
Packed client: `CLIENT_PATH` points at the `client` folder, but it must point
at its **parent** (the folder holding both `client/` and `versions/`).
Fix `.env`, then `lu start`.

### `player_cheat_detections ... errno: 150` in the logs on first start
Harmless. An early database migration fails, and a later migration recreates
that table correctly. It only appears once, on the first start.

### "Bind for 0.0.0.0:1001 failed: port is already allocated"
Something else is using that port, often another DLU server running outside
Docker. Close it (`MasterServer.exe`), or find it: `netstat -ano | findstr :1001`
(Windows) / `sudo ss -lunp | grep 1001` (Linux).

### Dashboard port 8000 already in use
Set `DASHBOARD_PORT=8080` in `.env`, then `lu start`.

### Client: "unable to connect" or stuck at login
1. `lu status`: all three containers should be up.
2. `boot.cfg` must have `AUTHSERVERIP=0:<EXTERNAL_IP>,` (with the comma) and
   `UGCUSE3DSERVICES=7:0`. Run `lu boot-cfg` on the host.
3. The IP in `boot.cfg` must equal `EXTERNAL_IP` in `.env`.
4. Other PCs: firewall (`.\lu.ps1 firewall` as admin) and Private network
   profile. See [`NETWORKING.md`](NETWORKING.md).
5. Your LAN IP changed: `lu set-ip`, then `lu boot-cfg`.

### Login works but stuck loading into a world
The world servers on UDP 3000-3300 aren't reachable at `EXTERNAL_IP`. Common
causes: `EXTERNAL_IP=localhost` while playing from another PC, those UDP ports
are firewalled, or they aren't port-forwarded for internet play.

### "Wrong username or password" / "Your account needs a play key"
- Accounts made on the dashboard work immediately. If play keys are on, the
  account needs a key (see `ADMIN.md`).
- Reset a password: run `lu create-account` with the same name, answer `y`.

### Dashboard shows errors about the client / images missing
The dashboard needs an unpacked client for model/property rendering. Logins
and moderation still work with a packed client.

### WSL2: works on the host but not from other PCs
Run the scripts from **Windows PowerShell** (`lu.ps1`) so `EXTERNAL_IP` is
the Windows LAN IP, not the WSL IP.

### Start completely fresh
`lu backup` (just in case), then `lu uninstall`, then `lu install`.
