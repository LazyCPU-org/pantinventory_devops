# Stage 1: VPS Prerequisites Setup

## Overview

This stage installs required software and performs basic security configuration on a fresh VPS. This prepares your server for infrastructure deployment.

**Time Estimate**: 15-30 minutes (mostly automated)

---

## What Gets Installed

The `01-vps-initial-setup.sh` script installs and configures:

### Software
- **Git** - Version control
- **Docker** - Container runtime
- **Docker Compose** - Multi-container orchestration
- **Essential tools** - curl, wget, vim, nano

### Security
- **UFW Firewall** - Configured to allow only SSH (22), HTTP (80), HTTPS (443)
- **Fail2Ban** - Protection against brute-force SSH attacks
- **Docker group** - Allows running Docker without sudo

---

## Prerequisites

Before running the script:

- [ ] Fresh VPS with Ubuntu 22.04 LTS or 24.04 LTS
- [ ] Root access or sudo privileges
- [ ] **SSH key-based authentication configured** (see below)

---

## IMPORTANT: SSH Key Setup (Do This First!)

**⚠️ WARNING**: Configuring SSH incorrectly can lock you out of your VPS. Follow these steps carefully and in order.

### Why SSH Keys?

Password authentication is vulnerable to brute-force attacks. SSH keys provide:
- Much stronger security (nearly impossible to brute-force)
- Convenient access (no password typing)
- Ability to grant/revoke access per key

### Step 1: Generate SSH Key on Your Local Machine

**On your local computer** (not the VPS):

```bash
# Generate an ED25519 key (recommended - modern and secure)
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/pantinventory_vps

# When prompted for passphrase:
# - RECOMMENDED: Enter a passphrase for extra security
# - OPTIONAL: Leave empty for convenience (less secure)
```

This creates two files:
- `~/.ssh/pantinventory_vps` - Private key (NEVER share this!)
- `~/.ssh/pantinventory_vps.pub` - Public key (safe to share)

### Step 2: Copy Public Key to VPS

**Option A: Using ssh-copy-id (easiest)**

```bash
# From your local machine
ssh-copy-id -i ~/.ssh/pantinventory_vps.pub root@YOUR_VPS_IP

# Or if you have a non-root user already:
ssh-copy-id -i ~/.ssh/pantinventory_vps.pub your-user@YOUR_VPS_IP
```

**Option B: Manual copy (if ssh-copy-id not available)**

```bash
# Display your public key
cat ~/.ssh/pantinventory_vps.pub

# Copy the output, then SSH to VPS and run:
ssh root@YOUR_VPS_IP

# On VPS:
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
# Paste your public key, save (Ctrl+X, Y, Enter)
chmod 600 ~/.ssh/authorized_keys
```

### Step 3: Test SSH Key Authentication

**CRITICAL: Open a NEW terminal (keep the old one open as backup!)**

```bash
# From your local machine, in a NEW terminal window
ssh -i ~/.ssh/pantinventory_vps your-user@YOUR_VPS_IP

# Should log in without asking for password
```

**If this fails, DO NOT proceed to Step 4!** Keep your password-based session open and troubleshoot.

### Step 4: Disable Password Authentication (After Testing!)

**Only do this after Step 3 works!**

On the VPS:

```bash
# Backup SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Edit SSH config
sudo nano /etc/ssh/sshd_config
```

Find and modify these lines:

```bash
PermitRootLogin no                    # Disable root login
PasswordAuthentication no             # Disable password auth
PubkeyAuthentication yes              # Enable key-based auth
ChallengeResponseAuthentication no    # Disable challenge-response
```

Save and exit (Ctrl+X, Y, Enter).

```bash
# Test the configuration
sudo sshd -t

# If no errors, restart SSH
sudo systemctl restart sshd
```

### Step 5: Verify Security Settings

**Keep your current session open! Open a NEW terminal to test:**

```bash
# This should work (key-based)
ssh -i ~/.ssh/pantinventory_vps your-user@YOUR_VPS_IP

# This should FAIL (password-based)
ssh your-user@YOUR_VPS_IP
# Expected: Permission denied (publickey)
```

Only after confirming the new connection works, close your old session.

### Creating Additional SSH Keys for Others

Later, when you need to grant access (e.g., for GitHub Actions or team members):

```bash
# On VPS, add their public key to authorized_keys
echo "THEIR_PUBLIC_KEY_CONTENT" >> ~/.ssh/authorized_keys

# Or for a different user:
sudo -u other-user bash -c 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'
sudo -u other-user bash -c 'echo "THEIR_PUBLIC_KEY" >> ~/.ssh/authorized_keys'
sudo -u other-user bash -c 'chmod 600 ~/.ssh/authorized_keys'
```

To revoke access:
```bash
# Edit authorized_keys and remove their key line
nano ~/.ssh/authorized_keys
```

---

## Automated Setup (Recommended)

**After completing SSH key setup above**, run the automated script:

### Step 1: Get the Script

SSH to your VPS and get the setup script:

```bash
# Clone the devops repository
git clone https://github.com/YOUR_USERNAME/pantinventory_devops.git /tmp/pantinventory_devops

# Or download just the script
curl -o 01-vps-initial-setup.sh https://raw.githubusercontent.com/YOUR_USERNAME/pantinventory_devops/main/scripts/01-vps-initial-setup.sh
chmod +x 01-vps-initial-setup.sh
```

### Step 2: Run the Script

```bash
cd /tmp/pantinventory_devops
./scripts/01-vps-initial-setup.sh
```

The script will:
1. Update system packages
2. Install essential tools (git, curl, wget, vim, nano)
3. Install Docker and Docker Compose
4. Add your user to the docker group
5. Configure UFW firewall (allow ports 22, 80, 443)
6. Install and configure Fail2Ban

### Step 3: Apply Docker Group Changes

**Important**: After the script completes, you must log out and log back in:

```bash
exit
ssh your-user@your-vps-ip
```

This is required for the docker group membership to take effect.

### Step 4: Verify Installation

After logging back in, verify everything works:

```bash
# Test Docker (should work without sudo)
docker --version
docker ps

# Test firewall
sudo ufw status

# Test Fail2Ban
sudo systemctl status fail2ban
```

---

## What the Script Does

### 1. System Update
```bash
sudo apt update
sudo apt upgrade -y
```

Updates all system packages to latest versions.

### 2. Install Essential Tools
```bash
sudo apt install -y git curl wget vim nano ufw fail2ban \
    ca-certificates gnupg lsb-release
```

Installs command-line tools and security utilities.

### 3. Install Docker

Adds Docker's official repository and installs:
- `docker-ce` - Docker engine
- `docker-ce-cli` - Docker command-line interface
- `containerd.io` - Container runtime
- `docker-buildx-plugin` - Build tool
- `docker-compose-plugin` - Multi-container tool

### 4. Configure Docker

- Adds current user to `docker` group (allows running docker without sudo)
- Enables Docker service to start on boot
- Starts Docker service immediately

### 5. Configure UFW Firewall

**What is UFW?**
UFW (Uncomplicated Firewall) is a user-friendly firewall management tool for Ubuntu. It blocks unauthorized network access while allowing legitimate traffic.

Sets up firewall rules:
```bash
sudo ufw default deny incoming   # Block all incoming by default
sudo ufw default allow outgoing   # Allow all outgoing
sudo ufw allow 22/tcp             # SSH
sudo ufw allow 80/tcp             # HTTP (for nginx-proxy-manager)
sudo ufw allow 443/tcp            # HTTPS (for nginx-proxy-manager)
sudo ufw enable
```

### 6. Configure Fail2Ban

**What is Fail2Ban?**
Fail2Ban is a security tool that monitors log files (like SSH login attempts) and automatically blocks IP addresses that show malicious behavior. For example, if someone tries to guess your SSH password 5 times, Fail2Ban will ban their IP for 10 minutes.

**Why use it?**
Without Fail2Ban, automated bots will constantly try to brute-force your SSH password. Fail2Ban stops these attacks automatically.

**How the script configures it:**
```bash
# Install fail2ban (if not already installed)
sudo apt install -y fail2ban

# Create local configuration (only if file doesn't exist)
if [ ! -f /etc/fail2ban/jail.local ]; then
    sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi

# Enable and start the service
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

The `jail.conf` file is provided by the fail2ban package when it's installed. The script copies it to `jail.local` (which takes precedence) so your custom settings won't be overwritten during updates.

---

## Security Notes

### Firewall Configuration

The script configures UFW to:
- ✅ Allow SSH (port 22) - **Required** for remote access
- ✅ Allow HTTP (port 80) - For nginx-proxy-manager
- ✅ Allow HTTPS (port 443) - For nginx-proxy-manager
- ✅ Deny all other incoming connections
- ✅ Allow all outgoing connections

**Warning**: If you use a custom SSH port, modify the script before running it, or add your custom port manually:
```bash
sudo ufw allow YOUR_SSH_PORT/tcp
```

### Fail2Ban Protection

**Default Configuration:**
- Monitors SSH login attempts
- Max retries: 5 failed attempts
- Ban time: 10 minutes
- After 10 minutes, IP is automatically unbanned

**Check banned IPs:**
```bash
sudo fail2ban-client status sshd
```

**Manually unban an IP (if you accidentally locked yourself out):**
```bash
sudo fail2ban-client set sshd unbanip IP_ADDRESS
```

**Check Fail2Ban logs:**
```bash
sudo tail -f /var/log/fail2ban.log
```

---

## Troubleshooting

### Docker: permission denied

**Problem**: `docker ps` fails with "permission denied"

**Solution**: You need to log out and log back in after the script runs:
```bash
exit
ssh your-user@your-vps-ip
```

### UFW: Command not found

**Problem**: UFW not installed

**Solution**: The script should have installed it. Try manually:
```bash
sudo apt update
sudo apt install -y ufw
```

### Cannot connect after enabling UFW

**Problem**: Locked out of server

**Solution**: Ensure SSH port 22 is allowed BEFORE enabling UFW. If locked out, use your VPS provider's console/recovery mode to disable UFW:
```bash
sudo ufw disable
sudo ufw allow 22/tcp
sudo ufw enable
```

### Fail2Ban not starting

**Problem**: `systemctl status fail2ban` shows failed

**Solution**: Check logs for errors:
```bash
sudo journalctl -u fail2ban -n 50
```

Common cause: Configuration file syntax error. Restore default:
```bash
sudo rm /etc/fail2ban/jail.local
sudo systemctl restart fail2ban
```

---

## Verification

After completing setup, verify all components:

```bash
# Docker
docker --version                    # Should show Docker version
docker ps                           # Should work without sudo
docker compose version              # Should show Compose version

# Firewall
sudo ufw status                     # Should show: Status: active
                                    # Rules for 22, 80, 443

# Fail2Ban
sudo systemctl status fail2ban      # Should show: active (running)
sudo fail2ban-client status sshd    # Should show SSH jail is active

# Git
git --version                       # Should show Git version
```

---

## Next Steps

Once Stage 1 is complete:

1. **Verify installation** (see Verification section above)
2. **Proceed to Stage 2: Network Configuration**:
   ```bash
   ./scripts/00-setup-infrastructure.sh
   ```
   Or run individual scripts:
   - Network Setup: `./scripts/02-network-setup.sh`
   - Nginx Proxy Manager: `./scripts/03-nginx-proxy-setup.sh`

   See: [Stage 2: Network Configuration](../02-network-configuration/README.md)

3. **Configure GitHub Actions access** for application deployment:
   - See [GitHub Actions Access Guide](../03-application-deployment/github-actions-setup.md)

---

## Files in This Directory

- **README.md** - This file (overview and automated setup)
- **troubleshooting.md** - Common issues and detailed solutions

---

## Summary

After completing Stage 1:
- ✅ Docker and Docker Compose installed
- ✅ User can run Docker without sudo
- ✅ Firewall configured (ports 22, 80, 443 open)
- ✅ Fail2Ban protecting against brute-force attacks
- ✅ System updated and essential tools installed
- ✅ Ready for infrastructure deployment
