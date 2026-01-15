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



# State Management for Restore/Undo
# ---------------------------------

# Helper: Capture a 'defaults read' value
# Usage: capture_default "domain" "key" "file_suffix"
capture_default() {
    local domain="$1"
    local key="$2"
    local suffix="$3"
    local state_dir="$HOME/.better-anonymity/state"
    
    local val
    if val=$(defaults read "$domain" "$key" 2>/dev/null); then
        echo "$val" > "$state_dir/defaults.$suffix"
    else
        echo "__MISSING__" > "$state_dir/defaults.$suffix"
    fi
}

# Helper: Capture Brew Analytics state
capture_brew_analytics() {
    local state_dir="$HOME/.better-anonymity/state"
    if command -v brew &>/dev/null; then
        if brew analytics | grep -q "disabled"; then
            echo "disabled" > "$state_dir/brew.analytics.original"
        else
            echo "enabled" > "$state_dir/brew.analytics.original"
        fi
    fi
}

# Helper: Restore a 'defaults write' value
# Usage: restore_default "domain" "key" "type" "file_suffix"
# Type can be: -bool, -int, -string, etc.
restore_default() {
    local domain="$1"
    local key="$2"
    local type="$3"
    local suffix="$4"
    local state_dir="$HOME/.better-anonymity/state"
    local file="$state_dir/defaults.$suffix"
    
    if [ -f "$file" ]; then
        local val
        val=$(cat "$file")
        if [ "$val" == "__MISSING__" ]; then
            # Check if currently exists, if so delete?
            # Safer to just defaults delete if it didn't exist, or ignore.
            # Usually 'defaults delete domain key' restores properly if it was missing.
            execute_sudo "Reset Default (Delete)" defaults delete "$domain" "$key" 2>/dev/null || true
        else
            execute_sudo "Restore Default" defaults write "$domain" "$key" $type "$val"
        fi
    fi
}

lifecycle_capture_state() {
    local state_dir="$HOME/.better-anonymity/state"
    mkdir -p "$state_dir"
    
    info "Capturing extended system state..."

    # 1. Hostname
    if [ ! -f "$state_dir/hostname.original" ]; then
        scutil --get ComputerName > "$state_dir/hostname.original"
    fi

    # 2. DNS
    if [ ! -f "$state_dir/dns.original" ]; then
        if command -v networksetup &>/dev/null; then
            networksetup -getdnsservers Wi-Fi > "$state_dir/dns.original"
        fi
    fi

    # 3. Firewall
    if [ ! -f "$state_dir/firewall.original" ]; then
        if [ -x "$SOCKETFILTERFW_CMD" ]; then
             "$SOCKETFILTERFW_CMD" --getglobalstate > "$state_dir/firewall.original"
        fi
    fi
    
    # 4. Defaults (Finder, Dock, Privacy)
    capture_default "com.apple.finder" "AppleShowAllFiles" "finder.showall"
    capture_default "com.apple.finder" "FXEnableExtensionChangeWarning" "finder.extwarn"
    capture_default "com.apple.dock" "show-recents" "dock.recents"
    capture_default "com.apple.screensaver" "askForPassword" "screensaver.ask"
    capture_default "/Library/Preferences/com.apple.loginwindow" "GuestEnabled" "guest.enabled"
    capture_default "/Library/Preferences/com.apple.loginwindow" "AutoSubmit" "analytics.autosubmit"
    capture_default "com.apple.AdLib" "forceLimitAdTracking" "adlib.limit"
    capture_default "com.apple.AdLib" "allowIdentifierForAdvertising" "adlib.id"
    capture_default "com.apple.AdLib" "allowApplePersonalizedAdvertising" "adlib.personal"
    capture_default "com.apple.screensaver" "askForPasswordDelay" "screensaver.delay"
    capture_default "com.apple.assistant.support" "Siri Data Sharing Opt-In Status" "siri.optin"
    capture_default "com.apple.CrashReporter" "DialogType" "crashreporter.dialog"
    
    # 4b. More Finder/Global
    capture_default "NSGlobalDomain" "AppleShowAllExtensions" "global.extensions"
    capture_default "NSGlobalDomain" "NSDocumentSaveNewDocumentsToCloud" "global.icloud"
    capture_default "com.apple.NetworkBrowser" "DisableAirDrop" "network.airdrop"

    # 4c. System Configuration (Captive Portal)
    capture_default "/Library/Preferences/SystemConfiguration/com.apple.captive.control" "Active" "captive.active"
    
    # 4d. Bonjour
    capture_default "/Library/Preferences/com.apple.mDNSResponder" "NoMulticastAdvertisements" "bonjour.multicast"

    # 5. Homebrew Analytics
    capture_brew_analytics
    
    # 5. Remote Login / Events
    if [ ! -f "$state_dir/ssh.original" ]; then
        systemsetup -getremotelogin > "$state_dir/ssh.original" 2>/dev/null || true
    fi
    
    info "System state snapshot saved."
}

lifecycle_restore_state() {
    local state_dir="$HOME/.better-anonymity/state"
    
    info "Restoring System Settings..."
    
    # 1. Hostname
    if [ -f "$state_dir/hostname.original" ]; then
        local orig_name
        orig_name=$(cat "$state_dir/hostname.original")
        if [ -n "$orig_name" ]; then
            info "Restoring Hostname to '$orig_name'..."
            execute_sudo "Restore Hostname" scutil --set ComputerName "$orig_name"
            execute_sudo "Restore LocalHostName" scutil --set LocalHostName "$orig_name"
            execute_sudo "Restore HostName" scutil --set HostName "$orig_name"
        fi
    fi

    # 2. DNS
    if [ -f "$state_dir/dns.original" ]; then
        local orig_dns
        orig_dns=$(cat "$state_dir/dns.original")
        if [[ "$orig_dns" == *"There aren't any DNS Servers set"* ]] || [[ -z "$orig_dns" ]]; then
             execute_sudo "Reset DNS to Empty" networksetup -setdnsservers Wi-Fi "Empty"
        else
             local clean_dns
             clean_dns=$(echo "$orig_dns" | tr '\n' ' ' | xargs)
             execute_sudo "Restore DNS" networksetup -setdnsservers Wi-Fi $clean_dns
        fi
    fi

    # 3. Firewall
    if [ -f "$state_dir/firewall.original" ]; then
        if grep -q "enabled" "$state_dir/firewall.original"; then
             execute_sudo "Enable Firewall" "$SOCKETFILTERFW_CMD" --setglobalstate on
        else
             execute_sudo "Disable Firewall" "$SOCKETFILTERFW_CMD" --setglobalstate off
        fi
    fi
    
    # 4. Defaults
    restore_default "com.apple.finder" "AppleShowAllFiles" "-bool" "finder.showall"
    restore_default "com.apple.finder" "FXEnableExtensionChangeWarning" "-bool" "finder.extwarn"
    restore_default "com.apple.dock" "show-recents" "-bool" "dock.recents"
    restore_default "com.apple.screensaver" "askForPassword" "-int" "screensaver.ask"
    restore_default "/Library/Preferences/com.apple.loginwindow" "GuestEnabled" "-bool" "guest.enabled"
    restore_default "/Library/Preferences/com.apple.loginwindow" "AutoSubmit" "-bool" "analytics.autosubmit"
    restore_default "com.apple.AdLib" "forceLimitAdTracking" "-bool" "adlib.limit"
    restore_default "com.apple.AdLib" "allowIdentifierForAdvertising" "-bool" "adlib.id"
    restore_default "com.apple.AdLib" "allowApplePersonalizedAdvertising" "-bool" "adlib.personal"
    restore_default "com.apple.screensaver" "askForPasswordDelay" "-int" "screensaver.delay"
    restore_default "com.apple.assistant.support" "Siri Data Sharing Opt-In Status" "-int" "siri.optin"
    restore_default "com.apple.CrashReporter" "DialogType" "-string" "crashreporter.dialog"
    
    restore_default "NSGlobalDomain" "AppleShowAllExtensions" "-bool" "global.extensions"
    restore_default "NSGlobalDomain" "NSDocumentSaveNewDocumentsToCloud" "-bool" "global.icloud"
    restore_default "com.apple.NetworkBrowser" "DisableAirDrop" "-bool" "network.airdrop"
    
    restore_default "/Library/Preferences/SystemConfiguration/com.apple.captive.control" "Active" "-bool" "captive.active"
    restore_default "/Library/Preferences/com.apple.mDNSResponder" "NoMulticastAdvertisements" "-bool" "bonjour.multicast"

    # Restore Homebrew Analytics
    local brew_state_file="$state_dir/brew.analytics.original"
    if [ -f "$brew_state_file" ]; then
        local bstate
        bstate=$(cat "$brew_state_file")
        if [ "$bstate" == "enabled" ]; then
            if command -v brew &>/dev/null; then
                 info "Restoring Homebrew Analytics (Enabling)..."
                 brew analytics on
            fi
        fi
    fi
    
    # Reload Finder/Dock to apply defaults
    killall Finder 2>/dev/null || true
    killall Dock 2>/dev/null || true
    
    # 5. Remote Login
    if [ -f "$state_dir/ssh.original" ]; then
        if grep -q "On" "$state_dir/ssh.original"; then
            execute_sudo "Enable Remote Login" systemsetup -setremotelogin on
        else
            execute_sudo "Disable Remote Login" systemsetup -setremotelogin off
        fi
    fi

    # 6. Restore Hosts
    if [ -f "/etc/hosts-base" ]; then
        execute_sudo "Restore Hosts" sh -c "cat /etc/hosts-base > /etc/hosts"
        dscacheutil -flushcache
    fi
    
    # 7. Clean Zshrc
    if [ -f "$HOME/.zshrc" ]; then
        info "Cleaning .zshrc of better-anonymity exports..."
        # Remove known exports
        sed -i '' '/HOMEBREW_NO_ANALYTICS=1/d' "$HOME/.zshrc"
        sed -i '' '/HOMEBREW_NO_INSECURE_REDIRECT=1/d' "$HOME/.zshrc"
        sed -i '' '/DOTNET_CLI_TELEMETRY_OPTOUT=1/d' "$HOME/.zshrc"
        sed -i '' '/POWERSHELL_TELEMETRY_OPTOUT=1/d' "$HOME/.zshrc"
        # Also remove completion block if present (harder to regex, usually manually added by user per README)
    fi
}

lifecycle_setup() {
    clear
    
    # Capture state before any changes
    lifecycle_capture_state
    
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

    # 2.5 Menu Bar Tools (PingBar)
    # Check if we are in auto mode or should ask
    if [ "${BETTER_ANONYMITY_AUTO_YES:-0}" -eq 1 ]; then
        info "Auto-Install: PingBar..."
        load_module "installers"
        install_pingbar
    else
        echo ""
        if ask_confirmation "Install PingBar? (Menu bar tool for quick network status)?"; then
             load_module "installers"
             install_pingbar
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
        install_firefox_extensions
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
    
    # Create wrapper script (more robust than symlink for permissions/resolution)
    # We use a wrapper that execs the absolute path to avoid symlink resolution issues
    local WRAPPER_CONTENT="#!/bin/bash
exec \"$SOURCE_BIN\" \"\$@\""

    # Check if correct wrapper is already installed
    if [ -f "$BIN_PATH/better-anonymity" ] && grep -qF "$SOURCE_BIN" "$BIN_PATH/better-anonymity"; then
        success "better-anonymity is already installed (wrapper points to $SOURCE_BIN)."
        return 0
    fi

    # Install main wrapper
    info "Installing wrapper script to $BIN_PATH/better-anonymity..."
    # Write to temp file first
    local tmp_wrapper
    tmp_wrapper=$(mktemp /tmp/b-a-wrapper.XXXXXX)
    echo "$WRAPPER_CONTENT" > "$tmp_wrapper"
    chmod +x "$tmp_wrapper"
    
    # Move to destination (sudo)
    execute_sudo "Install Wrapper" mv "$tmp_wrapper" "$BIN_PATH/better-anonymity"
    execute_sudo "Set Permissions" chmod 755 "$BIN_PATH/better-anonymity"

    # Create aliases (symlinks to the wrapper are fine, as the wrapper knows the path)
    execute_sudo "Link better-anon" ln -sf "$BIN_PATH/better-anonymity" "$BIN_PATH/better-anon"
    execute_sudo "Link b-a" ln -sf "$BIN_PATH/better-anonymity" "$BIN_PATH/b-a"
    
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
    
    echo ""
    if ask_confirmation "Do you want to attempting to RESTORE system state (Hostname, DNS, Firewall)?"; then
        lifecycle_restore_state
        success "System state restoration attempted."
    fi
    
    local installed_log="$HOME/.better-anonymity/state/installed_tools.log"
    if [ -f "$installed_log" ]; then
        echo ""
        warn "Found tracked installed tools in $installed_log."
        if ask_confirmation "Uninstall tools installed by better-anonymity (brew uninstall)?"; then
             # Sort and unique to avoid duplicates
             sort -u "$installed_log" | while read -r tool; do
                 if [ -n "$tool" ]; then
                     info "Uninstalling $tool..."
                     # We use 'brew uninstall' (ignoring dependencies? or just normall)
                     brew uninstall "$tool" || warn "Failed to uninstall $tool"
                 fi
             done
             
             # Clean up log -- Actually we keep it until final rm, but okay to remove now if successful
             rm -f "$installed_log"
             success "Tools uninstalled."
        fi
    fi
    
    # New: Remove manual files
    local files_log="$HOME/.better-anonymity/state/installed_files.log"
    if [ -f "$files_log" ]; then
        echo ""
        warn "Found tracked manual files (extensions, configs)."
        if ask_confirmation "Delete tracked files (e.g. Firefox extensions)?"; then
            sort -u "$files_log" | while read -r filepath; do
                if [ -f "$filepath" ]; then
                    info "Removing $filepath..."
                    rm -f "$filepath"
                fi
            done
            rm -f "$files_log"
        fi
    fi
    
    echo ""
    if ask_confirmation "Remove state data and logs (~/.better-anonymity)?"; then
        rm -rf "$HOME/.better-anonymity"
        success "Configuration directory removed."
    fi
}
