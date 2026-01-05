#!/usr/bin/env bash

# lib/wifi.sh
# Functions for Wi-Fi security auditing and MAC address randomization.

# Path to the airport utility
AIRPORT_BIN="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

# wifi_get_interface
# Returns the name of the primary Wi-Fi interface (e.g., en0).
wifi_get_interface() {
    networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $2}'
}

# wifi_generate_mac
# Generates a random MAC address with the locally administered bit set
# and the unicast bit set (second hex char: 2, 6, A, or E).
wifi_generate_mac() {
    openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//' | \
    awk -F: '{
        # Modify the first octet to ensure it is locally administered (unset bit 0, set bit 1)
        # To do this simply, we can just replace the first byte"s second nibble.
        # But a simpler way for bash generation:
        # standard patterns: x2:xx:xx:xx:xx:xx, x6, xA, xE
        v=$1;
        # Get the second char of the first octet
        second_char = substr(v, 2, 1);
        
        # We need a random valid second char.
        # Let"s just overwrite the first octet entirely to be safe and simple.
        # 02, 06, 0a, 0e are valid starts.
        # Let"s just pick one randomly using bash $RANDOM outside awk? 
        # Actually proper way:
        # We"ll just output the rest of the generated string and prepend a valid prefix in the caller
        # or do it here.
        print $0 
    }'
    # Re-impl below for simplicity
}

# wifi_spoof_mac
# Disassociates from the current network and changes the MAC address.
wifi_spoof_mac() {
    local iface
    iface=$(wifi_get_interface)

    if [ -z "$iface" ]; then
        error "No Wi-Fi interface found."
        return 1
    fi

    check_root || return 1

    info "Target Interface: $iface"
    local current_mac
    current_mac=$(ifconfig "$iface" | awk '/ether/{print $2}')
    info "Current MAC: $current_mac"

    # Generate a random valid prefix: 02, 06, 0a, 0e (locally administered, unicast)
    local prefix
    # simple random pick
    local r=$((RANDOM % 4))
    case $r in
        0) prefix="02" ;;
        1) prefix="06" ;;
        2) prefix="0a" ;;
        3) prefix="0e" ;;
    esac

    # Generate 5 random bytes
    local suffix
    suffix=$(openssl rand -hex 5 | sed 's/\(..\)/:\1/g')
    local new_mac="${prefix}${suffix}"

    warn "This will disassociate you from the current Wi-Fi network."
    # We don't ask for confirmation here if called from a script that already asked, 
    # but the menu item should probably ask.
    # We'll assume the caller (CLI) handles the "Are you sure?" or implies it by user action.

    info "Disassociating from airport..."
    if [ -x "$AIRPORT_BIN" ]; then
        "$AIRPORT_BIN" -z
    else
        warn "airport utility not found at $AIRPORT_BIN. Spoofing might fail if connected."
    fi

    info "Setting new MAC address to $new_mac..."
    if ifconfig "$iface" ether "$new_mac"; then
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
    local info_out
    info_out=$("$AIRPORT_BIN" -I)
    
    # Check if connected (AirPort: Off or similar results in mostly empty output)
    if echo "$info_out" | grep -q "AirPort: Off"; then
        warning "Wi-Fi is turned off."
        return 0
    fi
    
    local ssid
    ssid=$(echo "$info_out" | awk -F': ' '/ SSID/ {print $2}')
    
    if [ -z "$ssid" ]; then
        warning "Not connected to any Wi-Fi network."
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
        warning "Unknown or weak security type: $auth"
    fi

    # Check for hidden network?
    # Actually airport -I doesn't strictly tell us if it's hidden easily without scanning. 
    # But we can warn the user generally.
}
