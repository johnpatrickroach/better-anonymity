#!/bin/bash

# lib/backup.sh
# Secure Backup Utilities

# Encrypt directory to tar.gz.gpg
backup_encrypt_dir() {
    local source_dir="$1"
    local dest_file="$2"
    
    if [ -z "$source_dir" ]; then
        echo -n "Enter source directory to backup: "
        read -r source_dir
    fi
    # Default filename if not provided
    if [ -z "$dest_file" ]; then
        dest_file="backup-$(date +%F-%H%M).tar.gz.gpg"
    fi
    
    if [ ! -d "$source_dir" ]; then
        error "Source directory not found: $source_dir"
        return 1
    fi
    
    info "Archiving and Encrypting '$source_dir' to '$dest_file'..."
    info "You will be asked for a passphrase by GPG."
    
    # tar -> gzip -> gpg
    # Using - (stdout) for tar to pipe
    tar zcvf - "$source_dir" | gpg -c > "$dest_file"
    
    if [ $? -eq 0 ]; then
        success "Backup created at $dest_file"
        return 0
    else
        error "Backup failed."
        return 1
    fi
}

# Decrypt backup
backup_decrypt_dir() {
    local source_file="$1"
    
    if [ -z "$source_file" ]; then
        echo -n "Enter backup file to decrypt: "
        read -r source_file
    fi
    
    if [ ! -f "$source_file" ]; then
        error "File not found: $source_file"
        return 1
    fi
    
    local dest_name="decrypted-$(date +%s).tar.gz"
    
    info "Decrypting '$source_file'..."
    gpg -o "$dest_name" -d "$source_file"
    
    if [ $? -eq 0 ]; then
        info "Decrypted to $dest_name"
        if ask_confirmation "Extract now?"; then
             tar zxvf "$dest_name"
             success "Extracted."
        fi
    else
        error "Decryption failed."
        return 1
    fi
}

# Create encrypted volume (DMG)
backup_create_volume() {
    local vol_name="$1"
    local vol_size="$2"
    
    if [ -z "$vol_name" ]; then 
        echo -n "Enter Volume Name (e.g. SecretStuff): "
        read -r vol_name
    fi
    
    if [ -z "$vol_size" ]; then
        echo -n "Enter Volume Size (e.g. 100M, 1G): "
        read -r vol_size
    fi
    
    local dmg_name="${vol_name}.dmg"
    
    info "Creating Encrypted DMG ($vol_size)..."
    # AES-256 encryption. -stdinpass is hard to script securely in bash without leakage,
    # so we let hdiutil prompt interactively.
    hdiutil create "$dmg_name" -encryption -size "$vol_size" -volname "$vol_name" -fs APFS
    
    if [ $? -eq 0 ]; then
        success "Created $dmg_name"
        info "To mount: hdiutil mount $dmg_name"
    else
        error "Failed to create volume."
        return 1
    fi
}

# Audit Time Machine
backup_audit_timemachine() {
    info "Auditing Time Machine configuration..."
    if ! type tmutil >/dev/null 2>&1; then
        warn "Time Machine util (tmutil) not found."
        return 1
    fi
    
    local status
    status=$(tmutil status | grep "Running" | wc -l) # Naive check
    tmutil destinationinfo
    
    echo
    warn "Ensure your backups are encrypted!"
    warn "If destination is external, use Finder/Disk Utility to encrypt the disk."
}
