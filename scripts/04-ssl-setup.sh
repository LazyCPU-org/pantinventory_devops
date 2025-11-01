#!/bin/bash

###############################################################################
# PantInventory SSL Certificate Setup Script
###############################################################################
# This script obtains SSL certificates from Let's Encrypt using Certbot
#
# Prerequisites:
# - Nginx deployed and running (03-nginx-setup.sh)
# - DNS configured (domains pointing to VPS IP)
# - Ports 80 and 443 open in firewall
#
# Run this after: 03-nginx-setup.sh
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SSL Certificate Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
NGINX_DIR="/opt/pantinventory/nginx"

###############################################################################
# Check Prerequisites
###############################################################################
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

# Check if nginx is running
if ! docker ps --format '{{.Names}}' | grep -q "^pantinventory_nginx$"; then
    echo -e "${RED}Error: Nginx is not running${NC}"
    echo "Please run: ./scripts/03-nginx-setup.sh first"
    exit 1
fi

# Check if ports are accessible
for port in 80 443; do
    if ! sudo netstat -tuln | grep -q ":${port}.*LISTEN"; then
        echo -e "${RED}Error: Port ${port} is not listening${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✓ Prerequisites satisfied${NC}"
echo ""

###############################################################################
# Get User Input
###############################################################################
echo -e "${YELLOW}[2/5] Gathering certificate information...${NC}"
echo ""

# Get email
read -p "Enter your email address (for Let's Encrypt notifications): " EMAIL

if [ -z "$EMAIL" ]; then
    echo -e "${RED}Error: Email is required${NC}"
    exit 1
fi

# Get domains
echo ""
echo -e "${YELLOW}Enter the domains you want to secure (one per line, empty line to finish):${NC}"
echo -e "${BLUE}Example: app.example.com${NC}"
echo ""

DOMAINS=()
while true; do
    read -p "Domain: " domain
    if [ -z "$domain" ]; then
        break
    fi
    DOMAINS+=("$domain")
done

if [ ${#DOMAINS[@]} -eq 0 ]; then
    echo -e "${RED}Error: At least one domain is required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}You entered the following domains:${NC}"
for domain in "${DOMAINS[@]}"; do
    echo "  - $domain"
done
echo ""

read -p "Continue with certificate request? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Certificate request cancelled"
    exit 0
fi

echo ""

###############################################################################
# Verify DNS Configuration
###############################################################################
echo -e "${YELLOW}[3/5] Verifying DNS configuration...${NC}"

VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")

if [ -z "$VPS_IP" ]; then
    echo -e "${YELLOW}⚠ Could not detect VPS IP automatically${NC}"
    read -p "Enter your VPS IP address: " VPS_IP
fi

echo -e "${BLUE}VPS IP: ${VPS_IP}${NC}"
echo ""

ALL_DNS_VALID=true

for domain in "${DOMAINS[@]}"; do
    echo -n "Checking DNS for ${domain}... "

    RESOLVED_IP=$(dig +short $domain | tail -n1)

    if [ "$RESOLVED_IP" = "$VPS_IP" ]; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "${YELLOW}  Expected: ${VPS_IP}${NC}"
        echo -e "${YELLOW}  Got:      ${RESOLVED_IP}${NC}"
        ALL_DNS_VALID=false
    fi
done

echo ""

if [ "$ALL_DNS_VALID" = false ]; then
    echo -e "${YELLOW}⚠ Some domains have incorrect DNS configuration${NC}"
    echo ""
    read -p "Continue anyway? (y/N): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        echo "Certificate request cancelled"
        echo ""
        echo -e "${YELLOW}Please configure your DNS and try again:${NC}"
        echo "  1. Log in to your domain registrar (e.g., Namecheap)"
        echo "  2. Add A records pointing to: ${VPS_IP}"
        echo "  3. Wait for DNS propagation (5-10 minutes)"
        echo "  4. Run this script again"
        exit 0
    fi
fi

echo ""

###############################################################################
# Request SSL Certificates
###############################################################################
echo -e "${YELLOW}[4/5] Requesting SSL certificates...${NC}"
echo ""

# Build domain arguments for certbot
DOMAIN_ARGS=""
for domain in "${DOMAINS[@]}"; do
    DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
done

# Request certificate
echo -e "${BLUE}Requesting certificate from Let's Encrypt...${NC}"
echo ""

cd ${NGINX_DIR}

if docker compose run --rm certbot certonly \
    --webroot \
    -w /var/www/certbot \
    $DOMAIN_ARGS \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --non-interactive; then

    echo ""
    echo -e "${GREEN}✓ Certificates obtained successfully!${NC}"
else
    echo ""
    echo -e "${RED}✗ Failed to obtain certificates${NC}"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo "  1. DNS not properly configured (check with: dig yourdomain.com)"
    echo "  2. Port 80 not accessible from internet (check firewall)"
    echo "  3. Domain already has rate limit (5 certs/week)"
    echo ""
    echo "Check logs above for specific error"
    exit 1
fi

echo ""

###############################################################################
# Enable HTTPS Configuration
###############################################################################
echo -e "${YELLOW}[5/5] Configuration next steps...${NC}"
echo ""

echo -e "${YELLOW}Certificates have been obtained!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. ${BLUE}Enable HTTPS in nginx configuration${NC}"
echo "   Edit your domain configuration files:"
for domain in "${DOMAINS[@]}"; do
    CONF_FILE="${NGINX_DIR}/conf.d/${domain}.conf"
    if [ -f "$CONF_FILE" ]; then
        echo "   ${BLUE}vim ${CONF_FILE}${NC}"
    fi
done
echo ""
echo "   Uncomment the HTTPS server blocks (the sections marked with #)"
echo ""

echo "2. ${BLUE}Reload nginx${NC}"
echo "   After enabling HTTPS blocks:"
echo "   ${BLUE}./scripts/nginx-reload.sh${NC}"
echo ""

echo "3. ${BLUE}Test your domains${NC}"
echo "   Visit your domains in a browser:"
for domain in "${DOMAINS[@]}"; do
    echo "   ${BLUE}https://${domain}${NC}"
done
echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ SSL Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Certificate Details:${NC}"
echo "  Email:       $EMAIL"
echo "  Domains:"
for domain in "${DOMAINS[@]}"; do
    echo "    - $domain"
done
echo "  Location:    /etc/letsencrypt/live/${DOMAINS[0]}/"
echo "  Renewal:     Automatic (every 12 hours)"
echo ""

echo -e "${YELLOW}Certificate Files:${NC}"
echo "  fullchain.pem   - Full certificate chain"
echo "  privkey.pem     - Private key"
echo "  cert.pem        - Certificate only"
echo "  chain.pem       - Chain only"
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo "  List certificates:  ${BLUE}docker compose -f ${NGINX_DIR}/docker-compose.yml run --rm certbot certificates${NC}"
echo "  Renew certificates: ${BLUE}docker compose -f ${NGINX_DIR}/docker-compose.yml run --rm certbot renew${NC}"
echo "  Test renewal:       ${BLUE}docker compose -f ${NGINX_DIR}/docker-compose.yml run --rm certbot renew --dry-run${NC}"
echo ""
