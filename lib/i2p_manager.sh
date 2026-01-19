#!/bin/bash

# lib/i2p_manager.sh
# Manages I2P installation and service (via brew)

function i2p_install() {
    require_brew
    info "Installing I2P (Invisible Internet Project)..."
    
    # Check java dependency manually if needed, but brew usually handles it.
    # We install the formula 'i2p'.
    # We install the formula 'i2p'.
    install_brew_package "i2p"
    
    # Post-install info
    success "I2P installed."
    echo ""
    echo "To run I2P, you can use the 'better-anonymity i2p start' command."
    echo "This will launch the I2P router in the background."
}

I2P_PID_FILE="/tmp/better-anonymity-i2p.pid"

function i2p_start() {
    info "Starting I2P Router..."
    
    if ! command -v i2prouter &> /dev/null; then
        error "i2prouter command not found. Is I2P installed?"
        return 1
    fi

    # Try standard start
    local start_out
    start_out=$(i2prouter start 2>&1)
    local start_code=$?
    echo "$start_out"

    # Check for wrapper failure
    if echo "$start_out" | grep -q "Failed to load the wrapper"; then
        warn "detected wrapper failure (common on Apple Silicon)."
        warn "Attempting fallback to 'runplain.sh'..."
        
        local brew_prefix
        # Resolve prefix dynamically
        if command -v brew &>/dev/null; then
            brew_prefix=$(brew --prefix i2p 2>/dev/null)
        fi
        
        if [ -z "$brew_prefix" ]; then
             # Fallback guess
             if [ -d "/opt/homebrew/opt/i2p" ]; then brew_prefix="/opt/homebrew/opt/i2p"; else brew_prefix="/usr/local/opt/i2p"; fi
        fi
        
        # Determine exact path. Structure is usuallylibexec/runplain.sh or just alongside.
        local runplain="$brew_prefix/libexec/runplain.sh"
        
        if [[ -f "$runplain" ]]; then
             info "Found runner: $runplain"
             # Run in background, detached. Use 'sh' to ensure it runs even if +x is missing.
             nohup sh "$runplain" >/dev/null 2>&1 &
             local pid=$!
             echo "$pid" > "$I2P_PID_FILE"
             success "I2P started via runplain.sh (PID: $pid)"
             return 0
        else
             error "Could not find 'runplain.sh' at $runplain"
             return 1
        fi
    elif [ $start_code -eq 0 ]; then
        # Standard start succeeded - clear any stale PID file
        /bin/rm -f "$I2P_PID_FILE"
        success "I2P Router started."
    else
        error "Failed to start I2P Router."
        return 1
    fi
}

function i2p_stop() {
    info "Stopping I2P Router..."
    
    local standard_stop_ok=false

    # Try standard stop first if available
    if command -v i2prouter &> /dev/null; then
        if i2prouter stop; then
             standard_stop_ok=true
             info "Standard stop command issued."
        else
             warn "Standard stop command reported failure."
        fi
    fi

    # Check PID file for fallback process
    if [ -f "$I2P_PID_FILE" ]; then
        local pid_from_file
        pid_from_file=$(cat "$I2P_PID_FILE")
        if [ -n "$pid_from_file" ] && kill -0 "$pid_from_file" 2>/dev/null; then
             info "Stopping fallback process via PID file (PID: $pid_from_file)..."
             kill "$pid_from_file"
             sleep 2
             if kill -0 "$pid_from_file" 2>/dev/null; then
                 kill -9 "$pid_from_file" 2>/dev/null
                 success "I2P process killed (SIGKILL)."
             else
                 success "I2P process stopped."
             fi
             /bin/rm -f "$I2P_PID_FILE"
             return 0
        else
            # Stale PID file
            /bin/rm -f "$I2P_PID_FILE"
        fi
    fi

    # Heuristic Fallback (Safety Net)
    # ALWAYS check for process cleanup even if PID file was missing
    # This ensures backward compatibility or manual start cleanup
    local pids
    pids=$(pgrep -u "$(id -u)" -f "net.i2p.router.Router")
    
    if [ -n "$pids" ]; then
        if [ "$standard_stop_ok" = true ]; then
            warn "Standard stop succeeded, but I2P process (PID: $pids) is still running."
        else
            info "Checking for I2P process (PID: $pids)..."
        fi
        
        info "Killing I2P Java process..."
        # Use array to safely handle multiple PIDs
        local pid_array=($pids)
        kill "${pid_array[@]}"
        sleep 2
        
        # Double check
        pids=$(pgrep -u "$(id -u)" -f "net.i2p.router.Router")
        if [ -n "$pids" ]; then
             local pid_array_kill=($pids)
             kill -9 "${pid_array_kill[@]}" 2>/dev/null
             success "I2P process killed (SIGKILL)."
        else
             success "I2P process stopped."
        fi
    else
        if [ "$standard_stop_ok" = true ]; then
            success "I2P Router stopped."
        else
            warn "No running I2P process found."
        fi
    fi
}

function i2p_restart() {
    info "Restarting I2P Router..."
    # Use stop+start to ensure fallback mechanisms are respected
    i2p_stop
    sleep 2
    i2p_start
}

function i2p_status() {
    local installed=true
    if ! command -v i2prouter &> /dev/null; then
        installed=false
    fi

    local lines=()
    local is_running=false

    # PID File Check
    if [ -f "$I2P_PID_FILE" ]; then
        local pid_from_file
        pid_from_file=$(cat "$I2P_PID_FILE")
        if [ -n "$pid_from_file" ] && kill -0 "$pid_from_file" 2>/dev/null; then
            lines+=("NOTE: I2P is running via fallback (PID: $pid_from_file tracked in $I2P_PID_FILE).")
            is_running=true
        fi
    fi

    # Fallback process info (Heuristic)
    if [ "$is_running" = false ]; then
        if pgrep -u "$(id -u)" -f "net.i2p.router.Router" >/dev/null; then
            local pids
            pids=$(pgrep -u "$(id -u)" -f "net.i2p.router.Router" | tr '\n' ',' | sed 's/,$//')
            lines+=("NOTE: I2P appears to be running via fallback (Java process matched).")
            lines+=("PID: $pids")
            is_running=true
        fi
    fi

    if [ "$installed" = false ] && [ "$is_running" = false ]; then
        section "I2P Service Status" \
            "I2P is not installed or not in PATH."
        return
    elif [ "$installed" = false ]; then
         lines+=("WARNING: 'i2prouter' command not found, but I2P process detected.")
    fi

    if [ "$installed" = true ]; then
        # Wrapper status
        local status_out
        status_out=$(i2prouter status 2>&1)
        while IFS= read -r line; do
            [ -n "$line" ] && lines+=("$line")
        done <<< "$status_out"
    fi

    section "I2P Service Status" "${lines[@]}"
}

function i2p_console() {
    info "Opening I2P Router Console..."
    # Default console URL is http://127.0.0.1:7657
    open "http://127.0.0.1:7657/home"
}

function i2p_info() {
    section "about: I2P (Invisible Internet Project)" \
        "I2P is an anonymous network layer that allows for censorship-resistant," \
        "peer-to-peer communication. Anonymous connections are achieved by" \
        "encrypting the user's traffic (by end-to-end encryption) and sending it" \
        "through a volunteer-run network of roughly 55,000 computers distributed" \
        "around the world." \
        "" \
        "Commands:" \
        "  install  - Install I2P via Homebrew" \
        "  start    - Start the I2P router" \
        "  stop     - Stop the I2P router" \
        "  status   - Check router status" \
        "  console  - Open the web console"
}
