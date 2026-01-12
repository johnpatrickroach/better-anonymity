#!/bin/bash

# lib/lifecycle.sh
# Lifecycle management: setup, daily checks, updates

setup_advanced_dns_atomic() {
    info "Starting Atomic Advanced DNS Setup..."
    
    # 1. Install & Configure Services
    if ! install_dnscrypt; then
        warn "DNSCrypt-Proxy installation failed."
        return 1
    fi
    
    if ! install_unbound; then
        warn "Unbound installation failed."
        return 1
    fi
    
    # 2. Verify Services are Running
    info "Verifying services are active and listening..."
    
    local dnscrypt_ready=false
    local unbound_ready=false
    
    # Check DNSCrypt (Port 5355)
    for i in {1..10}; do
        if nc -z 127.0.0.1 5355 &>/dev/null; then
            dnscrypt_ready=true
            break
        fi
        sleep 1
    done
    
    # Check Unbound (Port 53 typically, or configured port if different? assuming 53 as per unbound.conf)
    # Note: Unbound might take a moment to bind
    for i in {1..10}; do
        if nc -z 127.0.0.1 53 &>/dev/null; then
            unbound_ready=true
            break
        fi
        sleep 1
    done
    
    if [ "$dnscrypt_ready" = true ] && [ "$unbound_ready" = true ]; then
        success "Both services are verified running."
        info "Setting System DNS to Localhost (127.0.0.1)..."
        network_set_dns "localhost"
        return 0
    else
        error "Verification Failed!"
        if [ "$dnscrypt_ready" = false ]; then warn "DNSCrypt-Proxy is NOT responding on port 5355."; fi
        if [ "$unbound_ready" = false ]; then warn "Unbound is NOT responding on port 53."; fi
        
        warn "Falling back to safe default (Quad9)..."
        network_set_dns "quad9"
        return 1
    fi
}

lifecycle_setup() {
    clear
    header "Better Anonymity - First Time Setup"
    echo "Welcome! This wizard will guide you through the recommended security baseline."
    echo "You can skip any step you prefer not to apply."
    echo ""

    # Refresh Sudo credentials to avoid timeouts
    start_sudo_keepalive
    echo ""

    # 1. macOS Hardening
    if ask_confirmation "Step 1: Apply Basic macOS Hardening (Firewall, Sudoers, Umask)?"; then
        load_module "macos_hardening"
        hardening_enable_firewall
        hardening_secure_sudoers
        hardening_set_umask
        hardening_disable_bonjour
        hardening_disable_analytics
        
        if ask_confirmation "Run all hardening steps (Privacy, Updates, Homebrew, etc.)?"; then
            hardening_update_system
            hardening_configure_privacy
            hardening_secure_screen
            hardening_harden_finder
            hardening_anonymize_hostname
            hardening_secure_homebrew
            hardening_disable_captive_portal
            hardening_remove_guest
            hardening_reset_tcc
        fi
        
        # Extended Hardening
        echo ""
        info "Checking Advanced Hardening features..."
        hardening_ensure_filevault
        hardening_ensure_lockdown
        
        success "Hardening applied."
    fi

    # 2. DNS
    echo ""
    if ask_confirmation "Step 2: Configure Encrypted DNS? (Recommended: Localhost/DNSCrypt)"; then
        load_module "network"
        load_module "installers"

        # Auto-Mode Logic
        if [ "${BETTER_ANONYMITY_AUTO_YES:-0}" -eq 1 ]; then
             info "Auto-Resolution: Installing Unbound + DNSCrypt-Proxy..."
             if setup_advanced_dns_atomic; then
                 info "Unbound + DNSCrypt-Proxy setup successful."
             else
                 warn "Advanced DNS setup failed during auto-mode."
             fi
        else
            # Interactive Logic
            local dns_msg="Configure Advanced DNS (Unbound + DNSCrypt)? [Best Anonymity]"
            
            # Check if likely installed (and configured)
            if check_installed "dnscrypt-proxy" && check_unbound_integrity; then
                dns_msg="Unbound & DNSCrypt detected. Use Localhost (127.0.0.1)?"
            fi
            
            if ask_confirmation "$dns_msg"; then
                setup_advanced_dns_atomic
            else
                # Fallback Menu
                echo "Select Alternative Provider:"
                echo "1) Quad9 (9.9.9.9) [Recommended Fallback]"
                echo "2) Mullvad (194.242.2.2)"
                echo "3) Cloudflare (1.1.1.1)"
                echo "4) Localhost (Manual)"
                read -r dns_setup_choice
                case $dns_setup_choice in
                    1) network_set_dns "quad9" ;;
                    2) network_set_dns "mullvad" ;;
                    3) network_set_dns "cloudflare" ;;
                    4) network_set_dns "localhost" ;;
                    *) network_set_dns "quad9" ;;
                esac
            fi
        fi
    fi

    # 3. Hosts Blocklist
    echo ""
    if ask_confirmation "Step 3: Install StevenBlack Hosts Blocklist (Ad-blocking)?"; then
        load_module "network"
        network_update_hosts
    fi

    # 4. Browser Privacy
    echo ""
    echo "Step 4: Browser Privacy"
    if ask_confirmation "Install & Harden Firefox (Arkenfox user.js)?"; then
        load_module "installers"
        install_firefox
        harden_firefox
    fi

    # 5. Essential Tools
    echo ""
    echo "Step 5: Install Privacy Tools"
    if ask_confirmation "Install Tor Browser & Service?"; then
        load_module "installers"
        load_module "tor_manager"
        install_tor_browser
        tor_install
    fi
    if ask_confirmation "Install I2P (Invisible Internet Project)?"; then
        load_module "i2p_manager"
        i2p_install
    fi
    if ask_confirmation "Install GPG (Encryption)?"; then
        load_module "installers"
        install_gpg
        setup_gpg
    fi
    if ask_confirmation "Install Signal (Secure Messenger)?"; then
        load_module "installers"
        install_signal
    fi
    if ask_confirmation "Install KeePassXC (Password Manager)?"; then
        load_module "installers"
        install_keepassxc
    fi
    if ask_confirmation "Install Privoxy (Local Proxy)?"; then
        load_module "installers"
        install_privoxy
    fi

    # 6. Cleanup
    echo ""
    echo "Step 6: System Cleanup"
    if ask_confirmation "Run initial privacy cleanup (Browsers, Logs, Metadata)?"; then
        load_module "cleanup"
        cleanup_metadata
    fi

    echo ""
    success "Setup Complete!"
    info "Run 'better-anonymity verify-security' to check your status."
}

lifecycle_daily() {
    header "Daily Health Check"
    # Load required modules
    load_module "network"
    load_module "macos_hardening"
    load_module "tor_manager"
    
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
        info "$BIN_PATH does not exist. Creating directory for global aliases..."
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
        echo ""
        echo "To enable zsh completions, run:"
        echo ""
        echo "  echo 'fpath=(\"$ROOT_DIR/completions\" \$fpath)' >> ~/.zshrc"
        echo "  echo 'autoload -Uz compinit && compinit' >> ~/.zshrc"
        echo ""
        echo "Then restart your shell."
        echo ""
        echo "Recommended Next Step:"
        echo "  Run 'better-anonymity setup' to apply the security baseline."
    else
        warn "Installation completed, but 'better-anonymity' not found in PATH."
        warn "Ensure $BIN_PATH is in your PATH."
    fi
}


lifecycle_check_update() {
    header "Checking for Updates..."
    
    # Check if we are in a git repo
    if [ -d "$ROOT_DIR/.git" ]; then
        cd "$ROOT_DIR" || return 1
        info "Fetching latest info from git (dry-run)..."
        
        # Git fetch without applying
        git fetch origin >/dev/null 2>&1
        
        # Check status
        local behind_count
        behind_count=$(git rev-list HEAD..origin/main --count 2>/dev/null)
        
        if [ "$behind_count" -gt 0 ]; then
            warn "Updates available! ($behind_count commits behind)"
            info "Run 'better-anonymity update' to apply."
        else
            success "You are up to date."
        fi
    else
        warn "Not a git repository. Cannot check for updates automatically."
        info "Please check https://github.com/johnpatrickroach/better-anonymity for releases."
    fi
}

lifecycle_uninstall() {
    header "Uninstalling Better Anonymity CLI..."
    
    local BIN_PATH="/usr/local/bin"
    if ask_confirmation "Remove global symlinks (b-a, better-anon)?"; then
        execute_sudo "Remove better-anonymity" rm -f "$BIN_PATH/better-anonymity"
        execute_sudo "Remove better-anon" rm -f "$BIN_PATH/better-anon"
        execute_sudo "Remove b-a" rm -f "$BIN_PATH/b-a"
        success "Symlinks removed."
    fi
    
    warn "This command does NOT remove installed tools (Tor, Privoxy) or configuration files (~/.better-anonymity)."
    info "To remove those, manual deletion is required to prevent data loss."
}
