# CORS Configuration

## Overview

This guide covers Cross-Origin Resource Sharing (CORS) configuration for PantInventory. CORS headers allow your frontend (app.yourdomain.store) to communicate with your backend API (api.yourdomain.store).

---

## What is CORS?

**CORS (Cross-Origin Resource Sharing)** is a security feature built into web browsers that restricts web pages from making requests to a different domain than the one serving the web page.

### The Problem

Without CORS configuration:

```
Browser loads:     https://app.yourdomain.store (frontend)
Frontend calls:    https://api.yourdomain.store/api/products

❌ Browser blocks request: "Cross-Origin Request Blocked"
```

Even though both domains are yours, they're **different origins** from the browser's perspective.

### The Solution

Configure your backend API to send CORS headers:

```
HTTP Response includes:
Access-Control-Allow-Origin: https://app.yourdomain.store
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization

✅ Browser allows request
```

---

## Why Configure CORS in nginx-proxy-manager?

You have **two options** for CORS configuration:

### Option 1: Application-Level CORS (Backend Code)

Configure CORS in your backend application (Node.js, Python, etc.)

**Pros:**
- More granular control
- Can vary by route
- Part of application logic

**Cons:**
- Requires code changes in backend
- Different config per application

### Option 2: Proxy-Level CORS (nginx-proxy-manager)

Configure CORS in nginx-proxy-manager (recommended for PantInventory)

**Pros:**
- ✅ Centralized configuration
- ✅ No code changes needed
- ✅ Consistent across all applications
- ✅ Easy to update (no redeployment)

**Cons:**
- Less granular (applies to all routes)

**For PantInventory, we'll use proxy-level CORS** for simplicity and centralized management.

---

## CORS Configuration in nginx-proxy-manager

### Step 1: Access Your API Proxy Host

1. Access nginx-proxy-manager admin UI:
   ```
   http://YOUR_VPS_IP:81
   ```

2. Go to **Hosts** → **Proxy Hosts**

3. Find your API proxy host (e.g., `api.yourdomain.store`)

4. Click the 3 dots → **Edit**

### Step 2: Add CORS Headers

1. Go to the **Advanced** tab

2. Add this nginx configuration:

```nginx
# CORS Configuration for PantInventory
# Allows frontend to communicate with backend API

# Handle preflight OPTIONS requests
if ($request_method = 'OPTIONS') {
    add_header 'Access-Control-Allow-Origin' 'https://app.yourdomain.store' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
    add_header 'Access-Control-Allow-Credentials' 'true' always;
    add_header 'Access-Control-Max-Age' 3600 always;
    add_header 'Content-Length' 0;
    add_header 'Content-Type' 'text/plain charset=UTF-8';
    return 204;
}

# Add CORS headers to all responses
add_header 'Access-Control-Allow-Origin' 'https://app.yourdomain.store' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
add_header 'Access-Control-Allow-Credentials' 'true' always;
```

3. **Replace** `https://app.yourdomain.store` with your actual frontend domain

4. Click **Save**

---

## Configuration Breakdown

Let's understand each part:

### Preflight Requests (OPTIONS)

```nginx
if ($request_method = 'OPTIONS') {
    # ... CORS headers ...
    return 204;
}
```

**What is a preflight request?**
- Before making certain requests (POST, PUT, DELETE), browsers send an OPTIONS request first
- This asks the server: "Am I allowed to make this request?"
- nginx-proxy-manager must respond with CORS headers and status 204 (No Content)

### CORS Headers

```nginx
add_header 'Access-Control-Allow-Origin' 'https://app.yourdomain.store' always;
```
**Meaning:** Only allow requests from `https://app.yourdomain.store`

```nginx
add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
```
**Meaning:** Allow these HTTP methods

```nginx
add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
```
**Meaning:** Allow these request headers (e.g., Authorization for JWT tokens)

```nginx
add_header 'Access-Control-Allow-Credentials' 'true' always;
```
**Meaning:** Allow cookies and authentication credentials in requests

```nginx
add_header 'Access-Control-Max-Age' 3600 always;
```
**Meaning:** Browser can cache preflight response for 1 hour (reduces OPTIONS requests)

### The `always` Directive

**Important:** The `always` directive ensures headers are added to ALL responses, including error responses (404, 500, etc.)

Without `always`:
- CORS headers only added to 200 OK responses
- Errors (401, 404, 500) don't include CORS headers
- Frontend can't see error details

With `always`:
- CORS headers added to ALL responses
- Frontend can properly handle errors

---

## Multiple Frontend Domains

If you have multiple frontends (e.g., admin panel, mobile app):

### Option 1: List Multiple Domains (Not Recommended)

```nginx
# This does NOT work - nginx only uses last add_header
add_header 'Access-Control-Allow-Origin' 'https://app.yourdomain.store' always;
add_header 'Access-Control-Allow-Origin' 'https://admin.yourdomain.store' always;
```

### Option 2: Dynamic Origin (Recommended)

```nginx
# Map allowed origins
map $http_origin $cors_origin {
    default "";
    "~^https://(app|admin)\.yourdomain\.store$" $http_origin;
}

# Handle preflight OPTIONS
if ($request_method = 'OPTIONS') {
    add_header 'Access-Control-Allow-Origin' $cors_origin always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
    add_header 'Access-Control-Allow-Credentials' 'true' always;
    add_header 'Access-Control-Max-Age' 3600 always;
    add_header 'Content-Length' 0;
    add_header 'Content-Type' 'text/plain charset=UTF-8';
    return 204;
}

# Add CORS headers to all responses
add_header 'Access-Control-Allow-Origin' $cors_origin always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
add_header 'Access-Control-Allow-Credentials' 'true' always;
```

**Explanation:**
- `map $http_origin $cors_origin` creates a variable
- If origin matches regex `https://(app|admin).yourdomain.store`, set `$cors_origin` to that origin
- Otherwise, `$cors_origin` is empty (request denied)

### Option 3: Allow All Origins (NOT Recommended for Production)

```nginx
add_header 'Access-Control-Allow-Origin' '*' always;
```

**Warning:** This allows ANY website to call your API. Only use for:
- Public APIs
- Development/testing
- Never for authenticated APIs

**Note:** `Access-Control-Allow-Credentials: true` does NOT work with `*` origin.

---

## Testing CORS Configuration

### Test 1: Browser DevTools

1. Open frontend in browser: `https://app.yourdomain.store`
2. Open DevTools (F12) → **Console** tab
3. Run this test:

```javascript
fetch('https://api.yourdomain.store/api/test')
  .then(response => response.json())
  .then(data => console.log('Success:', data))
  .catch(error => console.error('Error:', error));
```

**Expected result:**
- ✅ Request succeeds (no CORS error)
- ✅ Response data logged

**If you see CORS error:**
- Check nginx-proxy-manager configuration
- Verify frontend domain matches exactly in CORS config
- Check browser console for specific error message

### Test 2: Network Tab

1. Open DevTools → **Network** tab
2. Make a request from your frontend
3. Click the request → **Headers** tab
4. Look for **Response Headers**:

```
Access-Control-Allow-Origin: https://app.yourdomain.store
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, ...
Access-Control-Allow-Credentials: true
```

**If headers are missing:**
- CORS config not applied
- Check nginx-proxy-manager advanced configuration

### Test 3: Preflight Request (OPTIONS)

1. In DevTools → **Network** tab
2. Filter by **Fetch/XHR**
3. Look for OPTIONS request (usually before POST/PUT/DELETE)
4. Click OPTIONS request → **Headers** tab

**Expected:**
- Status: 204 No Content
- Response headers include CORS headers

**If OPTIONS request fails (403, 404):**
- Preflight handling not configured
- Check `if ($request_method = 'OPTIONS')` block

### Test 4: Command Line (curl)

```bash
# Test GET request
curl -H "Origin: https://app.yourdomain.store" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: Content-Type" \
     -X OPTIONS \
     -v \
     https://api.yourdomain.store/api/test

# Check response headers
# Should include:
# < Access-Control-Allow-Origin: https://app.yourdomain.store
# < Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH, OPTIONS
```

---

## Common CORS Errors

### Error: "No 'Access-Control-Allow-Origin' header present"

**Cause:** CORS headers not configured or not reaching browser

**Fix:**
1. Verify CORS config in nginx-proxy-manager Advanced tab
2. Check `always` directive is present
3. Test with curl to verify headers

### Error: "Origin is not allowed by Access-Control-Allow-Origin"

**Cause:** Frontend domain doesn't match allowed origin

**Fix:**
1. Check frontend domain exactly (with https://)
2. Verify no trailing slash: `https://app.yourdomain.store` (not `.../`)
3. Check for typos

### Error: "Preflight request doesn't pass access control check"

**Cause:** OPTIONS request not handled correctly

**Fix:**
1. Verify `if ($request_method = 'OPTIONS')` block exists
2. Ensure `return 204;` is present
3. Check CORS headers in OPTIONS response

### Error: "Credentials flag is true, but Access-Control-Allow-Credentials is not"

**Cause:** Frontend sends credentials but backend doesn't allow

**Fix:**
```nginx
add_header 'Access-Control-Allow-Credentials' 'true' always;
```

### Error: "Wildcard '*' cannot be used when credentials flag is true"

**Cause:** Using `Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true`

**Fix:**
- Use specific domain instead of `*`
- Or use dynamic origin (see "Multiple Frontend Domains" above)

---

## Security Considerations

### 1. Always Use Specific Origins

**Bad:**
```nginx
add_header 'Access-Control-Allow-Origin' '*' always;
```

**Good:**
```nginx
add_header 'Access-Control-Allow-Origin' 'https://app.yourdomain.store' always;
```

**Why:** Prevents unauthorized websites from accessing your API.

### 2. Use HTTPS Only

**Bad:**
```nginx
add_header 'Access-Control-Allow-Origin' 'http://app.yourdomain.store' always;
```

**Good:**
```nginx
add_header 'Access-Control-Allow-Origin' 'https://app.yourdomain.store' always;
```

**Why:** HTTP is unencrypted and vulnerable to man-in-the-middle attacks.

### 3. Limit Allowed Headers

**Too permissive:**
```nginx
add_header 'Access-Control-Allow-Headers' '*' always;
```

**Better:**
```nginx
add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
```

**Why:** Only allow headers your API actually uses.

### 4. Limit Allowed Methods

**Too permissive:**
```nginx
add_header 'Access-Control-Allow-Methods' '*' always;
```

**Better:**
```nginx
add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
```

**Why:** Only allow HTTP methods your API supports.

### 5. Set Appropriate Max-Age

```nginx
add_header 'Access-Control-Max-Age' 3600 always;  # 1 hour
```

**Why:** Reduces preflight requests (performance) but allows config changes to take effect within reasonable time.

---

## Development vs Production

### Development Configuration

For local development, you might want to allow localhost:

```nginx
# Development: Allow localhost
map $http_origin $cors_origin {
    default "";
    "~^https://(app|admin)\.yourdomain\.store$" $http_origin;
    "~^http://localhost:[0-9]+$" $http_origin;  # Allow localhost:3000, etc.
}
```

### Production Configuration

For production, **only allow production domains**:

```nginx
# Production: Only allow production domains
add_header 'Access-Control-Allow-Origin' 'https://app.yourdomain.store' always;
```

**Tip:** Use environment-specific configurations or different proxy hosts for development vs production.

---

## Alternative: Backend-Level CORS

If you prefer configuring CORS in your backend application:

### Node.js (Express) Example

```javascript
const cors = require('cors');

const corsOptions = {
  origin: 'https://app.yourdomain.store',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin']
};

app.use(cors(corsOptions));
```

### Python (FastAPI) Example

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.yourdomain.store"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Requested-With", "Accept", "Origin"],
)
```

**If you use backend-level CORS:**
- Remove CORS config from nginx-proxy-manager
- Configure in your application code
- Redeploy application when changing CORS settings

---

## Troubleshooting Checklist

When CORS isn't working:

- [ ] CORS headers configured in nginx-proxy-manager Advanced tab
- [ ] `always` directive present on all `add_header` statements
- [ ] Frontend domain exactly matches `Access-Control-Allow-Origin` (with https://)
- [ ] OPTIONS request handler configured (`if ($request_method = 'OPTIONS')`)
- [ ] nginx-proxy-manager reloaded/restarted after config change
- [ ] Browser cache cleared (Ctrl+Shift+R)
- [ ] Headers visible in browser DevTools → Network tab
- [ ] No conflicting CORS config in backend application
- [ ] Firewall allows traffic (ports 80, 443)

---

## Summary

✅ **CORS allows frontend to call backend API** from different domains
✅ **Configure in nginx-proxy-manager** for centralized management
✅ **Always use specific origins** (not `*`) for security
✅ **Handle OPTIONS requests** for preflight checks
✅ **Use `always` directive** to include headers in error responses
✅ **Test with browser DevTools** Network tab
✅ **HTTPS only** for production

**Configuration Template:**

```nginx
# CORS Configuration
if ($request_method = 'OPTIONS') {
    add_header 'Access-Control-Allow-Origin' 'https://app.yourdomain.store' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
    add_header 'Access-Control-Allow-Credentials' 'true' always;
    add_header 'Access-Control-Max-Age' 3600 always;
    add_header 'Content-Length' 0;
    add_header 'Content-Type' 'text/plain charset=UTF-8';
    return 204;
}

add_header 'Access-Control-Allow-Origin' 'https://app.yourdomain.store' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
add_header 'Access-Control-Allow-Credentials' 'true' always;
```

**Next Steps:**
- Test CORS with your frontend application
- Monitor browser console for CORS errors
- Adjust configuration as needed for your specific use case

