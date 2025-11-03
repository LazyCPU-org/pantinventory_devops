# Stage 3: Application Deployment with GitHub Actions

## Overview

This stage covers setting up automated CI/CD deployments for PantInventory using GitHub Actions. After completing this stage, pushing code to your repository will automatically deploy to your VPS with a dedicated deployment user for security.

**Time Estimate**: 1.5-2.5 hours

---

## Table of Contents

1. [Deployment Architecture](#deployment-architecture)
2. [Prerequisites](#prerequisites)
3. [Step 1: Create Dedicated Deployment User](#step-1-create-dedicated-deployment-user)
4. [Step 2: Configure SSH Keys](#step-2-configure-ssh-keys)
5. [Step 3: Configure GitHub Secrets](#step-3-configure-github-secrets)
6. [Step 4: Setup Deployment Workflows](#step-4-setup-deployment-workflows)
7. [Step 5: Test Your First Deployment](#step-5-test-your-first-deployment)
8. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
9. [Security Best Practices](#security-best-practices)

---

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
│    (as github-deployer user)     │
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

---

## Prerequisites

Before starting this stage, ensure you have:

- ✅ [Stage 1: Server Setup](../01-server-setup/README.md) completed
- ✅ [Stage 2: Network Configuration](../02-network-configuration/README.md) completed
- ✅ VPS accessible via SSH with your personal account
- ✅ Docker and Docker Compose installed on VPS
- ✅ GitHub repository access (admin/owner permissions)
- ✅ sudo access on your VPS

---

## Step 1: Create Dedicated Deployment User

For security best practices, we'll create a dedicated user (`github-deployer`) that GitHub Actions will use to deploy applications. This user will have limited permissions and cannot be used for interactive login.

### 1.1 Create the Deployment User

SSH to your VPS with your personal account and run:

```bash
# Create system user for GitHub Actions deployments
sudo useradd -r -m -d /home/github-deployer -s /bin/bash github-deployer

# Create .ssh directory for the new user
sudo mkdir -p /home/github-deployer/.ssh
sudo chown github-deployer:github-deployer /home/github-deployer/.ssh
sudo chmod 700 /home/github-deployer/.ssh
```

**What this does:**

- `-r`: Creates a system user (UID < 1000)
- `-m`: Creates home directory
- `-d /home/github-deployer`: Specifies home directory location
- `-s /bin/bash`: Sets shell (needed for SSH commands)

### 1.2 Set Up Project Directories

Create the application directories with shared group access so both your user and `github-deployer` can manage deployments:

```bash
# Create a deployment group for shared access
sudo groupadd deploygroup

# Add both your user and github-deployer to the group
sudo usermod -aG deploygroup $USER
sudo usermod -aG deploygroup github-deployer

# Create project directory structure
sudo mkdir -p /opt/pantinventory/backend
sudo mkdir -p /opt/pantinventory/frontend

# Set ownership: github-deployer as owner, deploygroup as group
sudo chown -R github-deployer:deploygroup /opt/pantinventory

# Set permissions: owner and group can read/write
sudo chmod -R g+w /opt/pantinventory

# Set SGID bit so new files inherit the group
sudo find /opt/pantinventory -type d -exec chmod g+s {} \;

# Verify permissions
ls -la /opt/pantinventory
# Should show: drwxrwsr-x ... github-deployer deploygroup

# Log out and back in for group changes to take effect
# Or run: newgrp deploygroup
```

**What this does:**

- Creates a shared group (`deploygroup`) for deployment access
- Both you and `github-deployer` can read/write to `/opt/pantinventory`
- SGID bit ensures new files inherit the group ownership
- Allows manual deployments from your account when needed

### 1.3 Configure Docker Access

The deployment user needs access to Docker to manage containers:

```bash
# Add deployment user to docker group
sudo usermod -aG docker github-deployer

# Verify group membership
groups github-deployer
# Should show: github-deployer : github-deployer docker
```

### 1.4 Configure Sudo Access (Optional)

If your deployment requires sudo commands (typically not needed), create a sudoers file:

```bash
# Create sudoers file for deployment user
sudo visudo -f /etc/sudoers.d/github-deployer
```

Add this content (only if needed):

```
# Allow github-deployer to run docker commands without password
github-deployer ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/local/bin/docker-compose
```

**Note:** For most deployments, docker group membership is sufficient and sudo is not required.

### 1.5 Verify User Setup

```bash
# Check user exists
id github-deployer

# Check home directory
sudo ls -la /home/github-deployer

# Check project directory ownership
ls -la /opt/pantinventory
```

---

## Step 2: Configure SSH Keys

We'll create **two SSH keys** for different purposes:

1. **GitHub VPS Key**: Allows VPS to clone/pull from GitHub repositories
2. **GitHub Actions Deploy Key**: Allows GitHub Actions to SSH into VPS

### 2.1 Generate GitHub VPS SSH Key (for Git Operations)

This key allows the deployment user to access GitHub repositories:

```bash
# Switch to deployment user
sudo -u github-deployer bash

# Generate SSH key for GitHub access
ssh-keygen -t ed25519 -C "github-deployer-git-access" -f ~/.ssh/github_vps -N ""

# Verify key was created
ls -la ~/.ssh/github_vps*
# Should show:
# github_vps       (private key)
# github_vps.pub   (public key)

# Display public key
cat ~/.ssh/github_vps.pub

# Exit back to your user
exit
```

**Add this public key to GitHub:**

1. Copy the output from `cat ~/.ssh/github_vps.pub`
2. Go to GitHub: [https://github.com/settings/keys](https://github.com/settings/keys)
3. Click **"New SSH key"**
4. Title: `VPS Deployment User - Git Access`
5. Paste the public key
6. Click **"Add SSH key"**

### 2.2 Configure SSH for GitHub Access

Configure the deployment user's SSH to use the correct key for GitHub:

```bash
# Switch to deployment user
sudo -u github-deployer bash

# Create SSH config
cat > ~/.ssh/config << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_vps
    IdentitiesOnly yes
EOF

# Set correct permissions
chmod 600 ~/.ssh/config

# Exit back to your user
exit
```

### 2.3 Test GitHub SSH Connection

```bash
# Test as deployment user
sudo -u github-deployer ssh -T git@github.com
# You should see: "Hi username! You've successfully authenticated..."
```

### 2.4 Generate GitHub Actions Deploy SSH Key

This key allows GitHub Actions to SSH into your VPS as the deployment user:

```bash
# Switch to deployment user
sudo -u github-deployer bash

# Generate SSH key for GitHub Actions
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy -N ""

# Verify keys were created
ls -la ~/.ssh/github_actions_deploy*
# Should show:
# github_actions_deploy       (private key)
# github_actions_deploy.pub   (public key)

# Exit back to your user
exit
```

**Note**: The `-N ""` flag creates a key without a passphrase, which is required for automated deployments.

### 2.5 Authorize GitHub Actions Deploy Key

Add the GitHub Actions public key to the deployment user's authorized_keys:

```bash
# Add public key to authorized_keys
sudo -u github-deployer bash -c "cat ~/.ssh/github_actions_deploy.pub >> ~/.ssh/authorized_keys"

# Set correct permissions
sudo -u github-deployer chmod 600 ~/.ssh/authorized_keys

# Verify
sudo cat /home/github-deployer/.ssh/authorized_keys
```

### 2.6 Copy GitHub Actions Private Key

Display and copy the private key (you'll add this to GitHub Secrets):

```bash
sudo cat /home/github-deployer/.ssh/github_actions_deploy
```

**Copy the entire output**, including:

- `-----BEGIN OPENSSH PRIVATE KEY-----`
- All lines in between
- `-----END OPENSSH PRIVATE KEY-----`

**⚠️ SECURITY WARNING:**

- This private key will be stored in GitHub Secrets (encrypted)
- Never commit this key to any repository
- Never share it via email, Slack, or insecure channels
- Store it temporarily in a secure password manager if needed

### 2.7 Test GitHub Actions SSH Connection

From your local machine, test the connection:

```bash
# Save the private key to a temporary file
cat > /tmp/test_deploy_key << 'EOF'
(paste the private key here)
EOF

chmod 600 /tmp/test_deploy_key

# Test connection
ssh -i /tmp/test_deploy_key github-deployer@YOUR_VPS_IP "echo 'Connection successful'"

# Clean up
rm /tmp/test_deploy_key
```

If you see "Connection successful", the setup is correct.

### SSH Keys Summary

You now have two SSH keys configured:

| Key Name                | Purpose                     | Public Key Location   | Private Key Location                        | Used By                  |
| ----------------------- | --------------------------- | --------------------- | ------------------------------------------- | ------------------------ |
| `github_vps`            | VPS accesses GitHub repos   | GitHub SSH keys       | VPS `/home/github-deployer/.ssh/github_vps` | VPS git operations       |
| `github_actions_deploy` | GitHub Actions accesses VPS | VPS `authorized_keys` | GitHub Secrets                              | GitHub Actions workflows |

**Authentication Flow:**

```
┌─────────────────────────────────────────────────────────────┐
│                       GitHub.com                            │
└─────────────────────────────────────────────────────────────┘
           ▲                                  ▲
           │                                  │
           │ (1) git clone/pull               │ (3) workflow triggered
           │ Uses: github_vps key             │
           │                                  │
    ┌──────┴──────────┐              ┌───────┴────────┐
    │   Your VPS      │              │ GitHub Actions │
    │                 │              │                │
    │ User:           │◄─────(2)─────┤   Secrets:     │
    │ github-deployer │   SSH into   │   VPS_SSH_     │
    │                 │   VPS        │   PRIVATE_KEY  │
    │ ~/.ssh/         │              │                │
    │ github_vps      │              │                │
    │ github_actions_ │              │                │
    │   deploy        │              │                │
    └─────────────────┘              └────────────────┘
```

---

## Step 3: Configure GitHub Secrets

You need to configure GitHub Secrets for **each application repository** (backend and frontend).

### 3.1 Add Secrets to Backend Repository

Go to your backend repository on GitHub:

1. Navigate to: `Settings` → `Secrets and variables` → `Actions`
2. Click `New repository secret`

Add these secrets:

| Secret Name           | Value                     | Example                                  |
| --------------------- | ------------------------- | ---------------------------------------- |
| `VPS_SSH_PRIVATE_KEY` | Private key from Step 2.6 | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `VPS_HOST`            | Your VPS IP address       | `192.168.1.100`                          |
| `VPS_USER`            | Deployment user           | `github-deployer`                        |
| `VPS_PROJECT_PATH`    | Backend deployment path   | `/opt/pantinventory/backend`             |
| `DB_PASSWORD`         | Database password         | Generate strong password                 |
| `JWT_SECRET`          | JWT secret key            | Generate random string (32+ chars)       |
| `ADMIN_PASSWORD`      | Admin user password       | Generate strong password                 |

**Generate secure secrets:**

```bash
# Generate random passwords/secrets
openssl rand -base64 32
```

### 3.2 Add Secrets to Frontend Repository

Go to your frontend repository on GitHub and add:

| Secret Name           | Value                          | Example                                    |
| --------------------- | ------------------------------ | ------------------------------------------ |
| `VPS_SSH_PRIVATE_KEY` | Same private key from Step 2.6 | `-----BEGIN OPENSSH PRIVATE KEY-----...`   |
| `VPS_HOST`            | Your VPS IP address            | `192.168.1.100`                            |
| `VPS_USER`            | Deployment user                | `github-deployer`                          |
| `VPS_PROJECT_PATH`    | Frontend deployment path       | `/opt/pantinventory/frontend`              |
| `VITE_API_URL`        | Backend API URL                | `https://api.pantinventory.yourdomain.com` |

### 3.3 Verify Secrets

After adding secrets, verify they appear in the list (values will be hidden):

```
VPS_SSH_PRIVATE_KEY    ••••••••
VPS_HOST               ••••••••
VPS_USER               ••••••••
VPS_PROJECT_PATH       ••••••••
...
```

---

## Step 4: Setup Deployment Workflows

### 4.1 Clone Repositories on VPS

First, clone your repositories to the VPS as the deployment user:

```bash
# Switch to deployment user
sudo -u github-deployer bash

# Clone backend
git clone git@github.com:YOUR_USERNAME/pantinventory_backend.git /opt/pantinventory/backend

# Clone frontend
git clone git@github.com:YOUR_USERNAME/pantinventory_frontend.git /opt/pantinventory/frontend

# Configure git for both repos
cd /opt/pantinventory/backend
git config pull.rebase false

cd /opt/pantinventory/frontend
git config pull.rebase false

# Exit back to your user
exit
```

**Configure Git safe directories for your personal user:**

Since the repositories are owned by `github-deployer`, you need to mark them as safe for your user to access:

```bash
# As your personal user (not github-deployer)
git config --global --add safe.directory /opt/pantinventory/backend
git config --global --add safe.directory /opt/pantinventory/frontend

# Verify you can now access the repos
cd /opt/pantinventory/backend
git status
```

This is a Git security feature introduced in Git 2.35.2 that prevents accessing repositories owned by other users.

### 4.2 Add Workflow to Backend Repository

On your local machine, navigate to your backend repository:

```bash
# Navigate to backend repo
cd pantinventory_backend

# Create workflows directory
mkdir -p .github/workflows

# Create deployment workflow
cat > .github/workflows/deploy.yml << 'EOF'
name: Deploy Backend to VPS

on:
  push:
    branches: [main, staging]
  workflow_dispatch:
    inputs:
      run_migrations:
        description: 'Run database migrations'
        required: false
        default: 'true'
      rebuild:
        description: 'Force rebuild (no cache)'
        required: false
        default: 'false'

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

      - name: Run tests
        run: npm test

      - name: Build check
        run: npm run build

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/staging'

    steps:
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.VPS_SSH_PRIVATE_KEY }}

      - name: Add VPS to known hosts
        run: |
          mkdir -p ~/.ssh
          ssh-keyscan -H ${{ secrets.VPS_HOST }} >> ~/.ssh/known_hosts

      - name: Deploy to VPS
        env:
          VPS_USER: ${{ secrets.VPS_USER }}
          VPS_HOST: ${{ secrets.VPS_HOST }}
          PROJECT_PATH: ${{ secrets.VPS_PROJECT_PATH }}
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          JWT_SECRET: ${{ secrets.JWT_SECRET }}
          ADMIN_PASSWORD: ${{ secrets.ADMIN_PASSWORD }}
          FRONTEND_URL: ${{ secrets.FRONTEND_URL }}
          BACKEND_URL: ${{ secrets.BACKEND_URL }}
          RUN_MIGRATIONS: ${{ github.event.inputs.run_migrations || 'true' }}
          REBUILD: ${{ github.event.inputs.rebuild || 'false' }}
        run: |
          ssh $VPS_USER@$VPS_HOST << 'ENDSSH'
            set -e

            echo "Deploying backend to $PROJECT_PATH"
            cd $PROJECT_PATH

            # Pull latest code
            echo "Pulling latest code..."
            git pull origin ${{ github.ref_name }}

            # Create .env file
            echo "Creating .env file..."
            cat > .env << EOF
          DB_HOST=postgres
          DB_PORT=5432
          DB_NAME=pantinventory
          DB_USER=postgres
          DB_PASSWORD=$DB_PASSWORD
          JWT_SECRET=$JWT_SECRET
          ADMIN_PASSWORD=$ADMIN_PASSWORD
          FRONTEND_URL=$FRONTEND_URL
          BACKEND_URL=$BACKEND_URL
          NODE_ENV=production
          EOF

            # Build and deploy
            echo "Building Docker images..."
            if [ "$REBUILD" = "true" ]; then
              docker compose -f docker/docker-compose.yml build --no-cache
            else
              docker compose -f docker/docker-compose.yml build
            fi

            echo "Deploying containers..."
            docker compose -f docker/docker-compose.yml up -d

            # Run migrations
            if [ "$RUN_MIGRATIONS" = "true" ]; then
              echo "Running database migrations..."
              docker compose -f docker/docker-compose.yml exec -T app npm run migrate
            fi

            # Health check
            echo "Waiting for application to start..."
            sleep 10

            # Verify containers are running
            docker compose -f docker/docker-compose.yml ps

            # Cleanup old images
            echo "Cleaning up old Docker images..."
            docker image prune -f

            echo "Deployment completed successfully!"
          ENDSSH
EOF

# Commit and push
git add .github/workflows/deploy.yml
git commit -m "Add automated CI/CD deployment workflow"
git push origin main
```

### 4.3 Add Workflow to Frontend Repository

Navigate to your frontend repository:

```bash
# Navigate to frontend repo
cd pantinventory_frontend

# Create workflows directory
mkdir -p .github/workflows

# Create deployment workflow
cat > .github/workflows/deploy.yml << 'EOF'
name: Deploy Frontend to VPS

on:
  push:
    branches: [main, staging]
  workflow_dispatch:
    inputs:
      rebuild:
        description: 'Force rebuild (no cache)'
        required: false
        default: 'false'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint || true

      - name: Build application
        run: npm run build
        env:
          VITE_API_URL: ${{ secrets.VITE_API_URL }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/staging'

    steps:
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.VPS_SSH_PRIVATE_KEY }}

      - name: Add VPS to known hosts
        run: |
          mkdir -p ~/.ssh
          ssh-keyscan -H ${{ secrets.VPS_HOST }} >> ~/.ssh/known_hosts

      - name: Deploy to VPS
        env:
          VPS_USER: ${{ secrets.VPS_USER }}
          VPS_HOST: ${{ secrets.VPS_HOST }}
          PROJECT_PATH: ${{ secrets.VPS_PROJECT_PATH }}
          VITE_API_URL: ${{ secrets.VITE_API_URL }}
          REBUILD: ${{ github.event.inputs.rebuild || 'false' }}
        run: |
          ssh $VPS_USER@$VPS_HOST << 'ENDSSH'
            set -e

            echo "Deploying frontend to $PROJECT_PATH"
            cd $PROJECT_PATH

            # Pull latest code
            echo "Pulling latest code..."
            git pull origin ${{ github.ref_name }}

            # Create .env file
            echo "Creating .env file..."
            cat > .env << EOF
          VITE_API_URL=$VITE_API_URL
          EOF

            # Build and deploy
            echo "Building Docker image..."
            if [ "$REBUILD" = "true" ]; then
              docker compose -f docker/docker-compose.yml build --no-cache
            else
              docker compose -f docker/docker-compose.yml build
            fi

            echo "Deploying container..."
            docker compose -f docker/docker-compose.yml up -d

            # Health check
            echo "Waiting for application to start..."
            sleep 10

            # Verify container is running
            docker compose -f docker/docker-compose.yml ps

            # Cleanup old images
            echo "Cleaning up old Docker images..."
            docker image prune -f

            echo "Deployment completed successfully!"
          ENDSSH
EOF

# Commit and push
git add .github/workflows/deploy.yml
git commit -m "Add automated CI/CD deployment workflow"
git push origin main
```

---

## Step 5: Test Your First Deployment

### 5.1 Monitor Workflow Execution

After pushing the workflow files:

1. Go to your repository on GitHub
2. Click the **Actions** tab
3. You should see the workflow running
4. Click on the workflow run to view detailed logs

### 5.2 Verify Deployment on VPS

SSH to your VPS and check the deployment:

```bash
# Check running containers
docker ps

# View backend logs
docker compose -f /opt/pantinventory/backend/docker/docker-compose.yml logs -f app

# View frontend logs
docker compose -f /opt/pantinventory/frontend/docker/docker-compose.yml logs -f frontend

# Check database
docker compose -f /opt/pantinventory/backend/docker/docker-compose.yml logs postgres
```

### 5.3 Manual Workflow Trigger

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

## Monitoring and Troubleshooting

### Common Issues

#### 1. SSH Connection Failed

**Error**: `Permission denied (publickey)`

**Solutions:**

- Verify `VPS_SSH_PRIVATE_KEY` secret contains the complete key (including headers/footers)
- Check `VPS_HOST` and `VPS_USER` are correct (`github-deployer`)
- Ensure public key is in `/home/github-deployer/.ssh/authorized_keys`
- Test SSH manually: `ssh -i <keyfile> github-deployer@YOUR_VPS_IP`

#### 2. Tests Failing

**Error**: Tests fail during CI

**Solutions:**

- Run tests locally first: `npm test`
- Fix failing tests before pushing
- Check test environment configuration

#### 3. Docker Build Fails

**Error**: Docker build fails on VPS

**Solutions:**

- Check disk space: `df -h`
- Check RAM: `free -h`
- Verify Dockerfile syntax
- Try manual build: `docker compose build --no-cache`
- Review deployment user's docker group membership: `groups github-deployer`

#### 4. Permission Denied on VPS

**Error**: Cannot write to directories

**Solutions:**

- Verify ownership: `ls -la /opt/pantinventory`
- Fix ownership: `sudo chown -R github-deployer:github-deployer /opt/pantinventory`
- Check docker group: `groups github-deployer`

#### 5. Git Pull Fails

**Error**: Repository not found or permission denied

**Solutions:**

- Test GitHub SSH as deployment user: `sudo -u github-deployer ssh -T git@github.com`
- Verify public key is added to GitHub
- Check SSH config: `sudo cat /home/github-deployer/.ssh/config`
- Ensure repository uses SSH URL: `git@github.com:username/repo.git`

#### 6. Migrations Fail

**Error**: Database migrations fail

**Solutions:**

- Check database is running: `docker ps`
- Check database logs: `docker compose logs postgres`
- Verify database credentials in secrets
- Try running migrations manually on VPS

### Monitoring Commands

```bash
# Check deployment user status
id github-deployer
groups github-deployer

# Check project ownership
ls -la /opt/pantinventory/

# View all running containers
docker ps

# View container logs
docker compose -f /opt/pantinventory/backend/docker/docker-compose.yml logs -f

# Check disk usage
df -h

# Check memory usage
free -h

# Check recent deployments (auth log)
sudo tail -f /var/log/auth.log | grep github-deployer

# Check Docker network
docker network ls
docker network inspect pantinventory_network
```

---

## Security Best Practices

### Dedicated Deployment User

✅ **Benefits of using `github-deployer` user:**

- Isolated from personal accounts
- Limited permissions (only `/opt/pantinventory`)
- Easy to audit deployment activities
- Can be revoked instantly without affecting personal access
- No sudo access needed (docker group membership sufficient)

### SSH Key Security

1. **Separate Keys for Different Purposes:**

   - Never reuse your personal SSH key for deployments
   - One key for GitHub access (`github_vps`)
   - One key for GitHub Actions access (`github_actions_deploy`)

2. **Key Rotation:**

   - Rotate deployment keys every 6-12 months
   - Process: Generate new key → Add to VPS → Update GitHub Secrets → Remove old key

3. **No Passphrase for Automation:**

   - GitHub Actions keys must have no passphrase
   - Your personal keys SHOULD have passphrases

4. **Monitor Key Usage:**

   ```bash
   # Check SSH login attempts
   sudo tail -f /var/log/auth.log | grep github-deployer

   # Check who's logged in
   who
   ```

### GitHub Secrets

1. **Never Commit Secrets:**

   - Never commit private keys to repositories
   - Add `.ssh/` and `*.pem` to `.gitignore`

2. **Use Strong Secrets:**

   ```bash
   # Generate strong passwords
   openssl rand -base64 32
   ```

3. **Limit Repository Access:**

   - Only grant access to trusted team members
   - Regularly review who has access

4. **Use Environment Protection:**
   - For production, use GitHub Environments
   - Add protection rules (required reviewers)

### VPS Security

1. **Regular Updates:**

   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Monitor Logs:**

   ```bash
   # Check authentication logs
   sudo tail -f /var/log/auth.log

   # Check deployment user activity
   sudo journalctl -u ssh | grep github-deployer
   ```

3. **Firewall Configuration:**

   - Ensure UFW is enabled
   - SSH port 22 should be allowed
   - Fail2Ban active to prevent brute-force

4. **Review Authorized Keys:**
   ```bash
   # Regularly check authorized_keys
   sudo cat /home/github-deployer/.ssh/authorized_keys
   ```

### Revoking Access

If you need to revoke GitHub Actions access:

```bash
# Remove GitHub Actions key from authorized_keys
sudo nano /home/github-deployer/.ssh/authorized_keys
# Delete the line containing "github-actions-deploy"

# Or remove entire user
sudo userdel -r github-deployer
```

Access is revoked immediately without needing to change passwords.

---

## Environment-Specific Deployments

### Staging vs Production

The workflows support both staging and production:

#### Setup Staging Environment

1. Create a `staging` branch:

   ```bash
   git checkout -b staging
   git push origin staging
   ```

2. Add environment-specific secrets in GitHub:

   - Go to Settings → Environments → New environment
   - Name: `staging`
   - Add staging-specific secrets (different passwords, URLs, etc.)

3. Push to `staging` branch to deploy to staging

#### Production Deployment

- Push to `main` branch to deploy to production
- Use separate GitHub Secrets for production

---

## Next Steps

After completing automated deployment setup:

1. ✅ Test deployments by pushing changes to your repositories
2. ✅ Configure domains and SSL certificates in nginx-proxy-manager
3. ✅ Set up monitoring and alerting (optional)
4. ✅ Consider setting up a staging environment

---

## Summary Checklist

Before proceeding:

**Deployment User Setup:**

- [ ] `github-deployer` user created
- [ ] Project directories created with correct ownership
- [ ] Deployment user added to docker group
- [ ] Permissions verified

**SSH Keys Configuration:**

- [ ] GitHub VPS key generated (`github_vps`)
- [ ] GitHub VPS public key added to GitHub
- [ ] SSH config created for GitHub
- [ ] GitHub SSH connection tested
- [ ] GitHub Actions deploy key generated (`github_actions_deploy`)
- [ ] GitHub Actions public key added to authorized_keys
- [ ] GitHub Actions private key copied securely

**GitHub Configuration:**

- [ ] GitHub Secrets added to backend repository
- [ ] GitHub Secrets added to frontend repository
- [ ] Secrets verified in GitHub UI

**Repository Setup:**

- [ ] Backend cloned to VPS as `github-deployer`
- [ ] Frontend cloned to VPS as `github-deployer`
- [ ] Git configured for pull deployments

**Workflow Configuration:**

- [ ] Backend workflow file added and committed
- [ ] Frontend workflow file added and committed
- [ ] First deployment tested successfully

**Verification:**

- [ ] Applications running on VPS
- [ ] Docker containers healthy
- [ ] Logs show no errors
- [ ] Can access applications via nginx-proxy-manager

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [SSH Key Authentication](https://www.ssh.com/academy/ssh/key)

---

## Support

If you encounter issues:

1. Review the troubleshooting section above
2. Check GitHub Actions logs for detailed error messages
3. Verify all secrets are configured correctly
4. Check VPS logs: `docker compose logs`
5. Verify deployment user permissions and group membership

Once everything is working, you have a fully automated CI/CD pipeline!
