#!/bin/bash

# lib/installers.sh
# Tool installation functions

# Generic pattern for simple cask installs with a docs hint.
# Usage: install_app_with_docs "Display Name" "cask-name" "App.app" "docs/path.md"
install_app_with_docs() {
    local display="$1"
    local cask="$2"
    local app="$3"
    local doc_path="$4"

    info "Installing $display..."
    require_brew
    install_cask_package "$cask" "$app"
    if [ -n "$doc_path" ]; then
        info "Refer to $doc_path for usage instructions."
    fi
}

install_privoxy() {
    require_brew

    install_brew_package "privoxy"

    info "Applying configuration..."
    # Use BREW_PREFIX from platform.sh
    local CONF_DIR="$BREW_PREFIX/etc/privoxy"
    # Use ROOT_DIR resolved from main script
    local CONFIG_SRC="$ROOT_DIR/config/privoxy"
    local RESTART_NEEDED="false"
    
    # Copy main config
    if [ -f "$CONFIG_SRC/config" ]; then
        # Check if config differs (ignore empty lines/comments for robustness, or just direct cmp)
        # We need to handle the ARM patch logic too. 
        # Strategy: Generate the target config in a temp file, then compare.
        local TEMP_CONFIG=$(mktemp /tmp/privoxy_config.XXXXXX)
        cp "$CONFIG_SRC/config" "$TEMP_CONFIG"
        
        # Patch for ARM if needed
        if [ "$PLATFORM_ARCH" == "arm64" ]; then
            sed_in_place "s|/usr/local|$BREW_PREFIX|g" "$TEMP_CONFIG"
        fi
        
        if ! cmp -s "$TEMP_CONFIG" "$CONF_DIR/config"; then
            info "Configuration changed. Updating..."
            if [ -f "$CONF_DIR/config" ]; then cp "$CONF_DIR/config" "$CONF_DIR/config.bak"; fi
            cp "$TEMP_CONFIG" "$CONF_DIR/config"
            RESTART_NEEDED="true"
        else
            info "Configuration is up to date."
        fi
        rm -f "$TEMP_CONFIG"
    else
        die "Config not found: $CONFIG_SRC/config"
    fi

    # Copy actions and filters
    # Copy actions and filters
    # Enable nullglob to handle case where no files match
    shopt -s nullglob
    for file_path in "$CONFIG_SRC"/*.{action,filter}; do
        local file
        file=$(basename "$file_path")
        
        # Ensure we don't try to copy directory itself in weird edge cases
        [ -f "$file_path" ] || continue

        if ! cmp -s "$file_path" "$CONF_DIR/$file"; then
            info "Updating $file..."
            cp "$file_path" "$CONF_DIR/$file"
            RESTART_NEEDED="true"
        fi
    done
    shopt -u nullglob

    # Check if running
    local is_running=false
    if brew services list | grep "privoxy" | grep -q "started"; then
        is_running=true
    elif pgrep -x "privoxy" >/dev/null; then
        is_running=true
    fi

    if [ "$RESTART_NEEDED" == "true" ] || [ "$is_running" = false ]; then
        info "Restarting Privoxy..."
        brew services restart privoxy
    else
        info "Privoxy is running and config is unchanged. Skipping restart."
    fi

    info "Configuring System Proxy (HTTP/HTTPS)..."
    
    # Check current state to avoid redundant sudo
    info "Configuring Privoxy..."
    local HTTP_PROXY
    HTTP_PROXY=$(networksetup -getwebproxy "${PLATFORM_WIFI_SERVICE:-Wi-Fi}")
    
    local HTTPS_PROXY
    HTTPS_PROXY=$(networksetup -getsecurewebproxy "${PLATFORM_WIFI_SERVICE:-Wi-Fi}")
    
    # Set HTTP/HTTPS Proxy to 127.0.0.1:8118 (Privoxy default)
    if [[ "$HTTP_PROXY" == *"Enabled: No"* ]]; then
        execute_sudo "Set HTTP Proxy" networksetup -setwebproxy "${PLATFORM_WIFI_SERVICE:-Wi-Fi}" 127.0.0.1 8118
        # Toggle on
        execute_sudo "Enable HTTP Proxy" networksetup -setwebproxystate "${PLATFORM_WIFI_SERVICE:-Wi-Fi}" on
    fi
    
    if [[ "$HTTPS_PROXY" == *"Enabled: No"* ]]; then
        execute_sudo "Set HTTPS Proxy" networksetup -setsecurewebproxy "${PLATFORM_WIFI_SERVICE:-Wi-Fi}" 127.0.0.1 8118
        execute_sudo "Enable HTTPS Proxy" networksetup -setsecurewebproxystate "${PLATFORM_WIFI_SERVICE:-Wi-Fi}" on
    fi
}

install_tor() {
    warn "install_tor is deprecated. Redirecting to tor_install..."
    tor_install
}

install_gpg() {
    # Check for Homebrew
    require_brew
    
    # Install
    if ! command -v gpg >/dev/null; then
         info "Installing GnuPG..."
         execute_with_spinner "Installing GnuPG..." install_brew_package "gnupg"
    else
         info "GnuPG is already installed."
    fi
    execute_with_spinner "Installing Pinentry..." install_brew_package "pinentry-mac"

    # Configure
    configure_gpg
}

configure_gpg() {
    info "Configuring GPG..."
    local GPG_HOME="$HOME/.gnupg"
    if [ ! -d "$GPG_HOME" ]; then
         info "Creating $GPG_HOME..."
         mkdir -p "$GPG_HOME"
         chmod 700 "$GPG_HOME"
    fi

    local SRC_CONF="$ROOT_DIR/config/gpg/gpg.conf"
    local DEST_CONF="$GPG_HOME/gpg.conf"
    local CHANGED="false"

    if [ -f "$SRC_CONF" ]; then
        if [ -f "$DEST_CONF" ]; then
             if ! cmp -s "$SRC_CONF" "$DEST_CONF"; then
                 info "Updating gpg.conf..."
                 # Create backup
                 local backup="$DEST_CONF.backup.$(date +%s)"
                 cp "$DEST_CONF" "$backup"
                 info "Backup created at $backup"
                 
                 cp "$SRC_CONF" "$DEST_CONF"
                 chmod 600 "$DEST_CONF"
                 CHANGED="true"
             else
                 info "gpg.conf is up to date."
             fi
        else
             info "Installing gpg.conf..."
             cp "$SRC_CONF" "$DEST_CONF"
             chmod 600 "$DEST_CONF"
             CHANGED="true"
        fi
    else
        warn "Source configuration file not found at $SRC_CONF"
    fi

    local AGENT_CONF="$GPG_HOME/gpg-agent.conf"
    local EXPECTED_AGENT_CONF="pinentry-program $BREW_PREFIX/bin/pinentry-mac"
    
    if [ ! -f "$AGENT_CONF" ] || ! grep -Fxq "$EXPECTED_AGENT_CONF" "$AGENT_CONF"; then
         info "Updating gpg-agent.conf..."
         echo "$EXPECTED_AGENT_CONF" > "$AGENT_CONF"
         CHANGED="true"
    else
         info "gpg-agent.conf is up to date."
    fi

    if [ "$CHANGED" == "true" ]; then
        info "Reloading gpg-agent..."
        killall gpg-agent 2>/dev/null || true
    else
        info "GPG configuration unchanged. Skipping agent reload."
    fi
    
    info "Please refer to docs/GPG.md for usage and YubiKey setup."
}



# ... (firefox/harden/tor_browser remain custom) ...



install_signal() {
    install_app_with_docs "Signal Desktop" "signal" "Signal.app" "docs/MESSENGERS.md"
}

install_keepassxc() {
    install_app_with_docs "KeePassXC" "keepassxc" "KeePassXC.app" "docs/PASSWORDS.md"
}

install_dnscrypt() {
    require_brew
    info "Installing DNSCrypt-Proxy..."
    if is_brew_installed "dnscrypt-proxy"; then
        info "DNSCrypt-Proxy is already installed."
    else
        execute_with_spinner "Installing DNSCrypt-Proxy..." brew install dnscrypt-proxy
    fi

    local CONF_SRC="$ROOT_DIR/config/dnscrypt-proxy/dnscrypt-proxy.toml"
    local CONF_DEST="$BREW_PREFIX/etc/dnscrypt-proxy.toml"

    if [ ! -f "$CONF_SRC" ]; then
        die "Configuration file not found: $CONF_SRC"
    fi

    # Check for config difference
    local config_changed=false
    if [ -f "$CONF_DEST" ]; then
        if cmp -s "$CONF_SRC" "$CONF_DEST"; then
            info "DNSCrypt config is up to date."
        else
            info "Configuration changed. Updating $CONF_DEST..."
            cp "$CONF_DEST" "${CONF_DEST}.bak"
            cp "$CONF_SRC" "$CONF_DEST"
            config_changed=true
        fi
    else
        info "Installing configuration to $CONF_DEST..."
        cp "$CONF_SRC" "$CONF_DEST"
        config_changed=true
    fi
    
    # (Re)start service if needed
    if [ "$config_changed" = true ]; then
        info "Restarting DNSCrypt-Proxy (requires sudo)..."
        manage_service "restart" "dnscrypt-proxy" "true"
    else
        # Ensure it's running
        manage_service "start" "dnscrypt-proxy" "true"
    fi
    
    info "DNSCrypt-Proxy started on port 5355."
    info "Verify with: sudo lsof +c 15 -Pni UDP:5355"
}

install_pingbar() {
    info "Checking requirements for PingBar..."
    if ! command -v swift &> /dev/null; then
         die "Swift compiler not found. Please install Xcode Command Line Tools (xcode-select --install)."
    fi

    local APP_PATH="${PINGBAR_APP_PATH:-/Applications/PingBar.app}"
    local BUNDLE_ID="fr.jedisct1.PingBar"
    local need_install=true
    
    if [ -d "$APP_PATH" ]; then
        info "PingBar is already installed."
        need_install=false
    fi
    
    if [ "$need_install" = "true" ]; then
        if ! ask_confirmation_with_info "Compiling PingBar from Source" \
             "PingBar is not available via Homebrew." \
             "This installer will download the source code and compile it using Swift." \
             "This process requires Xcode Command Line Tools and may take a few minutes."; then
             warn "PingBar installation cancelled by user."
             return 0
        fi

        # Create a temp dir for building
        local BUILD_DIR
        BUILD_DIR=$(mktemp -d)
        
        info "Cloning PingBar..."
        if ! git clone https://github.com/jedisct1/pingbar.git "$BUILD_DIR/pingbar"; then
            rm -rf "$BUILD_DIR"
            die "Failed to clone PingBar repository."
        fi

        pushd "$BUILD_DIR/pingbar" > /dev/null || die "Failed to enter build directory."
        
        info "Building PingBar (this may take a moment)..."
        if ! make bundle; then
            popd > /dev/null
            rm -rf "$BUILD_DIR"
            die "PingBar build failed."
        fi
        
        info "Installing PingBar..."
        # 'make install' typically defaults to /Applications or similar. 
        # We will trust it or assume standard behavior.
        if ! make install; then
            popd > /dev/null
            rm -rf "$BUILD_DIR"
            die "PingBar installation failed."
        fi

        popd > /dev/null
        rm -rf "$BUILD_DIR"
    fi
    
    info "Configuring PingBar..."
    local config_changed=false
    
    # "Restore my custom DNS after passing captive portal"
    # defaults read returns strict 1/0 usually? Or strings? We'll check carefully.
    local current_dns=$(defaults read "$BUNDLE_ID" RestoreDNS 2>/dev/null)
    if [ "$current_dns" != "1" ] && [ "$current_dns" != "true" ]; then
        defaults write "$BUNDLE_ID" RestoreDNS -bool true
        config_changed=true
    fi
    
    # "Launch PingBar at login"
    local current_launch=$(defaults read "$BUNDLE_ID" LaunchAtLogin 2>/dev/null)
    if [ "$current_launch" != "1" ] && [ "$current_launch" != "true" ]; then
        defaults write "$BUNDLE_ID" LaunchAtLogin -bool true
        config_changed=true
    fi
    
    if [ "$config_changed" = "false" ]; then
        info "PingBar configuration is up to date."
    else
        info "PingBar configuration updated."
    fi

    # Check process
    if pgrep -x "PingBar" >/dev/null; then
        if [ "$config_changed" = "true" ]; then
            info "Restarting PingBar to apply changes..."
            killall PingBar
            open "$APP_PATH"
        else
            info "PingBar is already running."
        fi
    else
        info "Starting PingBar..."
        open "$APP_PATH"
    fi

    info "PingBar installed and configured."
}

create_unbound_user() {
    # Check if user already exists
    if dscl . -list /Users/unbound &>/dev/null || dscl . -list /Users/_unbound &>/dev/null; then
        warn "User _unbound or unbound already exists. Skipping user creation."
        return 0
    fi

    info "Finding available User ID for _unbound..."
    local uid=333
    while true; do
        if ! dscl . -list /Groups PrimaryGroupID | grep -q "$uid" && \
           ! dscl . -list /Users PrimaryGroupID | grep -q "$uid"; then
            break
        fi
        ((uid++))
        if [ "$uid" -gt 500 ]; then
            die "Could not find a free UID in range 333-500."
        fi
    done
    info "Using UID $uid for _unbound."

    info "Creating _unbound group and user..."
    execute_sudo "Create Group" dscl . -create /Groups/_unbound
    execute_sudo "Set GroupId" dscl . -create /Groups/_unbound PrimaryGroupID "$uid"
    execute_sudo "Create User" dscl . -create /Users/_unbound
    execute_sudo "Set RecordName" dscl . -create /Users/_unbound RecordName _unbound unbound
    execute_sudo "Set RealName" dscl . -create /Users/_unbound RealName "Unbound DNS server"
    execute_sudo "Set UserID" dscl . -create /Users/_unbound UniqueID "$uid"
    execute_sudo "Set PrimaryGroupID" dscl . -create /Users/_unbound PrimaryGroupID "$uid"
    execute_sudo "Set UserShell" dscl . -create /Users/_unbound UserShell /usr/bin/false
    execute_sudo "Set Password" dscl . -create /Users/_unbound Password '*'
    execute_sudo "Set Membership" dscl . -create /Groups/_unbound GroupMembership _unbound
}

install_unbound() {
    require_brew
    info "Installing Unbound..."
    if is_brew_installed "unbound"; then
        info "Unbound is already installed."
    else
        brew install unbound
    fi

    create_unbound_user

    info "Setting up DNSSEC root key (requires sudo)..."
    local ROOT_KEY="$BREW_PREFIX/etc/unbound/root.key"
    if [ ! -f "$ROOT_KEY" ]; then
        execute_sudo "Fetch Root Key" unbound-anchor -a "$ROOT_KEY" || true # unbound-anchor can fail if certs are tricky, checking validity later is better
    else
        info "Root key already exists at $ROOT_KEY. Skipping fetch."
    fi

    info "Generating Control Certificates..."
    local CERT_DIR="$BREW_PREFIX/etc/unbound"
    if [ ! -f "$CERT_DIR/unbound_control.key" ] || \
       [ ! -f "$CERT_DIR/unbound_control.pem" ] || \
       [ ! -f "$CERT_DIR/unbound_server.key" ] || \
       [ ! -f "$CERT_DIR/unbound_server.pem" ]; then
        execute_sudo "Setup Control" unbound-control-setup -d "$CERT_DIR"
    else
        info "Control certificates already exist in $CERT_DIR. Skipping generation."
    fi

    info "Copying configuration..."
    local CONF_SRC="$ROOT_DIR/config/unbound/unbound.conf"
    local CONF_DEST="$BREW_PREFIX/etc/unbound/unbound.conf"

    if [ ! -f "$CONF_SRC" ]; then
        die "Configuration file not found: $CONF_SRC"
    fi

    # Prepare temp config for comparison (handling ARM patch)
    local TEMP_CONF=$(mktemp /tmp/unbound_conf.XXXXXX)
    cp "$CONF_SRC" "$TEMP_CONF"
    
    # Patch configuration for ARM Macs in temp file
    if [[ "$BREW_PREFIX" != "/usr/local" ]]; then
        sed_in_place "s|/usr/local|$BREW_PREFIX|g" "$TEMP_CONF"
    fi
    
    local config_changed=false
    
    # Check vs Destination
    # Use sudo cmp because destination might be root-owned
    if [ -f "$CONF_DEST" ]; then
        local files_match=false
        # Check readability to avoid unnecessary sudo
        if [ -r "$CONF_DEST" ]; then
            cmp -s "$TEMP_CONF" "$CONF_DEST" && files_match=true
        else
            sudo cmp -s "$TEMP_CONF" "$CONF_DEST" && files_match=true
        fi

        if [ "$files_match" == "true" ]; then
            info "Unbound configuration is up to date."
        else
            info "Configuration changed. Updating $CONF_DEST..."
            execute_sudo "Backup Config" cp "$CONF_DEST" "${CONF_DEST}.bak"
            execute_sudo "Update Config" cp "$TEMP_CONF" "$CONF_DEST"
            config_changed=true
        fi
    else
        info "Installing configuration to $CONF_DEST..."
        execute_sudo "Install Config" cp "$TEMP_CONF" "$CONF_DEST"
        config_changed=true
    fi
    rm -f "$TEMP_CONF"

    info "Verifying configuration..."
    if ! execute_sudo "Check Config" unbound-checkconf "$CONF_DEST"; then
        die "Unbound configuration check failed!"
    fi

    info "Setting permissions..."
    execute_sudo "Chown Unbound" chown -R _unbound:staff "$BREW_PREFIX/etc/unbound"
    execute_sudo "Chmod Unbound" chmod 640 "$BREW_PREFIX/etc/unbound"/*

    info "Directing Unbound (Brew) to start on boot..."
    if [ "$config_changed" = true ]; then
        info "Restarting Unbound (requires sudo)..."
        manage_service "restart" "unbound" "true"
    else
        manage_service "start" "unbound" "true"
    fi

    info "Unbound installed and configured."
    info "Test DNSSEC with: dig org. SOA +dnssec @127.0.0.1 | grep -E 'NOERROR|ad'"
}

check_unbound_integrity() {
    # 1. Check if Package is installed
    if ! check_installed "unbound"; then
        return 1
    fi

    # 2. Check for User and Group
    if ! dscl . -list /Users/_unbound &>/dev/null; then
        return 1
    fi
    if ! dscl . -list /Groups/_unbound &>/dev/null; then
        return 1
    fi

    # 3. Check for Config
    # We need BREW_PREFIX. Platform.sh should be loaded, but ensure it.
    if [ -z "$BREW_PREFIX" ]; then
        # Fallback detection if needed, or assume platform.sh loaded
        if [ "$(uname -m)" == "arm64" ]; then
            BREW_PREFIX="/opt/homebrew"
        else
            BREW_PREFIX="/usr/local"
        fi
    fi
    
    if [ ! -f "$BREW_PREFIX/etc/unbound/unbound.conf" ]; then
        return 1
    fi

    return 0
}

install_firefox() {
    install_app_with_docs "Firefox" "firefox" "Firefox.app" ""
}

harden_firefox() {
    info "Hardening Firefox (Arkenfox)..."
    
    local profile_path
    if ! profile_path=$(get_firefox_profile); then
        die "Firefox profiles directory not found or no suitable profile found. Is Firefox installed and run at least once?"
    fi
    
    info "Target Profile: $(basename "$profile_path")"
    
    # 1. Backups
    local backup_ts
    backup_ts=$(date +%Y%m%d%H%M%S)
    
    if [ -f "$profile_path/prefs.js" ]; then
        info "Backing up prefs.js..."
        cp "$profile_path/prefs.js" "$profile_path/prefs.js.backup.$backup_ts"
    else
        warn "prefs.js not found, nothing to backup."
    fi
    
    if [ -f "$profile_path/user.js" ]; then
        info "Backing up existing user.js..."
        cp "$profile_path/user.js" "$profile_path/user.js.backup.$backup_ts"
    fi

    # 2. Install Arkenfox Scripts
    info "Downloading Arkenfox scripts (updater.sh, prefsCleaner.sh)..."
    local updater_url="https://raw.githubusercontent.com/arkenfox/user.js/master/updater.sh"
    local cleaner_url="https://raw.githubusercontent.com/arkenfox/user.js/master/prefsCleaner.sh"
    
    if ! curl -L -s -o "$profile_path/updater.sh" "$updater_url"; then
        die "Failed to download updater.sh"
    fi
    chmod +x "$profile_path/updater.sh"
    
    if ! curl -L -s -o "$profile_path/prefsCleaner.sh" "$cleaner_url"; then
        warn "Failed to download prefsCleaner.sh"
    else
        chmod +x "$profile_path/prefsCleaner.sh"
    fi
    
    # 3. Create Overrides
    info "Creating user-overrides.js..."
    local overrides_file="$profile_path/user-overrides.js"
    {
        echo "// Better Anonymity Overrides"
        echo "// Generated by better-anonymity on $(date)"
        echo ""
        echo "// 3 = Restore previous session"
        echo "user_pref(\"browser.startup.page\", 3);"
        echo ""
        echo "// Example: Add your custom overrides here or edit this file later."
    } > "$overrides_file"

    # 4. Run Updater to generate user.js
    info "Running Arkenfox updater to generate user.js..."
    # -s: silent, -u: update (don't ask for confirmation), -d: don't create backups (we did our own)
    # The script acts on the directory it is residing in usually, or current dir.
    # We cd into profile to run it safely.
    (
        cd "$profile_path" || die "Failed to enter profile directory."
        # Use bash explicitly
        if ! bash updater.sh -s -u; then
             die "Arkenfox updater failed."
        fi
    )
    
    # 5. Track Files
    local state_dir="$HOME/.better-anonymity/state"
    mkdir -p "$state_dir"
    {
        echo "$profile_path/user.js"
        echo "$profile_path/user-overrides.js"
        echo "$profile_path/updater.sh"
        [ -f "$profile_path/prefsCleaner.sh" ] && echo "$profile_path/prefsCleaner.sh"
        # Log specific backup files
        [ -f "$profile_path/prefs.js.backup.$backup_ts" ] && echo "$profile_path/prefs.js.backup.$backup_ts"
        [ -f "$profile_path/user.js.backup.$backup_ts" ] && echo "$profile_path/user.js.backup.$backup_ts"
    } >> "$state_dir/installed_files.log"
    
    info "Arkenfox installed successfully."
    info "To update in the future, run: cd '$profile_path' && ./updater.sh"
    info "A 'prefsCleaner.sh' is also available in the profile directory to reset prefs if needed."
    
    verify_firefox
    info "Firefox hardening complete. Please restart Firefox."
}

install_firefox_extensions() {
    info "Installing Firefox Extensions..."
    
    local profile_path
    if ! profile_path=$(get_firefox_profile); then
         warn "Firefox profile not found. Cannot install extensions."
         return 1
    fi
    
    local extensions_dir="$profile_path/extensions"
    if [ ! -d "$extensions_dir" ]; then
        mkdir -p "$extensions_dir"
    fi
    
    # 1. uBlock Origin
    local ublock_id="uBlock0@raymondhill.net"
    local ublock_xpi="$extensions_dir/${ublock_id}.xpi"
    
    if [ -f "$ublock_xpi" ]; then
        info "uBlock Origin extension found. Skipping download."
    else
        info "Downloading uBlock Origin..."
        local url="https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
        if ! curl -L -o "$ublock_xpi" "$url"; then
            warn "Failed to download uBlock Origin."
        else
            info "uBlock Origin placed in extensions folder."
            info "Note: You must approve the extension in Firefox upon next launch."
            # Log for restore
            local state_dir="$HOME/.better-anonymity/state"
            mkdir -p "$state_dir"
            echo "$ublock_xpi" >> "$state_dir/installed_files.log"
        fi
    fi
}

get_firefox_profile() {
    local FIREFOX_DIR="$HOME/Library/Application Support/Firefox/Profiles"
    if [ ! -d "$FIREFOX_DIR" ]; then
        return 1
    fi
    
    local profile_path=""
    local dr_profile
    dr_profile=$(find "$FIREFOX_DIR" -maxdepth 1 -name "*.default-release" | head -n 1)
    
    if [ -n "$dr_profile" ]; then
        profile_path="$dr_profile"
    else
        local d_profile
        d_profile=$(find "$FIREFOX_DIR" -maxdepth 1 -name "*.default" -print | head -n 1)
        if [ -n "$d_profile" ]; then
            profile_path="$d_profile"
        fi
    fi
    
    if [ -z "$profile_path" ]; then
        return 1
    fi
    
    echo "$profile_path"
    return 0
}

verify_firefox() {
    info "Verifying Firefox Hardening..."
    
    local profile_path
    if ! profile_path=$(get_firefox_profile); then
         warn "Firefox profile not found. Cannot verify."
         return 1
    fi
    
    info "Checking profile: $(basename "$profile_path")"
    
    # Check 1: user.js exists
    if [ -f "$profile_path/user.js" ]; then
        info "[PASS] user.js exists."
    else
        warn "[FAIL] user.js does NOT exist."
    fi
    
    # Check 2: Arkenfox content in user.js
    # We look for "arkenfox" or "user_pref" generally if generic, but Arkenfox usually mentions it.
    if grep -i -q "arkenfox" "$profile_path/user.js" 2>/dev/null; then
         info "[PASS] user.js contains Arkenfox signatures."
    else
         warn "[FAIL] user.js does NOT appear to be based on Arkenfox."
    fi
    
    # Check 3: Active Preference (prefs.js)
    # privacy.resistFingerprinting is a hallmark of hardening.
    # Note: prefs.js is written by Firefox, usually user_pref("key", value);
    # Using grep -E to allow for variable whitespace
    if grep -E -q "user_pref\(\"privacy.resistFingerprinting\",[[:space:]]*true\);" "$profile_path/prefs.js" 2>/dev/null; then
         info "[PASS] privacy.resistFingerprinting is ENABLED in prefs.js."
    else
         warn "[FAIL] privacy.resistFingerprinting is NOT enabled in prefs.js."
         warn "If you just ran the hardening script, please RESTART Firefox for changes to apply."
    fi
}

install_tor_browser() {
    install_app_with_docs "Tor Browser" "tor-browser" "Tor Browser.app" "docs/TOR.md"
}

install_onionshare() {
    install_app_with_docs "OnionShare" "onionshare" "OnionShare.app" ""
}

install_telegram() {
    install_app_with_docs "Telegram" "telegram" "Telegram.app" "docs/MESSENGERS.md"
}

install_session() {
    install_app_with_docs "Session (Private Messenger)" "session" "Session.app" "docs/MESSENGERS.md"
}







