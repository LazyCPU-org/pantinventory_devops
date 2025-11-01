# Stage 3: Application Deployment

## Overview

This stage covers setting up automated deployment for your applications (backend and frontend) using GitHub Actions.

**Time Estimate**: 45-60 minutes

---

## What You'll Set Up

1. **GitHub Actions SSH Access** - Secure authentication for automated deployments
2. **Deployment Workflows** - Automatic deployment on code push
3. **Environment Variables** - Secure secrets management via GitHub

---

## Prerequisites

Before starting this stage:

- [ ] Stage 1 completed (VPS with Docker, SSH configured)
- [ ] Stage 2 completed (Docker network and nginx-proxy-manager running)
- [ ] GitHub repository access (admin/owner permissions)
- [ ] Domains configured (for application access)

---

## Quick Overview: Deployment Flow

```
Developer pushes to main branch
        ↓
GitHub Actions triggered
        ↓
Run tests/linting
        ↓
If tests pass → SSH to VPS
        ↓
Pull latest code
        ↓
Build Docker images on VPS
        ↓
Deploy with docker-compose
        ↓
Application running!
```

---

## Setup Steps

### 1. Configure GitHub Actions SSH Access

Follow the [GitHub Actions Setup Guide](./github-actions-setup.md) to:
- Generate SSH key for GitHub Actions on your VPS
- Add private key to GitHub Secrets
- Test the connection

**This is a one-time setup** that enables all future automated deployments.

### 2. Set Up Application Deployment

Follow the [Deployment Guide](./deployment-guide.md) to:
- Create GitHub Actions workflows in your application repositories
- Configure environment variables via GitHub Secrets
- Set up docker-compose to use the infrastructure network
- Test your first automated deployment

---

## Authentication: SSH Keys Only

**GitHub Actions uses SSH key-based authentication** to access your VPS:

- ✅ **Secure**: No passwords stored in GitHub
- ✅ **Auditable**: Each key can be tracked
- ✅ **Revocable**: Remove key to instantly revoke access
- ❌ **Never use username/password**: Insecure and not recommended

See [GitHub Actions Setup](./github-actions-setup.md) for detailed security information.

---

## Files in This Directory

- **README.md** - This file (overview)
- **github-actions-setup.md** - SSH key setup for GitHub Actions
- **deployment-guide.md** - Application deployment workflows and configuration

---

## Next Steps

1. **Start with**: [GitHub Actions Setup](./github-actions-setup.md)
   - Set up SSH access for GitHub Actions
   - Configure GitHub Secrets

2. **Then**: [Deployment Guide](./deployment-guide.md)
   - Create deployment workflows
   - Deploy your applications

3. **Finally**: Configure nginx-proxy-manager
   - Add proxy hosts for your domains
   - Set up SSL certificates
   - See [Stage 2: Network Configuration](../02-network-configuration/README.md)

---

## Summary

After completing Stage 3:
- ✅ GitHub Actions can securely SSH to your VPS
- ✅ Applications deploy automatically on code push
- ✅ Environment variables managed via GitHub Secrets
- ✅ Backend and frontend running on your infrastructure
