# GitHub Actions VPS Access Setup

## Overview

This guide explains how to configure GitHub Actions to securely access your VPS for automated deployments. This setup is required for both backend and frontend repositories to enable CI/CD.

## Architecture

```
GitHub Actions Runner
        ↓
  SSH Connection (key-based auth)
        ↓
    Your VPS
        ↓
  Deploy Applications
```

---

## Authentication Method: SSH Keys (Secure)

**GitHub Actions will use SSH key-based authentication** to access your VPS. This is:
- ✅ **Secure**: No passwords stored in GitHub
- ✅ **Auditable**: Each key can be tracked
- ✅ **Revocable**: Remove key to revoke access instantly
- ❌ **Never use username/password**: Insecure and not recommended

---

## One-Time VPS Setup

### Step 1: Generate Deployment SSH Key

On your VPS, create a **dedicated SSH key** for GitHub Actions (separate from your personal key):

**Why a separate key?**
- You can revoke GitHub Actions access without affecting your personal access
- Different keys for different purposes (principle of least privilege)
- Easy to identify in logs

```bash
# On your VPS (via your personal SSH connection)
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy -N ""

# Verify keys were created
ls -la ~/.ssh/github_actions_deploy*
# Should show:
# github_actions_deploy       (private key)
# github_actions_deploy.pub   (public key)
```

**Note**: The `-N ""` flag creates a key without a passphrase. This is required for GitHub Actions automated deployments.

### Step 2: Authorize the Public Key

Add the public key to authorized_keys so GitHub Actions can connect:

```bash
# Add public key to authorized_keys
cat ~/.ssh/github_actions_deploy.pub >> ~/.ssh/authorized_keys

# Set correct permissions
chmod 600 ~/.ssh/authorized_keys
```

**What this does**: Adds the GitHub Actions public key to the list of authorized keys. GitHub Actions will use the corresponding private key to authenticate.

### Step 3: Copy the Private Key

Display and copy the private key (you'll add this to GitHub Secrets):

```bash
cat ~/.ssh/github_actions_deploy
```

**Copy the entire output**, including:
- `-----BEGIN OPENSSH PRIVATE KEY-----`
- All lines in between
- `-----END OPENSSH PRIVATE KEY-----`

**⚠️ SECURITY NOTE**:
- This private key will be stored in GitHub Secrets (encrypted)
- Never commit this key to your git repository
- Never share it via email, Slack, or any insecure channel
- GitHub Secrets are encrypted and only exposed to workflows you specify

### Step 4: Test the Connection

From your local machine, test the SSH connection:

```bash
# Save the private key to a file temporarily
cat > /tmp/test_key << 'EOF'
(paste the private key here)
EOF

chmod 600 /tmp/test_key

# Test connection
ssh -i /tmp/test_key YOUR_VPS_USER@YOUR_VPS_IP "echo 'Connection successful'"

# Clean up
rm /tmp/test_key
```

If you see "Connection successful", the SSH key is configured correctly.

---

## GitHub Repository Setup

These steps should be performed for **each application repository** (backend and frontend).

### Step 1: Add GitHub Secrets

Go to your GitHub repository:

1. Navigate to: `Settings` → `Secrets and variables` → `Actions`
2. Click `New repository secret`

Add these secrets:

#### Required for All Applications

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `VPS_SSH_PRIVATE_KEY` | (private key from VPS Step 3) | SSH private key for authentication |
| `VPS_HOST` | Your VPS IP address | e.g., `192.168.1.100` |
| `VPS_USER` | Your SSH username | e.g., `pantiadmin` |

#### Application-Specific

Each application needs to define where it will be deployed on the VPS:

**Backend**:
- `VPS_PROJECT_PATH` → `/opt/pantinventory/backend`

**Frontend**:
- `VPS_PROJECT_PATH` → `/opt/pantinventory/frontend`

### Step 2: Verify Secrets

After adding secrets, you should see them listed (values will be hidden):

```
VPS_SSH_PRIVATE_KEY    ••••••••
VPS_HOST               ••••••••
VPS_USER               ••••••••
VPS_PROJECT_PATH       ••••••••
```

---

## SSH Connection in GitHub Actions

### Basic Workflow Template

Here's how to use the SSH connection in your GitHub Actions workflow:

```yaml
name: Deploy to VPS

on:
  push:
    branches: [main]

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

      - name: Deploy to VPS
        run: |
          ssh ${{ secrets.VPS_USER }}@${{ secrets.VPS_HOST }} << 'ENDSSH'
            cd ${{ secrets.VPS_PROJECT_PATH }}

            # Your deployment commands here
            git pull origin main
            docker compose build
            docker compose up -d

          ENDSSH
```

---

## Project Structure on VPS

Applications should be deployed to these locations:

```
/opt/pantinventory/
├── backend/          # Backend application
│   ├── .git/
│   ├── docker/
│   │   └── docker-compose.yml
│   └── ...
│
└── frontend/         # Frontend application
    ├── .git/
    ├── docker/
    │   └── docker-compose.yml
    └── ...
```

### Initial Repository Setup on VPS

Before first deployment, clone your repositories to the VPS:

```bash
# Create project directory
sudo mkdir -p /opt/pantinventory
sudo chown -R $USER:$USER /opt/pantinventory

# Clone backend
git clone https://github.com/YOUR_USERNAME/pantinventory_backend.git /opt/pantinventory/backend

# Clone frontend
git clone https://github.com/YOUR_USERNAME/pantinventory_frontend.git /opt/pantinventory/frontend

# Configure git for deployment
cd /opt/pantinventory/backend
git config pull.rebase false

cd /opt/pantinventory/frontend
git config pull.rebase false
```

---

## Security Best Practices

### Why SSH Keys for GitHub Actions?

**SSH keys are the ONLY recommended authentication method** for GitHub Actions to access your VPS:

| Method | Security | Recommendation |
|--------|----------|----------------|
| SSH Keys | ✅ Very Secure | **Use this** |
| Username/Password | ❌ Insecure | Never use |
| Personal Access Tokens | ⚠️ Not applicable | For Git operations only |

**Why SSH keys are secure:**
1. **Encrypted authentication**: Uses public-key cryptography
2. **No password transmission**: Password never sent over network
3. **Revocable**: Delete key from `authorized_keys` to revoke instantly
4. **Auditable**: Each key can be identified by its comment
5. **GitHub Secrets encryption**: Private key stored encrypted in GitHub

**Why NOT username/password:**
- ❌ Password stored in GitHub Secrets (security risk)
- ❌ Vulnerable to brute-force attacks
- ❌ Can't easily revoke without changing password everywhere
- ❌ Password transmitted over network (even with encryption, less secure than keys)

### SSH Key Management

1. **Use Dedicated Keys**:
   - Never reuse your personal SSH key for GitHub Actions
   - Create separate keys for each purpose (personal, GitHub Actions, team members)

2. **Key Rotation**:
   - Rotate deployment keys every 6-12 months
   - When rotating: Create new key → Add to VPS → Update GitHub Secrets → Remove old key

3. **Limited Scope**:
   - The deployment user should only have access to deployment directories (`/opt/pantinventory`)
   - Consider using restricted SSH commands if needed

4. **No Passphrase for Automation**:
   - GitHub Actions keys must have no passphrase (automated use)
   - Your personal keys SHOULD have passphrases (manual use)

### GitHub Secrets

1. **Never Commit**:
   - Never commit the private key to your repository
   - Add `.ssh/` and `*.pem` to `.gitignore` if working with keys locally

2. **Limit Access**:
   - Only repository admins should manage secrets
   - Review repository access regularly

3. **Audit Regularly**:
   - Review who has access to repository secrets
   - Check GitHub Actions logs for suspicious activity

4. **Use Environment Secrets for Production**:
   - For production deployments, use GitHub Environments
   - Add protection rules (required reviewers)

### VPS Security

1. **Restrict Permissions**:
   - Deployment user should only access `/opt/pantinventory`
   - Use `chmod` and `chown` appropriately

2. **Monitor Access**:
   ```bash
   # Check recent SSH logins
   sudo tail -f /var/log/auth.log | grep "Accepted publickey"

   # Check who's currently logged in
   who

   # Check SSH key usage
   sudo journalctl -u ssh | grep "github-actions-deploy"
   ```

3. **Firewall Rules**:
   - SSH port 22 protected by UFW (allow only, no specific IPs needed for GitHub Actions)
   - Fail2Ban active to prevent brute-force attempts

4. **Regular Updates**:
   - Keep your VPS system packages updated
   - Review `authorized_keys` periodically and remove unused keys

### Revoking GitHub Actions Access

If you need to revoke GitHub Actions access immediately:

```bash
# On VPS: Edit authorized_keys
nano ~/.ssh/authorized_keys

# Find and DELETE the line containing "github-actions-deploy"
# Save and exit

# Verify
cat ~/.ssh/authorized_keys | grep github-actions-deploy
# Should return nothing
```

GitHub Actions will immediately lose access. No need to change passwords or update GitHub Secrets.

---

## Troubleshooting

### "Permission denied (publickey)"

**Problem**: GitHub Actions cannot connect to VPS

**Solutions**:
1. Verify the private key in GitHub Secrets is complete (includes header/footer)
2. Check `VPS_HOST` and `VPS_USER` are correct
3. Verify public key is in `~/.ssh/authorized_keys` on VPS
4. Test SSH connection manually (see VPS Step 4)

### "Host key verification failed"

**Problem**: VPS host key not trusted

**Solution**: The workflow template above includes `ssh-keyscan` which fixes this automatically

### "Repository not found" during deployment

**Problem**: Git repository not cloned on VPS

**Solution**: Follow "Initial Repository Setup on VPS" section above

---

## Next Steps

Once GitHub Actions has VPS access configured:

1. **See Application Deployment Guide**: [../05-application-deployment-guide/README.md](../05-application-deployment-guide/README.md)
2. **Review workflow examples** for backend and frontend
3. **Test your first automated deployment**

---

## Summary Checklist

Before proceeding to application deployment:

- [ ] SSH key generated on VPS
- [ ] Public key added to authorized_keys
- [ ] Private key copied (securely stored)
- [ ] SSH connection tested successfully
- [ ] GitHub Secrets added to repository
- [ ] VPS_SSH_PRIVATE_KEY secret verified
- [ ] VPS_HOST and VPS_USER secrets set
- [ ] Repositories cloned to VPS
- [ ] Git configured for pull deployments

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [SSH Key Authentication](https://www.ssh.com/academy/ssh/key)
