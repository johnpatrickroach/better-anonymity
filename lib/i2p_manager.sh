#!/bin/bash

# lib/i2p_manager.sh
# Manages I2P installation and service (via brew)

function i2p_install() {
    require_brew
    info "Installing I2P (Invisible Internet Project)..."
    
    # Check java dependency manually if needed, but brew usually handles it.
    # We install the formula 'i2p'.
    if is_brew_installed "i2p"; then
        info "I2P is already installed."
    else
        brew install i2p
    fi
    
    # Post-install info
    success "I2P installed."
    echo ""
    echo "To run I2P, you can use the 'better-anonymity i2p start' command."
    echo "This will launch the I2P router in the background."
}

function i2p_start() {
    info "Starting I2P Router..."
    # 'i2prouter' script is provided by the brew formula
    if command -v i2prouter &> /dev/null; then
        i2prouter start
        success "I2P Router started."
    else
        error "i2prouter command not found. Is I2P installed?"
        return 1
    fi
}

function i2p_stop() {
    info "Stopping I2P Router..."
    if command -v i2prouter &> /dev/null; then
        i2prouter stop
        success "I2P Router stopped."
    else
        error "i2prouter command not found."
        return 1
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
    if command -v i2prouter &> /dev/null; then
        i2prouter status
    else
        echo "I2P is not installed or not in PATH."
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
