#!/bin/bash

# lib/platform.sh
# Architecture and OS detection

detect_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        arm64)
            export PLATFORM_ARCH="arm64"
            export BREW_PREFIX="/opt/homebrew"
            info "Detected Apple Silicon (ARM64). Using Homebrew prefix: $BREW_PREFIX"
            ;;
        x86_64|x86_64h)
            export PLATFORM_ARCH="x86_64"
            export BREW_PREFIX="/usr/local"
            info "Detected Intel ($ARCH). Using Homebrew prefix: $BREW_PREFIX"
            ;;
        i386)
            export PLATFORM_ARCH="i386"
            export BREW_PREFIX="/usr/local"
            warn "Detected i386. Homebrew support may be limited."
            ;;
        *)
            export PLATFORM_ARCH="$ARCH"
            # Fallback to usr/local for unknowns common on macOS
            export BREW_PREFIX="/usr/local"
            warn "Unknown architecture: $ARCH. Defaulting to /usr/local"
            ;;
    esac
}

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        die "This script is designed for macOS only."
    fi
}

detect_model() {
    # sysctl hw.model returns strings like "MacBookPro18,3", "Macmini9,1", etc.
    local model_id=$(sysctl -n hw.model | tr -d '[:space:]')
    export PLATFORM_MODEL="$model_id"
    
    # Generic "Mac" identifiers (M2/M3+) confuse the name-based check.
    # Reliable fallback: Check for battery.
    has_battery() {
        ioreg -c AppleSmartBattery -r | grep -q "BatteryInstalled"
    }

    if [[ "$model_id" == *"MacBook"* ]]; then
        export PLATFORM_TYPE="Laptop"
        info "Detected Model: $model_id (Laptop)"
    elif [[ "$model_id" == *"Macmini"* ]] || [[ "$model_id" == *"iMac"* ]] || [[ "$model_id" == *"MacPro"* ]] || [[ "$model_id" == *"Mac1"* ]]; then
        # 'Mac1,x' or generic 'Mac' identifiers could be anything.
        # Check battery to disambiguate.
        if has_battery; then
            export PLATFORM_TYPE="Laptop"
            info "Detected Model: $model_id (Laptop - Battery Detected)"
        else
            export PLATFORM_TYPE="Desktop"
            info "Detected Model: $model_id (Desktop)"
        fi
    elif [[ "$model_id" == *"Virtual"* ]] || [[ "$model_id" == *"VMware"* ]] || [[ "$model_id" == *"Parallels"* ]]; then
        export PLATFORM_TYPE="Virtual"
        info "Detected Model: $model_id (Virtual Machine)"
    else
        # Fallback for completely unknown strings
        if has_battery; then
             export PLATFORM_TYPE="Laptop"
             info "Detected Model: $model_id (Laptop - Fallback)"
        else
             export PLATFORM_TYPE="Unknown"
             warn "Could not determine platform type from model: $model_id"
        fi
    fi
}

detect_os_version() {
    # Get macOS version (e.g., 10.15.7, 13.0, 14.2.1)
    local ver=$(sw_vers -productVersion | tr -d '[:space:]')
    export PLATFORM_OS_VER="$ver"
    # Extract major version
    export PLATFORM_OS_VER_MAJOR=$(echo "$ver" | cut -d. -f1)
    info "Detected macOS Version: $ver (Major: $PLATFORM_OS_VER_MAJOR)"
}
