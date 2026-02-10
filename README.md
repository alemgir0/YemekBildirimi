# YemekBildirimi

**Windows Notification System** - Enterprise notification solution for cafeteria announcements.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Server Setup](#server-setup)
- [Nginx Configuration](#nginx-configuration)
- [Client Installation](#client-installation)
- [Troubleshooting](#troubleshooting)
- [Maintenance and Updates](#maintenance-and-updates)
- [Uninstall](#uninstall)

---

## Overview

YemekBildirimi is a 3-tier system consisting of a FastAPI server, external Nginx reverse proxy, and Windows clients.

**Components:**
- **Server** (`server/`) - FastAPI backend, runs in Docker
- **Nginx** (external) - Reverse proxy, SSL termination, Basic Auth
- **Client** (`client/`) - PowerShell-based Windows client, runs via Scheduled Task

---

## Architecture

```
┌─────────────┐      HTTPS       ┌─────────────┐      HTTP       ┌─────────────┐
│   Windows   │ ──────────────▶  │    Nginx    │ ──────────────▶ │   FastAPI   │
│   Client    │    (SSL/Auth)    │  (External) │   (no auth)     │   Server    │
│ (Scheduled  │                  │             │                 │  (Docker)   │
│    Task)    │ ◀───────────────  │             │ ◀──────────────  │             │
└─────────────┘      Notify      └─────────────┘     JSON        └─────────────┘
```

**Data Flow:**
1. Admin sends notification via `/panel` (protected by Nginx Basic Auth)
2. Server stores notification as JSON
3. Clients poll `/latest` endpoint periodically (no auth)
4. If new notification exists, Windows Toast is displayed

---

## Server Setup

### Requirements

- Docker and Docker Compose
- Linux server (optional: for systemd)

### Installation Steps

**1. Clone the repo:**
```bash
git clone <repo-url>
cd YemekBildirim/server
```

**2. Create environment file:**
```bash
cp .env.example .env
nano .env
```

Edit `.env`:
```env
YEMEK_API_KEY=change_me          # API key for panel
PANEL_USER=admin                  # Panel username
PANEL_PASS=strong_password_here   # Panel password
PANEL_ALLOWED_IPS=                # Empty = all IPs, or: 192.168.1.0/24
```

> **⚠️ IMPORTANT:** `.env` file should NOT be committed to git. It only exists on the server.

**3. Start with Docker Compose:**
```bash
cd server/
docker compose up -d
```

**4. Health check:**
```bash
curl http://localhost:8787/health
# Response: {"status":"healthy"}
```

### Optional: Systemd Auto-Start

To start automatically on system boot:

**1. Copy service file:**
```bash
sudo cp deploy/yemekbildirimi.service /etc/systemd/system/
```

**2. Edit WorkingDirectory:**
```bash
sudo nano /etc/systemd/system/yemekbildirimi.service
# WorkingDirectory=/opt/YemekBildirim/server  (adjust to your actual path)
```

**3. Reload systemd and enable:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable yemekbildirimi
sudo systemctl start yemekbildirimi
```

**4. Check status:**
```bash
sudo systemctl status yemekbildirimi
```

---

## Nginx Configuration

> **NOTE:** Nginx runs externally as a reverse proxy, outside this repository.

### General Structure

- **Public Endpoints** (no auth): `/health`, `/latest`, `/notify`, `/download/`
- **Protected Endpoint** (Basic Auth): `/panel`

### Basic Auth Setup

**1. Create `.htpasswd` file:**
```bash
cd YemekBildirim/nginx/conf/

# Method 1: htpasswd utility
htpasswd -c .htpasswd admin

# Method 2: openssl
printf "admin:$(openssl passwd -apr1)\n" > .htpasswd
```

> **⚠️ IMPORTANT:** `.htpasswd` file should NOT be committed to git. Only `.htpasswd.example` sample file is in the repo.

**2. Nginx config example:**

In `nginx/conf/default.conf`, the `/panel` endpoint is protected with Basic Auth:

```nginx
location /panel {
    auth_basic "Yemek Panel";
    auth_basic_user_file /etc/nginx/conf.d/.htpasswd;
    proxy_pass http://yemek-server:8787;
    # ... other proxy settings
}
```

**3. Reload Nginx:**
```bash
sudo nginx -t
sudo systemctl reload nginx
```

**Important Notes:**
- Nginx is configured as an **external reverse proxy** in this setup
- The `default.conf` file in this repo is a reference example
- Adjust `upstream` server name/port based on your Docker network setup
- For internal Docker networks, use service name `yemek-server:8787`
- For external access, use appropriate host:port mapping

---

## Client Installation

### Requirements

- Windows 10/11
- PowerShell 5.1 or higher
- BurntToast module (for notifications)

### BurntToast Module Installation

```powershell
Install-Module -Name BurntToast -Scope CurrentUser -Force
```

### Installation

**1. Download client files:**
- Copy `client/` folder to Windows PC or
- Download as ZIP: `https://<DOMAIN>/download/client.zip`

**2. Run installation script:**

Administrator rights **not required** (user-level Scheduled Task):

```powershell
cd client
.\install_client.ps1 -ServerUrl "https://<DOMAIN>" -PollingInterval 5
```

**Parameters:**
- `-ServerUrl` : Server address (default: https://yemek.example.com)
- `-PollingInterval` : Polling interval in seconds (default: 5)

**What the installer does:**
1. Copies files to `%LOCALAPPDATA%\YemekBildirimi` directory
2. Cleans up legacy VBS startup files (no longer used)
3. Deletes old Scheduled Task if exists and recreates
4. Creates new Scheduled Task: `\YemekBildirimiClient` (ONLOGON + 10s delay)
5. Starts the task immediately

### Post-Installation Verification

**1. Verify task is running:**
```powershell
schtasks /Query /TN "\YemekBildirimiClient"
```

**2. Check log file:**
```powershell
notepad $env:LOCALAPPDATA\YemekBildirimi\client.log
```

**3. Check running instance:**
```powershell
Get-Process | Where-Object { $_.CommandLine -like "*client.ps1*" }
```

---

## Troubleshooting

### No Notifications Received

**Symptom:** Client is running but no notifications are displayed.

**Solution Steps:**

**1. Old Scheduled Task conflict:**

An old task from previous installation might be running with outdated server address:

```powershell
# List all YemekBildirim tasks
schtasks /Query /FO LIST | Select-String -Pattern "YemekBildirim" -Context 0,10

# Delete old task manually
schtasks /Delete /TN "\YemekBildirimiClient" /F

# Reinstall
cd C:\path\to\client
.\install_client.ps1 -ServerUrl "https://<DOMAIN>"
```

**2. BurntToast module missing:**

```powershell
# Check if module is installed
Get-Module -ListAvailable -Name BurntToast

# Install if missing
Install-Module -Name BurntToast -Scope CurrentUser -Force
```

**3. Duplicate instance running:**

Client has mutex protection but manual check:

```powershell
# Kill all client.ps1 processes
Get-Process powershell | Where-Object { $_.CommandLine -like "*client.ps1*" } | Stop-Process -Force

# Restart task
schtasks /Run /TN "\YemekBildirimiClient"
```

### Old Installation Path Conflict

**Symptom:** Previous installation was at `%USERPROFILE%\YemekBildirimi`.

**Solution:** Installer automatically moves old path to `%LOCALAPPDATA%\YemekBildirimi_old`. Manual cleanup if needed:

```powershell
Remove-Item "$env:USERPROFILE\YemekBildirimi" -Recurse -Force
Remove-Item "$env:LOCALAPPDATA\YemekBildirimi_old" -Recurse -Force
```

### Log File Location

```powershell
# Open log file
notepad $env:LOCALAPPDATA\YemekBildirimi\client.log

# State file (last seen notification ID)
type $env:LOCALAPPDATA\YemekBildirimi\state.txt
```

### Server Connection Error

If getting **HTTP Error (latest)** errors:

1. Check server is running:
```bash
docker ps | grep yemek-server
```

2. Check Nginx proxy is running:
```bash
sudo systemctl status nginx
```

3. Manual test from client:
```powershell
curl https://<DOMAIN>/health
curl https://<DOMAIN>/latest
```

### Windows Notification Settings

Notifications might be disabled in system settings:

**Settings → System → Notifications → PowerShell** must be enabled.

---

## Maintenance and Updates

### Server Update

```bash
cd /opt/YemekBildirim
git pull origin main

cd server/
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Client Update

1. Download new `client/` files
2. Rerun installer (overwrites old installation):
```powershell
.\install_client.ps1 -ServerUrl "https://<DOMAIN>"
```

### Log Rotation

Client logs can grow over time:

```powershell
# Clear log file (stop and start client)
schtasks /End /TN "\YemekBildirimiClient"
Remove-Item $env:LOCALAPPDATA\YemekBildirimi\client.log
schtasks /Run /TN "\YemekBildirimiClient"
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

### Server Uninstall

```bash
cd /opt/YemekBildirim/server
docker compose down -v  # -v flag: also delete volumes

# If using systemd:
sudo systemctl stop yemekbildirimi
sudo systemctl disable yemekbildirimi
sudo rm /etc/systemd/system/yemekbildirimi.service
sudo systemctl daemon-reload
```

---

## Clean Clone Test Checklist

Verification after cloning repo to a new environment:

### Windows

```powershell
# Clone
git clone <repo-url>
cd YemekBildirim

# Verification 1: Secret files not tracked
Test-Path server/.env          # Should be False
Test-Path nginx/conf/.htpasswd # Should be False

# Verification 2: Example files exist
Test-Path server/.env.example            # True
Test-Path nginx/conf/.htpasswd.example   # True
Test-Path deploy/yemekbildirimi.service  # True
Test-Path .gitignore                     # True

# Verification 3: README content
Select-String -Path README.md -Pattern "Scheduled Task"  # Should find
```

### Linux

```bash
# Clone
git clone <repo-url>
cd YemekBildirim

# Verification 1: Secret files not tracked
[ ! -f server/.env ] && echo "OK: .env not tracked"
[ ! -f nginx/conf/.htpasswd ] && echo "OK: .htpasswd not tracked"

# Verification 2: Example files exist
[ -f server/.env.example ] && echo "OK: .env.example exists"
[ -f nginx/conf/.htpasswd.example ] && echo "OK: .htpasswd.example exists"
[ -f deploy/yemekbildirimi.service ] && echo "OK: systemd service exists"

# Verification 3: README content
grep -q "Scheduled Task" README.md && echo "OK: Scheduled Task documented"

# Verification 4: Clean git status
git status | grep "nothing to commit" && echo "OK: Clean clone"
```

---

## License

MIT License - See LICENSE file for details.

## Support

For issues, please check log files and verify all installation steps.
