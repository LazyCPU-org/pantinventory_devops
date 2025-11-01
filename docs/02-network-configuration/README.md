# Stage 2: Network Configuration

## Overview

This stage sets up the network infrastructure for PantInventory applications to communicate securely. This includes:
- Docker network for container communication
- Nginx reverse proxy for routing and SSL termination
- Let's Encrypt SSL certificates (via Certbot)
- Rate limiting and security features
- CORS configuration

**Time Estimate**: 30-45 minutes

---

## What Gets Configured

### 1. Docker Network
- **Name**: `pantinventory_network`
- **Type**: Bridge network
- **Purpose**: Allows all PantInventory containers to communicate

### 2. Nginx Reverse Proxy
- **Role**: Reverse proxy and SSL termination
- **Features**: Infrastructure as Code, automatic SSL (Certbot), rate limiting, security headers
- **Ports**: 80 (HTTP), 443 (HTTPS)

### 3. SSL Certificates
- **Provider**: Let's Encrypt (free, automated)
- **Tool**: Certbot
- **Renewal**: Automatic (every 12 hours)
- **Coverage**: All your domains (frontend, backend, etc.)

### 4. Security Features
- **Rate limiting**: Protection against abuse
- **Security headers**: X-Frame-Options, X-Content-Type-Options, etc.
- **CORS**: Allow frontend to communicate with backend API

---

## Prerequisites

Before starting this stage:

- [ ] Stage 1 completed (Docker, firewall, SSH configured)
- [ ] VPS accessible via SSH
- [ ] Domains pointing to your VPS IP (for SSL certificates)

---

## Quick Start

Run the automated setup:

```bash
# SSH to your VPS
ssh -i ~/.ssh/pantinventory_vps your-user@YOUR_VPS_IP

# Clone devops repo (if not already)
git clone https://github.com/YOUR_USERNAME/pantinventory_devops.git
cd pantinventory_devops

# Run infrastructure setup
./scripts/00-setup-infrastructure.sh
```

This will:
1. Create Docker network
2. Deploy nginx + certbot
3. Verify deployment

---

## Manual Setup (Step by Step)

If you prefer manual configuration, see individual guides (in order):

1. **[Docker Network Setup](./01-docker-network.md)** - Create pantinventory_network
2. **[Nginx Configuration](./02-nginx.md)** - Complete guide: deploy nginx, configure SSL, CORS, rate limiting, and manage all configurations

---

## Architecture Diagram

```
Internet (HTTPS only)
        ↓
   Port 80/443
        ↓
┌────────────────────────┐
│ Nginx                  │
│ - SSL Termination      │
│ - Reverse Proxy        │
│ - Rate Limiting        │
│ - Security Headers     │
│ - CORS Headers         │
└────────────────────────┘
        ↓
pantinventory_network (Docker Bridge)
        ↓
┌────────────┬────────────┬────────────┐
│  Frontend  │  Backend   │  Database  │
│ Container  │ Container  │ Container  │
└────────────┴────────────┴────────────┘
```

---

## Configuration Overview

### Docker Network

```bash
# Created by script: 02-network-setup.sh
docker network create pantinventory_network
```

Applications connect by adding to their `docker-compose.yml`:

```yaml
networks:
  pantinventory_network:
    external: true
```

### Nginx Reverse Proxy

Deployed via `03-nginx-setup.sh`:

```yaml
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    networks:
      - pantinventory_network

  certbot:
    image: certbot/certbot:latest
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt
```

All configuration files are version-controlled in your repository.

---

## Verification

After completing this stage:

```bash
# Check Docker network exists
docker network ls | grep pantinventory_network

# Check nginx is running
docker ps | grep pantinventory_nginx

# Test nginx configuration
docker compose -f /opt/pantinventory/nginx/docker-compose.yml exec nginx nginx -t

# Test HTTP access
curl -I http://YOUR_DOMAIN
```

---

## Next Steps

Once Stage 2 is complete:

1. **Configure DNS**:
   - Point your domains to your VPS IP
   - See [Nginx Guide - Step 1](./02-nginx.md#step-1-configure-dns)

2. **Obtain SSL certificates**:
   - Run `./scripts/04-ssl-setup.sh`
   - See [Nginx Guide - Step 4](./02-nginx.md#step-4-obtain-ssl-certificates)

3. **Enable HTTPS**:
   - Uncomment SSL server blocks in nginx configs
   - See [Nginx Guide - Step 5](./02-nginx.md#step-5-enable-https-configuration)

4. **Deploy Applications**:
   - Proceed to [Stage 3: Application Deployment](../03-application-deployment/README.md)

---

## Files in This Directory

- **README.md** - This file (overview)
- **01-docker-network.md** - Docker network setup (read first)
- **02-nginx.md** - Complete nginx guide (setup, SSL, CORS, configuration management)

---

## Summary

After completing Stage 2:
- ✅ Docker network created (`pantinventory_network`)
- ✅ Nginx running (ports 80, 443)
- ✅ Certbot container ready for SSL certificates
- ✅ All configuration files version-controlled
- ✅ Ready to configure DNS and SSL
- ✅ Ready to deploy applications
