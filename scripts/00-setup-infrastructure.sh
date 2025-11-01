#!/bin/bash

###############################################################################
# PantInventory Complete Infrastructure Setup
###############################################################################
# This master script runs all infrastructure setup steps in the correct order.
# Use this to fully provision infrastructure on your VPS.
#
# Prerequisites:
# - Fresh VPS with Ubuntu 22.04+
# - Run 01-vps-initial-setup.sh first (installs Docker, Git, etc.)
# - SSH access configured
# - User in docker group (logout/login after 01-vps-initial-setup.sh)
#
# What this script sets up:
# - Docker network for service communication
# - Nginx Proxy Manager for reverse proxy and SSL
#
# What this script does NOT do:
# - Does not deploy applications (handled by GitHub Actions)
# - Does not install system software (use 01-vps-initial-setup.sh)
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}PantInventory Infrastructure Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

###############################################################################
# Pre-flight Checks
###############################################################################
echo -e "${YELLOW}Running pre-flight checks...${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please run 01-vps-initial-setup.sh first:"
    echo "  ${BLUE}./scripts/01-vps-initial-setup.sh${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    echo "Please run 01-vps-initial-setup.sh first"
    exit 1
fi

# Check if user can run Docker without sudo
if ! docker ps &> /dev/null; then
    echo -e "${RED}Error: Cannot run Docker commands${NC}"
    echo "After running 01-vps-initial-setup.sh, you must log out and log back in"
    echo "Then run this script again"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites satisfied${NC}"
echo ""

###############################################################################
# Confirm Action
###############################################################################
echo -e "${YELLOW}This script will set up the following infrastructure:${NC}"
echo ""
echo "  1. Docker Network"
echo "     - Name: pantinventory_network"
echo "     - Purpose: Allows containers to communicate securely"
echo ""
echo "  2. Nginx Proxy Manager"
echo "     - Reverse proxy for all services"
echo "     - Automatic SSL certificate management"
echo "     - Web UI on port 81"
echo ""
echo -e "${YELLOW}Applications will be deployed separately via GitHub Actions${NC}"
echo ""

read -p "Continue with infrastructure setup? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Setup cancelled"
    exit 0
fi

echo ""

###############################################################################
# Step 1: Network Setup
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 1: Network Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ -f "$SCRIPT_DIR/02-network-setup.sh" ]; then
    bash "$SCRIPT_DIR/02-network-setup.sh"
else
    echo -e "${RED}Error: Network setup script not found${NC}"
    echo "Expected: $SCRIPT_DIR/02-network-setup.sh"
    exit 1
fi

echo ""
read -p "Press Enter to continue to next step..."
echo ""

###############################################################################
# Step 2: Nginx Proxy Manager Setup
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 2: Nginx Proxy Manager${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ -f "$SCRIPT_DIR/03-nginx-proxy-setup.sh" ]; then
    bash "$SCRIPT_DIR/03-nginx-proxy-setup.sh"
else
    echo -e "${RED}Error: Nginx proxy setup script not found${NC}"
    echo "Expected: $SCRIPT_DIR/03-nginx-proxy-setup.sh"
    exit 1
fi

echo ""

###############################################################################
# Completion Summary
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Infrastructure Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Infrastructure Status:${NC}"
echo "  ✓ Docker network:         pantinventory_network (created)"
echo "  ✓ Nginx Proxy Manager:    Running on ports 80, 443, 81"
echo ""

echo -e "${YELLOW}Your infrastructure is ready!${NC}"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Next Steps${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}1. Configure Nginx Proxy Manager${NC}"
echo ""
echo "   Access admin panel:"
echo "   ${BLUE}http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_VPS_IP'):81${NC}"
echo ""
echo "   Default credentials:"
echo "   - Email:    admin@example.com"
echo "   - Password: changeme"
echo ""
echo "   ${RED}⚠ IMPORTANT: Change these credentials immediately!${NC}"
echo ""

echo -e "${YELLOW}2. Configure Domains and SSL${NC}"
echo ""
echo "   Use Nginx Proxy Manager to:"
echo "   - Add proxy hosts for your applications"
echo "   - Configure SSL certificates (Let's Encrypt)"
echo "   - Set up CORS headers"
echo ""
echo "   Guides:"
echo "   ${BLUE}docs/02-network-configuration/nginx-proxy-manager.md${NC}"
echo "   ${BLUE}docs/02-network-configuration/ssl-certificates.md${NC}"
echo "   ${BLUE}docs/02-network-configuration/cors-configuration.md${NC}"
echo ""

echo -e "${YELLOW}3. Set up GitHub Actions Access${NC}"
echo ""
echo "   Your application repositories (backend/frontend) need SSH access to deploy."
echo "   Follow this guide:"
echo "   ${BLUE}docs/03-application-deployment/github-actions-setup.md${NC}"
echo ""

echo -e "${YELLOW}4. Deploy Your Applications${NC}"
echo ""
echo "   Once GitHub Actions access is configured, applications will deploy automatically"
echo "   when you push to their repositories."
echo ""
echo "   Reference guide for application teams:"
echo "   ${BLUE}docs/03-application-deployment/deployment-guide.md${NC}"
echo ""

echo -e "${GREEN}Your PantInventory infrastructure is fully deployed!${NC}"
echo ""
