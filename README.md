# YemekBildirimi

**Languages:** [English](README.md) | [Türkçe](README_TR.md)

**Windows Toast Notification System** - Instant food service notifications for organizations using FastAPI server + PowerShell client + Docker deployment.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://www.docker.com/)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2B-lightgrey.svg)](https://www.microsoft.com/windows)

---

## 📋 Overview

YemekBildirimi is a lightweight, self-hosted notification system designed for organizations (cafeterias, offices, schools) to notify Windows users when food service is ready. Built with FastAPI (Python 3.12), it provides a web panel for admins and a PowerShell client for Windows machines that displays native toast notifications.

**Key Benefits:**
- ⚡ **One-line installation** (server and client)
- 🔒 **Enterprise-grade security** (API keys, basic auth, IP allowlist)
- 🐳 **Docker-based** (no dependency hell)
- 💾 **Persistent state** (IDs don't reset on restart)
- 🔄 **Update-friendly** (preserves credentials across updates)

---

## ✨ Features

### Server (FastAPI + Docker)

- **Web Panel** (`/panel`): Simple HTML form for admins to send notifications
- **REST API** (`/notify`): Webhook endpoint for external integrations (protected by API key)
- **Client Distribution** (`/download/*`): Self-hosting client scripts and one-line installer
- **Security**:
  - HTTP Basic Authentication for panel
  - API Key authentication for `/notify` endpoint
  - Optional IP allowlist (CIDR support)
  - 2-second rate limiting (spam prevention)
- **Docker Hardening**: Read-only root filesystem, dropped capabilities, resource limits

### Windows Client (PowerShell)

- **Native Toasts**: BurntToast module for Windows 10/11 notifications
- **Auto-start**: Scheduled Task or Startup VBS (fallback)
- **Single Instance**: Mutex prevents duplicate processes
- **Logo Support**: Custom PNG logo in notifications
- **Simple Config**: JSON file with server URL and poll interval
  
---

## 📦 Requirements

| Component | Requirement |
|-----------|-------------|
| **Server OS** | Ubuntu 20.04+ / Debian 11+ (or any Linux with Docker) |
| **Server Software** | Docker 20.10+, Docker Compose (plugin) v2+ |
| **Server Port** | 8787 (default, customizable) |
| **Server RAM** | 128MB minimum (container limit) |
| **Client OS** | Windows 10 1809+ / Windows 11 / Windows Server 2019+ |
| **Client Software** | PowerShell 5.1+ (built-in), BurntToast module (auto-installed) |
| **Network** | HTTP access from clients to server (LAN recommended) |

---

## 🚀 Quick Start

### Server Installation (One-Line)

On Ubuntu/Debian (run as user with sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | sudo bash
```

**What This Does:**
1. Installs Docker + Docker Compose (if missing)
2. Clones repository to `/opt/yemekbildirim`
3. Generates [server/.env](file:///c:/Full/Half/YemekBildirim/server/.env) with random credentials
4. Builds and starts Docker container
5. Prints credentials (save these!)

**First Install Output Example:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 IMPORTANT: Save these credentials!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Panel User: admin
Panel Password: X9k2Lm4pR7sT
API Key: Ab3dF9xK12ZpQw45YrTg78NmVc56JhLo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**⚠️ IMPORTANT**: Save the panel password and API key immediately. They are only shown once.

**Access Panel**: Open `http://<SERVER_IP>:8787/panel` in browser.

---

### Install Specific Version (Recommended for Production)

Install a pinned release (prevents unexpected changes):

```bash
REF=v0.1.0 curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | sudo bash
```

**Supported REF Values:**
- `v0.1.0` - Tag (semantic version release)
- [main](file:///c:/Full/Half/YemekBildirim/install.sh#209-233) - Latest stable branch (default)
- `development` - Development branch
- `abc1234` - Specific commit hash

---

### Windows Client Installation (One-Line)

On user's Windows machine (PowerShell, no admin required):

```powershell
irm http://<SERVER_IP>:8787/download/install.ps1 | iex
```

Replace `<SERVER_IP>` with your server's IP address.

**What This Does:**
1. Downloads client scripts from server (`/download/client.zip`)
2. Extracts to `%LOCALAPPDATA%\YemekBildirimi`
3. Installs BurntToast PowerShell module
4. Creates `config.json` with server URL
5. Registers Scheduled Task (auto-start on login)
6. Starts client immediately

**Installation Directory**: `C:\Users\<USERNAME>\AppData\Local\YemekBildirimi`

---

## ⚙️ Configuration

### Server Configuration ([server/.env](file:///c:/Full/Half/YemekBildirim/server/.env))

Edit `/opt/yemekbildirim/server/.env`:

```bash
# API Key for /notify endpoint (required)
YEMEK_API_KEY=Ab3dF9xK12ZpQw45YrTg78NmVc56JhLo

# Panel credentials (required)
PANEL_USER=admin
PANEL_PASS=X9k2Lm4pR7sT

# IP Allowlist for panel (optional, comma-separated, CIDR supported)
# Empty = allow all IPs
PANEL_ALLOWED_IPS=192.168.1.0/24,10.0.0.100

# Logging level (optional)
LOG_LEVEL=INFO
```

**After editing `.env`, restart container:**
```bash
cd /opt/yemekbildirim/server
sudo docker compose restart
```

---

### Client Configuration (`config.json`)

Auto-generated at `%LOCALAPPDATA%\YemekBildirimi\config.json`:

```json
{
  "ServerUrl": "http://<SERVER_IP>:8787",
  "PollingInterval": 5
}
```

| Field | Description | Default | Range |
|-------|-------------|---------|-------|
| `ServerUrl` | Server base URL (no trailing slash) | Set during install | - |
| `PollingInterval` | Poll frequency in seconds | 5 | 1-3600 |

**To Apply Changes**: Restart client (logout/login or `Start-ScheduledTask -TaskName YemekBildirimiClient`)

---

## 💡 Usage

### Send Notification from Panel

1. Open `http://<SERVER_IP>:8787/panel` in browser
2. Login with credentials from installation
3. Type message (default: "🍽️ Yemek geldi! Afiyet olsun.")
4. Click **YEMEK GELDİ! 🔔**

All connected Windows clients will receive a toast notification within seconds.

---

### Send Notification via API

#### Using cURL (Linux/macOS)

```bash
curl -X POST http://<SERVER_IP>:8787/notify \
  -H "X-API-Key: Ab3dF9xK12ZpQw45YrTg78NmVc56JhLo" \
  -H "Content-Type: application/json" \
  -d '{"text":"🍽️ Food is ready!"}'
```

#### Using PowerShell (Windows)

```powershell
$headers = @{ "X-API-Key" = "Ab3dF9xK12ZpQw45YrTg78NmVc56JhLo" }
$body = @{ text = "🍽️ Food is ready!" } | ConvertTo-Json

Invoke-RestMethod -Uri "http://<SERVER_IP>:8787/notify" `
  -Method Post -Headers $headers -Body $body `
  -ContentType "application/json"
```

**Success Response:**
```json
{
  "ok": true,
  "id": 42
}
```

---

### Security Model

#### Panel Access
- **Authentication**: HTTP Basic Auth (`PANEL_USER` / `PANEL_PASS`)
- **IP Restriction** (optional): Set `PANEL_ALLOWED_IPS` to limit access
- **Rate Limit**: 2-second cooldown between notifications

#### API Access (`/notify`)
- **Authentication**: `X-API-Key` header (matches `YEMEK_API_KEY`)
- **IP Restriction**: None (API key is sufficient)
- **Rate Limit**: 2-second cooldown

#### Client Access (`/latest`)
- **Authentication**: None (read-only, public data)
- **Rate Limit**: None (designed for polling)

**Threat Model**: Assumes trusted LAN network. For internet-facing deployments, see [Production Hardening](#-production-hardening).

---

## 🔄 Update Procedure

### Update Server to Latest Version

Re-run [install.sh](file:///c:/Full/Half/YemekBildirim/install.sh) (credentials are preserved):

```bash
curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | sudo bash
```

**What Happens:**
1. Fetches latest code from GitHub
2. **Preserves** existing [server/.env](file:///c:/Full/Half/YemekBildirim/server/.env) file (no credential loss)
3. Rebuilds Docker image with new code
4. Restarts container

**⚠️ Safe to Run**: Your API key and panel password will NOT change.

**Check Logs After Update:**
```bash
cd /opt/yemekbildirim/server
sudo docker compose logs --tail=50 -f
```

---

### Update to Specific Version

```bash
REF=v0.2.0 curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | sudo bash
```

---

### Update Windows Client

Same as installation (re-run one-liner):

```powershell
irm http://<SERVER_IP>:8787/download/install.ps1 | iex
```

**What Happens:**
1. Stops existing client
2. Replaces scripts with new versions
3. Preserves `config.json` (server URL and polling settings)
4. Restarts client

---

## 🗑️ Uninstallation

### Uninstall Server

```bash
# Stop and remove containers
cd /opt/yemekbildirim/server
sudo docker compose down -v

# Remove installation directory
sudo rm -rf /opt/yemekbildirim

# (Optional) Remove Docker if installed by script
sudo apt-get remove -y docker-ce docker-ce-cli containerd.io
```

---

### Uninstall Windows Client

#### Method 1: Use Uninstall Script

If you downloaded `client.zip` previously:

```powershell
cd path\to\extracted\client
.\uninstall_client.ps1
```

#### Method 2: Manual Uninstall

```powershell
# Stop and remove scheduled task
Stop-ScheduledTask -TaskName YemekBildirimiClient -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName YemekBildirimiClient -Confirm:$false

# Remove installation directory
Remove-Item -Path "$env:LOCALAPPDATA\YemekBildirimi" -Recurse -Force

# (Optional) Remove Startup VBS fallback
$startupDir = [Environment]::GetFolderPath("Startup")
Remove-Item "$startupDir\YemekBildirimiClient.vbs" -ErrorAction SilentlyContinue
```

**Note**: BurntToast PowerShell module is NOT removed (may be used by other apps).

---

## 🔧 Troubleshooting

### 1. Server: Container Won't Start

**Symptoms**: `docker ps` shows no `yemek-server` container.

**Debug Steps:**
```bash
cd /opt/yemekbildirim/server
sudo docker compose logs --tail=100
```

**Common Causes:**
- **Port conflict**: Port 8787 already in use
  - Fix: Change `PORT_BIND` in install command or `.env`
- **Missing .env**: Environment file not found
  - Fix: Re-run [install.sh](file:///c:/Full/Half/YemekBildirim/install.sh) or create manually from [.env.example](file:///c:/Full/Half/YemekBildirim/server/.env.example)
- **Permission error**: `/opt/yemekbildirim` not writable
  - Fix: `sudo chown -R root:root /opt/yemekbildirim`

---

### 2. Server: Health Check Timeout

**Symptoms**: Installation script reports health check failure.

**Verify Container Status:**
```bash
sudo docker ps -a | grep yemek
```

**If container is running but health check fails:**
```bash
# Test locally
curl http://127.0.0.1:8787/health

# Expected: {"ok":true}
```

**Common Causes:**
- **Firewall blocking localhost**: Unlikely, but check `ufw status`
- **Wrong port binding**: Check `docker ps` output for port mapping
- **Container crash loop**: See logs with `docker compose logs -f`

---

### 3. Server: Panel Returns "Access Denied" (403)

**Cause**: Your IP is not in `PANEL_ALLOWED_IPS` list.

**Fix**:
```bash
# Edit .env, add your IP or remove restriction
sudo nano /opt/yemekbildirim/server/.env

# Example: Allow all IPs
PANEL_ALLOWED_IPS=

# Or: Allow specific network
PANEL_ALLOWED_IPS=192.168.1.0/24

# Restart
sudo docker compose restart
```

---

### 4. Server: API Returns "Invalid API Key" (401)

**Cause**: `X-API-Key` header doesn't match `YEMEK_API_KEY` in `.env`.

**Verify Configured Key:**
```bash
sudo grep YEMEK_API_KEY /opt/yemekbildirim/server/.env
```

**Test with Correct Key:**
```bash
curl -X POST http://<SERVER_IP>:8787/notify \
  -H "X-API-Key: <PASTE_KEY_HERE>" \
  -H "Content-Type: application/json" \
  -d '{"text":"Test"}'
```

---

### 5. Client: "client.zip is Empty" Error

**Cause**: Server's `client_payload` directory is missing or incomplete.

**Fix on Server:**
```bash
# Verify client_payload exists
ls -lah /opt/yemekbildirim/server/client_payload

# Should contain:
# - client.ps1
# - install_client.ps1
# - uninstall_client.ps1
# - send_yemekgeldi.ps1
# - assets/logo.png

# If missing, re-clone or rebuild
cd /opt/yemekbildirim
sudo git pull origin main
cd server
sudo docker compose up -d --build
```

---

### 6. Client: Scheduled Task Error (Windows Server 2016/2019)

**Symptoms**: `New-ScheduledTaskPrincipal` fails with enum errors.

**Cause**: PowerShell cmdlet parameter compatibility varies across Windows versions.

**Fix**: [install_client.ps1](file:///c:/Full/Half/YemekBildirim/server/client_payload/install_client.ps1) automatically handles this with try-catch fallback. If installation fails:
1. Check for Startup VBS fallback at `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\YemekBildirimiClient.vbs`
2. Manual task creation:
   ```powershell
   $action = New-ScheduledTaskAction -Execute "powershell.exe" `
     -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File '$env:LOCALAPPDATA\YemekBildirimi\client.ps1'"
   $trigger = New-ScheduledTaskTrigger -AtLogOn
   Register-ScheduledTask -TaskName "YemekBildirimiClient" -Action $action -Trigger $trigger
   ```

---

### 7. Client: Toast Notifications Not Showing

**Debug Steps:**

**Step 1**: Verify BurntToast is installed
```powershell
Get-Module -ListAvailable -Name BurntToast
```
If not found:
```powershell
Install-Module -Name BurntToast -Scope CurrentUser -Force
```

**Step 2**: Check client is running
```powershell
Get-ScheduledTask -TaskName YemekBildirimiClient
Get-ScheduledTaskInfo -TaskName YemekBildirimiClient

# Last run result should be 0 (success)
```

**Step 3**: Check logs
```powershell
Get-Content "$env:LOCALAPPDATA\YemekBildirimi\client.log" -Tail 50
```

**Step 4**: Windows Notification Settings
- Windows Settings → System → Notifications
- Ensure notifications are enabled
- Check if there's a "PowerShell" or "Windows PowerShell" app blocking notifications

**Step 5**: Test toast manually
```powershell
Import-Module BurntToast
New-BurntToastNotification -Text "Test", "If you see this, toasts work"
```

---

### 8. Client: Duplicate Processes (Client Running Twice)

**Symptoms**: Task Manager shows multiple `powershell.exe` running [client.ps1](file:///c:/Full/Half/YemekBildirim/server/client_payload/client.ps1).

**Cause**: Both Scheduled Task and Startup VBS fallback are active.

**Fix**:
```powershell
# Remove Startup VBS
$startupDir = [Environment]::GetFolderPath("Startup")
Remove-Item "$startupDir\YemekBildirimiClient.vbs" -Force -ErrorAction SilentlyContinue

# Keep only Scheduled Task
Stop-ScheduledTask -TaskName YemekBildirimiClient
Start-ScheduledTask -TaskName YemekBildirimiClient
```

---

### 9. Client: Old Notification Appears on First Run

**Symptoms**: After fresh install, client shows a notification from before it was installed.

**Cause**: Server's `/latest` endpoint returns the most recent notification (by design).

**Expected Behavior**: Client will NOT show notifications from before its `state.json` was created. If you see this, check:
```powershell
Get-Content "$env:LOCALAPPDATA\YemekBildirimi\state.json"

# Should show last_seen_id matching current server ID
```

**Manual Reset** (if needed):
```powershell
# Get current server ID
Invoke-RestMethod -Uri "http://<SERVER_IP>:8787/latest"

# Update client state to current ID
@{ last_seen_id = <CURRENT_ID> } | ConvertTo-Json | Out-File "$env:LOCALAPPDATA\YemekBildirimi\state.json" -Encoding UTF8
```

---

### 10. General: UTF-8 Encoding Issues (Turkish Characters)

**Symptoms**: Turkish characters (ğ, ü, ş, ı, ç, ö) display as   or corrupted.

**Cause**: PowerShell 5.1 requires UTF-8 BOM for non-ASCII characters.

**Verification**:
```powershell
# PowerShell scripts MUST have UTF-8 BOM
Get-Content "$env:LOCALAPPDATA\YemekBildirimi\client.ps1" -Encoding Byte -TotalCount 3
# Should return: 239, 187, 191 (UTF-8 BOM)
```

**Fix**: All scripts in repository are already UTF-8 BOM. If editing manually:
- **VS Code**: Files → Preferences → Settings → `files.encoding` → `utf8bom` (for [.ps1](file:///c:/Full/Half/YemekBildirim/client/send_yemekgeldi.ps1))
- **Notepad++**: Encoding → UTF-8-BOM → Save

---

## 🔒 Production Hardening

### 1. Use HTTPS (Mandatory for Production)

**Option A: External Reverse Proxy** (Recommended)

Run server on localhost only:
```bash
PORT_BIND=127.0.0.1:8787:8787 curl -fsSL ... | sudo bash
```

Then configure Nginx/Caddy/Traefik:

**Nginx Example** (`/etc/nginx/sites-available/yemek`):
```nginx
server {
    listen 443 ssl;
    server_name yemek.example.com;

    ssl_certificate /etc/letsencrypt/live/yemek.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yemek.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8787;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

**Caddy Example** (`Caddyfile`):
```
yemek.example.com {
    reverse_proxy 127.0.0.1:8787
}
```

**Option B: Docker Nginx with SSL** (Advanced)

See [docker-compose.nginx.yml](file:///c:/Full/Half/YemekBildirim/docker-compose.nginx.yml) and [nginx/conf/default.docker.conf](file:///c:/Full/Half/YemekBildirim/nginx/conf/default.docker.conf) for SSL configuration options.

---

### 2. Firewall Configuration

**Allow only necessary ports:**

```bash
# Ubuntu UFW example
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (if remote)
sudo ufw allow 22/tcp

# Allow HTTPS (if using reverse proxy)
sudo ufw allow 443/tcp

# Allow server port ONLY from LAN (if direct access)
sudo ufw allow from 192.168.1.0/24 to any port 8787 proto tcp

sudo ufw enable
```

**Principle of Least Privilege:**
- Panel: Only accessible from admin network
- API: Only accessible from webhook sources
- Client endpoint (`/latest`): Accessible from all clients (LAN)

---

### 3. Credential Rotation

**Change Default Credentials Immediately After Install:**

```bash
cd /opt/yemekbildirim/server
sudo nano .env
```

**Update:**
- `YEMEK_API_KEY`: Generate new 32+ character random string
- `PANEL_PASS`: Use strong password (min 16 chars, mixed case, numbers, symbols)

**Generate Random Credentials:**
```bash
# Linux
openssl rand -base64 32
# or
head -c 32 /dev/urandom | base64

# Windows PowerShell
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | % {[char]$_})
```

**After changing, restart:**
```bash
sudo docker compose restart
```

**⚠️ Update Clients**: If changing `ServerUrl` schema (HTTP→HTTPS), update all client `config.json` files.

---

### 4. IP Allowlist  (Defense in Depth)

**Restrict panel to admin IPs:**

```bash
# .env
PANEL_ALLOWED_IPS=192.168.1.10,10.0.0.5
```

**For CIDR ranges:**
```bash
PANEL_ALLOWED_IPS=192.168.1.0/24,10.8.0.0/16
```

**Empty = Allow All** (only safe on trusted LAN).

---

### 5. Log Management

**Centralized Logging** (production):

```yaml
# docker-compose.yml
services:
  server:
    logging:
      driver: syslog
      options:
        syslog-address: "udp://syslog-server.local:514"
        tag: "yemek-server"
```

**Log Rotation** (if using local logs):

```bash
# /etc/logrotate.d/yemek
/opt/yemekbildirim/server/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

**Monitor Logs for:**
- Failed authentication attempts (brute force)
- Rate limit violations
- IP allowlist blocks

```bash
sudo docker compose logs -f | grep -E "(401|403|429)"
```

---

### 6. Backup Strategy

**Critical Files to Backup:**

```bash
#!/bin/bash
# /opt/scripts/backup_yemek.sh

BACKUP_DIR="/backup/yemek"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup state (notification IDs)
docker cp yemek-server:/app/data/state.json \
  "$BACKUP_DIR/state_$TIMESTAMP.json"

# Backup credentials
cp /opt/yemekbildirim/server/.env \
  "$BACKUP_DIR/env_$TIMESTAMP"

# Keep last 30 days
find "$BACKUP_DIR" -type f -mtime +30 -delete
```

**Cron Job** (daily at 2 AM):
```bash
0 2 * * * /opt/scripts/backup_yemek.sh
```

---

### 7. Container Security Updates

**Keep Base Images Updated:**

```bash
cd /opt/yemekbildirim/server

# Pull latest Python 3.12 base image
sudo docker pull python:3.12-slim

# Rebuild with updated base
sudo docker compose up -d --build

# Clean old images
sudo docker image prune -f
```

**Automated Updates** (Watchtower - use with caution):

```yaml
# docker-compose.yml
services:
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 86400 yemek-server
```

---

### 8. Monitoring & Alerts

**Health Check Monitoring:**

```bash
# Uptime Kuma / Healthchecks.io / Nagios
*/5 * * * * curl -fsS -m 10 --retry 3 http://127.0.0.1:8787/health || \
  curl -X POST https://hc-ping.com/<YOUR_CHECK_ID>/fail
```

**Metrics to Monitor:**
- Health endpoint response time
- Container memory usage (should stay under 128MB)
- Failed auth attempts (panel + API)
- Disk space (`/app/data` volume)

**Grafana + Prometheus** (advanced):
- Export Docker metrics
- Alert on: container restart, high memory, 4xx/5xx errors

---

### 9. Incident Response Plan

**If Credentials Compromised:**

1. **Immediately rotate** `.env` secrets
2. Restart server: `sudo docker compose restart`
3. **Review logs** for unauthorized access:
   ```bash
   sudo docker compose logs | grep -E "(notify|panel)" | grep -v "200"
   ```
4. Update all API integrations with new key
5. Notify admins to update panel password

**If Server Compromised:**

1. Isolate server (block network access)
2. Inspect container for malicious changes:
   ```bash
   sudo docker diff yemek-server
   ```
3. Restore from backup or rebuild from known-good repo commit
4. Audit `.env` and `server/data/state.json` for tampering

---

### 10. Compliance Considerations

**Data Privacy**: Notification text may contain sensitive info (e.g., menu items). Ensure:
- `state.json` is not world-readable (Docker volume permissions)
- Logs are stored securely (no plain-text sensitive data)
- HTTPS encrypts data in transit

**Access Control**: Audit who has:
- Server SSH access (can read `.env`)
- Docker daemon access (can inspect containers)
- Panel credentials (can send notifications)

---

## 📚 Documentation

- **Project Structure**: See `ARCHITECTURE.md` (if exists) or review [server/app.py](file:///c:/Full/Half/YemekBildirim/server/app.py)
- **Development Setup**: See README section "Development Notes"
- **API Reference**: See [server/app.py](file:///c:/Full/Half/YemekBildirim/server/app.py) endpoint definitions
- **Troubleshooting**: See above section (10 common issues)

---

## 🤝 Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit with [Conventional Commits](https://www.conventionalcommits.org/):
   ```
   feat: Add HTTPS support
   fix: Resolve encoding issue in Turkish characters
   docs: Update troubleshooting guide
   ```
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

**Before submitting:**
- Test on clean Ubuntu 22.04 LTS (server) and Windows 11 (client)
- Update README if adding features
- Ensure no hardcoded IPs or secrets in code

---

## 📜 License

[Specify license - MIT, GPL, etc.]

---

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/alemgir0/YemekBildirimi/issues)
- **Discussions**: [GitHub Discussions](https://github.com/alemgir0/YemekBildirimi/discussions)
- **Email**: [Your contact email]

---

## 🙏 Acknowledgments

- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [BurntToast](https://github.com/Windos/BurntToast) - Windows toast notifications for PowerShell
- [Docker](https://www.docker.com/) - Containerization platform

---

**Built with ❤️ for seamless food service notifications**
