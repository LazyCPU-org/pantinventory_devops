# PantInventory DevOps Implementation Roadmap

## Overview

This document provides a comprehensive roadmap for deploying the PantInventory application on a VPS with full DevOps automation, security hardening, and CI/CD pipeline integration.

## Project Goals

- Deploy a secure, containerized multi-tier application
- Implement SSH key-based authentication only
- Set up automated SSL certificate management
- Configure reverse proxy with CORS support
- Establish CI/CD pipelines for automated deployments
- Provide secure external database access via SSH tunneling

## Architecture Summary

```
Internet → Nginx Proxy Manager → Internal Docker Network
                                  ├── Frontend Container
                                  ├── Backend Container
                                  └── Database Container
```

## Implementation Stages

### Stage 1: Server Setup
**Directory:** `docs/01-server-setup/`
**Status:** Pending

#### Objectives
- Provision and configure VPS
- Harden SSH security (key-based authentication only)
- Install Docker and Docker Compose
- Configure firewall and basic security

#### Key Deliverables
- VPS with SSH key authentication configured
- Docker environment ready
- Firewall rules configured
- Initial security hardening complete

#### Estimated Effort
- Setup time: 2-3 hours
- Documentation: 1 hour

---

### Stage 2: Network Configuration
**Directory:** `docs/02-network-configuration/`
**Status:** Pending

#### Objectives
- Create isolated Docker network
- Deploy nginx-proxy-manager
- Configure internal routing
- Set up network isolation

#### Key Deliverables
- Docker network created
- Nginx-proxy-manager running and accessible
- Internal container communication configured
- Network isolation verified

#### Estimated Effort
- Setup time: 1-2 hours
- Documentation: 30 minutes

---

### Stage 3: Application Deployment
**Directory:** `docs/03-application-deployment/`
**Status:** Pending

#### Objectives
- Deploy database container
- Deploy backend with migrations/seeding
- Deploy frontend container
- Configure nginx-proxy-manager routing

#### Key Deliverables
- All three containers running
- Database initialized and seeded
- Frontend accessible via proxy
- Backend API accessible via proxy

#### Estimated Effort
- Setup time: 2-4 hours
- Documentation: 1 hour

---

### Stage 4: SSL Configuration
**Directory:** `docs/04-ssl-configuration/`
**Status:** Pending

#### Objectives
- Configure domain DNS records
- Set up Let's Encrypt in nginx-proxy-manager
- Enable HTTPS for all services
- Configure HTTP to HTTPS redirection

#### Key Deliverables
- SSL certificates issued and installed
- HTTPS enforced for all external connections
- Automatic certificate renewal configured
- HTTP redirects working

#### Estimated Effort
- Setup time: 1-2 hours
- Documentation: 30 minutes

---

### Stage 5: CORS Configuration
**Directory:** `docs/05-cors-configuration/`
**Status:** Pending

#### Objectives
- Configure CORS headers in nginx-proxy-manager
- Allow frontend-to-backend communication
- Handle preflight requests (OPTIONS)
- Test cross-origin authenticated requests

#### Key Deliverables
- CORS headers configured on backend proxy
- Frontend can communicate with backend
- No CORS errors in browser console
- Cookie/credential-based auth working (if applicable)

#### Estimated Effort
- Setup time: 1 hour
- Documentation: 30 minutes

---

### Stage 6: CI/CD Pipeline Setup
**Directory:** `docs/06-cicd-pipeline/`
**Status:** Pending

#### Objectives
- Create GitHub Actions workflows for each repository
- Configure GitHub Secrets for VPS access
- Implement Docker Secrets for runtime credentials
- Set up automated deployment on push to main

#### Key Deliverables
- GitHub Actions workflows created (frontend, backend, devops)
- GitHub Secrets configured
- Docker Secrets implemented
- Automated deployments working
- Health checks and verification in place

#### Estimated Effort
- Setup time: 3-5 hours
- Documentation: 1-2 hours

---

### Stage 7: Database Access Setup
**Directory:** `docs/07-database-access/`
**Status:** Pending

#### Objectives
- Configure SSH tunneling for database access
- Document DBeaver/database client setup
- Set up authorized user SSH keys
- Optional: Configure fail2ban

#### Key Deliverables
- SSH tunnel configuration documented
- Database accessible via SSH tunnel only
- Authorized users can connect from DBeaver/TablePlus
- Security measures in place
- User management process documented

#### Estimated Effort
- Setup time: 1-2 hours
- Documentation: 1 hour

---

## Critical Dependencies

### Between Stages
1. **Stage 1 → Stage 2:** Docker must be installed before network setup
2. **Stage 2 → Stage 3:** Nginx-proxy-manager must be running before app deployment
3. **Stage 3 → Stage 4:** Applications must be deployed before SSL configuration
4. **Stage 4 → Stage 5:** HTTPS should be working before CORS testing
5. **Stage 5 → Stage 6:** Manual deployment must work before automation
6. **Stage 3 → Stage 7:** Database must be deployed before access configuration

### External Requirements
- VPS provider account and access
- Domain name with DNS management access
- GitHub account with repository access
- SSH key pair generated locally
- Docker Hub or container registry account (optional)

## Success Criteria

### Technical
- [ ] All services running and accessible via HTTPS
- [ ] No CORS errors in browser console
- [ ] Automated deployments working on git push
- [ ] Database accessible only via SSH tunnel
- [ ] SSL certificates auto-renewing
- [ ] Zero plaintext passwords in repositories

### Security
- [ ] SSH password authentication disabled
- [ ] Only nginx-proxy-manager exposed on 80/443
- [ ] Internal services isolated in Docker network
- [ ] All secrets managed via GitHub Secrets + Docker Secrets
- [ ] Database not directly exposed to internet
- [ ] CORS properly configured (not wide-open)

### Operations
- [ ] Deployment time < 5 minutes (automated)
- [ ] Rolling deployments with health checks
- [ ] Easy rollback capability
- [ ] Clear documentation for all procedures
- [ ] Database backup strategy in place

## Risk Management

### High Priority Risks
1. **SSH Lockout:** Losing SSH access during security hardening
   - Mitigation: Keep backup SSH session open, test before closing

2. **DNS Misconfiguration:** Domain not pointing to VPS
   - Mitigation: Verify DNS propagation before SSL setup

3. **Database Data Loss:** Accidental data deletion
   - Mitigation: Implement backup strategy before production use

4. **Secrets Exposure:** Credentials leaked in git history
   - Mitigation: Use .gitignore, git-secrets, never commit credentials

### Medium Priority Risks
1. **Docker Registry Rate Limits:** Pull limits from Docker Hub
   - Mitigation: Authenticate to Docker Hub or use private registry

2. **Let's Encrypt Rate Limits:** Too many certificate requests
   - Mitigation: Test with staging environment first

3. **Port Conflicts:** Nginx ports already in use
   - Mitigation: Check for existing services, adjust port mappings

## Timeline Estimate

### Minimum Viable Deployment
- **Total Time:** 8-12 hours
- **Includes:** Stages 1-5 (basic deployment with SSL and CORS)

### Full Production Deployment
- **Total Time:** 12-18 hours
- **Includes:** All 7 stages with documentation

### Per-Stage Breakdown
- Stage 1: 3 hours
- Stage 2: 1.5 hours
- Stage 3: 3 hours
- Stage 4: 1.5 hours
- Stage 5: 1 hour
- Stage 6: 4 hours
- Stage 7: 2 hours

## Next Steps

1. Review this roadmap and adjust priorities as needed
2. Begin with Stage 1: Server Setup
3. Complete each stage sequentially, documenting as you go
4. Test thoroughly at each stage before proceeding
5. Keep detailed notes of any deviations from the plan

## Documentation Structure

Each stage directory will contain:
- `README.md` - Overview and objectives
- `implementation-guide.md` - Step-by-step instructions
- `verification.md` - How to verify success
- `troubleshooting.md` - Common issues and solutions
- `scripts/` - Any automation scripts needed
- `configs/` - Configuration file templates

## Notes

- This is an internal tool prioritizing simplicity and security
- Single instance architecture (no HA/clustering needed initially)
- Focus on reliability over advanced features
- All stages should be completable by one person
- Documentation should enable future team members to understand and maintain the system
