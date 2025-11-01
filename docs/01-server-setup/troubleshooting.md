# Stage 1: Server Setup - Troubleshooting Guide

## Common Issues and Solutions

---

## SSH Issues

### Issue 1: Locked Out After Disabling Password Authentication

**Symptoms:**
- Cannot connect to server after hardening SSH
- "Permission denied (publickey)" error
- No password prompt appears

**Possible Causes:**
- SSH public key not properly copied to server
- Wrong permissions on `.ssh` directory or `authorized_keys` file
- SSH key not being used in connection attempt

**Solutions:**

#### Solution A: Use Provider's Console/VNC Access

1. Log in to your VPS provider's dashboard
2. Access the server console/terminal (emergency access)
3. Login as root or your user
4. Fix SSH configuration:

```bash
# Restore original SSH config
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config

# Restart SSH
sudo systemctl restart sshd
```

5. From local machine, verify key is correct:
```bash
cat ~/.ssh/pantinventory_vps.pub
```

6. On server, ensure key is in authorized_keys:
```bash
nano ~/.ssh/authorized_keys
# Paste your public key
```

7. Fix permissions:
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

8. Test connection from new terminal before proceeding

#### Solution B: Use Provider's SSH Key Reset

Some providers allow injecting SSH keys through their dashboard. Check your provider's documentation.

---

### Issue 2: SSH Connection Slow or Hangs

**Symptoms:**
- SSH connection takes 30+ seconds to establish
- Hangs at "debug1: Connecting to..."

**Possible Causes:**
- DNS resolution issues
- IPv6 connectivity problems

**Solution:**

```bash
# On VPS, edit SSH config
sudo nano /etc/ssh/sshd_config

# Add or modify:
UseDNS no
AddressFamily inet

# Restart SSH
sudo systemctl restart sshd
```

---

### Issue 3: "Too Many Authentication Failures"

**Symptoms:**
- Error: "Received disconnect from ... Too many authentication failures"
- Connection rejected after trying multiple keys

**Cause:**
- SSH client trying multiple keys from ssh-agent

**Solution:**

```bash
# Specify exact key to use
ssh -i ~/.ssh/pantinventory_vps -o IdentitiesOnly=yes pantiadmin@YOUR_VPS_IP

# Or add to ~/.ssh/config on local machine:
Host pantinventory
    HostName YOUR_VPS_IP
    User pantiadmin
    IdentityFile ~/.ssh/pantinventory_vps
    IdentitiesOnly yes
```

---

### Issue 4: SSH Key Permissions Error

**Symptoms:**
- Warning: "UNPROTECTED PRIVATE KEY FILE!"
- "Permissions 0644 for '~/.ssh/key' are too open"

**Cause:**
- Private key file has incorrect permissions

**Solution:**

```bash
# Fix private key permissions
chmod 600 ~/.ssh/pantinventory_vps

# Fix public key permissions (if needed)
chmod 644 ~/.ssh/pantinventory_vps.pub
```

---

## Docker Issues

### Issue 5: Docker Permission Denied

**Symptoms:**
- "Got permission denied while trying to connect to the Docker daemon socket"
- Need to use sudo for docker commands

**Cause:**
- User not in docker group
- Need to reload group membership

**Solution:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Option 1: Logout and login again
exit
ssh -i ~/.ssh/pantinventory_vps pantiadmin@YOUR_VPS_IP

# Option 2: Apply group without logout
newgrp docker

# Verify
docker ps
```

---

### Issue 6: Docker Service Won't Start

**Symptoms:**
- "Failed to start docker.service: Unit docker.service not found"
- Docker commands return "Cannot connect to Docker daemon"

**Solution:**

```bash
# Check Docker service status
sudo systemctl status docker

# If not running, start it
sudo systemctl start docker

# If service doesn't exist, reinstall Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Enable on boot
sudo systemctl enable docker
sudo systemctl start docker
```

---

### Issue 7: Docker Compose Command Not Found

**Symptoms:**
- "docker-compose: command not found"
- Using old `docker-compose` syntax

**Solution:**

Modern Docker includes Compose as a plugin. Use `docker compose` (space, not hyphen):

```bash
# New syntax (correct)
docker compose version

# Old syntax (deprecated)
docker-compose --version

# If truly missing, reinstall Docker
sudo apt update
sudo apt install -y docker-compose-plugin
```

---

## Firewall Issues

### Issue 8: Locked Out After Enabling UFW

**Symptoms:**
- Cannot SSH to server after enabling firewall
- Connection times out

**Cause:**
- Forgot to allow SSH port before enabling UFW

**Solution:**

#### Prevention (ALWAYS DO THIS):
```bash
# ALWAYS allow SSH before enabling UFW
sudo ufw allow 22/tcp
sudo ufw enable
```

#### Recovery:
1. Use provider's console/VNC access
2. Disable UFW temporarily:
```bash
sudo ufw disable
```
3. Allow SSH:
```bash
sudo ufw allow 22/tcp
# Or if custom port: sudo ufw allow 2222/tcp
```
4. Re-enable UFW:
```bash
sudo ufw enable
```

---

### Issue 9: Application Ports Not Accessible

**Symptoms:**
- Cannot access services on ports 80/443
- Nginx Proxy Manager not reachable

**Solution:**

```bash
# Check UFW status
sudo ufw status verbose

# Allow HTTP and HTTPS if not present
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Verify rules added
sudo ufw status numbered
```

---

## System Issues

### Issue 10: Insufficient Disk Space

**Symptoms:**
- "No space left on device"
- Docker images fail to download

**Solution:**

```bash
# Check disk usage
df -h

# Clean up Docker
docker system prune -a --volumes

# Clean apt cache
sudo apt clean
sudo apt autoclean

# Remove old kernels (Ubuntu)
sudo apt autoremove
```

---

### Issue 11: Insufficient Memory

**Symptoms:**
- Services crashing randomly
- "Out of memory" errors

**Solution:**

```bash
# Check memory usage
free -h

# Check what's using memory
ps aux --sort=-%mem | head

# Add swap space if needed (2GB example)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

### Issue 12: System Time Incorrect

**Symptoms:**
- SSL certificate errors
- Authentication failures

**Solution:**

```bash
# Check current time
timedatectl

# Set timezone
sudo timedatectl set-timezone America/New_York
# List all: timedatectl list-timezones

# Enable NTP
sudo timedatectl set-ntp on

# If issues persist, install chrony
sudo apt install -y chrony
sudo systemctl enable chrony
sudo systemctl start chrony
```

---

## Fail2Ban Issues

### Issue 13: Fail2Ban Not Starting

**Symptoms:**
- fail2ban service fails to start
- Error in service status

**Solution:**

```bash
# Check fail2ban status and logs
sudo systemctl status fail2ban
sudo journalctl -u fail2ban -n 50

# Check configuration
sudo fail2ban-client -d

# If syntax error, restore default config
sudo rm /etc/fail2ban/jail.local
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Restart
sudo systemctl restart fail2ban
```

---

### Issue 14: Accidentally Banned Own IP

**Symptoms:**
- Cannot SSH to server
- Connection times out or refused

**Solution:**

1. Use provider's console access
2. Unban your IP:

```bash
# Find your IP in banned list
sudo fail2ban-client status sshd

# Unban specific IP
sudo fail2ban-client set sshd unbanip YOUR_IP_ADDRESS

# Or restart fail2ban to clear all bans
sudo systemctl restart fail2ban
```

3. Add your IP to whitelist:

```bash
sudo nano /etc/fail2ban/jail.local

# Add under [DEFAULT]:
ignoreip = 127.0.0.1/8 ::1 YOUR_IP_ADDRESS

sudo systemctl restart fail2ban
```

---

## Package Installation Issues

### Issue 15: Package Installation Fails

**Symptoms:**
- "Unable to locate package"
- "Package has no installation candidate"

**Solution:**

```bash
# Update package lists
sudo apt update

# Fix broken packages
sudo apt --fix-broken install

# If specific package missing, check Ubuntu version
lsb_release -a

# For Docker, ensure correct repository
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo apt update
```

---

### Issue 16: GPG Key Errors

**Symptoms:**
- "GPG error: ... NO_PUBKEY"
- Repository signature errors

**Solution:**

```bash
# Re-add Docker GPG key
sudo rm /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Update
sudo apt update
```

---

## Network Issues

### Issue 17: Cannot Ping External Sites

**Symptoms:**
- "ping: google.com: Name or service not known"
- No internet connectivity

**Solution:**

```bash
# Check DNS resolution
cat /etc/resolv.conf

# If empty or wrong, add Google DNS
sudo nano /etc/resolv.conf
# Add:
nameserver 8.8.8.8
nameserver 8.8.4.4

# Test
ping -c 3 google.com
```

---

### Issue 18: SSH Port Already in Use

**Symptoms:**
- SSH fails to start
- "Address already in use" error

**Solution:**

```bash
# Check what's using port 22
sudo netstat -tulpn | grep :22

# Or with ss
sudo ss -tulpn | grep :22

# If another SSH instance, kill it
sudo killall sshd

# Start SSH service
sudo systemctl start sshd
```

---

## Diagnostic Commands

### General System Health

```bash
# Check system logs
sudo journalctl -xe

# Check SSH logs
sudo tail -f /var/log/auth.log

# Check system resources
htop  # or: top

# Check disk I/O
iostat -x 1

# Check network connections
sudo netstat -tulpn
```

### Service Status

```bash
# Check all services
sudo systemctl list-units --type=service --state=running

# Check specific service
sudo systemctl status docker
sudo systemctl status fail2ban
sudo systemctl status sshd
```

---

## Getting Help

### Gather System Information

When seeking help, provide:

```bash
# System info
uname -a
lsb_release -a

# Service status
sudo systemctl status docker
sudo systemctl status sshd

# Recent logs
sudo journalctl -u docker -n 50
sudo journalctl -u sshd -n 50

# Network config
ip addr show
sudo ufw status verbose
```

### Safe Mode Recovery

If system is broken and you need to start over:

1. **Snapshot/Backup** (if provider supports)
2. **Use Provider Console** for emergency access
3. **Disable security measures temporarily**:
   ```bash
   sudo ufw disable
   sudo systemctl stop fail2ban
   ```
4. **Fix issues**
5. **Re-enable security**
6. **Test thoroughly**

---

## Prevention Tips

1. **Always keep a backup SSH session open** when changing SSH config
2. **Test new configurations** before closing sessions
3. **Allow SSH in firewall** before enabling UFW
4. **Snapshot before major changes** (if provider supports)
5. **Document all changes** you make
6. **Keep emergency console access** credentials handy

---

## Still Having Issues?

1. Review [implementation-guide.md](implementation-guide.md) for missed steps
2. Check [verification.md](verification.md) to identify failed tests
3. Search error messages online with context (Ubuntu 22.04 + your error)
4. Check provider-specific documentation for console access
5. Consider redeploying if system is badly broken (with lessons learned)

---

## Emergency Recovery Checklist

- [ ] Can access via provider console/VNC?
- [ ] Is SSH service running? (`sudo systemctl status sshd`)
- [ ] Are correct ports open? (`sudo ufw status`)
- [ ] Are SSH keys in authorized_keys? (`cat ~/.ssh/authorized_keys`)
- [ ] Are permissions correct? (`ls -la ~/.ssh/`)
- [ ] Is fail2ban blocking you? (`sudo fail2ban-client status sshd`)
- [ ] Can you ping the server? (`ping YOUR_VPS_IP`)
- [ ] Is the server running? (check provider dashboard)
