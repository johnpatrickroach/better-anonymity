#!/bin/bash

# lib/macos_hardening.sh
# macOS hardening functions

hardening_update_system() {
    info "Checking for system software updates..."
    # dry run or interactive check could go here
    softwareupdate --list
}



hardening_enable_firewall() {
    info "Enabling Firewall..."
    execute_sudo "Enable socketfilterfw" "$SOCKETFILTERFW_CMD" --setglobalstate on
    execute_sudo "Enable logging" "$SOCKETFILTERFW_CMD" --setloggingmode on
    # Capture output to check for errors/status
    local output
    output=$(execute_sudo "Enable stealth mode" "$SOCKETFILTERFW_CMD" --setstealthmode on 2>&1)
    echo "$output" # Show to user

    if echo "$output" | grep -q "managed Mac"; then
        warn "Firewall settings are managed by an MDM profile. Skipping Stealth Mode enforcement."
        return 0
    fi
    
    # Verify and Retry
    local stealth_retries=0
    while ! "$SOCKETFILTERFW_CMD" --getstealthmode | grep -E -q "enabled|on"; do
        if [ "$stealth_retries" -ge 3 ]; then
            warn "Could not enable Stealth Mode after 3 attempts."
            break
        fi
        warn "Stealth Mode failed to enable. Retrying ($((stealth_retries+1))/3)..."
        sleep 1
        output=$(execute_sudo "Retry Stealth Mode" "$SOCKETFILTERFW_CMD" --setstealthmode on 2>&1)
        echo "$output"
        
        if echo "$output" | grep -q "managed Mac"; then
             warn "Firewall settings are managed by an MDM profile. Skipping Stealth Mode enforcement."
             break
        fi

        stealth_retries=$((stealth_retries + 1))
    done

    execute_sudo "Disable allow signed" "$SOCKETFILTERFW_CMD" --setallowsigned off
    execute_sudo "Disable allow signed app" "$SOCKETFILTERFW_CMD" --setallowsignedapp off
    execute_sudo "Reload Firewall" pkill -HUP socketfilterfw
}

hardening_disable_analytics() {
    info "Disabling Analytics and Crash Reports..."
    execute_sudo "Unload DIAG info" launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist 2>/dev/null || true
    execute_sudo "Disable AutoSubmit" defaults write /Library/Preferences/com.apple.loginwindow AutoSubmit -bool false
    defaults write com.apple.assistant.support "Siri Data Sharing Opt-In Status" -int 2
    defaults write com.apple.CrashReporter DialogType none
    
    # Ad Tracking (Privacy.sexy)
    info "Disabling Ad Tracking..."
    if [ "$(defaults read com.apple.AdLib allowIdentifierForAdvertising 2>/dev/null)" != "0" ]; then
        defaults write com.apple.AdLib allowIdentifierForAdvertising -bool false
    fi
     if [ "$(defaults read com.apple.AdLib allowApplePersonalizedAdvertising 2>/dev/null)" != "0" ]; then
        defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false
    fi
     if [ "$(defaults read com.apple.AdLib forceLimitAdTracking 2>/dev/null)" != "1" ]; then
        defaults write com.apple.AdLib forceLimitAdTracking -bool true
    fi

    # Firefox Telemetry
    if [ -d "/Applications/Firefox.app" ]; then
        info "Disabling Firefox Telemetry..."
         if [ "$(defaults read /Library/Preferences/org.mozilla.firefox EnterprisePoliciesEnabled 2>/dev/null)" != "1" ]; then
            execute_sudo "Enable Firefox Policies" defaults write /Library/Preferences/org.mozilla.firefox EnterprisePoliciesEnabled -bool TRUE
        fi
         if [ "$(defaults read /Library/Preferences/org.mozilla.firefox DisableTelemetry 2>/dev/null)" != "1" ]; then
            execute_sudo "Disable Firefox Telemetry" defaults write /Library/Preferences/org.mozilla.firefox DisableTelemetry -bool TRUE
        fi
    fi
    
    # Other App Telemetry
    hardening_disable_app_telemetry
}

    hardening_disable_app_telemetry() {
    info "Disabling Third-Party App Telemetry..."
    
    hardening_disable_parallels
    
    # Google (Aggressive)
    if [ "$(defaults read com.google.Keystone.Agent checkInterval 2>/dev/null)" != "0" ]; then
        defaults write com.google.Keystone.Agent checkInterval 0 2>/dev/null || true
    fi
    # Delete Google Software Update agent if aggressive (Privacy.sexy does this)
    if [ -d "$HOME/Library/Google/GoogleSoftwareUpdate" ]; then
         info "Disabling Google Software Update..."
         rm -rf "$HOME/Library/Google/GoogleSoftwareUpdate" 2>/dev/null || true
    fi
    
    # Microsoft Office / AutoUpdate
    if [ "$(defaults read com.microsoft.autoupdate2 HowToCheck 2>/dev/null)" != "Manual" ]; then
        defaults write com.microsoft.autoupdate2 HowToCheck -string "Manual" 2>/dev/null || true
    fi
    if [ "$(defaults read com.microsoft.office.telemetry SendAllTelemetryEnabled 2>/dev/null)" != "0" ]; then
        defaults write com.microsoft.office.telemetry SendAllTelemetryEnabled -bool false 2>/dev/null || true
    fi
    # Stricter Office
    # Stricter Office
    if [ "$(defaults read com.microsoft.office.telemetry ZeroDiagnosticData -bool 2>/dev/null)" != "1" ]; then
        defaults write com.microsoft.office.telemetry ZeroDiagnosticData -bool true 2>/dev/null || true
    fi
     if [ "$(defaults read com.microsoft.office.telemetry UserOptIn -bool 2>/dev/null)" != "0" ]; then
        defaults write com.microsoft.office.telemetry UserOptIn -bool false 2>/dev/null || true
    fi

    
    # .NET / PowerShell
    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export POWERSHELL_TELEMETRY_OPTOUT=1
    # Persistence
    local zshrc="$HOME/.zshrc"
    if ! grep -q "DOTNET_CLI_TELEMETRY_OPTOUT" "$zshrc"; then echo "export DOTNET_CLI_TELEMETRY_OPTOUT=1" >> "$zshrc"; fi
    if ! grep -q "POWERSHELL_TELEMETRY_OPTOUT" "$zshrc"; then echo "export POWERSHELL_TELEMETRY_OPTOUT=1" >> "$zshrc"; fi
}

hardening_disable_parallels() {
    # Parallels Desktop Ads & Updates
    if [ -d "/Applications/Parallels Desktop.app" ]; then
        info "Disabling Parallels Desktop Ads/Updates..."
        defaults write com.parallels.Parallels\ Desktop ApplicationPreferences.CheckForUpdates -bool false 2>/dev/null || true
        defaults write com.parallels.Parallels\ Desktop "ApplicationPreferences.ShowPromo" -bool false 2>/dev/null || true
        defaults write com.parallels.Parallels\ Desktop "ApplicationPreferences.ShowTutorial" -bool false 2>/dev/null || true
    fi
}


hardening_configure_privacy() {
    info "Configuring Spotlight and Privacy..."
    # Disable Spotlight suggestions
    defaults write com.apple.spotlight orderedItems -array \
        '{"enabled" = 1;"name" = "APPLICATIONS";}' \
        '{"enabled" = 1;"name" = "SYSTEM_PREFS";}' \
        '{"enabled" = 1;"name" = "DIRECTORIES";}' \
        '{"enabled" = 1;"name" = "PDF";}' \
        '{"enabled" = 1;"name" = "FONTS";}' \
        '{"enabled" = 0;"name" = "DOCUMENTS";}' \
        '{"enabled" = 0;"name" = "MESSAGES";}' \
        '{"enabled" = 0;"name" = "CONTACTS";}' \
        '{"enabled" = 0;"name" = "EVENT_TODO";}' \
        '{"enabled" = 0;"name" = "IMAGES";}' \
        '{"enabled" = 0;"name" = "BOOKMARKS";}' \
        '{"enabled" = 0;"name" = "MUSIC";}' \
        '{"enabled" = 0;"name" = "MOVIES";}' \
        '{"enabled" = 0;"name" = "PRESENTATIONS";}' \
        '{"enabled" = 0;"name" = "SPREADSHEETS";}' \
        '{"enabled" = 0;"name" = "SOURCE";}' \
        '{"enabled" = 0;"name" = "MENU_DEFINITION";}' \
        '{"enabled" = 0;"name" = "MENU_OTHER";}' \
        '{"enabled" = 0;"name" = "MENU_CONVERSION";}' \
        '{"enabled" = 0;"name" = "MENU_EXPRESSION";}' \
        '{"enabled" = 0;"name" = "WEB_VIDEO";}' \
        '{"enabled" = 0;"name" = "MENU_SPOTLIGHT_SUGGESTIONS";}'
    
    killall mds > /dev/null 2>&1 || true
    execute_sudo "Re-enable indexing" mdutil -i on / > /dev/null
    
    # Remote Apple Events
    info "Disabling Remote Apple Events..."
    execute_sudo "Disable Remote Events" systemsetup -setremoteappleevents off 2>/dev/null || true

    # Remote Login (SSH)
    hardening_disable_remote_login

    # Privacy Tweaks
    hardening_privacy_tweaks
}

hardening_disable_remote_login() {
    # Check if currently on
    if systemsetup -getremotelogin 2>/dev/null | grep -i "On"; then
        warn "Remote Login (SSH) is currently ENABLED."
        if ask_confirmation "Disable Remote Login (SSH) to reduce attack surface?"; then
             execute_sudo "Disable Remote Login" systemsetup -setremotelogin off
        else
             info "Keeping Remote Login enabled (ensure it is hardened!)."
        fi
    else
        info "Remote Login (SSH) is already disabled."
    fi
}

hardening_privacy_tweaks() {
    # Disable Recent Apps in Dock
    defaults write com.apple.dock show-recents -bool false
    
    # Disable AirDrop (optional)
    if ask_confirmation "Disable AirDrop?"; then
        defaults write com.apple.NetworkBrowser DisableAirDrop -bool true
    fi

    # Disable Metadata Indexing (Aggressive)
    if ask_confirmation "Disable Spotlight Indexing entirely (Aggressive)?"; then
         execute_sudo "Disable Spotlight" mdutil -i off /
    fi
}

hardening_secure_screen() {
    info "Securing Screen Saver and Lock..."
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0
}

hardening_harden_finder() {
    info "Hardening Finder..."
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
    defaults write com.apple.finder AppleShowAllFiles -bool true
    defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
    chflags nohidden ~/Library 2>/dev/null || true
}

hardening_anonymize_hostname() {
    local new_name="Mac"
    if [ "$PLATFORM_TYPE" == "Laptop" ]; then
        new_name="MacBook"
    fi
    
    info "Anonymizing Hostname to '$new_name'..."
    execute_sudo "Set ComputerName" scutil --set ComputerName "$new_name"
    execute_sudo "Set LocalHostName" scutil --set LocalHostName "$new_name"
    execute_sudo "Set HostName" scutil --set HostName "$new_name"
}
hardening_check_filevault() {
    info "Checking FileVault status..."
    if fdesetup status | grep -q "FileVault is On"; then
        return 0
    else
        return 1
    fi
}

hardening_ensure_filevault() {
    if hardening_check_filevault; then
        info "FileVault is already enabled."
    else
        warn "FileVault is NOT enabled."
        if ask_confirmation "Do you want to enable FileVault now?"; then
             execute_sudo "Enable FileVault" fdesetup enable
        else
             info "Skipping FileVault enablement."
        fi
    fi
}

hardening_remove_guest() {
    info "Removing Guest User..."
    if ask_confirmation "Permanently remove Guest User accounts?"; then
         execute_sudo "Disable Guest Login" defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false
         
         # Aggressive removal
         if id "guest" &>/dev/null; then
            execute_sudo "Remove Guest User" sysadminctl -deleteUser guest 2>/dev/null || true
         fi
         
         if dscl . -read /Users/Guest &>/dev/null; then
            execute_sudo "Remove Guest User (dscl)" dscl . -delete /Users/Guest 2>/dev/null || true
         fi
    fi
}

hardening_check_lockdown() {
    info "Checking Lockdown Mode status..."
    # GlobalPreferences LDMStatus: 1 = enabled, 0 or missing = disabled
    # We use 2>/dev/null because the key might not exist
    local status
    status=$(defaults read .GlobalPreferences.plist LDMStatus 2>/dev/null || echo "0")
    
    if [ "$status" == "1" ]; then
        return 0
    else
        return 1
    fi
}

hardening_ensure_lockdown() {
    # Lockdown Mode is only available on macOS 13 (Ventura) and later
    if [ -z "$PLATFORM_OS_VER_MAJOR" ]; then
         # Fallback if not detected for some reason
         warn "macOS version not detected. Skipping Lockdown Mode check."
         return 0
    fi
    
    if [ "$PLATFORM_OS_VER_MAJOR" -lt 13 ]; then
        info "Lockdown Mode is not available on macOS $PLATFORM_OS_VER"
        return 0
    fi

    if hardening_check_lockdown; then
        info "Lockdown Mode is already enabled."
    else
        warn "Lockdown Mode is NOT enabled."
        echo "Lockdown Mode significantly reduces attack surface."
        if ask_confirmation "Do you want to enable Lockdown Mode now? (Requires Restart)"; then
             # There is no direct CLI command to enable it silently.
             # We can try opening the preference pane.
             info "Opening System Settings for Lockdown Mode..."
             # Ventura+ URL scheme
             execute_sudo "Open Lockdown Mode Settings" open "x-apple.systempreferences:com.apple.LockdownMode"
             warn "Please enable Lockdown Mode manually in the window that appears, then restart your computer."
        else
             info "Skipping Lockdown Mode."
        fi
    fi
}

hardening_check_sip() {
    info "Checking System Integrity Protection (SIP)..."
    if csrutil status | grep -q "enabled"; then
        return 0
    else
        return 1
    fi
}

hardening_audit_gatekeeper() {
    info "Auditing Gatekeeper Exclusions..."
    # 'spctl --list' lists all rules. We want to see what is allowed.
    # We strip whitespace for clean count
    local allowed_apps
    allowed_apps=$(spctl --list --type execute | grep "accepted" | wc -l | xargs)
    
    info "Total accepted rules in Gatekeeper: $allowed_apps"
    info "Note: You can list all allowed apps using: spctl --list --type execute"
}


hardening_secure_homebrew() {
    info "Securing Homebrew..."
    
    if ! command -v brew &> /dev/null; then
        warn "Homebrew not found. Skipping Homebrew hardening."
        return 0
    fi

    # Disable Analytics
    info "Disabling Homebrew Analytics..."
    export HOMEBREW_NO_ANALYTICS=1
    # Capture brew path
    local brew_path
    brew_path=$(command -v brew)

    # We execute this as the user (brew warns against running as root)
    if [ -n "$SUDO_USER" ]; then
        execute_sudo "Disable Analytics (User)" su - "$SUDO_USER" -c "$brew_path analytics off"
    else
        # Run directly as current user (do NOT use execute_sudo which adds sudo)
        info "Disable Analytics"
        brew analytics off
    fi
    
    export HOMEBREW_NO_INSECURE_REDIRECT=1
    info "Set HOMEBREW_NO_INSECURE_REDIRECT=1 for this session."
    
    # Persistence
    local zshrc="$HOME/.zshrc"
    info "Ensuring persistence in $zshrc..."
    
    if [ ! -f "$zshrc" ]; then
        touch "$zshrc"
    fi
    
    if ! grep -q "HOMEBREW_NO_INSECURE_REDIRECT=1" "$zshrc"; then
        echo "export HOMEBREW_NO_INSECURE_REDIRECT=1" >> "$zshrc"
        info "Added HOMEBREW_NO_INSECURE_REDIRECT to .zshrc"
    fi
    
    if ! grep -q "HOMEBREW_NO_ANALYTICS=1" "$zshrc"; then
        echo "export HOMEBREW_NO_ANALYTICS=1" >> "$zshrc"
        info "Added HOMEBREW_NO_ANALYTICS to .zshrc"
    fi
    
    # TCC Warning
    warn "SECURITY WARNING: Homebrew requests 'App Management' or 'Full Disk Access'. Granting this is dangerous."
    warn "It allows any non-sandboxed app to execute code with Terminal's permissions."
    warn "Do NOT grant full disk access to Terminal for Homebrew if likely to run untrusted code."
    warn "Do NOT grant full disk access to Terminal for Homebrew if likely to run untrusted code."
}

hardening_disable_bonjour() {
    local plist="${MDNS_PLIST:-/Library/Preferences/com.apple.mDNSResponder.plist}"
    info "Disabling Bonjour/Multicast Advertisements..."
    if [ -f "$plist" ]; then
        execute_sudo "Disable Multicast" defaults write "$plist" NoMulticastAdvertisements -bool YES
    else
        warn "mDNSResponder plist not found (OK if on newer macOS where it might differ, skipping)."
    fi
}

hardening_secure_sudoers() {
    info "Auditing sudoers for env_keep..."
    # Warning: greedy match
    if sudo grep -q "env_keep += \"HOME MAIL\"" /etc/sudoers 2>/dev/null; then
        warn "Sudoers contains 'env_keep += HOME MAIL'. This is a potential risk."
        warn "Consider editing /etc/sudoers (via visudo) to comment out this line."
    else
        info "Sudoers looks clean."
    fi
}

hardening_set_umask() {
    info "Setting system umask to 077..."
    execute_sudo "Set Umask" launchctl config user umask 077
}

hardening_disable_captive_portal() {
    warn "Disabling Captive Portal detection may prevent login pages from appearing on public Wi-Fi."
    if ask_confirmation "Disable Captive Portal detection?"; then
        execute_sudo "Disable Captive Portal" defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control.plist Active -bool false
    fi
}

hardening_reset_tcc() {
    warn "This will reset Privacy Permissions (Camera, Mic, etc.) for ALL apps."
    if ask_confirmation "Reset TCC Permissions?"; then
        execute_sudo "Reset TCC" tccutil reset All || true
        info "TCC Permissions reset."
    fi
}

hardening_run_all() {
    hardening_update_system
    hardening_enable_firewall
    hardening_disable_analytics
    hardening_configure_privacy
    hardening_secure_screen
    hardening_harden_finder
    hardening_anonymize_hostname
    hardening_ensure_filevault
    hardening_ensure_lockdown
    hardening_secure_homebrew
    hardening_disable_bonjour
    hardening_secure_sudoers
    hardening_set_umask
    hardening_disable_captive_portal
    hardening_remove_guest
    # TCC reset is manual only
}

hardening_verify() {
    info "Verifying Security Configuration..."
    local all_good=true

    # 1. Firewall
    info "Checking Application Firewall..."
    # socketfilterfw --getglobalstate returns "Firewall is enabled. (State = 1)" or similar
    if "$SOCKETFILTERFW_CMD" --getglobalstate | grep -q "enabled"; then
        info "[PASS] Firewall is enabled."
    else
        warn "[FAIL] Firewall is DISABLED."
        all_good=false
    fi

    if "$SOCKETFILTERFW_CMD" --getstealthmode | grep -E -q "enabled|on"; then
        info "[PASS] Stealth Mode is enabled."
    else
        warn "[FAIL] Stealth Mode is DISABLED."
        all_good=false
    fi

    # 2. FileVault
    info "Checking FileVault..."
    if fdesetup status | grep -q "FileVault is On"; then
        info "[PASS] FileVault is enabled."
    else
        warn "[FAIL] FileVault is DISABLED."
        all_good=false
    fi

    # 3. System Integrity Protection (SIP)
    if hardening_check_sip; then
        info "[PASS] SIP is enabled."
    else
        warn "[FAIL] SIP is DISABLED."
        all_good=false
    fi

    # 4. Gatekeeper
    info "Checking Gatekeeper (spctl)..."
    if spctl --status | grep -q "assessments enabled"; then
         info "[PASS] Gatekeeper is enabled."
    else
         warn "[FAIL] Gatekeeper is DISABLED."
         all_good=false
    fi

    # 5. Lockdown Mode (Ventura+)
    if [ -n "$PLATFORM_OS_VER_MAJOR" ] && [ "$PLATFORM_OS_VER_MAJOR" -ge 13 ]; then
        info "Checking Lockdown Mode..."
        local ldm_status
        ldm_status=$(defaults read .GlobalPreferences.plist LDMStatus 2>/dev/null || echo "0")
        if [ "$ldm_status" == "1" ]; then
            info "[PASS] Lockdown Mode is enabled."
        else
            warn "[FAIL] Lockdown Mode is DISABLED."
            # Not strict fail, maybe just warn? User preference.
        fi
    fi

    # 6. Homebrew Analytics
    if command -v brew &> /dev/null; then
        info "Checking Homebrew Analytics..."
        # brew analytics returns "Analytics are disabled." or "Analytics are enabled."
        if brew analytics | grep -q "disabled"; then
            info "[PASS] Homebrew Analytics are disabled."
        else
            warn "[FAIL] Homebrew Analytics are ENABLED."
            all_good=false
        fi
    fi

    if [ "$all_good" = true ]; then
        info "Security Verification Completed: ALL CHECKS PASSED."
    else
        warn "Security Verification Completed: SOME CHECKS FAILED."
    fi
}
