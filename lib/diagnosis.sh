#!/bin/bash

# lib/diagnosis.sh
# System Diagnosis and Scoring Module
#
# Dependencies:
#   - core.sh (for logging, is_brew_installed, check_airport_exists)
#   - platform.sh (for network detection)
#   - External commands: socketfilterfw, fdesetup, csrutil, spctl, defaults, brew, gpg

# Score Weights (Total 100 per category)
# These are arbitrary but prioritize critical items.

diagnosis_run() {
    header "System Diagnosis & Scoring"
    info "Analyzing system configuration..."
    
    # Detect active network service
    local net_service="Wi-Fi"
    if type -t detect_active_network | grep -q "function"; then
        detect_active_network
        net_service="${PLATFORM_ACTIVE_SERVICE:-Wi-Fi}"
    fi

    # Initialize Scores
    local security_score=0
    local privacy_score=0
    local anonymity_score=0
    
    # --- SECURITY CHECK ---
    info "1. Auditing Security..."
    local sec_total=0
    local sec_passed=0
    
    # Firewall (15 pts)
    # Check for "enabled" OR "on" (macOS versions differ)
    ((sec_total+=15))
    if "$SOCKETFILTERFW_CMD" --getglobalstate 2>/dev/null | grep -E -q "enabled|on"; then
        ((sec_passed+=15))
    else
        warn "  [FAIL] Firewall is DISABLED."
    fi

    # FileVault (15 pts)
    ((sec_total+=15))
    if fdesetup status | grep -q "FileVault is On"; then
        ((sec_passed+=15))
    else
        warn "  [FAIL] FileVault is DISABLED."
    fi

    # SIP (15 pts)
    ((sec_total+=15))
    if csrutil status | grep -q "enabled"; then
        ((sec_passed+=15))
    else
        warn "  [FAIL] SIP is DISABLED."
    fi

    # Gatekeeper (15 pts)
    ((sec_total+=15))
    if spctl --status | grep -q "assessments enabled"; then
         ((sec_passed+=15))
    else
         warn "  [FAIL] Gatekeeper is DISABLED."
    fi
    
    # Stealth Mode (5 pts)
    ((sec_total+=5))
    if "$SOCKETFILTERFW_CMD" --getstealthmode 2>/dev/null | grep -E -q "enabled|on"; then
        ((sec_passed+=5))
    else
        warn "  [FAIL] Stealth Mode is DISABLED."
    fi

    # Automatic Updates (10 pts)
    ((sec_total+=10))
    if [ "$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null)" == "1" ] && \
       [ "$(defaults read /Library/Preferences/com.apple.commerce AutoUpdate 2>/dev/null)" == "1" ]; then
        ((sec_passed+=10))
    else
        warn "  [FAIL] Automatic Updates are disabled (If intentional for privacy, ignore this)."
    fi

    # Screen Saver & Login (10 pts)
    ((sec_total+=10))
    local screen_score=0
    # AutoLogin off
    if ! defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser &>/dev/null; then
        ((screen_score+=5))
    else
        warn "  [FAIL] Automatic Login is enabled."
    fi
    # Screensaver idle time <= 1200
    local idle_time
    idle_time=$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo "0")
    if [ "$idle_time" -gt 0 ] && [ "$idle_time" -le 1200 ]; then
        ((screen_score+=5))
    else
        warn "  [FAIL] Screen Saver does not trigger within 20 minutes."
    fi
    ((sec_passed+=screen_score))

    # Secure Sleep (10 pts)
    ((sec_total+=10))
    local sleep_score=0
    local pmset_out
    pmset_out=$(pmset -g custom 2>/dev/null || pmset -g)
    if echo "$pmset_out" | grep -E -q "hibernatemode[[:space:]]+25"; then
         ((sleep_score+=5))
    else
         warn "  [FAIL] Hibernation Mode is not set to 25 (Secure Sleep)."
    fi
    if echo "$pmset_out" | grep -E -q "destroyfvkeyonstandby[[:space:]]+1"; then
         ((sleep_score+=5))
    else
         warn "  [FAIL] FileVault key is not destroyed on standby."
    fi
    ((sec_passed+=sleep_score))

    # Secure Terminal (5 pts)
    ((sec_total+=5))
    if [ "$(defaults read com.apple.Terminal SecureKeyboardEntry 2>/dev/null)" == "1" ]; then
        ((sec_passed+=5))
    else
        warn "  [FAIL] Terminal Secure Keyboard Entry is disabled."
    fi

    # SSH Hardening & Keys (10 pts)
    ((sec_total+=10))
    local ssh_score=0
    local remote_login_status
    remote_login_status=$(sudo systemsetup -getremotelogin 2>/dev/null || echo "Off")
    
    if echo "$remote_login_status" | grep -i -q "Off"; then
        ((ssh_score+=5))
    else
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null && grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
             ((ssh_score+=5))
        else
             warn "  [FAIL] Remote Login is ON but not fully hardened."
        fi
    fi
    
    # Check keys for passphrase
    local ssh_dir="$HOME/.ssh"
    local keys_found=0
    local keys_unprotected=0
    if [ -d "$ssh_dir" ]; then
        for key in "$ssh_dir"/id_*; do
            if [[ "$key" == *.pub ]]; then continue; fi
            if [ -f "$key" ]; then
                ((keys_found++))
                if ssh-keygen -y -P "" -f "$key" &>/dev/null; then
                    ((keys_unprotected++))
                fi
            fi
        done
    fi
    
    if [ "$keys_found" -eq 0 ]; then
        ((ssh_score+=5))
    elif [ "$keys_unprotected" -eq 0 ]; then
        ((ssh_score+=5))
    else
        warn "  [FAIL] SSH keys found without a passphrase."
    fi
    
    ((sec_passed+=ssh_score))
    
    if [ $sec_total -gt 0 ]; then
        security_score=$(( (sec_passed * 100) / sec_total ))
    else
        security_score=0
    fi


    # --- PRIVACY CHECK ---
    info "2. Auditing Privacy..."
    local priv_total=0
    local priv_passed=0
    
    # Analytics (20 pts)
    # Check one key indicator
    ((priv_total+=20))
    if [ "$(defaults read /Library/Preferences/com.apple.loginwindow AutoSubmit 2>/dev/null)" == "0" ]; then
        ((priv_passed+=20))
    else
        warn "  [FAIL] Apple Analytics (AutoSubmit) enabled."
    fi
    
    # Ad Tracking (20 pts)
    ((priv_total+=20))
    if [ "$(defaults read com.apple.AdLib forceLimitAdTracking 2>/dev/null)" == "1" ]; then
        ((priv_passed+=20))
    else
        warn "  [FAIL] Ad Tracking not limited."
    fi
    
    # Secure Browser Check (30 pts)
    # Goal: Ensure at least one privacy-respecting browser is installed and configured.
    # Accepts: Tor Browser (Best) OR Hardened Firefox.
    ((priv_total+=30))
    local secure_browser_found=0
    
    # Priority A: Tor Browser (Gold Standard)
    if is_app_installed "Tor Browser.app"; then
         ((priv_passed+=30))
         info "  [PASS] Tor Browser detected."
         secure_browser_found=1
    # Priority B: Firefox Hardening
    elif check_path "/Applications/Firefox.app"; then
         local ff_score=0
         # Check Telemetry pref (10 pts)
         if [ "$(defaults read /Library/Preferences/org.mozilla.firefox DisableTelemetry 2>/dev/null)" == "1" ]; then
            ((ff_score+=10))
         else
            warn "  [FAIL] Firefox Telemetry enabled in policies."
         fi
         
         # Check Arkenfox user.js (20 pts)
         local ff_dir="$HOME/Library/Application Support/Firefox/Profiles"
         if check_path "$ff_dir"; then
             if find "$ff_dir" -name "user.js" -maxdepth 2 2>/dev/null | grep -q "user.js"; then
                  ((ff_score+=20))
             else
                  warn "  [FAIL] Firefox user.js (Arkenfox) not found."
             fi
         else
             warn "  [FAIL] Firefox installed but no profiles found."
         fi
         
         ((priv_passed+=ff_score))
         if [ $ff_score -gt 0 ]; then secure_browser_found=1; fi
    else
         # No Secure Browser
         warn "  [FAIL] No secure browser detected (Tor Browser or Hardened Firefox)."
    fi
    
    # Homebrew Analytics (10 pts)
    ((priv_total+=10))
    if command -v brew &>/dev/null; then
        if brew analytics | grep -q "disabled"; then
            ((priv_passed+=10))
        else
            warn "  [FAIL] Homebrew Analytics enabled."
        fi
    else
        ((priv_passed+=10))
    fi
    
    # Messengers & Vaults (20 pts)
    ((priv_total+=20))
    local tools_passed=0
    if is_cask_installed "signal" || is_app_installed "Signal.app"; then ((tools_passed+=10)); fi
    if is_cask_installed "keepassxc" || is_app_installed "KeePassXC.app"; then ((tools_passed+=10)); fi
    
    if [ $tools_passed -eq 20 ]; then
        ((priv_passed+=20))
    elif [ $tools_passed -gt 0 ]; then
         ((priv_passed+=10))
         warn "  [NOTE] Consider installing all recommended privacy tools (Signal, KeePassXC)."
    else
         warn "  [FAIL] Recommended privacy tools (Signal, KeePassXC) not found."
    fi
    
    if [ $priv_total -gt 0 ]; then
        privacy_score=$(( (priv_passed * 100) / priv_total ))
    else
        privacy_score=0
    fi


    # --- ANONYMITY CHECK ---
    info "3. Auditing Anonymity..."
    local anon_total=0
    local anon_passed=0
    
    # Tor Installed & Service (20 pts)
    ((anon_total+=20))
    if is_brew_installed "tor"; then
        ((anon_passed+=10))
        # Check if service is running if we are supposed to be using it as service?
        # Just having it installed is good.
    else
        warn "  [FAIL] Tor not installed."
    fi
    if is_app_installed "Tor Browser.app"; then
         ((anon_passed+=10))
    else
         warn "  [FAIL] Tor Browser not installed."
    fi
    
    # DNS Encrypted & Service Health (20 pts)
    ((anon_total+=20))
    local dns
    dns=$(networksetup -getdnsservers "$net_service" 2>/dev/null)
    if [[ "$dns" == *"127.0.0.1"* ]]; then
        # Check if Unbound or DNSCrypt is running
        if pgrep -x "unbound" >/dev/null || pgrep -x "dnscrypt-proxy" >/dev/null; then
             ((anon_passed+=20))
        else
             warn "  [FAIL] DNS set to localhost but Unbound/DNSCrypt servce NOT running!"
        fi
    elif [[ "$dns" == *"9.9.9.9"* ]] || [[ "$dns" == *"1.1.1.1"* ]] || [[ "$dns" == *"194.242.2"* ]]; then
        ((anon_passed+=15)) # Good but not self-hosted
    else
        warn "  [FAIL] DNS appears to be ISP default or unrecognised ($dns)."
    fi
    
    # IPv6 Status (10 pts)
    ((anon_total+=10))
    local ipv6_status
    ipv6_status=$(networksetup -getinfo "$net_service" 2>/dev/null | grep "^IPv6:" || echo "")
    if echo "$ipv6_status" | grep -i -q "Off"; then
        ((anon_passed+=10))
    else
        warn "  [FAIL] IPv6 is enabled on $net_service (Potential Leak)."
    fi
    
    # I2P Installed (20 pts)
    ((anon_total+=20))
    if is_brew_installed "i2p"; then
        ((anon_passed+=20))
    else
        warn "  [FAIL] I2P not installed."
    fi
    
    # Privoxy Installed (10 pts)
    ((anon_total+=10))
    if is_brew_installed "privoxy"; then
         ((anon_passed+=10))
    else
         warn "  [FAIL] Privoxy not installed."
    fi
    
    # GPG Installed (10 pts)
    ((anon_total+=10))
    if command -v gpg >/dev/null; then
         ((anon_passed+=10))
    else
         warn "  [FAIL] GPG not installed."
    fi

    # MAC Spoofing Capable & Active (20 pts)
    # Check if airport util exists
    # MAC Spoofing Capable & Active (20 pts)
    # Check if airport util exists
    ((anon_total+=20))
    if check_airport_exists; then
         ((anon_passed+=10))
         
         # Audit Spoofing (Basic check: Does Config MAC == Hardware MAC?)
         # We can use logic from wifi.sh regarding 'networksetup -getmacaddress' vs 'ifconfig'?
         # Or simplest: just give points for capability for now, spoofing is ephemeral.
         # Let's check permissions/tools.
         if command -v openssl >/dev/null; then
              ((anon_passed+=10))
         fi
    else
         warn "  [FAIL] Airport utility missing (MAC spoofing hard)."
    fi

    if [ $anon_total -gt 0 ]; then
        anonymity_score=$(( (anon_passed * 100) / anon_total ))
    else
        anonymity_score=0
    fi
    
    # Report
    echo ""
    local total_score=$(( (security_score + privacy_score + anonymity_score) / 3 ))

    # Build lines with scores + overall
    local report_lines=()
    report_lines+=("$(diagnosis_print_score "Security" "$security_score")")
    report_lines+=("$(diagnosis_print_score "Privacy " "$privacy_score")")
    report_lines+=("$(diagnosis_print_score "Anonymity" "$anonymity_score")")
    report_lines+=("----------------------------------------")
    report_lines+=("OVERALL SCORE: $total_score / 100")
    report_lines+=("")

    section "DIAGNOSIS REPORT" "${report_lines[@]}"

    diagnosis_recommendations "$security_score" "$privacy_score" "$anonymity_score"
}

diagnosis_print_score() {
    local name="$1"
    local score="$2"
    local color="$RED"

    if [ "$score" -ge 90 ]; then color="$GREEN"; fi
    if [ "$score" -ge 70 ] && [ "$score" -lt 90 ]; then color="$YELLOW"; fi

    local grade="F"
    if [ "$score" -ge 90 ]; then grade="A"
    elif [ "$score" -ge 80 ]; then grade="B"
    elif [ "$score" -ge 70 ]; then grade="C"
    elif [ "$score" -ge 60 ]; then grade="D"
    fi

    # Return a single formatted line so caller can decide where to print
    echo -e "${name}: ${color}${score}/100${NC} (Grade: $grade)"
}

diagnosis_recommendations() {
    local s="$1"
    local p="$2"
    local a="$3"
    
    if [ "$s" -lt 100 ] || [ "$p" -lt 100 ] || [ "$a" -lt 100 ]; then
        echo "RECOMMENDATIONS:"
        if [ "$s" -lt 100 ]; then
            echo "- Security: Run 'better-anonymity harden' (covers Firewall, FileVault, SSH, etc)."
        fi
        if [ "$p" -lt 100 ]; then
            echo "- Privacy: Run 'better-anonymity install-firefox', 'harden-firefox', or install Signal/KeePassXC."
        fi
        if [ "$a" -lt 100 ]; then
            echo "- Anonymity: Run 'better-anonymity install-tor', 'install-i2p', or 'install-dnscrypt'."
        fi
    else
        success "Excellent configuration! No immediate actions required."
    fi
}
