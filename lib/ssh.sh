#!/usr/bin/env bash

# lib/ssh.sh
# Functions for SSH hardening (Server and Client)

SSH_CONFIG_SRC="$ROOT_DIR/config/ssh/ssh_config"
SSHD_CONFIG_SRC="$ROOT_DIR/config/ssh/sshd_config"

# ssh_check_sshd_status
# Checks if Remote Login is enabled.
ssh_check_sshd_status() {
    info "Checking SSH Server (Remote Login) status..."
    if command -v systemsetup >/dev/null; then
        # macOS specific
        systemsetup -getremotelogin
    else
        # Generic check (using connection test instead of process listing)
        # This avoids needing sudo if lsof is restricted.
        if check_port "localhost" 22; then
            echo "Remote Login: On (Listening on localhost:22)"
        else
            echo "Remote Login: Off (Locahost:22 not reachable)"
        fi
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
