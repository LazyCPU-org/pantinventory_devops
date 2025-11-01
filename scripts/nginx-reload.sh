#!/bin/bash

###############################################################################
# Nginx Safe Reload Script
###############################################################################
# This script safely reloads nginx configuration after changes
# It tests the configuration first before reloading
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NGINX_DIR="/opt/pantinventory/nginx"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Nginx Configuration Reload${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if nginx is running
if ! docker ps --format '{{.Names}}' | grep -q "^pantinventory_nginx$"; then
    echo -e "${RED}Error: Nginx is not running${NC}"
    echo "Start nginx with: docker compose -f ${NGINX_DIR}/docker-compose.yml up -d"
    exit 1
fi

# Test configuration
echo -e "${YELLOW}Testing nginx configuration...${NC}"
echo ""

if docker compose -f ${NGINX_DIR}/docker-compose.yml exec nginx nginx -t; then
    echo ""
    echo -e "${GREEN}✓ Configuration test passed${NC}"
    echo ""

    # Reload nginx
    echo -e "${YELLOW}Reloading nginx...${NC}"
    docker compose -f ${NGINX_DIR}/docker-compose.yml exec nginx nginx -s reload

    echo -e "${GREEN}✓ Nginx reloaded successfully${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}✗ Configuration test failed${NC}"
    echo -e "${YELLOW}Please fix the errors above and try again${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Reload Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
