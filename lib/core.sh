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

# Resolve airport(8) path (legacy or modern). Echo path if found, empty otherwise.
get_airport_bin() {
    if [ -x "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport" ]; then
        echo "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
    elif [ -x "/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport" ]; then
        echo "/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport"
    else
        echo ""
    fi
}

# Check if airport or a suitable network utility exists
check_airport_exists() {
    [ -n "$(get_airport_bin)" ] || command -v networksetup >/dev/null 2>&1
}

# Logging
# Logging
_LOADED_MODULES=":"
load_module() {
    local name="$1"
    if [[ "$_LOADED_MODULES" != *":$name:"* ]]; then
        if [ -f "$LIB_DIR/$name.sh" ]; then
            source "$LIB_DIR/$name.sh"
            _LOADED_MODULES="${_LOADED_MODULES}${name}:"
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

# Helper: Cross-platform sed in-place wrapper
# Defaults to macOS (BSD) style 'sed -i ""' if not specified otherwise
sed_in_place() {
    # Usage: sed_in_place 'pattern' file
    local expression="$1"
    local file="$2"
    
    if sed --version 2>/dev/null | grep -q GNU; then
        # GNU sed
        sed -i "$expression" "$file"
    else
        # BSD/macOS sed
        sed -i '' "$expression" "$file"
    fi
}

# Helper: Check if a TCP port is open (Robust: nc -> bash /dev/tcp)
check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-1}"
    
    # Method 1: Netcat (nc)
    if command -v nc &>/dev/null; then
        # -z: zero-I/O mode (scanning)
        # -G: timeout (macOS/BSD), -w (GNU)? macOS nc uses -G for connection timeout usually, or -w.
        # -w 1 is generally portable for 1 second timeout.
        if nc -z -w "$timeout" "$host" "$port" &>/dev/null; then
            return 0
        fi
        return 1
    fi
    
    # Method 2: Bash /dev/tcp (Fallback)
    # Note: /dev/tcp is a bash feature, not a real file.
    # We use a subshell with timeout to prevent hanging.
    if timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

header() {
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}   $1${NC}"
    echo -e "${BLUE}======================================================================${NC}"
}

# section "Title" "line1" "line2" ...
# Convenience wrapper: header + multi-line body text.
section() {
    local title="$1"
    shift
    header "$title"
    while [ "$#" -gt 0 ]; do
        echo "$1"
        shift
    done
}

# Banner
show_banner() {
    if [ -f "$LIB_DIR/banner.txt" ]; then
        cat "$LIB_DIR/banner.txt"
    fi
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

# ask_confirmation_with_info "Title" "description line 1" "description line 2" ...
# Prints a short description block, then a standard yes/no confirmation.
ask_confirmation_with_info() {
    local title="$1"
    shift

    # Optional description lines
    if [ "$#" -gt 0 ]; then
        section "$title" "$@"
    else
        header "$title"
    fi

    ask_confirmation "Proceed?"
}

# Ensure the script is run as root (auto-elevate)
# Usage: ensure_root "$@"
# WARNING: This re-executes the script. You MUST pass "$@" to forward arguments.
# If called from a function, "$@" are the function's args, which may not match script args.
# For subcommands, consider using start_sudo_keepalive instead.
ensure_root() {
    if [ "$EUID" -ne 0 ]; then
        # Resolve script path for sudo
        local script_path
        if [ -n "$SOURCE" ]; then
             script_path="$SOURCE"
        elif [[ "$0" = /* ]]; then
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
    info "$desc" >&2
    # check if we are root, if not use sudo
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# execute_brew "Description" command args...
# Wraps brew execution to ensure it runs as non-root user if possible.
execute_brew() {
    local desc="$1"
    shift
    
    info "$desc" >&2
    
    # If we are root (EUID 0)
    if [[ $EUID -eq 0 ]]; then
        # Check if we assume a sudo user
        if [ -n "$SUDO_USER" ]; then
            # Drop privileges to the invoking user
            sudo -u "$SUDO_USER" brew "$@"
        else
            warn "Running brew as root (SUDO_USER not set). This is not recommended."
            brew "$@"
        fi
    else
        # Not root, run normally
        brew "$@"
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
    while kill -0 "$1" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
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
    
    local status
    if [ -t 1 ]; then
        # Interactive: Run command in background, spinner in foreground
        tput civis
        "$@" > "$temp_log" 2>&1 &
        local pid=$!
        _spinner "$pid"
        wait "$pid"
        status=$?
        tput cnorm # Reset cursor
        printf "\r\033[K" # Clear line
    else
        # Non-interactive: Run synchronously
        "$@" > "$temp_log" 2>&1
        status=$?
    fi
    
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
    if execute_with_spinner "Installing $package (this may take a while)..." brew install "$package"; then
        # Log successful installation for undo/restore
        local state_dir="$HOME/.better-anonymity/state"
        mkdir -p "$state_dir"
        echo "$package" >> "$state_dir/installed_tools.log"
        return 0
    else
        return 1
    fi
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

    if execute_with_spinner "Installing $cask (this may take a while)..." brew install --cask "$cask"; then
         # Log successful installation for undo/restore
        local state_dir="$HOME/.better-anonymity/state"
        mkdir -p "$state_dir"
        echo "$cask" >> "$state_dir/installed_tools.log"
        return 0
    else
        return 1
    fi
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
    # Ensure BREW_PREFIX is set if not already
    if [ -z "$BREW_PREFIX" ]; then
        if [[ "$(uname -m)" == "arm64" ]]; then
            BREW_PREFIX="/opt/homebrew"
        else
            BREW_PREFIX="/usr/local"
        fi
    fi

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
    # Check multiple reliable DNS providers (Cloudflare, Google, Quad9)
    local targets=("1.1.1.1" "8.8.8.8" "9.9.9.9")
    
    for target in "${targets[@]}"; do
        # -c 1: send 1 packet
        # -W 1000: wait 1000ms (1s) - This is for macOS (BSD) ping where -W is ms, 
        # but commonly on Linux -W is seconds. 
        # To be safe and portable-ish without complex logic, we rely on -c 1
        # or use a simple timeout wrapper if we really wanted to be strict.
        # But 'ping -c 1' is usually sufficient.
        if ping -c 1 "$target" &> /dev/null; then
            return 0
        fi
    done
    
    warn "No internet connection detected. Network-dependent steps may fail."
    return 1
}

# Helper to manage Homebrew services quietly and idempotently.
# Usage: manage_service action service [as_root]
manage_service() {
    local action="$1"
    local service="$2"
    local as_root="$3"

    local action_pretty
    action_pretty="$(tr '[:lower:]' '[:upper:]' <<< "${action:0:1}")${action:1}"
    info "$action_pretty $service..."

    local cmd_prefix=""
    if [ "$as_root" == "true" ]; then cmd_prefix="sudo"; fi

    local output
    output=$($cmd_prefix brew services "$action" "$service" 2>&1)
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "$output" | while read -r line; do
            [ -n "$line" ] && info "$line"
        done
        return 0
    fi

    # Verify actual state to handle idempotency robustly
    local status
    status=$($cmd_prefix brew services list 2>/dev/null | grep "^$service " | awk '{print $2}')

    if [[ "$action" == "start" || "$action" == "restart" ]]; then
        if [ "$status" == "started" ]; then
            info "Service $service is actually running (ignoring $action error)."
            return 0
        fi
    elif [ "$action" == "stop" ]; then
        if [ "$status" != "started" ]; then
            info "Service $service is already stopped."
            return 0
        fi
    fi

    warn "Failed to $action $service (Exit Code: $exit_code)"
    echo "$output"
    return $exit_code
}
