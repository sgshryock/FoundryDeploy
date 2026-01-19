#!/bin/bash
# FoundryDeploy - Shared Library Functions
# Source this file in other scripts: source "$(dirname "$0")/lib/common.sh"

# Prevent double-sourcing
if [ -n "$_FOUNDRYDEPLOY_COMMON_LOADED" ]; then
    return 0
fi
_FOUNDRYDEPLOY_COMMON_LOADED=1

# =============================================================================
# Logging Functions
# =============================================================================

# Colors for output (disabled if not a terminal)
if [ -t 1 ]; then
    _RED='\033[0;31m'
    _YELLOW='\033[0;33m'
    _GREEN='\033[0;32m'
    _BLUE='\033[0;34m'
    _NC='\033[0m' # No Color
else
    _RED=''
    _YELLOW=''
    _GREEN=''
    _BLUE=''
    _NC=''
fi

log_info() {
    echo -e "${_BLUE}[INFO]${_NC} $*"
}

log_ok() {
    echo -e "${_GREEN}[OK]${_NC} $*"
}

log_warn() {
    echo -e "${_YELLOW}[WARN]${_NC} $*"
}

log_error() {
    echo -e "${_RED}[ERROR]${_NC} $*" >&2
}

# =============================================================================
# Docker Functions
# =============================================================================

# Check if Docker Compose is available (modern or legacy)
# Returns 0 if available, 1 if not
# Sets DOCKER_COMPOSE_CMD to the command to use
check_docker_compose() {
    if docker compose version &>/dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        return 0
    elif command -v docker-compose &>/dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
        return 0
    else
        log_error "Docker Compose is not installed"
        return 1
    fi
}

# Check if Docker daemon is running
check_docker_daemon() {
    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running"
        echo "  Start it with: sudo systemctl start docker"
        return 1
    fi
    return 0
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed"
        return 1
    fi
    return 0
}

# Get the full volume name used by Docker Compose
# Docker Compose prefixes volume names with project name
get_volume_name() {
    local volume_name="${1:-foundry_data}"
    local project_name
    project_name="$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')"
    echo "${project_name}_${volume_name}"
}

# =============================================================================
# Environment File Functions
# =============================================================================

# Parse a value from .env file
# Usage: value=$(parse_env_value "KEY")
parse_env_value() {
    local key=$1
    local env_file="${2:-.env}"
    if [ -f "$env_file" ]; then
        grep -E "^${key}=" "$env_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/#.*//'
    fi
}

# Check that .env file exists with helpful error
require_env_file() {
    if [ ! -f .env ]; then
        log_error "No .env file found"
        echo "  Run ./setup first or copy .env.example to .env"
        return 1
    fi
    return 0
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_non_empty() {
    local value=$1
    local field_name=$2
    if [ -z "$value" ]; then
        log_error "$field_name cannot be empty"
        return 1
    fi
    return 0
}

validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Port must be a number between 1 and 65535"
        return 1
    fi
    return 0
}

validate_hostname() {
    local hostname=$1
    # Allow hostname, FQDN, or IP address
    if ! [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]] && \
       ! [[ "$hostname" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "Invalid hostname format"
        return 1
    fi
    return 0
}

# =============================================================================
# Certificate Functions
# =============================================================================

# Get SSL certificate expiration date
# Returns date string or empty if cert doesn't exist
get_cert_expiry() {
    local cert_path="${1:-/etc/nginx/certs/foundry.crt}"
    if [ -f "$cert_path" ]; then
        sudo openssl x509 -enddate -noout -in "$cert_path" 2>/dev/null | cut -d= -f2
    fi
}

# Check if SSL certificate will expire within N days
# Returns 0 if valid, 1 if expired/expiring
check_cert_valid() {
    local cert_path="${1:-/etc/nginx/certs/foundry.crt}"
    local days="${2:-30}"
    local seconds=$((days * 86400))

    if [ ! -f "$cert_path" ]; then
        return 1
    fi

    if sudo openssl x509 -checkend "$seconds" -noout -in "$cert_path" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Service Status Functions
# =============================================================================

# Check if nginx is running
is_nginx_running() {
    systemctl is-active --quiet nginx 2>/dev/null
}

# Check if Foundry container is running
is_foundry_running() {
    docker compose ps 2>/dev/null | grep -q "foundry.*Up"
}

# Check if Foundry container is healthy
is_foundry_healthy() {
    local health
    health=$(docker inspect --format='{{.State.Health.Status}}' foundry 2>/dev/null)
    [ "$health" = "healthy" ]
}

# =============================================================================
# Utility Functions
# =============================================================================

# Get script directory (handles symlinks)
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir
        dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)G"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)M"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)K"
    else
        echo "${bytes}B"
    fi
}

# Format seconds to human readable duration
format_duration() {
    local seconds=$1
    if [ "$seconds" -ge 86400 ]; then
        echo "$((seconds / 86400)) days"
    elif [ "$seconds" -ge 3600 ]; then
        echo "$((seconds / 3600)) hours"
    elif [ "$seconds" -ge 60 ]; then
        echo "$((seconds / 60)) minutes"
    else
        echo "$seconds seconds"
    fi
}
