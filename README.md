# YemekBildirim

Enterprise Notification System - Cafeteria announcement notifications for Windows clients.

============================================================
OVERVIEW
============================================================

YemekBildirim consists of:

- Server: FastAPI backend (Docker)
- Nginx: Reverse proxy (optional)
- Client: PowerShell-based Windows client (Scheduled Task)

Data Flow:
1. Admin sends notification via /panel (Basic Auth protected)
2. Server stores notification in server/data/
3. Clients poll /latest endpoint
4. New notifications trigger Windows Toast popups

============================================================
QUICK SERVER INSTALL (RECOMMENDED)
============================================================

Ubuntu/Debian one-liner:

curl -fsSL https://raw.githubusercontent.com/alemgir0/yemekbildirim/main/install.sh | bash

What it does:
- Installs Docker if missing
- Clones repo to /opt/yemekbildirim
- Generates random secrets
- Starts server on port 8787
- Waits for health check
- Prints access URLs and credentials

After install:

API Health:
http://<SERVER_IP>:8787/health

Admin Panel:
http://<SERVER_IP>:8787/panel

IMPORTANT:
Installer prints credentials once. Save them immediately.

============================================================
INSTALLATION MODES
============================================================

OPTION A – Server Only (Default)
--------------------------------

Port: 8787

bash install.sh

Access:
http://SERVER_IP:8787/panel

--------------------------------

OPTION B – Docker Nginx (Port 8080)
--------------------------------

ENABLE_NGINX=1 HTTP_PORT=8080 bash install.sh

Access:
http://SERVER_IP:8080/panel

--------------------------------

OPTION C – Host Nginx Reverse Proxy
--------------------------------

Use nginx/conf/default.host.conf

Proxy upstream:
127.0.0.1:8787

============================================================
CLIENT INSTALLATION (WINDOWS)
============================================================

REQUIREMENTS:
- Windows 10/11
- PowerShell 5.1+
- BurntToast module

============================================================
METHOD A – DOWNLOAD FROM SERVER (RECOMMENDED)
============================================================

Run this in PowerShell:

------------------------------------------------------------
$Server = "http://192.168.2.211:8787"
$Temp   = "$env:TEMP\YemekClient"

New-Item -ItemType Directory -Force -Path $Temp | Out-Null
Invoke-WebRequest "$Server/download/client.zip" -OutFile "$Temp\client.zip"
Expand-Archive "$Temp\client.zip" -DestinationPath $Temp -Force
Set-Location $Temp

Install-Module BurntToast -Scope CurrentUser -Force
.\install_client.ps1 -ServerUrl $Server -PollingInterval 5
------------------------------------------------------------

This:
- Downloads client
- Extracts
- Installs BurntToast
- Creates Scheduled Task
- Starts client

============================================================
METHOD B – GITHUB DIRECT DOWNLOAD
============================================================

------------------------------------------------------------
$Repo   = "https://raw.githubusercontent.com/alemgir0/yemekbildirim/main/client"
$Temp   = "$env:TEMP\YemekClient"
$Server = "http://192.168.2.211:8787"

New-Item -ItemType Directory -Force -Path $Temp | Out-Null

Invoke-WebRequest "$Repo/client.ps1" -OutFile "$Temp\client.ps1"
Invoke-WebRequest "$Repo/install_client.ps1" -OutFile "$Temp\install_client.ps1"
Invoke-WebRequest "$Repo/uninstall_client.ps1" -OutFile "$Temp\uninstall_client.ps1"

Set-Location $Temp
Install-Module BurntToast -Scope CurrentUser -Force
.\install_client.ps1 -ServerUrl $Server -PollingInterval 5
------------------------------------------------------------

============================================================
VERIFY CLIENT
============================================================

Check Scheduled Task:

schtasks /Query /TN "\YemekBildirimiClient"

Check logs:

notepad $env:LOCALAPPDATA\YemekBildirimi\client.log

============================================================
SERVER CONFIGURATION
============================================================

File:
server/.env

Example:

YEMEK_API_KEY=your_random_key
PANEL_USER=admin
PANEL_PASS=strong_password
PANEL_ALLOWED_IPS=

Restart server after changes:

cd server
docker compose restart

============================================================
TROUBLESHOOTING
============================================================

Panel 401 Unauthorized:
- Check PANEL_USER and PANEL_PASS in server/.env

Health check:

curl http://localhost:8787/health

Server logs:

docker logs yemek-server

Client not working:
- Check BurntToast installed
- Check Scheduled Task
- Check client.log

============================================================
UPDATE SERVER
============================================================

cd /opt/yemekbildirim
git pull
cd server
docker compose up -d --build

============================================================
UNINSTALL
============================================================

Client:

schtasks /Delete /TN "\YemekBildirimiClient" /F
Remove-Item "$env:LOCALAPPDATA\YemekBildirimi" -Recurse -Force

Server:

cd /opt/yemekbildirim/server
docker compose down -v
sudo rm -rf /opt/yemekbildirim

============================================================
END
============================================================
