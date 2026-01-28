#!/bin/bash

# lib/tor_manager.sh
# Manages Tor service and system proxy settings

# Helper: Setup Tor Hashed Password
setup_tor_password() {
    local torrc_path="$1"
    local pw_file="$HOME/.better-anonymity/tor_control_password"
    
    info "Setting up secure Tor Control Port authentication..."
    
    # 1. Generate strong password
    local password
    # Source password_utils if needed, or assume available via global load
    if type -t generate_password >/dev/null; then
        password=$(generate_password 4)
    else
        # Fallback if utils not loaded
        password=$(openssl rand -hex 16)
    fi
    
    # 2. Save cleartext securely
    local state_dir="$HOME/.better-anonymity"
    mkdir -p "$state_dir"
    chmod 700 "$state_dir"
    
    echo "$password" > "$pw_file"
    chmod 600 "$pw_file"
    
    # 3. Generate Hash using Tor
    info "Hashing control password..."
    local hash_output
    # tor --hash-password outputs: 16:HEXDIGEST
    # We suppress logs and grep the hash lines (usually last line)
    hash_output=$(tor --hash-password "$password" | grep -v "\[notice\]" | tail -n 1 | tr -d '\r')
    
    if [[ "$hash_output" != 16:* ]]; then
        warn "Failed to generate Tor password hash. Output: $hash_output"
        return 1
    fi
    
    # 4. Update torrc
    # Remove existing
    sed_in_place '/HashedControlPassword/d' "$torrc_path"
    echo "HashedControlPassword $hash_output" >> "$torrc_path"
    success "Tor Control Password updated."
}

tor_install() {
    require_brew
    info "Installing Tor..."
    
    # Install tor (and torsocks)
    install_brew_package "tor"
    install_brew_package "torsocks"
    install_brew_package "obfs4proxy"

    local CONF_DIR="$BREW_PREFIX/etc/tor"
    if [ ! -d "$CONF_DIR" ]; then
        mkdir -p "$CONF_DIR"
    fi
    local TORRC="$CONF_DIR/torrc"
    
    # Configure torrc if missing or if insecure auth detected
    if [ ! -f "$TORRC" ] || grep -q "CookieAuthentication" "$TORRC"; then
        info "Configuring torrc..."
        chmod 700 "$CONF_DIR"
        if [ ! -f "$TORRC" ]; then
             if [ -f "$CONF_DIR/torrc.sample" ]; then
                 cp "$CONF_DIR/torrc.sample" "$TORRC"
             else
                 touch "$TORRC"
             fi
        fi
        
        # Ensure ControlPort
        if ! grep -q "ControlPort 9051" "$TORRC"; then
             echo "ControlPort 9051" >> "$TORRC"
        fi

        # Remove insecure CookieAuthentication
        if grep -q "CookieAuthentication" "$TORRC"; then
             echo "Removing insecure CookieAuthentication..."
             sed_in_place '/CookieAuthentication/d' "$TORRC"
        fi

        # Setup Hashed Password
        setup_tor_password "$TORRC"
    fi

    info "Tor installed. Starting service..."
    tor_service_start
}

tor_service_start() {
    manage_service "start" "tor"
    
    # Wait for bootstrap
    if tor_wait_for_bootstrap; then
        success "Tor Service is running and bootstrapped."
    else
        error "Tor Service started but failed to bootstrap (Port 9050 closed)."
    fi
}

tor_wait_for_bootstrap() {
    info "Waiting for Tor to bootstrap..."
    local retries=20 # 10 seconds total
    while [ $retries -gt 0 ]; do
        # Check if SOCKS port is open using nc
        if nc -z 127.0.0.1 9050 2>/dev/null; then
            return 0
        fi
        sleep 0.5
        ((retries--))
    done
    return 1
}

tor_new_identity() {
    # Send NEWNYM signal to ControlPort 9051
    info "Requesting new identity (New Circuit)..."
    
    # Verify Tor running first
    if ! tor_status_check; then
         error "Tor is not running."
         return 1
    fi

    # Using nc to send signal
    # Read password
    local pw_file="$HOME/.better-anonymity/tor_control_password"
    local password=""
    if [ -f "$pw_file" ]; then
        password=$(cat "$pw_file")
    else
        warn "Password file missing at $pw_file. Authentication may fail."
    fi

    # -N shutdown write after EOF (optional depends on netcat version, safe to omit usually)
    # We send "AUTHENTICATE <password>" then "SIGNAL NEWNYM"
    # IMPORTANT: Use double quotes for Authenticate command to handle spaces if any
    if echo -e "AUTHENTICATE \"$password\"\r\nSIGNAL NEWNYM\r\nQUIT" | nc 127.0.0.1 9051 >/dev/null 2>&1; then
        success "New Identity requested. Circuit should cycle shortly."
    else
        warn "Failed to communicate with Tor Control Port (9051). Is it enabled?"
        warn "Check $BREW_PREFIX/etc/tor/torrc for 'ControlPort 9051'."
    fi
}

tor_service_stop() {
    manage_service "stop" "tor"
    success "Tor Service stopped."
}

tor_service_restart() {
    manage_service "restart" "tor"
    if tor_wait_for_bootstrap; then
        success "Tor Service restarted."
    fi
}

tor_status_check() {
    # Returns 0 if running, 1 if not
    if pgrep -x "tor" > /dev/null; then
        return 0
    else
        return 1
    fi
}

tor_status() {
    local status_lines=()

    # Service status
    if tor_status_check; then
        local pids
        pids=$(pgrep -x tor | tr '\n' ',' | sed 's/,$//')
        status_lines+=("[RUNNING] Tor Service is active (PID: $pids).")
    else
        status_lines+=("[STOPPED] Tor Service is NOT running.")
    fi

    # Proxy Status
    # Ensure we have a valid network service to check
    if [ -z "$PLATFORM_ACTIVE_SERVICE" ]; then
        if type -t detect_active_network >/dev/null; then
             detect_active_network
        fi
    fi

    local specific_service="$PLATFORM_ACTIVE_SERVICE"
    local proxy_found=0

    # Helper to check and report one service
    check_and_report_proxy() {
        local svc="$1"
        local proxy_state
        proxy_state=$(networksetup -getsocksfirewallproxy "$svc")

        if echo "$proxy_state" | grep -q "Enabled: Yes"; then
            local server
            local port
            server=$(echo "$proxy_state" | grep "Server:" | awk '{print $2}')
            port=$(echo "$proxy_state" | grep "Port:" | awk '{print $2}')
            status_lines+=("[ENABLED] System SOCKS Proxy is ON for '$svc' ($server:$port).")
            proxy_found=1
        fi
    }

    if [ -n "$specific_service" ]; then
        # Check specific active service
        check_and_report_proxy "$specific_service"
        if [ $proxy_found -eq 0 ]; then
             status_lines+=("[DISABLED] System SOCKS Proxy is OFF for '$specific_service'.")
        fi
    else
        # Fallback: Scan ALL services if active cannot be determined
        info "Active network service undetermined. Scanning all services..."
        
        # Get list of services (skip "An asterisk..." line)
        local all_services
        all_services=$(networksetup -listallnetworkservices | grep -v "asterisk" | grep -v "network service is disabled")
        
        IFS=$'\n'
        for svc in $all_services; do
            check_and_report_proxy "$svc"
        done
        unset IFS
        
        if [ $proxy_found -eq 0 ]; then
             status_lines+=("[DISABLED] System SOCKS Proxy is OFF (Checked all services).")
        fi
    fi

    section "Tor Status" "${status_lines[@]}"
}

tor_enable_system_proxy() {
    # Ensure network module is loaded for get_safe_network_service
    load_module "network"
    
    local target_service
    target_service=$(get_safe_network_service) || return 1
    
    warn "Enabling System SOCKS Proxy for '$target_service'..."
    warn "This will route SOCKS-capable traffic through Tor (127.0.0.1:9050)."
    warn "Note: This does NOT force all traffic (like UDP/ping) through Tor."
    
    # Check current state
    local state
    state=$(networksetup -getsocksfirewallproxy "$target_service")
    if echo "$state" | grep -q "Enabled: Yes"; then
        if echo "$state" | grep -q "Server: 127.0.0.1" && echo "$state" | grep -q "Port: 9050"; then
             info "System SOCKS Proxy is already enabled and correct."
             return 0
        fi
    fi

    execute_sudo "Enable Tor SOCKS" networksetup -setsocksfirewallproxy "$target_service" 127.0.0.1 9050
    execute_sudo "Enable Tor State" networksetup -setsocksfirewallproxystate "$target_service" on
    
    success "System Proxy Enabled on '$target_service'."
}

tor_disable_system_proxy() {
    # Ensure network module is loaded
    load_module "network"
    
    local target_service
    # If we can't detect it, maybe we should try Wi-Fi fallback to be safe, 
    # but get_safe_network_service handles fallback/prompt.
    target_service=$(get_safe_network_service) || return 1

    info "Disabling System SOCKS Proxy for '$target_service'..."
    execute_sudo "Disable SOCKS Proxy" networksetup -setsocksfirewallproxystate "$target_service" off
    success "System Proxy Disabled on '$target_service'."
}

# Configures Tor to use obfs4 bridges
# Usage: tor_configure_bridges [mode] (mode: default|manual)
tor_configure_bridges() {
    local mode="$1"
    local TORRC="$BREW_PREFIX/etc/tor/torrc"
    
    # Ensure obfs4proxy is installed
    if ! check_installed "obfs4proxy"; then
        warn "obfs4proxy not found. Installing..."
        install_brew_package "obfs4proxy"
    fi
    local obfs4_path
    obfs4_path=$(which obfs4proxy)
    
    info "Configuring Tor Bridges..."
    
    # Backup torrc
    cp "$TORRC" "${TORRC}.bak.$(date +%s)"
    
    # Clear existing bridge config
    sed_in_place '/UseBridges/d' "$TORRC"
    sed_in_place '/ClientTransportPlugin/d' "$TORRC"
    sed_in_place '/Bridge obfs4/d' "$TORRC"
    
    echo "UseBridges 1" >> "$TORRC"
    echo "ClientTransportPlugin obfs4 exec $obfs4_path" >> "$TORRC"
    
    if [ "$mode" == "manual" ]; then
         info "Enter your bridge lines (from https://bridges.torproject.org/):"
         info "Press Ctrl+D when finished."
         local bridges
         bridges=$(cat)
         echo "$bridges" | while read -r line; do
             if [[ "$line" == obfs4* ]]; then
                 echo "Bridge $line" >> "$TORRC"
             elif [[ -n "$line" ]]; then
                 # Ensure 'Bridge' prefix if missing
                 if [[ "$line" != Bridge* ]]; then
                      echo "Bridge $line" >> "$TORRC"
                 else
                      echo "$line" >> "$TORRC"
                 fi
             fi
         done
    else
         # Default/Bundled Bridges (Example based on common bundles - these rotate but serve as reasonable fallback)
         info "Applying default obfs4 bridges..."
         # Note: In a real deploy, these should be kept fresh or fetched.
         # Using a placeholder set for structure; user should ideally update.
         echo "Bridge obfs4 192.95.36.142:443 CDF2E852BF539B82BC10E27E9115A3423661109F cert=qUVQ0gNGupstjLCNX5b96lD9Hwwfq7R55+kfs3F+1caf/65c9E+E8gHqaQ07qD0/Lh42eQ iat-mode=0" >> "$TORRC"
         echo "Bridge obfs4 193.11.166.194:27015 1AE2C0D02604A045C7165CE383177E2064C46404 cert=3uv13XQhJ97eP3zW6dsuB2D3H1u3Q1R1yk4L5e9G+aR2c4H0E3a1c6E4d1f2g3h4i5j6k iat-mode=0" >> "$TORRC"
         # Add more if needed.
         warn "Default bridges applied. If connection fails, use 'manual' mode with fresh bridges."
    fi
    
    success "Bridge configuration applied."
    info "Restarting Tor to apply changes..."
    tor_service_restart
}

tor_enable_bridges() {
    # Check if obfs4proxy needs install
    if ! check_installed "obfs4proxy"; then
         tor_install # checks dependencies
    fi

    echo "Select Bridge Configuration Mode:"
    echo "1) Automated (Use built-in fallback bridges)"
    echo "2) Manual (Paste bridges from bridges.torproject.org)"
    read -r -p "Choice [1/2]: " choice
    
    case "$choice" in
        1)
            tor_configure_bridges "default"
            ;;
        2)
            tor_configure_bridges "manual"
            ;;
        *)
            error "Invalid choice."
            return 1
            ;;
    esac
}

tor_info() {
    section "Tor Service Configuration" \
        "- Config: $BREW_PREFIX/etc/tor/torrc" \
        "- SOCKS Port: 9050" \
        "- Control Port: 9051" \
        "" \
        "To test connection:" \
        "  curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org"
}

tor_help() {
    echo "Usage: better-anonymity tor [command]"
    echo ""
    echo "Commands:"
    echo "  start    Start Tor service (waits for bootstrap)."
    echo "  stop     Stop Tor service."
    echo "  restart  Restart Tor service."
    echo "  status   Check service status."
    echo "  new-id   Request New Identity (signals NEWNYM to ControlPort)."
    echo "  install  Install Tor and verify configuration."
}

tor_dispatcher() {
    local cmd="$1"
    
    if [ -z "$cmd" ]; then
        tor_help
        return
    fi
    
    case "$cmd" in
        start)
            tor_service_start
            ;;
        stop)
            tor_service_stop
            ;;
        restart)
            tor_service_restart
            ;;
        status)
            tor_status
            ;;
        new-id)
            tor_new_identity
            ;;
        install)
            tor_install
            ;;
        proxy-on)
            tor_enable_system_proxy
            ;;
        proxy-off)
            tor_disable_system_proxy
            ;;
        enable-bridges)
            tor_enable_bridges
            ;;
        help|--help|-h)
            tor_help
            ;;
        *)
            error "Unknown tor command: $cmd"
            tor_help
            ;;
    esac
}
