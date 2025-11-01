# CORS Configuration Guide

## Overview

CORS (Cross-Origin Resource Sharing) is required because the frontend (`https://app.yourdomain.store`) and backend API (`https://api.yourdomain.store`) run on different domains.

**Architecture Decision:** CORS is handled **exclusively by nginx** in production for better performance and centralized configuration.

---

## Configuration Approach

### Production: Nginx Handles CORS

**Location:** `pantinventory_devops/nginx/conf.d/api.yourdomain.store.conf`

Nginx adds CORS headers to all API responses:

```nginx
location / {
    # CORS headers at location level (apply to all responses)
    add_header 'Access-Control-Allow-Origin' 'https://app.yourdomain.store' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
    add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
    add_header 'Access-Control-Allow-Credentials' 'true' always;
    add_header 'Access-Control-Max-Age' '1728000' always;

    # Handle preflight OPTIONS requests (return 204, don't proxy)
    if ($request_method = 'OPTIONS') {
        return 204;
    }

    proxy_pass http://pantinventory_backend:3000;
    # ... other config
}
```

**Backend:** `pantinventory_backend/src/main.ts`

CORS is **disabled** in production:

```typescript
// CORS is handled by nginx reverse proxy in production
if (process.env.NODE_ENV !== 'production') {
  app.enableCors({
    // ... development config
  });
}
```

### Development: Backend Handles CORS

When running locally without nginx, the backend handles CORS for localhost origins.

---

## Why This Approach?

### Benefits

1. **Single Source of Truth:** All CORS configuration in one place (nginx)
2. **No Conflicts:** Backend doesn't send duplicate/conflicting CORS headers
3. **Better Performance:** Nginx handles OPTIONS preflight without hitting the backend
4. **Centralized Security:** CORS policy managed with other nginx security settings
5. **Easier Debugging:** Only one place to check when CORS issues occur

### Trade-offs

- Backend must know its environment (`NODE_ENV=production`)
- Nginx configuration is slightly more complex
- Local development still needs backend CORS enabled

---

## CORS Headers Explained

| Header | Value | Purpose |
|--------|-------|---------|
| `Access-Control-Allow-Origin` | `https://app.yourdomain.store` | Which domain can access the API |
| `Access-Control-Allow-Methods` | `GET, POST, PUT, DELETE, PATCH, OPTIONS` | Which HTTP methods are allowed |
| `Access-Control-Allow-Headers` | `Content-Type, Authorization, ...` | Which request headers can be sent |
| `Access-Control-Expose-Headers` | `Content-Length, Content-Range` | Which response headers JS can access |
| `Access-Control-Allow-Credentials` | `true` | Allow cookies and auth headers |
| `Access-Control-Max-Age` | `1728000` (20 days) | How long to cache preflight responses |

**Important:** The `always` parameter ensures headers are sent even on error responses (4xx, 5xx).

---

## Preflight OPTIONS Requests

Browsers send a **preflight OPTIONS request** before certain API calls to check if CORS is allowed.

**Example flow:**
```
Browser wants to: POST https://api.yourdomain.store/api/auth/login

1. Browser sends OPTIONS request (preflight)
   OPTIONS /api/auth/login
   Origin: https://app.yourdomain.store

2. Nginx responds with 204 + CORS headers (doesn't hit backend)
   204 No Content
   Access-Control-Allow-Origin: https://app.yourdomain.store
   Access-Control-Allow-Methods: GET, POST, ...

3. Browser sends actual POST request
   POST /api/auth/login

4. Nginx proxies to backend and adds CORS headers to response
```

**Performance benefit:** Nginx returns 204 for OPTIONS immediately without proxying to the backend.

---

## Common CORS Errors and Solutions

### Error: "No 'Access-Control-Allow-Origin' header is present"

**Cause:** CORS headers not configured in nginx

**Solution:**
1. Verify nginx config has CORS headers in `location /` block
2. Ensure `always` parameter is used: `add_header ... always;`
3. Reload nginx: `docker compose exec nginx nginx -s reload`

### Error: "CORS header 'Access-Control-Allow-Origin' does not match"

**Cause:** Frontend domain doesn't match the configured origin

**Solution:**
1. Check frontend domain in nginx config matches actual domain
2. Verify `https://` vs `http://` (must match exactly)
3. No trailing slash in domain

### Error: "Response to preflight request doesn't pass access control check"

**Cause:** OPTIONS preflight not handled correctly

**Solution:**
1. Ensure `if ($request_method = 'OPTIONS')` block exists in nginx
2. Verify CORS headers are at location level (not inside if block)
3. Check nginx error logs: `docker compose logs nginx`

### Error: Multiple CORS headers

**Cause:** Both nginx and backend sending CORS headers

**Solution:**
1. Verify backend CORS is disabled in production (`src/main.ts`)
2. Check `NODE_ENV=production` is set in backend container
3. Restart backend: `docker compose restart app`

---

## Testing CORS Configuration

### 1. Check Preflight Response

```bash
curl -X OPTIONS https://api.yourdomain.store/api/auth/login \
  -H "Origin: https://app.yourdomain.store" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type,Authorization" \
  -v
```

**Expected response:**
- Status: `204 No Content`
- Headers should include:
  - `Access-Control-Allow-Origin: https://app.yourdomain.store`
  - `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH, OPTIONS`
  - `Access-Control-Allow-Headers: ... Authorization ...`

### 2. Check Actual Request

```bash
curl https://api.yourdomain.store/api/health \
  -H "Origin: https://app.yourdomain.store" \
  -v
```

**Expected response:**
- Status: `200 OK`
- Headers should include CORS headers
- Body: API response

### 3. Browser DevTools

1. Open browser DevTools (F12)
2. Go to Network tab
3. Trigger an API call from your frontend
4. Check the request:
   - Look for OPTIONS request (preflight)
   - Check Response Headers for CORS headers
   - Verify no CORS errors in Console

---

## Deployment Checklist

When deploying or updating CORS configuration:

- [ ] Backend `src/main.ts` has CORS disabled for production
- [ ] Nginx config has CORS headers in `location /` block
- [ ] CORS headers use `always` parameter
- [ ] OPTIONS preflight handled with `if ($request_method = 'OPTIONS')`
- [ ] `Access-Control-Allow-Origin` matches your frontend domain exactly
- [ ] Nginx config tested: `docker compose exec nginx nginx -t`
- [ ] Nginx reloaded: `docker compose exec nginx nginx -s reload`
- [ ] Backend redeployed with updated code
- [ ] CORS tested with curl (preflight and actual requests)
- [ ] Frontend tested in browser (no CORS errors in console)

---

## Updating Allowed Origins

If you need to allow multiple frontend domains (e.g., staging + production):

**Option 1: Using nginx map** (recommended for multiple domains)

```nginx
# In nginx.conf (main config)
map $http_origin $cors_origin {
    default "";
    "https://app.yourdomain.store" "https://app.yourdomain.store";
    "https://staging.yourdomain.store" "https://staging.yourdomain.store";
}

# In location block
add_header 'Access-Control-Allow-Origin' $cors_origin always;
```

**Option 2: Separate nginx configs** (recommended for completely different environments)

Create separate config files for each environment with different origins.

---

## Additional Resources

- [MDN CORS Documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [Nginx CORS Configuration](https://enable-cors.org/server_nginx.html)
- [Understanding CORS Preflight](https://developer.mozilla.org/en-US/docs/Glossary/Preflight_request)

---

## Summary

- **Production:** Nginx handles all CORS (backend CORS disabled)
- **Development:** Backend handles CORS (nginx not used)
- **CORS headers:** Location level with `always` parameter
- **OPTIONS requests:** Nginx returns 204 without proxying to backend
- **Configuration:** Single source of truth in nginx for production
