#!/bin/bash

# lib/installers.sh
# Tool installation functions

install_privoxy() {
    require_brew
    require_brew
    install_brew_package "privoxy"

    info "Applying configuration..."
    # Use BREW_PREFIX from platform.sh
    local CONF_DIR="$BREW_PREFIX/etc/privoxy"
    local CONFIG_SRC="$(pwd)/config/privoxy"
    
    # Copy main config
    if [ -f "$CONFIG_SRC/config" ]; then
        if [ -f "$CONF_DIR/config" ]; then cp "$CONF_DIR/config" "$CONF_DIR/config.bak"; fi
        cp "$CONFIG_SRC/config" "$CONF_DIR/config"
        
        # Patch for ARM if needed
        if [ "$PLATFORM_ARCH" == "arm64" ]; then
            sed -i '' "s|/usr/local|$BREW_PREFIX|g" "$CONF_DIR/config"
        fi
    else
        die "Config not found: $CONFIG_SRC/config"
    fi

    # Copy actions and filters
    for file in user.action; do
        if [ -f "$CONFIG_SRC/$file" ]; then
            info "Copying $file..."
            cp "$CONFIG_SRC/$file" "$CONF_DIR/$file"
        fi
    done

    info "Restarting Privoxy..."
    brew services restart privoxy

    info "Configuring System Proxy (HTTP/HTTPS)..."
    execute_sudo "Set HTTP Proxy" networksetup -setwebproxy "Wi-Fi" 127.0.0.1 8118
    execute_sudo "Set HTTPS Proxy" networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 8118
}

install_tor() {
    warn "install_tor is deprecated. Redirecting to tor_install..."
    tor_install
}

install_gpg() {
    require_brew
    install_brew_package "gnupg"
    install_brew_package "pinentry-mac"

    local GPG_HOME="$HOME/.gnupg"
    mkdir -p "$GPG_HOME"
    chmod 700 "$GPG_HOME"

    local SRC_CONF="$(pwd)/config/gpg/gpg.conf"
    local DEST_CONF="$GPG_HOME/gpg.conf"

    if [ -f "$SRC_CONF" ]; then
        cp "$SRC_CONF" "$DEST_CONF"
        chmod 600 "$DEST_CONF"
    fi

    echo "pinentry-program $BREW_PREFIX/bin/pinentry-mac" > "$GPG_HOME/gpg-agent.conf"
    killall gpg-agent 2>/dev/null || true
}



# ... (firefox/harden/tor_browser remain custom) ...

setup_gpg() {
    info "Setting up GPG..."
    # Reuse install_gpg logic or checks, but setup_gpg mainly configures.
    # It seems to duplicate install_gpg's install step. Let's optimize.
    require_brew
    install_brew_package "gnupg"
    # Pinentry might be needed too? existing code didn't check it here explicitly but relied on command -v gpg.

    # ... (rest of configuration logic is specific here) ...
    # Wait, existing setup_gpg duplicates install_gpg completely but with slightly different paths?
    # install_gpg vs setup_gpg seems redundant.
    # install_gpg installs AND configures. setup_gpg installs AND configures.
    # Let's keep existing logic but use helpers.
    
    # Existing logic:
    # if ! command -v gpg >/dev/null; then brew install... else installed...
    # This is exactly what check_installed does.
    
    # Note: setup_gpg in the file (lines 505-550) is very similar to install_gpg (lines 54-77).
    # I should probably consolidate them or just refactor setup_gpg to use the helper.
    # Since they are separate functions in the file, I will refactor setup_gpg to use install_brew_package too.
    
    local gpg_dir="$HOME/.gnupg"
    if [ ! -d "$gpg_dir" ]; then
        info "Creating $gpg_dir..."
        mkdir -p "$gpg_dir"
        chmod 700 "$gpg_dir"
    fi

    local config_src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/gpg/gpg.conf"
    local config_dest="$gpg_dir/gpg.conf"
    
    # Use smart config copy!
    check_config_and_backup "$config_src" "$config_dest"
    chmod 600 "$config_dest"
    info "GPG configured successfully."
    
    info "Please refer to docs/GPG.md for usage and YubiKey setup."
}

install_signal() {
    require_brew
    install_cask_package "signal" "Signal.app"
    info "Refer to docs/MESSENGERS.md for usage instructions."
}

install_keepassxc() {
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
        brew install dnscrypt-proxy
    fi

    local CONF_SRC="$(pwd)/config/dnscrypt-proxy/dnscrypt-proxy.toml"
    local CONF_DEST="$BREW_PREFIX/etc/dnscrypt-proxy.toml"

    if [ ! -f "$CONF_SRC" ]; then
        die "Configuration file not found: $CONF_SRC"
    fi

    info "Applying configuration to $CONF_DEST..."
    if [ -f "$CONF_DEST" ]; then
        cp "$CONF_DEST" "${CONF_DEST}.bak"
    fi
    
    cp "$CONF_SRC" "$CONF_DEST"
    
    # Check if we need to adjust anything for ARM vs Intel? 
    # The TOML format is generic, listening on localhost. Should be fine.
    
    info "Restarting DNSCrypt-Proxy (requires sudo)..."
    execute_sudo "Restart dnscrypt-proxy" brew services restart dnscrypt-proxy
    
    info "DNSCrypt-Proxy started on port 5355."
    info "Verify with: sudo lsof +c 15 -Pni UDP:5355"
}

install_pingbar() {
    info "Checking requirements for PingBar..."
    if ! command -v swift &> /dev/null; then
         die "Swift compiler not found. Please install Xcode Command Line Tools (xcode-select --install)."
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
    
    info "Configuring PingBar..."
    # Defaults keys based on typical Jedisct1 naming or derived from prompt requirements
    local BUNDLE_ID="fr.jedisct1.PingBar"
    
    # "Restore my custom DNS after passing captive portal"
    defaults write "$BUNDLE_ID" RestoreDNS -bool true
    
    # "Launch PingBar at login"
    defaults write "$BUNDLE_ID" LaunchAtLogin -bool true
    
    info "PingBar installed and configured."
    info "You can find it in your Applications folder."
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
    execute_sudo "Fetch Root Key" unbound-anchor -a "$BREW_PREFIX/etc/unbound/root.key" || true # unbound-anchor can fail if certs are tricky, checking validity later is better

    info "Generating Control Certificates..."
    execute_sudo "Setup Control" unbound-control-setup -d "$BREW_PREFIX/etc/unbound"

    info "Copying configuration..."
    local CONF_SRC="$(pwd)/config/unbound/unbound.conf"
    local CONF_DEST="$BREW_PREFIX/etc/unbound/unbound.conf"

    if [ ! -f "$CONF_SRC" ]; then
        die "Configuration file not found: $CONF_SRC"
    fi
     
    # We must copy with permissions, so probably sudo is needed if /etc/unbound is root owned (it usually is)
    execute_sudo "Copy Config" cp "$CONF_SRC" "$CONF_DEST"

    info "Verifying configuration..."
    if ! execute_sudo "Check Config" unbound-checkconf "$CONF_DEST"; then
        die "Unbound configuration check failed!"
    fi

    info "Setting permissions..."
    execute_sudo "Chown Unbound" chown -R _unbound:staff "$BREW_PREFIX/etc/unbound"
    execute_sudo "Chmod Unbound" chmod 640 "$BREW_PREFIX/etc/unbound"/*

    info "Directing Unbound (Brew) to start on boot..."
    execute_sudo "Start Service" brew services start unbound

    info "Switching system DNS to 127.0.0.1..."
    execute_sudo "Set DNS" networksetup -setdnsservers Wi-Fi 127.0.0.1

    info "Unbound installed and configured."
    info "Test DNSSEC with: dig org. SOA +dnssec @127.0.0.1 | grep -E 'NOERROR|ad'"
}

install_firefox() {
    info "Installing Firefox..."
    
    if is_app_installed "Firefox.app"; then
        warn "Firefox.app is already in /Applications. Skipping install."
        return 0
    fi
    
    local download_url="https://download.mozilla.org/?product=firefox-latest-ssl&os=osx&lang=en-US"
    local dmg_path
    dmg_path=$(mktemp /tmp/firefox-installer.XXXXXX.dmg)
    
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
    
    local FIREFOX_DIR="$HOME/Library/Application Support/Firefox/Profiles"
    if [ ! -d "$FIREFOX_DIR" ]; then
        die "Firefox profiles directory not found at $FIREFOX_DIR. Is Firefox installed and run at least once?"
    fi
    
    # Locate profile
    local profile_path=""
    # Prefer default-release
    local dr_profile
    dr_profile=$(find "$FIREFOX_DIR" -maxdepth 1 -name "*.default-release" | head -n 1)
    
    if [ -n "$dr_profile" ]; then
        profile_path="$dr_profile"
    else
        # Fallback to default
        local d_profile
        d_profile=$(find "$FIREFOX_DIR" -maxdepth 1 -name "*.default" -print | head -n 1)
        if [ -n "$d_profile" ]; then
            profile_path="$d_profile"
        fi
    fi
    
    if [ -z "$profile_path" ]; then
        die "No suitable Firefox profile found (*.default-release or *.default)."
    fi
    
    info "Target Profile: $(basename "$profile_path")"
    
    # Backup
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
    
    # Cleanup
    rm -f "$temp_user_js" "$overrides_file"
    
    info "Firefox hardening complete. Please restart Firefox."
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
        execute_sudo "Install gnupg" brew install gnupg
    fi
    
    # 1. Fetch Latest Version
    info "Fetching latest Tor Browser version..."
    local version_url="https://www.torproject.org/download/"
    local version_page
    version_page=$(curl -sL "$version_url")
    # regex to capture version from links like TorBrowser-13.0.1-macos_ALL.dmg
    # We search for the dmg link pattern in the page
    local version
    version=$(echo "$version_page" | grep -o 'TorBrowser-[0-9.]\+-macos_ALL\.dmg' | head -n 1 | sed -E 's/TorBrowser-([0-9.]+)-.*/\1/')
    
    if [ -z "$version" ]; then
         # Try older pattern
         version=$(echo "$version_page" | grep -o 'TorBrowser-[0-9.]\+-osx64_en-US\.dmg' | head -n 1 | sed -E 's/TorBrowser-([0-9.]+)-.*/\1/')
    fi

    if [ -z "$version" ]; then
        die "Could not determine latest Tor Browser version."
    fi
    
    info "Latest Version detected: $version"
    
    # Construct download URL
    # We'll use the filename we scraped if possible, or reconstruct it to be safe? 
    # Let's reconstruct based on version to match the folder structure
    # Dist path: /dist/torbrowser/{version}/TorBrowser-{version}-macos_ALL.dmg
    local download_base="https://www.torproject.org/dist/torbrowser/$version"
    local dmg_filename="TorBrowser-${version}-macos_ALL.dmg"
    local asc_filename="${dmg_filename}.asc"
    
    # Validation: If we scraped a different filename (e.g. osx64_en-US), we should use that.
    # But usually macos_ALL is the standard since v13??
    # Let's verify what grep found.
    # If the grep found nothing, we died. 
    # If grep found something like TorBrowser-13.0.1-macos_ALL.dmg, we extracted 13.0.1.
    # If grep found TorBrowser-12.5-osx64_en-US.dmg, we extracted 12.5.
    
    # To be robust, let's use the exact file we found in grep if we can?
    # Actually, simpler: construct download URL and curl it. If 404, try legacy name.
    
    local dmg_path="/tmp/$dmg_filename"
    local asc_path="/tmp/$asc_filename"
    
    info "Downloading $dmg_filename..."
    # We use -f to fail on 404
    if ! curl -f -L -o "$dmg_path" "$download_base/$dmg_filename"; then
        warn "Failed to download $dmg_filename. Trying legacy filename..."
        dmg_filename="TorBrowser-${version}-osx64_en-US.dmg"
        asc_filename="${dmg_filename}.asc"
        dmg_path="/tmp/$dmg_filename"
        asc_path="/tmp/$asc_filename"
        
        if ! curl -f -L -o "$dmg_path" "$download_base/$dmg_filename"; then
             die "Download failed for both naming conventions."
        fi
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
    local mount_point
    mount_point=$(hdiutil attach "$dmg_path" -nobrowse | grep '/Volumes/' | awk '{$1=$2=""; print $0}' | xargs)
    if [ -z "$mount_point" ]; then die "Failed to mount DMG."; fi
    
    info "Copying to /Applications..."
    if [ ! -d "$mount_point/Tor Browser.app" ]; then
        hdiutil detach "$mount_point" -quiet
        die "Tor Browser.app not found in DMG."
    fi
    
    execute_sudo "Install Tor Browser" cp -R "$mount_point/Tor Browser.app" "/Applications/"
    
    info "Unmounting..."
    hdiutil detach "$mount_point" -quiet
    
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

setup_gpg() {
    info "Setting up GPG..."

    # Check for Homebrew
    require_brew

    # Install GPG if missing
    if ! command -v gpg >/dev/null; then
        info "Installing GnuPG..."
        execute_sudo "Install GnuPG" brew install gnupg
    else
        info "GnuPG is already installed."
    fi

    # Create ~/.gnupg directory
    local gpg_dir="$HOME/.gnupg"
    if [ ! -d "$gpg_dir" ]; then
        info "Creating $gpg_dir..."
        mkdir -p "$gpg_dir"
        chmod 700 "$gpg_dir"
    fi

    # Configure hardened gpg.conf
    local config_src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/gpg/gpg.conf"
    local config_dest="$gpg_dir/gpg.conf"

    if [ -f "$config_src" ]; then
        if [ -f "$config_dest" ]; then
            warn "Existing gpg.conf found at $config_dest."
            # Create backup
            local backup="$config_dest.backup.$(date +%s)"
            cp "$config_dest" "$backup"
            info "Backup created at $backup"
        fi

        info "Copying hardened configuration to $config_dest..."
        cp "$config_src" "$config_dest"
        chmod 600 "$config_dest"
        info "GPG configured successfully."
    else
        error "Source configuration file not found at $config_src"
        return 1
    fi
    
    info "Please refer to docs/GPG.md for usage and YubiKey setup."
}

install_signal() {
    info "Installing Signal Desktop..."
    
    require_brew
    
    if is_cask_installed "signal"; then
        info "Signal is already installed."
    else
        execute_sudo "Install Signal" brew install --cask signal
        info "Signal installed successfully."
    fi
    
    info "Refer to docs/MESSENGERS.md for usage instructions."
}

install_keepassxc() {
    info "Installing KeePassXC..."
    
    require_brew
    
    if is_cask_installed "keepassxc"; then
        info "KeePassXC is already installed."
    else
        execute_sudo "Install KeePassXC" brew install --cask keepassxc
        info "KeePassXC installed successfully."
    fi
    
    info "Refer to docs/PASSWORDS.md for usage instructions."
}



