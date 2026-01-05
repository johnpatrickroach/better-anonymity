#!/bin/bash

# lib/checks.sh
# System audit and pre-flight checks

require_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This operation requires root privileges. Please run with sudo."
    fi
}

require_brew() {
    if ! command -v brew &> /dev/null; then
        warn "Homebrew not found. Attempting to locate based on architecture..."
        if [ -x "$BREW_PREFIX/bin/brew" ]; then
             # Already exported in platform.sh presumably, but ensuring PATH
             export PATH="$BREW_PREFIX/bin:$PATH"
             info "Found Homebrew at $BREW_PREFIX/bin/brew."
        else
            if ask_confirmation "Homebrew is required but not found. Install it?"; then
                 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                 # Re-check
                 if [ -x "$BREW_PREFIX/bin/brew" ]; then
                    export PATH="$BREW_PREFIX/bin:$PATH"
                 else
                    die "Homebrew installation failed or path unavailable."
                 fi
            else
                die "Homebrew is required to proceed."
            fi
        fi
    fi
}

check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        warn "No internet connection detected. Network-dependent steps may fail."
    fi
}
