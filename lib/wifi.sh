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
    local candidates
    # Delegate to platform helper if available, otherwise use direct networksetup
    if command -v get_wifi_device >/dev/null 2>&1; then
        candidates=$(get_wifi_device)
    else
        candidates=$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort|WLAN/{getline; print $2}')
    fi
    
    # Iterate to find the connected one (active association)
    for dev in $candidates; do
         if networksetup -getairportnetwork "$dev" 2>/dev/null | grep -q "Current Wi-Fi Network"; then
             echo "$dev"
             return 0
         fi
    done

    # If none are connected, return the first one found (default)
    for dev in $candidates; do
        echo "$dev"
        return 0
    done
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
    
    info "Target Interface: $iface"
    
    local current_mac
    current_mac=$(ifconfig "$iface" | awk '/ether/{print $2}')
    # Privacy: Do not log current MAC
    
    info "Setting new MAC address..."
    
    # Method 1: Disassociate via airport (Fast, keeps radio on)
    if [ -x "$AIRPORT_BIN" ]; then
        info "Disassociating from airport..."
        execute_sudo "Disassociating from current network..." "$AIRPORT_BIN" -z
        
        if execute_sudo "Changing MAC address..." ifconfig "$iface" ether "$new_mac"; then
             success "MAC address changed (via airport disassociate)."
        else
             error "Failed to change MAC address."
             return 1
        fi
        
    else
        # Method 3: Power Cycle Race
        # On Apple Silicon / newer macOS, we can't change MAC if DOWN, and can't if ASSOCIATED.
        # We need "UP but NOT ASSOCIATED".
        # We achieve this by cycling power and racing against the auto-connect.
        warn "airport utility not found. Using Power Cycle Race method."
        
        # Pre-authorize sudo so we don't get prompted during the critical race window
        execute_sudo "Pre-authorizing sudo for race condition..." -v
        
        info "Cycling Wi-Fi Power..."
        networksetup -setairportpower "$iface" off
        sleep 1
        networksetup -setairportpower "$iface" on
        
        # No sleep here! We must catch it before it associates.
        info "Changing MAC address (Race condition)..."
        
        if execute_sudo "Change MAC" ifconfig "$iface" ether "$new_mac"; then
             success "MAC address updated."
        else
             error "Failed to change MAC address."
             error "Your network card may block MAC spoofing completely."
             return 1
        fi
    fi
    
    # Verify (Wait a moment for interface to come up if cycled)
    sleep 1 
    local verify_mac
    verify_mac=$(ifconfig "$iface" | awk '/ether/{print $2}')
    
    if [ "$verify_mac" == "$new_mac" ]; then
        if [ "$verify_mac" != "$current_mac" ]; then
             success "Verified: MAC address successfully changed."
        else
             warn "Target MAC applied but matches original MAC."
        fi
        
        info "You may need to manually reconnect to your Wi-Fi network."
    else
        error "Verification failed. MAC address check mismatch."
        return 1
    fi
}

# wifi_audit
# Checks the security of the current Wi-Fi connection.
wifi_audit() {
    local iface
    iface=$(wifi_get_interface)
    
    info "Auditing current Wi-Fi connection (Interface: ${iface:-Unknown})..."
    
    # 1. Check Power Status forcefully via networksetup (Robust)
    if [ -n "$iface" ]; then
        local power_status
        power_status=$(networksetup -getairportpower "$iface" 2>/dev/null)
        if [[ "$power_status" == *": Off"* ]]; then
             error "Wi-Fi Status: OFF (Interface: $iface)"
             return 0
        fi
    fi

    # 2. Detailed Audit (Try 'airport' utility first)
    if [ -x "$AIRPORT_BIN" ]; then
        local info_out
        info_out=$("$AIRPORT_BIN" -I)
        
        # Check association (SSID)
        local ssid
        ssid=$(echo "$info_out" | awk -F': ' '/ SSID/ {print $2}')
        
        if [ -z "$ssid" ]; then
            error "Wi-Fi Status: DISCONNECTED (No SSID found)"
            return 0
        fi

        success "Wi-Fi Status: CONNECTED (SSID: $ssid)"
        
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
    else
        # Fallback: Use networksetup
        warn "airport utility not found. Using basic audit (SSID only)."
        
        local net_out
        net_out=$(networksetup -getairportnetwork "$iface" 2>/dev/null)
        # Output format: "Current Wi-Fi Network: MySSID" or "You are not associated..."
        
        local ssid=""
        if [[ "$net_out" == *"You are not associated"* ]] || [[ -z "$net_out" ]]; then
             # Deep Fallback: system_profiler (Slow but reliable)
             info "networksetup reports not associated. Trying system_profiler..."
             local prof_out
             prof_out=$(system_profiler SPAirPortDataType 2>/dev/null)
             
             # Parse 'Current Network Information: \n SSID:'
             # We grab the first block's second line (the SSID)
             ssid=$(echo "$prof_out" | grep -A 1 "Current Network Information:" | head -n 2 | tail -n 1 | sed 's/://g' | xargs)
             
             if [ -z "$ssid" ]; then
                 error "Wi-Fi Status: DISCONNECTED (Confirmed via system_profiler)"
                 return 0
             fi
        else
             ssid=$(echo "$net_out" | sed 's/^Current Wi-Fi Network: //')
        fi
        
        if [ -n "$ssid" ]; then
            success "Wi-Fi Status: CONNECTED (SSID: $ssid)"
            warn "Detailed encryption info unavailable."
        else
             error "Wi-Fi Status: UNKNOWN (Could not determine SSID)"
        fi
    fi
}
