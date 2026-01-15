#!/bin/bash

# lib/installers.sh
# Tool installation functions

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
            sed -i '' "s|/usr/local|$BREW_PREFIX|g" "$TEMP_CONFIG"
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
    for file in user.action; do
        if [ -f "$CONFIG_SRC/$file" ]; then
            if ! cmp -s "$CONFIG_SRC/$file" "$CONF_DIR/$file"; then
                info "Updating $file..."
                cp "$CONFIG_SRC/$file" "$CONF_DIR/$file"
                RESTART_NEEDED="true"
            fi
        fi
    done

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
    local DO_HTTP="false"
    local DO_HTTPS="false"
    
    local HTTP_PROXY=$(networksetup -getwebproxy "Wi-Fi")
    if ! echo "$HTTP_PROXY" | grep -q "Enabled: Yes" || ! echo "$HTTP_PROXY" | grep -q "Server: 127.0.0.1" || ! echo "$HTTP_PROXY" | grep -q "Port: 8118"; then
        DO_HTTP="true"
    fi
    
    local HTTPS_PROXY=$(networksetup -getsecurewebproxy "Wi-Fi")
    if ! echo "$HTTPS_PROXY" | grep -q "Enabled: Yes" || ! echo "$HTTPS_PROXY" | grep -q "Server: 127.0.0.1" || ! echo "$HTTPS_PROXY" | grep -q "Port: 8118"; then
        DO_HTTPS="true"
    fi

    if [ "$DO_HTTP" == "true" ]; then
        execute_sudo "Set HTTP Proxy" networksetup -setwebproxy "Wi-Fi" 127.0.0.1 8118
    else
        info "HTTP Proxy already set correctly."
    fi
    
    if [ "$DO_HTTPS" == "true" ]; then
        execute_sudo "Set HTTPS Proxy" networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 8118
    else
        info "HTTPS Proxy already set correctly."
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
    info "Installing Signal Desktop..."
    require_brew
    install_cask_package "signal" "Signal.app"
    info "Refer to docs/MESSENGERS.md for usage instructions."
}

install_keepassxc() {
    info "Installing KeePassXC..."
    require_brew
    install_cask_package "keepassxc" "KeePassXC.app"
    info "Refer to docs/PASSWORDS.md for usage instructions."
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
    
    # Check if running
    local is_running=false
    # User requested sudo check for brew services
    if execute_sudo "Check if running" brew services list | grep "dnscrypt-proxy" | grep -q "started"; then
        is_running=true
    elif pgrep -x "dnscrypt-proxy" >/dev/null; then
        is_running=true
    fi

    if [ "$config_changed" = true ] || [ "$is_running" = false ]; then
        info "Restarting DNSCrypt-Proxy (requires sudo)..."
        execute_sudo "Restart dnscrypt-proxy" brew services restart dnscrypt-proxy
    else
        info "DNSCrypt-Proxy is already running with latest config. Skipping restart."
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
        sed -i '' "s|/usr/local|$BREW_PREFIX|g" "$TEMP_CONF"
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

    # Check if running
    local is_running=false
    if execute_sudo "Check if running" brew services list | grep "unbound" | grep -q "started"; then
        is_running=true
    elif pgrep -x "unbound" >/dev/null; then
        is_running=true
    fi

    info "Directing Unbound (Brew) to start on boot..."
    if [ "$config_changed" = true ] || [ "$is_running" = false ]; then
        info "Restarting Unbound (requires sudo)..."
        execute_sudo "Start Unbound" brew services restart unbound
    else
        info "Unbound is already running with latest config. Skipping restart."
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
    info "Installing Firefox..."
    
    if is_app_installed "Firefox.app"; then
        warn "Firefox.app is already in /Applications. Skipping install."
        return 0
    fi
    
    local download_url="https://download.mozilla.org/?product=firefox-latest-ssl&os=osx&lang=en-US"
    local dmg_path
    dmg_path=$(mktemp /tmp/firefox-installer.XXXXXX)
    
    info "Downloading Firefox (dmg)..."
    if ! curl -L -o "$dmg_path" "$download_url"; then
        rm -f "$dmg_path"
        die "Download failed."
    fi
    
    info "Mounting DMG..."
    # Attach and parse the mount point. 
    # expected output: /dev/diskXsY ... /Volumes/Firefox
    local mount_point
    # We use -nobrowse to prevent Finder window, -noverify to speed up if trusted (but verification ensures integrity). 
    # Let's keep verification default for security.
    mount_point=$(hdiutil attach "$dmg_path" -nobrowse | grep '/Volumes/' | awk '{$1=$2=""; print $0}' | xargs)
    
    if [ -z "$mount_point" ]; then
         rm -f "$dmg_path"
         die "Failed to mount DMG."
    fi
    
    info "Mounted at: $mount_point"
    
    if [ ! -d "$mount_point/Firefox.app" ]; then
         hdiutil detach "$mount_point" -quiet
         rm -f "$dmg_path"
         die "Firefox.app not found in DMG."
    fi
    
    info "Copying Firefox to /Applications..."
    # sudo might be needed if user doesn't own /Applications, but usually admin user does or prompt happens?
    # Better to use sudo to be safe on standard user accounts or hardened systems.
    if ! execute_sudo "Install Firefox" cp -R "$mount_point/Firefox.app" "/Applications/Firefox.app"; then
         error "Failed to copy Firefox."
         hdiutil detach "$mount_point" -quiet
         rm -f "$dmg_path"
         return 1
    fi
    
    info "Unmounting DMG..."
    hdiutil detach "$mount_point" -quiet
    rm -f "$dmg_path"
    
    info "Verifying Code Signature..."
    if codesign -dv --verbose=4 "/Applications/Firefox.app" 2>&1 | grep -q "Mozilla Corporation"; then
        info "[PASS] Firefox signature verified (Mozilla Corporation)."
    else
        warn "[FAIL] Firefox signature verification FAILED or mismatch."
        # We don't uninstall automatically to avoid data loss if it's just a check fail, but warn loudly.
    fi
    
    info "Firefox installed successfully."
}

harden_firefox() {
    info "Hardening Firefox (Arkenfox)..."
    
    local profile_path
    if ! profile_path=$(get_firefox_profile); then
        die "Firefox profiles directory not found or no suitable profile found. Is Firefox installed and run at least once?"
    fi
    
    info "Target Profile: $(basename "$profile_path")"
    
    # Idempotency Check
    if [ -f "$profile_path/user.js" ]; then
        if grep -i -q "arkenfox" "$profile_path/user.js" 2>/dev/null; then
            info "Arkenfox user.js verified present. Skipping download."
            verify_firefox
            return 0
        fi
        info "Existing user.js found but does not appear to be Arkenfox. Overwriting..."
        # Backup existing non-arkenfox user.js
        cp "$profile_path/user.js" "$profile_path/user.js.backup.$(date +%Y%m%d%H%M%S)"
    fi
    
    # Backup prefs.js logic remains...
    info "Backing up prefs.js..."
    if [ -f "$profile_path/prefs.js" ]; then
        cp "$profile_path/prefs.js" "$profile_path/prefs.js.backup.$(date +%Y%m%d%H%M%S)"
    else
        warn "prefs.js not found, nothing to backup."
    fi
    
    # Download user.js
    local arkenfox_url="https://raw.githubusercontent.com/arkenfox/user.js/master/user.js"
    local temp_user_js="/tmp/arkenfox_user.js"
    
    info "Downloading Arkenfox user.js..."
    if ! curl -L -o "$temp_user_js" "$arkenfox_url"; then
        die "Failed to download user.js"
    fi
    
    # Create simple overrides (optional, can be empty or have defaults)
    local overrides_file="/tmp/user-overrides.js"
    echo "// Custom Overrides for Better Anonymity" > "$overrides_file"
    echo "// user_pref(\"browser.startup.page\", 3); // 3 = Restore previous session" >> "$overrides_file"
    
    # Append overrides to user.js
    info "Applying configuration..."
    cat "$overrides_file" >> "$temp_user_js"
    
    # Install
    cp "$temp_user_js" "$profile_path/user.js"
    
    # Log for restore
    local state_dir="$HOME/.better-anonymity/state"
    mkdir -p "$state_dir"
    echo "$profile_path/user.js" >> "$state_dir/installed_files.log"
    echo "$profile_path/prefs.js.backup.*" >> "$state_dir/installed_files.log" # Wildcard to flag manual cleanup or just best effort
    
    # Cleanup
    rm -f "$temp_user_js" "$overrides_file"
    
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
    info "Installing Tor Browser..."
    
    if is_app_installed "Tor Browser.app"; then
        warn "Tor Browser.app is already in /Applications. Skipping install."
        return 0
    fi
    
    # Check for GPG
    if ! command -v gpg >/dev/null; then
        warn "GPG is not installed. Attempting to install via brew..."
        require_brew
        brew install gnupg
    fi
    
    # 1. Fetch Latest Version
    info "Fetching latest Tor Browser version..."
    local version_url="https://www.torproject.org/download/"
    local version_page
    version_page=$(curl -sL "$version_url")
    
    # regex for new format: tor-browser-macos-15.0.3.dmg
    local version
    local filename_format="new"
    
    # Use -Eo for extended regex (support +) and only output matching
    version=$(echo "$version_page" | grep -Eo 'tor-browser-macos-[0-9.]+\.dmg' | head -n 1 | sed -E 's/tor-browser-macos-([0-9.]+)\.dmg/\1/')
    
    if [ -z "$version" ]; then
         # Try old format: TorBrowser-13.0.1-macos_ALL.dmg
         version=$(echo "$version_page" | grep -Eo 'TorBrowser-[0-9.]+-macos_ALL\.dmg' | head -n 1 | sed -E 's/TorBrowser-([0-9.]+)-.*/\1/')
         filename_format="legacy_all"
    fi
    
    if [ -z "$version" ]; then
         # Try older legacy: TorBrowser-12.5-osx64_en-US.dmg
         version=$(echo "$version_page" | grep -Eo 'TorBrowser-[0-9.]+-osx64_en-US\.dmg' | head -n 1 | sed -E 's/TorBrowser-([0-9.]+)-.*/\1/')
         filename_format="legacy_osx"
    fi

    if [ -z "$version" ]; then
        die "Could not determine latest Tor Browser version."
    fi
    
    info "Latest Version detected: $version"
    
    # Construct download URL
    local download_base="https://www.torproject.org/dist/torbrowser/$version"
    local dmg_filename
    
    if [ "$filename_format" == "new" ]; then
        dmg_filename="tor-browser-macos-${version}.dmg"
    elif [ "$filename_format" == "legacy_all" ]; then
        dmg_filename="TorBrowser-${version}-macos_ALL.dmg"
    else
        dmg_filename="TorBrowser-${version}-osx64_en-US.dmg"
    fi
    
    local asc_filename="${dmg_filename}.asc"
    
    local dmg_path="/tmp/$dmg_filename"
    local asc_path="/tmp/$asc_filename"
    
    info "Downloading $dmg_filename..."
    # We use -f to fail on 404
    if ! curl -f -L -o "$dmg_path" "$download_base/$dmg_filename"; then
        warn "Failed to download $dmg_filename. Trying alternatives..."
        
        # Fallback Logic if format detection was wrong or mismatch
        if [ "$filename_format" == "new" ]; then
             dmg_filename="TorBrowser-${version}-macos_ALL.dmg"
        else
             dmg_filename="tor-browser-macos-${version}.dmg"
        fi
        
        if ! curl -f -L -o "$dmg_path" "$download_base/$dmg_filename"; then
             die "Download failed."
        fi
        # Update filename for signature
        asc_filename="${dmg_filename}.asc"
        asc_path="/tmp/$asc_filename"
    fi
    
    info "Downloading signature..."
    if ! curl -f -L -o "$asc_path" "$download_base/$asc_filename"; then
        die "Signature download failed."
    fi
    
    # 2. Verify GPG
    info "Verifying PGP Signature..."
    local tor_key_id="0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290"
    
    # Import key if not present
    if ! gpg --list-keys "$tor_key_id" > /dev/null 2>&1; then
        info "Importing Tor Browser Developers key ($tor_key_id)..."
        if ! gpg --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org; then
             gpg --keyserver keys.openpgp.org --recv-keys "$tor_key_id" || \
             gpg --keyserver keyserver.ubuntu.com --recv-keys "$tor_key_id" || \
             die "Failed to import Tor signing key."
        fi
    fi
    
    if gpg --verify "$asc_path" "$dmg_path" 2>&1 | grep -q "Good signature"; then
        info "[PASS] PGP Signature Verified."
    else
        die "PGP Signature Verification FAILED! The file may be corrupted or tampered with."
    fi
    
    # 3. Install (Mount & Copy)
    info "Mounting DMG..."
    local mount_point="/tmp/Tor_Browser_Mount_$$"
    mkdir -p "$mount_point"
    
    # -nobrowse: don't show in Finder
    # -mountpoint: verify where it goes
    # -noverify: skip verification for speed (we already checked GPG signature)
    # -noautoopen: don't open window
    if ! hdiutil attach "$dmg_path" -mountpoint "$mount_point" -nobrowse -noverify -noautoopen -quiet; then
         rmdir "$mount_point"
         die "Failed to mount DMG."
    fi
    
    info "Copying to /Applications..."
    if [ ! -d "$mount_point/Tor Browser.app" ]; then
        hdiutil detach "$mount_point" -quiet
        rmdir "$mount_point"
        die "Tor Browser.app not found in DMG."
    fi
    
    execute_sudo "Install Tor Browser" cp -R "$mount_point/Tor Browser.app" "/Applications/"
    
    info "Unmounting..."
    hdiutil detach "$mount_point" -quiet
    rmdir "$mount_point"
    
    # 4. Code Signature Check
    info "Verifying Code Signature (Apple Developer ID)..."
    local app_path="/Applications/Tor Browser.app"
    
    # Check explicit ID: The Tor Project, Inc (MADPSAYN6T)
    if codesign -dv --verbose=4 "$app_path" 2>&1 | grep -q "MADPSAYN6T"; then
        info "[PASS] Code Signature matches The Tor Project (MADPSAYN6T)."
    else
        warn "[FAIL] Code Signature mismatch or verification failed."
    fi
    
    # Cleanup
    rm -f "$dmg_path" "$asc_path"
    
    info "Tor Browser successfully installed."
    info "See docs/TOR.md for instructions on configuring Pluggable Transports."
}







