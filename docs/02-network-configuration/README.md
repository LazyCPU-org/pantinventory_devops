# Stage 2: Network Configuration

## Overview

This stage sets up the network infrastructure for PantInventory applications to communicate securely. This includes:
- Docker network for container communication
- Nginx Proxy Manager for reverse proxy and SSL termination
- Let's Encrypt SSL certificates
- CORS configuration

**Time Estimate**: 30-45 minutes

---

## What Gets Configured

### 1. Docker Network
- **Name**: `pantinventory_network`
- **Type**: Bridge network
- **Purpose**: Allows all PantInventory containers to communicate

### 2. Nginx Proxy Manager
- **Role**: Reverse proxy and SSL termination
- **Features**: Web UI, automatic SSL, easy configuration
- **Ports**: 80 (HTTP), 443 (HTTPS), 81 (Admin UI)

### 3. SSL Certificates
- **Provider**: Let's Encrypt (free, automated)
- **Renewal**: Automatic via nginx-proxy-manager
- **Coverage**: All your domains (frontend, backend, etc.)

### 4. CORS Configuration
- **Purpose**: Allow frontend to communicate with backend API
- **Method**: Custom headers in nginx-proxy-manager

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
2. Deploy nginx-proxy-manager
3. Verify deployment

---

## Manual Setup (Step by Step)

If you prefer manual configuration, see individual guides:

1. **[Docker Network Setup](./docker-network.md)** - Create pantinventory_network
2. **[Nginx Proxy Manager](./nginx-proxy-manager.md)** - Deploy reverse proxy
3. **[SSL Certificates](./ssl-certificates.md)** - Configure Let's Encrypt
4. **[CORS Configuration](./cors-configuration.md)** - Enable frontend-backend communication

---

## Architecture Diagram

```
Internet (HTTP/HTTPS)
        ↓
   Port 80/443
        ↓
┌────────────────────────┐
│ Nginx Proxy Manager    │
│ - SSL Termination      │
│ - Reverse Proxy        │
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

### Nginx Proxy Manager

Deployed via `03-nginx-proxy-setup.sh`:

```yaml
version: '3.8'
services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    ports:
      - "80:80"
      - "443:443"
      - "81:81"
    networks:
      - pantinventory_network
```

---

## Verification

After completing this stage:

```bash
# Check Docker network exists
docker network ls | grep pantinventory_network

# Check nginx-proxy-manager is running
docker ps | grep nginx-proxy-manager

# Access admin UI
# http://YOUR_VPS_IP:81
# Default: admin@example.com / changeme
```

---

## Next Steps

Once Stage 2 is complete:

1. **Configure nginx-proxy-manager**:
   - Access admin UI at `http://YOUR_VPS_IP:81`
   - Change default password
   - Add proxy hosts for your domains

2. **Set up SSL certificates**:
   - See [SSL Certificates Guide](./ssl-certificates.md)
   - Configure Let's Encrypt for your domains

3. **Configure CORS**:
   - See [CORS Configuration Guide](./cors-configuration.md)
   - Allow frontend to access backend API

4. **Deploy Applications**:
   - Proceed to [Stage 3: Application Deployment](../03-application-deployment/README.md)

---

## Files in This Directory

- **README.md** - This file (overview)
- **docker-network.md** - Docker network details
- **nginx-proxy-manager.md** - Nginx proxy setup and configuration
- **ssl-certificates.md** - SSL certificate setup with Let's Encrypt
- **cors-configuration.md** - CORS headers configuration

---

## Summary

After completing Stage 2:
- ✅ Docker network created (`pantinventory_network`)
- ✅ Nginx Proxy Manager running (ports 80, 443, 81)
- ✅ Ready to configure SSL certificates
- ✅ Ready to configure CORS headers
- ✅ Ready to deploy applications
