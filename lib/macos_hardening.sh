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
    
    # Aggressive Siri Disable (Privacy.sexy)
    info "Disabling Siri Services..."
    defaults write com.apple.assistant.support 'Assistant Enabled' -bool false
    defaults write com.apple.assistant.backedup 'Use device speaker for TTS' -int 3
    execute_sudo "Disable Siri Agent" launchctl disable "system/com.apple.Siri.agent" 2>/dev/null || true
    execute_sudo "Disable Assistantd" launchctl disable "system/com.apple.assistantd" 2>/dev/null || true
    # User agents (might need to run as user without sudo, or just warn)
    launchctl disable "user/$UID/com.apple.Siri.agent" 2>/dev/null || true
    launchctl disable "user/$UID/com.apple.assistantd" 2>/dev/null || true
    
    defaults write com.apple.SetupAssistant 'DidSeeSiriSetup' -bool True
    defaults write com.apple.systemuiserver 'NSStatusItem Visible Siri' 0
    defaults write com.apple.Siri 'StatusMenuVisible' -bool false
    defaults write com.apple.Siri 'UserHasDeclinedEnable' -bool true

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
         info "Disabling and Removing Google Software Update..."
         # Try to be nice first? No, privacy.sexy nukes it.
         if [ -x "$HOME/Library/Google/GoogleSoftwareUpdate/GoogleSoftwareUpdate.bundle/Contents/Resources/ksinstall" ]; then
             "$HOME/Library/Google/GoogleSoftwareUpdate/GoogleSoftwareUpdate.bundle/Contents/Resources/ksinstall" --nuke 2>/dev/null || true
         fi
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
    if [ "$(defaults read com.microsoft.office.telemetry ZeroDiagnosticData 2>/dev/null)" != "1" ]; then
        defaults write com.microsoft.office.telemetry ZeroDiagnosticData -bool true 2>/dev/null || true
    fi
    if [ "$(defaults read com.microsoft.office.telemetry UserOptIn 2>/dev/null)" != "0" ]; then
        defaults write com.microsoft.office.telemetry UserOptIn -bool false 2>/dev/null || true
    fi
    # Privacy.sexy exact key match
    defaults write com.microsoft.office DiagnosticDataTypePreference -string "ZeroDiagnosticData" 2>/dev/null || true


    
    # .NET / PowerShell
    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export POWERSHELL_TELEMETRY_OPTOUT=1
    # Persistence
    if ask_confirmation "Add telemetry opt-out environment variables to shell profiles?"; then
        local profiles=("$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc")
        for profile in "${profiles[@]}"; do
            # Only modify if exists or is the default shell profile
            if [ -f "$profile" ] || { [ "$SHELL" = "/bin/zsh" ] && [ "$profile" = "$HOME/.zshrc" ]; } || { [ "$SHELL" = "/bin/bash" ] && [ "$profile" = "$HOME/.bash_profile" ]; }; then
                if [ ! -f "$profile" ]; then touch "$profile"; fi
                
                # DOTNET
                if ! grep -q "^\s*export DOTNET_CLI_TELEMETRY_OPTOUT=" "$profile"; then
                    echo "export DOTNET_CLI_TELEMETRY_OPTOUT=1" >> "$profile"
                    info "Added DOTNET_CLI_TELEMETRY_OPTOUT to $profile"
                fi
                
                # POWERSHELL
                if ! grep -q "^\s*export POWERSHELL_TELEMETRY_OPTOUT=" "$profile"; then
                     echo "export POWERSHELL_TELEMETRY_OPTOUT=1" >> "$profile"
                     info "Added POWERSHELL_TELEMETRY_OPTOUT to $profile"
                fi
            fi
        done
    else
        info "Skipping shell profile modifications for telemetry."
    fi
}

hardening_disable_parallels() {
    # Parallels Desktop Ads & Updates
    if [ -d "/Applications/Parallels Desktop.app" ]; then
        info "Disabling Parallels Desktop Ads/Updates..."
        defaults write com.parallels.Parallels\ Desktop ApplicationPreferences.CheckForUpdates -bool false 2>/dev/null || true
        defaults write com.parallels.Parallels\ Desktop "ApplicationPreferences.ShowPromo" -bool false 2>/dev/null || true
        defaults write com.parallels.Parallels\ Desktop "ApplicationPreferences.ShowTutorial" -bool false 2>/dev/null || true
        # Privacy.sexy exact keys
        defaults write "com.parallels.Parallels Desktop" "ProductPromo.ForcePromoOff" -bool yes 2>/dev/null || true
        defaults write "com.parallels.Parallels Desktop" "WelcomeScreenPromo.PromoOff" -bool yes 2>/dev/null || true
    fi
}


hardening_configure_privacy() {
    info "Configuring Spotlight and Privacy..."
    # Disable Spotlight suggestions
    # Disable Spotlight suggestions (Non-destructive update of orderedItems)
    # We use Python to surgically disable 'MENU_SPOTLIGHT_SUGGESTIONS' and 'MENU_WEBSEARCH'
    # without resetting the user's custom sort order or other categories.
    
    if command -v python3 >/dev/null 2>&1; then
        local plist_path="$HOME/Library/Preferences/com.apple.Spotlight.plist"
        # Helper script to modify the specialized array-of-dicts
        python3 -c "
import plistlib, os, sys

path = os.path.expanduser('$plist_path')
if not os.path.exists(path):
    sys.exit(0) # Nothing to modify

try:
    with open(path, 'rb') as f:
        pl = plistlib.load(f)
    
    changed = False
    if 'orderedItems' in pl:
        for item in pl['orderedItems']:
            # Target specific privacy-invasive categories
            if item.get('name') in ['MENU_SPOTLIGHT_SUGGESTIONS', 'MENU_WEBSEARCH', 'MENU_OTHER']:
                if item.get('enabled') != False:
                    item['enabled'] = False
                    changed = True
    
    if changed:
        with open(path, 'wb') as f:
            plistlib.dump(pl, f)
        print('Updated Spotlight preferences.')
except Exception as e:
    print(f'Error updating Spotlight plist: {e}')
"
    else
        # Fallback if Python is missing: Just warn, don't overwrite user config destructively.
        warn "Python3 not found. Skipping granular Spotlight configuration to preserve user settings."
    fi
    
    # 2. Disable 'Look up' & Suggestions at the system level (Global key)
    defaults write com.apple.lookup.shared LookupEnabled -bool false 2>/dev/null || true
    
    killall mds > /dev/null 2>&1 || true
    execute_sudo "Re-enable indexing" mdutil -i on / > /dev/null
    
    # Remote Apple Events
    info "Disabling Remote Apple Events..."
    execute_sudo "Disable Remote Events" systemsetup -setremoteappleevents off 2>/dev/null || true

    # Remote Services
    hardening_disable_services

    # Privacy Tweaks
    hardening_privacy_tweaks
}

hardening_disable_services() {
    info "Disabling Unnecessary Services..."

    # 1. Remote Login (SSH)
    if systemsetup -getremotelogin 2>/dev/null | grep -i "On"; then
        warn "Remote Login (SSH) is currently ENABLED."
        if ask_confirmation "Disable Remote Login (SSH) to reduce attack surface?"; then
             execute_sudo "Disable Remote Login" systemsetup -setremotelogin off
        else
             info "Keeping Remote Login enabled."
        fi
    else
        info "Remote Login (SSH) is already disabled."
    fi
    
    # 2. Insecure Services (TFTP, Telnet)
    # Telnet/TFTP are rarely used but if present should be off
    execute_sudo "Disable TFTP" launchctl disable 'system/com.apple.tftpd' 2>/dev/null || true
    execute_sudo "Disable Telnet" launchctl disable 'system/com.apple.telnetd' 2>/dev/null || true
    
    # 3. Remote Management (ARD / Screen Sharing)
    # This is different from "Remote Login" (SSH)
    local ard_agent="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"
    if [ -x "$ard_agent" ]; then
        execute_sudo "Disable Remote Management (ARD)" "$ard_agent" -deactivate -stop 2>/dev/null || true
    fi
    # Aggressive Removal (Privacy.sexy)
    execute_sudo "Remove ARD Settings" rm -rf /var/db/RemoteManagement 2>/dev/null || true
    execute_sudo "Remove ARD PList" rm -f /Library/Preferences/com.apple.RemoteDesktop.plist 2>/dev/null || true
    rm -f ~/Library/Preferences/com.apple.RemoteDesktop.plist 2>/dev/null || true
    execute_sudo "Remove ARD App Support" rm -rf /Library/Application\ Support/Apple/Remote\ Desktop/ 2>/dev/null || true
    rm -rf ~/Library/Application\ Support/Remote\ Desktop/ 2>/dev/null || true
    rm -rf ~/Library/Containers/com.apple.RemoteDesktop 2>/dev/null || true
    
    # 4. Printer Sharing
    if command -v cupsctl >/dev/null; then
        info "Disabling Printer Sharing..."
        cupsctl --no-share-printers 2>/dev/null || true
        cupsctl --no-remote-any 2>/dev/null || true
        cupsctl --no-remote-admin 2>/dev/null || true
    fi
    
    # 5. Guest Sharing (SMB/AFP)
    info "Disabling Guest File Sharing..."
    execute_sudo "Disable SMB Guest" defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server AllowGuestAccess -bool NO
    execute_sudo "Disable AFP Guest" defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool NO
    
    if command -v sysadminctl >/dev/null; then
         execute_sudo "Disable SMB Guest (sysadminctl)" sysadminctl -smbGuestAccess off 2>/dev/null || true
         execute_sudo "Disable AFP Guest (sysadminctl)" sysadminctl -afpGuestAccess off 2>/dev/null || true
    fi
}

hardening_disable_updates() {
    info "Disabling Automatic Updates (Aggressive)..."
    if ! ask_confirmation_with_info "Disable ALL Automatic Updates?" \
        "This includes Security Updates, App Store Updates, and macOS System Updates." \
        "You will need to manually update your system to stay secure."; then
        info "Skipping Update Disabling."
        return 0
    fi

    # System Updates
    execute_sudo "Disable Auto Check" defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
    execute_sudo "Disable Auto Download" defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
    execute_sudo "Disable Release Install" defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
    execute_sudo "Disable Config Data" defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool false
    execute_sudo "Disable Critical Update" defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool false
    
    # App Store
    execute_sudo "Disable App AutoUpdate" defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool false
    execute_sudo "Disable App AutoUpdate (High Sierra)" defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallAppUpdates -bool false
    
    # Beta Updates
    execute_sudo "Disable Beta Updates" defaults write /Library/Preferences/com.apple.SoftwareUpdate AllowPreReleaseInstallation -bool false

    # Gatekeeper Auto-Rearm (Prevent it from re-enabling itself)
    execute_sudo "Disable Gatekeeper Auto-Rearm" defaults write /Library/Preferences/com.apple.security GKAutoRearm -bool true
}

hardening_privacy_tweaks() {
    # Disable Recent Apps in Dock
    defaults write com.apple.dock show-recents -bool false
    
    # Disable AirDrop (optional)
    if ask_confirmation_with_info "Disable AirDrop?" \
        "Disabling AirDrop reduces local attack surface and casual file sharing." \
        "You can still move files via cables or encrypted messengers."; then
        defaults write com.apple.NetworkBrowser DisableAirDrop -bool true
    fi

    # Disable Metadata Indexing (Aggressive)
    if ask_confirmation_with_info "Disable Spotlight Indexing (Aggressive)?" \
        "Disables Spotlight indexing system-wide, which can reduce metadata leakage." \
        "This may degrade search performance in Finder and apps."; then
         execute_sudo "Disable Spotlight" mdutil -i off /
    fi
    
    # Spell Correction (sending data to Apple)
    defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false
    
    # Screenshots (Metadata)
    defaults write com.apple.screencapture include-date -bool false
    killall SystemUIServer 2>/dev/null || true
    
    # Gatekeeper & Quarantine Logs
    # These are now handled in `hardening_enable_gatekeeper_options` and `hardening_enable_quarantine`
    # to group "Privacy Over Security" decisions.
}

hardening_enable_library_validation() {
   # "DisableLibraryValidation" = false (Good/Secure)
   # "DisableLibraryValidation" = true (Privacy Over Security / Unsafe)
   
   if ask_confirmation_with_info "Enable Library Validation (Security) or Disable it (Privacy Over Security)?" \
        "Enabling (Recommended) prevents unsigned code injection (Better Security)." \
        "Disabling (Privacy Over Security) allows any library to load (Reduced Security, Privacy.sexy default)."; then
         # User chose YES -> Enable/Enforce Security
         execute_sudo "Enable Library Validation" defaults write /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation -bool false 2>/dev/null || true
   else
         # User chose NO -> They want to "disable" it? Or just do nothing?
         # The prompt wording "Enable ... or Disable?" makes "Yes" = Enable.
         # The user request specifically asked for "Privacy Over Security" wording.
         
         if ask_confirmation "ATTENTION: Disable Library Validation (Unsafe)? (Privacy Over Security)"; then
              warn "Disabling Library Validation..."
              execute_sudo "Disable Library Validation" defaults write /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation -bool true 2>/dev/null || true
         else
              info "Keeping Library Validation enabled (Safe)."
         fi
   fi
}

hardening_enable_quarantine() {
    # LSQuarantine & Gatekeeper Options
    
    # 1. Gatekeeper
    if ask_confirmation_with_info "Enforce Gatekeeper (Security) or Disable it (Privacy Over Security)?" \
       "Enforcing (Recommended) blocks untrusted apps (Better Security)." \
       "Disabling (Privacy Over Security) allows any app to run (Reduced Security, Privacy.sexy default)."; then
       # YES = Enforce
       execute_sudo "Enable Gatekeeper" spctl --master-enable 2>/dev/null || true
       execute_sudo "Enable Gatekeeper (Policy)" defaults write /var/db/SystemPolicy-prefs enabled -string yes 2>/dev/null || true
    else
        # NO -> Check for disable
        if ask_confirmation "ATTENTION: Disable Gatekeeper (Unsafe)? (Privacy Over Security)"; then
            warn "Disabling Gatekeeper..."
            execute_sudo "Disable Gatekeeper" spctl --master-disable
            execute_sudo "Disable Gatekeeper (Policy)" defaults write /var/db/SystemPolicy-prefs enabled -string no 2>/dev/null || true
        fi
    fi

    # 2. Quarantine (LSQuarantine)
    if ask_confirmation_with_info "Enforce File Quarantine (Security) or Disable it (Privacy Over Security)?" \
       "Enforcing (Recommended) flags downloaded files for inspection (Better Security)." \
       "Disabling (Privacy Over Security) removes provenance metadata (Reduced Security, Privacy.sexy default)."; then
        # YES = Enforce
        info "Enforcing File Quarantine..."
        defaults delete com.apple.LaunchServices LSQuarantine 2>/dev/null || true
        defaults write com.apple.LaunchServices LSQuarantine -bool true 2>/dev/null || true
    else
         if ask_confirmation "ATTENTION: Disable File Quarantine (Unsafe)? (Privacy Over Security)"; then
             warn "Disabling File Quarantine..."
             defaults write com.apple.LaunchServices LSQuarantine -bool false 2>/dev/null || true
         fi
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
        if ask_confirmation_with_info "Enable FileVault?" \
            "FileVault provides full-disk encryption at rest." \
            "Enabling it requires administrative credentials and may take time to complete."; then
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
        if ask_confirmation_with_info "Enable Lockdown Mode? (Requires Restart)" \
            "Lockdown Mode significantly reduces attack surface but may break some features." \
            "You will need to enable it manually in System Settings and then restart."; then
            info "Opening System Settings for Lockdown Mode..."
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
        info "Disabling Analytics (User: $SUDO_USER)..."
        # Run directly to avoid nested 'sudo' inside 'execute_sudo'
        sudo -u "$SUDO_USER" "$brew_path" analytics off
    else
        # Run directly as current user (do NOT use execute_sudo which adds sudo)
        info "Disable Analytics"
        brew analytics off
    fi
    
    export HOMEBREW_NO_INSECURE_REDIRECT=1
    info "Set HOMEBREW_NO_INSECURE_REDIRECT=1 for this session."
    
    # Persistence
    # Persistence (Centralized File)
    local brew_env_file="$HOME/.homebrew_secure_env"
    
    if ask_confirmation "Add Homebrew security variables and proxy aliases to shell profiles?"; then
        info "Creating centralized config at $brew_env_file..."
        
        {
            echo "# Better Anonymity - Homebrew & Proxy Hardening"
            echo "export HOMEBREW_NO_ANALYTICS=1"
            echo "export HOMEBREW_NO_INSECURE_REDIRECT=1"
            echo "export HOMEBREW_CASK_OPTS=--require-sha"
            echo ""
            echo "# Tor/I2P Aliases"
            echo "alias torify='export ALL_PROXY=socks5h://127.0.0.1:9050'"
            echo "alias untorify='unset ALL_PROXY'"
            echo "alias tor-run='env ALL_PROXY=socks5h://127.0.0.1:9050'"
            echo "alias stay-connected='better-anonymity captive monitor'"
            echo "alias i2pify='export http_proxy=http://127.0.0.1:4444 https_proxy=http://127.0.0.1:4445'"
        } > "$brew_env_file"
        
        local profiles=("$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc")
        for profile in "${profiles[@]}"; do
            if [ -f "$profile" ] || { [ "$SHELL" = "/bin/zsh" ] && [ "$profile" = "$HOME/.zshrc" ]; } || { [ "$SHELL" = "/bin/bash" ] && [ "$profile" = "$HOME/.bash_profile" ]; }; then
                if [ ! -f "$profile" ]; then touch "$profile"; fi
                
                # Source the centralized file if not already present
                if ! grep -q "source.*$brew_env_file" "$profile" && ! grep -q "\. .*$brew_env_file" "$profile"; then
                    echo "" >> "$profile"
                    echo "# Better Anonymity Hardening" >> "$profile"
                    echo "[ -f \"$brew_env_file\" ] && source \"$brew_env_file\"" >> "$profile"
                    info "Added source command for secure env to $profile"
                else
                    info "Profile $profile already sources secure env."
                fi
            fi
        done
    else
        info "Skipping shell profile modifications for Homebrew/Proxies."
    fi
    
    # TCC Warning
    warn "SECURITY WARNING: Homebrew requests 'App Management' or 'Full Disk Access'. Granting this is dangerous."
    warn "It allows any non-sandboxed app to execute code with Terminal's permissions."
    warn "Do NOT grant full disk access to Terminal for Homebrew if likely to run untrusted code."
}

hardening_disable_bonjour() {
    local plist="${MDNS_PLIST:-/Library/Preferences/com.apple.mDNSResponder.plist}"
    info "Disabling Bonjour/Multicast Advertisements..."
    
    if [ ! -f "$plist" ]; then
        warn "mDNSResponder plist not found at $plist. Skipping."
        return 0
    fi
    
    # Write preference unconditionally (creates file if missing)
    # defaults write expects a domain or path without extension
    execute_sudo "Disable Multicast" defaults write "${plist%.plist}" NoMulticastAdvertisements -bool YES
    
    # Reload mDNSResponder to apply changes
    execute_sudo "Reload mDNSResponder" killall -HUP mDNSResponder 2>/dev/null || true
}

hardening_secure_sudoers() {
    info "Auditing sudoers for env_keep..."
    
    # 1. Define Whitelist (Standard macOS defaults)
    # Based on /etc/sudoers standard install and user feedback
    local whitelist="BLOCKSIZE COLORFGBG COLORTERM __CF_USER_TEXT_ENCODING CHARSET LANG LANGUAGE LC_ALL LC_COLLATE LC_CTYPE LC_MESSAGES LC_MONETARY LC_NUMERIC LC_TIME LINES COLUMNS LSCOLORS SSH_AUTH_SOCK TZ DISPLAY XAUTHORIZATION XAUTHORITY EDITOR VISUAL HOME MAIL"
    
    # 2. Capture env_keep directives
    local matches
    matches=$(sudo grep -rE "^\s*Defaults.*env_keep" /etc/sudoers /etc/sudoers.d 2>/dev/null)
    
    if [ -n "$matches" ]; then
        local found_risks=0
        
        # 3. Parse each line
        while read -r line; do
             # Extract variables inside quotes: Defaults env_keep += "VAR1 VAR2"
             if [[ "$line" =~ \"(.*)\" ]]; then
                 local vars="${BASH_REMATCH[1]}"
                 for v in $vars; do
                     local safe=0
                     for wl in $whitelist; do
                         if [ "$v" == "$wl" ]; then
                             safe=1
                             break
                         fi
                     done
                     
                     if [ $safe -eq 0 ]; then
                         warn "  [RISK] Unknown/Unsafe env_keep variable preserved: '$v'"
                         # warn "         Source: $line" # Optional verbose 
                         found_risks=1
                     fi
                 done
             fi
        done <<< "$matches"
        
        if [ $found_risks -eq 0 ]; then
             info "Sudoers audit passed. (Standard macOS defaults detected and verified safe)."
        else
             warn "Audit complete. Review potential risks above."
             warn "Use 'sudo visudo' to edit if necessary."
        fi
    else
        info "Sudoers looks clean (no env_keep directives found)."
    fi
}

hardening_set_umask() {
    info "Setting system umask to 077..."
    execute_sudo "Set Umask" launchctl config user umask 077
}

hardening_disable_captive_portal() {
    if ask_confirmation_with_info "Disable Captive Portal detection?" \
        "Disabling Captive Portal detection may prevent captive Wi-Fi login pages from appearing automatically." \
        "Only do this if you understand the trade-offs for public Wi-Fi usage."; then
        execute_sudo "Disable Captive Portal" defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control.plist Active -bool false
    fi
}

hardening_reset_tcc() {
    if ask_confirmation_with_info "Reset TCC Permissions?" \
        "This will reset all privacy permissions (Camera, Mic, Files, etc.) for ALL apps." \
        "macOS will ask again next time each app requests access."; then
        execute_sudo "Reset TCC" tccutil reset All || true
        info "TCC Permissions reset."
    fi
}


hardening_backup() {
    local backup_root="$HOME/.better-anonymity/backups"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="${backup_root}/hardening_${timestamp}"
    
    info "Creating hardening backup at $backup_dir..."
    mkdir -p "$backup_dir"
    
    # 1. Defaults Domains
    local domains=(
        "com.apple.spotlight"
        "com.apple.loginwindow"
        "com.apple.alf"
        "com.apple.mDNSResponder"
        "com.apple.CrashReporter"
        "com.apple.AdLib"
        "com.apple.assistant.support"
        "com.apple.lookup.shared"
    )
    
    for domain in "${domains[@]}"; do
        if defaults read "$domain" &>/dev/null; then
            defaults export "$domain" "$backup_dir/$domain.plist"
        fi
    done
    
    # 2. Hostname
    scutil --get ComputerName > "$backup_dir/ComputerName.txt"
    scutil --get LocalHostName > "$backup_dir/LocalHostName.txt"
    scutil --get HostName > "$backup_dir/HostName.txt"
    
    # 3. Files
    if [ -f "$HOME/.homebrew_secure_env" ]; then
        cp "$HOME/.homebrew_secure_env" "$backup_dir/homebrew_secure_env"
    fi
    
    info "Backup complete."
}

hardening_restore() {
    local backup_root="$HOME/.better-anonymity/backups"
    if [ ! -d "$backup_root" ]; then
        warn "No backups found."
        return 1
    fi
    
    echo "Available backups:"
    ls -1 "$backup_root" | grep "hardening_"
    echo ""
    
    local selected_backup
    read -p "Enter backup directory name to restore (e.g., hardening_2023...): " selected_backup
    local restore_path="$backup_root/$selected_backup"
    
    if [ ! -d "$restore_path" ]; then
        warn "Backup not found: $restore_path"
        return 1
    fi
    
    if ask_confirmation "Restore system settings from $selected_backup? This requires sudo."; then
        info "Restoring defaults from plists..."
        for plist in "$restore_path"/*.plist; do
            if [ -f "$plist" ]; then
                local domain
                domain=$(basename "$plist" .plist)
                info "Restoring defaults for $domain..."
                # defaults import is safer than write
                defaults import "$domain" "$plist"
            fi
        done
        
        info "Restoring Hostnames..."
        if [ -f "$restore_path/ComputerName.txt" ]; then
             execute_sudo "Restore ComputerName" scutil --set ComputerName "$(cat "$restore_path/ComputerName.txt")"
        fi
         if [ -f "$restore_path/LocalHostName.txt" ]; then
             execute_sudo "Restore LocalHostName" scutil --set LocalHostName "$(cat "$restore_path/LocalHostName.txt")"
        fi
         if [ -f "$restore_path/HostName.txt" ]; then
             execute_sudo "Restore HostName" scutil --set HostName "$(cat "$restore_path/HostName.txt")"
        fi
        
        info "Restoring Homebrew Env..."
        if [ -f "$restore_path/homebrew_secure_env" ]; then
            cp "$restore_path/homebrew_secure_env" "$HOME/.homebrew_secure_env"
        elif [ -f "$HOME/.homebrew_secure_env" ]; then
            # If it didn't exist in backup but exists now, maybe remove it?
            # Or just leave it. Let's just restore if present.
             true
        fi
        
        # Reload services
        info "Reloading services..."
        killall cfprefsd &>/dev/null || true
        killall SystemUIServer &>/dev/null || true
        execute_sudo "Reload Firewall" pkill -HUP socketfilterfw &>/dev/null || true
        execute_sudo "Reload mDNSResponder" killall -HUP mDNSResponder &>/dev/null || true
        
        warn "Restore complete. A restart is recommended to ensure all changes take effect."
    fi
}

hardening_run_all() {
    if ask_confirmation "Create a backup of system settings before hardening?"; then
        hardening_backup
    fi

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
    hardening_disable_updates
    hardening_enable_library_validation
    hardening_enable_quarantine
    hardening_remove_guest
    # TCC reset is manual only
}

hardening_verify() {
    info "Verifying Security Configuration..."
    local all_good=1

    # 1. Firewall
    info "Checking Application Firewall..."
    # socketfilterfw --getglobalstate returns "Firewall is enabled. (State = 1)" or similar
    if "$SOCKETFILTERFW_CMD" --getglobalstate | grep -q "enabled"; then
        info "[PASS] Firewall is enabled."
    else
        warn "[FAIL] Firewall is DISABLED."
        all_good=0
    fi

    if "$SOCKETFILTERFW_CMD" --getstealthmode | grep -E -q "enabled|on"; then
        info "[PASS] Stealth Mode is enabled."
    else
        warn "[FAIL] Stealth Mode is DISABLED."
        all_good=0
    fi

    # 2. FileVault
    info "Checking FileVault..."
    if fdesetup status | grep -q "FileVault is On"; then
        info "[PASS] FileVault is enabled."
    else
        warn "[FAIL] FileVault is DISABLED."
        all_good=0
    fi

    # 3. System Integrity Protection (SIP)
    if hardening_check_sip; then
        info "[PASS] SIP is enabled."
    else
        warn "[FAIL] SIP is DISABLED."
        all_good=0
    fi

    # 4. Gatekeeper
    info "Checking Gatekeeper (spctl)..."
    if spctl --status | grep -q "assessments enabled"; then
         info "[PASS] Gatekeeper is enabled."
    else
         warn "[FAIL] Gatekeeper is DISABLED."
         all_good=0
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
            all_good=0
        fi
    fi

    # 7. Hostname Anonymity
    info "Checking Hostname Anonymity..."
    local computer_name
    computer_name=$(scutil --get ComputerName)
    if [[ "$computer_name" == "Mac" ]] || [[ "$computer_name" == "MacBook" ]]; then
        info "[PASS] Hostname appears anonymized ($computer_name)."
    else
        warn "[FAIL] Hostname reveals potential identity: $computer_name"
        all_good=0
    fi


    if [ "$all_good" -eq 1 ]; then
        info "Security Verification Completed: ALL CHECKS PASSED."
    else
        warn "Security Verification Completed: SOME CHECKS FAILED."
    fi
}
