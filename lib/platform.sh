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

# Helper: Check for battery presence (indicates laptop)
has_battery() {
    # Check for InternalBattery explicitly to avoid UPS false positives
    pmset -g batt | grep -q "InternalBattery"
}

detect_model() {
    # sysctl hw.model returns strings like "MacBookPro18,3", "Macmini9,1", etc.
    local model_id=$(sysctl -n hw.model | tr -d '[:space:]')
    export PLATFORM_MODEL="$model_id"
    
    # Generic "Mac" identifiers (M2/M3+) confuse the name-based check.
    # Reliable fallback: Check for battery.

    if [[ "$model_id" == *"MacBook"* ]]; then
        export PLATFORM_TYPE="Laptop"
        info "Detected Model: $model_id (Laptop)"
    elif [[ "$model_id" == *"Macmini"* ]] || [[ "$model_id" == *"iMac"* ]] || [[ "$model_id" == *"MacPro"* ]] || [[ "$model_id" == *"Mac1"* ]]; then
        # 'Mac1,x' (common on M1/M2/M3 chips) or generic 'Mac' identifiers are ambiguous.
        # They don't encode form factor (Laptop vs Desktop) like legacy 'MacBookPro' strings.
        # We must check for a battery to definitively classify them as Laptops.
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

# Hardware Detection Helpers

get_wifi_device() {
    # Returns the device ID (e.g., en0) for the Wi-Fi interface.
    if [ -n "$PLATFORM_WIFI_DEVICE" ]; then echo "$PLATFORM_WIFI_DEVICE"; return; fi

    local dev
    # Added WLAN/AirPort for localization support
    dev=$(networksetup -listallhardwareports | grep -A 1 -E "Hardware Port: (Wi-Fi|AirPort|WLAN)" | grep "Device:" | awk '{print $2}')
    
    if [ -z "$dev" ]; then
        # Check common wireless interface en0 explicitly
        if networksetup -getairportpower en0 >/dev/null 2>&1; then
            warn "Could not detect Wi-Fi device from hardware ports. Defaulting to en0 (heuristic - validated)."
            dev="en0"
        else
            warn "Could not detect valid Wi-Fi device."
            dev=""
        fi 
    fi
    echo "$dev"
}

get_wifi_service() {
    if [ -n "$PLATFORM_WIFI_SERVICE" ]; then echo "$PLATFORM_WIFI_SERVICE"; return; fi
    # Returns the Service Name (e.g., "Wi-Fi") associated with the Wi-Fi device.
    local dev
    dev=$(get_wifi_device)
    
    local sname
    # Map Device -> Service Name using networkserviceorder
    sname=$(networksetup -listnetworkserviceorder | grep -B 1 "Device: $dev)" | head -n 1 | sed -E 's/^\([0-9]+\) //')
    
    if [ -z "$sname" ]; then
        # Check common names
        if networksetup -listallnetworkservices | grep -q "^Wi-Fi$"; then
            sname="Wi-Fi"
        elif networksetup -listallnetworkservices | grep -q "^WLAN$"; then
            sname="WLAN"
        else
            warn "Could not determine Wi-Fi service name."
            sname=""
        fi
    fi
    echo "$sname"
}

detect_wifi_network() {
    export PLATFORM_WIFI_DEVICE=$(get_wifi_device)
    export PLATFORM_WIFI_SERVICE=$(get_wifi_service)
}

detect_active_network() {
    # 1. Find active interface via default route
    local active_dev
    active_dev=$(route get default 2>/dev/null | grep interface: | awk '{print $2}')
    
    if [ -z "$active_dev" ]; then
        warn "No default route found (offline?). Scanning for first active service..."
        
        # Parse service order: (1) Service Name (2) Device
        # networksetup -listnetworkserviceorder returns:
        # (1) Wi-Fi
        # (Hardware Port: Wi-Fi, Device: en0)
        
        # We try to extract devices in order.
        local services
        services=$(networksetup -listnetworkserviceorder | grep "Device:" | sed -E 's/.*Device: ([a-z0-9]+).*/\1/')
        
        for dev in $services; do
             # Check if interface is active
             if ifconfig "$dev" 2>/dev/null | grep -q "status: active"; then
                 active_dev="$dev"
                 info "Found active fallback device: $active_dev"
                 break
             fi
        done
        
        if [ -z "$active_dev" ]; then
             warn "No active network interface found."
             PLATFORM_ACTIVE_DEVICE=""
             PLATFORM_ACTIVE_SERVICE=""
             return
        fi
    fi
    
    export PLATFORM_ACTIVE_DEVICE="$active_dev"
    
    # 2. Map Device -> Service Name
    local sname
    sname=$(networksetup -listnetworkserviceorder | grep -B 1 "Device: $active_dev)" | head -n 1 | sed -E 's/^\([0-9]+\) //')
    
    if [ -z "$sname" ]; then
        warn "Could not map device $active_dev to Service Name. Trying fallback..."
        # If active device is en0/en1, it might be Wi-Fi without service name match?
        if [ "$active_dev" == "$(get_wifi_device)" ]; then
             sname=$(get_wifi_service)
        else
             # Assume "Ethernet" or use device name as fallback?
             # Networksetup commands usually NEED the Service Name, not device.
             # If we can't find it, we might be in trouble for changing settings.
     warn "Could not verify service name for $active_dev. Network configuration features will be skipped."
             sname=""
        fi
    fi
    export PLATFORM_ACTIVE_SERVICE="$sname"
    info "Active Network: $PLATFORM_ACTIVE_SERVICE ($PLATFORM_ACTIVE_DEVICE)"
}
