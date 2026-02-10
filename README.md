# YemekBildirim

**Enterprise Notification System** - Cafeteria announcement notifications for Windows clients.

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Install (Recommended)](#quick-install-recommended)
- [Installation Options](#installation-options)
  - [Option 1: Server-Only (Default)](#option-1-server-only-default)
  - [Option 2: Docker Nginx (Port 8080)](#option-2-docker-nginx-port-8080)
  - [Option 3: Host Nginx Integration](#option-3-host-nginx-integration)
- [Client Installation](#client-installation)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Verification](#verification)
- [Maintenance](#maintenance)
- [Uninstall](#uninstall)

---

## Overview

YemekBildirim is a notification system consisting of:

- **Server**: FastAPI backend (Docker)
- **Nginx**: Reverse proxy (optional - Docker or host)
- **Client**: PowerShell-based Windows client (Scheduled Task)

**Data Flow:**
1. Admin sends notification via `/panel` (Basic Auth protected)
2. Server stores notification as JSON in `server/data/`
3. Clients poll `/latest` endpoint periodically
4. New notifications trigger Windows Toast popups

---

## Quick Install (Recommended)

**One-liner install** for Ubuntu/Debian servers:

```bash
curl -fsSL https://raw.githubusercontent.com/<USERNAME>/YemekBildirim/main/install.sh | bash
```

**What this does:**
- ✅ Installs Docker if missing
- ✅ Clones repo to `/opt/yemekbildirim`
- ✅ Generates random secrets for API key and panel password
- ✅ Starts server on port `8787`
- ✅ Waits for health check
- ✅ Prints access URLs and credentials

**After install:**
```
API Health: http://<SERVER_IP>:8787/health
Admin Panel: http://<SERVER_IP>:8787/panel
```

> **⚠️ SAVE YOUR CREDENTIALS:** The installer prints auto-generated credentials **once**. Save them immediately.

---

## Installation Options

### Option 1: Server-Only (Default)

**Use when:** You want the simplest setup or plan to add nginx later.

**Ports:** `8787` (no port 80/443 usage)

**Steps:**
1. Run the quick install command above, or:
   ```bash
   git clone https://github.com/<USERNAME>/YemekBildirim.git
   cd YemekBildirim
   bash install.sh
   ```

2. Access the panel:
   ```bash
   curl http://localhost:8787/health
   # Response: {"status":"healthy"}
   ```

**Port Conflict?** If port `8787` is in use, edit `server/docker-compose.yml` and change the port mapping.

---

### Option 2: Docker Nginx (Port 8080)

**Use when:** You want nginx in Docker but already have something on port 80.

**Ports:** `8080` (HTTP), `8443` (HTTPS)

**Why 8080?** To avoid conflicts with existing nginx/Apache on port 80.

**Installation:**
```bash
# Enable nginx mode during install
ENABLE_NGINX=1 HTTP_PORT=8080 bash install.sh
```

Or if already installed:
```bash
cd /opt/yemekbildirim
ENABLE_NGINX=1 HTTP_PORT=8080 bash install.sh
```

**What happens:**
- Nginx container runs alongside server
- Both containers share a Docker network
- Root `/` redirects to `/panel`
- Access: `http://<SERVER_IP>:8080/panel`

**Custom ports:**
```bash
ENABLE_NGINX=1 HTTP_PORT=9000 HTTPS_PORT=9443 bash install.sh
```

> **⚠️ WARNING:** Using `HTTP_PORT=80` may conflict with existing web servers.

**Nginx config:** `nginx/conf/default.docker.conf` (auto-mounted)

---

### Option 3: Host Nginx Integration

**Use when:** You already have nginx installed on the host and want to proxy to the Docker container.

**Prerequisites:**
- nginx installed on host
- YemekBildirim server running (Option 1)

**Steps:**

**1. Copy nginx config:**
```bash
sudo cp /opt/yemekbildirim/nginx/conf/default.host.conf /etc/nginx/sites-available/yemek
```

**2. Edit server_name:**
```bash
sudo nano /etc/nginx/sites-available/yemek
# Change: server_name yemek.example.com;
```

**3. Enable site:**
```bash
sudo ln -s /etc/nginx/sites-available/yemek /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

**4. Access:**
```
http://yemek.example.com/panel
```

**SSL/HTTPS:** See commented-out HTTPS section in `default.host.conf` for Let's Encrypt integration.

**Nginx config:** `nginx/conf/default.host.conf` (upstream: `127.0.0.1:8787`)

---

## Client Installation

### Requirements
- Windows 10/11
- PowerShell 5.1+
- BurntToast module

### Installation Steps

**1. Install BurntToast module:**
```powershell
Install-Module -Name BurntToast -Scope CurrentUser -Force
```

**2. Download client files:**
- Clone repo and copy `client/` folder to Windows PC, or
- Download from web: `http://<SERVER>/download/client.zip` (if configured)

**3. Run installer:**
```powershell
cd client
.\install_client.ps1 -ServerUrl "https://yemek.example.com" -PollingInterval 5
```

**Parameters:**
- `-ServerUrl`: Your server address (default: `https://yemek.example.com`)
- `-PollingInterval`: Polling interval in seconds (default: `5`)

**What installer does:**
1. Copies files to `%LOCALAPPDATA%\YemekBildirimi`
2. Creates Scheduled Task `\YemekBildirimiClient` (runs on logon)
3. Starts task immediately

**Verification:**
```powershell
# Check task exists
schtasks /Query /TN "\YemekBildirimiClient"

# View logs
notepad $env:LOCALAPPDATA\YemekBildirimi\client.log
```

---

## Configuration

### Server Environment Variables

Edit `server/.env`:

```env
YEMEK_API_KEY=<32_char_random_string>   # Auto-generated on first install
PANEL_USER=admin                         # Panel username (fixed)
PANEL_PASS=<16_char_random_string>       # Auto-generated on first install
PANEL_ALLOWED_IPS=                       # Empty = allow all, or: 192.168.1.0/24
```

> **⚠️ SECURITY:** Never commit `.env` to git. It's gitignored by default.

**To change credentials:**
1. Edit `server/.env`
2. Restart container: `cd server && docker compose restart`

---

### Nginx Basic Auth (Optional)

The admin panel has **server-side Basic Auth** by default. To add an **additional nginx-level auth layer**:

**1. Generate `.htpasswd`:**
```bash
cd /opt/yemekbildirim/nginx/conf/
htpasswd -c .htpasswd admin
```

**2. Uncomment auth lines in nginx config:**

In `nginx/conf/default.docker.conf` or `default.host.conf`:
```nginx
location /panel {
    auth_basic "Yemek Panel";
    auth_basic_user_file /etc/nginx/conf.d/.htpasswd;  # Uncomment this
    proxy_pass http://yemek_api/panel;
    # ...
}
```

**3. Reload nginx:**
```bash
# Docker nginx:
docker compose -f server/docker-compose.yml -f docker-compose.nginx.yml restart yemek-nginx

# Host nginx:
sudo nginx -t && sudo systemctl reload nginx
```

> **NOTE:** Basic auth is **optional**. Panel already requires username/password via server-side auth.

---

## Troubleshooting

### Port 80 Already in Use

**Symptom:** Can't access server on port 80.

**Explanation:**
- **Server-only mode** uses port `8787` by default (no port 80)
- **Docker nginx mode** defaults to port `8080` (not 80)
- To use port 80, explicitly set: `HTTP_PORT=80`

**Solution:**
```bash
# Check what's using port 80
sudo netstat -tuln | grep :80

# Use non-conflicting port
ENABLE_NGINX=1 HTTP_PORT=8080 bash install.sh
```

---

### Health Check Timeout

**Symptom:** Install script fails with "Service did not become healthy".

**Debug steps:**
```bash
# Check container status
docker ps -a

# View server logs
docker logs yemek-server

# Check port binding
netstat -tuln | grep 8787

# Manual health check
curl http://127.0.0.1:8787/health
```

---

### 401 Unauthorized (Panel Access)

**Symptom:** Browser shows "401 Unauthorized" when accessing `/panel`.

**Cause:** Basic authentication required.

**Solution:**
1. Use credentials from install output, or
2. Check `server/.env` for `PANEL_USER` and `PANEL_PASS`

**Browser should prompt for:**
- Username: `admin`
- Password: `<from .env file>`

---

### Client Not Receiving Notifications

**Debug checklist:**

**1. Task running?**
```powershell
schtasks /Query /TN "\YemekBildirimiClient"
```

**2. Correct server URL?**
```powershell
notepad $env:LOCALAPPDATA\YemekBildirimi\client.ps1
# Check $ServerUrl variable
```

**3. Server reachable?**
```powershell
curl https://yemek.example.com/health
curl https://yemek.example.com/latest
```

**4. BurntToast installed?**
```powershell
Get-Module -ListAvailable -Name BurntToast
```

**5. Check logs:**
```powershell
notepad $env:LOCALAPPDATA\YemekBildirimi\client.log
```

**6. Duplicate instance?**
```powershell
# Kill all instances
Get-Process powershell | Where-Object { $_.CommandLine -like "*client.ps1*" } | Stop-Process -Force

# Restart task
schtasks /Run /TN "\YemekBildirimiClient"
```

---

## Verification

### Server Health Check

```bash
# Test API
curl http://localhost:8787/health
# Expected: {"status":"healthy"}

# Test panel (requires auth)
curl -u admin:<PASSWORD> http://localhost:8787/panel | head -n 20
# Expected: HTML content
```

---

### Docker Container Status

```bash
# List running containers
docker ps

# Expected output (server-only):
# yemek-server   (port 8787)

# Expected output (with nginx):
# yemek-server   (port 8787)
# yemek-nginx    (ports 8080/8443)
```

---

### Clean Clone Test

After cloning repo to a new environment:

```bash
# Secrets should NOT be tracked
[ ! -f server/.env ] && echo "✓ .env not tracked"
[ ! -f nginx/conf/.htpasswd ] && echo "✓ .htpasswd not tracked"

# Example files should exist
[ -f server/.env.example ] && echo "✓ .env.example exists"
[ -f nginx/conf/.htpasswd.example ] && echo "✓ .htpasswd.example exists"

# No uncommitted changes
git status | grep "nothing to commit" && echo "✓ Clean repository"
```

---

## Maintenance

### Update Server

```bash
cd /opt/yemekbildirim
git pull origin main

cd server/
docker compose down
docker compose build --no-cache
docker compose up -d
```

---

### Update Client

1. Download new `client/` folder
2. Re-run installer:
   ```powershell
   .\install_client.ps1 -ServerUrl "https://yemek.example.com"
   ```

Installer overwrites old installation automatically.

---

### View Logs

**Server logs:**
```bash
docker logs yemek-server
docker logs yemek-server --tail 50 -f  # Follow mode
```

**Client logs:**
```powershell
notepad $env:LOCALAPPDATA\YemekBildirimi\client.log
```

---

## Uninstall

### Client Uninstall

**Method 1: Use uninstaller:**
```powershell
cd client
.\uninstall_client.ps1
```

**Method 2: Manual:**
```powershell
# Delete Scheduled Task
schtasks /Delete /TN "\YemekBildirimiClient" /F

# Delete files
Remove-Item "$env:LOCALAPPDATA\YemekBildirimi" -Recurse -Force
```

---

### Server Uninstall

**Server-only mode:**
```bash
cd /opt/yemekbildirim/server
docker compose down -v  # -v removes volumes
```

**With docker nginx:**
```bash
cd /opt/yemekbildirim
docker compose -f server/docker-compose.yml -f docker-compose.nginx.yml down -v
```

**Remove repository:**
```bash
sudo rm -rf /opt/yemekbildirim
```

**If using systemd:**
```bash
sudo systemctl stop yemekbildirimi
sudo systemctl disable yemekbildirimi
sudo rm /etc/systemd/system/yemekbildirimi.service
sudo systemctl daemon-reload
```

---

## FAQ

**Q: Can I use port 80 for docker nginx?**  
A: Yes, set `HTTP_PORT=80 ENABLE_NGINX=1 bash install.sh`. But ensure no other service uses port 80.

**Q: Is .htpasswd required?**  
A: No. Panel has server-side Basic Auth. Nginx `.htpasswd` is an optional additional layer.

**Q: Where are notifications stored?**  
A: Server stores them in `server/data/notifications.json` (persisted via Docker volume).

**Q: Can I run multiple clients?**  
A: Yes. Install on each Windows PC using the same `ServerUrl`.

**Q: How do I change the API key?**  
A: Edit `server/.env`, change `YEMEK_API_KEY`, then `docker compose restart`.

---

## License

MIT License - See LICENSE file for details.

## Support

For issues:
1. Check [Troubleshooting](#troubleshooting)
2. View logs (server: `docker logs yemek-server`, client: `client.log`)
3. Verify installation steps
