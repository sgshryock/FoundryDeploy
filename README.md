# Foundry VTT Server

Run your own Foundry VTT server on a Linux machine.

## Requirements

- A Linux server (Ubuntu recommended)
- A Foundry VTT license and account

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
