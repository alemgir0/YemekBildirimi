#!/bin/bash
set -e

# YemekBildirim - One-Liner Install Script
# Usage: curl -fsSL <RAW_URL>/install.sh | bash
# Advanced: ENABLE_NGINX=1 HTTP_PORT=8080 bash install.sh

REPO_URL="https://github.com/yourusername/YemekBildirim.git"
INSTALL_DIR="/opt/yemekbildirim"
COMPOSE_CMD=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  YemekBildirim Installation"
echo "=========================================="
echo ""

# 1. Detect Docker Compose (plugin > legacy > install)
detect_docker_compose() {
    echo -n "Detecting Docker Compose... "
    
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        echo -e "${GREEN}✓ Found plugin${NC}"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
        echo -e "${YELLOW}⚠ Using legacy docker-compose${NC}"
    else
        echo -e "${RED}✗ Not found${NC}"
        echo "Docker Compose not found. Installing Docker..."
        install_docker
        COMPOSE_CMD="docker compose"
    fi
}

install_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "Installing Docker Engine..."
        
        # Ubuntu/Debian install
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -qq
            sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
            
            # Add Docker's official GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Setup repository
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker Engine
            sudo apt-get update -qq
            sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
            # Start and enable Docker
            sudo systemctl start docker
            sudo systemctl enable docker
            
            echo -e "${GREEN}✓ Docker installed successfully${NC}"
        else
            echo -e "${RED}Error: Unsupported OS. Please install Docker manually.${NC}"
            echo "Visit: https://docs.docker.com/engine/install/"
            exit 1
        fi
    fi
}

# 2. Clone or update repository
setup_repository() {
    echo -n "Setting up repository... "
    
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}exists${NC}"
        echo "Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull --quiet
        echo -e "${GREEN}✓ Repository updated${NC}"
    else
        echo -e "${YELLOW}cloning${NC}"
        sudo mkdir -p "$(dirname "$INSTALL_DIR")"
        sudo git clone --quiet "$REPO_URL" "$INSTALL_DIR"
        sudo chown -R $USER:$USER "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        echo -e "${GREEN}✓ Repository cloned${NC}"
    fi
}

# 3. Generate .env with random secrets
generate_env() {
    ENV_FILE="$INSTALL_DIR/server/.env"
    ENV_EXAMPLE="$INSTALL_DIR/server/.env.example"
    
    if [ -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}⚠ Using existing .env (not overwriting)${NC}"
        return
    fi
    
    echo "Generating environment configuration..."
    
    # Generate random secrets
    API_KEY=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
    PANEL_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
    
    # Read .env.example and replace values
    if [ ! -f "$ENV_EXAMPLE" ]; then
        echo -e "${RED}Error: .env.example not found${NC}"
        exit 1
    fi
    
    # Create .env with generated secrets
    sed "s/YEMEK_API_KEY=.*/YEMEK_API_KEY=$API_KEY/" "$ENV_EXAMPLE" | \
    sed "s/PANEL_PASS=.*/PANEL_PASS=$PANEL_PASS/" > "$ENV_FILE"
    
    echo -e "${GREEN}✓ Environment configured${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  IMPORTANT: Save these credentials!${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Panel User:     ${GREEN}admin${NC}"
    echo -e "Panel Password: ${GREEN}$PANEL_PASS${NC}"
    echo -e "API Key:        ${GREEN}$API_KEY${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Store for later display
    GENERATED_PANEL_PASS="$PANEL_PASS"
    GENERATED_API_KEY="$API_KEY"
}

# 4. Start containers
start_containers() {
    echo "Starting containers..."
    cd "$INSTALL_DIR"
    
    if [ "${ENABLE_NGINX}" = "1" ]; then
        echo "Mode: Server + Docker Nginx"
        HTTP_PORT="${HTTP_PORT:-8080}"
        HTTPS_PORT="${HTTPS_PORT:-8443}"
        export HTTP_PORT HTTPS_PORT
        
        # Check if docker-compose.nginx.yml exists
        if [ ! -f "docker-compose.nginx.yml" ]; then
            echo -e "${RED}Error: docker-compose.nginx.yml not found${NC}"
            exit 1
        fi
        
        $COMPOSE_CMD -f server/docker-compose.yml -f docker-compose.nginx.yml up -d --remove-orphans
        MAIN_PORT="$HTTP_PORT"
    else
        echo "Mode: Server only"
        $COMPOSE_CMD -f server/docker-compose.yml up -d --remove-orphans
        MAIN_PORT="8787"
    fi
    
    echo -e "${GREEN}✓ Containers started${NC}"
}

# 5. Wait for health check
wait_for_health() {
    echo -n "Waiting for service to be ready"
    
    TIMEOUT=30
    ELAPSED=0
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        if curl -s http://127.0.0.1:8787/health > /dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done
    
    echo -e " ${RED}✗${NC}"
    echo -e "${RED}Error: Service did not become healthy within ${TIMEOUT}s${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Check container logs:"
    echo "     docker logs yemek-server"
    echo "  2. Verify container is running:"
    echo "     docker ps -a"
    echo "  3. Check port availability:"
    echo "     netstat -tuln | grep 8787"
    exit 1
}

# 6. Print success info
print_success() {
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✓ YemekBildirim installed successfully!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ "${ENABLE_NGINX}" = "1" ]; then
        echo "Access URLs:"
        echo "  API Health:   http://${SERVER_IP}:${MAIN_PORT}/health"
        echo "  Admin Panel:  http://${SERVER_IP}:${MAIN_PORT}/panel"
        echo ""
        echo "Note: Root (/) redirects to /panel"
    else
        echo "Access URLs:"
        echo "  API Health:   http://${SERVER_IP}:8787/health"
        echo "  Admin Panel:  http://${SERVER_IP}:8787/panel"
        echo ""
    fi
    
    # Show credentials if newly generated
    if [ -n "$GENERATED_PANEL_PASS" ]; then
        echo "Login Credentials (saved above):"
        echo "  Username: admin"
        echo "  Password: $GENERATED_PANEL_PASS"
        echo ""
    fi
    
    if [ "${ENABLE_NGINX}" != "1" ]; then
        echo "Optional: Enable Docker Nginx (port 8080):"
        echo "  ENABLE_NGINX=1 HTTP_PORT=8080 bash install.sh"
        echo ""
        echo "Or use existing host nginx:"
        echo "  See: nginx/conf/default.host.conf"
        echo ""
    fi
    
    echo "Verify installation:"
    echo "  docker ps"
    echo "  curl http://localhost:8787/health"
    echo ""
}

# Main execution
detect_docker_compose
setup_repository
generate_env
start_containers
wait_for_health
print_success

echo -e "${GREEN}Installation complete!${NC}"
