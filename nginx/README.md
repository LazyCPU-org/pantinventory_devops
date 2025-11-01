# Nginx Configuration Directory

This directory contains all Nginx configuration files for PantInventory infrastructure.

## Directory Structure

```
nginx/
├── docker-compose.yml          # Docker Compose for nginx + certbot
├── nginx.conf                  # Main nginx configuration
├── conf.d/                     # Server block configurations
│   ├── *.conf.example         # Example configurations (copy and customize)
│   └── *.conf                 # Active configurations (gitignored)
└── snippets/                   # Reusable configuration snippets
    ├── ssl-params.conf        # SSL best practices
    ├── proxy-params.conf      # Common proxy settings
    └── security-headers.conf  # Security headers
```

## Quick Start

### 1. Copy Example Configurations

```bash
cd nginx/conf.d
cp app.yourdomain.store.conf.example app.yourdomain.store.conf
cp api.yourdomain.store.conf.example api.yourdomain.store.conf
```

### 2. Customize for Your Domain

Replace `yourdomain.store` with your actual domain in both files:

```bash
sed -i 's/yourdomain.store/your-actual-domain.com/g' app.yourdomain.store.conf
sed -i 's/yourdomain.store/your-actual-domain.com/g' api.yourdomain.store.conf
```

### 3. Deploy Nginx

Use the automated setup script:

```bash
cd ..
./scripts/03-nginx-setup.sh
```

### 4. Obtain SSL Certificates

```bash
./scripts/04-ssl-setup.sh
```

### 5. Enable HTTPS Configuration

Uncomment the SSL server blocks in your `.conf` files and reload:

```bash
./scripts/nginx-reload.sh
```

## Configuration Files

### Main Configuration (`nginx.conf`)

Global nginx settings including:
- Worker processes and connections
- Logging configuration
- Gzip compression
- SSL defaults
- Rate limiting zones

### Server Blocks (`conf.d/*.conf`)

Individual configurations for each domain/subdomain:
- `app.yourdomain.store.conf` - Frontend application
- `api.yourdomain.store.conf` - Backend API

### Snippets (`snippets/*.conf`)

Reusable configuration blocks:
- `ssl-params.conf` - SSL/TLS best practices
- `proxy-params.conf` - Common proxy headers and settings
- `security-headers.conf` - Security headers for all responses

## Making Changes

### Edit Configuration

```bash
vim nginx/conf.d/app.yourdomain.store.conf
```

### Test Configuration

```bash
docker compose exec nginx nginx -t
```

### Reload Nginx

```bash
./scripts/nginx-reload.sh
```

## SSL Certificates

SSL certificates are managed by Certbot and stored in `/etc/letsencrypt/`.

### Obtain New Certificate

```bash
./scripts/04-ssl-setup.sh
```

### Manual Certificate Request

```bash
docker compose run --rm certbot certonly --webroot \
  -w /var/www/certbot \
  -d app.yourdomain.store \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email
```

### Certificate Renewal

Certbot container automatically renews certificates every 12 hours. You can also manually trigger renewal:

```bash
docker compose run --rm certbot renew
docker compose exec nginx nginx -s reload
```

## Logs

View nginx logs:

```bash
# Access logs
docker compose logs -f nginx

# Error logs
docker compose exec nginx tail -f /var/log/nginx/error.log

# Specific domain logs
docker compose exec nginx tail -f /var/log/nginx/app.yourdomain.store.access.log
```

## Troubleshooting

### Configuration Test Fails

```bash
# Check syntax
docker compose exec nginx nginx -t

# View detailed error
docker compose logs nginx
```

### SSL Certificate Issues

```bash
# Check certificate expiry
docker compose exec nginx openssl x509 -in /etc/letsencrypt/live/app.yourdomain.store/fullchain.pem -noout -dates

# Force renewal
docker compose run --rm certbot renew --force-renewal
```

### Connection Refused

```bash
# Check if nginx is running
docker ps | grep nginx

# Check if ports are bound
sudo netstat -tlnp | grep -E ':80|:443'

# Restart nginx
docker compose restart nginx
```

## Security

### Rate Limiting

Configured in `nginx.conf`:
- Frontend: 20 req/s, burst 40
- Backend API: 10 req/s, burst 20

Adjust in `nginx.conf` and reload.

### CORS

CORS headers are configured in `api.yourdomain.store.conf` to allow frontend access.

Update the `Access-Control-Allow-Origin` header to match your frontend domain.

### Security Headers

All security headers are included via `snippets/security-headers.conf`:
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection
- Referrer-Policy
- Permissions-Policy

## Version Control

The `.conf` files in `conf.d/` are gitignored to prevent committing sensitive domain information.

Only `.conf.example` files are tracked in Git.

After customizing your configuration, consider committing your changes to a private repository or backing them up securely.
