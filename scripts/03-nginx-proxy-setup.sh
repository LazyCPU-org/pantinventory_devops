#!/bin/bash

###############################################################################
# PantInventory Nginx Proxy Manager Setup Script
###############################################################################
# This script deploys nginx-proxy-manager as the reverse proxy and SSL
# termination point for all pantinventory services.
#
# Run this after: 02-network-setup.sh
# Run this before: Deploying applications
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Nginx Proxy Manager Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
NETWORK_NAME="pantinventory_network"
INSTALL_DIR="/opt/nginx-proxy-manager"
CONTAINER_NAME="nginx-proxy-manager"

###############################################################################
# Check Prerequisites
###############################################################################
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

# Check if Docker network exists
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    echo -e "${RED}Error: Docker network '${NETWORK_NAME}' not found${NC}"
    echo "Please run: ./scripts/02-network-setup.sh first"
    exit 1
fi

# Check if ports 80, 443, 81 are available
for port in 80 443 81; do
    if sudo netstat -tuln | grep -q ":${port} "; then
        echo -e "${RED}Error: Port ${port} is already in use${NC}"
        echo "Please stop the service using this port first"
        exit 1
    fi
done

echo -e "${GREEN}✓ Prerequisites satisfied${NC}"
echo ""

###############################################################################
# Create Installation Directory
###############################################################################
echo -e "${YELLOW}[2/5] Creating installation directory...${NC}"

sudo mkdir -p ${INSTALL_DIR}
sudo chown -R $USER:$USER ${INSTALL_DIR}

echo -e "${GREEN}✓ Directory created: ${INSTALL_DIR}${NC}"
echo ""

###############################################################################
# Create Docker Compose Configuration
###############################################################################
echo -e "${YELLOW}[3/5] Creating docker-compose configuration...${NC}"

cat > ${INSTALL_DIR}/docker-compose.yml << 'EOF'
version: '3.8'

services:
  nginx-proxy-manager:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      # HTTP
      - '80:80'
      # HTTPS
      - '443:443'
      # Admin Web UI
      - '81:81'
    environment:
      # MySQL/MariaDB connection
      DB_MYSQL_HOST: "db"
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: "npm"
      DB_MYSQL_PASSWORD: "npm"
      DB_MYSQL_NAME: "npm"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    networks:
      - pantinventory_network
    depends_on:
      - db
    healthcheck:
      test: ["CMD", "/bin/check-health"]
      interval: 10s
      timeout: 3s

  db:
    image: 'jc21/mariadb-aria:latest'
    container_name: nginx-proxy-manager-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: 'npm'
      MYSQL_DATABASE: 'npm'
      MYSQL_USER: 'npm'
      MYSQL_PASSWORD: 'npm'
    volumes:
      - ./mysql:/var/lib/mysql
    networks:
      - pantinventory_network

networks:
  pantinventory_network:
    external: true
EOF

echo -e "${GREEN}✓ Configuration created${NC}"
echo ""

###############################################################################
# Deploy Nginx Proxy Manager
###############################################################################
echo -e "${YELLOW}[4/5] Deploying nginx-proxy-manager...${NC}"

cd ${INSTALL_DIR}
docker compose pull
docker compose up -d

echo ""
echo "Waiting for services to start..."
sleep 15

echo -e "${GREEN}✓ Nginx Proxy Manager deployed${NC}"
echo ""

###############################################################################
# Verify Deployment
###############################################################################
echo -e "${YELLOW}[5/5] Verifying deployment...${NC}"

# Check if containers are running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${GREEN}✓ Nginx Proxy Manager is running${NC}"
else
    echo -e "${RED}✗ Nginx Proxy Manager failed to start${NC}"
    echo "Check logs with: docker compose -f ${INSTALL_DIR}/docker-compose.yml logs"
    exit 1
fi

# Check if database is running
if docker ps --format '{{.Names}}' | grep -q "^nginx-proxy-manager-db$"; then
    echo -e "${GREEN}✓ Database is running${NC}"
else
    echo -e "${RED}✗ Database failed to start${NC}"
    exit 1
fi

echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Nginx Proxy Manager Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Access Information:${NC}"
echo "  Admin UI: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_VPS_IP'):81"
echo ""
echo -e "${YELLOW}Default Login Credentials:${NC}"
echo "  Email:    admin@example.com"
echo "  Password: changeme"
echo ""
echo -e "${RED}⚠ IMPORTANT: Change these credentials immediately after first login!${NC}"
echo ""
echo -e "${YELLOW}Firewall Configuration:${NC}"
echo "If you haven't already, allow these ports through your firewall:"
echo "  ${BLUE}sudo ufw allow 80/tcp${NC}   # HTTP"
echo "  ${BLUE}sudo ufw allow 443/tcp${NC}  # HTTPS"
echo "  ${BLUE}sudo ufw allow 81/tcp${NC}   # Admin UI (can be restricted to your IP)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Access the admin UI and change default credentials"
echo "  2. Configure DNS records (point domains to your VPS IP)"
echo "  3. Configure proxy hosts for your applications"
echo "  4. Set up SSL certificates (Let's Encrypt)"
echo ""
echo -e "${YELLOW}Documentation:${NC}"
echo "  Configuration guide:  ${BLUE}docs/02-network-configuration/nginx-proxy-manager.md${NC}"
echo "  SSL setup:            ${BLUE}docs/02-network-configuration/ssl-certificates.md${NC}"
echo "  CORS configuration:   ${BLUE}docs/02-network-configuration/cors-configuration.md${NC}"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  View logs:    ${BLUE}docker compose -f ${INSTALL_DIR}/docker-compose.yml logs -f${NC}"
echo "  Stop:         ${BLUE}docker compose -f ${INSTALL_DIR}/docker-compose.yml stop${NC}"
echo "  Start:        ${BLUE}docker compose -f ${INSTALL_DIR}/docker-compose.yml start${NC}"
echo "  Restart:      ${BLUE}docker compose -f ${INSTALL_DIR}/docker-compose.yml restart${NC}"
echo ""
