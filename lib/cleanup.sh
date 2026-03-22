#!/bin/bash

# lib/cleanup.sh
# Metadata and artifact cleanup functions

cleanup_metadata() {
    warn "This process will delete cached data, recent file history, and other metadata artifacts."
    warn "Some applications may lose state (e.g. open windows, unsaved changes)."
    if ! ask_confirmation "Are you sure you want to proceed with Metadata Cleanup?"; then
        return 0
    fi

    info "Initializing background sudo session for cleanup..."
    start_sudo_keepalive || return 1
    
    # Hijack execute_sudo to collect privileged tasks
    local orig_execute_sudo
    orig_execute_sudo=$(declare -f execute_sudo)
    local deferred_sudo_script
    deferred_sudo_script=$(mktemp)
    echo "#!/bin/bash" > "$deferred_sudo_script"
    
    execute_sudo() {
        local desc="$1"
        shift
        info "Queueing privileged task: $desc"
        printf "%q " "$@" >> "$deferred_sudo_script"
        echo "" >> "$deferred_sudo_script"
    }


    # 1. QuickLook Cache
    info "Cleaning QuickLook Cache..."
    # 'qlmanage -r disablecache' is deprecated/invalid on newer macOS.
    # We rely on 'qlmanage -r cache' (reset) below.
    
    local user_cache_dir
    user_cache_dir=$(getconf DARWIN_USER_CACHE_DIR)
    
    # Try aggressive remove, but suppress errors (SIP/Permissions)
    execute_sudo "Remove QL Thumbnails" bash -c "rm -rf \"$user_cache_dir/com.apple.QuickLook.thumbnailcache\" 2>/dev/null || true"
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
    execute_sudo "Clear Bluetooth & CUPS Cache" bash -c '
        if [ -f /Library/Preferences/com.apple.Bluetooth.plist ]; then
            defaults delete /Library/Preferences/com.apple.Bluetooth.plist DeviceCache 2>/dev/null || true
        fi
        rm -rf /var/spool/cups/c0* /var/spool/cups/tmp/* /var/spool/cups/cache/job.cache* 2>/dev/null || true
    ' || true

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

    # 8. Wi-Fi NVRAM & DNS Cache (Sudo)
    info "Clearing Wi-Fi NVRAM and Flushing DNS Cache..."
    execute_sudo "Clear NVRAM & DNS Cache" bash -c '
        nvram -d 36C28AB5-6566-4C50-9EBD-CBB920F83843:preferred-networks 2>/dev/null || true
        dscacheutil -flushcache 2>/dev/null || true
        killall -HUP mDNSResponder 2>/dev/null || true
    ' || true

    # 10. System Logs & Audits
    if ask_confirmation "Clear System & App Logs (Aggressive)?"; then
        cleanup_logs
    fi

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
    
    # Execute all queued sudo tasks in ONE batch before Quarantine
    if [ "$(wc -l < "$deferred_sudo_script" | tr -d ' ')" -gt 1 ]; then
        info "Executing all queued privileged tasks (requires password once)..."
        eval "$orig_execute_sudo"
        execute_sudo "Batch Privileged Tasks" bash "$deferred_sudo_script"
    else
        eval "$orig_execute_sudo"
    fi
    rm -f "$deferred_sudo_script"
    
    # 17. Quarantine (Aggressive)
    if ask_confirmation "Clear Quarantine History (Downloaded files logs)?"; then
        cleanup_quarantine
    fi

    stop_sudo_keepalive
    info "Metadata cleanup completed."
}

cleanup_trash() {
    info "Emptying Trash..."
    
    # 1. Main User Trash (Force delete with sudo to handle locked files)
    execute_sudo "Empty Main Trash (~/.Trash)" rm -rf "$HOME/.Trash/"* 2>/dev/null || true

    # 2. External Volumes (Targeting current User UID)
    # macOS stores external trash in .Trashes/<UID>
    local my_uid
    my_uid=$(id -u)
    
    # Enable nullglob to handle no matches
    shopt -s nullglob
    for vol in /Volumes/*; do
        local trash_dir="$vol/.Trashes/$my_uid"
        if [ -d "$trash_dir" ]; then
             info "Emptying Trash on volume: $(basename "$vol")"
             execute_sudo "Empty Vol Trash" rm -rf "$trash_dir/"* 2>/dev/null || true
        fi
    done
    shopt -u nullglob
}

cleanup_receipts() {
    info "Clearing Installation Receipts..."
    execute_sudo "Remove Receipts & History" bash -c '
        rm -rf /private/var/db/receipts/* 2>/dev/null
        rm -f /Library/Receipts/InstallHistory.plist 2>/dev/null
    ' || true
}

cleanup_logs() {
    info "Clearing Logs (System, User, Mail, Diagnostics)..."
    
    # 1. System & Diagnostic Logs
    execute_sudo "Clear System & Diagnostic Logs" bash -c '
        rm -rf /private/var/log/asl/* 2>/dev/null
        rm -rf /private/var/audit/* 2>/dev/null
        rm -rf /private/var/log/install.log /Library/Logs/install.log 2>/dev/null
        rm -rf /Library/Logs/* 2>/dev/null
        rm -rf /private/var/db/diagnostics/* 2>/dev/null
        rm -rf /private/var/db/uuidtext/* 2>/dev/null
        rm -f /private/var/log/daily.out /private/var/log/weekly.out /private/var/log/monthly.out 2>/dev/null
    ' || true
    
    # 2. General User Logs
    rm -rf "$HOME/Library/Logs/"* 2>/dev/null
    
    # 3. Shell History (Privacy.sexy)
    if [ -f "$HOME/.bash_history" ]; then
         info "Clearing Bash History..."
         rm -f "$HOME/.bash_history" 2>/dev/null
    fi
     if [ -f "$HOME/.zsh_history" ]; then
         info "Clearing Zsh History..."
         rm -f "$HOME/.zsh_history" 2>/dev/null
    fi
    
    # 4. Mail Logs
    local mail_logs="$HOME/Library/Containers/com.apple.mail/Data/Library/Logs/Mail"
    if [ -d "$mail_logs" ]; then
        info "Clearing Mail Logs..."
        rm -rf "$mail_logs/"* 2>/dev/null
    fi
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

cleanup_system_cache() {
    info "Clearing System Caches (Aggressive - Privacy.sexy)..."
    # /System/Library/Caches is usually protected by SIP, so we try but ignore errors
    # /Library/Caches is writable by root
    execute_sudo "Clear System Caches" bash -c '
        rm -rf /Library/Caches/* 2>/dev/null || true
        rm -rf /System/Library/Caches/* 2>/dev/null || true
    ' || true
    
    # Also User Caches (Aggressive)
    rm -rf "$HOME/Library/Caches/"* 2>/dev/null
    success "System Caches cleared."
}


cleanup_quarantine() {
    info "Clearing File Quarantine Logs..."
    
    local db_file="$HOME/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
    
    if [ -f "$db_file" ]; then
        local has_schg=false
        local has_uchg=false
        
        # Check for immutability
        if ls -lO "$db_file" | grep -q 'schg'; then
            execute_sudo "Unflag system immutable" chflags noschg "$db_file"
            has_schg=true
        fi
        if ls -lO "$db_file" | grep -q 'uchg'; then
             chflags nouchg "$db_file"
             has_uchg=true
        fi
        
        # Try sqlite3 cleaning first (Cleaner, preserves inode/permissions)
        local cleaned_via_sql=false
        if command -v sqlite3 >/dev/null 2>&1; then
            info "Attempting to clean Quarantine Database via sqlite3..."
            if sqlite3 "$db_file" "DELETE FROM LSQuarantineEvent; VACUUM;" 2>/dev/null; then
                success "Quarantine History cleared (via SQL)."
                cleaned_via_sql=true
            else
                warn "sqlite3 cleanup failed (Database locked or schema changed?). Falling back to file deletion."
            fi
        else
            info "sqlite3 not found. Falling back to file deletion."
        fi

        if [ "$cleaned_via_sql" = false ]; then
            info "Removing Quarantine Database file..."
            rm -f "$db_file"
            
            # Recreate empty to maintain file existence for system monitors
            touch "$db_file"
            success "Quarantine History cleared (file deleted and recreated)."
        fi
        
        # Restore flags if they were present
        if [ "$has_schg" = true ]; then
             execute_sudo "Restore system immutable" chflags schg "$db_file"
             info "Restored system immutable flag."
        fi
         if [ "$has_uchg" = true ]; then
             chflags uchg "$db_file"
             info "Restored user immutable flag."
        fi
    fi
    
    # Clear attributes from Downloads
    info "Removing quarantine attributes from ~/Downloads..."
    find "$HOME/Downloads" -type f -exec xattr -d com.apple.quarantine {} 2>/dev/null \; || true
}

close_app() {
    local proc_name="$1"
    local nice_name="${2:-$proc_name}"

    local pgrep_cmd="${PGREP_CMD:-pgrep}"
    local killall_cmd="${KILLALL_CMD:-killall}"

    # Use -x for exact match to avoid partial matches
    if $pgrep_cmd -x "$proc_name" >/dev/null; then
        if ask_confirmation "$nice_name is currently running. Close it to safely clean data?"; then
            info "Closing $nice_name to safely clean data..."
            # Try standard kill (SIGTERM) first which allows cleanup
            $killall_cmd "$proc_name" 2>/dev/null
            
            # Wait up to 5 seconds
            for i in {1..5}; do
                if ! $pgrep_cmd -x "$proc_name" >/dev/null; then return 0; fi
                sleep 1
            done
            
            # Force kill (SIGKILL) if stuck
            warn "$nice_name still running. Force quitting..."
            $killall_cmd -9 "$proc_name" 2>/dev/null || true
        else
            warn "Skipping cleanup for $nice_name (Application must be closed)."
            return 1
        fi
    fi
    return 0
}

cleanup_browsers() {
    info "Cleaning Browser Data..."
    
    # --- Chrome ---
    if close_app "Google Chrome"; then
        # 1. Cache (Global)
        rm -rf "$HOME/Library/Caches/Google/Chrome/"* 2>/dev/null
        
        # 2. Profiles (History, Cookies, Session)
        local chrome_root="$HOME/Library/Application Support/Google/Chrome"
        if [ -d "$chrome_root" ]; then
            # Iterate Default and Profile directories
            for profile in "$chrome_root"/Default "$chrome_root"/Profile*; do
                if [ -d "$profile" ]; then
                    info "Cleaning Chrome Profile: $(basename "$profile")..."
                    rm -rf "$profile/History"* 2>/dev/null
                    rm -rf "$profile/Visited Links" 2>/dev/null
                    rm -rf "$profile/Last Session" 2>/dev/null
                    rm -rf "$profile/Last Tabs" 2>/dev/null
                    rm -rf "$profile/Top Sites"* 2>/dev/null
                    rm -rf "$profile/Application Cache" 2>/dev/null
                    rm -rf "$profile/GPUCache" 2>/dev/null
                    # Optional: Cookies? User asked for History & Cache. 
                    # Keeping cookies might be preferred for convenience, but "Cleanup" usually implies tracking data.
                    # Let's clean Cookies too if we are being thorough, or stick to History?
                    # The prompt says "Browser History & Cache".
                    # rm -f "$profile/Cookies" 2>/dev/null
                fi
            done
        fi
    fi
    
    # --- Safari ---
    if close_app "Safari"; then
    
    info "Cleaning Safari Data..."
    rm -f "$HOME/Library/Safari/History.db"* 2>/dev/null
    rm -f "$HOME/Library/Safari/Downloads.plist" 2>/dev/null
    rm -f "$HOME/Library/Safari/LastSession.plist" 2>/dev/null
    rm -f "$HOME/Library/Safari/TopSites.plist" 2>/dev/null
    rm -f "$HOME/Library/Safari/WebpageIcons.db" 2>/dev/null
    rm -f "$HOME/Library/Safari/WebpageIcons.db" 2>/dev/null
    rm -rf "$HOME/Library/Caches/com.apple.Safari/"* 2>/dev/null
    rm -rf "$HOME/Library/Caches/Metadata/Safari/"* 2>/dev/null
    rm -rf "$HOME/Library/Containers/com.apple.Safari/Data/Library/Caches/"* 2>/dev/null
    rm -rf "$HOME/Library/Containers/com.apple.Safari/Data/Library/Caches/"* 2>/dev/null
    # Cookies
    rm -f "$HOME/Library/Cookies/Cookies.binarycookies" 2>/dev/null
    rm -f "$HOME/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies" 2>/dev/null
    
    # Per-Site Preferences (Privacy.sexy)
    rm -f "$HOME/Library/Safari/PerSitePreferences.db" 2>/dev/null
    rm -f "$HOME/Library/Safari/PerSiteZoomPreferences.plist" 2>/dev/null
    rm -f "$HOME/Library/Safari/UserNotificationPreferences.plist" 2>/dev/null
    fi
    
    # --- Firefox ---
    if close_app "firefox" "Firefox"; then
    
    local firefox_dir="$HOME/Library/Application Support/Firefox/Profiles"
    if [ -d "$firefox_dir" ]; then
        info "Cleaning Firefox Data..."
        
        # Cache
        # Cache & Crash Reports
        rm -rf "$HOME/Library/Caches/Mozilla/Firefox/"* 2>/dev/null
        rm -rf "$HOME/Library/Application Support/Firefox/Crash Reports/"* 2>/dev/null
        
        # Profiles
        find "$firefox_dir" -name "*.default*" -type d | while read -r profile; do
            info "Processing Firefox Profile: $(basename "$profile")"
            rm -f "$profile/cookies.sqlite"* 2>/dev/null
            rm -f "$profile/forms.sqlite" 2>/dev/null
            rm -f "$profile/formhistory.sqlite" 2>/dev/null
            rm -f "$profile/sessionstore"* 2>/dev/null
            
            # Passwords & Crash Reports (Aggressive - Privacy.sexy)
            rm -f "$profile/logins.json" 2>/dev/null
            rm -f "$profile/signons.sqlite" 2>/dev/null
            rm -f "$profile/key3.db" 2>/dev/null
            rm -f "$profile/key4.db" 2>/dev/null
            rm -rf "$profile/minidumps/"* 2>/dev/null
            rm -rf "$profile/bookmarkbackups/"* 2>/dev/null
            rm -f "$profile/webappsstore.sqlite" 2>/dev/null
            
            rm -rf "$profile/storage/default/http"* 2>/dev/null
            
            # History (places.sqlite) - Use SQL to preserve Bookmarks
            if command -v sqlite3 >/dev/null; then
                 # Delete history visits and non-bookmarked places
                 sqlite3 "$profile/places.sqlite" "DELETE FROM moz_historyvisits; DELETE FROM moz_places WHERE id NOT IN (SELECT fk FROM moz_bookmarks); VACUUM;" 2>/dev/null || true
            else
                 # Fallback: Can't safely delete places.sqlite without losing bookmarks.
                 warn "sqlite3 not found. Skipping Firefox History (places.sqlite) to preserve bookmarks."
            fi
        done
    fi
    fi
    
    info "Browser cleanup finished."
}
