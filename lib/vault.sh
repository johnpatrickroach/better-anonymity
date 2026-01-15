#!/bin/bash

# lib/vault.sh
# GPG-based Password Vault (Simple, Symmetrical by default)

VAULT_DIR="$HOME/.better-anonymity/vault"

vault_init() {
    if [ ! -d "$VAULT_DIR" ]; then
        info "Initializing Vault at $VAULT_DIR..."
        mkdir -p "$VAULT_DIR"
        chmod 700 "$VAULT_DIR"
        success "Vault initialized."
    else
        info "Vault already exists at $VAULT_DIR."
    fi
}

vault_write() {
    local name="$1"
    if [ -z "$name" ]; then
        echo -n "Enter secret name (e.g. github): "
        read -r name
    fi
    
    if [ -z "$name" ]; then
        error "No name provided."
        return 1
    fi
    
    vault_init
    
    local target_file="$VAULT_DIR/${name}.gpg"
    if [ -f "$target_file" ]; then
        if ! ask_confirmation "Secret exists. Overwrite?"; then
            return 0
        fi
    fi
    
    local password=""
    if ask_confirmation "Generate a secure password?"; then
        # Use existing utils if sourced, simplistic fallback if not
        if type generate_password >/dev/null 2>&1; then
             password=$(generate_password 5)
        else
             # Failover simple generator
             password=$(openssl rand -base64 24)
        fi
        
        if command -v pbcopy >/dev/null 2>&1; then
             echo -n "$password" | pbcopy
             info "Generated password copied to clipboard."
        else
             # Fallback only if no clipboard (e.g. strict headless)
             # But unsafe to print.
             warn "Clipboard not available. Password generated but not displayed to prevent logs."
             warn "You can view it after encryption via 'vault read $name'."
        fi
    else
        echo -n "Enter Password: "
        read -rs password
        echo
        echo -n "Confirm Password: "
        read -rs confirm
        echo
        if [ "$password" != "$confirm" ]; then
            error "Passwords do not match."
            return 1
        fi
    fi
    
    info "Encrypting..."
    # Symmetric encryption by default.
    # --armor for text output, --output to file
    echo "$password" | gpg --symmetric --armor --output "$target_file"
    
    if [ $? -eq 0 ]; then
        chmod 600 "$target_file"
        success "Secret '$name' saved."
    else
        error "Encryption failed."
        return 1
    fi
}

vault_read() {
    local name="$1"
    if [ -z "$name" ]; then
        echo -n "Enter secret name to read: "
        read -r name
    fi
    
    local target_file="$VAULT_DIR/${name}.gpg"
    if [ ! -f "$target_file" ]; then
        error "Secret not found: $name"
        return 1
    fi
    
    info "Decrypting '$name'..."
    local decrypted
    decrypted=$(gpg --decrypt --quiet "$target_file")
    
    if [ $? -eq 0 ]; then
        echo "--- SECRET START ---"
        echo "$decrypted"
        echo "--- SECRET END ---"
        
        # Clipboard support if available (pbcopy on Mac)
        if command -v pbcopy >/dev/null 2>&1; then
            echo -n "$decrypted" | pbcopy
            info "Secret copied to clipboard (clearing in 15s)..."
            (sleep 15 && echo -n "" | pbcopy) &
        fi
    else
        error "Decryption failed."
        return 1
    fi
}

vault_list() {
    vault_init
    info "Vault Contents:"
    ls -1 "$VAULT_DIR" | sed 's/\.gpg$//'
}
