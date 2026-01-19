# Running FoundryDeploy in Proxmox LXC Containers

This guide explains how to run FoundryDeploy inside a Proxmox LXC container. While VMs are the recommended approach, LXC containers can work with proper configuration.

## Quick Start

1. Create a **privileged** Debian 12 or Ubuntu 22.04 LXC container
2. Enable **nesting** feature (via SSH if not using root@pam)
3. Configure AppArmor (host config + remove inside container)
4. Install Docker inside the container
5. Run FoundryDeploy setup

## Container Requirements

### Privileged vs Unprivileged

| Type | Docker Support | Security | Recommended |
|------|---------------|----------|-------------|
| **Privileged** | Full | Lower isolation | Yes (for Docker) |
| Unprivileged | Limited/Complex | Higher isolation | No |

**Recommendation:** Use a **privileged container** for Docker workloads. Unprivileged containers require complex workarounds and may have stability issues.

### Minimum Resources

- **CPU:** 2 cores
- **RAM:** 2 GB (4 GB recommended)
- **Disk:** 20 GB (50 GB recommended)
- **Template:** Debian 12 or Ubuntu 22.04

---

## Proxmox Host Configuration

### Creating the LXC Container

#### Via Web UI

1. **Datacenter > Create CT**
2. **General:**
   - CT ID: (e.g., 200)
   - Hostname: foundry-lxc
   - **Privileged container: Checked**
3. **Template:** Debian 12 or Ubuntu 22.04
4. **Resources:**
   - Root Disk: 50 GB
   - CPU: 2 cores
   - Memory: 4096 MB
5. **Network:** Configure as needed (DHCP or static)

#### Via Command Line

```bash
# On Proxmox host
pct create 200 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname foundry-lxc \
  --memory 4096 \
  --cores 2 \
  --rootfs local-lvm:50 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --features nesting=1,keyctl=1 \
  --unprivileged 0
```

### Enabling Docker Support Features

**Important:** Proxmox only allows `root@pam` to modify privileged container features via the web UI. If you're using a different admin user, you'll see: `Permission check failed (changing feature flags for privileged container is only allowed for root@pam)`

**Workaround:** Edit the container config directly via SSH on the Proxmox host:

```bash
# SSH to Proxmox host and edit container config (replace 200 with your CT ID)
sudo bash -c 'echo "features: nesting=1" >> /etc/pve/lxc/200.conf'
```

Or edit manually:

```bash
# Edit container config (replace 200 with your CT ID)
nano /etc/pve/lxc/200.conf
```

Add or modify these lines:

```
# Enable nesting (required for Docker)
features: nesting=1,keyctl=1

# AppArmor profile for Docker
lxc.apparmor.profile: unconfined

# Required for Docker overlay filesystem
lxc.cap.drop:

# Mount required devices
lxc.mount.auto: proc:rw sys:rw cgroup:rw
```

**Alternative for newer Proxmox versions (7.0+):**

```bash
# Set features via command line
pct set 200 --features nesting=1,keyctl=1
```

### AppArmor Configuration

For Docker to work properly, you may need to configure AppArmor on the Proxmox host:

```bash
# On Proxmox host - disable AppArmor for this container
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/200.conf
```

Or create a custom AppArmor profile that allows Docker operations.

---

## Container Setup

### Start and Enter Container

```bash
# Start the container
pct start 200

# Enter the container
pct enter 200
```

### Install Docker

Inside the container:

```bash
# Update packages
apt update && apt upgrade -y

# Install prerequisites
apt install -y ca-certificates curl gnupg

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository (Debian)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# For Ubuntu, use:
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Fix AppArmor (required for Docker in LXC)
systemctl stop apparmor
systemctl disable apparmor
apt remove -y apparmor
systemctl restart docker

# Verify Docker works
docker run --rm hello-world
```

### Install Other Dependencies

```bash
apt install -y git nginx openssl
```

### Run FoundryDeploy Setup

```bash
# Create a user (optional but recommended)
adduser foundry
usermod -aG docker foundry
su - foundry

# Download and run setup
curl -fsSL https://raw.githubusercontent.com/sgshryock/FoundryDeploy/main/setup -o setup
chmod +x setup
./setup
```

---

## Troubleshooting

### Docker Fails to Start

**Symptom:** `Cannot connect to the Docker daemon`

**Check 1:** Verify nesting is enabled
```bash
# On Proxmox host
pct config 200 | grep features
# Should show: features: nesting=1,keyctl=1
```

**Check 2:** Verify AppArmor profile
```bash
# On Proxmox host
grep apparmor /etc/pve/lxc/200.conf
# Should show: lxc.apparmor.profile: unconfined
```

**Check 3:** Check Docker logs inside container
```bash
journalctl -u docker -n 50
```

### AppArmor Profile Errors

**Symptom:** `AppArmor enabled on system but the docker-default profile could not be loaded`

This error occurs because LXC containers cannot load AppArmor profiles even with `lxc.apparmor.profile: unconfined` in the host config.

**Solution:** Remove AppArmor inside the container:

```bash
# Inside the container
systemctl stop apparmor
systemctl disable apparmor
apt remove -y apparmor
systemctl restart docker

# Verify Docker works
docker run --rm hello-world
```

**Note:** This is required in addition to the host-side AppArmor configuration. The host config alone is not sufficient.

### Overlay Filesystem Errors

**Symptom:** `overlay: upper fs does not support RENAME_WHITEOUT`

**Solution:** The container filesystem may not support overlay2. Try:

1. Use privileged container (if not already)
2. Switch Docker storage driver to `vfs`:

```bash
# Create Docker daemon config
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "storage-driver": "vfs"
}
EOF

# Restart Docker
systemctl restart docker
```

Note: `vfs` is slower but more compatible.

### Permission Denied Errors

**Symptom:** Various permission denied errors when running Docker

**Solution:** Ensure you're using a privileged container:
```bash
# On Proxmox host
pct config 200 | grep unprivileged
# Should NOT show unprivileged: 1
```

If it shows `unprivileged: 1`, you need to recreate as a privileged container.

### systemd Not Available

**Symptom:** `Failed to connect to bus: No such file or directory`

Some LXC containers don't run systemd by default. FoundryDeploy will automatically detect this and use direct service management.

If you see warnings about systemd, services will be managed directly (nginx will be started with `nginx` command instead of `systemctl`).

---

## Security Considerations

Running Docker inside LXC containers, especially privileged ones, has security implications:

1. **Privileged containers** have more access to the host system
2. **Container escape** is theoretically possible
3. **Resource isolation** is weaker than VMs

### Mitigations

- Keep Proxmox and container packages updated
- Use firewall rules to restrict network access
- Consider VMs for production workloads
- Limit who has access to the Proxmox host

### When to Use VMs Instead

Consider using a Proxmox VM instead of LXC if:
- You need stronger security isolation
- You're running a public-facing server
- You have security compliance requirements
- You experience stability issues with Docker in LXC

---

## Alternative: Proxmox VM

If you encounter issues with LXC, a Proxmox VM is simpler to set up:

1. Create a VM with Debian 12 or Ubuntu 22.04
2. Install Docker normally
3. Run FoundryDeploy setup

VMs have full Docker support without special configuration.

See the main [README.md](../README.md) for standard VM/physical server setup.
