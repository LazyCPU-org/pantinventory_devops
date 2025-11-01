#!/bin/bash

###############################################################################
# PantInventory Nginx Setup Script
###############################################################################
# This script deploys Nginx as the reverse proxy and SSL termination point
# for all pantinventory services.
#
# Run this after: 02-network-setup.sh
# Run this before: 04-ssl-setup.sh
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Nginx Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
NETWORK_NAME="pantinventory_network"
NGINX_DIR="/opt/pantinventory/nginx"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

###############################################################################
# Check Prerequisites
###############################################################################
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"

# Check if Docker network exists
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    echo -e "${RED}Error: Docker network '${NETWORK_NAME}' not found${NC}"
    echo "Please run: ./scripts/02-network-setup.sh first"
    exit 1
fi

# Check if ports 80, 443 are available
for port in 80 443; do
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
echo -e "${YELLOW}[2/6] Creating installation directory...${NC}"

sudo mkdir -p ${NGINX_DIR}
sudo chown -R $USER:$USER ${NGINX_DIR}

echo -e "${GREEN}✓ Directory created: ${NGINX_DIR}${NC}"
echo ""

###############################################################################
# Copy Nginx Configuration Files
###############################################################################
echo -e "${YELLOW}[3/6] Copying nginx configuration files...${NC}"

# Copy entire nginx directory structure
cp -r ${PROJECT_ROOT}/nginx/* ${NGINX_DIR}/

# Create conf.d directory if it doesn't exist
mkdir -p ${NGINX_DIR}/conf.d

echo -e "${GREEN}✓ Configuration files copied${NC}"
echo ""

###############################################################################
# Setup Domain Configuration
###############################################################################
echo -e "${YELLOW}[4/6] Setting up domain configuration...${NC}"

# Check if user wants to configure domains now
read -p "Do you want to configure your domains now? (y/N): " CONFIGURE_DOMAINS

if [ "$CONFIGURE_DOMAINS" = "y" ] || [ "$CONFIGURE_DOMAINS" = "Y" ]; then
    read -p "Enter your domain (e.g., example.com): " DOMAIN

    if [ -n "$DOMAIN" ]; then
        echo -e "${BLUE}Configuring for domain: ${DOMAIN}${NC}"

        # Copy and customize frontend config
        if [ -f "${NGINX_DIR}/conf.d/app.yourdomain.store.conf.example" ]; then
            sed "s/yourdomain.store/${DOMAIN}/g" \
                ${NGINX_DIR}/conf.d/app.yourdomain.store.conf.example \
                > ${NGINX_DIR}/conf.d/app.${DOMAIN}.conf
            echo -e "${GREEN}✓ Created app.${DOMAIN}.conf${NC}"
        fi

        # Copy and customize backend config
        if [ -f "${NGINX_DIR}/conf.d/api.yourdomain.store.conf.example" ]; then
            sed "s/yourdomain.store/${DOMAIN}/g" \
                ${NGINX_DIR}/conf.d/api.yourdomain.store.conf.example \
                > ${NGINX_DIR}/conf.d/api.${DOMAIN}.conf
            echo -e "${GREEN}✓ Created api.${DOMAIN}.conf${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Skipping domain configuration${NC}"
    echo -e "${YELLOW}  You can configure domains later by copying .conf.example files${NC}"
fi

echo ""

###############################################################################
# Deploy Nginx
###############################################################################
echo -e "${YELLOW}[5/6] Deploying nginx...${NC}"

cd ${NGINX_DIR}
docker compose pull
docker compose up -d

echo ""
echo "Waiting for services to start..."
sleep 10

echo -e "${GREEN}✓ Nginx deployed${NC}"
echo ""

###############################################################################
# Verify Deployment
###############################################################################
echo -e "${YELLOW}[6/6] Verifying deployment...${NC}"

# Check if container is running
if docker ps --format '{{.Names}}' | grep -q "^pantinventory_nginx$"; then
    echo -e "${GREEN}✓ Nginx is running${NC}"
else
    echo -e "${RED}✗ Nginx failed to start${NC}"
    echo "Check logs with: docker compose -f ${NGINX_DIR}/docker-compose.yml logs"
    exit 1
fi

# Test nginx configuration
if docker compose exec nginx nginx -t > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
else
    echo -e "${RED}✗ Nginx configuration has errors${NC}"
    docker compose exec nginx nginx -t
    exit 1
fi

echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Nginx Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Configuration Details:${NC}"
echo "  Nginx directory: ${NGINX_DIR}"
echo "  Configuration:   ${NGINX_DIR}/nginx.conf"
echo "  Server blocks:   ${NGINX_DIR}/conf.d/"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. ${BLUE}Configure DNS${NC}"
echo "   Point your domains to this VPS IP:"
echo "   ${BLUE}$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_VPS_IP')${NC}"
echo ""
echo "2. ${BLUE}Obtain SSL Certificates${NC}"
echo "   Run the SSL setup script:"
echo "   ${BLUE}./scripts/04-ssl-setup.sh${NC}"
echo ""
echo "3. ${BLUE}Enable HTTPS Configuration${NC}"
echo "   After obtaining certificates:"
echo "   - Edit ${NGINX_DIR}/conf.d/*.conf"
echo "   - Uncomment the SSL server blocks"
echo "   - Reload: ${BLUE}./scripts/nginx-reload.sh${NC}"
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo "  View logs:       ${BLUE}docker compose -f ${NGINX_DIR}/docker-compose.yml logs -f${NC}"
echo "  Reload config:   ${BLUE}./scripts/nginx-reload.sh${NC}"
echo "  Stop nginx:      ${BLUE}docker compose -f ${NGINX_DIR}/docker-compose.yml stop${NC}"
echo "  Start nginx:     ${BLUE}docker compose -f ${NGINX_DIR}/docker-compose.yml start${NC}"
echo ""

echo -e "${YELLOW}Documentation:${NC}"
echo "  Nginx guide:     ${BLUE}docs/02-network-configuration/nginx.md${NC}"
echo "  SSL setup:       ${BLUE}docs/02-network-configuration/ssl-certificates.md${NC}"
echo ""
