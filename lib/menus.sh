#!/bin/bash

# lib/menus.sh
# Interactive Menus for Better Anonymity
# Modularized for better navigation

# --- Sub-Menus ---

menu_ssh() {
    clear
    header "SSH Security Tools"
    load_module "ssh"
    echo "1. Audit SSHD Status"
    echo "2. Harden SSHD (Server) Config"
    echo "3. Harden SSH Client Config"
    echo "4. Hash known_hosts"
    echo "b. Back"
    echo
    echo -n "Select an option: "
    read -r schoice
    case $schoice in
        1) ssh_check_sshd_status ;;
        2) ssh_harden_sshd ;;
        3) ssh_harden_client ;;
        4) ssh_hash_hosts ;;
        b|back) return ;;
        *) error "Invalid option" ;;
    esac
    read -p "Press Enter to continue..."
    menu_ssh
}

menu_hardening() {
    clear
    header "Hardening & Security"
    echo "1. Run OS Hardening"
    echo "2. Verify Security Config"
    echo "3. SSH Hardening Tools"
    echo "4. Misc Hardening (Finder, Analytics, etc.)"
    echo "b. Back"
    echo
    echo -n "Select an option: "
    read -r choice

    case $choice in
        1)
            load_module "macos_hardening"
            if ask_confirmation "Run all hardening steps?"; then
                hardening_run_all
            fi
            ;;
        2)
            load_module "macos_hardening"
            hardening_verify
            ;;
        3)
            menu_ssh
            ;;
        4)
            load_module "macos_hardening"
            echo "Running Miscellaneous Hardening Steps..."
            hardening_harden_finder
            hardening_disable_bonjour
            hardening_secure_sudoers
            hardening_set_umask
            hardening_disable_analytics
            hardening_remove_guest
            hardening_privacy_tweaks
            hardening_reset_tcc
            ;;
        b|back) return ;;
        *) error "Invalid option" ;;
    esac
    read -p "Press Enter to continue..."
    menu_hardening
}

menu_network() {
    clear
    header "Network & Anonymity"
    echo "1. Configure DNS (Anti-Censorship)"
    echo "2. Verify DNS Configuration"
    echo "3. Wi-Fi Security Tools (Audit, Spoof MAC)"
    echo "4. Update Hosts Blocklist"
    echo "b. Back"
    echo
    echo -n "Select an option: "
    read -r choice

    case $choice in
        1)
            load_module "network"
            echo "1) Localhost (127.0.0.1) [Recommended]"
            echo "2) Quad9"
            echo "3) Mullvad"
            echo "4) Cloudflare"
            read -r dns_choice
            case $dns_choice in
                1) network_set_dns "localhost" ;;
                2) network_set_dns "quad9" ;;
                3) network_set_dns "mullvad" ;;
                4) network_set_dns "cloudflare" ;;
                *) error "Invalid choice" ;;
            esac
            ;;
        2)
            load_module "network"
            network_verify_dns
            ;;
        3)
            load_module "wifi"
            echo "Wi-Fi Tools:"
            echo "  1) Audit Connection"
            echo "  2) Spoof MAC Address"
            read -p "Select: " wchoice
            case $wchoice in
                1) wifi_audit ;;
                2) wifi_spoof_mac ;;
            esac
            ;;
        4)
            load_module "network"
            network_update_hosts
            ;;
        b|back) return ;;
        *) error "Invalid option" ;;
    esac
    read -p "Press Enter to continue..."
    menu_network
}

menu_installers() {
    clear
    header "Software Installers"
    echo "1. Tor (Browser & Service)"
    echo "2. I2P (Invisible Internet Project)"
    echo "3. Privoxy"
    echo "4. Signal Messenger"
    echo "5. Firefox Browser"
    echo "6. KeePassXC Password Manager"
    echo "7. GPG (GnuPG)"
    echo "8. DNSCrypt / Unbound / PingBar"
    echo "9. Harden Firefox (Arkenfox)"
    echo "b. Back"
    echo
    echo -n "Select an option: "
    read -r choice
    
    # Load installers module for most tasks
    load_module "installers"

    case $choice in
        1)
             echo "1) Install Tor Browser (App)"
             echo "2) Install Tor Service (CLI)"
             read -p "Select: " tchoice
             case $tchoice in
                1) install_tor_browser ;;
                2) 
                    load_module "tor_manager"
                    tor_install ;;
             esac
             ;;
        2)
             load_module "i2p_manager"
             echo "1) Install I2P"
             echo "2) Start I2P"
             echo "3) Stop I2P"
             echo "4) Console"
             read -p "Select: " ichoice
             case $ichoice in
                1) i2p_install ;;
                2) i2p_start ;;
                3) i2p_stop ;;
                4) i2p_console ;;
             esac
             ;;
        3) install_privoxy ;;
        4) install_signal ;;
        5) install_firefox ;;
        6) install_keepassxc ;;
        7) 
            echo "1) Install GPG"
            echo "2) Setup GPG Config"
            read -p "Select: " gchoice
            case $gchoice in
                1) install_gpg ;;
                2) setup_gpg ;;
            esac
            ;;
        8)
            echo "1) DNSCrypt"
            echo "2) Unbound"
            echo "3) PingBar"
            read -p "Select: " ochoice
            case $ochoice in
                1) install_dnscrypt ;;
                2) install_unbound ;;
                3) install_pingbar ;;
            esac
            ;;
        9) harden_firefox ;;
        b|back) return ;;
        *) error "Invalid option" ;;
    esac
    read -p "Press Enter to continue..."
    menu_installers
}

menu_privacy() {
    clear
    header "Privacy Tools"
    echo "1. Generate Strong Password"
    echo "2. Password Vault (Encrypted Storage)"
    echo "3. Secure Backup Tools (Enc/Dec/Volume)"
    echo "4. Cleanup Metadata & Artifacts"
    echo "b. Back"
    echo
    echo -n "Select an option: "
    read -r choice

    case $choice in
        1)
             load_module "password_utils"
             pwd=$(generate_password 6)
             info "Generated Password: $pwd"
             check_strength "$pwd"
             ;;
        2)
             load_module "vault"
             vault_list 
             echo "Vault Commands:"
             echo "  w [name] - Write/Create"
             echo "  r [name] - Read"
             echo "  l        - List"
             read -p "Action (w/r/l): " vaction
             case $vaction in
                w) vault_write ;;
                r) vault_read ;;
                l) vault_list ;;
             esac
             ;;
        3)
             load_module "backup"
             echo "Backup Commands:"
             echo "  encrypt [dir]  - Encrypt Directory"
             echo "  decrypt [file] - Decrypt Archive"
             echo "  volume         - Create Encrypted DMG"
             echo "  audit          - Audit Time Machine"
             read -p "Action: " baction
             case $baction in
                encrypt) backup_encrypt_dir ;;
                decrypt) backup_decrypt_dir ;;
                volume) backup_create_volume ;;
                audit) backup_audit_timemachine ;;
             esac
             ;;
        4)
             load_module "cleanup"
             cleanup_metadata
             ;;
        b|back) return ;;
        *) error "Invalid option" ;;
    esac
    read -p "Press Enter to continue..."
    menu_privacy
}

# --- Main Menu ---

interactive_menu() {
    clear
    header "Better Anonymity - Main Menu"
    echo "1. Hardening & Security"
    echo "2. Network & Anonymity"
    echo "3. Software Installer"
    echo "4. Privacy Tools"
    echo "5. System Diagnosis (Score)"
    echo "6. First Time Setup Wizard"
    echo "7. Check for Updates"
    echo "8. Uninstall CLI"
    echo "q. Quit"
    echo
    echo -n "Select an option: "
    read -r choice

    case $choice in
        1) menu_hardening ;;
        2) menu_network ;;
        3) menu_installers ;;
        4) menu_privacy ;;
        5) 
            load_module "diagnosis"
            load_module "wifi"
            diagnosis_run 
            read -p "Press Enter to continue..."
            ;;
        6)
            load_module "lifecycle"
            lifecycle_setup
            read -p "Press Enter to continue..."
            ;;
        7)
            load_module "lifecycle"
            lifecycle_check_update
            read -p "Press Enter to continue..."
            ;;
        8)
            load_module "lifecycle"
            lifecycle_uninstall
            read -p "Press Enter to continue..."
            ;;
        q) exit 0 ;;
        *) error "Invalid option" ;;
    esac
    
    interactive_menu
}
