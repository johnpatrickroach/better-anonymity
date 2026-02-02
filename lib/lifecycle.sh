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
        if check_port 127.0.0.1 5355; then
            dnscrypt_ready=true
            break
        fi
        sleep 1
    done
    
    # Check Unbound (Port 53 typically, or configured port if different? assuming 53 as per unbound.conf)
    # Note: Unbound might take a moment to bind
    for i in {1..10}; do
        if check_port 127.0.0.1 53; then
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

# Helper: Append variable to state file safely (KEY="VAL" format)
save_state_var() {
    local key="$1"
    local value="$2"
    local state_file="$HOME/.better-anonymity/state/restore_state.env"
    
    # Escape backslashes and double quotes for safe double-quoted string
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    
    printf "%s=\"%s\"\n" "$key" "$value" >> "$state_file"
}

# Helper: Retrieve variable from state file (replacing source)
get_state_var() {
    local key="$1"
    local state_file="$HOME/.better-anonymity/state/restore_state.env"
    
    if [ -f "$state_file" ]; then
        # Grep key, cut value, remove surrounding quotes, unescape
        grep "^$key=" "$state_file" | head -n1 | cut -d'=' -f2- | sed 's/^"//;s/"$//' | sed 's/\\"/"/g;s/\\\\/\\/g'
    fi
}


# Helper: Capture a 'defaults read' value
# Usage: capture_default "domain" "key" "file_suffix"
capture_default() {
    local domain="$1"
    local key="$2"
    local suffix="$3"
    
    # Convert suffix to safe variable name (replace . with _)
    local var_name="STATE_DEF_${suffix//./_}"
    
    local val
    if val=$(defaults read "$domain" "$key" 2>/dev/null); then
        save_state_var "$var_name" "$val"
    else
        save_state_var "$var_name" "__MISSING__"
    fi
}

# Helper: Capture Proxy State
# Usage: capture_proxy_state "service" "type" "state_suffix"
# "type" can be: -getwebproxy, -getsecurewebproxy, -getsocksfirewallproxy
capture_proxy_state() {
    local service="$1"
    local proxy_cmd="$2"
    local suffix="$3"
    
    if command -v networksetup &>/dev/null; then
         local output
         output=$(networksetup "$proxy_cmd" "$service")
         local enabled
         local enabled
         enabled=$(echo "$output" | grep "Enabled:" | head -n1 | sed 's/Enabled: //' | tr -d '[:space:]')
         local server
         server=$(echo "$output" | grep "Server:" | head -n1 | sed 's/Server: //' | tr -d '[:space:]')
         local port
         port=$(echo "$output" | grep "Port:" | head -n1 | sed 's/Port: //' | tr -d '[:space:]')
         
         # Fallback if empty (some networksetup versions differ)
         if [ "$enabled" == "Yes" ]; then
             save_state_var "STATE_PROXY_${suffix}_ENABLED" "Yes"
             if [ -n "$server" ]; then save_state_var "STATE_PROXY_${suffix}_SERVER" "$server"; fi
             if [ -n "$port" ]; then save_state_var "STATE_PROXY_${suffix}_PORT" "$port"; fi
         else
             save_state_var "STATE_PROXY_${suffix}_ENABLED" "No"
         fi
    fi
}


# Helper: Restore Proxy State
# Usage: restore_proxy_state "service" "set_cmd_base" "state_suffix"
restore_proxy_state() {
    local service="$1"
    local cmd_base="$2" # e.g. -setwebproxy or -setsocksfirewallproxy
    local suffix="$3"
    
    local enabled
    enabled=$(get_state_var "STATE_PROXY_${suffix}_ENABLED")
    
    if [ "$enabled" == "Yes" ]; then
         local server
         server=$(get_state_var "STATE_PROXY_${suffix}_SERVER")
         local port
         port=$(get_state_var "STATE_PROXY_${suffix}_PORT")
         
         if [ -n "$server" ] && [ -n "$port" ]; then
             execute_sudo "Restore $suffix Proxy" networksetup "$cmd_base" "$service" "$server" "$port"
             
             # Also enable state
             # Determine state command (webproxy -> webproxystate, socksfirewallproxy -> socksfirewallproxystate)
             local state_cmd="${cmd_base}state"
             execute_sudo "Enable $suffix Proxy" networksetup "$state_cmd" "$service" on
         else
             warn "Could not restore $suffix proxy: Missing state."
         fi
    elif [ "$enabled" == "No" ]; then
         local state_cmd="${cmd_base}state"
         execute_sudo "Disable $suffix Proxy" networksetup "$state_cmd" "$service" off 2>/dev/null || true
    fi
}

# Helper: Capture Brew Analytics state (Moved down needed to preserve order if user prefers)
capture_brew_analytics() {
    if command -v brew &>/dev/null; then
        local val
        if brew analytics | grep -q "disabled"; then
            val="disabled"
        else
            val="enabled"
        fi
        save_state_var "STATE_BREW_ANALYTICS" "$val"
    fi
}

# Helper: Restore a 'defaults write' value
# Usage: restore_default "domain" "key" "type" "file_suffix"
restore_default() {
    local domain="$1"
    local key="$2"
    local type="$3"
    local suffix="$4"
    
    # Construct variable name
    local var_name="STATE_DEF_${suffix//./_}"
    
    # Get value using helper
    local val
    val=$(get_state_var "$var_name")
    
    if [ -n "$val" ]; then
        if [ "$val" == "__MISSING__" ]; then
            execute_sudo "Reset Default (Delete)" defaults delete "$domain" "$key" 2>/dev/null || true
        else
            execute_sudo "Restore Default" defaults write "$domain" "$key" $type "$val"
        fi
    fi
}

lifecycle_capture_state() {
    local state_dir="$HOME/.better-anonymity/state"
    local state_file="$state_dir/restore_state.env"
    
    mkdir -p "$state_dir"
    
    info "Capturing extended system state..."
    
    # Initialize State File
    echo "# Better Anonymity System State - $(date)" > "$state_file"
    echo "# DO NOT EDIT MANUALLY" >> "$state_file"
    
    # Pre-calculate active service
    local net_svc="${PLATFORM_ACTIVE_SERVICE:-Wi-Fi}"
    save_state_var "STATE_NETWORK_SERVICE" "$net_svc"


    # 1. Hostname
    local hostname
    hostname=$(scutil --get ComputerName)
    save_state_var "STATE_HOSTNAME" "$hostname"

    # 2. DNS
    # 2. DNS
    if command -v networksetup &>/dev/null; then
        # Detect Active Service (using platform var if available, else literal fallback)
        local dns
        dns=$(networksetup -getdnsservers "$net_svc")
        save_state_var "STATE_DNS" "$dns"
        
        # 2.5 Proxies
        capture_proxy_state "$net_svc" "-getwebproxy" "WEB"
        capture_proxy_state "$net_svc" "-getsecurewebproxy" "SECUREWEB"
        capture_proxy_state "$net_svc" "-getsocksfirewallproxy" "SOCKS"
    fi


    # 3. Firewall
    if [ -x "$SOCKETFILTERFW_CMD" ]; then
         local fw_state
         fw_state=$("$SOCKETFILTERFW_CMD" --getglobalstate)
         save_state_var "STATE_FIREWALL" "$fw_state"
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
    local ssh_state
    ssh_state=$(systemsetup -getremotelogin 2>/dev/null || true)
    save_state_var "STATE_SSH" "$ssh_state"
    
    info "System state snapshot saved to $state_file."
}

lifecycle_restore_state() {
    local state_dir="$HOME/.better-anonymity/state"
    local state_file="$state_dir/restore_state.env"
    
    if [ ! -f "$state_file" ]; then
        warn "No state file found at $state_file. Cannot restore."
        return 1
    fi
    
    info "Loading System State from $state_file..."
    
    # Load Top-Level Variables
    local STATE_HOSTNAME
    STATE_HOSTNAME=$(get_state_var "STATE_HOSTNAME")
    
    local STATE_DNS
    STATE_DNS=$(get_state_var "STATE_DNS")
    
    local STATE_FIREWALL
    STATE_FIREWALL=$(get_state_var "STATE_FIREWALL")
    
    local STATE_BREW_ANALYTICS
    STATE_BREW_ANALYTICS=$(get_state_var "STATE_BREW_ANALYTICS")
    
    local STATE_SSH
    STATE_SSH=$(get_state_var "STATE_SSH")

    
    info "Restoring System Settings..."
    
    # 1. Hostname
    if [ -n "$STATE_HOSTNAME" ]; then
        info "Restoring Hostname to '$STATE_HOSTNAME'..."
        execute_sudo "Restore Hostname" scutil --set ComputerName "$STATE_HOSTNAME"
        execute_sudo "Restore LocalHostName" scutil --set LocalHostName "$STATE_HOSTNAME"
        execute_sudo "Restore HostName" scutil --set HostName "$STATE_HOSTNAME"
    fi

    # 2. DNS
    local STATE_NETWORK_SERVICE
    STATE_NETWORK_SERVICE=$(get_state_var "STATE_NETWORK_SERVICE")
    
    # Target original service if known, else fallback to current active
    local net_svc="${STATE_NETWORK_SERVICE:-${PLATFORM_ACTIVE_SERVICE:-Wi-Fi}}"
    
    if [ -n "$STATE_NETWORK_SERVICE" ] && [ "$STATE_NETWORK_SERVICE" != "${PLATFORM_ACTIVE_SERVICE:-Wi-Fi}" ]; then
         warn "Restoring state to original service '$STATE_NETWORK_SERVICE' (Current active: '${PLATFORM_ACTIVE_SERVICE:-Wi-Fi}')"
    fi
    
    if [ -n "$STATE_DNS" ]; then
        if [[ "$STATE_DNS" == *"There aren't any DNS Servers set"* ]] || [[ -z "$STATE_DNS" ]]; then
             execute_sudo "Reset DNS to Empty" networksetup -setdnsservers "$net_svc" "Empty"
        else
             local clean_dns
             clean_dns=$(echo "$STATE_DNS" | tr '\n' ' ' | xargs)
             execute_sudo "Restore DNS" networksetup -setdnsservers "$net_svc" $clean_dns
        fi
    fi
    
    # 2.5 Proxies (Restore)
    info "Restoring Network Proxies..."
    restore_proxy_state "$net_svc" "-setwebproxy" "WEB"
    restore_proxy_state "$net_svc" "-setsecurewebproxy" "SECUREWEB"
    restore_proxy_state "$net_svc" "-setsocksfirewallproxy" "SOCKS"


    # 3. Firewall
    if [ -n "$STATE_FIREWALL" ]; then
        if [[ "$STATE_FIREWALL" == *"enabled"* ]]; then
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
    if [ "$STATE_BREW_ANALYTICS" == "enabled" ]; then
        if command -v brew &>/dev/null; then
             info "Restoring Homebrew Analytics (Enabling)..."
             brew analytics on
        fi
    fi
    
    # Reload Finder/Dock to apply defaults
    killall Finder 2>/dev/null || true
    killall Dock 2>/dev/null || true
    
    # 5. Remote Login
    if [ -n "$STATE_SSH" ]; then
        if [[ "$STATE_SSH" == *"On"* ]]; then
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
        sed_in_place '/HOMEBREW_NO_ANALYTICS=1/d' "$HOME/.zshrc"
        sed_in_place '/HOMEBREW_NO_INSECURE_REDIRECT=1/d' "$HOME/.zshrc"
        sed_in_place '/DOTNET_CLI_TELEMETRY_OPTOUT=1/d' "$HOME/.zshrc"
        sed_in_place '/POWERSHELL_TELEMETRY_OPTOUT=1/d' "$HOME/.zshrc"
        # Also remove completion block if present (harder to regex, usually manually added by user per README)
    fi
}

lifecycle_setup() {
    clear
    show_banner
    
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
    if ask_confirmation "Install OnionShare (Secure File Sharing)?"; then
        load_module "installers"
        install_onionshare
    fi
    if ask_confirmation "Install GPG (Encryption)?"; then
        load_module "installers"
        install_gpg
    fi
    if ask_confirmation "Install Signal (Secure Messenger)?"; then
        load_module "installers"
        install_signal
    fi
    if ask_confirmation "Install Telegram (Cloud-based Messenger)?"; then
        load_module "installers"
        install_telegram
    fi
    if ask_confirmation "Install Session (No Phone Number Messenger)?"; then
        load_module "installers"
        install_session
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
    
    # 1. Update Tools & System
    info "Checking for tool and system updates..."
    
    # 1a. System Update
    if ask_confirmation "Run macOS System Update (softwareupdate -ia)?"; then
        info "Running softwareupdate (may require restart)..."
        # -i: install, -a: all appropriate updates
        execute_sudo "System Update" softwareupdate -ia || warn "Software Update reported an issue."
    fi
    
    # 1b. Homebrew Update
    if command -v brew &> /dev/null; then
         if ask_confirmation "Update Homebrew and installed packages?"; then
             info "Updating Homebrew..."
             execute_brew "Update" update
             info "Upgrading packages..."
             execute_brew "Upgrade" upgrade || warn "Brew upgrade encountered errors."
         fi
    else
         info "Homebrew not found. Skipping package updates."
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
    network_verify_anonymity

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
        section "CLI Usage" \
            "You can now run:" \
            "  better-anonymity" \
            "  better-anon" \
            "  b-a" \
            "" \
            "To enable zsh completions, run:" \
            "" \
            "  echo 'fpath=(\"$ROOT_DIR/completions\" \$fpath)' >> ~/.zshrc" \
            "  echo 'autoload -Uz compinit && compinit' >> ~/.zshrc" \
            "" \
            "Then restart your shell." \
            "" \
            "Recommended Next Step:" \
            "  Run 'better-anonymity setup' to apply the security baseline."
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
    
    if ask_confirmation_with_info "Remove CLI shims?" \
        "This removes the global commands: better-anonymity, better-anon, and b-a." \
        "Installed tools (Tor, Privoxy, etc.) are not removed by this step."; then
        execute_sudo "Remove better-anonymity" rm -f "$BIN_PATH/better-anonymity"
        execute_sudo "Remove better-anon" rm -f "$BIN_PATH/better-anon"
        execute_sudo "Remove b-a" rm -f "$BIN_PATH/b-a"
        success "Symlinks removed."
    fi
    
    warn "This command does NOT remove installed tools (Tor, Privoxy) or configuration files (~/.better-anonymity)."
    info "To remove those, manual deletion is required to prevent data loss."
    
    if ask_confirmation_with_info "Restore system state?" \
        "Attempts to restore hostname, DNS, firewall, proxies, and related settings from the snapshot." \
        "Use this if you want to undo configuration changes made by better-anonymity."; then
        lifecycle_restore_state
        success "System state restoration attempted."
    fi
    
    local installed_log="$HOME/.better-anonymity/state/installed_tools.log"
    if [ -f "$installed_log" ]; then
        echo ""
        if ask_confirmation_with_info "Uninstall tracked tools?" \
            "Uninstalls tools recorded in $installed_log using 'brew uninstall'." \
            "This may remove Tor, DNSCrypt, Unbound, and other dependencies set up by better-anonymity."; then
             # Sort and unique to avoid duplicates
             sort -u "$installed_log" | while read -r tool; do
                 if [ -n "$tool" ]; then
                     info "Uninstalling $tool..."
                     # We use 'execute_brew' to handle privilege drops
                     execute_brew "Uninstalling $tool" uninstall "$tool" || warn "Failed to uninstall $tool"
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
        if ask_confirmation_with_info "Delete tracked files?" \
            "Deletes files recorded in $files_log (e.g., Firefox extensions and custom configs)." \
            "Only choose this if you want to fully remove these artifacts."; then
            sort -u "$files_log" | while read -r filepath; do
                if [ -f "$filepath" ]; then
                    info "Removing $filepath..."
                    rm -f "$filepath"
                fi
            done
            rm -f "$files_log"
        fi
    fi
    
    if ask_confirmation_with_info "Remove state data and logs?" \
        "Deletes ~/.better-anonymity, including state snapshots, logs, and internal tracking files." \
        "Secrets in the vault will also be removed if stored there."; then
        rm -rf "$HOME/.better-anonymity"
        success "Configuration directory removed."
    fi
}
