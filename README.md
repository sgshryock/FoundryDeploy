# Foundry VTT Docker Deployment

Docker Compose setup for running Foundry VTT with a Caddy reverse proxy for local network access.

## Quick Start (Fresh Linux System)

```bash
# Update and upgrade your system first
sudo apt update && sudo apt upgrade -y

# Install dependencies (Debian/Ubuntu)
sudo apt install -y git curl docker.io docker-compose-v2
sudo usermod -aG docker $USER
newgrp docker

# Download and run setup
curl -O https://raw.githubusercontent.com/sgshryock/FoundryDeploy/main/setup
chmod +x setup
./setup
```

The setup script will:
1. Check that all dependencies are installed
2. Clone the repository
3. Prompt you for your Foundry credentials and configuration
4. Create the `.env` file
5. Start Foundry VTT

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
