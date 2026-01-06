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
        # Generic check
        if sudo lsof -Pni TCP:22 >/dev/null; then
            echo "Remote Login: On (Process listening on port 22)"
        else
            echo "Remote Login: Off (No process on port 22)"
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
    local backup="/etc/ssh/sshd_config.bak.$(date +%s)"

    if [ ! -f "$SSHD_CONFIG_SRC" ]; then
        error "Source config not found at $SSHD_CONFIG_SRC"
        return 1
    fi

    ensure_root # Function from core.sh to auto-elevate if needed
    
    # Use helper from core.sh
    if check_config_and_backup "$SSHD_CONFIG_SRC" "$target" "sudo"; then
        # If check_config_and_backup returned 0, it might mean it copied OR it verified identical.
        # We need to set permissions regardless if we touched it, or assume helper did it? 
        # Helper does cp. We need to set perms.
        execute_sudo "Set permissions" chmod 644 "$target"
        execute_sudo "Set ownership" chown root:wheel "$target"
        
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
