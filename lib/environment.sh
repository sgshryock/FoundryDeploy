#!/bin/bash
# FoundryDeploy - Environment Detection Library
# Source this file in other scripts: source "$(dirname "$0")/lib/environment.sh"

# Prevent double-sourcing
if [ -n "$_FOUNDRYDEPLOY_ENV_LOADED" ]; then
    return 0
fi
_FOUNDRYDEPLOY_ENV_LOADED=1

# =============================================================================
# Environment Detection
# =============================================================================

# Exported variables:
# - DEPLOY_ENV_TYPE: physical | proxmox_vm | proxmox_lxc | aws_ec2
# - DEPLOY_HAS_SYSTEMD: true | false
# - DEPLOY_IS_PRIVILEGED: true | false (relevant for LXC)
# - DEPLOY_SERVICE_MANAGER: systemd | direct

# Detect if running in LXC container
_detect_lxc() {
    # Method 1: Check /proc/1/environ for container=lxc
    if [ -f /proc/1/environ ] && grep -qa 'container=lxc' /proc/1/environ 2>/dev/null; then
        return 0
    fi

    # Method 2: Use systemd-detect-virt if available
    if command -v systemd-detect-virt &>/dev/null; then
        local virt
        virt=$(systemd-detect-virt 2>/dev/null)
        if [ "$virt" = "lxc" ] || [ "$virt" = "lxc-libvirt" ]; then
            return 0
        fi
    fi

    # Method 3: Check for LXC-specific files
    if [ -f /dev/lxd/sock ] || [ -f /.dockerenv ]; then
        # /.dockerenv is Docker, not LXC
        [ -f /.dockerenv ] && return 1
        return 0
    fi

    # Method 4: Check cgroup for lxc
    if [ -f /proc/1/cgroup ] && grep -qa 'lxc' /proc/1/cgroup 2>/dev/null; then
        return 0
    fi

    return 1
}

# Detect if running on AWS EC2
_detect_ec2() {
    # Skip EC2 detection if we're in an LXC container (mutually exclusive)
    # This avoids the slow curl timeout in LXC environments
    if [ -f /proc/1/environ ] && grep -qa 'container=lxc' /proc/1/environ 2>/dev/null; then
        return 1
    fi
    if [ -f /proc/1/cgroup ] && grep -qa 'lxc' /proc/1/cgroup 2>/dev/null; then
        return 1
    fi

    # Method 1: Check DMI data for Amazon/EC2 (fast, no network)
    if [ -f /sys/devices/virtual/dmi/id/sys_vendor ]; then
        local vendor
        vendor=$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null)
        if [[ "$vendor" == *"Amazon"* ]]; then
            return 0
        fi
    fi

    if [ -f /sys/devices/virtual/dmi/id/product_name ]; then
        local product
        product=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)
        if [[ "$product" == *"EC2"* ]]; then
            return 0
        fi
    fi

    # Method 2: Check for EC2-specific files
    if [ -f /sys/hypervisor/uuid ] && grep -qi '^ec2' /sys/hypervisor/uuid 2>/dev/null; then
        return 0
    fi

    # Method 3: Check EC2 metadata service (slow, has network timeout)
    # Only try this if DMI checks didn't find anything
    if curl -s --connect-timeout 1 -m 2 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        return 0
    fi

    return 1
}

# Detect if running in Proxmox VM (not LXC)
_detect_proxmox_vm() {
    # Must not be LXC first
    if _detect_lxc; then
        return 1
    fi

    # Method 1: Check DMI for QEMU/Proxmox
    if [ -f /sys/devices/virtual/dmi/id/sys_vendor ]; then
        local vendor
        vendor=$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null)
        if [[ "$vendor" == *"QEMU"* ]] || [[ "$vendor" == *"Proxmox"* ]]; then
            return 0
        fi
    fi

    if [ -f /sys/devices/virtual/dmi/id/product_name ]; then
        local product
        product=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)
        if [[ "$product" == *"QEMU"* ]] || [[ "$product" == *"Standard PC"* ]]; then
            # Additional check to distinguish from other QEMU setups
            if [ -f /sys/devices/virtual/dmi/id/bios_vendor ]; then
                local bios
                bios=$(cat /sys/devices/virtual/dmi/id/bios_vendor 2>/dev/null)
                if [[ "$bios" == *"SeaBIOS"* ]] || [[ "$bios" == *"OVMF"* ]]; then
                    return 0
                fi
            fi
        fi
    fi

    # Method 2: Use systemd-detect-virt
    if command -v systemd-detect-virt &>/dev/null; then
        local virt
        virt=$(systemd-detect-virt 2>/dev/null)
        if [ "$virt" = "qemu" ] || [ "$virt" = "kvm" ]; then
            return 0
        fi
    fi

    return 1
}

# Detect if systemd is available and functional
_detect_systemd() {
    # Method 1: Check if systemctl command exists and works
    if command -v systemctl &>/dev/null && systemctl --version &>/dev/null; then
        # Verify systemd is actually the init system (PID 1)
        if [ -d /run/systemd/system ]; then
            return 0
        fi
    fi

    return 1
}

# Detect if running in privileged mode (LXC-specific)
_detect_privileged() {
    # For non-LXC environments, always return true (privileged)
    if ! _detect_lxc; then
        return 0
    fi

    # In LXC: check if we can access privileged operations
    # Method 1: Check if we can read kernel parameters
    if [ -r /proc/sys/kernel/cap_last_cap ]; then
        local cap_last
        cap_last=$(cat /proc/sys/kernel/cap_last_cap 2>/dev/null)
        # Full capabilities typically means privileged
        if [ "$cap_last" -ge 40 ] 2>/dev/null; then
            return 0
        fi
    fi

    # Method 2: Check if /dev/fuse is writable (often blocked in unprivileged)
    if [ -w /dev/fuse ] 2>/dev/null; then
        return 0
    fi

    # Method 3: Check for capability bounding set
    if command -v capsh &>/dev/null; then
        if capsh --print 2>/dev/null | grep -q 'cap_sys_admin'; then
            return 0
        fi
    fi

    return 1
}

# =============================================================================
# Main Detection Function
# =============================================================================

detect_environment() {
    # Allow override via environment variable or .env file
    local env_override="${DEPLOY_ENVIRONMENT:-auto}"
    local service_override="${DEPLOY_SERVICE_MANAGER:-auto}"

    # Check for .env file override
    if [ -f .env ]; then
        local file_env
        file_env=$(grep -E "^DEPLOY_ENVIRONMENT=" .env 2>/dev/null | cut -d'=' -f2- | tr -d ' ') || true
        if [ -n "$file_env" ] && [ "$file_env" != "auto" ]; then
            env_override="$file_env"
        fi

        local file_service
        file_service=$(grep -E "^DEPLOY_SERVICE_MANAGER=" .env 2>/dev/null | cut -d'=' -f2- | tr -d ' ') || true
        if [ -n "$file_service" ] && [ "$file_service" != "auto" ]; then
            service_override="$file_service"
        fi
    fi

    # Detect environment type
    if [ "$env_override" != "auto" ]; then
        DEPLOY_ENV_TYPE="$env_override"
    elif _detect_lxc; then
        DEPLOY_ENV_TYPE="proxmox_lxc"
    elif _detect_ec2; then
        DEPLOY_ENV_TYPE="aws_ec2"
    elif _detect_proxmox_vm; then
        DEPLOY_ENV_TYPE="proxmox_vm"
    else
        DEPLOY_ENV_TYPE="physical"
    fi

    # Detect systemd availability
    if [ "$service_override" = "systemd" ]; then
        DEPLOY_HAS_SYSTEMD=true
        DEPLOY_SERVICE_MANAGER="systemd"
    elif [ "$service_override" = "direct" ]; then
        DEPLOY_HAS_SYSTEMD=false
        DEPLOY_SERVICE_MANAGER="direct"
    elif _detect_systemd; then
        DEPLOY_HAS_SYSTEMD=true
        DEPLOY_SERVICE_MANAGER="systemd"
    else
        DEPLOY_HAS_SYSTEMD=false
        DEPLOY_SERVICE_MANAGER="direct"
    fi

    # Detect privileged status
    if _detect_privileged; then
        DEPLOY_IS_PRIVILEGED=true
    else
        DEPLOY_IS_PRIVILEGED=false
    fi

    # Export variables
    export DEPLOY_ENV_TYPE
    export DEPLOY_HAS_SYSTEMD
    export DEPLOY_IS_PRIVILEGED
    export DEPLOY_SERVICE_MANAGER
}

# =============================================================================
# Environment Information Functions
# =============================================================================

# Get human-readable environment description
get_environment_description() {
    case "$DEPLOY_ENV_TYPE" in
        physical)
            echo "Physical Linux Server"
            ;;
        proxmox_vm)
            echo "Proxmox Virtual Machine"
            ;;
        proxmox_lxc)
            if [ "$DEPLOY_IS_PRIVILEGED" = true ]; then
                echo "Proxmox LXC Container (Privileged)"
            else
                echo "Proxmox LXC Container (Unprivileged)"
            fi
            ;;
        aws_ec2)
            echo "AWS EC2 Instance"
            ;;
        *)
            echo "Unknown Environment ($DEPLOY_ENV_TYPE)"
            ;;
    esac
}

# Get public IP for EC2 instances
get_ec2_public_ip() {
    if [ "$DEPLOY_ENV_TYPE" = "aws_ec2" ]; then
        curl -s --connect-timeout 2 -m 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null
    fi
}

# Get instance ID for EC2 instances
get_ec2_instance_id() {
    if [ "$DEPLOY_ENV_TYPE" = "aws_ec2" ]; then
        curl -s --connect-timeout 2 -m 5 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null
    fi
}

# Print environment summary
print_environment_summary() {
    echo "Environment: $(get_environment_description)"
    echo "  Type: $DEPLOY_ENV_TYPE"
    echo "  Service Manager: $DEPLOY_SERVICE_MANAGER"
    echo "  Systemd Available: $DEPLOY_HAS_SYSTEMD"

    if [ "$DEPLOY_ENV_TYPE" = "proxmox_lxc" ]; then
        echo "  Privileged: $DEPLOY_IS_PRIVILEGED"
    fi

    if [ "$DEPLOY_ENV_TYPE" = "aws_ec2" ]; then
        local public_ip
        public_ip=$(get_ec2_public_ip)
        if [ -n "$public_ip" ]; then
            echo "  Public IP: $public_ip"
        fi
    fi
}

# =============================================================================
# Initialize on source
# =============================================================================

# Auto-detect environment when this file is sourced
detect_environment
