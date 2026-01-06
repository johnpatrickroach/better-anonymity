#!/bin/bash

# lib/lifecycle.sh
# Lifecycle management: setup, daily checks, updates

lifecycle_setup() {
    clear
    header "Better Anonymity - First Time Setup"
    echo "Welcome! This wizard will guide you through the recommended security baseline."
    echo "You can skip any step you prefer not to apply."
    echo ""

    # 1. macOS Hardening
    if ask_confirmation "Step 1: Apply Basic macOS Hardening (Firewall, Sudoers, Umask)?"; then
        hardening_enable_firewall
        hardening_secure_sudoers
        hardening_set_umask
        hardening_disable_bonjour
        hardening_disable_analytics
        success "Basic hardening applied."
    fi

    # 2. DNS
    echo ""
    if ask_confirmation "Step 2: Configure Encrypted DNS (Quad9)?"; then
        network_set_dns "quad9"
    fi

    # 3. Hosts Blocklist
    echo ""
    if ask_confirmation "Step 3: Install StevenBlack Hosts Blocklist (Ad-blocking)?"; then
        network_update_hosts
    fi

    # 4. Essential Tools
    echo ""
    echo "Step 4: Install Privacy Tools"
    if ask_confirmation "Install Tor Browser & Service?"; then
        install_tor_browser
        tor_install
    fi
    if ask_confirmation "Install GPG (Encryption)?"; then
        install_gpg
        setup_gpg
    fi
    if ask_confirmation "Install Signal (Secure Messenger)?"; then
        install_signal
    fi

    echo ""
    success "Setup Complete!"
    info "Run 'better-anonymity verify-security' to check your status."
}

lifecycle_daily() {
    header "Daily Health Check"
    
    # 1. Update Tools
    info "Checking for tool updates..."
    # If brew is installed, optional update
    if command -v brew &> /dev/null; then
         # Only run update if user wants, or just run upgrade on our known tools?
         # Full brew upgrade is heavy. Let's just update blocklists.
         info "Brew installed. Run 'brew upgrade' manually to update tools."
    fi

    # 2. Update Hosts
    if [ -f "/etc/hosts-base" ]; then
        if ask_confirmation "Update Hosts Blocklist?"; then
            network_update_hosts
        fi
    fi

    # 3. Verify Security
    echo ""
    hardening_verify
    
    # 4. Verify DNS
    echo ""
    network_verify_dns

    # 5. Check Tor
    echo ""
    tor_status
}

lifecycle_update() {
    info "Checking for 'better-anonymity' updates..."
    
    # Check if we are in a git repo
    if [ -d "$ROOT_DIR/.git" ]; then
        cd "$ROOT_DIR" || return 1
        info "Pulling latest changes from git..."
        if git pull; then
            success "Update successful."
        else
            error "Update failed. Check git status."
        fi
    else
        warn "Not a git repository. Cannot auto-update."
        warn "Please download the latest version manually."
    fi
}

lifecycle_install_cli() {
    header "Installing Global CLI..."
    local BIN_PATH="/usr/local/bin"
    local SOURCE_BIN="$ROOT_DIR/bin/better-anonymity"
    
    # Check if /usr/local/bin exists
    if [ ! -d "$BIN_PATH" ]; then
        warn "$BIN_PATH does not exist. Attempting to create..."
        execute_sudo "Create bin/ folder" mkdir -p "$BIN_PATH"
    fi
    
    info "Installing symlinks to $BIN_PATH..."
    
    # Create main link
    execute_sudo "Link better-anonymity" ln -sf "$SOURCE_BIN" "$BIN_PATH/better-anonymity"
    
    # Create aliases
    execute_sudo "Link better-anon" ln -sf "$SOURCE_BIN" "$BIN_PATH/better-anon"
    execute_sudo "Link b-a" ln -sf "$SOURCE_BIN" "$BIN_PATH/b-a"
    
    if command -v better-anonymity &>/dev/null; then
        success "CLI installed successfully!"
        echo "You can now run:"
        echo "  better-anonymity"
        echo "  better-anon"
        echo "  b-a"
    else
        warn "Installation completed, but 'better-anonymity' not found in PATH."
        warn "Ensure $BIN_PATH is in your PATH."
    fi
}
