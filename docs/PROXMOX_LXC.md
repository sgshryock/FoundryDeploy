# Running FoundryDeploy in Proxmox LXC Containers

This guide explains how to run FoundryDeploy inside a Proxmox LXC container. While VMs are the recommended approach, LXC containers work well with the automatic setup.

## Quick Start (Automatic Setup)

**On Proxmox Host:**
```bash
# 1. Create a privileged Ubuntu/Debian LXC container via web UI or CLI

# 2. Enable nesting (replace 200 with your CT ID)
sudo bash -c 'echo "features: nesting=1" >> /etc/pve/lxc/200.conf'

# 3. Start the container
pct start 200
```

**Inside the Container:**
```bash
# 4. Install curl (only dependency needed)
apt update && apt install -y curl

# 5. Run setup - it handles everything else automatically
curl -fsSL https://raw.githubusercontent.com/sgshryock/FoundryDeploy/main/setup -o setup
chmod +x setup
./setup
```

The setup script will:
- Auto-detect Proxmox LXC environment
- Install Docker, nginx, and other dependencies
- Remove AppArmor (required for Docker in LXC)
- Configure and start Foundry
- Display the container's IP address for access

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

### Automatic Setup (Recommended)

The setup script handles everything automatically. Just run:

```bash
# Start and enter the container
pct start 200
pct enter 200

# Install curl and run setup
apt update && apt install -y curl
curl -fsSL https://raw.githubusercontent.com/sgshryock/FoundryDeploy/main/setup -o setup
chmod +x setup
./setup
```

When prompted, select option 2 (Proxmox LXC Container) and let it install dependencies automatically.

### Manual Setup (Advanced)

If you prefer manual control or automatic setup fails:

```bash
# Update packages
apt update && apt upgrade -y

# Install prerequisites
apt install -y ca-certificates curl gnupg git nginx openssl

# Install Docker via convenience script
curl -fsSL https://get.docker.com | sh

# Fix AppArmor (required for Docker in LXC)
systemctl stop apparmor
systemctl disable apparmor
apt remove -y apparmor
systemctl restart docker

# Verify Docker works
docker run --rm hello-world
```

### Run FoundryDeploy Setup

```bash
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

### Rate Limit Errors (429)

**Symptom:** `Unexpected response 429: Too Many Requests` or `Failed to fetch release URL`

The Foundry container reinstalls on each startup and validates the download URL with Foundry's API. Too many restart attempts can trigger rate limiting.

**Solution 1: Wait**
```bash
# Stop the container to stop retry attempts
docker compose down

# Wait 30-60 minutes for rate limit to reset
# Then start again
docker compose up -d
```

**Solution 2: Use direct download URL**
1. Log into https://foundryvtt.com
2. Go to Purchased Licenses → Download
3. Copy the timed download URL
4. Add to .env:
```bash
echo 'FOUNDRY_RELEASE_URL=https://your-timed-url-here' >> .env
docker compose up -d
```

**Prevention:** The setup script caches the Foundry download in `/data/container_cache`. When using `./remove`, select "Keep everything" to preserve the cache and avoid re-downloading.

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
