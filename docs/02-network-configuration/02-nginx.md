# Nginx Configuration

## Overview

Nginx acts as the reverse proxy and SSL termination point for all PantInventory applications. It provides:
- SSL/TLS termination (HTTPS → HTTP)
- Domain-based routing
- Automatic SSL certificate management (via Certbot)
- Rate limiting and security
- Load balancing capabilities
- Infrastructure as Code (all configs version-controlled)

---

## Architecture: HTTPS External, HTTP Internal

```
Internet (HTTPS only)
        ↓
     Port 443
        ↓
┌─────────────────────────────┐
│  Nginx                      │
│  - SSL Termination          │
│  - HTTPS → HTTP conversion  │
│  - Domain routing           │
│  - Rate limiting            │
│  - Security headers         │
└─────────────────────────────┘
        ↓
   HTTP (unencrypted, internal Docker network)
        ↓
┌──────────────┬──────────────┐
│  Frontend    │  Backend     │
│  (port 80)   │  (port 3000) │
└──────────────┴──────────────┘
```

**Why this architecture?**
- ✅ **Performance**: No SSL overhead inside internal network
- ✅ **Security**: External traffic encrypted, internal network isolated
- ✅ **Simplicity**: Applications don't need SSL certificates
- ✅ **Centralized SSL**: Manage all certificates in one place
- ✅ **Infrastructure as Code**: All configurations version-controlled

---

## Domain Strategy

### Recommended Setup

Use **subdomains** for your application, leaving the root domain free:

```
app.yourdomain.store       → Frontend (PantInventory app)
api.yourdomain.store       → Backend API
yourdomain.store           → Landing page (can be on Cloudflare)
www.yourdomain.store       → Landing page (redirect to root)
```

**Benefits:**
- ✅ Root domain free for marketing/landing page
- ✅ App isolated on subdomain
- ✅ Can move landing page to Cloudflare later
- ✅ Professional separation of concerns

---

## Step-by-Step Setup

### Step 1: Configure DNS

**Before deploying nginx**, point your domains to your VPS.

#### Get Your VPS IP

```bash
# On your VPS
curl ifconfig.me
```

#### Configure DNS in Namecheap

1. Log in to Namecheap
2. Go to **Domain List** → Your domain → **Manage**
3. Go to **Advanced DNS** tab
4. Add these records:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A Record | `app` | `YOUR_VPS_IP` | Automatic |
| A Record | `api` | `YOUR_VPS_IP` | Automatic |

**Result:**
- `app.yourdomain.store` points to your VPS
- `api.yourdomain.store` points to your VPS
- `yourdomain.store` (root) is FREE for Cloudflare

#### Verify DNS Propagation

```bash
# Wait 5-10 minutes, then check
dig app.yourdomain.store +short
# Should show YOUR_VPS_IP

dig api.yourdomain.store +short
# Should show YOUR_VPS_IP
```

**Note**: DNS propagation can take up to 24 hours, but usually happens in minutes.

---

### Step 2: Customize Nginx Configuration Files

Before deploying, customize the configuration files for your domain.

#### Navigate to Nginx Directory

```bash
cd pantinventory_devops/nginx/conf.d
```

#### Copy Example Configurations

```bash
cp app.yourdomain.store.conf.example app.yourdomain.store.conf
cp api.yourdomain.store.conf.example api.yourdomain.store.conf
```

#### Replace Domain Placeholders

**Option A: Using sed (automated)**

```bash
# Replace yourdomain.store with your actual domain
sed -i 's/yourdomain.store/example.com/g' app.yourdomain.store.conf
sed -i 's/yourdomain.store/example.com/g' api.yourdomain.store.conf
```

**Option B: Manual editing**

```bash
# Edit each file
vim app.yourdomain.store.conf
vim api.yourdomain.store.conf

# Replace all instances of 'yourdomain.store' with your actual domain
# Example: app.yourdomain.store → app.example.com
```

#### Understanding the Configuration Files

Each configuration file has two main sections:

1. **HTTP server block** (lines 8-19)
   - Listens on port 80
   - Handles Let's Encrypt challenges
   - Redirects all other traffic to HTTPS
   - **This section is already active**

2. **HTTPS server block** (lines 21-70)
   - Listens on port 443
   - Serves your application over SSL
   - **This section is commented out initially** (starts with `#`)
   - You'll uncomment this after obtaining SSL certificates

**For now**, leave the HTTPS sections commented out. We'll enable them in Step 4.

---

### Step 3: Deploy Nginx

Now deploy nginx with your customized configuration.

#### Automated Deployment

```bash
cd pantinventory_devops
./scripts/03-nginx-setup.sh
```

The script will:
1. Check prerequisites (Docker network exists, ports available)
2. Create `/opt/pantinventory/nginx/` directory
3. Copy all nginx configuration files from your repo
4. Deploy nginx + certbot containers via Docker Compose
5. Verify nginx is running

#### Manual Deployment

If you prefer to understand each step:

```bash
# Create installation directory
sudo mkdir -p /opt/pantinventory/nginx
sudo chown -R $USER:$USER /opt/pantinventory/nginx

# Copy nginx configuration files
cp -r pantinventory_devops/nginx/* /opt/pantinventory/nginx/

# Deploy with Docker Compose
cd /opt/pantinventory/nginx
docker compose pull
docker compose up -d

# Verify deployment
docker ps | grep pantinventory_nginx
docker compose exec nginx nginx -t
```

#### Verify Deployment

```bash
# Check nginx is running
docker ps | grep pantinventory_nginx

# Test configuration
docker compose -f /opt/pantinventory/nginx/docker-compose.yml exec nginx nginx -t

# Check logs
docker logs pantinventory_nginx

# Test HTTP access (should work, but will show nginx default or 502 if apps not deployed)
curl -I http://app.yourdomain.store
```

At this point:
- ✅ Nginx is running
- ✅ HTTP (port 80) is active
- ✅ Let's Encrypt challenge endpoint is ready
- ❌ HTTPS (port 443) is NOT yet configured

---

### Step 4: Obtain SSL Certificates

Now that nginx is running and DNS is configured, request SSL certificates.

#### Automated SSL Setup

```bash
cd pantinventory_devops
./scripts/04-ssl-setup.sh
```

The script will:
1. Check prerequisites (nginx running, ports accessible)
2. Prompt for your email address (for Let's Encrypt notifications)
3. Prompt for domains to secure (e.g., app.example.com, api.example.com)
4. Verify DNS configuration
5. Request certificates from Let's Encrypt using Certbot
6. Provide instructions for enabling HTTPS

#### Manual SSL Setup

If you prefer manual control:

```bash
cd /opt/pantinventory/nginx

# Request certificate for frontend
docker compose run --rm certbot certonly \
  --webroot \
  -w /var/www/certbot \
  -d app.yourdomain.store \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email

# Request certificate for backend
docker compose run --rm certbot certonly \
  --webroot \
  -w /var/www/certbot \
  -d api.yourdomain.store \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email
```

#### How SSL Verification Works

1. Certbot places a challenge file in `/var/www/certbot/.well-known/acme-challenge/`
2. Let's Encrypt requests `http://app.yourdomain.store/.well-known/acme-challenge/XXXXX`
3. Nginx serves the file (this is why port 80 must be open)
4. Let's Encrypt verifies you control the domain
5. Certificate is issued and stored in `/etc/letsencrypt/live/app.yourdomain.store/`

#### Verify SSL Certificates

```bash
# List all certificates
docker compose -f /opt/pantinventory/nginx/docker-compose.yml run --rm certbot certificates

# Check certificate details
sudo ls -la /etc/letsencrypt/live/
```

You should see directories for each domain with these files:
- `fullchain.pem` - Full certificate chain (use this in nginx)
- `privkey.pem` - Private key (use this in nginx)
- `cert.pem` - Certificate only
- `chain.pem` - Chain only

---

### Step 5: Enable HTTPS Configuration

Now that you have SSL certificates, enable the HTTPS server blocks.

#### Edit Configuration Files

```bash
cd /opt/pantinventory/nginx/conf.d

# Edit frontend configuration
vim app.yourdomain.store.conf
```

Find the HTTPS server block (starting around line 21) and **uncomment all lines**:

**Before:**
```nginx
# HTTPS - Main frontend configuration
# UNCOMMENT THIS BLOCK AFTER OBTAINING SSL CERTIFICATES
#server {
#    listen 443 ssl http2;
#    ...
#}
```

**After:**
```nginx
# HTTPS - Main frontend configuration
server {
    listen 443 ssl http2;
    ...
}
```

Repeat for backend configuration:

```bash
vim api.yourdomain.store.conf
# Uncomment the HTTPS server block
```

#### Test and Reload Nginx

```bash
# Test configuration for syntax errors
docker compose -f /opt/pantinventory/nginx/docker-compose.yml exec nginx nginx -t

# If test passes, reload nginx
cd pantinventory_devops
./scripts/nginx-reload.sh
```

#### Verify HTTPS is Working

```bash
# Test HTTPS access
curl -I https://app.yourdomain.store
curl -I https://api.yourdomain.store

# Should show:
# HTTP/2 200 (or 502 if apps not deployed yet, but SSL should work)

# Test HTTP redirect
curl -I http://app.yourdomain.store
# Should show: HTTP/1.1 301 Moved Permanently
# Location: https://app.yourdomain.store/
```

**Visit in browser:**
- https://app.yourdomain.store (should show lock icon)
- https://api.yourdomain.store (should show lock icon)

---

### Step 6: Enable HSTS (Optional, Recommended)

After confirming HTTPS works correctly for a few days, enable HSTS for added security.

#### What is HSTS?

HTTP Strict Transport Security (HSTS) tells browsers to **always** use HTTPS for your domain, even if the user types `http://`.

**Warning**: Only enable after confirming SSL works. HSTS can lock you out if SSL fails.

#### Enable HSTS

Edit your configuration files:

```bash
cd /opt/pantinventory/nginx/conf.d
vim app.yourdomain.store.conf
```

Find this line (around line 40):

```nginx
# add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

Uncomment it:

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

Repeat for `api.yourdomain.store.conf`.

Reload nginx:

```bash
cd pantinventory_devops
./scripts/nginx-reload.sh
```

---

## Configuration Files Explained

### Directory Structure

```
/opt/pantinventory/nginx/
├── docker-compose.yml          # Nginx + Certbot containers
├── nginx.conf                  # Main nginx configuration
├── conf.d/                     # Server block configurations
│   ├── app.yourdomain.store.conf
│   └── api.yourdomain.store.conf
└── snippets/                   # Reusable config snippets
    ├── ssl-params.conf         # SSL best practices
    ├── proxy-params.conf       # Proxy settings
    └── security-headers.conf   # Security headers
```

### Main Configuration (nginx.conf)

Global settings including:
- Worker processes and connections
- Logging configuration
- Gzip compression
- SSL defaults
- **Rate limiting zones** (defined globally)

### Server Blocks (conf.d/*.conf)

Individual configurations for each domain/subdomain.

**Frontend (app.yourdomain.store.conf):**
- Rate limiting: 20 requests/second, burst 40
- Static asset caching (1 year)
- Security headers
- Proxies to `pantinventory_frontend:80`

**Backend API (api.yourdomain.store.conf):**
- Stricter rate limiting: 10 requests/second, burst 20
- CORS headers (allows frontend access)
- No caching for API responses
- Proxies to `pantinventory_backend:3000`
- Larger body size for uploads (50MB)

### Snippets (Reusable Config Blocks)

**ssl-params.conf:**
- TLS 1.2 and 1.3 only
- Strong cipher suites
- OCSP stapling
- Session caching

**proxy-params.conf:**
- Common proxy headers (X-Real-IP, X-Forwarded-For, etc.)
- Proxy timeouts
- Buffering settings

**security-headers.conf:**
- X-Frame-Options (prevent clickjacking)
- X-Content-Type-Options (prevent MIME sniffing)
- X-XSS-Protection
- Referrer-Policy
- Permissions-Policy

---

## SSL Certificate Management

### Automatic Renewal

Certificates automatically renew every 12 hours via the certbot container.

The certbot container runs in the background and:
1. Checks certificate expiry every 12 hours
2. Renews certificates within 30 days of expiry
3. Stores renewed certificates in `/etc/letsencrypt/`

Nginx automatically picks up renewed certificates on next reload.

### Manual Renewal

Force certificate renewal:

```bash
cd /opt/pantinventory/nginx

# Renew all certificates
docker compose run --rm certbot renew

# Reload nginx to use new certificates
docker compose exec nginx nginx -s reload
```

### Test Renewal (Dry Run)

Test renewal process without actually renewing:

```bash
docker compose run --rm certbot renew --dry-run
```

### Check Certificate Expiry

```bash
# List all certificates with expiry dates
docker compose run --rm certbot certificates

# Check specific certificate
sudo openssl x509 -in /etc/letsencrypt/live/app.yourdomain.store/fullchain.pem -noout -dates
```

---

## Managing Nginx Configuration

### Making Configuration Changes

The typical workflow for updating nginx configuration:

#### 1. Edit Configuration Locally

```bash
cd pantinventory_devops/nginx/conf.d

# Edit configuration
vim app.yourdomain.store.conf

# Example: Change rate limit from 20r/s to 30r/s
# In the server block, update:
# limit_req zone=frontend_limit burst=60 nodelay;
```

#### 2. Commit to Version Control

```bash
git add nginx/conf.d/app.yourdomain.store.conf
git commit -m "Increase frontend rate limit to 30 req/s"
git push
```

#### 3. Deploy to VPS

```bash
# SSH to VPS
ssh your-vps

# Pull latest changes
cd pantinventory_devops
git pull

# Copy updated config to nginx directory
cp nginx/conf.d/app.yourdomain.store.conf /opt/pantinventory/nginx/conf.d/

# Test and reload
./scripts/nginx-reload.sh
```

### Common Configuration Changes

#### Change Rate Limits

**Edit nginx.conf for global rate zones:**

```bash
vim /opt/pantinventory/nginx/nginx.conf

# Find and modify:
limit_req_zone $binary_remote_addr zone=frontend_limit:10m rate=30r/s;  # Changed from 20r/s
```

**Edit server block for burst size:**

```bash
vim /opt/pantinventory/nginx/conf.d/app.yourdomain.store.conf

# Find and modify:
limit_req zone=frontend_limit burst=60 nodelay;  # Changed from 40
```

**Apply changes:**

```bash
cd pantinventory_devops
./scripts/nginx-reload.sh
```

#### Update CORS Headers

Edit the API configuration:

```bash
vim /opt/pantinventory/nginx/conf.d/api.yourdomain.store.conf

# Modify CORS headers:
add_header 'Access-Control-Allow-Origin' 'https://app.example.com' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
```

Reload:

```bash
./scripts/nginx-reload.sh
```

#### Increase Upload Size

Edit the API configuration:

```bash
vim /opt/pantinventory/nginx/conf.d/api.yourdomain.store.conf

# Find and modify:
client_max_body_size 100M;  # Changed from 50M
```

Reload:

```bash
./scripts/nginx-reload.sh
```

#### Add New Security Headers

Edit your server block:

```bash
vim /opt/pantinventory/nginx/conf.d/app.yourdomain.store.conf

# Add custom headers:
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'" always;
add_header X-Custom-Header "value" always;
```

Reload:

```bash
./scripts/nginx-reload.sh
```

### The nginx-reload.sh Script

This script ensures safe configuration reloads:

```bash
./scripts/nginx-reload.sh
```

What it does:
1. Tests nginx configuration for syntax errors
2. If valid, reloads nginx gracefully
3. If invalid, shows errors and exits without reloading

**Always use this script** instead of manually reloading to avoid breaking nginx.

---

## Future Configuration Updates

### Workflow for Configuration Changes

#### Scenario 1: Update Existing Configuration

**Example**: Increase rate limit for frontend

1. **Edit locally:**
   ```bash
   cd pantinventory_devops/nginx/conf.d
   vim app.yourdomain.store.conf
   # Make changes
   ```

2. **Commit to Git:**
   ```bash
   git add nginx/conf.d/app.yourdomain.store.conf
   git commit -m "Increase frontend rate limit"
   git push
   ```

3. **Deploy to VPS:**
   ```bash
   ssh your-vps
   cd pantinventory_devops
   git pull
   cp nginx/conf.d/app.yourdomain.store.conf /opt/pantinventory/nginx/conf.d/
   ./scripts/nginx-reload.sh
   ```

#### Scenario 2: Add New Domain

**Example**: Add `dashboard.example.com`

1. **Configure DNS:**
   - Add A record for `dashboard.example.com` pointing to VPS IP

2. **Create configuration file:**
   ```bash
   cd pantinventory_devops/nginx/conf.d
   cp app.yourdomain.store.conf.example dashboard.example.com.conf
   sed -i 's/yourdomain.store/example.com/g' dashboard.example.com.conf
   sed -i 's/app\./dashboard./g' dashboard.example.com.conf
   # Edit manually to point to correct container
   vim dashboard.example.com.conf
   ```

3. **Commit to Git:**
   ```bash
   git add nginx/conf.d/dashboard.example.com.conf
   git commit -m "Add dashboard subdomain"
   git push
   ```

4. **Deploy to VPS:**
   ```bash
   ssh your-vps
   cd pantinventory_devops
   git pull
   cp nginx/conf.d/dashboard.example.com.conf /opt/pantinventory/nginx/conf.d/
   ./scripts/nginx-reload.sh
   ```

5. **Obtain SSL certificate:**
   ```bash
   cd /opt/pantinventory/nginx
   docker compose run --rm certbot certonly \
     --webroot -w /var/www/certbot \
     -d dashboard.example.com \
     --email your-email@example.com \
     --agree-tos
   ```

6. **Enable HTTPS in config:**
   ```bash
   vim /opt/pantinventory/nginx/conf.d/dashboard.example.com.conf
   # Uncomment HTTPS server block
   ```

7. **Reload:**
   ```bash
   cd pantinventory_devops
   ./scripts/nginx-reload.sh
   ```

#### Scenario 3: Update Global Settings

**Example**: Change gzip compression level

1. **Edit nginx.conf:**
   ```bash
   cd pantinventory_devops
   vim nginx/nginx.conf
   # Change: gzip_comp_level 6; → gzip_comp_level 5;
   ```

2. **Commit:**
   ```bash
   git add nginx/nginx.conf
   git commit -m "Adjust gzip compression level"
   git push
   ```

3. **Deploy:**
   ```bash
   ssh your-vps
   cd pantinventory_devops
   git pull
   cp nginx/nginx.conf /opt/pantinventory/nginx/
   ./scripts/nginx-reload.sh
   ```

### Best Practices for Updates

1. **Always test locally if possible:**
   ```bash
   docker compose -f nginx/docker-compose.yml exec nginx nginx -t
   ```

2. **Use git for version control:**
   - Track all changes
   - Easy rollback if needed
   - See history of what changed

3. **Use the reload script:**
   ```bash
   ./scripts/nginx-reload.sh  # Safe reload with validation
   ```

4. **Keep backups:**
   ```bash
   # Before major changes, backup current config
   cd /opt/pantinventory
   tar -czf nginx-backup-$(date +%Y%m%d).tar.gz nginx/
   ```

5. **Monitor logs after changes:**
   ```bash
   docker logs -f pantinventory_nginx
   ```

### Rollback Procedure

If a configuration change breaks nginx:

```bash
# SSH to VPS
ssh your-vps

# Check what broke
docker logs pantinventory_nginx
docker compose -f /opt/pantinventory/nginx/docker-compose.yml exec nginx nginx -t

# Revert to previous Git commit
cd pantinventory_devops
git log --oneline  # Find previous working commit
git checkout <commit-hash> nginx/conf.d/

# Or restore from backup
cd /opt/pantinventory
tar -xzf nginx-backup-YYYYMMDD.tar.gz

# Reload
cd pantinventory_devops
./scripts/nginx-reload.sh
```

---

## Monitoring and Logs

### View Nginx Logs

```bash
# Real-time logs (all)
docker logs -f pantinventory_nginx

# Specific domain access logs
docker compose -f /opt/pantinventory/nginx/docker-compose.yml exec nginx tail -f /var/log/nginx/app.yourdomain.store.access.log

# Error logs
docker compose -f /opt/pantinventory/nginx/docker-compose.yml exec nginx tail -f /var/log/nginx/error.log

# Last 100 lines
docker logs --tail 100 pantinventory_nginx
```

### Check Nginx Status

```bash
# Container running?
docker ps | grep pantinventory_nginx

# Test configuration
docker compose -f /opt/pantinventory/nginx/docker-compose.yml exec nginx nginx -t

# Check ports
sudo netstat -tlnp | grep -E ':80|:443'
```

### View Certificate Status

```bash
# List all certificates
docker compose -f /opt/pantinventory/nginx/docker-compose.yml run --rm certbot certificates

# Check expiry
sudo openssl x509 -in /etc/letsencrypt/live/app.yourdomain.store/fullchain.pem -noout -dates
```

---

## Troubleshooting

### SSL Certificate Errors

**Problem**: "Failed to obtain SSL certificate"

**Checklist:**
1. ✅ DNS configured? `dig app.yourdomain.store +short`
2. ✅ Port 80 open? `sudo ufw status | grep 80`
3. ✅ Nginx running? `docker ps | grep pantinventory_nginx`
4. ✅ Port 80 accessible from internet? Use https://www.whatsmyip.org/port-scanner/

**Solutions:**
```bash
# Check DNS
dig app.yourdomain.store +short  # Should show VPS IP

# Check firewall
sudo ufw status | grep 80

# Check nginx logs
docker logs pantinventory_nginx

# Wait for DNS propagation (can take hours)
# Try again later
```

**Problem**: Certificate expired

**Solution:**
```bash
# Check auto-renewal is working
docker logs pantinventory_certbot

# Force renewal
cd /opt/pantinventory/nginx
docker compose run --rm certbot renew --force-renewal
docker compose exec nginx nginx -s reload
```

### Configuration Errors

**Problem**: Nginx won't reload

**Solution:**
```bash
# Test configuration
docker compose -f /opt/pantinventory/nginx/docker-compose.yml exec nginx nginx -t

# Read error message carefully
# Fix the error in your .conf file
# Test again
./scripts/nginx-reload.sh
```

**Problem**: Syntax error in config

**Example error:**
```
nginx: [emerg] unexpected "}" in /etc/nginx/conf.d/app.example.com.conf:45
```

**Solution:**
```bash
# Edit the file
vim /opt/pantinventory/nginx/conf.d/app.example.com.conf

# Go to line 45 (:45 in vim)
# Check for missing semicolon, extra bracket, etc.
# Fix and test
./scripts/nginx-reload.sh
```

### Connection Issues

**Problem**: Cannot connect to domain

**Checklist:**
1. ✅ Nginx running? `docker ps | grep pantinventory_nginx`
2. ✅ DNS pointing to VPS? `dig app.yourdomain.store +short`
3. ✅ Firewall open? `sudo ufw status`
4. ✅ Application running? `docker ps | grep pantinventory_frontend`

**Solutions:**
```bash
# Check nginx
docker ps | grep pantinventory_nginx

# Check DNS
dig app.yourdomain.store +short

# Check firewall
sudo ufw status | grep -E '80|443'

# Test HTTP
curl -I http://app.yourdomain.store

# Test HTTPS
curl -I https://app.yourdomain.store

# Check logs
docker logs pantinventory_nginx
```

**Problem**: 502 Bad Gateway

**Cause**: Nginx is running, but backend application is not

**Solution:**
```bash
# Check if backend is running
docker ps | grep pantinventory_frontend
docker ps | grep pantinventory_backend

# If not running, deploy applications
# See: docs/03-application-deployment/
```

### Rate Limiting Issues

**Problem**: Legitimate users getting rate limited

**Symptoms:**
- 429 Too Many Requests errors
- Logs show: `limiting requests, excess`

**Solutions:**

1. **Temporarily disable rate limiting** (for testing):
   ```bash
   vim /opt/pantinventory/nginx/conf.d/app.yourdomain.store.conf
   # Comment out: # limit_req zone=frontend_limit burst=40 nodelay;
   ./scripts/nginx-reload.sh
   ```

2. **Increase rate limits:**
   ```bash
   # Edit global rate limit
   vim /opt/pantinventory/nginx/nginx.conf
   # Change: rate=20r/s → rate=30r/s

   # Edit burst size
   vim /opt/pantinventory/nginx/conf.d/app.yourdomain.store.conf
   # Change: burst=40 → burst=60

   ./scripts/nginx-reload.sh
   ```

3. **Whitelist specific IPs:**
   ```nginx
   # In server block
   geo $limit {
       default 1;
       10.0.0.0/8 0;  # Internal network
       YOUR_IP 0;      # Your IP
   }

   map $limit $limit_key {
       0 "";
       1 $binary_remote_addr;
   }

   limit_req_zone $limit_key zone=frontend_limit:10m rate=20r/s;
   ```

---

## Advanced Features

### Load Balancing

If you have multiple backend instances:

**Create upstream block** (in nginx.conf or separate file):

```nginx
upstream backend_cluster {
    least_conn;  # Or: ip_hash, round_robin
    server pantinventory_backend_1:3000;
    server pantinventory_backend_2:3000;
    server pantinventory_backend_3:3000;
}
```

**Use in server block:**

```nginx
location / {
    proxy_pass http://backend_cluster;
    include /etc/nginx/snippets/proxy-params.conf;
}
```

### Custom Error Pages

Add custom error pages:

```nginx
# In server block
error_page 404 /404.html;
error_page 500 502 503 504 /50x.html;

location = /404.html {
    root /usr/share/nginx/html;
    internal;
}

location = /50x.html {
    root /usr/share/nginx/html;
    internal;
}
```

### IP-based Access Control

Restrict access to specific IPs:

```nginx
# In location block
location /admin {
    allow 203.0.113.0/24;  # Allow specific network
    allow 203.0.113.50;     # Allow specific IP
    deny all;                # Deny everyone else

    proxy_pass http://pantinventory_backend:3000;
    include /etc/nginx/snippets/proxy-params.conf;
}
```

---

## Backup and Disaster Recovery

### Backup Configuration

```bash
# Backup nginx configs
cd /opt/pantinventory
tar -czf nginx-backup-$(date +%Y%m%d).tar.gz nginx/

# Backup SSL certificates
sudo tar -czf letsencrypt-backup-$(date +%Y%m%d).tar.gz /etc/letsencrypt/

# Copy to local machine
scp nginx-backup-*.tar.gz your-local:~/backups/
scp letsencrypt-backup-*.tar.gz your-local:~/backups/
```

### Restore from Backup

```bash
# Restore nginx configs
cd /opt/pantinventory
tar -xzf nginx-backup-YYYYMMDD.tar.gz

# Restore SSL certificates
sudo tar -xzf letsencrypt-backup-YYYYMMDD.tar.gz -C /

# Restart
cd nginx
docker compose restart
```

### Rebuild on New VPS

Since all configs are in Git, rebuilding is simple:

```bash
# On new VPS
git clone https://github.com/YOUR_USERNAME/pantinventory_devops.git
cd pantinventory_devops

# Run setup scripts
./scripts/01-vps-initial-setup.sh
# (log out and back in)
./scripts/02-network-setup.sh
./scripts/03-nginx-setup.sh
./scripts/04-ssl-setup.sh

# Done! Nginx configured identically
```

---

## Summary

✅ **HTTPS externally** - All internet traffic encrypted
✅ **HTTP internally** - Fast, no SSL overhead between containers
✅ **Subdomain strategy** - Root domain free for Cloudflare
✅ **Automatic SSL** - Certbot handles certificates and renewal
✅ **Infrastructure as Code** - All configs version-controlled in Git
✅ **Rate limiting** - Protection against abuse (20 req/s frontend, 10 req/s API)
✅ **Security headers** - Protection against common attacks
✅ **CORS enabled** - Frontend can access backend API

**Your Setup:**
- `app.yourdomain.store` → Your VPS (PantInventory frontend)
- `api.yourdomain.store` → Your VPS (PantInventory backend)
- `yourdomain.store` → Available for Cloudflare (landing page)

**Next Steps:**
- [Application Deployment](../03-application-deployment/README.md) - Deploy your applications
