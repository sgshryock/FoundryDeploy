# Foundry VTT Server

Run your own Foundry VTT server on a Linux machine.

## Requirements

### Minimum
- Linux server (Ubuntu 20.04+, Debian 11+, Fedora, or Arch)
- 2 GB RAM
- 10 GB free disk space
- Docker 20.10+
- Docker Compose v2+
- nginx (installed by setup script)
- openssl (installed by setup script)
- A Foundry VTT license and account
- **User account with sudo privileges** (for nginx configuration)

### Recommended
- 4 GB RAM
- 50 GB free disk space (for modules and worlds)
- SSD storage for better performance
- Stable internet connection

## Setup

**Prerequisites:**
- You must have sudo privileges on your server
- Your user must be in the `docker` group (setup script will check and instruct if not)

1. Copy the `setup` script to your server
2. Run these commands:
```bash
sudo apt update && sudo apt upgrade -y
./setup
```

**Important:** Run `./setup` as a normal user (NOT with sudo). The script will prompt for your password when it needs elevated privileges for nginx configuration.

The setup script will:
- Install any missing software
- Download the server files
- Ask for your Foundry account details
- Start the server

**To update:** Simply run `./setup` again. It will:
- Check for repository updates
- Pull latest Foundry version if "release" tag is used
- Rebuild containers if configuration changed
- Skip reconfiguration (uses existing .env)

## Daily Use

**Start the server:**
```bash
./start
```

**Stop the server:**
```bash
./stop
```

**View server logs:**
```bash
./logs
```

**Uninstall Foundry:**
```bash
./remove
```
This script will:
- Stop and remove all Foundry containers
- Remove deployment files (compose.yml, start, stop, logs, remove)
- Prompt you to keep or delete:
  - **Foundry VTT software and all data** (worlds, modules, systems, assets, config)
  - **nginx configuration and SSL certificates**
- Always preserve the setup script for easy reinstallation
- Preserve settings (.env) if you keep data, delete it if you delete data

**Note:** If you keep your Foundry installation and data, the next time you run `./setup` it will:
- Use your existing Foundry VTT and data without redownloading
- Use your existing settings (.env) without asking for credentials again

## Accessing Foundry

Open your web browser and go to the address shown after running `./start`.

Example: `https://myserver.local`

**Note:** You'll see a security warning due to the self-signed SSL certificate. Click "Advanced" and "Proceed" to accept the certificate. This is normal for local network servers.

**Hostname Options:**
- **System hostname (recommended)**: Uses mDNS, works automatically on local network
- **Custom hostname**: Requires DNS configuration (like Pi-hole) to resolve
- **IP address**: Always works, but harder to remember (e.g., `https://192.168.1.100`)

---

## Updating Foundry

### Easiest Method: Re-run Setup

The simplest way to update everything:
```bash
./setup
```

This will automatically:
- Check for repository updates
- Pull the latest Foundry image (if using "release" tag)
- Rebuild containers if needed
- Use your existing configuration (no need to re-enter credentials)

### Manual Update to Latest Version

If you prefer manual control:

1. Edit `.env` and ensure `FOUNDRY_DOCKER_TAG=release`
2. Pull the new image:
```bash
docker compose pull
```
3. Restart the server:
```bash
./stop && ./start
```

### Manual Update to Specific Version

To switch to a specific Foundry version:

1. Edit `.env` and change `FOUNDRY_DOCKER_TAG=12` (or desired version number)
2. Pull the new image:
```bash
docker compose pull
```
3. Restart the server:
```bash
./stop && ./start
```

---

## Backup and Restore

### Backup Your Data

Create a backup of your Foundry data:
```bash
# Create backup directory
mkdir -p backups

# Backup Foundry data volume
docker run --rm \
  -v foundrydeploy_foundry_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/foundry-backup-$(date +%Y%m%d).tar.gz -C /data .

# Backup configuration
cp .env backups/env-backup-$(date +%Y%m%d)
```

### Restore from Backup

Restore your Foundry data from a backup:
```bash
# Stop containers
./stop

# Restore data volume
docker run --rm \
  -v foundrydeploy_foundry_data:/data \
  -v $(pwd)/backups:/backup \
  alpine sh -c "cd /data && tar xzf /backup/foundry-backup-YYYYMMDD.tar.gz"

# Restore configuration
cp backups/env-backup-YYYYMMDD .env

# Start containers
./start
```

### Automated Backups

Set up daily backups with cron:
```bash
# Edit crontab
crontab -e

# Add this line for daily 2 AM backups
0 2 * * * cd /path/to/FoundryDeploy && docker run --rm -v foundrydeploy_foundry_data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/foundry-backup-$(date +\%Y\%m\%d).tar.gz -C /data .
```

---

## Firewall Configuration

This setup uses standard HTTP (port 80) and HTTPS (port 443) ports.

### Ubuntu/Debian (UFW)

```bash
# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable
```

### Fedora/RHEL (firewalld)

```bash
# Allow HTTP and HTTPS
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# Reload firewall
sudo firewall-cmd --reload
```

---

## HTTPS Setup

**HTTPS is automatically configured during setup.** The setup script:
- Installs nginx as a reverse proxy
- Generates a self-signed SSL certificate (valid for 10 years)
- Configures nginx to redirect HTTP to HTTPS
- Exposes Foundry on ports 80 (HTTP) and 443 (HTTPS)

### Self-Signed Certificates (Default)

The default setup uses self-signed SSL certificates, which provide encryption but will trigger browser security warnings.

**Pros:**
- Works immediately, no additional setup
- Free and automatic
- Perfect for local network use
- Provides encryption for sensitive data

**Cons:**
- Browser security warnings (need to click "Advanced" → "Proceed")
- Not trusted by browsers automatically
- Not suitable for public internet-facing servers

**Accept the certificate warning:**
1. Visit `https://yourserver.local`
2. Click "Advanced" or "More information"
3. Click "Proceed to yourserver.local (unsafe)" or "Accept the Risk"
4. The warning won't appear again on that device

### Using Your Own SSL Certificates (Optional)

If you have valid SSL certificates (e.g., from Let's Encrypt), you can replace the self-signed certificates:

1. Copy your certificates to the server:
```bash
sudo cp your-cert.crt /etc/nginx/certs/foundry.crt
sudo cp your-cert.key /etc/nginx/certs/foundry.key
```

2. Set proper permissions:
```bash
sudo chmod 644 /etc/nginx/certs/foundry.crt
sudo chmod 600 /etc/nginx/certs/foundry.key
```

3. Reload nginx:
```bash
sudo systemctl reload nginx
```

### Obtaining Let's Encrypt Certificates

For a public domain with automatic certificate renewal:

1. Install certbot:
```bash
# Ubuntu/Debian
sudo apt install certbot python3-certbot-nginx

# Fedora
sudo dnf install certbot python3-certbot-nginx
```

2. Obtain certificate (requires domain pointing to server):
```bash
sudo certbot --nginx -d your-domain.com
```

3. Follow the prompts. Certbot will automatically configure nginx and set up renewal.

**Note:** Let's Encrypt requires a public domain and port 80 accessible from the internet.

---

## Troubleshooting

### Containers Won't Start

**Check Docker daemon:**
```bash
sudo systemctl status docker
sudo systemctl start docker
```

**Check logs:**
```bash
./logs
# Or specific container
docker compose logs foundry

# Check nginx logs
sudo journalctl -u nginx -n 50
```

**Check disk space:**
```bash
df -h
```

### Can't Access Foundry

**Verify containers are running:**
```bash
docker compose ps
```

**Check firewall:**
```bash
sudo ufw status  # Ubuntu/Debian
sudo firewall-cmd --list-all  # Fedora/RHEL
```

**Test from server:**
```bash
# Test Foundry container directly
curl http://localhost:30000

# Test nginx HTTPS
curl -k https://localhost

# Check nginx status
sudo systemctl status nginx
```

**Check port binding:**
```bash
docker compose ps
# Look for "127.0.0.1:30000->30000" in output

# Check nginx is listening on 80/443
sudo ss -tulpn | grep nginx
```

### Permission Errors

**Docker permission denied:**
If you see "permission denied while trying to connect to Docker daemon":
```bash
# Add your user to the docker group
sudo usermod -aG docker $USER

# Log out and back in for changes to take effect
# Or run this to apply immediately (in current shell only):
newgrp docker

# Verify you're in the docker group
groups | grep docker
```

**nginx configuration permission denied:**
Make sure you have sudo privileges. Test with:
```bash
sudo nginx -t
```

**Fix data volume permissions:**
```bash
./stop
docker run --rm -v foundrydeploy_foundry_data:/data alpine chown -R $(id -u):$(id -g) /data
./start
```

### Foundry Won't Download

**Check credentials in .env:**
```bash
# Verify FOUNDRY_USERNAME and FOUNDRY_PASSWORD are correct
grep FOUNDRY_USERNAME .env
```

**Verify your Foundry account:**
- Log in to https://foundryvtt.com
- Verify your license is active
- Check that your credentials are correct

### Port Already in Use

**Find what's using ports 80 or 443:**
```bash
sudo lsof -i :80
sudo lsof -i :443
# Or
sudo ss -tulpn | grep :80
sudo ss -tulpn | grep :443
```

**Common conflicts:**
- Apache or other web servers
- Another nginx instance

**Solution:**
Stop the conflicting service:
```bash
# For Apache
sudo systemctl stop apache2

# For other nginx instances
sudo systemctl stop nginx
# Then run ./start which will restart nginx with Foundry config
```

### Docker Compose Command Not Found

**Check Docker Compose version:**
```bash
docker compose version  # v2 (plugin)
docker-compose version  # v1 (standalone)
```

**Install Docker Compose v2:**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker-compose-v2
```

### Out of Disk Space

**Clean up Docker:**
```bash
docker system prune -a
```

**Check volume size:**
```bash
docker system df -v
```

**Remove old backups:**
```bash
ls -lh backups/
rm backups/foundry-backup-YYYYMMDD.tar.gz
```

---

## Advanced Configuration

### Running on Specific Network Interface

Edit `/etc/nginx/sites-available/foundry` to bind to a specific IP:
```nginx
server {
  listen 192.168.1.100:80;
  listen 192.168.1.100:443 ssl;
  # ... rest of configuration
}
```

Then reload nginx:
```bash
sudo systemctl reload nginx
```

### Resource Limits

Limit CPU and memory usage in `compose.yml`:
```yaml
foundry:
  deploy:
    resources:
      limits:
        cpus: '2.0'
        memory: 2G
      reservations:
        memory: 1G
```

### Custom nginx Configuration

For more advanced reverse proxy features, edit `/etc/nginx/sites-available/foundry`. After making changes:
```bash
# Test configuration
sudo nginx -t

# Reload if valid
sudo systemctl reload nginx
```

See [nginx documentation](https://nginx.org/en/docs/) for details.
