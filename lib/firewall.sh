#!/bin/bash

# lib/firewall.sh
# PF Hardware Firewall Management

filter_pf_blocklist() {
    # Filters standard IP blacklist to valid IPv4
    grep -Ev "^192\.168\.|^10\.|172\.16\.|127\.0\.0\.0|0\.0\.0\.0|^#|#$" | grep -E "^[0-9]"
}

firewall_enable_blocklist() {
    info "Downloading and building PF blocklist..."
    
    local pf_dir="/etc/pf"
    local blocklist_file="$pf_dir/blocklist"
    local temp_threats="/tmp/pf-threats.txt"
    
    execute_sudo "Create PF Directory" mkdir -p "$pf_dir"
    execute_sudo "Create PF Blocklist" touch "$blocklist_file"
    
    # Backup pf.conf if we haven't already
    if [ ! -f /etc/pf.conf.bak ]; then
        execute_sudo "Backup pf.conf" cp -p /etc/pf.conf /etc/pf.conf.bak
    fi
    
    rm -f "$temp_threats" 2>/dev/null
    touch "$temp_threats"
    
    # Download threat lists
    curl -sq "https://pgl.yoyo.org/adservers/iplist.php?ipformat=&showintro=0&mimetype=plaintext" \
             "https://www.binarydefense.com/banlist.txt" \
             "https://rules.emergingthreats.net/blockrules/compromised-ips.txt" \
             "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt" \
             "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset" \
             "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level2.netset" \
             "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level3.netset" | filter_pf_blocklist >> "$temp_threats"

    local total_threats
    total_threats=$(sort "$temp_threats" | uniq | wc -l | tr -d ' ')
    
    if [ "$total_threats" -eq 0 ]; then
        warn "Failed to download threat IPs (empty list). Aborting blocklist update."
        return 1
    fi
    info "Successfully compiled $total_threats unique threat IPs."
    
    # Sort and deploy
    sort "$temp_threats" | uniq > "/tmp/pf-blocklist.tmp"
    execute_sudo "Deploy Blocklist File" cp "/tmp/pf-blocklist.tmp" "$blocklist_file"
    rm -f "/tmp/pf-blocklist.tmp" "$temp_threats"
    
    # Map the PF rules dynamically using a separate anchor or insert before existing ones
    # For safety, we dynamically rebuild the rules if missing
    if ! grep -q "table <blocklist> persist file" /etc/pf.conf; then
        info "Injecting PF hooks into /etc/pf.conf..."
        execute_sudo "Inject PF Tables" sed -i '' '/^scrub-anchor/i\
table <blocklist> persist file "/etc/pf/blocklist"\
block drop in quick from <blocklist>\
' /etc/pf.conf
    fi
    
    # Enable and load PF
    execute_sudo "Enable PF Firewall" pfctl -e || true
    execute_sudo "Load PF Ruleset" pfctl -f /etc/pf.conf || warn "Failed to load PF ruleset. Check syntax."
    
    # Track state for uninstallation
    save_state_var "STATE_PF_BLOCKLIST" "enabled"
    
    local active_rules
    active_rules=$(sudo pfctl -t blocklist -T show 2>/dev/null | wc -l | tr -d ' ')
    success "Hardware Firewall active! Blocking $active_rules malicious IPs at the kernel level."
}

firewall_disable_blocklist() {
    info "Disabling PF blocklist..."
    
    # Remove from pf.conf
    if grep -q "table <blocklist> persist file" /etc/pf.conf; then
        execute_sudo "Remove PF Tables" sed -i '' '/table <blocklist> persist file "\/etc\/pf\/blocklist"/d' /etc/pf.conf
        execute_sudo "Remove PF Block Drops" sed -i '' '/block drop in quick from <blocklist>/d' /etc/pf.conf
    fi
    
    execute_sudo "Flush PF Ruleset" pfctl -f /etc/pf.conf || true
    
    if [ -f "/etc/pf/blocklist" ]; then
        execute_sudo "Remove Blocklist File" rm -f "/etc/pf/blocklist"
    fi
    
    save_state_var "STATE_PF_BLOCKLIST" "__MISSING__"
    success "Hardware Firewall blocklist removed."
}
