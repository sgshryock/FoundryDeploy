# FoundryDeploy Proxmox LXC Testing Session Notes

## Session Goal
Test the new multi-platform support on a real Proxmox LXC container.

## Environment
- **Proxmox Host:** scadrial.local (user: tensoon)
- **Container ID:** 102
- **Container Name:** foundry-test
- **Template:** ubuntu-24.04-standard_24.04-2_amd64.tar.zst
- **Resources:** 2 cores, 2GB RAM, 20GB disk

---

## LXC Container Setup Issues & Solutions

### Issue 1: Privileged container features require root@pam
**Error:** `Permission check failed (changing feature flags for privileged container is only allowed for root@pam) (403)`

**Cause:** Proxmox hardcodes that only `root@pam` can modify privileged container features, regardless of Administrator role.

**Solution:** Edit config directly via SSH on Proxmox host:
```bash
sudo bash -c 'echo "features: nesting=1" >> /etc/pve/lxc/102.conf'
```

### Issue 2: Docker AppArmor profile fails to load
**Error:** `AppArmor enabled on system but the docker-default profile could not be loaded: apparmor_parser: Unable to replace "docker-default". Access denied.`

**Cause:** LXC containers can't load AppArmor profiles even with `lxc.apparmor.profile: unconfined` in the host config.

**Solution:** Disable and remove AppArmor inside the container:
```bash
systemctl stop apparmor
systemctl disable apparmor
apt remove -y apparmor
systemctl restart docker
```

---

## Complete LXC Setup Steps (for docs)

### On Proxmox Host (before starting container)
```bash
# Add nesting for Docker support
sudo bash -c 'echo "features: nesting=1" >> /etc/pve/lxc/102.conf'

# Add AppArmor unconfined (helps but not sufficient alone)
sudo bash -c 'echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/102.conf'
```

### Inside Container (after first boot)
```bash
# Update and install curl
apt update && apt install -y curl

# Install Docker
curl -fsSL https://get.docker.com | sh

# Fix AppArmor issue
systemctl stop apparmor
systemctl disable apparmor
apt remove -y apparmor
systemctl restart docker

# Verify Docker works
docker run --rm hello-world

# Install other dependencies
apt install -y git nginx openssl
```

---

## Current State
- Container 102 created and running
- Docker installed and working (hello-world passed)
- Dependencies installed: git, nginx, openssl, curl

## Next Steps
1. Run FoundryDeploy setup script:
   ```bash
   cd ~
   curl -fsSL https://raw.githubusercontent.com/sgshryock/FoundryDeploy/main/setup -o setup
   chmod +x setup
   ./setup
   ```

2. Verify environment detection shows:
   - `DEPLOY_ENV_TYPE: proxmox_lxc`
   - `DEPLOY_SERVICE_MANAGER: systemd`

3. Complete Foundry setup (will need Foundry credentials)

4. Test start/stop/status commands

5. Update `docs/PROXMOX_LXC.md` with AppArmor fix

---

## Documentation Updates Needed

The `docs/PROXMOX_LXC.md` file should be updated to include:
1. The AppArmor removal step (not just host config)
2. Note that `lxc.apparmor.profile: unconfined` alone is insufficient
3. Tested on Ubuntu 24.04 LXC template

---

## Git Status
Branch is 4 commits ahead of origin/main:
```
5ee4be4 Add CI workflows and unit tests
64613c9 Fix critical bugs found in code review
4881565 Add multi-platform support for Proxmox LXC and AWS EC2
9955e03 Add backup/restore, status monitoring, and security hardening
```

Unpushed - run `git push` when ready.
