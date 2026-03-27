#!/bin/bash

# lib/browser_hardening.sh
# Extreme offline browser hardening implementation

harden_browser_profiles() {
    header "Aggressively Hardening Browsers..."
    
    local legacy_js="$CONFIG_DIR/browser/user.js"
    
    if [ ! -f "$legacy_js" ]; then
        # Try local path for dev
        legacy_js="config/browser/user.js"
        if [ ! -f "$legacy_js" ]; then
            error "Browser hardening profile asset missing! Looked for $CONFIG_DIR/browser/user.js"
            return 1
        fi
    fi
    
    # Ensure installers is loaded to use get_firefox_profile
    load_module "installers"
    
    local profile_path
    if ! profile_path=$(get_firefox_profile); then
         warn "Firefox profile not found. Cannot inject browser lock-down."
         return 1
    fi
    
    local backup_ts
    backup_ts=$(date +%Y%m%d%H%M%S)
    
    info "Target Firefox Profile: $(basename "$profile_path")"
    
    # Backup existing
    if [ -f "$profile_path/user.js" ]; then
        info "Creating backup of existing user.js..."
        execute_sudo "Backup user.js" cp "$profile_path/user.js" "$profile_path/user.js.old.$backup_ts"
    fi
    
    if [ -f "$profile_path/prefs.js" ]; then
        info "Creating backup of existing prefs.js..."
        execute_sudo "Backup prefs.js" cp "$profile_path/prefs.js" "$profile_path/prefs.js.old.$backup_ts"
    fi
    
    info "Injecting better-anonymity static user.js..."
    
    # Copy new user.js into profile
    execute_sudo "Inject user.js" cp "$legacy_js" "$profile_path/user.js"
    
    info "Flushing cached preferences..."
    # If prefs.js is not deleted, Firefox might not pick up user.js correctly or might clash
    # Actually, user.js overwrites prefs.js on startup. We don't need to delete prefs.js
    # But sometimes forcing it is safer
    
    # Track Files so they can be removed on `b-a uninstall`
    local state_dir="$HOME/.better-anonymity/state"
    mkdir -p "$state_dir"
    {
        echo "$profile_path/user.js"
    } >> "$state_dir/installed_files.log"
    
    save_state_var "STATE_BROWSER_HARDENING" "enabled"
    
    success "Browser permanently locked down against WebRTC/Fingerprinting/Telemetry."
    info "Please fully restart Firefox for all settings to inject."
}
