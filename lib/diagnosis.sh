#!/bin/bash

# lib/diagnosis.sh
# System Diagnosis and Scoring Module

# Score Weights (Total 100 per category)
# These are arbitrary but prioritize critical items.

diagnosis_run() {
    header "System Diagnosis & Scoring"
    info "Analyzing system configuration..."
    
    # Initialize Scores
    local security_score=0
    local privacy_score=0
    local anonymity_score=0
    
    # --- SECURITY CHECK ---
    info "1. Auditing Security..."
    local sec_checks=0
    local sec_passed=0
    
    # Firewall (20 pts)
    if "$SOCKETFILTERFW_CMD" --getglobalstate 2>/dev/null | grep -q "enabled"; then
        ((sec_passed+=20))
        sec_checks=$((sec_checks+1))
    else
        warn "  [FAIL] Firewall is DISABLED."
    fi

    # FileVault (20 pts)
    if fdesetup status | grep -q "FileVault is On"; then
        ((sec_passed+=20))
         sec_checks=$((sec_checks+1))
    else
        warn "  [FAIL] FileVault is DISABLED."
    fi

    # SIP (20 pts)
    if csrutil status | grep -q "enabled"; then
        ((sec_passed+=20))
         sec_checks=$((sec_checks+1))
    else
        warn "  [FAIL] SIP is DISABLED."
    fi

    # Gatekeeper (20 pts)
    if spctl --status | grep -q "assessments enabled"; then
         ((sec_passed+=20))
          sec_checks=$((sec_checks+1))
    else
         warn "  [FAIL] Gatekeeper is DISABLED."
    fi
    
    # Stealth Mode (10 pts)
    if "$SOCKETFILTERFW_CMD" --getstealthmode 2>/dev/null | grep -q "enabled"; then
        ((sec_passed+=10))
    else
        warn "  [FAIL] Stealth Mode is DISABLED."
    fi

    # SSH Hardening (10 pts)
    # Check if Remote Login is Off OR if Config is hardened (e.g. PermitRootLogin no)
    if systemsetup -getremotelogin 2>/dev/null | grep -q "Off"; then
        ((sec_passed+=10))
    else
        # If On, check config
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
             ((sec_passed+=10))
        else
             warn "  [FAIL] Remote Login is ON and potentially weak (PermitRootLogin not clearly 'no')."
        fi
    fi
    
    security_score=$sec_passed


    # --- PRIVACY CHECK ---
    info "2. Auditing Privacy..."
    local priv_passed=0
    
    # Analytics (30 pts)
    # Check one key indicator
    if [ "$(defaults read /Library/Preferences/com.apple.loginwindow AutoSubmit 2>/dev/null)" == "0" ]; then
        ((priv_passed+=30))
    else
        warn "  [FAIL] Apple Analytics (AutoSubmit) enabled."
    fi
    
    # Ad Tracking (30 pts)
    if [ "$(defaults read com.apple.AdLib forceLimitAdTracking 2>/dev/null)" == "1" ]; then
        ((priv_passed+=30))
    else
        warn "  [FAIL] Ad Tracking not limited."
    fi
    
    # Firefox Telemetry (20 pts) - If Firefox installed
    if [ -d "/Applications/Firefox.app" ]; then
         if [ "$(defaults read /Library/Preferences/org.mozilla.firefox DisableTelemetry 2>/dev/null)" == "1" ]; then
            ((priv_passed+=20))
         else
            warn "  [FAIL] Firefox Telemetry enabled."
         fi
    else
         # Bonus if not installed? Or just N/A. Let's give points to be fair or normalize?
         # Let's give points for "not vulnerable"
         ((priv_passed+=20))
    fi
    
    # Homebrew Analytics (20 pts)
    if command -v brew &>/dev/null; then
        if brew analytics | grep -q "disabled"; then
            ((priv_passed+=20))
        else
            warn "  [FAIL] Homebrew Analytics enabled."
        fi
    else
        ((priv_passed+=20))
    fi
    
    privacy_score=$priv_passed


    # --- ANONYMITY CHECK ---
    info "3. Auditing Anonymity..."
    local anon_passed=0
    
    # Tor Installed (25 pts)
    if is_brew_installed "tor"; then
        ((anon_passed+=25))
    else
        warn "  [FAIL] Tor not installed."
    fi
    
    # DNS Encrypted (25 pts) - Check if not default/ISP (heuristic)
    # If using Quad9, Mullvad, or Cloudflare or localhost (dnscrypt)
    local dns
    dns=$(networksetup -getdnsservers Wi-Fi 2>/dev/null)
    if [[ "$dns" == *"9.9.9.9"* ]] || [[ "$dns" == *"1.1.1.1"* ]] || [[ "$dns" == *"127.0.0.1"* ]] || [[ "$dns" == *"194.242.2"* ]]; then
        ((anon_passed+=25))
    else
        warn "  [FAIL] DNS appears to be ISP default or unrecognised ($dns)."
    fi
    
    # I2P Installed (25 pts)
    if is_brew_installed "i2p"; then
        ((anon_passed+=25))
    else
        warn "  [FAIL] I2P not installed."
    fi
    
    # MAC Spoofing Capable (25 pts)
    # Check if airport util exists? Use generic check.
    if [ -x "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport" ]; then
         ((anon_passed+=25))
    else
         warn "  [FAIL] Airport utility missing (MAC spoofing hard)."
    fi

    anonymity_score=$anon_passed
    
    # Report
    echo ""
    header "DIAGNOSIS REPORT"
    diagnosis_print_score "Security" "$security_score"
    diagnosis_print_score "Privacy " "$privacy_score"
    diagnosis_print_score "Anonymity" "$anonymity_score"
    
    local total_score=$(( (security_score + privacy_score + anonymity_score) / 3 ))
    echo "----------------------------------------"
    echo "OVERALL SCORE: $total_score / 100"
    echo ""
    
    diagnosis_recommendations "$security_score" "$privacy_score" "$anonymity_score"
}

diagnosis_print_score() {
    local name="$1"
    local score="$2"
    local color="$RED"
    
    if [ "$score" -ge 90 ]; then color="$GREEN"; fi
    if [ "$score" -ge 70 ] && [ "$score" -lt 90 ]; then color="$YELLOW"; fi
    
    # Calculate Grade
    local grade="F"
    if [ "$score" -ge 90 ]; then grade="A"; 
    elif [ "$score" -ge 80 ]; then grade="B"; 
    elif [ "$score" -ge 70 ]; then grade="C"; 
    elif [ "$score" -ge 60 ]; then grade="D"; 
    fi
    
    echo -e "${name}: ${color}${score}/100${NC} (Grade: $grade)"
}

diagnosis_recommendations() {
    local s="$1"
    local p="$2"
    local a="$3"
    
    if [ "$s" -lt 100 ] || [ "$p" -lt 100 ] || [ "$a" -lt 100 ]; then
        echo "RECOMMENDATIONS:"
        if [ "$s" -lt 100 ]; then
            echo "- Run 'better-anonymity harden' to improve Security."
            echo "- Run 'better-anonymity ssh harden' to secure Remote Login."
        fi
        if [ "$p" -lt 100 ]; then
            echo "- Run 'better-anonymity harden' (Privacy Tweaks) to improve Privacy."
            echo "- Run 'better-anonymity install-firefox' and 'harden-firefox'."
        fi
        if [ "$a" -lt 100 ]; then
            echo "- Run 'better-anonymity install-tor' and 'install-i2p'."
            echo "- Configure DNS using 'better-anonymity dns'."
        fi
    else
        success "Excellent configuration! No immediate actions required."
    fi
}
