# SSL Certificates with Let's Encrypt

## Overview

This guide covers SSL certificate setup for PantInventory using Let's Encrypt through nginx-proxy-manager. Let's Encrypt provides free, automated SSL certificates with automatic renewal.

---

## What is Let's Encrypt?

**Let's Encrypt** is a free, automated Certificate Authority (CA) that provides SSL/TLS certificates for HTTPS encryption.

**Benefits:**
- ✅ **Free** - No cost for certificates
- ✅ **Automated** - nginx-proxy-manager handles everything
- ✅ **Auto-renewal** - Certificates renew automatically before expiry
- ✅ **Trusted** - Recognized by all major browsers
- ✅ **Easy** - Web UI configuration, no command-line certificates

**How it works:**
1. You request a certificate for your domain (e.g., app.yourdomain.store)
2. Let's Encrypt verifies you control the domain (HTTP-01 challenge)
3. Certificate is issued (valid for 90 days)
4. nginx-proxy-manager automatically renews at 60 days

---

## Prerequisites

Before requesting SSL certificates:

### 1. DNS Must Point to VPS

```bash
# Check DNS resolution
dig app.yourdomain.store +short
# Should show: YOUR_VPS_IP

dig api.yourdomain.store +short
# Should show: YOUR_VPS_IP
```

**If DNS doesn't resolve correctly:**
- Verify A records in Namecheap (see [nginx-proxy-manager.md](./nginx-proxy-manager.md))
- Wait for DNS propagation (can take 5 minutes to 24 hours)
- Try again after waiting

### 2. Firewall Ports Must Be Open

```bash
# Check firewall
sudo ufw status | grep -E '80|443'

# Should show:
# 80/tcp                     ALLOW       Anywhere
# 443/tcp                    ALLOW       Anywhere
```

**Port 80 is required** for Let's Encrypt validation (HTTP-01 challenge).

### 3. No Port Conflicts

```bash
# Check nothing else is using port 80
sudo netstat -tlnp | grep :80

# Should only show nginx-proxy-manager
```

**If another service is on port 80:**
```bash
# Identify the service
sudo netstat -tlnp | grep :80

# Stop it (example for apache2)
sudo systemctl stop apache2
sudo systemctl disable apache2
```

---

## Requesting SSL Certificates

### Via nginx-proxy-manager UI

1. **Access admin UI**:
   ```
   http://YOUR_VPS_IP:81
   ```

2. **Go to Proxy Hosts**:
   - Click **Hosts** → **Proxy Hosts**

3. **Edit or create proxy host**:
   - For existing: Click the 3 dots → **Edit**
   - For new: Click **Add Proxy Host**

4. **Configure SSL Tab**:
   ```
   SSL Certificate:  Request a new SSL Certificate

   [x] Force SSL
   [x] HTTP/2 Support
   [ ] HSTS Enabled (enable after confirming SSL works)

   Email Address:    your-email@yourdomain.store
   [x] I Agree to the Let's Encrypt TOS
   ```

5. **Click Save**

nginx-proxy-manager will:
- Contact Let's Encrypt
- Verify domain ownership (HTTP-01 challenge via port 80)
- Download and install certificate
- Configure nginx to use HTTPS

---

## Verification

### Check Certificate Installation

1. **In browser**:
   ```
   https://app.yourdomain.store
   ```
   - Should show padlock icon (🔒)
   - Click padlock → Certificate details → Should show Let's Encrypt

2. **Via command line**:
   ```bash
   # Check HTTPS works
   curl -I https://app.yourdomain.store
   # Should show: HTTP/2 200

   # Check HTTP redirects to HTTPS (if Force SSL enabled)
   curl -I http://app.yourdomain.store
   # Should show: HTTP/1.1 301 Moved Permanently
   # Location: https://app.yourdomain.store
   ```

3. **Check certificate expiry**:
   ```bash
   echo | openssl s_client -connect app.yourdomain.store:443 2>/dev/null | openssl x509 -noout -dates

   # Shows:
   # notBefore=... (when issued)
   # notAfter=...  (expiry date, 90 days from issue)
   ```

### View in nginx-proxy-manager

1. Go to **SSL Certificates** tab
2. View all certificates and expiry dates
3. Verify auto-renewal is scheduled (30 days before expiry)

---

## Certificate Renewal

### Automatic Renewal

nginx-proxy-manager automatically renews certificates:

- **Renewal trigger**: 30 days before expiry
- **Process**: Same as initial request (HTTP-01 challenge)
- **No action required**: Completely automatic

### Check Renewal Status

```bash
# View nginx-proxy-manager logs
docker logs nginx-proxy-manager | grep -i certbot

# Look for:
# - "Certificate renewed successfully"
# - "Renewal succeeded"
```

### Manual Renewal (if needed)

1. In nginx-proxy-manager UI:
   - Go to **SSL Certificates**
   - Click on your certificate
   - Click **Renew** button

2. Or force renewal via command:
   ```bash
   # Get container ID
   docker ps | grep nginx-proxy-manager

   # Execute renewal inside container
   docker exec <container-id> certbot renew --force-renewal
   ```

---

## Troubleshooting

### Error: "Failed to obtain SSL certificate"

**Possible causes and solutions:**

#### 1. DNS Not Pointing to VPS

**Check:**
```bash
dig app.yourdomain.store +short
# Should show YOUR_VPS_IP
```

**Fix:**
- Verify A records in Namecheap
- Wait for DNS propagation (try again in 1 hour)

#### 2. Port 80 Not Open

**Check:**
```bash
sudo ufw status | grep 80
# Should show: 80/tcp ALLOW
```

**Fix:**
```bash
sudo ufw allow 80/tcp
sudo ufw reload
```

#### 3. Port 80 Already in Use

**Check:**
```bash
sudo netstat -tlnp | grep :80
```

**Fix:**
```bash
# If another service is using port 80, stop it
sudo systemctl stop <service-name>
sudo systemctl disable <service-name>
```

#### 4. Domain Doesn't Exist or Typo

**Check:**
- Verify domain name in proxy host matches DNS exactly
- Check for typos (app vs apps, api vs api-backend, etc.)

#### 5. Rate Limiting

Let's Encrypt has rate limits:
- **5 failures per hour** for the same domain
- **50 certificates per week** for the same domain

**Fix:**
- Wait 1 hour if you hit failure limit
- Use [Let's Encrypt staging environment](https://letsencrypt.org/docs/staging-environment/) for testing

**Test with staging (doesn't count against limits):**
1. Edit proxy host
2. SSL Tab → **Use Let's Encrypt Staging**
3. Request certificate
4. If successful, delete and request production certificate

---

### Error: "Certificate expired"

**Cause:** Auto-renewal failed

**Check logs:**
```bash
docker logs nginx-proxy-manager | grep -i "certbot\|renewal"

# Look for errors like:
# - DNS issues
# - Port 80 blocked
# - Rate limiting
```

**Fix:**
1. Resolve the underlying issue (DNS, firewall, etc.)
2. Manually renew certificate (see Manual Renewal above)

---

### Error: "ERR_CERT_AUTHORITY_INVALID"

**Cause:** Using Let's Encrypt staging certificate in production

**Fix:**
1. Delete staging certificate
2. Request new certificate without staging option

---

### Error: "Too many certificates already issued"

**Cause:** Hit Let's Encrypt rate limit (50 certs/week)

**Fix:**
- Wait until next week
- Use wildcard certificate (covers *.yourdomain.store)
- Consolidate multiple domains into one certificate

---

## Security Best Practices

### 1. Force SSL

Always redirect HTTP to HTTPS:

1. Edit proxy host
2. **SSL Tab**
3. Enable **Force SSL**

This ensures all traffic is encrypted.

### 2. Enable HSTS

HTTP Strict Transport Security forces browsers to always use HTTPS:

1. Edit proxy host
2. **SSL Tab**
3. Enable **HSTS Enabled**

**Warning:** Only enable after confirming SSL works correctly. HSTS can lock you out if SSL fails.

**HSTS settings:**
- Max Age: 31536000 (1 year)
- Include Subdomains: ✓ (if all subdomains use HTTPS)

### 3. HTTP/2 Support

Enable HTTP/2 for better performance:

1. Edit proxy host
2. **SSL Tab**
3. Enable **HTTP/2 Support**

Benefits:
- Faster page loads (multiplexing)
- Better resource loading
- Header compression

### 4. Monitor Certificate Expiry

Set up email notifications:

1. Use a real email address when requesting certificates
2. Let's Encrypt sends expiry warnings if auto-renewal fails
3. Check nginx-proxy-manager logs periodically

### 5. Use Strong Ciphers

nginx-proxy-manager uses secure defaults, but you can customize:

1. Edit proxy host
2. **Advanced Tab**
3. Add custom nginx config:

```nginx
# Modern configuration (recommended)
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;
```

---

## Advanced: Wildcard Certificates

### What is a Wildcard Certificate?

A wildcard certificate covers all subdomains:
- `*.yourdomain.store` covers:
  - app.yourdomain.store
  - api.yourdomain.store
  - admin.yourdomain.store
  - etc.

### Requirements

Wildcard certificates require **DNS-01 challenge** (not HTTP-01):
- Requires DNS provider API access
- More complex setup
- nginx-proxy-manager supports some DNS providers

### Supported DNS Providers

nginx-proxy-manager supports:
- Cloudflare
- Route53 (AWS)
- DigitalOcean
- And others (see [nginx-proxy-manager docs](https://nginxproxymanager.com/))

**Namecheap is NOT directly supported** for DNS-01 challenge in nginx-proxy-manager.

### Alternative: Individual Certificates

Easier approach for most users:
- Request separate certificate for each subdomain
- app.yourdomain.store → Certificate 1
- api.yourdomain.store → Certificate 2

**Advantages:**
- Simpler setup (HTTP-01 challenge)
- Works with any DNS provider
- Better isolation (compromised cert doesn't affect other domains)

---

## Certificate Management Commands

### View Certificates

```bash
# List all certificates in nginx-proxy-manager
docker exec nginx-proxy-manager certbot certificates

# Output shows:
# - Certificate Name
# - Domains
# - Expiry Date
# - Certificate Path
```

### Force Renewal

```bash
# Renew all certificates
docker exec nginx-proxy-manager certbot renew

# Renew specific certificate
docker exec nginx-proxy-manager certbot renew --cert-name app.yourdomain.store
```

### Delete Certificate

```bash
# Delete via UI (recommended)
# SSL Certificates → Click certificate → Delete

# Or via command
docker exec nginx-proxy-manager certbot delete --cert-name app.yourdomain.store
```

### Backup Certificates

```bash
# Certificates are stored in nginx-proxy-manager data
cd /opt/nginx-proxy-manager
tar -czf ssl-backup-$(date +%Y%m%d).tar.gz data/letsencrypt/

# Store backup securely (off-server recommended)
scp ssl-backup-*.tar.gz your-local-machine:/backups/
```

---

## Monitoring & Alerts

### Email Notifications

Let's Encrypt sends emails for:
- ✅ Certificate expiry warnings (if auto-renewal fails)
- ✅ Rate limit notifications
- ✅ Certificate revocation

**Ensure you use a real email address** when requesting certificates.

### Log Monitoring

```bash
# Monitor renewal attempts
docker logs nginx-proxy-manager -f | grep -i certbot

# Check for errors
docker logs nginx-proxy-manager | grep -i "error\|failed" | grep -i certbot
```

### External Monitoring (Optional)

Use external services to monitor SSL:
- [SSL Labs](https://www.ssllabs.com/ssltest/) - Test SSL configuration
- [UptimeRobot](https://uptimerobot.com/) - Monitor certificate expiry
- [HetrixTools](https://hetrixtools.com/) - SSL monitoring and alerts

---

## Summary

✅ **Let's Encrypt provides free SSL certificates** via nginx-proxy-manager
✅ **Automatic renewal** - No manual intervention needed
✅ **Prerequisites**: DNS points to VPS, ports 80/443 open
✅ **HTTP-01 challenge** - Used for domain validation
✅ **90-day validity** - Auto-renews at 60 days
✅ **Force SSL** - Always redirect HTTP to HTTPS
✅ **Enable HSTS** - After confirming SSL works
✅ **Monitor expiry** - Check logs and email notifications

**Next Steps:**
- [Configure CORS](./cors-configuration.md) - Enable frontend-backend communication
- [nginx-proxy-manager Configuration](./nginx-proxy-manager.md) - Full proxy setup guide

