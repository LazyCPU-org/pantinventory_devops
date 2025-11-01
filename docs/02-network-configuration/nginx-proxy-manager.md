# Nginx Proxy Manager Configuration

## Overview

Nginx Proxy Manager acts as a reverse proxy, handling all incoming internet traffic and routing it to your applications. It provides:
- SSL/TLS termination (HTTPS → HTTP)
- Domain-based routing
- Automatic SSL certificate management
- Web-based configuration UI

---

## Architecture: HTTPS External, HTTP Internal

```
Internet (HTTPS only)
        ↓
     Port 443
        ↓
┌─────────────────────────────┐
│  Nginx Proxy Manager        │
│  - SSL Termination          │
│  - HTTPS → HTTP conversion  │
│  - Domain routing           │
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

### DNS Configuration

**For VPS-hosted services** (app and API):
```
A Record: app.yourdomain.store  → YOUR_VPS_IP
A Record: api.yourdomain.store  → YOUR_VPS_IP
```

**For Cloudflare-hosted landing page** (root domain):
```
A Record: yourdomain.store      → CLOUDFLARE_IP (or proxy)
A Record: www.yourdomain.store  → CLOUDFLARE_IP (or proxy)
```

**Can you use both?** YES! You can:
- Point `app.yourdomain.store` to your VPS (nginx-proxy-manager)
- Point `yourdomain.store` to Cloudflare (landing page)
- They're completely independent DNS records

---

## Installation

### Automated Installation

```bash
# Run the nginx-proxy-manager setup script
./scripts/03-nginx-proxy-setup.sh
```

This deploys nginx-proxy-manager via docker-compose on the `pantinventory_network`.

### Manual Installation

See the script at `scripts/03-nginx-proxy-setup.sh` for details.

---

## DNS Setup (Namecheap)

Before configuring nginx-proxy-manager, set up DNS:

### Step 1: Get Your VPS IP

```bash
# On your VPS
curl ifconfig.me
```

### Step 2: Configure DNS in Namecheap

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

### Step 3: Verify DNS Propagation

```bash
# Wait 5-10 minutes, then check
dig app.yourdomain.store +short
# Should show YOUR_VPS_IP

dig api.yourdomain.store +short
# Should show YOUR_VPS_IP
```

**Note**: DNS propagation can take up to 24 hours, but usually happens in minutes.

---

## Initial Access & Setup

### Step 1: Access Admin UI

After installation, access the admin panel:

```
http://YOUR_VPS_IP:81
```

**Default credentials:**
- Email: `admin@example.com`
- Password: `changeme`

### Step 2: Change Default Credentials

**⚠️ CRITICAL**: Change these immediately!

1. Log in with default credentials
2. Click on **Admin** (top right) → **Users**
3. Click **Edit** on the admin user
4. Change email and password
5. Save changes

**Recommended:**
- Use a strong password (20+ characters)
- Use a real email address (for Let's Encrypt notifications)

### Step 3: Configure Admin UI Access (Optional Security)

For security, you may want to restrict admin UI access:

**Option A: Firewall restriction (recommended)**
```bash
# On VPS: Allow admin UI only from your IP
sudo ufw delete allow 81/tcp
sudo ufw allow from YOUR_HOME_IP to any port 81 proto tcp
```

**Option B: SSH tunnel (most secure)**
```bash
# From your local machine
ssh -L 8081:localhost:81 -i ~/.ssh/pantinventory_vps your-user@YOUR_VPS_IP

# Access via: http://localhost:8081
# Port 81 not exposed to internet
```

---

## Configuring Proxy Hosts

### Frontend Configuration (app.yourdomain.store)

**Purpose**: Route `app.yourdomain.store` to your frontend container

1. In admin UI, go to **Hosts** → **Proxy Hosts**
2. Click **Add Proxy Host**

**Details Tab:**
```
Domain Names:     app.yourdomain.store
Scheme:           http
Forward Hostname: pantinventory_frontend
Forward Port:     80

[x] Block Common Exploits
[ ] Websockets Support (enable if using WebSockets)
[x] Cache Assets
```

**SSL Tab:**
```
SSL Certificate:  Request a new SSL Certificate
[x] Force SSL
[x] HTTP/2 Support
[ ] HSTS Enabled (enable after confirming SSL works)

Email Address:    your-email@yourdomain.store
[x] I Agree to the Let's Encrypt TOS
```

Click **Save**

### Backend API Configuration (api.yourdomain.store)

**Purpose**: Route `api.yourdomain.store` to your backend container

1. Click **Add Proxy Host**

**Details Tab:**
```
Domain Names:     api.yourdomain.store
Scheme:           http
Forward Hostname: pantinventory_backend
Forward Port:     3000

[x] Block Common Exploits
[ ] Websockets Support
[ ] Cache Assets (don't cache API responses)
```

**SSL Tab:**
```
SSL Certificate:  Request a new SSL Certificate
[x] Force SSL
[x] HTTP/2 Support
[ ] HSTS Enabled

Email Address:    your-email@yourdomain.store
[x] I Agree to the Let's Encrypt TOS
```

**Custom Locations Tab:**
Leave empty for now (we'll add CORS headers in next section)

Click **Save**

---

## SSL Certificate Details

### How It Works

When you click "Request a new SSL Certificate":

1. Nginx Proxy Manager contacts Let's Encrypt
2. Let's Encrypt verifies you control the domain (HTTP-01 challenge)
3. Certificate is issued and installed automatically
4. Auto-renewal happens every 60 days

### Prerequisites for SSL

- ✅ Domain DNS must point to your VPS IP
- ✅ Port 80 must be open (for Let's Encrypt validation)
- ✅ Port 443 must be open (for HTTPS traffic)

**Verify Prerequisites:**
```bash
# Check DNS
dig app.yourdomain.store +short
# Should show YOUR_VPS_IP

# Check firewall
sudo ufw status | grep -E '80|443'
# Should show 80/tcp and 443/tcp ALLOW

# Ensure no service conflicts on port 80
sudo netstat -tlnp | grep :80
# Should only show nginx-proxy-manager
```

### Troubleshooting SSL

**Problem**: "Failed to obtain SSL certificate"

**Solutions:**
1. **Verify DNS**: `dig app.yourdomain.store +short` (should show VPS IP)
2. **Check firewall**: `sudo ufw status | grep 80`
3. **Check port 80 available**: `sudo netstat -tlnp | grep :80`
4. **Check logs**:
   ```bash
   docker logs nginx-proxy-manager
   ```
5. **Wait for DNS**: DNS propagation can take hours, try again later

**Problem**: Certificate expired

**Solution**: Certificates auto-renew. If renewal fails:
```bash
# Check logs
docker logs nginx-proxy-manager | grep -i certbot

# Force renewal (in nginx-proxy-manager UI)
# SSL Certificates → Click on certificate → Renew
```

---

## Force HTTPS (Redirect HTTP to HTTPS)

After SSL is configured, force HTTPS:

1. Edit your proxy host
2. Go to **SSL** tab
3. Enable **Force SSL**
4. Save

Now all HTTP requests automatically redirect to HTTPS.

---

## Custom Configuration

### Block Common Exploits

Protect against common attacks:

1. Edit proxy host
2. **Details** tab
3. Check **Block Common Exploits**
4. Save

This blocks:
- SQL injection attempts
- Directory traversal attacks
- Common exploit patterns

### Enable HTTP/2

For better performance:

1. Edit proxy host
2. **SSL** tab
3. Check **HTTP/2 Support**
4. Save

HTTP/2 provides:
- Multiplexing (faster page loads)
- Header compression
- Better resource loading

### HSTS (HTTP Strict Transport Security)

Forces browsers to always use HTTPS:

1. Edit proxy host
2. **SSL** tab
3. Check **HSTS Enabled**
4. Save

**Warning**: Only enable after confirming SSL works correctly. HSTS can lock you out if SSL fails.

---

## Using Root Domain with Cloudflare (Future)

### Scenario

You want:
- `app.yourdomain.store` → VPS (PantInventory)
- `yourdomain.store` → Cloudflare Pages (Landing page)

### How to Configure

This works seamlessly because they're different DNS records:

**In Namecheap DNS:**
```
A Record: app.yourdomain.store  → YOUR_VPS_IP
A Record: api.yourdomain.store  → YOUR_VPS_IP
```

**In Cloudflare** (when you set it up):
```
CNAME: yourdomain.store         → your-site.pages.dev
```

**No conflicts!** Each subdomain/domain is independent.

**Steps when ready:**
1. Add domain to Cloudflare
2. Point NS records to Cloudflare nameservers
3. Configure DNS in Cloudflare (move A records there)
4. Keep `app` and `api` pointing to VPS
5. Add `yourdomain.store` CNAME to Cloudflare Pages

---

## Advanced: Custom Nginx Configuration

For advanced use cases, add custom nginx directives:

1. Edit proxy host
2. Go to **Advanced** tab
3. Add custom nginx config

**Example: Increase upload size**
```nginx
client_max_body_size 100M;
```

**Example: Custom timeouts**
```nginx
proxy_connect_timeout 600;
proxy_send_timeout 600;
proxy_read_timeout 600;
send_timeout 600;
```

**Example: Additional security headers**
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

---

## Monitoring & Logs

### Access Logs

```bash
# View real-time logs
docker logs nginx-proxy-manager -f

# Search for errors
docker logs nginx-proxy-manager | grep -i error

# Search for specific domain
docker logs nginx-proxy-manager | grep app.yourdomain.store
```

### Check Certificate Expiry

1. Admin UI → **SSL Certificates**
2. View expiry dates
3. Auto-renewal happens at 30 days before expiry

### Health Check

```bash
# Check container running
docker ps | grep nginx-proxy-manager

# Test HTTP (should redirect to HTTPS)
curl -I http://app.yourdomain.store

# Test HTTPS
curl -I https://app.yourdomain.store
```

---

## Security Best Practices

### 1. Keep Updated

```bash
cd /opt/nginx-proxy-manager
docker compose pull
docker compose up -d
```

### 2. Limit Admin UI Access

- Use firewall rules to limit port 81 access to your IP
- Or use SSH tunnel for admin access (no internet exposure)

### 3. Strong Passwords

- Use unique, strong password for admin account
- Use password manager

### 4. Monitor Logs

```bash
# Check for suspicious activity
docker logs nginx-proxy-manager | grep -i "403\|404\|500"
docker logs nginx-proxy-manager | grep -i "attack\|exploit"
```

### 5. Backup Configuration

```bash
# Backup nginx-proxy-manager data
cd /opt/nginx-proxy-manager
tar -czf npm-backup-$(date +%Y%m%d).tar.gz data/

# Store backup securely (off-server recommended)
scp npm-backup-*.tar.gz your-local-machine:/backups/
```

---

## Disaster Recovery

### Restore from Backup

```bash
cd /opt/nginx-proxy-manager
docker compose down
tar -xzf npm-backup-YYYYMMDD.tar.gz
docker compose up -d
```

### Recreate from Scratch

```bash
# Stop and remove
cd /opt/nginx-proxy-manager
docker compose down -v
sudo rm -rf data/ mysql/ letsencrypt/

# Reinstall
./scripts/03-nginx-proxy-setup.sh

# Reconfigure proxy hosts (SSL will auto-renew)
```

---

## Summary

✅ **HTTPS externally** - All internet traffic encrypted
✅ **HTTP internally** - Fast, no SSL overhead between containers
✅ **Subdomain strategy** - Root domain free for Cloudflare
✅ **Automatic SSL** - Let's Encrypt handles certificates
✅ **Web UI** - Easy configuration without editing nginx files
✅ **Flexible DNS** - Can mix VPS and Cloudflare hosting

**Example Configuration:**
- `app.yourdomain.store` → Your VPS (PantInventory frontend)
- `api.yourdomain.store` → Your VPS (PantInventory backend)
- `yourdomain.store` → Available for Cloudflare (landing page)

**Next Steps:**
- [Configure CORS](./cors-configuration.md) - Enable frontend-backend communication
- [SSL Certificates Guide](./ssl-certificates.md) - Detailed SSL troubleshooting
