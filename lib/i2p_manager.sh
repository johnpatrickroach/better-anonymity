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
        # User reported: /opt/homebrew/Cellar/i2p/2.10.0/libexec/runplain.sh
        # brew --prefix i2p points to opted version (linked).
        local runplain="$brew_prefix/libexec/runplain.sh"
        
        if [[ -f "$runplain" ]]; then
             info "Found runner: $runplain"
             # Run in background, detached. Use 'sh' to ensure it runs even if +x is missing.
             nohup sh "$runplain" >/dev/null 2>&1 &
             local pid=$!
             success "I2P started via runplain.sh (PID: $pid)"
             return 0
        else
             error "Could not find 'runplain.sh' at $runplain"
             return 1
        fi
    elif [ $start_code -eq 0 ]; then
        success "I2P Router started."
    else
        error "Failed to start I2P Router."
        return 1
    fi
}

function i2p_stop() {
    info "Stopping I2P Router..."
    if ! command -v i2prouter &> /dev/null; then
         error "i2prouter command not found."
         return 1
    fi

    # Try standard stop
    if i2prouter stop; then
        success "I2P Router stopped."
        return 0
    fi
    
    # Fallback: Kill java process if runplain was used
    # Identify by main java class 'net.i2p.router.Router'
    warn "Standard stop failed. Checking for fallback process..."
    local pids
    pids=$(pgrep -f "net.i2p.router.Router")
    
    if [ -n "$pids" ]; then
        info "Found I2P java process(es): $pids. Killing..."
        kill $pids
        sleep 1
        if pgrep -f "net.i2p.router.Router" >/dev/null; then
            kill -9 $pids 2>/dev/null
        fi
        success "I2P process stopped manually."
    else
        warn "No running I2P process found."
    fi
}

function i2p_restart() {
    info "Restarting I2P Router..."
    if command -v i2prouter &> /dev/null; then
        i2prouter restart
        success "I2P Router restarted."
    else
        error "i2prouter command not found."
        return 1
    fi
}

function i2p_status() {
    header "I2P Service Status"
    if ! command -v i2prouter &> /dev/null; then
        echo "I2P is not installed or not in PATH."
        return
    fi
    
    # Check wrapper status
    local status_out
    status_out=$(i2prouter status 2>&1)
    echo "$status_out"
    
    # Check fallback process if wrapper says not running
    if echo "$status_out" | grep -q "not running"; then
         if pgrep -f "net.i2p.router.Router" >/dev/null; then
             local pids
             pids=$(pgrep -f "net.i2p.router.Router" | tr '\n' ',' | sed 's/,$//')
             echo "NOTE: I2P appears to be running via fallback (Java process found)."
             echo "PID: $pids"
         fi
    fi
}

function i2p_console() {
    info "Opening I2P Router Console..."
    # Default console URL is http://127.0.0.1:7657
    open "http://127.0.0.1:7657/home"
}

function i2p_info() {
    header "about: I2P (Invisible Internet Project)"
    echo "I2P is an anonymous network layer that allows for censorship-resistant,"
    echo "peer-to-peer communication. Anonymous connections are achieved by"
    echo "encrypting the user's traffic (by end-to-end encryption) and sending it"
    echo "through a volunteer-run network of roughly 55,000 computers distributed" 
    echo "around the world."
    echo ""
    echo "Commands:"
    echo "  install  - Install I2P via Homebrew"
    echo "  start    - Start the I2P router"
    echo "  stop     - Stop the I2P router"
    echo "  status   - Check router status"
    echo "  console  - Open the web console"
}
