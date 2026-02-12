# YemekBildirimi

**Windows Toast Bildirim Sistemi** - FastAPI server + PowerShell client + Docker deployment ile organizasyonlar için anlık yemek servisi bildirimleri.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-gerekli-blue.svg)](https://www.docker.com/)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2B-lightgrey.svg)](https://www.microsoft.com/windows)

---

## 📋 Genel Bakış

YemekBildirimi, organizasyonlar (kafeteryalar, ofisler, okullar) için yemek servisi hazır olduğunda Windows kullanıcılarını bilgilendirmek üzere tasarlanmış hafif, self-hosted bir bildirim sistemidir. FastAPI (Python 3.12) ile inşa edilmiş, yöneticiler için web paneli ve Windows makinelerde native toast bildirimleri gösteren bir PowerShell client sunar.

**Temel Faydalar:**
- ⚡ **Tek satır kurulum** (server ve client)
- 🔒 **Kurumsal seviye güvenlik** (API keys, basic auth, IP allowlist)
- 🐳 **Docker tabanlı** (bağımlılık karmaşası yok)
- 💾 **Kalıcı durum** (ID'ler restart sonrası sıfırlanmaz)
- 🔄 **Güncelleme dostu** (credentials güncellemelerde korunur)

---

## ✨ Özellikler

### Server (FastAPI + Docker)

- **Web Paneli** (`/panel`): Yöneticilerin bildirim göndermesi için basit HTML formu
- **REST API** (`/notify`): Harici entegrasyonlar için webhook endpoint (API key korumalı)
- **Client Dağıtımı** (`/download/*`): Client scriptleri ve tek satır installer'ı self-hosting
- **Güvenlik**:
  - Panel için HTTP Basic Authentication
  - `/notify` endpoint için API Key authentication
  - Opsiyonel IP allowlist (CIDR desteği)
  - 2 saniyelik rate limiting (spam önleme)
- **Docker Hardening**: Read-only root filesystem, dropped capabilities, resource limits

### Windows Client (PowerShell)

- **Native Toast'lar**: Windows 10/11 bildirimleri için BurntToast modülü
- **Otomatik başlatma**: Scheduled Task veya Startup VBS (fallback)
- **Tek instance**: Mutex duplicate process'leri önler
- **Logo desteği**: Bildirimlerde özel PNG logo
- **Basit config**: Server URL ve polling aralığı ile JSON dosyası

---

## 📦 Gereksinimler

| Bileşen | Gereksinim |
|---------|------------|
| **Server OS** | Ubuntu 20.04+ / Debian 11+ (veya Docker çalıştırabilen Linux) |
| **Server Yazılım** | Docker 20.10+, Docker Compose (plugin) v2+ |
| **Server Port** | 8787 (varsayılan, özelleştirilebilir) |
| **Server RAM** | 128MB minimum (container limit) |
| **Client OS** | Windows 10 1809+ / Windows 11 / Windows Server 2019+ |
| **Client Yazılım** | PowerShell 5.1+ (dahili), BurntToast modülü (otomatik yüklenir) |
| **Ağ** | Client'lardan server'a HTTP erişimi (LAN önerilir) |

---

## 🚀 Hızlı Başlangıç

### Server Kurulumu (Tek Satır)

Ubuntu/Debian'da (sudo yetkisi olan kullanıcı olarak çalıştırın):

```bash
curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | sudo bash
```

**Bu Komut Ne Yapar:**
1. Docker + Docker Compose'u yükler (yoksa)
2. Repository'i `/opt/yemekbildirim` altına klonlar
3. Random credentials ile [server/.env](file:///c:/Full/Half/YemekBildirim/server/.env) oluşturur
4. Docker container'ı build ve başlatır
5. Credentials'ları ekrana yazdırır (bunları kaydedin!)

**İlk Kurulum Çıktı Örneği:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ÖNEMLİ: Bu bilgileri kaydedin!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Panel Kullanıcısı: admin
Panel Şifresi: X9k2Lm4pR7sT
API Key: Ab3dF9xK12ZpQw45YrTg78NmVc56JhLo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**⚠️ ÖNEMLİ**: Panel şifresini ve API key'i hemen kaydedin. Sadece bir kez gösterilir.

**Panele Erişim**: Tarayıcıda `http://<SERVER_IP>:8787/panel` açın.

---

### Belirli Sürüm Kurulumu (Production İçin Önerilen)

Sabit bir release yükleyin (beklenmedik değişiklikleri önler):

```bash
REF=v0.1.0 curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | sudo bash
```

**Desteklenen REF Değerleri:**
- `v0.1.0` - Tag (semantik versiyon release)
- [main](file:///c:/Full/Half/YemekBildirim/install.sh#209-233) - En son kararlı branch (varsayılan)
- `development` - Geliştirme branch'i
- `abc1234` - Belirli commit hash

---

### Windows Client Kurulumu (Tek Satır)

Kullanıcının Windows makinesinde (PowerShell, admin gerekmez):

```powershell
irm http://<SERVER_IP>:8787/download/install.ps1 | iex
```

`<SERVER_IP>` yerine server'ınızın IP adresini yazın.

**Bu Komut Ne Yapar:**
1. Server'dan client scriptlerini indirir (`/download/client.zip`)
2. `%LOCALAPPDATA%\YemekBildirimi` altına açar
3. BurntToast PowerShell modülünü yükler
4. Server URL ile `config.json` oluşturur
5. Scheduled Task kaydeder (login'de otomatik başlat)
6. Client'ı hemen başlatır

**Kurulum Dizini**: `C:\Users\<USERNAME>\AppData\Local\YemekBildirimi`

---

## ⚙️ Konfigürasyon

### Server Konfigürasyonu ([server/.env](file:///c:/Full/Half/YemekBildirim/server/.env))

`/opt/yemekbildirim/server/.env` dosyasını düzenleyin:

```bash
# /notify endpoint için API Key (zorunlu)
YEMEK_API_KEY=Ab3dF9xK12ZpQw45YrTg78NmVc56JhLo

# Panel credentials (zorunlu)
PANEL_USER=admin
PANEL_PASS=X9k2Lm4pR7sT

# Panel için IP Allowlist (opsiyonel, virgül ayraçlı, CIDR destekli)
# Boş = tüm IP'lere izin ver
PANEL_ALLOWED_IPS=192.168.1.0/24,10.0.0.100

# Loglama seviyesi (opsiyonel)
LOG_LEVEL=INFO
```

**`.env` düzenledikten sonra container'ı yeniden başlatın:**
```bash
cd /opt/yemekbildirim/server
sudo docker compose restart
```

---

### Client Konfigürasyonu (`config.json`)

`%LOCALAPPDATA%\YemekBildirimi\config.json` otomatik oluşturulur:

```json
{
  "ServerUrl": "http://<SERVER_IP>:8787",
  "PollingInterval": 5
}
```

| Alan | Açıklama | Varsayılan | Aralık |
|------|----------|------------|--------|
| `ServerUrl` | Server base URL (slash ile bitmemeli) | Kurulumda ayarlanır | - |
| `PollingInterval` | Saniye cinsinden polling sıklığı | 5 | 1-3600 |

**Değişiklikleri Uygulamak İçin**: Client'ı yeniden başlatın (logout/login veya `Start-ScheduledTask -TaskName YemekBildirimiClient`)

---

## 💡 Kullanım

### Panelden Bildirim Gönderme

1. Tarayıcıda `http://<SERVER_IP>:8787/panel` açın
2. Kurulumdan aldığınız credentials ile login olun
3. Mesajı yazın (varsayılan: "🍽️ Yemek geldi! Afiyet olsun.")
4. **YEMEK GELDİ! 🔔** butonuna tıklayın

Tüm bağlı Windows client'lar saniyeler içinde toast bildirimi alacaktır.

---

### API ile Bildirim Gönderme

#### cURL Kullanarak (Linux/macOS)

```bash
curl -X POST http://<SERVER_IP>:8787/notify \
  -H "X-API-Key: Ab3dF9xK12ZpQw45YrTg78NmVc56JhLo" \
  -H "Content-Type: application/json" \
  -d '{"text":"🍽️ Yemek hazır!"}'
```

#### PowerShell Kullanarak (Windows)

```powershell
$headers = @{ "X-API-Key" = "Ab3dF9xK12ZpQw45YrTg78NmVc56JhLo" }
$body = @{ text = "🍽️ Yemek hazır!" } | ConvertTo-Json

Invoke-RestMethod -Uri "http://<SERVER_IP>:8787/notify" `
  -Method Post -Headers $headers -Body $body `
  -ContentType "application/json"
```

**Başarılı Yanıt:**
```json
{
  "ok": true,
  "id": 42
}
```

---

### Güvenlik Modeli

#### Panel Erişimi
- **Authentication**: HTTP Basic Auth (`PANEL_USER` / `PANEL_PASS`)
- **IP Kısıtlama** (opsiyonel): Erişimi sınırlamak için `PANEL_ALLOWED_IPS` ayarlayın
- **Rate Limit**: Bildirimler arası 2 saniye cooldown

#### API Erişimi (`/notify`)
- **Authentication**: `X-API-Key` header (`YEMEK_API_KEY` ile eşleşmeli)
- **IP Kısıtlama**: Yok (API key yeterli)
- **Rate Limit**: 2 saniye cooldown

#### Client Erişimi (`/latest`)
- **Authentication**: Yok (read-only, public data)
- **Rate Limit**: Yok (polling için tasarlanmış)

**Tehdit Modeli**: Güvenilir LAN ağı varsayar. İnternet'e açık deploymentlar için [Production Hardening](#-production-hardening) bölümüne bakın.

---

## 🔄 Güncelleme Prosedürü

### Server'ı En Son Sürüme Güncelleme

[install.sh](file:///c:/Full/Half/YemekBildirim/install.sh) scripti'ni tekrar çalıştırın (credentials korunur):

```bash
curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | sudo bash
```

**Ne Olur:**
1. GitHub'dan en son kodu çeker
2. Mevcut [server/.env](file:///c:/Full/Half/YemekBildirim/server/.env) dosyasını **korur** (credential kaybı olmaz)
3. Docker image'ı yeni kod ile rebuild eder
4. Container'ı yeniden başlatır

**⚠️ Güvenle Çalıştırılabilir**: API key ve panel şifreniz DEĞİŞMEZ.

**Güncellemeden Sonra Logları Kontrol Edin:**
```bash
cd /opt/yemekbildirim/server
sudo docker compose logs --tail=50 -f
```

---

### Belirli Sürüme Güncelleme

```bash
REF=v0.2.0 curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | sudo bash
```

---

### Windows Client'ı Güncelleme

Kurulumla aynı (tek satırı tekrar çalıştırın):

```powershell
irm http://<SERVER_IP>:8787/download/install.ps1 | iex
```

**Ne Olur:**
1. Mevcut client'ı durdurur
2. Scriptleri yeni versiyonlarla değiştirir
3. `config.json`'u korur (server URL ve polling ayarları)
4. Client'ı yeniden başlatır

---

## 🗑️ Kaldırma

### Server'ı Kaldırma

```bash
# Container'ları durdur ve kaldır
cd /opt/yemekbildirim/server
sudo docker compose down -v

# Kurulum dizinini kaldır
sudo rm -rf /opt/yemekbildirim

# (Opsiyonel) Script tarafından yüklendiyse Docker'ı kaldır
sudo apt-get remove -y docker-ce docker-ce-cli containerd.io
```

---

### Windows Client'ı Kaldırma

#### Yöntem 1: Uninstall Script Kullan

Eğer daha önce `client.zip` indirdiyseniz:

```powershell
cd path\to\extracted\client
.\uninstall_client.ps1
```

#### Yöntem 2: Manuel Kaldırma

```powershell
# Scheduled task'ı durdur ve kaldır
Stop-ScheduledTask -TaskName YemekBildirimiClient -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName YemekBildirimiClient -Confirm:$false

# Kurulum dizinini kaldır
Remove-Item -Path "$env:LOCALAPPDATA\YemekBildirimi" -Recurse -Force

# (Opsiyonel) Startup VBS fallback'i kaldır
$startupDir = [Environment]::GetFolderPath("Startup")
Remove-Item "$startupDir\YemekBildirimiClient.vbs" -ErrorAction SilentlyContinue
```

**Not**: BurntToast PowerShell modülü kaldırılmaz (diğer uygulamalar kullanıyor olabilir).

---

## 🔧 Sorun Giderme

### 1. Server: Container Başlamıyor

**Belirtiler**: `docker ps` komutu `yemek-server` container'ını göstermiyor.

**Debug Adımları:**
```bash
cd /opt/yemekbildirim/server
sudo docker compose logs --tail=100
```

**Yaygın Sebepler:**
- **Port çakışması**: 8787 portu zaten kullanımda
  - Çözüm: Install komutunda veya `.env`'de `PORT_BIND` değiştirin
- **Eksik .env**: Environment dosyası bulunamadı
  - Çözüm: [install.sh](file:///c:/Full/Half/YemekBildirim/install.sh)'yi tekrar çalıştırın veya [.env.example](file:///c:/Full/Half/YemekBildirim/server/.env.example)'dan manuel oluşturun
- **İzin hatası**: `/opt/yemekbildirim` yazılabilir değil
  - Çözüm: `sudo chown -R root:root /opt/yemekbildirim`

---

### 2. Server: Health Check Timeout

**Belirtiler**: Kurulum scripti health check başarısızlığı bildiriyor.

**Container Durumunu Doğrulayın:**
```bash
sudo docker ps -a | grep yemek
```

**Container çalışıyor ama health check başarısız ise:**
```bash
# Yerel test
curl http://127.0.0.1:8787/health

# Beklenen: {"ok":true}
```

**Yaygın Sebepler:**
- **Firewall localhost'u engelliyor**: Olası değil ama `ufw status` kontrol edin
- **Yanlış port binding**: `docker ps` çıktısında port mapping'i kontrol edin
- **Container crash loop**: `docker compose logs -f` ile logları görün

---

### 3. Server: Panel "Access Denied" (403) Döndürüyor

**Sebep**: IP'niz `PANEL_ALLOWED_IPS` listesinde değil.

**Çözüm**:
```bash
# .env'yi düzenle, IP'inizi ekle veya kısıtlamayı kaldır
sudo nano /opt/yemekbildirim/server/.env

# Örnek: Tüm IP'lere izin ver
PANEL_ALLOWED_IPS=

# Veya: Belirli network'e izin ver
PANEL_ALLOWED_IPS=192.168.1.0/24

# Yeniden başlat
sudo docker compose restart
```

---

### 4. Server: API "Invalid API Key" (401) Döndürüyor

**Sebep**: `X-API-Key` header `.env`'deki `YEMEK_API_KEY` ile eşleşmiyor.

**Yapılandırılmış Key'i Doğrulayın:**
```bash
sudo grep YEMEK_API_KEY /opt/yemekbildirim/server/.env
```

**Doğru Key ile Test Edin:**
```bash
curl -X POST http://<SERVER_IP>:8787/notify \
  -H "X-API-Key: <KEY_I_BURAYA_YAPIŞTIRIN>" \
  -H "Content-Type: application/json" \
  -d '{"text":"Test"}'
```

---

### 5. Client: "client.zip Boş" Hatası

**Sebep**: Server'ın `client_payload` dizini eksik veya eksik.

**Server'da Çözüm:**
```bash
# client_payload'ın var olduğunu doğrula
ls -lah /opt/yemekbildirim/server/client_payload

# İçermesi gerekenler:
# - client.ps1
# - install_client.ps1
# - uninstall_client.ps1
# - send_yemekgeldi.ps1
# - assets/logo.png

# Eksikse, tekrar clone veya rebuild
cd /opt/yemekbildirim
sudo git pull origin main
cd server
sudo docker compose up -d --build
```

---

### 6. Client: Scheduled Task Hatası (Windows Server 2016/2019)

**Belirtiler**: `New-ScheduledTaskPrincipal` enum hataları ile başarısız oluyor.

**Sebep**: PowerShell cmdlet parameter uyumluluğu Windows versiyonları arasında değişiyor.

**Çözüm**: [install_client.ps1](file:///c:/Full/Half/YemekBildirim/server/client_payload/install_client.ps1) bunu try-catch fallback ile otomatik halleder. Kurulum başarısız olursa:
1. `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\YemekBildirimiClient.vbs` konumunda Startup VBS fallback kontrol edin
2. Manuel task oluşturma:
   ```powershell
   $action = New-ScheduledTaskAction -Execute "powershell.exe" `
     -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File '$env:LOCALAPPDATA\YemekBildirimi\client.ps1'"
   $trigger = New-ScheduledTaskTrigger -AtLogOn
   Register-ScheduledTask -TaskName "YemekBildirimiClient" -Action $action -Trigger $trigger
   ```

---

### 7. Client: Toast Bildirimleri Gösterilmiyor

**Debug Adımları:**

**Adım 1**: BurntToast yüklü mü doğrulayın
```powershell
Get-Module -ListAvailable -Name BurntToast
```
Bulunamazsa:
```powershell
Install-Module -Name BurntToast -Scope CurrentUser -Force
```

**Adım 2**: Client çalışıyor mu kontrol edin
```powershell
Get-ScheduledTask -TaskName YemekBildirimiClient
Get-ScheduledTaskInfo -TaskName YemekBildirimiClient

# Son çalıştırma sonucu 0 olmalı (başarılı)
```

**Adım 3**: Logları kontrol edin
```powershell
Get-Content "$env:LOCALAPPDATA\YemekBildirimi\client.log" -Tail 50
```

**Adım 4**: Windows Bildirim Ayarları
- Windows Ayarlar → Sistem → Bildirimler
- Bildirimlerin etkin olduğundan emin olun
- "PowerShell" veya "Windows PowerShell" uygulamasının bildirimleri engellemediğini kontrol edin

**Adım 5**: Toast'u manuel test edin
```powershell
Import-Module BurntToast
New-BurntToastNotification -Text "Test", "Bunu görüyorsanız, toast'lar çalışıyor"
```

---

### 8. Client: Duplicate Process (Client İki Kez Çalışıyor)

**Belirtiler**: Task Manager birden fazla `powershell.exe` [client.ps1](file:///c:/Full/Half/YemekBildirim/server/client_payload/client.ps1) çalıştırıyor gösteriyor.

**Sebep**: Hem Scheduled Task hem Startup VBS fallback aktif.

**Çözüm**:
```powershell
# Startup VBS'i kaldır
$startupDir = [Environment]::GetFolderPath("Startup")
Remove-Item "$startupDir\YemekBildirimiClient.vbs" -Force -ErrorAction SilentlyContinue

# Sadece Scheduled Task kalsın
Stop-ScheduledTask -TaskName YemekBildirimiClient
Start-ScheduledTask -TaskName YemekBildirimiClient
```

---

### 9. Client: İlk Çalıştırmada Eski Bildirim Görünüyor

**Belirtiler**: Fresh kurulumdan sonra, client kurulmadan önceki bir bildirimi gösteriyor.

**Sebep**: Server'ın `/latest` endpoint'i en son bildirimi döndürür (tasarımdan).

**Beklenen Davranış**: Client `state.json` oluşturulmadan önceki bildirimleri GÖSTERMEZ. Bunu görüyorsanız, kontrol edin:
```powershell
Get-Content "$env:LOCALAPPDATA\YemekBildirimi\state.json"

# Mevcut server ID'si ile eşleşen last_seen_id göstermeli
```

**Manuel Sıfırlama** (gerekirse):
```powershell
# Mevcut server ID'sini alın
Invoke-RestMethod -Uri "http://<SERVER_IP>:8787/latest"

# Client state'ini mevcut ID'ye güncelleyin
@{ last_seen_id = <MEVCUT_ID> } | ConvertTo-Json | Out-File "$env:LOCALAPPDATA\YemekBildirimi\state.json" -Encoding UTF8
```

---

### 10. Genel: UTF-8 Encoding Sorunları (Türkçe Karakterler)

**Belirtiler**: Türkçe karakterler (ğ, ü, ş, ı, ç, ö)   veya bozuk görünüyor.

**Sebep**: PowerShell 5.1 ASCII olmayan karakterler için UTF-8 BOM gerektirir.

**Doğrulama**:
```powershell
# PowerShell scriptleri UTF-8 BOM içermeli
Get-Content "$env:LOCALAPPDATA\YemekBildirimi\client.ps1" -Encoding Byte -TotalCount 3
# Dönmeli: 239, 187, 191 (UTF-8 BOM)
```

**Çözüm**: Repository'deki tüm scriptler zaten UTF-8 BOM'lu. Manuel düzenliyorsanız:
- **VS Code**: Files → Preferences → Settings → `files.encoding` → `utf8bom` ([.ps1](file:///c:/Full/Half/YemekBildirim/client/send_yemekgeldi.ps1) için)
- **Notepad++**: Encoding → UTF-8-BOM → Kaydet

---

## 🔒 Production Hardening

### 1. HTTPS Kullanın (Production İçin Zorunlu)

**Seçenek A: Harici Reverse Proxy** (Tavsiye Edilen)

Server'ı sadece localhost'ta çalıştırın:
```bash
PORT_BIND=127.0.0.1:8787:8787 curl -fsSL ... | sudo bash
```

Sonra Nginx/Caddy/Traefik yapılandırın:

**Nginx Örneği** (`/etc/nginx/sites-available/yemek`):
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

**Caddy Örneği** (`Caddyfile`):
```
yemek.example.com {
    reverse_proxy 127.0.0.1:8787
}
```

**Seçenek B: Docker Nginx + SSL** (İleri Seviye)

SSL yapılandırma seçenekleri için [docker-compose.nginx.yml](file:///c:/Full/Half/YemekBildirim/docker-compose.nginx.yml) ve [nginx/conf/default.docker.conf](file:///c:/Full/Half/YemekBildirim/nginx/conf/default.docker.conf) dosyalarına bakın.

---

### 2. Firewall Yapılandırması

**Sadece gerekli portları açın:**

```bash
# Ubuntu UFW örneği
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH'a izin ver (uzaktan ise)
sudo ufw allow 22/tcp

# HTTPS'e izin ver (reverse proxy kullanıyorsanız)
sudo ufw allow 443/tcp

# Server portuna SADECE LAN'dan izin ver (doğrudan erişim ise)
sudo ufw allow from 192.168.1.0/24 to any port 8787 proto tcp

sudo ufw enable
```

**En Az Ayrıcalık İlkesi:**
- Panel: Sadece admin ağından erişilebilir olmalı
- API: Sadece webhook kaynaklarından erişilebilir olmalı
- Client endpoint (`/latest`): Tüm client'lardan erişilebilir (LAN)

---

### 3. Credential Rotasyon

**Kurulumdan Hemen Sonra Varsayılan Credentials'ları Değiştirin:**

```bash
cd /opt/yemekbildirim/server
sudo nano .env
```

**Güncelleyin:**
- `YEMEK_API_KEY`: Yeni 32+ karakter random string üretin
- `PANEL_PASS`: Güçlü şifre kullanın (min 16 karakter, karışık case, sayılar, semboller)

**Random Credentials Üretme:**
```bash
# Linux
openssl rand -base64 32
# veya
head -c 32 /dev/urandom | base64

# Windows PowerShell
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | % {[char]$_})
```

**Değiştirdikten sonra yeniden başlatın:**
```bash
sudo docker compose restart
```

**⚠️ Client'ları Güncelleyin**: `ServerUrl` şemasını değiştiriyorsanız (HTTP→HTTPS), tüm client `config.json` dosyalarını güncelleyin.

---

### 4. IP Allowlist (Derinlemesine Savunma)

**Panel'i admin IP'lere kısıtlayın:**

```bash
# .env
PANEL_ALLOWED_IPS=192.168.1.10,10.0.0.5
```

**CIDR aralıkları için:**
```bash
PANEL_ALLOWED_IPS=192.168.1.0/24,10.8.0.0/16
```

**Boş = Herkese İzin** (sadece güvenilir LAN'da güvenli).

---

### 5. Log Yönetimi

**Merkezi Loglama** (production):

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

**Log Rotasyon** (lokal loglar kullanıyorsanız):

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

**Logları İzleyin:**
- Başarısız authentication denemeleri (brute force)
- Rate limit ihlalleri
- IP allowlist blokları

```bash
sudo docker compose logs -f | grep -E "(401|403|429)"
```

---

### 6. Yedekleme Stratejisi

**Yedeklenecek Kritik Dosyalar:**

```bash
#!/bin/bash
# /opt/scripts/backup_yemek.sh

BACKUP_DIR="/backup/yemek"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# State yedekle (bildirim ID'leri)
docker cp yemek-server:/app/data/state.json \
  "$BACKUP_DIR/state_$TIMESTAMP.json"

# Credentials yedekle
cp /opt/yemekbildirim/server/.env \
  "$BACKUP_DIR/env_$TIMESTAMP"

# Son 30 günü sakla
find "$BACKUP_DIR" -type f -mtime +30 -delete
```

**Cron Job** (her gün saat 2'de):
```bash
0 2 * * * /opt/scripts/backup_yemek.sh
```

---

### 7. Container Güvenlik Güncellemeleri

**Base Image'ları Güncel Tutun:**

```bash
cd /opt/yemekbildirim/server

# En son Python 3.12 base image'ı çek
sudo docker pull python:3.12-slim

# Güncellenmiş base ile rebuild
sudo docker compose up -d --build

# Eski image'ları temizle
sudo docker image prune -f
```

**Otomatik Güncellemeler** (Watchtower - dikkatli kullanın):

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

### 8. İzleme & Alarmlar

**Health Check İzleme:**

```bash
# Uptime Kuma / Healthchecks.io / Nagios
*/5 * * * * curl -fsS -m 10 --retry 3 http://127.0.0.1:8787/health || \
  curl -X POST https://hc-ping.com/<SIZIN_CHECK_ID>/fail
```

**İzlenecek Metrikler:**
- Health endpoint yanıt süresi
- Container memory kullanımı (128MB altında kalmalı)
- Başarısız auth denemeleri (panel + API)
- Disk alanı (`/app/data` volume)

**Grafana + Prometheus** (ileri seviye):
- Docker metriklerini export et
- Alarm ver: container restart, yüksek memory, 4xx/5xx hatalar

---

### 9. Olay Müdahale Planı

**Credentials Ele Geçirilirse:**

1. **Hemen rotate** edin `.env` secret'larını
2. Server'ı yeniden başlatın: `sudo docker compose restart`
3. **Logları inceleyin** yetkisiz erişim için:
   ```bash
   sudo docker compose logs | grep -E "(notify|panel)" | grep -v "200"
   ```
4. Tüm API entegrasyonlarını yeni key ile güncelleyin
5. Adminleri panel şifresini güncellemeleri için bilgilendirin

**Server Ele Geçirilirse:**

1. Server'ı izole edin (ağ erişimini blokla)
2. Container'ı kötü amaçlı değişiklikler için inceleyin:
   ```bash
   sudo docker diff yemek-server
   ```
3. Backup'tan restore edin veya bilinen-iyi repo commit'ten rebuild edin
4. `.env` ve `server/data/state.json`'u kurcalama için audit edin

---

### 10. Uyumluluk Değerlendirmeleri

**Veri Gizliliği**: Bildirim metni hassas bilgi içerebilir (örn. menü öğeleri). Şunları sağlayın:
- `state.json` herkese okunabilir değil (Docker volume izinleri)
- Loglar güvenli saklanır (düz metin hassas veri yok)
- HTTPS transitde veriyi şifreler

**Erişim Kontrolü**: Kimin sahip olduğunu audit edin:
- Server SSH erişimi (`.env` okuyabilir)
- Docker daemon erişimi (container'ları inspect edebilir)
- Panel credentials (bildirim gönderebilir)

---

## 📚 Dokümantasyon

- **Proje Yapısı**: `ARCHITECTURE.md` (varsa) veya [server/app.py](file:///c:/Full/Half/YemekBildirim/server/app.py)'yi inceleyin
- **Geliştirme Kurulumu**: README "Geliştirme Notları" bölümüne bakın
- **API Referansı**: [server/app.py](file:///c:/Full/Half/YemekBildirim/server/app.py) endpoint tanımlarına bakın
- **Sorun Giderme**: Yukarıdaki bölüme bakın (10 yaygın sorun)

---

## 🤝 Katkıda Bulunma

Katkılarınızı bekliyoruz! Lütfen:

1. Repository'yi fork edin
2. Feature branch oluşturun: `git checkout -b feature/amazing-feature`
3. [Conventional Commits](https://www.conventionalcommits.org/) ile commit edin:
   ```
   feat: HTTPS desteği eklendi
   fix: Türkçe karakterlerde encoding sorunu çözüldü
   docs: Sorun giderme kılavuzu güncellendi
   ```
4. Branch'e push edin: `git push origin feature/amazing-feature`
5. Pull Request açın

**Göndermeden önce:**
- Temiz Ubuntu 22.04 LTS (server) ve Windows 11 (client) üzerinde test edin
- Özellik ekliyorsanız README'yi güncelleyin
- Kodda hardcoded IP veya secret olmadığından emin olun

---

## 📜 Lisans

[Lisans belirtin - MIT, GPL, vb.]

---

## 🆘 Destek

- **Sorunlar**: [GitHub Issues](https://github.com/alemgir0/YemekBildirimi/issues)
- **Tartışmalar**: [GitHub Discussions](https://github.com/alemgir0/YemekBildirimi/discussions)
- **E-posta**: [İletişim e-postanız]

---

## 🙏 Teşekkürler

- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [BurntToast](https://github.com/Windos/BurntToast) - PowerShell için Windows toast bildirimleri
- [Docker](https://www.docker.com/) - Containerization platform

---

**Kesintisiz yemek servisi bildirimleri için ❤️ ile geliştirilmiştir**
