# Installing Docker

## Windows 10/11

1. Make sure virtualization is enabled in BIOS (Task Manager → Performance → CPU → "Virtualization: Enabled").
2. In an **admin** PowerShell: `wsl --install` then reboot (skip if WSL2 is already installed).
3. Install Docker Desktop: https://www.docker.com/products/docker-desktop/
   or `winget install -e --id Docker.DockerDesktop`
4. Start Docker Desktop, accept the license, wait for **Engine running**.
5. Settings → General → tick **Start Docker Desktop when you sign in** (so the server comes back after a reboot).
6. Check: `docker compose version`

## Linux (Ubuntu/Debian)

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER     # then log out and back in
sudo systemctl enable --now docker
docker compose version
```
Other distros: https://docs.docker.com/engine/install/

## macOS

Install Docker Desktop (Apple silicon or Intel build): https://www.docker.com/products/docker-desktop/
or `brew install --cask docker`, then open it once.

Note: on Apple silicon the server images are x86-64 and run under emulation; it works but is slower.
