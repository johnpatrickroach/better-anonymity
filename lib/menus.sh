#!/bin/bash

# lib/menus.sh
# Interactive Menus for Better Anonymity
# Modularized for better navigation

# --- Sub-Menus ---

menu_ssh() {
    while true; do
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
    done
}

menu_hardening() {
    while true; do
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
    done
}

menu_network() {
    while true; do
        clear
        header "Network & Anonymity"
        echo "1. Configure DNS (Anti-Censorship)"
        echo "2. Verify DNS Configuration"
        echo "3. Wi-Fi Security Tools (Audit, Spoof MAC)"
        echo "4. Update Hosts Blocklist"
        echo "5. Restore Network Defaults (Disable Proxies)"
        echo "6. Enable Anonymity Mode (All Services)"
        echo "7. Captive Portal Monitor"
        echo "b. Back"
        echo
        echo -n "Select an option: "
        read -r choice
    
        case $choice in
            1)
                load_module "network"
                echo "1) DNSCrypt Proxy (Localhost) [Recommended]"
                echo "2) Quad9"
                echo "3) Mullvad"
                echo "4) Cloudflare"
                read -r dns_choice
                case $dns_choice in
                    1) network_set_dns "dnscrypt-proxy" ;;
                    2) network_set_dns "quad9" ;;
                    3) network_set_dns "mullvad" ;;
                    4) network_set_dns "cloudflare" ;;
                    *) error "Invalid choice" ;;
                esac
                ;;
            2)
                load_module "network"
                network_verify_anonymity
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
                    *) error "Invalid option" ;;
                esac
                ;;
            4)
                load_module "network"
                network_update_hosts
                ;;
            5)
                load_module "network"
                network_restore_default
                ;;
            6)
                load_module "network"
                network_enable_anonymity
                ;;
            7)
                load_module "captive"
                echo "Captive Portal Monitor"
                echo "1) Start (Monitor in new window)"
                echo "2) Stop"
                echo "3) Status"
                read -r cchoice
                case $cchoice in
                    1) captive_dispatcher monitor ;;
                    2) captive_dispatcher stop ;;
                    3) captive_dispatcher status ;;
                    *) error "Invalid option" ;;
                esac
                ;;
            b|back) return ;;
            *) error "Invalid option" ;;
        esac
        read -p "Press Enter to continue..."
    done
}

menu_installers() {
    while true; do
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
        
        # Load installers module only when needed
    
        case $choice in
            1)
                 echo "1) Install Tor Browser (App)"
                 echo "2) Install Tor Service (CLI)"
                 echo "3) Manage Tor Service (Start/Stop/New Identity)"
                 read -p "Select: " tchoice
                 case $tchoice in
                    1) 
                        load_module "installers"
                        install_tor_browser ;;
                    2) 
                        load_module "tor_manager"
                        tor_install ;;
                    3)
                        load_module "tor_manager"
                        echo "Tor Service Management:"
                        echo "  1) Start (and wait for bootstrap)"
                        echo "  2) Stop"
                        echo "  3) Restart"
                        echo "  4) Status"
                        echo "  5) Request New Identity (New Circuit)"
                        echo "  6) Enable System Proxy"
                        echo "  7) Disable System Proxy"
                        read -r tschoice
                        case $tschoice in
                            1) tor_dispatcher start ;;
                            2) tor_dispatcher stop ;;
                            3) tor_dispatcher restart ;;
                            4) tor_dispatcher status ;;
                            5) tor_dispatcher new-id ;;
                            6) tor_dispatcher proxy-on ;;
                            7) tor_dispatcher proxy-off ;;
                            *) error "Invalid option" ;;
                        esac
                        ;;
                    *) error "Invalid option" ;;
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
                    *) error "Invalid option" ;;
                 esac
                 ;;
            3) 
                load_module "installers"
                install_privoxy ;;
            4) 
                load_module "installers"
                install_signal ;;
            5) 
                load_module "installers"
                install_firefox ;;
            6) 
                load_module "installers"
                install_keepassxc ;;
            7) 
                load_module "installers"
                echo "1) Install GPG"
                echo "2) Setup GPG Config"
                read -p "Select: " gchoice
                case $gchoice in
                    1) install_gpg ;;
                    2) configure_gpg ;;
                    *) error "Invalid option" ;;
                esac
                ;;
            8)
                load_module "installers"
                echo "1) DNSCrypt"
                echo "2) Unbound"
                echo "3) PingBar"
                read -p "Select: " ochoice
                case $ochoice in
                    1) install_dnscrypt ;;
                    2) install_unbound ;;
                    3) install_pingbar ;;
                    *) error "Invalid option" ;;
                esac
                ;;
            9) 
                load_module "installers"
                harden_firefox ;;
            b|back) return ;;
            *) error "Invalid option" ;;
        esac
        read -p "Press Enter to continue..."
    done
}

menu_privacy() {
    while true; do
        clear
        header "Privacy Tools"
        echo "1. Generate Strong Password"
        echo "2. Password Vault (Encrypted Storage)"
        echo "3. Secure Backup Tools (Enc/Dec/Volume)"
        echo "4. Cleanup Metadata, Browsers & Artifacts"
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
                 echo "  w - Write/Create"
                 echo "  r - Read"
                 echo "  l - List"
                 read -p "Action (w/r/l): " vaction
                  case $vaction in
                    w) 
                        echo -n "Enter secret name (e.g. github): "
                        read -r vname
                        vault_write "$vname" 
                        ;;
                    r) 
                        echo -n "Enter secret name to read: "
                        read -r vname
                        vault_read "$vname" 
                        ;;
                    l) vault_list ;;
                    *) error "Invalid option" ;;
                 esac
                 ;;
            3)
                 load_module "backup"
                 echo "Backup Commands:"
                 echo "  encrypt - Encrypt Directory"
                 echo "  decrypt - Decrypt Archive"
                 echo "  volume  - Create Encrypted DMG"
                 echo "  audit   - Audit Time Machine"
                 read -p "Action: " baction
                  case $baction in
                    encrypt) 
                        echo -n "Enter source directory to backup: "
                        read -r bsrc
                        backup_encrypt_dir "$bsrc" 
                        ;;
                    decrypt) 
                        echo -n "Enter backup file to decrypt: "
                        read -r bfile
                        backup_decrypt_dir "$bfile" 
                        ;;
                    volume) 
                        echo -n "Enter Volume Name (e.g. SecretStuff): "
                        read -r vname
                        echo -n "Enter Volume Size (e.g. 100M, 1G): "
                        read -r vsize
                        backup_create_volume "$vname" "$vsize" 
                        ;;
                    audit) backup_audit_timemachine ;;
                    *) error "Invalid option" ;;
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
    done
}

# --- Main Menu ---

interactive_menu() {
    while true; do
        clear
        if [ -f "$LIB_DIR/banner.txt" ]; then
            cat "$LIB_DIR/banner.txt"
            echo ""
        fi
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
    done
}
