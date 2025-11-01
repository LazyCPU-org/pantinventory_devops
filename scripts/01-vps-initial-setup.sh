#!/bin/bash

###############################################################################
# PantInventory VPS Prerequisites Setup
###############################################################################
# This script installs required software and performs basic VPS configuration
# Run this ONCE on a fresh VPS before infrastructure setup
#
# What this script does:
# - Installs Git, Docker, Docker Compose
# - Configures Docker to run without sudo
# - Sets up basic security (UFW firewall)
# - Prepares system for infrastructure deployment
#
# What this script does NOT do:
# - Does not create Docker networks (use 02-network-setup.sh)
# - Does not deploy nginx-proxy-manager (use 03-nginx-proxy-setup.sh)
# - Does not clone application repositories (handled by GitHub Actions)
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}PantInventory VPS Prerequisites Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

###############################################################################
# 1. System Update
###############################################################################
echo -e "${YELLOW}[1/6] Updating system packages...${NC}"

sudo apt update
sudo apt upgrade -y

echo -e "${GREEN}✓ System updated${NC}"
echo ""

###############################################################################
# 2. Install Essential Tools
###############################################################################
echo -e "${YELLOW}[2/6] Installing essential tools...${NC}"

sudo apt install -y \
    git \
    curl \
    wget \
    vim \
    nano \
    ufw \
    fail2ban \
    ca-certificates \
    gnupg \
    lsb-release

echo -e "${GREEN}✓ Essential tools installed${NC}"
echo ""

###############################################################################
# 3. Install Docker
###############################################################################
echo -e "${YELLOW}[3/6] Installing Docker...${NC}"

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠ Docker is already installed${NC}"
    docker --version
else
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo -e "${GREEN}✓ Docker installed${NC}"
fi

echo ""

###############################################################################
# 4. Configure Docker
###############################################################################
echo -e "${YELLOW}[4/6] Configuring Docker...${NC}"

# Add current user to docker group
if ! groups $USER | grep -q docker; then
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓ User added to docker group${NC}"
    echo -e "${YELLOW}⚠ You may need to log out and back in for group changes to take effect${NC}"
else
    echo -e "${YELLOW}⚠ User already in docker group${NC}"
fi

# Enable Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Verify Docker installation
docker --version
docker compose version

echo -e "${GREEN}✓ Docker configured${NC}"
echo ""

###############################################################################
# 5. Configure Firewall
###############################################################################
echo -e "${YELLOW}[5/6] Configuring firewall (UFW)...${NC}"

# Check if UFW is already enabled
if sudo ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}⚠ UFW is already enabled${NC}"
else
    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH (IMPORTANT!)
    sudo ufw allow 22/tcp comment 'SSH'

    # Allow HTTP and HTTPS for nginx-proxy-manager
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'

    # Enable UFW
    echo "y" | sudo ufw enable

    echo -e "${GREEN}✓ Firewall configured${NC}"
fi

# Show firewall status
sudo ufw status numbered

echo ""

###############################################################################
# 6. Configure Fail2Ban
###############################################################################
echo -e "${YELLOW}[6/6] Configuring Fail2Ban...${NC}"

# Check if Fail2Ban is running
if sudo systemctl is-active --quiet fail2ban; then
    echo -e "${YELLOW}⚠ Fail2Ban is already running${NC}"
else
    # Create local jail configuration
    if [ ! -f /etc/fail2ban/jail.local ]; then
        sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    fi

    # Enable and start Fail2Ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban

    echo -e "${GREEN}✓ Fail2Ban configured${NC}"
fi

echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ VPS Prerequisites Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Installed Software:${NC}"
echo "  ✓ Git:              $(git --version | head -n1)"
echo "  ✓ Docker:           $(docker --version)"
echo "  ✓ Docker Compose:   $(docker compose version)"
echo "  ✓ UFW:              $(sudo ufw version | head -n1)"
echo "  ✓ Fail2Ban:         Enabled"
echo ""

echo -e "${YELLOW}Security Configuration:${NC}"
echo "  ✓ Firewall (UFW):   Active (ports 22, 80, 443 open)"
echo "  ✓ Fail2Ban:         Running"
echo "  ✓ Docker:           User added to docker group"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. ${RED}IMPORTANT:${NC} Log out and log back in for docker group changes to take effect:"
echo "   ${BLUE}exit${NC}"
echo "   ${BLUE}ssh $USER@$(hostname -I | awk '{print $1}')${NC}"
echo ""
echo "2. Run the infrastructure setup scripts:"
echo "   ${BLUE}./scripts/02-network-setup.sh${NC}      # Create Docker network"
echo "   ${BLUE}./scripts/03-nginx-proxy-setup.sh${NC}  # Deploy nginx-proxy-manager"
echo ""
echo "   Or run all infrastructure setup at once:"
echo "   ${BLUE}./scripts/setup-infrastructure.sh${NC}"
echo ""
echo "3. Configure GitHub Actions access for your applications:"
echo "   ${BLUE}See: docs/04-github-actions-access/README.md${NC}"
echo ""

echo -e "${GREEN}Your VPS is now ready for infrastructure deployment!${NC}"
echo ""
