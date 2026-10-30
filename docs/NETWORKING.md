# Networking

## Ports

| Port | Protocol | Used for |
|------|----------|----------|
| 1001 | UDP | Login (auth server) |
| 2005 | UDP | Chat server |
| 3000-3300 | UDP | World/zone servers (one port per running world) |
| 8000 | TCP | Nexus Dashboard website (change with `DASHBOARD_PORT`) |

## The one setting that matters: `EXTERNAL_IP`

When a player logs in, the server tells their client which IP to connect to
for each world. That IP is `EXTERNAL_IP` in `.env`. Every player must be able
to reach it, and it must match what's in their `boot.cfg`.

| Who plays | `EXTERNAL_IP` |
|-----------|---------------|
| Only the host PC | `localhost` |
| Anyone on your home network | the host's LAN IP, e.g. `192.168.1.50` (install picks this automatically) |
| Friends over the internet | your public IP or a DDNS name |

Change it with `lu set-ip <ip>` (restarts the server), then update `boot.cfg` on the clients.

## Home network (LAN)

1. Give the host PC a **fixed LAN IP**: set a DHCP reservation in your
   router (search "<router brand> DHCP reservation"). Otherwise the IP can
   change and everyone has to update `boot.cfg`.
2. Windows: make sure your network is set to **Private** (Settings → Network →
   your connection → Network profile type), and run `.\lu.ps1 firewall` in an
   admin PowerShell.
3. Linux with ufw: `sudo ufw allow 1001,2005/udp && sudo ufw allow 3000:3300/udp && sudo ufw allow 8000/tcp`
4. Friends set `AUTHSERVERIP=0:<LAN IP>,` in `boot.cfg` and register at `http://<LAN IP>:8000`.

## Friends over the internet

**Easiest and safest: a VPN like Tailscale or ZeroTier.** Install it on the host
and on each friend's PC, set `EXTERNAL_IP` to the host's Tailscale IP
(`100.x.y.z`), and use that IP in everyone's `boot.cfg`. No router changes,
nothing exposed to the public internet.

**Port forwarding** (if you really want it public):
1. Do the LAN steps above first (fixed LAN IP).
2. In your router, forward UDP 1001, 2005, 3000-3300 to the host's LAN IP.
   Only forward TCP 8000 if friends need the dashboard. If you do, put it behind
   HTTPS (a reverse proxy like Caddy or nginx).
3. Find your public IP (https://ifconfig.me). If it changes, use a DDNS name (DuckDNS, No-IP).
4. `lu set-ip <public IP or DDNS name>`.
5. **Hairpin NAT:** with a public `EXTERNAL_IP`, players *inside* your house may not
   be able to connect unless the router supports NAT loopback. If not, use the VPN option.
6. If your ISP uses CGNAT (the router's WAN IP isn't the same as your public IP),
   port forwarding won't work; use the VPN option.

The DLU developers recommend small groups of trusted friends, not public servers.
