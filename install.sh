#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/alemgir0/yemekbildirim.git"
INSTALL_DIR="/opt/yemekbildirim"
COMPOSE_CMD=""
DOCKER_RUN=""   # "" or "sudo"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

say() { echo -e "$*"; }

echo "=========================================="
echo "  YemekBildirim Installation"
echo "=========================================="
echo ""

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_git() {
  if need_cmd git; then return; fi
  if need_cmd apt-get; then
    say "${YELLOW}Git not found, installing...${NC}"
    sudo apt-get update -qq
    sudo apt-get install -y -qq git
  else
    say "${RED}Error: git not found and apt-get not available. Install git manually.${NC}"
    exit 1
  fi
}

install_docker() {
  if need_cmd docker; then return; fi

  say "${YELLOW}Installing Docker Engine...${NC}"
  if need_cmd apt-get; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

    sudo systemctl start docker
    sudo systemctl enable docker
  else
    say "${RED}Error: Unsupported OS. Please install Docker manually.${NC}"
    exit 1
  fi
}

detect_docker_compose() {
  echo -n "Detecting Docker Compose... "
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
    echo -e "${GREEN}✓ Found plugin${NC}"
  elif need_cmd docker-compose; then
    COMPOSE_CMD="docker-compose"
    echo -e "${YELLOW}⚠ Using legacy docker-compose${NC}"
  else
    echo -e "${RED}✗ Not found${NC}"
    install_docker
    COMPOSE_CMD="docker compose"
  fi
}

detect_docker_privilege() {
  # if docker needs sudo, use it automatically
  if docker ps >/dev/null 2>&1; then
    DOCKER_RUN=""
  else
    DOCKER_RUN="sudo"
  fi
}

setup_repository() {
  echo -n "Setting up repository... "
  ensure_git

  if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "${YELLOW}exists${NC}"
    echo "Updating existing installation..."

    cd "$INSTALL_DIR"
    git remote set-url origin "$REPO_URL" >/dev/null 2>&1 || true
    git fetch origin --prune

    git checkout -B main origin/main
    git reset --hard origin/main

    # runtime dosyalarını KORU
    git clean -fd \
      -e server/.env \
      -e server/data \
      -e server/data/*

    echo -e "${GREEN}✓ Repository updated${NC}"
  else
    echo -e "${YELLOW}cloning${NC}"
    sudo mkdir -p "$(dirname "$INSTALL_DIR")"
    sudo git clone --quiet "$REPO_URL" "$INSTALL_DIR"

    # owner fix (safe)
    local u
    u="$(id -un)"
    sudo chown -R "$u:$u" "$INSTALL_DIR"

    cd "$INSTALL_DIR"
    git checkout -B main origin/main
    echo -e "${GREEN}✓ Repository cloned${NC}"
  fi
}

generate_env() {
  local ENV_FILE="$INSTALL_DIR/server/.env"
  local ENV_EXAMPLE="$INSTALL_DIR/server/.env.example"

  if [ -f "$ENV_FILE" ]; then
    say "${YELLOW}⚠ Using existing .env (not overwriting)${NC}"
    return
  fi

  echo "Generating environment configuration..."

  if [ ! -f "$ENV_EXAMPLE" ]; then
    say "${RED}Error: .env.example not found${NC}"
    exit 1
  fi

  local API_KEY PANEL_PASS
  API_KEY="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  PANEL_PASS="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)"

  sed "s/YEMEK_API_KEY=.*/YEMEK_API_KEY=$API_KEY/" "$ENV_EXAMPLE" | \
  sed "s/PANEL_PASS=.*/PANEL_PASS=$PANEL_PASS/" > "$ENV_FILE"

  say "${GREEN}✓ Environment configured${NC}"
  echo ""
  say "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  say "${YELLOW}  IMPORTANT: Save these credentials!${NC}"
  say "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  say "Panel User:     ${GREEN}admin${NC}"
  say "Panel Password: ${GREEN}$PANEL_PASS${NC}"
  say "API Key:        ${GREEN}$API_KEY${NC}"
  say "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  GENERATED_PANEL_PASS="$PANEL_PASS"
}

start_containers() {
  echo "Starting containers..."
  cd "$INSTALL_DIR"

  if [ "${ENABLE_NGINX:-0}" = "1" ]; then
    echo "Mode: Server + Docker Nginx"
    HTTP_PORT="${HTTP_PORT:-8080}"
    HTTPS_PORT="${HTTPS_PORT:-8443}"
    export HTTP_PORT HTTPS_PORT

    [ -f "docker-compose.nginx.yml" ] || { say "${RED}Error: docker-compose.nginx.yml not found${NC}"; exit 1; }

    $DOCKER_RUN $COMPOSE_CMD -f server/docker-compose.yml -f docker-compose.nginx.yml up -d --remove-orphans
    MAIN_PORT="$HTTP_PORT"
  else
    echo "Mode: Server only"
    $DOCKER_RUN $COMPOSE_CMD -f server/docker-compose.yml up -d --remove-orphans
    MAIN_PORT="8787"
  fi

  say "${GREEN}✓ Containers started${NC}"
}

wait_for_health() {
  echo -n "Waiting for service to be ready"
  local TIMEOUT=30 ELAPSED=0

  while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -s http://127.0.0.1:8787/health >/dev/null 2>&1; then
      echo -e " ${GREEN}✓${NC}"
      return 0
    fi
    echo -n "."
    sleep 2
    ELAPSED=$((ELAPSED + 2))
  done

  echo -e " ${RED}✗${NC}"
  say "${RED}Error: Service did not become healthy within ${TIMEOUT}s${NC}"
  echo "Troubleshooting:"
  echo "  docker logs yemek-server"
  echo "  $DOCKER_RUN docker ps -a"
  exit 1
}

print_success() {
  local SERVER_IP
  SERVER_IP="$(hostname -I | awk '{print $1}')"

  echo ""
  say "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  say "${GREEN}  ✓ YemekBildirim installed successfully!${NC}"
  say "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  echo "Access URLs:"
  if [ "${ENABLE_NGINX:-0}" = "1" ]; then
    echo "  API Health:   http://${SERVER_IP}:${MAIN_PORT}/health"
    echo "  Admin Panel:  http://${SERVER_IP}:${MAIN_PORT}/panel"
  else
    echo "  API Health:   http://${SERVER_IP}:8787/health"
    echo "  Admin Panel:  http://${SERVER_IP}:8787/panel"
  fi
  echo ""

  if [ -n "${GENERATED_PANEL_PASS:-}" ]; then
    echo "Login Credentials:"
    echo "  Username: admin"
    echo "  Password: $GENERATED_PANEL_PASS"
    echo ""
  fi

  if [ "${ENABLE_NGINX:-0}" != "1" ]; then
    echo "Optional: Enable Docker Nginx (port 8080):"
    echo "  ENABLE_NGINX=1 HTTP_PORT=8080 bash install.sh"
    echo ""
    echo "Or use existing host nginx:"
    echo "  See: nginx/conf/default.host.conf"
    echo ""
  fi

  echo "Verify:"
  echo "  $DOCKER_RUN docker ps"
  echo "  curl http://localhost:8787/health"
  echo ""
}

detect_docker_compose
detect_docker_privilege
setup_repository
generate_env
start_containers
wait_for_health
print_success

say "${GREEN}Installation complete!${NC}"
