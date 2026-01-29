#!/usr/bin/env bash

# lib/wifi.sh
# Functions for Wi-Fi security auditing and MAC address randomization.

# Path to the airport utility
# Path to the airport utility (legacy or modern)
# Path to the airport utility (legacy or modern)
AIRPORT_BIN="${AIRPORT_BIN:-$(get_airport_bin)}"

# wifi_get_interface
# Returns the name of the primary Wi-Fi interface (e.g., en0).
wifi_get_interface() {
    # Delegate to platform helper for consistency
    if command -v get_wifi_device >/dev/null 2>&1; then
        get_wifi_device
    else
        # Fallback in case platform.sh wasn't loaded for some reason
        networksetup -listallhardwareports | awk '/Wi-Fi|AirPort|WLAN/{getline; print $2}'
    fi
}

# wifi_generate_mac
# Generates a random MAC address with the locally administered bit set (bit 1)
# and the unicast bit cleared (bit 0).
# This results in the second hex digit being 2, 6, A, or E.
wifi_generate_mac() {
    # Generate 6 random bytes via openssl
    local hex
    hex=$(openssl rand -hex 6)
    
    # Extract the first byte
    local first_byte="${hex:0:2}"
    
    # Convert hex to decimal to perform bitwise operations
    local val=$((16#$first_byte))
    
    # Set bit 1 (locally administered) -> | 0x02
    # Clear bit 0 (unicast) -> & 0xFE
    val=$(( (val | 2) & 254 ))
    
    # Convert back to hex, ensure 2 digits
    local new_first_byte
    new_first_byte=$(printf "%02x" "$val")
    
    # Reconstruct the string with colons
    # We use the new first byte, then the remaining 5 bytes from original
    local suffix="${hex:2}"
    local full_hex="${new_first_byte}${suffix}"
    
    # Format with colons
    echo "$full_hex" | sed 's/\(..\)/:\1/g' | sed 's/^://' 
}

# wifi_spoof_mac
# Disassociates from the current network and changes the MAC address.
# Usage: wifi_spoof_mac <new_mac_address>
wifi_spoof_mac() {
    local new_mac="$1"

    # If no MAC provided, generate a random one
    if [ -z "$new_mac" ]; then
        info "No MAC address provided. Generating a random secure MAC..."
        new_mac=$(wifi_generate_mac)
    fi


    local iface
    iface=$(wifi_get_interface)

    if [ -z "$iface" ]; then
        error "No Wi-Fi interface found."
        return 1
    fi

    info "Disassociating from airport..."
    if [ -x "$AIRPORT_BIN" ]; then
        execute_sudo "Disassociating from current network..." "$AIRPORT_BIN" -z
    else
        warn "airport utility not found at $AIRPORT_BIN. Spoofing might fail if connected."
    fi

    info "Setting new MAC address to $new_mac..."
    if execute_sudo "Changing MAC address..." ifconfig "$iface" ether "$new_mac"; then
        success "MAC address changed successfully."
        # Verify
        local verify_mac
        verify_mac=$(ifconfig "$iface" | awk '/ether/{print $2}')
        if [ "$verify_mac" == "$new_mac" ]; then
            success "Verified active MAC is now $new_mac"
        else
            error "Verification failed. Active MAC is $verify_mac"
        fi
        
        # Note: changing MAC often turns off Wi-Fi power or similar on some OS versions? 
        # Usually it just disconnects.
        info "You may need to manually reconnect to your Wi-Fi network."
    else
        error "Failed to change MAC address."
        return 1
    fi
}

# wifi_audit
# Checks the security of the current Wi-Fi connection.
wifi_audit() {
    if [ ! -x "$AIRPORT_BIN" ]; then
        error "airport utility not found. Cannot perform audit."
        return 1
    fi

    info "Auditing current Wi-Fi connection..."
    
    local iface
    iface=$(wifi_get_interface)
    
    # 1. Check Power Status forcefully via networksetup (Robust)
    if [ -n "$iface" ]; then
        local power_status
        power_status=$(networksetup -getairportpower "$iface" 2>/dev/null)
        if [[ "$power_status" == *": Off"* ]]; then
             warn "Wi-Fi interface ($iface) is powered OFF."
             return 0
        fi
    fi

    local info_out
    info_out=$("$AIRPORT_BIN" -I)
    
    # 2. Check association (SSID)
    local ssid
    ssid=$(echo "$info_out" | awk -F': ' '/ SSID/ {print $2}')
    
    if [ -z "$ssid" ]; then
        warn "Not connected to any Wi-Fi network."
        return 0
    fi

    info "Connected to: $ssid"
    
    local auth
    auth=$(echo "$info_out" | awk -F': ' '/link auth/ {print $2}')
    info "Security Type: $auth"

    if [[ "$auth" == *"wpa2"* ]] || [[ "$auth" == *"wpa3"* ]]; then
        success "Encryption ($auth) appears modern."
    elif [[ "$auth" == "none" ]]; then
        error "Network is OPEN (Unsecured)! Traffic is visible to everyone nearby."
    elif [[ "$auth" == *"wep"* ]]; then
        error "Network uses WEP (Insecure)! Easily cracked."
    else
        warn "Unknown or weak security type: $auth"
    fi

    # Check for hidden network?
    # Actually airport -I doesn't strictly tell us if it's hidden easily without scanning. 
    # But we can warn the user generally.
}
