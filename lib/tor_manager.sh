#!/bin/bash

# lib/tor_manager.sh
# Manages Tor service and system proxy settings

tor_install() {
    require_brew
    info "Installing Tor..."
    
    # Install tor (and torsocks)
    install_brew_package "tor"
    install_brew_package "torsocks"

    local CONF_DIR="$BREW_PREFIX/etc/tor"
    if [ ! -d "$CONF_DIR" ]; then
        mkdir -p "$CONF_DIR"
    fi
    local TORRC="$CONF_DIR/torrc"
    
    # Configure torrc if missing
    if [ ! -f "$TORRC" ]; then
        info "Configuring default torrc..."
        chmod 700 "$CONF_DIR"
        if [ -f "$CONF_DIR/torrc.sample" ]; then
            cp "$CONF_DIR/torrc.sample" "$TORRC"
        else
            touch "$TORRC"
        fi
        # Default SOCKS port is 9050, usually enabled by default or commented out.
        # We ensure Control Port is enabled for advanced usage (check.torproject.org etc)
        if ! grep -q "ControlPort 9051" "$TORRC"; then
             echo "ControlPort 9051" >> "$TORRC"
        fi
        # Disable Cookie Auth to allow local nc control easier
        if ! grep -q "CookieAuthentication 0" "$TORRC"; then
             # Remove existing line if 1
             sed -i '' '/CookieAuthentication/d' "$TORRC"
             echo "CookieAuthentication 0" >> "$TORRC"
        fi
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
    # -N shutdown write after EOF (optional depends on netcat version, safe to omit usually)
    # We send "AUTHENTICATE" (empty password) then "SIGNAL NEWNYM"
    if echo -e 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT' | nc 127.0.0.1 9051 >/dev/null 2>&1; then
        success "New Identity requested. Circuit should cycle shortly."
    else
        warn "Failed to communicate with Tor Control Port (9051). Is it enabled?"
        warn "Check $BREW_PREFIX/etc/tor/torrc for 'ControlPort 9051' and 'CookieAuthentication 0'."
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

    local target_service="$PLATFORM_ACTIVE_SERVICE"
    
    if [ -z "$target_service" ]; then
        # Last resort fallback with warning
        target_service="${PLATFORM_WIFI_SERVICE:-Wi-Fi}"
        warn "Could not detect active network service. Defaulting to '$target_service' for proxy status."
    fi

    local proxy_state
    proxy_state=$(networksetup -getsocksfirewallproxy "$target_service")

    if echo "$proxy_state" | grep -q "Enabled: Yes"; then
        local server
        local port
        server=$(echo "$proxy_state" | grep "Server:" | awk '{print $2}')
        port=$(echo "$proxy_state" | grep "Port:" | awk '{print $2}')
        status_lines+=("[ENABLED] System SOCKS Proxy is ON for '$target_service' ($server:$port).")
    else
        status_lines+=("[DISABLED] System SOCKS Proxy is OFF for '$target_service'.")
    fi

    section "Tor Status" "${status_lines[@]}"
}

tor_enable_system_proxy() {
    warn "Enabling System SOCKS Proxy for '${PLATFORM_WIFI_SERVICE:-Wi-Fi}'..."
    warn "This will route SOCKS-capable traffic through Tor (127.0.0.1:9050)."
    warn "Note: This does NOT force all traffic (like UDP/ping) through Tor."
    
    # Check current state
    local state
    state=$(networksetup -getsocksfirewallproxy "${PLATFORM_WIFI_SERVICE:-Wi-Fi}")
    if echo "$state" | grep -q "Enabled: Yes"; then
        if echo "$state" | grep -q "Server: 127.0.0.1" && echo "$state" | grep -q "Port: 9050"; then
             info "System SOCKS Proxy is already enabled and correct."
             return 0
        fi
    fi

    execute_sudo "Enable Tor SOCKS" networksetup -setsocksfirewallproxy "${PLATFORM_WIFI_SERVICE:-Wi-Fi}" 127.0.0.1 9050
    execute_sudo "Enable Tor State" networksetup -setsocksfirewallproxystate "${PLATFORM_WIFI_SERVICE:-Wi-Fi}" on
    
    success "System Proxy Enabled."
}

tor_disable_system_proxy() {
    info "Disabling System SOCKS Proxy for '${PLATFORM_WIFI_SERVICE:-Wi-Fi}'..."
    execute_sudo "Disable SOCKS Proxy" networksetup -setsocksfirewallproxystate "${PLATFORM_WIFI_SERVICE:-Wi-Fi}" off
    success "System Proxy Disabled."
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
        help|--help|-h)
            tor_help
            ;;
        *)
            error "Unknown tor command: $cmd"
            tor_help
            ;;
    esac
}
