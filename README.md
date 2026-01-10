# Foundry VTT Docker Deployment

Docker Compose setup for running Foundry VTT with a Caddy reverse proxy for local network access.

## Prerequisites

- Docker and Docker Compose installed
- A valid Foundry VTT license and account

## Setup

1. Clone this repository to your server

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
