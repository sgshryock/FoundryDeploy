# Foundry VTT Docker Deployment

Docker Compose setup for running Foundry VTT with a Caddy reverse proxy for local network access.

## Quick Start

1. Copy the `setup` script to your server
2. Run:
```bash
sudo apt update && sudo apt upgrade -y
./setup
```

The setup script will check for missing dependencies, clone the repository, and guide you through configuration.

## Manual Setup

### Prerequisites

- Git
- Docker and Docker Compose
- A valid Foundry VTT license and account

#### Installing Docker (Debian/Ubuntu)

```bash
sudo apt update
sudo apt install -y git docker.io docker-compose-v2
sudo usermod -aG docker $USER
newgrp docker
```

### Installation

1. Clone this repository to your server:
   ```bash
   git clone https://github.com/sgshryock/FoundryDeploy.git
   cd FoundryDeploy
   ```

2. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

3. Edit `.env` and fill in your values:
   - `FOUNDRY_USERNAME` - Your Foundry VTT account username
   - `FOUNDRY_PASSWORD` - Your Foundry VTT account password
   - `FOUNDRY_ADMIN_KEY` - Admin password for the Foundry web UI
   - `FOUNDRY_HOSTNAME` - Hostname for this server (e.g., `myserver.local`)
   - `FOUNDRY_PORT` - Port to expose Foundry on (default: `80`)

## Deployment

Start the services:
```bash
docker compose up -d
```

Check that everything is running:
```bash
docker compose ps
```

View logs:
```bash
docker compose logs -f
```

## Access

Once deployed, access Foundry at:
```
http://<FOUNDRY_HOSTNAME>:<FOUNDRY_PORT>
```

If using the default port 80, you can omit the port:
```
http://<FOUNDRY_HOSTNAME>
```

## Stopping

```bash
docker compose down
```

To stop and remove the data volume (this will delete all Foundry data):
```bash
docker compose down -v
```
