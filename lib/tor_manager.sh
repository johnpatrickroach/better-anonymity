#!/bin/bash

# lib/tor_manager.sh
# Manages Tor service and system proxy settings

tor_install() {
    require_brew
    info "Installing Tor..."
    
    # Install tor and torsocks
    brew install tor torsocks

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

    info "Tor installed. Use 'start' to run the service."
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
        info "[RUNNING] Tor Service is active (PID: $(pgrep -x tor))."
    else
        warn "[STOPPED] Tor Service is NOT running."
    fi
    
    # Check Proxy Status
    local proxy_state
    # Check Wi-Fi interface
    proxy_state=$(networksetup -getsocksfirewallproxy Wi-Fi)
    if echo "$proxy_state" | grep -q "Enabled: Yes"; then
        info "[ENABLED] System SOCKS Proxy is ON (127.0.0.1:9050)."
    else
        info "[DISABLED] System SOCKS Proxy is OFF."
    fi
}

tor_enable_system_proxy() {
    warn "Enabling System SOCKS Proxy for 'Wi-Fi'..."
    warn "This will route SOCKS-capable traffic through Tor (127.0.0.1:9050)."
    warn "Note: This does NOT force all traffic (like UDP/ping) through Tor."
    
    execute_sudo "Set SOCKS Proxy" networksetup -setsocksfirewallproxy Wi-Fi 127.0.0.1 9050
    execute_sudo "Enable SOCKS Proxy" networksetup -setsocksfirewallproxystate Wi-Fi on
    
    success "System Proxy Enabled."
}

tor_disable_system_proxy() {
    info "Disabling System SOCKS Proxy for 'Wi-Fi'..."
    execute_sudo "Disable SOCKS Proxy" networksetup -setsocksfirewallproxystate Wi-Fi off
    success "System Proxy Disabled."
}

tor_info() {
    echo "Tor Service Configuration:"
    echo "- Config: $BREW_PREFIX/etc/tor/torrc"
    echo "- SOCKS Port: 9050"
    echo "- Control Port: 9051"
    echo ""
    echo "To test connection:"
    echo "  curl --socks5 127.0.0.1:9050 https://check.torproject.org"
}
