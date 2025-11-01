# PantInventory DevOps Configuration

## Project Purpose

This project contains all DevOps configuration and management tools needed to deploy and maintain the PantInventory application on a VPS. It handles server security, network configuration, and containerized application orchestration.

## Architecture Overview

### Application Structure

```
/home/user/pantinventory/
├── pantinventory_devops/     # This project - DevOps configuration
├── pantinventory_frontend/   # Frontend application with Docker config
└── pantinventory_backend/    # Backend application with Docker config
```

### Deployment Components

**Three Main Docker Instances:**

1. **Database** - Persistent data storage for the backend
2. **Backend** - Application server with migration and seeding capabilities
3. **Frontend** - UI application serving the client interface

### Network Architecture

```
Internet (HTTP/HTTPS)
        ↓
Nginx Proxy Manager (nginx-proxy-manager)
├── SSL/TLS (Let's Encrypt automation)
├── Load Balancing
├── Routing
└── CORS Configuration (Frontend ↔ Backend communication)
        ↓
Internal Docker Network
├── Frontend Container
├── Backend Container
└── Database Container
```

## Key Features

### Security

- **SSH Hardening**: Server configured to allow only SSH key-based authentication (symmetric keys)
- **Network Isolation**: Applications run in isolated Docker network, not directly exposed to internet
- **Reverse Proxy Protection**: Nginx Proxy Manager acts as single entry point, shielding internal services

### Automation

- **CI/CD Pipeline**: GitHub Actions for automated deployment on code changes
- **Let's Encrypt**: Automatic SSL certificate generation and renewal via nginx-proxy-manager
- **Database Management**: Backend handles database migrations and seeding automatically
- **Container Orchestration**: Docker Compose for easy deployment and management
- **Secrets Management**: GitHub Secrets and Docker Secrets for secure credential handling

### Simplicity

- **Single Instance Architecture**: One instance of each service (sufficient for internal tool)
- **Focus**: Reliability and quick access over horizontal scaling
- **Easy Management**: nginx-proxy-manager provides web UI for proxy configuration

## Technology Stack

- **Containerization**: Docker & Docker Compose
- **Reverse Proxy**: nginx-proxy-manager
- **SSL/TLS**: Let's Encrypt (automated via nginx-proxy-manager)
- **Server OS**: Linux (VPS)
- **Authentication**: SSH key-based authentication only
- **CI/CD**: GitHub Actions
- **Secrets Management**: GitHub Secrets + Docker Secrets

## Deployment Workflow

### Quick Start

For a rapid setup, see the [Deployment Quick Start Guide](./docs/02-deployment/QUICKSTART.md).

### Detailed Stages

1. **[Stage 1: Server Setup](./docs/01-server-setup/README.md)**
   - Initial VPS provisioning
   - SSH key-based authentication configuration
   - Disable password authentication
   - Install Docker and Docker Compose
   - Configure firewall and security measures

2. **[Stage 2: Automated Deployment](./docs/02-deployment/README.md)**
   - Configure GitHub Actions workflows
   - Set up GitHub Secrets for secure credential management
   - Create automated CI/CD pipelines for backend and frontend
   - Enable automatic deployments on push to main branch
   - Configure environment-specific deployments (staging/production)

3. **Network Configuration** *(Coming soon)*
   - Create Docker network for internal communication
   - Configure nginx-proxy-manager as internet-facing service
   - Set up internal routing between containers

4. **SSL Configuration** *(Coming soon)*
   - Configure domain(s) in nginx-proxy-manager
   - Enable Let's Encrypt SSL automation
   - Set up HTTP to HTTPS redirection

5. **CORS Configuration** *(Coming soon)*
   - Configure CORS headers in nginx-proxy-manager for backend API routes
   - Allow frontend domain to access backend APIs
   - Set proper Access-Control-Allow-Origin headers
   - Configure preflight request handling (OPTIONS method)

6. **Database Access Setup** *(Coming soon)*
   - Configure SSH server for key-based authentication only
   - Add authorized users' public keys to server
   - Configure Docker network to expose database only internally
   - Document SSH tunnel setup for DBeaver/database clients
   - Optional: Configure fail2ban for additional security

## Security Considerations

### SSH Access

- Only SSH key authentication allowed
- No password-based login
- Symmetric key encryption for secure access
- SSH tunneling enabled for secure database access from authorized clients

### Network Security

- Only nginx-proxy-manager exposed on ports 80/443
- Backend and database not directly accessible from internet
- Internal Docker network for inter-service communication
- Frontend communicates with backend through nginx reverse proxy
- CORS configured to allow only authorized frontend domains
- Database accessible externally only via SSH tunnel (port forwarding)
- No direct database port exposure to public internet

### SSL/TLS

- Automatic certificate management
- HTTPS enforced for all external connections
- Let's Encrypt for trusted certificates

### Secrets Management

- **GitHub Secrets**: Store VPS SSH keys, server credentials, and deployment tokens
- **Docker Secrets**: Runtime secrets for database passwords, API keys, and application credentials
- **Environment Isolation**: Separate secrets for development, staging, and production
- **No Hardcoded Credentials**: All sensitive data managed through secure secret stores

### CORS Configuration

To enable proper frontend-to-backend communication without CORS errors, nginx-proxy-manager will be configured with:

**Required Headers:**
```nginx
Access-Control-Allow-Origin: https://yourdomain.com
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 86400
```

**Implementation Strategy:**
- **Frontend domain**: `https://app.yourdomain.com` (served by frontend container)
- **Backend API domain**: `https://api.yourdomain.com` (proxied to backend container)
- **Database**: Not exposed externally, only accessible within Docker network

**Configuration in nginx-proxy-manager:**
1. Create proxy host for frontend (`app.yourdomain.com` → frontend container)
2. Create proxy host for backend API (`api.yourdomain.com` → backend container)
3. Add custom CORS headers to backend API proxy host
4. Configure OPTIONS method handling for preflight requests
5. Ensure credentials are allowed for authenticated requests

**Benefits:**
- Frontend can make authenticated API calls to backend
- No CORS errors in browser console
- Secure cross-origin communication
- Cookie-based sessions work correctly (if using credentials)

### Secure External Database Access

For authorized users to access the database from external tools like DBeaver, TablePlus, or pgAdmin:

**Security Strategy: SSH Tunneling**

The database will NOT be exposed directly to the internet. Instead, authorized users will connect through an SSH tunnel (also known as SSH port forwarding).

**How it works:**
```
Local Machine (DBeaver)
        ↓
SSH Tunnel (encrypted)
        ↓
VPS Server (authenticated via SSH key)
        ↓
Database Container (internal Docker network)
```

**Setup Process:**

1. **Server Configuration:**
   - Database listens only on internal Docker network
   - No database port (e.g., 5432 for PostgreSQL) exposed to public internet
   - SSH server accepts only key-based authentication

2. **Client Configuration (DBeaver/TablePlus):**
   - Configure SSH tunnel in database client:
     - SSH Host: `vps_ip_address`
     - SSH Port: `22` (or custom SSH port)
     - SSH User: `authorized_user`
     - SSH Auth: Private key file (matching public key on VPS)
   - Configure database connection through tunnel:
     - Database Host: `localhost` or `127.0.0.1` (tunneled)
     - Database Port: `5432` (or mapped port)
     - Database User: `db_username`
     - Database Password: `db_password`

3. **Connection Command (Manual SSH Tunnel):**
   ```bash
   ssh -i ~/.ssh/vps_key -L 5432:database_container:5432 user@vps_host
   ```
   Then connect DBeaver to `localhost:5432`

**Security Benefits:**
- Database never exposed to public internet
- Requires both SSH key AND database credentials
- All traffic encrypted through SSH tunnel
- Easy to revoke access (remove SSH public key from VPS)
- Can use fail2ban to prevent brute force attempts
- Audit trail through SSH logs

**Authorized Users Management:**
- Add user's public SSH key to `~/.ssh/authorized_keys` on VPS
- Each developer has unique SSH key pair
- Easy to revoke individual access without affecting others
- Can use different SSH keys for different team members

**Additional Security Measures:**
- Whitelist specific IPs in SSH configuration (optional)
- Use non-standard SSH port to reduce automated attacks
- Configure fail2ban to block repeated failed attempts
- Regular rotation of database passwords
- Monitor SSH access logs for suspicious activity

## CI/CD Pipeline Architecture

### Deployment Flow

```
Developer Push to GitHub
        ↓
GitHub Actions Triggered
        ↓
Build & Test Phase
├── Run unit tests
├── Build Docker images
└── Run integration tests
        ↓
Deployment Phase (if tests pass)
├── SSH into VPS using GitHub Secrets
├── Pull latest Docker images
├── Update docker-compose configuration
├── Perform rolling deployment
└── Run database migrations (backend)
        ↓
Verification Phase
├── Health checks
└── Smoke tests
        ↓
Deployment Complete / Rollback on Failure
```

### GitHub Actions Workflows

**Frontend Repository:**
- Trigger: Push to `main` branch
- Build optimized production bundle
- Build and push Docker image
- Deploy to VPS and restart container
- Invalidate CDN cache if applicable

**Backend Repository:**
- Trigger: Push to `main` branch
- Run backend tests
- Build Docker image with dependencies
- Deploy to VPS
- Run database migrations automatically
- Execute health check endpoints

**DevOps Repository:**
- Trigger: Manual or configuration changes
- Update nginx-proxy-manager configuration
- Update Docker Compose files
- Restart affected services with zero-downtime strategy

### Required GitHub Secrets

Each repository will need these secrets configured:

- `VPS_HOST`: VPS server IP or hostname
- `VPS_USER`: SSH user for deployment
- `VPS_SSH_KEY`: Private SSH key for authentication
- `DOCKER_REGISTRY_USER`: Docker registry username (if using private registry)
- `DOCKER_REGISTRY_TOKEN`: Docker registry access token
- `DATABASE_PASSWORD`: Database root password (backend only)
- `APP_SECRET_KEY`: Application secret key (backend only)

### Docker Secrets Integration

Runtime secrets managed through Docker Swarm secrets or docker-compose secrets:

```yaml
secrets:
  db_password:
    external: true
  app_secret_key:
    external: true
  api_keys:
    external: true
```

## Future Enhancements (Optional)

### Monitoring & Observability

- **Grafana**: Backend application logs and metrics visualization
- **Frontend Monitoring**: Separate monitoring tool for frontend performance
- **Alerting**: Notification system for critical issues
- **Deployment Notifications**: Slack/Discord integration for deployment status

### Scaling (if needed)

- Horizontal scaling support for backend instances
- Load balancing across multiple instances
- Database replication/clustering

## Project Scope

### Current Focus

- Single instance deployment
- Reliability and stability
- Quick and secure access
- Simple management and maintenance

### Out of Scope (for now)

- High availability clustering
- Auto-scaling
- Multi-region deployment
- Complex monitoring dashboards

## Notes

This is an internal tool, so the architecture prioritizes:

- **Simplicity** over complexity
- **Reliability** over high availability
- **Security** over convenience
- **Ease of maintenance** over advanced features
