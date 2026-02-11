# 🍽️ YemekBildirim

![Docker](https://img.shields.io/badge/Docker-Ready-blue)
![FastAPI](https://img.shields.io/badge/FastAPI-Backend-green)
![Windows Client](https://img.shields.io/badge/Windows-Client-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)

Enterprise Cafeteria Notification System for Windows environments.

---

# 📌 Overview

YemekBildirim is a lightweight internal notification system designed for corporate environments.

It consists of:

* **FastAPI Backend (Dockerized)**
* **Optional Nginx Reverse Proxy**
* **PowerShell Windows Client (Scheduled Task)**
* **Persistent JSON-based state storage**

---

# 🏗 Architecture

```
+-------------------+
|   Admin Browser   |
|   /panel (Auth)   |
+---------+---------+
          |
          v
+-------------------+
|   FastAPI Server  |
|   Port 8787       |
|   Docker          |
+---------+---------+
          |
          v
+-------------------+
|  server/data/     |
|  JSON storage     |
+-------------------+

Clients Poll:

+-------------------+
| Windows Client    |
| Poll /latest      |
| Toast Notification|
+-------------------+
```

---

# 🚀 QUICK SERVER INSTALL (RECOMMENDED)

Ubuntu / Debian one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/alemgir0/yemekbildirim/main/install.sh | bash
```

What it does:

* Installs Docker (if missing)
* Clones repository to `/opt/yemekbildirim`
* Generates secure random API key
* Generates secure panel password
* Starts container on port 8787
* Waits for health check
* Prints credentials once

After install:

```bash
http://<SERVER_IP>:8787/health
http://<SERVER_IP>:8787/panel
```

⚠️ Save printed credentials immediately.

---

# ⚙ Installation Modes

## 1️⃣ Server Only (Default)

Port: 8787

```bash
curl -fsSL https://raw.githubusercontent.com/alemgir0/yemekbildirim/main/install.sh | bash
```

---

## 2️⃣ Docker Nginx (Port 8080)

```bash
ENABLE_NGINX=1 HTTP_PORT=8080 bash install.sh
```

Access:

```
http://<SERVER_IP>:8080/panel
```

Custom ports:

```bash
ENABLE_NGINX=1 HTTP_PORT=9000 HTTPS_PORT=9443 bash install.sh
```

---

## 3️⃣ Host Nginx Integration

If nginx already runs on host:

```bash
sudo cp /opt/yemekbildirim/nginx/conf/default.host.conf /etc/nginx/sites-available/yemek
sudo ln -s /etc/nginx/sites-available/yemek /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

# 🖥 Windows Client Installation

Requirements:

* Windows 10 / 11
* PowerShell 5.1+
* BurntToast module

---

## ✅ Method A — One-Line Install (Recommended)

Open PowerShell as Administrator:

```powershell
Invoke-WebRequest -Uri "http://192.168.2.211:8787/download/client.zip" -OutFile "$env:TEMP\yemek_client.zip"; Expand-Archive "$env:TEMP\yemek_client.zip" -DestinationPath "$env:TEMP\yemek_client" -Force; Set-Location "$env:TEMP\yemek_client"; .\install_client.ps1 -ServerUrl "http://192.168.2.211:8787" -PollingInterval 5
```

✔ Downloads
✔ Extracts
✔ Installs Scheduled Task
✔ Starts immediately

---

## 🧩 Method B — Manual Install

Download:

```
http://<SERVER_IP>:8787/download/client.zip
```

Extract and run:

```powershell
cd client
.\install_client.ps1 -ServerUrl "http://192.168.2.211:8787" -PollingInterval 5
```

---

# 🔐 Security Model

### Server-Side Authentication

* HTTP Basic Auth protects `/panel`
* Credentials stored in `server/.env`
* Secure comparison using `secrets.compare_digest`

### Optional IP Restriction

In `server/.env`:

```env
PANEL_ALLOWED_IPS=192.168.2.0/24
```

### Optional Nginx Layer Auth

Add `.htpasswd` for double protection.

---

# 🧾 Configuration

`server/.env`

```env
YEMEK_API_KEY=auto_generated_key
PANEL_USER=admin
PANEL_PASS=auto_generated_password
PANEL_ALLOWED_IPS=
```

Restart after changes:

```bash
cd /opt/yemekbildirim/server
docker compose restart
```

---

# 🧪 Verification

Health check:

```bash
curl http://localhost:8787/health
```

Panel test:

```bash
curl -u admin:password http://localhost:8787/panel
```

Docker status:

```bash
docker ps
```

---

# 🔄 Update Server

```bash
cd /opt/yemekbildirim
git pull origin main
cd server
docker compose down
docker compose up -d --build
```

---

# 📜 Logs

Server:

```bash
docker logs yemek-server --tail 50 -f
```

Client:

```powershell
notepad $env:LOCALAPPDATA\YemekBildirimi\client.log
```

---

# 🗑 Uninstall

Server:

```bash
cd /opt/yemekbildirim/server
docker compose down -v
sudo rm -rf /opt/yemekbildirim
```

Client:

```powershell
schtasks /Delete /TN "\YemekBildirimiClient" /F
Remove-Item "$env:LOCALAPPDATA\YemekBildirimi" -Recurse -Force
```

---

# 📌 FAQ

**Where is data stored?**
`server/data/state.json`

**Can I run multiple clients?**
Yes. Install on all Windows machines.

**How to rotate API key?**
Edit `.env` → restart container.

---

# 📄 License

MIT License

---

İstersen bir sonraki adımda şunları da yapabiliriz:

* 🔐 HTTPS + Let’s Encrypt otomatik kurulum ekleyelim
* 🏢 Domain-based production deployment bölümü ekleyelim
* 📦 Release versioning ve changelog yapısı oluşturalım
* 🔄 GitHub Actions ile auto-build sistemi kuralım

