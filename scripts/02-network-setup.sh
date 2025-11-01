#!/bin/bash

###############################################################################
# PantInventory Network Configuration Script
###############################################################################
# This script creates the Docker network infrastructure needed for
# pantinventory services to communicate securely.
#
# Run this after: 01-server-setup (from Stage 1 docs)
# Run this before: 03-nginx-proxy-setup.sh
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}PantInventory Network Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
NETWORK_NAME="pantinventory_network"
NETWORK_SUBNET="172.18.0.0/16"
NETWORK_GATEWAY="172.18.0.1"

###############################################################################
# Check Prerequisites
###############################################################################
echo -e "${YELLOW}[1/3] Checking prerequisites...${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please complete Stage 1: Server Setup first"
    exit 1
fi

# Check if user can run Docker without sudo
if ! docker ps &> /dev/null; then
    echo -e "${RED}Error: Cannot run Docker commands${NC}"
    echo "Please ensure your user is in the docker group"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites satisfied${NC}"
echo ""

###############################################################################
# Create Docker Network
###############################################################################
echo -e "${YELLOW}[2/3] Creating Docker network...${NC}"

# Check if network already exists
if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    echo -e "${YELLOW}⚠ Network '${NETWORK_NAME}' already exists${NC}"

    read -p "Do you want to recreate it? (y/N): " RECREATE
    if [ "$RECREATE" = "y" ] || [ "$RECREATE" = "Y" ]; then
        echo "Removing existing network..."

        # Check for connected containers
        CONNECTED=$(docker network inspect ${NETWORK_NAME} -f '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")
        if [ -n "$CONNECTED" ]; then
            echo -e "${RED}Error: Network has connected containers: ${CONNECTED}${NC}"
            echo "Please stop these containers first:"
            echo "  docker stop ${CONNECTED}"
            exit 1
        fi

        docker network rm ${NETWORK_NAME}
        echo -e "${GREEN}✓ Existing network removed${NC}"
    else
        echo "Keeping existing network"
        echo ""
        echo -e "${GREEN}Network setup complete (using existing network)${NC}"
        exit 0
    fi
fi

# Create the network
docker network create \
    --driver bridge \
    --subnet ${NETWORK_SUBNET} \
    --gateway ${NETWORK_GATEWAY} \
    ${NETWORK_NAME}

echo -e "${GREEN}✓ Docker network '${NETWORK_NAME}' created${NC}"
echo ""

###############################################################################
# Verify Network Configuration
###############################################################################
echo -e "${YELLOW}[3/3] Verifying network configuration...${NC}"

# Display network details
echo -e "${BLUE}Network Details:${NC}"
docker network inspect ${NETWORK_NAME} --format '  Name: {{.Name}}'
docker network inspect ${NETWORK_NAME} --format '  Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}'
docker network inspect ${NETWORK_NAME} --format '  Gateway: {{range .IPAM.Config}}{{.Gateway}}{{end}}'
docker network inspect ${NETWORK_NAME} --format '  Driver: {{.Driver}}'

echo ""
echo -e "${GREEN}✓ Network verified${NC}"
echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Network Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Network Information:${NC}"
echo "  Name:    ${NETWORK_NAME}"
echo "  Subnet:  ${NETWORK_SUBNET}"
echo "  Gateway: ${NETWORK_GATEWAY}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Run the reverse proxy setup:"
echo "     ${BLUE}./scripts/03-nginx-proxy-setup.sh${NC}"
echo ""
echo "  2. Applications can now connect to this network by adding:"
echo "     ${BLUE}networks:${NC}"
echo "     ${BLUE}  - pantinventory_network${NC}"
echo ""
echo "     And declaring it as external:"
echo "     ${BLUE}networks:${NC}"
echo "     ${BLUE}  pantinventory_network:${NC}"
echo "     ${BLUE}    external: true${NC}"
echo ""
