# Stage 2: Automated Deployment Setup

## Overview

This stage covers setting up automated CI/CD deployments for PantInventory using GitHub Actions. After completing this stage, pushing code to your repository will automatically deploy to your VPS.

## Deployment Architecture

```
┌──────────────────┐
│  Developer PC    │
│                  │
│  git push main   │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────┐
│      GitHub Repository           │
│  (Backend or Frontend)           │
└────────┬─────────────────────────┘
         │
         │ Triggers
         ▼
┌──────────────────────────────────┐
│    GitHub Actions Workflow       │
│                                  │
│  1. Run Tests                    │
│  2. Run Linter                   │
│  3. Build Check                  │
└────────┬─────────────────────────┘
         │
         │ If tests pass
         ▼
┌──────────────────────────────────┐
│    SSH to VPS                    │
│                                  │
│  1. Pull latest code             │
│  2. Create .env from secrets     │
│  3. Build Docker images          │
│  4. Deploy containers            │
│  5. Run migrations (backend)     │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│    Application Running on VPS    │
│                                  │
│  ✅ Backend + Database           │
│  ✅ Frontend                     │
└──────────────────────────────────┘
```

## Objectives

- Configure GitHub Secrets for secure credential management
- Set up automated CI/CD pipelines for backend and frontend
- Enable automatic deployments on push to main branch
- Implement pre-deployment testing
- Configure environment-specific deployments (staging/production)

## Prerequisites

Before starting this stage, ensure you have completed:

- ✅ [Stage 1: Server Setup](../01-server-setup/README.md)
- ✅ VPS accessible via SSH with key-based authentication
- ✅ Docker and Docker Compose installed on VPS
- ✅ GitHub repository access (admin/owner permissions)

## Time Estimate

- **Initial Setup:** 1-2 hours
- **Testing & Verification:** 30 minutes
- **Total:** 1.5-2.5 hours

---

## Quick Start Guide

### 1. Run VPS Initial Setup

On your VPS, run the setup script:

```bash
# Clone the devops repository (or download the script)
git clone https://github.com/YOUR_USERNAME/pantinventory_devops.git /tmp/pantinventory_devops

# Run the setup script
cd /tmp/pantinventory_devops
./scripts/vps-initial-setup.sh
```

This script will:
- Create project directories (`/opt/pantinventory/backend` and `/opt/pantinventory/frontend`)
- Create Docker network (`pantinventory_network`)
- Clone backend and frontend repositories
- Generate SSH key for GitHub Actions
- Display the private key to add to GitHub Secrets

**Important:** Copy the SSH private key displayed at the end - you'll need it for GitHub Secrets.

### 2. Configure GitHub Secrets

Follow the [GitHub Secrets Setup Guide](./github-secrets-setup.md) to add required secrets to your repositories.

**Quick Reference - Required Secrets:**

#### Both Repositories:
- `VPS_SSH_PRIVATE_KEY` (from step 1)
- `VPS_HOST` (your VPS IP)
- `VPS_USER` (your SSH username)

#### Backend Repository:
- `VPS_BACKEND_PATH` = `/opt/pantinventory/backend`
- `DB_PASSWORD`, `JWT_SECRET`, `ADMIN_PASSWORD`
- `FRONTEND_URL`, `BACKEND_URL`

#### Frontend Repository:
- `VPS_FRONTEND_PATH` = `/opt/pantinventory/frontend`
- `VITE_API_URL` (or `BACKEND_URL`)

### 3. Copy Workflow Files to Your Repositories

#### Backend Repository

```bash
# Navigate to your backend repository
cd pantinventory_backend

# Create .github/workflows directory if it doesn't exist
mkdir -p .github/workflows

# Copy the template workflow
cp ../pantinventory_devops/workflows/templates/backend-ci-cd.yml .github/workflows/deploy.yml

# Commit and push
git add .github/workflows/deploy.yml
git commit -m "Add automated CI/CD deployment workflow"
git push origin main
```

#### Frontend Repository

```bash
# Navigate to your frontend repository
cd pantinventory_frontend

# Create .github/workflows directory if it doesn't exist
mkdir -p .github/workflows

# Copy the template workflow
cp ../pantinventory_devops/workflows/templates/frontend-ci-cd.yml .github/workflows/deploy.yml

# Commit and push
git add .github/workflows/deploy.yml
git commit -m "Add automated CI/CD deployment workflow"
git push origin main
```

### 4. Test Your First Deployment

Once workflows are added:

1. Go to your repository on GitHub
2. Click **Actions** tab
3. You should see the workflow running (triggered by your push)
4. Monitor the deployment logs
5. Verify deployment succeeded

---

## Detailed Setup Instructions

### Understanding the Deployment Flow

#### Backend Deployment Flow

1. **Trigger**: Push to `main` or `staging` branch
2. **Test Job**:
   - Install dependencies
   - Run linter
   - Run tests
   - Build application
3. **Deploy Job** (only if tests pass):
   - SSH to VPS
   - Pull latest code
   - Create `.env` file from GitHub Secrets
   - Build Docker images
   - Deploy containers
   - Run database migrations
   - Health check
   - Cleanup old images

#### Frontend Deployment Flow

1. **Trigger**: Push to `main` or `staging` branch
2. **Test Job**:
   - Install dependencies
   - Run linter (if configured)
   - Build application
3. **Deploy Job** (only if build succeeds):
   - SSH to VPS
   - Pull latest code
   - Create `.env` file from GitHub Secrets
   - Build Docker image
   - Deploy container
   - Health check
   - Cleanup old images

### Manual Deployment Trigger

You can also trigger deployments manually:

1. Go to **Actions** tab in your repository
2. Select the deployment workflow
3. Click **Run workflow**
4. Choose options:
   - Branch to deploy
   - Run migrations (backend only)
   - Force rebuild
5. Click **Run workflow**

---

## Environment-Specific Deployments

### Staging vs Production

The workflows support both staging and production environments:

#### Setup Staging Environment

1. Create a `staging` branch:
   ```bash
   git checkout -b staging
   git push origin staging
   ```

2. Add environment-specific secrets in GitHub:
   - Go to Settings → Environments → New environment
   - Name: `staging`
   - Add environment-specific secrets (different DB passwords, URLs, etc.)

3. Push to `staging` branch to deploy to staging environment

#### Production Deployment

- Push to `main` branch to deploy to production
- Use separate GitHub Secrets for production

---

## Workflow Configuration Options

### Backend Workflow Options

When manually triggering the backend workflow:

| Option | Description | Default |
|--------|-------------|---------|
| `run_migrations` | Run database migrations after deployment | `true` |
| `rebuild` | Force rebuild Docker images (no cache) | `false` |

### Frontend Workflow Options

When manually triggering the frontend workflow:

| Option | Description | Default |
|--------|-------------|---------|
| `rebuild` | Force rebuild Docker images (no cache) | `false` |

---

## Monitoring Deployments

### GitHub Actions Dashboard

1. Go to your repository
2. Click **Actions** tab
3. View recent workflow runs
4. Click on a run to see detailed logs

### VPS Monitoring

SSH to your VPS and check:

```bash
# Check running containers
docker ps

# View backend logs
cd /opt/pantinventory/backend
docker compose -f docker/docker-compose.yml logs -f app

# View frontend logs
cd /opt/pantinventory/frontend
docker compose -f docker/docker-compose.yml logs -f frontend

# Check database
cd /opt/pantinventory/backend
docker compose -f docker/docker-compose.yml logs -f postgres
```

---

## Troubleshooting

### Common Issues

#### 1. SSH Connection Failed

**Error**: `Permission denied (publickey)`

**Solution**:
- Verify `VPS_SSH_PRIVATE_KEY` secret is correct
- Ensure public key is in `~/.ssh/authorized_keys` on VPS
- Check `VPS_HOST` and `VPS_USER` are correct

#### 2. Tests Failing

**Error**: Tests fail during CI

**Solution**:
- Run tests locally: `npm test`
- Fix failing tests before pushing
- Check test environment configuration

#### 3. Docker Build Fails

**Error**: Docker build fails on VPS

**Solution**:
- Check VPS has enough disk space: `df -h`
- Verify Dockerfile syntax
- Try manual build: `docker compose build --no-cache`
- Check VPS resources: `free -h` (RAM)

#### 4. Environment Variables Not Working

**Error**: Application can't read env vars

**Solution**:
- Verify GitHub Secrets are set correctly
- Check secret names match workflow file
- Review `.env` file creation in workflow logs
- SSH to VPS and check: `cat /opt/pantinventory/backend/.env`

#### 5. Migrations Fail

**Error**: Database migrations fail

**Solution**:
- Ensure database is running: `docker ps`
- Check database logs: `docker compose logs postgres`
- Verify database credentials in secrets
- Try running migrations manually on VPS

---

## Security Considerations

### Secrets Management

- ✅ All sensitive data stored in GitHub Secrets
- ✅ Secrets never committed to repository
- ✅ Secrets masked in workflow logs
- ✅ Different secrets for staging/production

### SSH Security

- ✅ Dedicated SSH key for deployments
- ✅ Key-based authentication only
- ✅ Limited permissions on deployment key
- ✅ Regular key rotation (recommended every 6-12 months)

### Best Practices

1. **Use strong secrets**: Generate cryptographically secure random strings
2. **Rotate regularly**: Update passwords and keys periodically
3. **Limit access**: Only grant repository access to trusted team members
4. **Monitor logs**: Regularly review GitHub Actions logs for suspicious activity
5. **Use environments**: Separate staging and production with different secrets
6. **Audit trail**: GitHub Actions provides full audit trail of deployments

---

## Next Steps

After completing automated deployment setup:

1. ✅ Test a deployment by pushing a small change
2. ✅ Set up staging environment (optional)
3. ✅ Configure monitoring and alerting
4. ✅ Proceed to [Stage 3: Reverse Proxy Setup](../03-reverse-proxy/README.md)

---

## Files in This Directory

- [README.md](./README.md) - This file
- [github-secrets-setup.md](./github-secrets-setup.md) - Detailed GitHub Secrets configuration
- [troubleshooting.md](./troubleshooting.md) - Common deployment issues and solutions
- [rollback-guide.md](./rollback-guide.md) - How to rollback failed deployments

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Workflow Templates](../../workflows/templates/)
- [VPS Setup Script](../../scripts/vps-initial-setup.sh)

---

## Support

If you encounter issues:

1. Check the [troubleshooting guide](./troubleshooting.md)
2. Review GitHub Actions logs for errors
3. Check VPS logs: `docker compose logs`
4. Verify all secrets are configured correctly

---

## Summary Checklist

Before proceeding to the next stage:

- [ ] VPS initial setup script executed successfully
- [ ] Docker network `pantinventory_network` created
- [ ] Backend and frontend repositories cloned to VPS
- [ ] GitHub Secrets configured in both repositories
- [ ] Workflow files copied to backend and frontend repos
- [ ] First deployment tested and succeeded
- [ ] Application accessible on VPS
- [ ] Database migrations completed successfully
- [ ] Logs show no errors

Once all items are checked, you're ready for [Stage 3: Reverse Proxy Setup](../03-reverse-proxy/README.md)!
