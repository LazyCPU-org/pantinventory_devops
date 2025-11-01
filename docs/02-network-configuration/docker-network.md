# Docker Network Configuration

## Overview

This guide explains the Docker network setup for PantInventory. All containers communicate through a dedicated bridge network.

---

## Why a Separate Network?

**Benefits:**
- ✅ **Isolation**: Applications can't access containers outside the network
- ✅ **DNS**: Containers can communicate by name (e.g., `backend`, `frontend`)
- ✅ **Security**: Network traffic doesn't leave the VPS
- ✅ **Flexibility**: Easy to add new services to the network

---

## Network Configuration

### Network Details

| Property | Value |
|----------|-------|
| Name | `pantinventory_network` |
| Driver | bridge |
| Subnet | 172.18.0.0/16 |
| Gateway | 172.18.0.1 |
| Scope | Local to VPS |

### Automated Setup

```bash
# Run the network setup script
./scripts/02-network-setup.sh
```

### Manual Setup

```bash
# Create the network
docker network create \
  --driver bridge \
  --subnet 172.18.0.0/16 \
  --gateway 172.18.0.1 \
  pantinventory_network

# Verify creation
docker network ls | grep pantinventory_network

# Inspect network
docker network inspect pantinventory_network
```

---

## Using the Network in Applications

### In docker-compose.yml

All application `docker-compose.yml` files should include:

```yaml
version: '3.8'

services:
  your-service:
    # ... service configuration ...
    networks:
      - pantinventory_network

networks:
  pantinventory_network:
    external: true  # Important: network is created externally
```

**Key Point**: `external: true` tells Docker Compose that the network already exists and was created outside this compose file.

### Container Communication

Containers on the same network can communicate using:

**1. Container Name**
```yaml
services:
  backend:
    # Backend can be reached at: http://backend:3000
    container_name: pantinventory_backend

  frontend:
    # Frontend can be reached at: http://frontend:80
    container_name: pantinventory_frontend
    environment:
      API_URL: http://backend:3000  # Use container name
```

**2. Service Name** (if no container_name specified)
```yaml
services:
  postgres:
    # Can be reached at: postgres:5432
    image: postgres:16
    # No container_name, so use service name

  app:
    environment:
      DB_HOST: postgres  # Use service name
```

---

## Network Topology

```
pantinventory_network (172.18.0.0/16)
│
├── nginx-proxy-manager (172.18.0.x)
│   └── Exposes: 80, 443 to internet
│
├── frontend (172.18.0.x)
│   └── Internal only, accessed via nginx
│
├── backend (172.18.0.x)
│   └── Internal only, accessed via nginx
│
└── database (172.18.0.x)
    └── Internal only, accessed by backend
```

---

## Security Considerations

### Network Isolation

- ✅ Only nginx-proxy-manager exposes ports to the internet
- ✅ Backend and database are NOT directly accessible from internet
- ✅ Frontend is NOT directly accessible (served through nginx)
- ✅ Communication between containers is encrypted at application level if needed

### Firewall Configuration

The VPS firewall (UFW) configuration:

```bash
# Only these ports open to internet
sudo ufw allow 80/tcp   # HTTP (nginx-proxy-manager)
sudo ufw allow 443/tcp  # HTTPS (nginx-proxy-manager)
sudo ufw allow 22/tcp   # SSH

# Database port NOT exposed to internet
# Backend port NOT exposed to internet
```

---

## Troubleshooting

### Network not found

**Problem**: `docker-compose up` fails with "network not found"

**Solution**:
```bash
# Check if network exists
docker network ls | grep pantinventory_network

# If missing, create it
./scripts/02-network-setup.sh
```

### Containers can't communicate

**Problem**: Backend can't connect to database

**Solution**:
```bash
# 1. Verify both containers are on the network
docker network inspect pantinventory_network

# 2. Check container names
docker ps --format "{{.Names}}"

# 3. Use correct hostname (container name or service name)
# In backend code: DB_HOST=postgres (not localhost!)
```

### Cannot remove network

**Problem**: `docker network rm` fails - "network has active endpoints"

**Solution**:
```bash
# Find containers using the network
docker network inspect pantinventory_network -f '{{range .Containers}}{{.Name}} {{end}}'

# Stop those containers first
docker stop container1 container2

# Then remove network
docker network rm pantinventory_network
```

---

## Network Management Commands

```bash
# List all networks
docker network ls

# Inspect network (see connected containers)
docker network inspect pantinventory_network

# See which containers are on the network
docker network inspect pantinventory_network \
  --format '{{range .Containers}}{{.Name}} {{end}}'

# Remove network (only if no containers attached)
docker network rm pantinventory_network

# Recreate network
./scripts/02-network-setup.sh
```

---

## Advanced: Custom Subnet

If you need to change the subnet (e.g., conflicts with existing network):

```bash
# Remove existing network (stop containers first!)
docker network rm pantinventory_network

# Create with custom subnet
docker network create \
  --driver bridge \
  --subnet 172.19.0.0/16 \
  --gateway 172.19.0.1 \
  pantinventory_network
```

**Warning**: Changing the subnet requires updating any hardcoded IPs in your application configuration.

---

## Summary

- ✅ Network name: `pantinventory_network`
- ✅ All containers must join this network
- ✅ Use `external: true` in docker-compose.yml
- ✅ Containers communicate by name
- ✅ Only nginx-proxy-manager exposes ports to internet
