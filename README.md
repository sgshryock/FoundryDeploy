# Foundry VTT Server

Run your own Foundry VTT server on a Linux machine.

## Requirements

### Minimum
- Linux server (Ubuntu 20.04+, Debian 11+, Fedora, or Arch)
- 2 GB RAM
- 10 GB free disk space
- Docker 20.10+
- Docker Compose v2+
- A Foundry VTT license and account

### Recommended
- 4 GB RAM
- 50 GB free disk space (for modules and worlds)
- SSD storage for better performance
- Stable internet connection

## Setup

1. Copy the `setup` script to your server
2. Run these commands:
```bash
sudo apt update && sudo apt upgrade -y
./setup
```

The setup script will:
- Install any missing software
- Download the server files
- Ask for your Foundry account details
- Start the server

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

## Accessing Foundry

Open your web browser and go to the address shown after running `./start`.

Example: `http://myserver.local`

---

## Updating Foundry

### Update to Latest Version

1. Edit `.env` and change `FOUNDRY_DOCKER_TAG=release`
2. Pull the new image:
```bash
docker compose pull
```
3. Restart the server:
```bash
./stop && ./start
```

### Update to Specific Version

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

### Ubuntu/Debian (UFW)

```bash
# Allow HTTP
sudo ufw allow 80/tcp

# For HTTPS
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable
```

### Fedora/RHEL (firewalld)

```bash
# Allow HTTP
sudo firewall-cmd --permanent --add-service=http

# For HTTPS
sudo firewall-cmd --permanent --add-service=https

# Reload firewall
sudo firewall-cmd --reload
```

### Custom Port

If you changed `FOUNDRY_PORT` from 80:
```bash
# UFW
sudo ufw allow 8080/tcp

# firewalld
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

---

## HTTPS Setup

### Option 1: Automatic HTTPS with Caddy (Recommended)

If you have a public domain pointing to your server, Caddy can automatically obtain and renew SSL certificates:

1. Update your `Caddyfile`:
```
your-domain.com {
    reverse_proxy foundry:30000
}
```

2. Open port 443 in your firewall:
```bash
sudo ufw allow 443/tcp
```

3. Restart:
```bash
./stop && ./start
```

Caddy will automatically obtain certificates from Let's Encrypt.

### Option 2: Manual Certificates

If you have your own SSL certificates:

1. Create a `certs` directory and place your `cert.pem` and `key.pem` files in it

2. Update `Caddyfile`:
```
:443 {
    tls /etc/caddy/cert.pem /etc/caddy/key.pem
    reverse_proxy foundry:30000
}
```

3. Update `compose.yml` to mount certificates:
```yaml
caddy:
  volumes:
    - ./Caddyfile:/etc/caddy/Caddyfile:ro
    - ./certs:/etc/caddy:ro
  ports:
    - "${FOUNDRY_PORT:-80}:80"
    - "443:443"
```

4. Restart:
```bash
./stop && ./start
```

### Option 3: HTTP Only (Current Default)

The default configuration uses HTTP only, which is suitable for:
- Local network use only
- When behind a separate reverse proxy or load balancer
- Testing and development environments

**Note:** For internet-facing servers with sensitive data, HTTPS is strongly recommended.

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
docker compose logs caddy
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
curl http://localhost:${FOUNDRY_PORT}
```

**Check port binding:**
```bash
docker compose ps
# Look for "0.0.0.0:80->80" or similar in output
```

### Permission Errors

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

**Find what's using the port:**
```bash
sudo lsof -i :80
# Or
sudo ss -tulpn | grep :80
```

**Change Foundry port:**
1. Edit `.env` and set `FOUNDRY_PORT=8080`
2. Restart: `./stop && ./start`

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

Edit `compose.yml` to bind to a specific IP:
```yaml
caddy:
  ports:
    - "192.168.1.100:${FOUNDRY_PORT:-80}:80"
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

### Custom Caddy Configuration

For more advanced reverse proxy features, edit the `Caddyfile`. See [Caddy documentation](https://caddyserver.com/docs/) for details.
