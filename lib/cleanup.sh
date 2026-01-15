#!/bin/bash

# lib/cleanup.sh
# Metadata and artifact cleanup functions

cleanup_metadata() {
    warn "This process will delete cached data, recent file history, and other metadata artifacts."
    warn "Some applications may lose state (e.g. open windows, unsaved changes)."
    if ! ask_confirmation "Are you sure you want to proceed with Metadata Cleanup?"; then
        return 0
    fi

    info "Converting sudo authentication for cleanup..."
    sudo -v

    # 1. QuickLook Cache
    info "Cleaning QuickLook Cache..."
    # 'qlmanage -r disablecache' is deprecated/invalid on newer macOS.
    # We rely on 'qlmanage -r cache' (reset) below.
    
    local user_cache_dir
    user_cache_dir=$(getconf DARWIN_USER_CACHE_DIR)
    
    # Try aggressive remove, but suppress errors (SIP/Permissions)
    execute_sudo "Remove QL Thumbnails" rm -rf "$user_cache_dir/com.apple.QuickLook.thumbnailcache" 2>/dev/null || true
    
    # Official reset
    qlmanage -r cache
    
    # 2. Finder Metadata
    info "Clearing Finder Metadata..."
    defaults delete ~/Library/Preferences/com.apple.finder.plist FXDesktopVolumePositions 2>/dev/null || true
    defaults delete ~/Library/Preferences/com.apple.finder.plist FXRecentFolders 2>/dev/null || true
    defaults delete ~/Library/Preferences/com.apple.finder.plist RecentMoveAndCopyDestinations 2>/dev/null || true
    defaults delete ~/Library/Preferences/com.apple.finder.plist RecentSearches 2>/dev/null || true
    
    # 3. Bluetooth / CUPS (Sudo required)
    info "Clearing Bluetooth and CUPS metadata..."
    if [ -f /Library/Preferences/com.apple.Bluetooth.plist ]; then
        execute_sudo "Clear Bluetooth Cache" defaults delete /Library/Preferences/com.apple.Bluetooth.plist DeviceCache 2>/dev/null || true
    fi
    execute_sudo "Clear CUPS jobs" rm -rf /var/spool/cups/c0* /var/spool/cups/tmp/* /var/spool/cups/cache/job.cache* 2>/dev/null || true

    # 4. Language/Spelling/Suggestions (Delete and Lock)
    info "Cleaning and Locking Language/Spelling data..."
    rm -rf ~/Library/LanguageModeling/* ~/Library/Spelling/* ~/Library/Suggestions/* 2>/dev/null || true
    # Locking
    chmod -R 000 ~/Library/LanguageModeling ~/Library/Spelling ~/Library/Suggestions 2>/dev/null || true
    chflags -R uchg ~/Library/LanguageModeling ~/Library/Spelling ~/Library/Suggestions 2>/dev/null || true

    # 5. QuickLook Application Support
    info "Cleaning and Locking QuickLook App Support..."
    rm -rf ~/Library/Application\ Support/Quick\ Look/* 2>/dev/null || true
    chmod -R 000 ~/Library/Application\ Support/Quick\ Look 2>/dev/null || true
    chflags -R uchg ~/Library/Application\ Support/Quick\ Look 2>/dev/null || true

    # 6. Autosave / Saved Application State
    info "Cleaning Saved Application State..."
    rm -rf ~/Library/Saved\ Application\ State/* 2>/dev/null || true
    # We won't lock this by default as it can be very annoying for usability, 
    # but we will clear it.
    
    # 7. Siri Analytics
    info "Clearing Siri Analytics..."
    rm -rf ~/Library/Assistant/SiriAnalytics.db 2>/dev/null || true

    # 8. Wi-Fi NVRAM (Sudo)
    info "Clearing preferred Wi-Fi from NVRAM..."
    execute_sudo "Clear NVRAM Wi-Fi" nvram -d 36C28AB5-6566-4C50-9EBD-CBB920F83843:preferred-networks 2>/dev/null || true

    # 9. DNS Cache
    info "Flushing DNS Cache..."
    execute_sudo "Flush DNS Cache" dscacheutil -flushcache
    execute_sudo "Restart mDNSResponder" killall -HUP mDNSResponder 2>/dev/null || true

    # 10. System Logs & Audits
    info "Clearing System Logs (ASL, Audit, Install)..."
    execute_sudo "Clear ASL" rm -rf /private/var/log/asl/* 2>/dev/null
    execute_sudo "Clear Audit" rm -rf /private/var/audit/* 2>/dev/null
    execute_sudo "Clear Install Logs" rm -rf /private/var/log/install.log /Library/Logs/install.log 2>/dev/null
    execute_sudo "Clear System Logs" rm -rf /Library/Logs/* 2>/dev/null

    # 11. Trash (Optional)
    if ask_confirmation "Empty Trash on all volumes?"; then
        cleanup_trash
    fi

    # 12. Dev Tools (Optional)
    if ask_confirmation "Clean Developer Caches (Xcode, Docker, NPM, etc.)?"; then
        cleanup_dev_tools
    fi

    # 13. iOS Data (Optional)
    if ask_confirmation "Clean iOS Data (Backups, Simulators)?"; then
        cleanup_ios_data
    fi
    
    # 14. Receipts (Optional/Aggressive)
    if ask_confirmation "Clear Installation Receipts (Aggressive)?"; then
        cleanup_receipts
    fi

    # 15. Memory (Optional)
    if ask_confirmation "Purge Inactive Memory (sudo purge)?"; then
        cleanup_memory
    fi

    # 16. Browsers (Aggressive)
    if ask_confirmation "Clean Browser History & Cache (Chrome/Safari/Firefox)?"; then
        cleanup_browsers
    fi
    
    # 17. Quarantine (Aggressive)
    if ask_confirmation "Clear Quarantine History (Downloaded files logs)?"; then
        cleanup_quarantine
    fi

    info "Metadata cleanup completed."
}

cleanup_trash() {
    info "Emptying Trash..."
    execute_sudo "Empty Main Trash" rm -rf ~/.Trash/* 2>/dev/null || true
    # /Volumes is tricky, we just do best effort
    execute_sudo "Empty Volumes Trash" rm -rf /Volumes/*/.Trashes/* 2>/dev/null || true
}

cleanup_receipts() {
    info "Clearing Installation Receipts..."
    execute_sudo "Remove Receipts" rm -rf /private/var/db/receipts/* 2>/dev/null
    execute_sudo "Remove InstallHistory" rm -f /Library/Receipts/InstallHistory.plist 2>/dev/null
}

cleanup_dev_tools() {
    info "Cleaning Developer Tools..."
    
    # Xcode
    close_app "Xcode"
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
    rm -rf ~/Library/Developer/Xcode/Archives/* 2>/dev/null
    rm -rf ~/Library/Developer/Xcode/iOS\ Device\ Logs/* 2>/dev/null
    
    # Gradle
    [ -d "$HOME/.gradle/caches" ] && rm -rf "$HOME/.gradle/caches/" 2>/dev/null
    
    # Adobe
    execute_sudo "Clear Adobe Cache" rm -rf "$HOME/Library/Application Support/Adobe/Common/Media Cache Files/"* 2>/dev/null
    
    # Dropbox/Google Drive
    [ -d "$HOME/Dropbox/.dropbox.cache" ] && execute_sudo "Clear Dropbox" rm -rf "$HOME/Dropbox/.dropbox.cache/"* 2>/dev/null
    killall "Google Drive File Stream" 2>/dev/null || true
    rm -rf "$HOME/Library/Application Support/Google/DriveFS/"*"/content_cache" 2>/dev/null
    
    # Docker
    if command -v docker &>/dev/null; then
         info "Pruning Docker..."
         docker system prune -af 2>/dev/null || true
    fi
    
    # NPM/Yarn
    if command -v npm &>/dev/null; then npm cache clean --force 2>/dev/null; fi
    if command -v yarn &>/dev/null; then yarn cache clean --force 2>/dev/null; fi
    
    # Homebrew
    if command -v brew &>/dev/null; then 
        brew cleanup -s 2>/dev/null
        rm -rf "$(brew --cache)" 2>/dev/null
    fi
    
    # Ruby/Gems
    if command -v gem &>/dev/null; then gem cleanup 2>/dev/null; fi
    
    info "Developer tools cleanup finished."
}

cleanup_ios_data() {
    info "Cleaning iOS Data..."
    # iTunes Apps/Photo Cache
    rm -rf "$HOME/Music/iTunes/iTunes Media/Mobile Applications/"* 2>/dev/null
    rm -rf "$HOME/Pictures/iPhoto Library/iPod Photo Cache/"* 2>/dev/null
    
    # Backups
    rm -rf "$HOME/Library/Application Support/MobileSync/Backup/"* 2>/dev/null
    
    # Simulators
    if command -v xcrun &>/dev/null; then
        close_app "Simulator"
        xcrun simctl shutdown all 2>/dev/null
        xcrun simctl erase all 2>/dev/null
    fi
    
    # Connected Devices History
    defaults delete "$HOME/Library/Preferences/com.apple.iPod.plist" "conn:128:Last Connect" 2>/dev/null || true
    defaults delete "$HOME/Library/Preferences/com.apple.iPod.plist" Devices 2>/dev/null || true
    execute_sudo "Clear Lockdown" rm -rf /var/db/lockdown/* 2>/dev/null
    
    info "iOS data cleanup finished."
}


remove_file_metadata() {
    local file="$1"
    if [ -z "$file" ]; then
        error "No file specified."
        return 1
    fi
    
    if [ ! -e "$file" ]; then
        error "File not found: $file"
        return 1
    fi

    info "Removing metadata from $file..."
    xattr -d com.apple.metadata:kMDItemWhereFroms "$file" 2>/dev/null || true
    xattr -d com.apple.quarantine "$file" 2>/dev/null || true
    info "Metadata removed."
}

cleanup_memory() {
    info "Clearing inactive memory..."
    execute_sudo "Purge Memory" purge
}

cleanup_quarantine() {
    info "Clearing File Quarantine Logs..."
    
    local db_file="$HOME/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
    
    if [ -f "$db_file" ]; then
        # Check for immutability
        if ls -lO "$db_file" | grep -q 'schg'; then
            execute_sudo "Unflag system immutable" chflags noschg "$db_file"
        fi
        if ls -lO "$db_file" | grep -q 'uchg'; then
             chflags nouchg "$db_file"
        fi
        
        # User requested robustness against schema changes/corruption.
        # The safest way is to remove the file entirely and let macOS recreate it.
        # This avoids assuming table names (like LSQuarantineEvent) or handling open DB locks.
        info "Removing Quarantine Database (recreation is automatic)..."
        rm -f "$db_file"
        
        # Optional: Recreate empty to prevent "missing file" checks if any? 
        # Usually not needed, but touch ensures it exists.
        # touch "$db_file"
    fi
    
    # Clear attributes from Downloads
    info "Removing quarantine attributes from ~/Downloads..."
    find "$HOME/Downloads" -type f -exec xattr -d com.apple.quarantine {} 2>/dev/null \; || true
}

close_app() {
    local proc_name="$1"
    local nice_name="${2:-$proc_name}"

    if pgrep -q "$proc_name"; then
        info "Closing $nice_name to safely clean data..."
        # Try standard kill (SIGTERM) first which allows cleanup
        killall "$proc_name" 2>/dev/null
        
        # Wait up to 5 seconds
        for i in {1..5}; do
            if ! pgrep -q "$proc_name"; then
                return 0
            fi
            sleep 1
        done
        
        # Force kill (SIGKILL) if stuck
        warn "$nice_name still running. Force quitting..."
        killall -9 "$proc_name" 2>/dev/null || true
    fi
}

cleanup_browsers() {
    info "Cleaning Browser Data..."
    
    # Chrome
    # Process name is "Google Chrome" on macOS
    close_app "Google Chrome"
    
    local chrome_dir="$HOME/Library/Application Support/Google/Chrome/Default"
    if [ -d "$chrome_dir" ]; then
        info "Cleaning Chrome History/Cache..."
        rm -rf "$chrome_dir/History" "$chrome_dir/History-journal" "$chrome_dir/Application Cache" 2>/dev/null
    fi
    
    # Safari
    # Process name is "Safari"
    close_app "Safari"
    
    info "Cleaning Safari Data..."
    rm -f "$HOME/Library/Safari/History.db"* 2>/dev/null
    rm -f "$HOME/Library/Safari/Downloads.plist" 2>/dev/null
    rm -f "$HOME/Library/Safari/LastSession.plist" 2>/dev/null
    rm -f "$HOME/Library/Safari/TopSites.plist" 2>/dev/null
    rm -f "$HOME/Library/Safari/WebpageIcons.db" 2>/dev/null
    rm -rf "$HOME/Library/Caches/com.apple.Safari/Cache.db" 2>/dev/null
    rm -rf "$HOME/Library/Caches/com.apple.Safari/Webpage Previews" 2>/dev/null
    rm -f "$HOME/Library/Cookies/Cookies.binarycookies" 2>/dev/null
    
    # Firefox
    # Process name is "firefox" or "Firefox" depending on version/launch, usually "Firefox" match
    # pgrep -f might be safer or just pgrep -x Firefox
    close_app "firefox" "Firefox"
    
    local firefox_dir="$HOME/Library/Application Support/Firefox/Profiles"
    if [ -d "$firefox_dir" ]; then
        info "Cleaning Firefox Data (Cookies, Form History)..."
        # Find all profiles
        find "$firefox_dir" -name "*.default*" -type d | while read -r profile; do
            rm -f "$profile/cookies.sqlite"* 2>/dev/null
            rm -f "$profile/formhistory.sqlite" 2>/dev/null
            rm -fv "$profile/sessionstore"* 2>/dev/null
            rm -rf "$profile/storage/default/http"* 2>/dev/null
        done
        
        rm -rf "$HOME/Library/Caches/Mozilla" 2>/dev/null
    fi
    
    info "Browser cleanup finished."
}
