#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# =========================
# Config (override via env)
# =========================
REPO_URL="${REPO_URL:-https://github.com/alemgir0/YemekBildirimi.git}"
REF="${REF:-main}"          # branch / tag / commit
INSTALL_DIR="${INSTALL_DIR:-/opt/yemekbildirim}"

# Optional modes
ENABLE_NGINX="${ENABLE_NGINX:-0}"
HTTP_PORT="${HTTP_PORT:-8080}"
HTTPS_PORT="${HTTPS_PORT:-8443}"

# Port bind override examples:
#   PORT_BIND="8787:8787"
#   PORT_BIND="127.0.0.1:8787:8787"
PORT_BIND="${PORT_BIND:-8787:8787}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[-]${NC} $*" >&2; exit 1; }

# sudo detection
SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || die "sudo bulunamadı. Root olarak çalıştır veya sudo kur."
  SUDO="sudo"
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }

install_deps_apt() {
  log "APT bağımlılıkları kuruluyor (curl, git, ca-certificates, gnupg, lsb-release)..."
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq ca-certificates curl gnupg lsb-release git
}

install_docker_deb_ubuntu() {
  . /etc/os-release || die "/etc/os-release okunamadı."
  [[ "$ID" == "ubuntu" || "$ID" == "debian" ]] || die "Desteklenmeyen OS: $ID (Ubuntu/Debian hedefleniyor)."

  install_deps_apt

  log "Docker repo ekleniyor ($ID)..."
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  CODENAME="${VERSION_CODENAME:-}"
  [[ -n "$CODENAME" ]] || CODENAME="$(lsb_release -cs 2>/dev/null || true)"
  [[ -n "$CODENAME" ]] || die "Dağıtım codename bulunamadı (VERSION_CODENAME/lsb_release)."

  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${CODENAME} stable" \
  | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  $SUDO apt-get update -qq
  log "Docker Engine + Compose Plugin kuruluyor..."
  $SUDO apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  $SUDO systemctl enable --now docker >/dev/null 2>&1 || true
}

detect_docker_cmd() {
  if docker ps >/dev/null 2>&1; then
    echo "docker"
  else
    echo "$SUDO docker"
  fi
}

setup_repo() {
  log "Repo kurulumu: $INSTALL_DIR (REF=$REF)"
  $SUDO mkdir -p "$(dirname "$INSTALL_DIR")"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    warn "Mevcut kurulum bulundu, güncelleniyor..."
    $SUDO git -C "$INSTALL_DIR" remote set-url origin "$REPO_URL" >/dev/null 2>&1 || true
    $SUDO git -C "$INSTALL_DIR" fetch --all --tags --prune
  else
    log "Repo klonlanıyor..."
    $SUDO rm -rf "$INSTALL_DIR"
    $SUDO git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    $SUDO git -C "$INSTALL_DIR" fetch --all --tags --prune
  fi

  # REF checkout:
  # - origin/<branch> varsa: branch'e geç + hard reset
  # - tag varsa: tag checkout (detached)
  # - değilse: commit hash vb.
  if $SUDO git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/remotes/origin/$REF"; then
    $SUDO git -C "$INSTALL_DIR" checkout -f "$REF"
    $SUDO git -C "$INSTALL_DIR" reset --hard "origin/$REF"
  elif $SUDO git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/tags/$REF"; then
    $SUDO git -C "$INSTALL_DIR" checkout -f "tags/$REF"
  else
    $SUDO git -C "$INSTALL_DIR" checkout -f "$REF"
  fi

  # Runtime dosyalarını koru
  $SUDO git -C "$INSTALL_DIR" clean -fd \
    -e server/.env \
    -e server/data \
    -e server/data/*
}

generate_env_if_missing() {
  local env_file="$INSTALL_DIR/server/.env"
  local example="$INSTALL_DIR/server/.env.example"

  if [[ -f "$env_file" ]]; then
    warn "server/.env mevcut, üzerine yazmıyorum."
    return 0
  fi
  [[ -f "$example" ]] || die ".env.example yok: $example"

  log "server/.env oluşturuluyor (random secrets)..."
  local API_KEY PANEL_PASS
  API_KEY="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
  PANEL_PASS="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)"

  sed "s/^YEMEK_API_KEY=.*/YEMEK_API_KEY=${API_KEY}/" "$example" \
    | sed "s/^PANEL_PASS=.*/PANEL_PASS=${PANEL_PASS}/" \
    > "/tmp/yemek_env.$$"

  $SUDO mv "/tmp/yemek_env.$$" "$env_file"
  $SUDO chmod 600 "$env_file" || true

  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW} IMPORTANT: Save these credentials!${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "Panel User: ${GREEN}admin${NC}"
  echo -e "Panel Password: ${GREEN}${PANEL_PASS}${NC}"
  echo -e "API Key: ${GREEN}${API_KEY}${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

start_containers() {
  local DOCKER_BIN; DOCKER_BIN="$(detect_docker_cmd)"
  log "Docker Compose başlatılıyor..."

  cd "$INSTALL_DIR/server"
  export PORT_BIND HTTP_PORT HTTPS_PORT

  if [[ "$ENABLE_NGINX" == "1" ]]; then
    log "Mode: Server + Docker Nginx"
    $DOCKER_BIN compose -f docker-compose.yml -f ../docker-compose.nginx.yml up -d --build --remove-orphans
  else
    log "Mode: Server only"
    $DOCKER_BIN compose -f docker-compose.yml up -d --build --remove-orphans
  fi
}

wait_for_health() {
  local bind="$PORT_BIND"
  local ip="127.0.0.1"
  local hostport="8787"

  if [[ "$bind" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):([0-9]+):([0-9]+)$ ]]; then
    ip="${BASH_REMATCH[1]}"
    hostport="${BASH_REMATCH[2]}"
    [[ "$ip" == "0.0.0.0" ]] && ip="127.0.0.1"
  elif [[ "$bind" =~ ^([0-9]+):([0-9]+)$ ]]; then
    hostport="${BASH_REMATCH[1]}"
  fi

  log "Health check bekleniyor: http://${ip}:${hostport}/health"
  local timeout=45 elapsed=0
  while (( elapsed < timeout )); do
    if curl -fsS "http://${ip}:${hostport}/health" >/dev/null 2>&1; then
      log "Service ready."
      return 0
    fi
    sleep 2
    elapsed=$((elapsed+2))
  done

  warn "Health check timeout."
  warn "Loglar: (server klasöründe) docker compose logs --tail=200"
  return 1
}

print_success() {
  local server_ip
  server_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  [[ -n "$server_ip" ]] || server_ip="<SERVER_IP>"

  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN} ✓ YemekBildirim kuruldu (REF=${REF})${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "URL:"
  if [[ "$ENABLE_NGINX" == "1" ]]; then
    echo " Panel:  http://${server_ip}:${HTTP_PORT}/panel"
    echo " Health: http://${server_ip}:${HTTP_PORT}/health"
  else
    echo " Panel:  http://${server_ip}:8787/panel"
    echo " Health: http://${server_ip}:8787/health"
  fi
  echo ""
}

main() {
  echo "=========================================="
  echo " YemekBildirim Installation"
  echo "=========================================="

  if ! need_cmd curl || ! need_cmd git; then
    if need_cmd apt-get; then
      install_deps_apt
    else
      die "curl/git eksik ve apt-get yok. Manuel kurulum gerekli."
    fi
  fi

  if ! need_cmd docker; then
    warn "Docker yok, kuruluyor..."
    install_docker_deb_ubuntu
  fi

  setup_repo
  generate_env_if_missing
  start_containers
  wait_for_health || true
  print_success
}

main "$@"
