# Environment Variables Management Guide

## Overview

This guide explains how to manage environment variables for both **manual deployment** and **automated deployment with GitHub Actions**. Proper environment variable management is critical for security and configuration.

**IMPORTANT SECURITY PRINCIPLES:**
- Never commit `.env` files to git repositories
- Use `.env.example` files as templates (safe to commit)
- Store production secrets securely (not in plaintext files on your laptop)
- Use different values for development and production

---

## Table of Contents

1. [Environment Variables Overview](#environment-variables-overview)
2. [Manual Deployment Setup](#manual-deployment-setup)
3. [GitHub Actions Automated Deployment](#github-actions-automated-deployment)
4. [Security Best Practices](#security-best-practices)
5. [Troubleshooting](#troubleshooting)

---

## Environment Variables Overview

### Backend Variables

Located in: `pantinventory_backend/docker/.env.production`

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `DB_HOST` | PostgreSQL host (use service name in Docker) | `postgres` | Yes |
| `DB_PORT` | PostgreSQL port | `5432` | Yes |
| `DB_USERNAME` | Database username | `postgres` | Yes |
| `DB_PASSWORD` | Database password | `SecurePass123!` | Yes |
| `DB_NAME` | Database name | `pantinventory` | Yes |
| `JWT_SECRET` | Secret key for JWT tokens (min 32 chars) | `your-very-secure-secret-key-here-min-32-chars` | Yes |
| `PORT` | Application port | `3000` | Yes |
| `NODE_ENV` | Environment | `production` | Yes |
| `ADMIN_USERNAME` | Default admin username | `admin` | Yes |
| `ADMIN_PASSWORD` | Default admin password | `Admin@SecurePass123!` | Yes |
| `ADMIN_FIRSTNAME` | Admin first name | `Admin` | No |
| `ADMIN_LASTNAME` | Admin last name | `Sistema` | No |
| `ADMIN_EMAIL` | Admin email | `admin@yourdomain.store` | Yes |

**Note:** `FRONTEND_URL` and `BACKEND_URL` are no longer needed since CORS is handled by nginx.

### Frontend Variables

Located in: `pantinventory_frontend/docker/.env.production`

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `VITE_API_URL` | Backend API URL | `https://api.yourdomain.store/api` | Yes |

**IMPORTANT:** Frontend environment variables are **baked into the build** during `docker build`. You cannot change them after the image is built.

---

## Manual Deployment Setup

### Method 1: Using .env Files (Recommended for Manual Deployment)

This method keeps your secrets in files on the VPS (not on your local machine).

#### Step 1: Create .env Files on VPS

**Backend:**

```bash
# SSH into your VPS
ssh your-user@your-vps-ip

# Navigate to backend docker directory
cd /opt/pantinventory/backend/docker

# Copy the example file
cp .env.production.example .env.production

# Edit with your actual values
nano .env.production
```

Fill in your actual values:

```bash
# Database Configuration
DB_HOST=postgres
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=YourSecureDatabasePassword123!
DB_NAME=pantinventory

# JWT Configuration (MUST be at least 32 characters)
JWT_SECRET=your-production-jwt-secret-key-minimum-32-characters-long

# Application
PORT=3000
NODE_ENV=production

# Default Admin User
ADMIN_USERNAME=admin
ADMIN_PASSWORD=YourSecureAdminPassword123!
ADMIN_FIRSTNAME=Admin
ADMIN_LASTNAME=Sistema
ADMIN_EMAIL=admin@yourdomain.store
```

**Frontend:**

```bash
# Navigate to frontend docker directory
cd /opt/pantinventory/frontend/docker

# Copy the example file
cp .env.production.example .env.production

# Edit with your actual values
nano .env.production
```

Fill in your actual values:

```bash
# API URL - Backend API endpoint
VITE_API_URL=https://api.yourdomain.store/api
```

#### Step 2: Verify .env Files Are Not Tracked by Git

```bash
# Backend
cd /opt/pantinventory/backend
git status

# Frontend
cd /opt/pantinventory/frontend
git status
```

You should NOT see `.env.production` in the output. If you do:

```bash
# Make sure .gitignore includes .env files
echo ".env*" >> .gitignore
echo "!.env.example" >> .gitignore
echo "!.env.production.example" >> .gitignore
```

#### Step 3: Deploy with docker-compose

Docker Compose automatically loads `.env.production` files when you run from the docker directory.

**Backend:**

```bash
cd /opt/pantinventory/backend/docker

# Docker compose will read .env.production automatically
docker compose --env-file .env.production up -d
```

**Frontend:**

```bash
cd /opt/pantinventory/frontend/docker

# Docker compose will read .env.production automatically
docker compose --env-file .env.production build
docker compose up -d
```

**Note:** The frontend build step is separate because environment variables are baked into the build.

---

### Method 2: Export Environment Variables in Shell

This method is useful for quick testing but **NOT recommended for production**.

```bash
# Export variables in your current shell session
export DB_PASSWORD="YourSecurePassword123!"
export JWT_SECRET="your-production-jwt-secret-key-minimum-32-characters-long"
export ADMIN_PASSWORD="YourSecureAdminPassword123!"
export VITE_API_URL="https://api.yourdomain.store/api"

# Then run docker compose
cd /opt/pantinventory/backend/docker
docker compose up -d
```

**Drawbacks:**
- Variables are lost when you close the terminal
- Must re-export every time
- Visible in shell history (security risk)
- Not suitable for automated deployments

---

## GitHub Actions Automated Deployment

For automated deployments, we use **GitHub Secrets** to store sensitive values securely.

### Architecture

```
GitHub Repository
    ↓
GitHub Secrets (encrypted)
    ↓
GitHub Actions Workflow
    ↓
SSH to VPS
    ↓
Create .env files on VPS
    ↓
Deploy with docker compose
```

### Step 1: Add Secrets to GitHub Repository

Go to your repository: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

#### Backend Repository Secrets

| Secret Name | Value | Example |
|-------------|-------|---------|
| `VPS_SSH_PRIVATE_KEY` | SSH private key | (from SSH setup guide) |
| `VPS_HOST` | VPS IP address | `192.168.1.100` |
| `VPS_USER` | SSH username | `pantiadmin` |
| `VPS_PROJECT_PATH` | Backend path on VPS | `/opt/pantinventory/backend` |
| `DB_PASSWORD` | Database password | `YourSecurePassword123!` |
| `JWT_SECRET` | JWT secret (min 32 chars) | `your-jwt-secret-32-chars` |
| `ADMIN_PASSWORD` | Admin password | `AdminPass123!` |
| `ADMIN_EMAIL` | Admin email | `admin@yourdomain.store` |

#### Frontend Repository Secrets

| Secret Name | Value | Example |
|-------------|-------|---------|
| `VPS_SSH_PRIVATE_KEY` | SSH private key | (from SSH setup guide) |
| `VPS_HOST` | VPS IP address | `192.168.1.100` |
| `VPS_USER` | SSH username | `pantiadmin` |
| `VPS_PROJECT_PATH` | Frontend path on VPS | `/opt/pantinventory/frontend` |
| `VITE_API_URL` | Backend API URL | `https://api.yourdomain.store/api` |

### Step 2: Create GitHub Actions Workflow

#### Backend Workflow

Create `.github/workflows/deploy-backend.yml`:

```yaml
name: Deploy Backend to VPS

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.VPS_SSH_PRIVATE_KEY }}

      - name: Add VPS to known hosts
        run: |
          mkdir -p ~/.ssh
          ssh-keyscan -H ${{ secrets.VPS_HOST }} >> ~/.ssh/known_hosts

      - name: Deploy Backend to VPS
        env:
          VPS_USER: ${{ secrets.VPS_USER }}
          VPS_HOST: ${{ secrets.VPS_HOST }}
          PROJECT_PATH: ${{ secrets.VPS_PROJECT_PATH }}
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          JWT_SECRET: ${{ secrets.JWT_SECRET }}
          ADMIN_PASSWORD: ${{ secrets.ADMIN_PASSWORD }}
          ADMIN_EMAIL: ${{ secrets.ADMIN_EMAIL }}
        run: |
          ssh $VPS_USER@$VPS_HOST << 'ENDSSH'
            set -e

            cd ${{ secrets.VPS_PROJECT_PATH }}

            # Pull latest code
            git pull origin main

            # Navigate to docker directory
            cd docker

            # Create .env.production file with secrets
            cat > .env.production << EOF
          DB_HOST=postgres
          DB_PORT=5432
          DB_USERNAME=postgres
          DB_PASSWORD=${{ secrets.DB_PASSWORD }}
          DB_NAME=pantinventory
          JWT_SECRET=${{ secrets.JWT_SECRET }}
          PORT=3000
          NODE_ENV=production
          ADMIN_USERNAME=admin
          ADMIN_PASSWORD=${{ secrets.ADMIN_PASSWORD }}
          ADMIN_FIRSTNAME=Admin
          ADMIN_LASTNAME=Sistema
          ADMIN_EMAIL=${{ secrets.ADMIN_EMAIL }}
          EOF

            # Deploy with docker compose
            docker compose --env-file .env.production down
            docker compose --env-file .env.production build
            docker compose --env-file .env.production up -d

            # Verify deployment
            docker compose ps
          ENDSSH

      - name: Verify Deployment
        run: |
          echo "Backend deployed successfully!"
          echo "Check health at: https://api.yourdomain.store/health"
```

#### Frontend Workflow

Create `.github/workflows/deploy-frontend.yml`:

```yaml
name: Deploy Frontend to VPS

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.VPS_SSH_PRIVATE_KEY }}

      - name: Add VPS to known hosts
        run: |
          mkdir -p ~/.ssh
          ssh-keyscan -H ${{ secrets.VPS_HOST }} >> ~/.ssh/known_hosts

      - name: Deploy Frontend to VPS
        env:
          VPS_USER: ${{ secrets.VPS_USER }}
          VPS_HOST: ${{ secrets.VPS_HOST }}
          PROJECT_PATH: ${{ secrets.VPS_PROJECT_PATH }}
          VITE_API_URL: ${{ secrets.VITE_API_URL }}
        run: |
          ssh $VPS_USER@$VPS_HOST << 'ENDSSH'
            set -e

            cd ${{ secrets.VPS_PROJECT_PATH }}

            # Pull latest code
            git pull origin main

            # Navigate to docker directory
            cd docker

            # Create .env.production file with build args
            cat > .env.production << EOF
          VITE_API_URL=${{ secrets.VITE_API_URL }}
          EOF

            # Build and deploy with docker compose
            # Frontend needs rebuild when env vars change
            docker compose --env-file .env.production down
            docker compose --env-file .env.production build --no-cache
            docker compose --env-file .env.production up -d

            # Verify deployment
            docker compose ps
          ENDSSH

      - name: Verify Deployment
        run: |
          echo "Frontend deployed successfully!"
          echo "Check at: https://app.yourdomain.store"
```

### Step 3: Test GitHub Actions Deployment

1. Push a commit to the `main` branch
2. Go to `Actions` tab in GitHub
3. Watch the workflow run
4. Check logs for any errors

---

## Security Best Practices

### 1. Never Commit Secrets

**Bad:**
```bash
# NEVER DO THIS
git add .env.production
git commit -m "Add production config"
```

**Good:**
```bash
# Make sure .gitignore excludes .env files
cat .gitignore | grep "\.env"
# Should show: .env*
```

### 2. Use Strong Secrets

**JWT_SECRET Requirements:**
- Minimum 32 characters
- Mix of uppercase, lowercase, numbers, and symbols
- Use a password generator

```bash
# Generate secure JWT secret (Linux/Mac)
openssl rand -base64 48

# Output example:
# k7n2B9xP4mQ8jL5wR3vT1yU6hG0fD2aS9cX7eN4bM1zK3pJ5qW8
```

**Database Password Requirements:**
- Minimum 16 characters
- Mix of character types
- Not based on dictionary words

### 3. Rotate Secrets Regularly

**Schedule:**
- JWT_SECRET: Every 6 months
- Database passwords: Every 6-12 months
- Admin password: Every 3 months or after team changes

**How to rotate:**
1. Generate new secret
2. Update GitHub Secrets (or .env file on VPS)
3. Redeploy application
4. Verify everything works
5. Update any documentation

### 4. Limit Access

**GitHub Repository:**
- Only admins should manage GitHub Secrets
- Review repository access quarterly
- Use team permissions, not individual access

**VPS:**
- .env files should have restricted permissions:
  ```bash
  chmod 600 .env.production
  ```
- Only deployment user should access `/opt/pantinventory`

### 5. Audit and Monitor

**Check who accessed secrets:**
```bash
# On VPS: Check file access
ls -la /opt/pantinventory/*/docker/.env.production

# Check recent modifications
find /opt/pantinventory -name ".env.production" -ls
```

**GitHub:**
- Review Actions logs regularly
- Check for failed authentication attempts
- Monitor unusual deployment patterns

---

## Troubleshooting

### Issue: "Environment variable not set"

**Symptom:**
```
Error: JWT_SECRET is not defined
```

**Solution:**
```bash
# Verify .env file exists
ls -la /opt/pantinventory/backend/docker/.env.production

# Verify file contents (check secret values are not empty)
cat /opt/pantinventory/backend/docker/.env.production

# Make sure docker compose uses the env file
docker compose --env-file .env.production config
# This shows the resolved configuration
```

### Issue: "Frontend shows wrong API URL"

**Symptom:** Frontend tries to connect to `http://localhost:3000/api` instead of your production API.

**Cause:** Environment variables are baked into the build. If you change `VITE_API_URL` after building, it won't take effect.

**Solution:**
```bash
# Rebuild the frontend with --no-cache
cd /opt/pantinventory/frontend/docker
docker compose --env-file .env.production build --no-cache
docker compose up -d
```

### Issue: "Permission denied reading .env file"

**Symptom:**
```
Error: EACCES: permission denied, open '.env.production'
```

**Solution:**
```bash
# Fix file permissions
chmod 600 /opt/pantinventory/*/docker/.env.production

# Fix ownership
sudo chown $USER:$USER /opt/pantinventory/*/docker/.env.production
```

### Issue: "GitHub Actions can't create .env file on VPS"

**Symptom:** Deployment fails with "permission denied" when creating .env file.

**Solution:**
```bash
# On VPS: Ensure deployment user owns the directories
sudo chown -R $USER:$USER /opt/pantinventory

# Verify permissions
ls -la /opt/pantinventory/*/docker/
```

---

## Summary Checklist

### Manual Deployment
- [ ] `.env.production` files created on VPS
- [ ] All required variables filled in
- [ ] Strong passwords and secrets used
- [ ] File permissions set to 600
- [ ] Files not tracked by git
- [ ] Applications deployed successfully

### GitHub Actions Deployment
- [ ] All secrets added to GitHub repository
- [ ] Workflow files created (`.github/workflows/`)
- [ ] SSH access configured (see [Application Deployment](03-application-deployment/README.md))
- [ ] Test deployment successful
- [ ] Health checks passing

---

## Additional Resources

- [Application Deployment Guide](03-application-deployment/README.md)
- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)
- [Vite Environment Variables](https://vitejs.dev/guide/env-and-mode.html)
- [12-Factor App Config](https://12factor.net/config)
