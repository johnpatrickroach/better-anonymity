#!/usr/bin/env bash

# lib/ssh.sh
# Functions for SSH hardening (Server and Client)

SSH_CONFIG_SRC="$ROOT_DIR/config/ssh/ssh_config"
SSHD_CONFIG_SRC="$ROOT_DIR/config/ssh/sshd_config"

# ssh_check_sshd_status
# Checks if Remote Login is enabled.
ssh_check_sshd_status() {
    info "Checking SSH Server (Remote Login) status..."
    
    local status="Unknown"
    local detail=""
    
    # Method 1: Ask macOS systemsetup (Requires Root)
    # Use 'sudo -n' to check only if we already have privileges, fail silently otherwise.
    if sudo -n systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
        status="On"
        detail="(Confirmed via systemsetup)"
    elif sudo -n systemsetup -getremotelogin 2>/dev/null | grep -q "Off"; then
         status="Off"
         detail="(Confirmed via systemsetup)"
    else
        # Method 2: Check standard launchd service (Non-Root)
        # com.openssh.sshd is the standard label
        if launchctl list com.openssh.sshd &>/dev/null; then
             status="On"
             detail="(Service com.openssh.sshd is loaded)"
        else
             # Method 3: Port Check (Network)
             if check_port "localhost" 22; then
                 status="On"
                 detail="(Listening on Port 22)"
             else
                 status="Off"
                 detail="(Port 22 closed and service not loaded)"
             fi
        fi
    fi
    
    if [ "$status" == "On" ]; then
        echo -e "Remote Login: ${GREEN}On${NC} $detail"
        warn "Security Risk: Ensure 'Harden SSHD Config' has been run if this is intended."
    else
        echo -e "Remote Login: ${GREEN}Off${NC} $detail"
    fi
    
    echo ""
    ssh_audit_keys
}

# ssh_audit_keys
# Audits private keys in ~/.ssh/ for strong encryption and passphrases
ssh_audit_keys() {
    info "Auditing SSH Private Keys..."
    local ssh_dir="$HOME/.ssh"
    if [ ! -d "$ssh_dir" ]; then
        info "No SSH directory found (~/.ssh)."
        return 0
    fi

    local keys_found=0
    local keys_passed=0
    
    for key in "$ssh_dir"/id_*; do
        # Skip public keys
        if [[ "$key" == *.pub ]]; then continue; fi
        if [ ! -f "$key" ]; then continue; fi
        
        ((keys_found++))
        local key_name
        key_name=$(basename "$key")
        info "Checking key: $key_name"
        
        # Check Encryption Type (Pareto: use strong encryption)
        if [[ "$key_name" == *"rsa"* ]]; then
             warn "  [RISK] Key uses RSA. Consider generating an ED25519 key (ssh-keygen -t ed25519)."
        elif [[ "$key_name" == *"dsa"* ]] || [[ "$key_name" == *"ecdsa"* ]]; then
             warn "  [RISK] Key uses legacy/weak encryption. Consider ED25519."
        else
             success "  [PASS] Key uses strong encryption."
        fi
        
        # Check Passphrase (Pareto: SSH keys require a password)
        # ssh-keygen -y -P "" -f <key> will succeed ONLY if there is no passphrase
        if ssh-keygen -y -P "" -f "$key" &>/dev/null; then
             warn "  [RISK] Key ($key_name) does NOT have a passphrase!"
        else
             success "  [PASS] Key ($key_name) requires a passphrase."
             ((keys_passed++))
        fi
    done
    
    if [ "$keys_found" -eq 0 ]; then
        info "No standard private keys found (id_*)."
    else
        info "$keys_passed/$keys_found keys are protected by a passphrase."
    fi
}

# ssh_harden_sshd
# Backs up and replaces /etc/ssh/sshd_config
ssh_harden_sshd() {
    warn "This will overwrite /etc/ssh/sshd_config with a hardened version."
    warn "Ensure you have physical access or an alternative way in if SSH fails."
    if ! ask_confirmation "Proceed with SSHD hardening?"; then
        return 0
    fi

    local target="/etc/ssh/sshd_config"


    if [ ! -f "$SSHD_CONFIG_SRC" ]; then
        error "Source config not found at $SSHD_CONFIG_SRC"
        return 1
    fi

    start_sudo_keepalive # Use keepalive instead of re-exec to preserve flow
    
    # Use helper from core.sh
    if check_config_and_backup "$SSHD_CONFIG_SRC" "$target" "sudo"; then
        # Check_config_and_backup handles the copy.
        
        success "Configuration applied."
        info "You must restart Remote Login for changes to take effect:"
        info "  sudo launchctl stop com.openssh.sshd"
        info "  sudo launchctl start com.openssh.sshd"
        info "Or toggle 'Remote Login' in System Preferences."
    fi
    
    # Check validity
    execute_sudo "Test configuration" sshd -t
}

# ssh_harden_client
# Backs up and replaces ~/.ssh/config
ssh_harden_client() {
    warn "This will overwrite your personal SSH client config (~/.ssh/config)."
    if ! ask_confirmation "Proceed with SSH Client hardening?"; then
        return 0
    fi

    local ssh_dir="$HOME/.ssh"
    local target="$ssh_dir/config"
    local backup="$target.bak.$(date +%s)"

    if [ ! -d "$ssh_dir" ]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi

    # Use helper
    check_config_and_backup "$SSH_CONFIG_SRC" "$target"
    chmod 600 "$target"

    success "Client configuration applied to $target"
}

# ssh_hash_hosts
# Hashes known_hosts file
ssh_hash_hosts() {
    local hosts_file="$HOME/.ssh/known_hosts"
    if [ ! -f "$hosts_file" ]; then
        warn "No known_hosts file found at $hosts_file"
        return 0
    fi

    info "Hashing known_hosts file..."
    ssh-keygen -H -f "$hosts_file"
    rm "${hosts_file}.old" 2>/dev/null || true
    success "known_hosts hashed."
}
