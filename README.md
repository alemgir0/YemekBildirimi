# YemekBildirimi (V0.1)

**YemekBildirimi**, ofis içi kullanım için geliştirilmiş küçük bir bildirim sistemidir:
- Sunucu (FastAPI) bir “son bildirim” durumunu tutar.
- Panelden veya API’den “Yemek geldi” gibi bir mesaj tetiklenir.
- Windows client arka planda `/latest` endpoint’ini poll’lar ve yeni mesaj geldiğinde **toast bildirim** gösterir.

Repo: https://github.com/alemgir0/YemekBildirimi

---

## İçindekiler
- [Mimari](#mimari)
- [Gereksinimler](#gereksinimler)
- [Hızlı Kurulum (Server)](#hızlı-kurulum-server)
- [Konfigürasyon (.env)](#konfigürasyon-env)
- [Kullanım](#kullanım)
- [Windows Client](#windows-client)
- [Güvenlik Notları](#güvenlik-notları)
- [Troubleshooting](#troubleshooting)
- [Uninstall / Geri Alma](#uninstall--geri-alma)
- [Geliştirme Notları](#geliştirme-notları)

---

## Mimari

### Server (FastAPI)
- `POST /notify` : API ile bildirim tetikler (header: `x-api-key`)
- `GET /latest` : En son bildirimi döner
- `GET /panel` : Web panel (Basic Auth)
- `POST /panel/notify` : Panel form submit
- `GET /download/client.zip` : Client payload’ını zip olarak indirir
- `GET /download/install.ps1` : Windows için **tek satır kurulum** script’ini üretir (dinamik base URL)

### Client (Windows / PowerShell)
- `%LOCALAPPDATA%\YemekBildirimi\config.json` içinden `ServerUrl` ve `PollingInterval` okur
- `/latest` poll ederek yeni ID geldiğinde toast gösterir
- `client.log` içine log yazar, `state.json` ile “son görülen ID”yi saklar
- **Current User** kurulumu: admin istemez
- Otomatik başlatma: Scheduled Task (olmazsa Startup fallback)

---

## Gereksinimler

### Server
- Linux önerilir (Debian/Ubuntu)
- Docker + Docker Compose (plugin) önerilir
- Açık port: varsayılan `8787/tcp`

### Client
- Windows 10/11
- PowerShell 5.1 (varsayılan) yeterli
- Toast için `BurntToast` modülü (installer user-scope kurmayı dener; kuramazsa client çalışır ama toast atlaması olabilir)

---

## Hızlı Kurulum (Server)

### Seçenek A — Tek komut (önerilen)
> Sunucuda Docker yoksa kurar, projeyi `/opt/yemekbildirim` altına alır ve servisleri ayağa kaldırır.

```bash
curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | bash
