#!/bin/bash

# lib/core.sh
# Core utilities for logging, error handling, and execution

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# System Constants
SOCKETFILTERFW_CMD="/usr/libexec/ApplicationFirewall/socketfilterfw"

# Logging
# Logging
_LOADED_MODULES=""
load_module() {
    local name="$1"
    if [[ "$_LOADED_MODULES" != *" $name "* ]]; then
        if [ -f "$LIB_DIR/$name.sh" ]; then
            source "$LIB_DIR/$name.sh"
            _LOADED_MODULES="$_LOADED_MODULES $name "
        else
            error "Module library $name.sh not found in $LIB_DIR"
            exit 1
        fi
    fi
}

# Logging
info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
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
    
    # Check for auto-yes override
    if [ "${BETTER_ANONYMITY_AUTO_YES:-0}" -eq 1 ]; then
        info "$prompt [y/N] (Auto-Yes)"
        return 0
    fi

    # Default to No if just Enter, strictly require Y/y
    warn "$prompt [y/N]"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    fi
    return 1
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

# Check Functions
# ---------------

# Check if a brew formula is installed
is_brew_installed() {
    local formula="$1"
    # Ensure brew is available
    if ! command -v brew >/dev/null; then return 1; fi
    
    if brew list --formula "$formula" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Check if a brew cask is installed
is_cask_installed() {
    local cask="$1"
    if ! command -v brew >/dev/null; then return 1; fi
    
    if brew list --cask "$cask" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Check if an app is installed in /Applications or other standard locations
is_app_installed() {
    local app_name="$1" # e.g. "Firefox.app"
    
    # Check standard locations
    if [ -d "/Applications/$app_name" ]; then
        return 0
    fi
    if [ -d "$HOME/Applications/$app_name" ]; then
        return 0
    fi
    if [ -d "/System/Applications/$app_name" ]; then
        return 0
    fi
    
    # Check if brew thinks it's likely installed (rough heuristic for cask)
    # This might return true for "firefox", but we are looking for "Firefox.app"
    # So we don't rely only on brew list for physical app presence check.
    
    return 1
}

# Fast check if a command exists in PATH (Faster than brew list)
check_installed() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Spinner Implementation
_SPINNER_PID=""

_spinner() {
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep "$1")" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

start_spinner() {
    # Only if interactive
    if [ -t 1 ]; then
        # Hide cursor
        tput civis
        # Run spinner in background
        _spinner $$ &
        _SPINNER_PID=$!
    fi
}

stop_spinner() {
    if [ -n "$_SPINNER_PID" ]; then
        disown "$_SPINNER_PID"
        kill "$_SPINNER_PID" >/dev/null 2>&1
        _SPINNER_PID=""
        tput cnorm # Reset cursor
        # Clear the entire line using CR + Clear to EOL
        printf "\r\033[K"
    fi
}

# Wrapper for commands to show spinner
execute_with_spinner() {
    local msg="$1"
    shift
    local cmd="$*"
    
    info "$msg"
    
    # Temp Log
    local temp_log
    temp_log=$(mktemp /tmp/b-a-install.XXXXXX)
    
    start_spinner
    
    # Execute command
    "$@" > "$temp_log" 2>&1
    local status=$?
    
    stop_spinner
    
    if [ $status -eq 0 ]; then
        rm -f "$temp_log"
        return 0
    else
        error "Command failed. Output:"
        cat "$temp_log"
        rm -f "$temp_log"
        return $status
    fi
}

# Generic Brew Installer with Optimization
# Usage: install_brew_package "package_name" [command_name]
install_brew_package() {
    local package="$1"
    local cmd="${2:-$package}" # Default command name same as package

    info "Checking installation for $package..."
    
    # 1. Fast Path: Check command
    if check_installed "$cmd"; then
        info "$package is already installed (found $cmd)."
        return 0
    fi

    # 2. Slow Path: Check brew list (in case command differs or not in path)
    if is_brew_installed "$package"; then
        info "$package is installed via Homebrew."
        return 0
    fi

    # 3. Install
    execute_with_spinner "Installing $package (this may take a while)..." brew install "$package"
}

# Generic Cask Installer
# Usage: install_cask_check "cask_name" "App Name.app"
install_cask_package() {
    local cask="$1"
    local app_name="$2"

    info "Checking installation for $cask..."

    if [ -n "$app_name" ] && is_app_installed "$app_name"; then
        info "$app_name is already installed in /Applications."
        return 0
    fi

    if is_cask_installed "$cask"; then
        info "$cask is already installed via Homebrew Cask."
        return 0
    fi

    execute_with_spinner "Installing $cask (this may take a while)..." brew install --cask "$cask"
}

# Smart Config Copy
# Usage: check_config_and_backup source destination [sudo]
check_config_and_backup() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"

    if [ ! -f "$src" ]; then
        error "Source config not found: $src"
        return 1
    fi

    local cp_cmd="cp"
    if [ "$use_sudo" == "sudo" ]; then
        cp_cmd="sudo cp"
    fi

    if [ -f "$dest" ]; then
        # Check for difference
        local diff_cmd="cmp -s"
        # If we need sudo for cp, we likely need it for reading if check fails, 
        # but let's try standard first. use sudo cmp if sudo requested.
        if [ "$use_sudo" == "sudo" ]; then
             diff_cmd="sudo cmp -s"
        fi
        
        if $diff_cmd "$src" "$dest" 2>/dev/null; then
            info "Config at $dest is identical. Skipping update."
            return 0
        fi

        info "Config differs at $dest. Creating backup..."
        $cp_cmd "$dest" "${dest}.bak.$(date +%s)"
    fi

    info "Installing config to $dest..."
    $cp_cmd "$src" "$dest"
}

# Sudo Keep-Alive
# ---------------
SUDO_KEEPALIVE_PID=""

start_sudo_keepalive() {
    # If already running, skip
    if [ -n "$SUDO_KEEPALIVE_PID" ] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
        return
    fi
    
    # Check if we have sudo privileges
    info "Validating sudo access..."
    sudo -v || return 1 # Exit if user cancels or fails
    
    # Loop in background
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & ) &
    SUDO_KEEPALIVE_PID=$!
    
    # Trap exit to kill it
    trap stop_sudo_keepalive EXIT
}

stop_sudo_keepalive() {
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
        SUDO_KEEPALIVE_PID=""
    fi
}

# System Checks (Merged from checks.sh)
# -----------------------------------

require_root() {
    ensure_root "$@"
}

require_brew() {
    if ! command -v brew &> /dev/null; then
        warn "Homebrew not found. Attempting to locate based on architecture..."
        if [ -x "$BREW_PREFIX/bin/brew" ]; then
             # Already exported in platform.sh presumably, but ensuring PATH
             export PATH="$BREW_PREFIX/bin:$PATH"
             info "Found Homebrew at $BREW_PREFIX/bin/brew."
        else
            if ask_confirmation "Homebrew is required but not found. Install it?"; then
                 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                 # Re-check
                 if [ -x "$BREW_PREFIX/bin/brew" ]; then
                    export PATH="$BREW_PREFIX/bin:$PATH"
                 else
                    die "Homebrew installation failed or path unavailable."
                 fi
            else
                die "Homebrew is required to proceed."
            fi
        fi
    fi
}

check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        warn "No internet connection detected. Network-dependent steps may fail."
    fi
}

