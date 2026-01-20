#!/bin/bash

# lib/captive.sh
# Captive Portal Monitoring and Auto-Resolution (Service)

CAPTIVE_CHECK_URL="http://captive.apple.com/hotspot-detect.html"
CAPTIVE_TRIGGER_URL="http://neverssl.com"
CAPTIVE_CHECK_INTERVAL=10 # Seconds
CAPTIVE_PID_FILE="/var/run/better_anonymity_captive.pid"
CAPTIVE_LOG_FILE="/var/log/better_anonymity_captive.log"

# Check if Wi-Fi interface is connected (associated)
captive_is_wifi_connected() {
    if [ "$PLATFORM_OS" == "mac" ]; then
        if command -v networksetup &>/dev/null; then
            load_module "platform"
            detect_active_network
            if [[ "$PLATFORM_ACTIVE_SERVICE" == *"Wi-Fi"* ]]; then
                 # Check if associated
                 local wifi_net
                 wifi_net=$(networksetup -getairportnetwork "$PLATFORM_ACTIVE_INTERFACE" 2>/dev/null)
                 if [[ "$wifi_net" == *"Current Wi-Fi Network"* ]]; then
                     return 0
                 fi
            fi
        fi
    fi
    return 1
}

# Check connectivity state
# Returns: 0 (ONLINE), 1 (OFFLINE/BLOCKED), 2 (PORTAL DETECTED)
captive_check_state() {
    local response
    response=$(curl -s --max-time 5 "$CAPTIVE_CHECK_URL" 2>&1)
    
    if [[ "$response" == *"Success"* ]]; then
        return 0 # ONLINE (Apple success page)
    fi
    
    if [[ "$response" == *"<html"* ]] || [[ "$response" == *"<HTML"* ]]; then
        return 2 # PORTAL
    fi
    
    return 1 # OFFLINE/BLOCKED
}

# The main loop (Runs in background)
# NOTE: This must NOT be called directly with sudo auto-escalation inside,
# as it's meant to be spawned by captive_start
captive_loop() {
    # Ensure log directory exists (if using a custom one, but /var/log is standard)
    
    local in_portal_recovery=0
    
    while true; do
        if captive_is_wifi_connected; then
             captive_check_state
             local state=$?
             
             if [ $state -eq 0 ]; then
                 if [ $in_portal_recovery -eq 1 ]; then
                     log_to_file "Internet restored. Re-enabling anonymity..."
                     notify_user "Network Monitor" "Internet restored. Re-enabling anonymity..."
                     network_enable_anonymity >> "$CAPTIVE_LOG_FILE" 2>&1
                     in_portal_recovery=0
                 else
                     : # Normal state
                 fi
             elif [ $state -eq 2 ] || [ $state -eq 1 ]; then
                 if [ $in_portal_recovery -eq 0 ]; then
                     log_to_file "Connection Frozen! (State: $state). Switching to Open Mode..."
                     notify_user "Network Monitor" "Captive Portal probable. Switching to Open Mode..."
                     
                     network_restore_default >> "$CAPTIVE_LOG_FILE" 2>&1
                     
                     if [ -n "$SUDO_USER" ]; then
                         sudo -u "$SUDO_USER" open "$CAPTIVE_TRIGGER_URL"
                     else
                         open "$CAPTIVE_TRIGGER_URL"
                     fi
                     
                     in_portal_recovery=1
                 fi
                 sleep 5
                 continue
             fi
        else
            if [ $in_portal_recovery -eq 1 ]; then
                log_to_file "Wi-Fi disconnected. Resetting state."
                in_portal_recovery=0
            fi
        fi
        sleep "$CAPTIVE_CHECK_INTERVAL"
    done
}

# Logging helper
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$CAPTIVE_LOG_FILE"
}

notify_user() {
    local title="$1"
    local msg="$2"
    
    if [ -n "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
    else
        osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
    fi
}

# Service Management Functions

captive_start() {
    ensure_root "Captive Service Start"
    
    if [ -f "$CAPTIVE_PID_FILE" ]; then
        local pid
        pid=$(cat "$CAPTIVE_PID_FILE")
        if ps -p "$pid" > /dev/null; then
            warn "Captive monitor is already running (PID: $pid)."
            return
        else
            rm "$CAPTIVE_PID_FILE"
        fi
    fi
    
    header "Starting Captive Monitor Service"
    info "Service will run in background."
    info "Logs: $CAPTIVE_LOG_FILE"
    
    # Launch in background
    # We must call the script again with a special internal command to run the loop
    # $0 is the better-anonymity script.
    
    nohup "$0" captive run >> "$CAPTIVE_LOG_FILE" 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$CAPTIVE_PID_FILE"
    
    success "Started Captive Monitor (PID: $new_pid)"
}

captive_stop() {
    ensure_root "Captive Service Stop"
    
    if [ ! -f "$CAPTIVE_PID_FILE" ]; then
        warn "No PID file found. Is the service running?"
        return
    fi
    
    local pid
    pid=$(cat "$CAPTIVE_PID_FILE")
    
    if ps -p "$pid" > /dev/null; then
        info "Stopping process $pid..."
        kill "$pid"
        rm "$CAPTIVE_PID_FILE"
        success "Captive Monitor stopped."
    else
        warn "Process $pid not found. Cleaning up PID file."
        rm "$CAPTIVE_PID_FILE"
    fi
}

captive_status() {
    if [ -f "$CAPTIVE_PID_FILE" ]; then
        local pid
        pid=$(cat "$CAPTIVE_PID_FILE")
        if ps -p "$pid" > /dev/null; then
            info "Captive Monitor is RUNNING (PID: $pid)"
            return 0
        else
            warn "PID file exists but process $pid is dead."
            return 1
        fi
    else
        info "Captive Monitor is STOPPED."
        return 3
    fi
}

captive_help() {
    echo "Usage: better-anonymity captive [command]"
    echo ""
    echo "Commands:"
    echo "  start    Start the monitor service in background (set & forget)."
    echo "  stop     Stop the background service."
    echo "  status   Check service status."
    echo "  monitor  Launch monitor in a new terminal window (recommended)."
    echo "  run      Run in foreground (current terminal)."
    echo ""
    echo "Aliases:"
    echo "  stay-connected -> better-anonymity captive monitor"
}

# Internal wrapper for background process
captive_run() {
    ensure_root "Captive Service Run"
    
    # Check if run directly from CLI (interactive) or service
    if [ -t 1 ]; then
        # Interactive foreground run
        captive_loop
    else
        # Service background run
        log_to_file "Service started."
        captive_loop
    fi
}

captive_monitor_window() {
    info "Launching Captive Monitor in new window..."
    osascript -e "tell application \"Terminal\" to do script \"sudo better-anonymity captive run\""
}

captive_dispatcher() {
    local cmd="$1"
    
    # If no subcommand, default to help
    if [ -z "$cmd" ]; then
        captive_help
        return
    fi
    
    case "$cmd" in
        start)
            captive_start
            ;;
        stop)
            captive_stop
            ;;
        status)
            captive_status
            ;;
        run)
            # Auto-escalate if not root
             if [ "$(id -u)" -ne 0 ]; then
                info "Captive Monitor requires root privileges."
                exec sudo "$0" captive run
            fi
            captive_run
            ;;
        monitor|window) # 'window' kept for backward compat, monitor is new standard
            captive_monitor_window
            ;;
        help|--help|-h)
            captive_help
            ;;
        *)
            error "Unknown captive command: $cmd"
            captive_help
            ;;
    esac
}
