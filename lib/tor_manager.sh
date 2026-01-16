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
        if ! grep -q "CookieAuthentication 1" "$TORRC"; then
             echo "CookieAuthentication 1" >> "$TORRC"
        fi
    fi

    info "Tor installed. Starting service..."
    tor_service_start
}

tor_service_start() {
    info "Starting Tor Service..."
    brew services start tor
    
    # Wait a moment for boot
    sleep 2
    if tor_status_check; then
        success "Tor Service is running."
    else
        error "Tor Service failed to start."
    fi
}

tor_service_stop() {
    info "Stopping Tor Service..."
    brew services stop tor
    success "Tor Service stopped."
}

tor_service_restart() {
    info "Restarting Tor Service..."
    brew services restart tor
    sleep 2
    tor_status_check
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
    info "Checking Tor Status..."
    if tor_status_check; then
        local pids
        # Capture all PIDs, replace newlines with commas, remove trailing comma
        pids=$(pgrep -x tor | tr '\n' ',' | sed 's/,$//')
        info "[RUNNING] Tor Service is active (PID: $pids)."
    else
        warn "[STOPPED] Tor Service is NOT running."
    fi
    
    # Check Proxy Status
    # Check Proxy Status
    local target_service="${PLATFORM_ACTIVE_NETWORK_SERVICE:-${PLATFORM_WIFI_SERVICE:-Wi-Fi}}"
    local proxy_state
    
    proxy_state=$(networksetup -getsocksfirewallproxy "$target_service")
    
    if echo "$proxy_state" | grep -q "Enabled: Yes"; then
        local server
        local port
        server=$(echo "$proxy_state" | grep "Server:" | awk '{print $2}')
        port=$(echo "$proxy_state" | grep "Port:" | awk '{print $2}')
        info "[ENABLED] System SOCKS Proxy is ON for '$target_service' ($server:$port)."
    else
        info "[DISABLED] System SOCKS Proxy is OFF for '$target_service'."
    fi
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
