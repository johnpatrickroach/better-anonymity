#!/bin/bash

# lib/core.sh
# Core utilities for logging, error handling, and execution

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

die() {
    error "$1"
    exit 1
}

header() {
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}   $1${NC}"
    echo -e "${BLUE}======================================================================${NC}"
}

# User Interaction
ask_confirmation() {
    local prompt="$1"
    warn "$prompt (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        return 1
    fi
    return 0
    return 0
}

# Ensure the script is run as root (auto-elevate)
ensure_root() {
    if [ "$EUID" -ne 0 ]; then
        # Resolve script path for sudo
        local script_path
        if [[ "$0" = /* ]]; then
            script_path="$0"
        else
            script_path="$PWD/${0#./}"
        fi
        
        warn "Administrator privileges are required. Elevating..."
        sudo "$script_path" "$@" || {
            error "Elevation failed. Administrator privileges are required."
            exit 1
        }
        exit 0
    fi
}


# Execution wrappers
# execute_sudo "Description" command args...
execute_sudo() {
    local desc="$1"
    shift
    info "$desc"
    # check if we are root, if not use sudo
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}
