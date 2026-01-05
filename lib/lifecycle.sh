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
