#!/bin/bash

# lib/network.sh
# Network config functions

network_set_dns() {
    local provider=$1
    local dns_servers=""

    case $provider in
        "localhost")
            dns_servers="127.0.0.1"
            info "Setting DNS to Localhost (127.0.0.1)..."
            ;;
        "quad9")
            dns_servers="9.9.9.9 149.112.112.112"
            info "Setting DNS to Quad9..."
            ;;
        "mullvad")
            dns_servers="194.242.2.2 194.242.2.3"
            info "Setting DNS to Mullvad..."
            ;;
        "cloudflare")
            dns_servers="1.1.1.1 1.0.0.1"
            info "Setting DNS to Cloudflare..."
            ;;
        "default"|"dhcp"|"empty"|"system")
            dns_servers="Empty"
            info "Resetting DNS to System Default (DHCP)..."
            ;;
        *)
            error "Unknown provider: $provider"
            return 1
            ;;
    esac

    services=$(networksetup -listallnetworkservices | grep -v '*')
    
    IFS=$'\n'
    for service in $services; do
        current_dns=$(networksetup -getdnsservers "$service" | tr '\n' ' ' | sed 's/ $//')
        
        if [[ "$current_dns" == *"$dns_servers"* ]] || [[ "$dns_servers" == *"$current_dns"* ]]; then 
             # Check if they are effectively equal. 
             # If current_dns contains the target servers (and maybe more? No, exact match preference)
             # Let's check for containment of our target string in the normalized current_dns
             if [[ "$current_dns" == *"$dns_servers"* ]]; then
                 info "DNS for $service is already set to $dns_servers."
                 continue
             fi
        fi

        info "Configuring $service..."
        # Requires sudo
        execute_sudo "Set DNS for $service" networksetup -setdnsservers "$service" $dns_servers
    done
    unset IFS
    
    execute_sudo "Flush DNS cache" dscacheutil -flushcache
    execute_sudo "Kill mDNSResponder" killall -HUP mDNSResponder
    info "DNS updated and cache flushed."
}

# Helper to manage services quietly.
# Usage: manage_service action service [as_root]
manage_service() {
    local action="$1"
    local service="$2"
    local as_root="$3"
    
    local action_pretty="$(tr '[:lower:]' '[:upper:]' <<< ${action:0:1})${action:1}"
    info "$action_pretty $service"
    
    local output
    if [ "$as_root" == "true" ]; then
        output=$(sudo brew services "$action" "$service" 2>&1)
    else
        output=$(brew services "$action" "$service" 2>&1)
    fi
    local exit_code=$?
    
    if [[ "$output" == *"not started"* ]]; then
        info "Service $service is not started (skipping)."
    elif [[ "$output" == *"already started"* ]]; then
        info "Service $service is already started."
    elif [[ "$exit_code" -ne 0 ]]; then
        warn "Output from brew services:"
        echo "$output"
    else
        echo "$output"
    fi
}


network_update_hosts() {
    info "Updating /etc/hosts with StevenBlack blocklist..."
    
    # 1. Backup / Create Base
    if [ ! -f "/etc/hosts-base" ]; then
        info "Creating /etc/hosts-base backup..."
        execute_sudo "Backup hosts" cp /etc/hosts /etc/hosts-base
    fi
    
    # 2. Restore Base
    # We use 'cat >' pattern via sudo sh -c to handle permissions cleanly
    execute_sudo "Restore base hosts" sh -c "cat /etc/hosts-base > /etc/hosts"
    
    # 3. Download and Append
    info "Downloading blocklist to config/hosts..."
    local BLOCKLIST_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    local LOCAL_BLOCKLIST="config/hosts"
    
    # Ensure config dir exists (it should, but safety first)
    if [ ! -d "config" ]; then mkdir -p config; fi
    
    # Try downloading
    if curl -sS -o "$LOCAL_BLOCKLIST" "$BLOCKLIST_URL"; then
        info "Blocklist downloaded successfully."
    else
        warn "Download failed."
        if [ -f "$LOCAL_BLOCKLIST" ]; then
            warn "Using cached blocklist from $LOCAL_BLOCKLIST"
        else
            error "No local blocklist available. Aborting hosts update."
            return 1
        fi
    fi
    
    # Append local blocklist to /etc/hosts
    info "Applying blocklist..."
    # We use awk or simple cat logic. 'tee -a' is simplest with sudo.
    execute_sudo "Append Blocklist" sh -c "cat '$LOCAL_BLOCKLIST' | tee -a /etc/hosts > /dev/null"
    
    # Flush cache
    execute_sudo "Flush DNS cache" dscacheutil -flushcache
    execute_sudo "Kill mDNSResponder" killall -HUP mDNSResponder
    info "Hosts file updated successfully."
}

network_verify_dns() {
    info "Verifying DNS Configuration..."
    
    # 0. Check Service Status
    info "Checking Service Status (brew services)..."
    # We use execute_sudo because they are likely root services
    local services_out
    if command -v brew &> /dev/null; then
         # We capture output. execute_sudo usually executes "$@".
         # We'll call brew directly with sudo for capture, assuming execute_sudo might be noisy or hard to capture if it echoes info.
         # Actually, execute_sudo mocks just run the command. Real execute_sudo runs sudo.
         # But we want to capture the output for grep.
         # So we'll use 'sudo brew services list' directly or via a wrapper if we want to be consistent?
         # Consistent approach:
         # Split checks: Root services (DNS) vs User services (Privoxy)
         
         # 1. Root Services (DNSCrypt, Unbound) - Check with Sudo
         local root_services
         root_services=$(execute_sudo "Check Root Services" brew services list 2>/dev/null)
         
         if echo "$root_services" | grep -q "dnscrypt-proxy.*started" || pgrep -x "dnscrypt-proxy" >/dev/null; then
             info "[PASS] dnscrypt-proxy is running."
         else
             warn "[FAIL] dnscrypt-proxy is NOT running or has errors."
         fi
         
         if echo "$root_services" | grep -q "unbound.*started" || pgrep -x "unbound" >/dev/null; then
             info "[PASS] unbound is running."
         else
             warn "[FAIL] unbound is NOT running or has errors."
         fi

         # 2. User Services (Privoxy) - Check as User
         local user_services
         user_services=$(brew services list 2>/dev/null)
         
         if echo "$user_services" | grep -q "privoxy.*started" || pgrep -x "privoxy" >/dev/null; then
             info "[PASS] privoxy is running."
         else
             warn "[FAIL] privoxy is NOT running or has errors."
         fi
    else
         warn "Homebrew not found. Skipping service check."
         # Still check processes if brew missing
         if pgrep -x "dnscrypt-proxy" >/dev/null; then info "[PASS] dnscrypt-proxy process found."; fi
         if pgrep -x "unbound" >/dev/null; then info "[PASS] unbound process found."; fi
         if pgrep -x "privoxy" >/dev/null; then info "[PASS] privoxy process found."; fi
    fi

    # 1. Check System Resolver
    info "Checking System Resolver (scutil)..."
    local scutil_out
    if ! command -v scutil &> /dev/null; then
        warn "scutil command not found. Skipping."
    else
        scutil_out=$(scutil --dns | head -n 10)
        echo "$scutil_out"
        if echo "$scutil_out" | grep -q "127.0.0.1"; then
            info "[PASS] System resolver is using localhost (127.0.0.1)."
        else
            warn "[FAIL] System resolver does NOT appear to use 127.0.0.1."
        fi
    fi

    # 2. Check NetworkSetup
    info "Checking Wi-Fi DNS Settings..."
    local ns_out
    if ! command -v networksetup &> /dev/null; then
         warn "networksetup command not found. Skipping."
    else
        ns_out=$(networksetup -getdnsservers Wi-Fi)
        echo "$ns_out"
        if echo "$ns_out" | grep -q "127.0.0.1"; then
            info "[PASS] Wi-Fi is configured to use 127.0.0.1."
        else
            warn "[FAIL] Wi-Fi does NOT appear to use 127.0.0.1."
        fi

        # 3. Check Proxy Settings (Privoxy)
        info "Checking Privoxy (HTTP/HTTPS) Proxy Settings..."
        local proxy_out
        
        # Check webproxy (HTTP)
        proxy_out=$(networksetup -getwebproxy Wi-Fi)
        echo "$proxy_out"
        if echo "$proxy_out" | grep -q "Enabled: Yes" && \
           echo "$proxy_out" | grep -q "Server: 127.0.0.1" && \
           echo "$proxy_out" | grep -q "Port: 8118"; then
            info "[PASS] HTTP Proxy is using Privoxy (127.0.0.1:8118)."
        else
            warn "[FAIL] HTTP Proxy is NOT correctly configured for Privoxy."
        fi
        
        # Check securewebproxy (HTTPS)
        proxy_out=$(networksetup -getsecurewebproxy Wi-Fi)
        echo "$proxy_out"
        if echo "$proxy_out" | grep -q "Enabled: Yes" && \
           echo "$proxy_out" | grep -q "Server: 127.0.0.1" && \
           echo "$proxy_out" | grep -q "Port: 8118"; then
            info "[PASS] HTTPS Proxy is using Privoxy (127.0.0.1:8118)."
        else
            warn "[FAIL] HTTPS Proxy is NOT correctly configured for Privoxy."
        fi
    fi

    # 3. Test Valid DNSSEC
    info "Testing Valid DNSSEC (icann.org)..."
    if ! command -v dig &> /dev/null; then
        warn "dig command not found. Skipping DNSSEC tests."
        return
    fi

    local digging=$(dig +dnssec icann.org @127.0.0.1)
    if echo "$digging" | grep -q "NOERROR" && echo "$digging" | grep -q "ad"; then
        info "[PASS] Valid DNSSEC signature verified (NOERROR + ad flag)."
    else
        warn "[FAIL] DNSSEC validation failed for icann.org."
        # Print status line for debugging
        echo "$digging" | grep "status:"
        echo "$digging" | grep "flags:"
    fi

    # 4. Test Invalid DNSSEC (Should Fail)
    info "Testing Invalid DNSSEC (dnssec-failed.org)..."
    local digging_fail=$(dig www.dnssec-failed.org @127.0.0.1)
    if echo "$digging_fail" | grep -q "SERVFAIL"; then
        info "[PASS] Invalid DNSSEC rejected (SERVFAIL)."
    else
        warn "[FAIL] Invalid DNSSEC was NOT rejected (Expected SERVFAIL)."
        echo "$digging_fail" | grep "status:"
    fi
}

# Unset Proxies and Restore Defaults
network_restore_default() {
    header "Restoring Network Defaults"
    
    # 1. Stop Anonymity Services
    info "Stopping privacy services..."
    manage_service "stop" "privoxy"
    manage_service "stop" "dnscrypt-proxy" "true"
    manage_service "stop" "unbound" "true"

    # 2. Disable Proxies on Wi-Fi
    info "Disabling Proxies on Wi-Fi..."
    execute_sudo "Disable HTTP Proxy" networksetup -setwebproxystate Wi-Fi off
    execute_sudo "Disable HTTPS Proxy" networksetup -setsecurewebproxystate Wi-Fi off
    
    # 3. Restore DNS to System Default (DHCP)
    info "Resetting DNS to System Default (DHCP)..."
    network_set_dns "default"
    
    success "Network restored to default settings."
}

# Enable Anonymity Services
network_enable_anonymity() {
    header "Enabling Anonymity Mode"
    
    # 1. Start Services
    info "Starting privacy services..."
    manage_service "start" "dnscrypt-proxy" "true"
    manage_service "start" "unbound" "true"
    manage_service "start" "privoxy"
    
    # 2. Set DNS to Localhost (DNSCrypt/Unbound)
    info "Setting DNS to Localhost..."
    network_set_dns "localhost"
    
    # 3. Enable Proxies (Privoxy)
    info "Enabling Privoxy on Wi-Fi (127.0.0.1:8118)..."
    execute_sudo "Set HTTP Proxy" networksetup -setwebproxy Wi-Fi 127.0.0.1 8118
    execute_sudo "Set HTTPS Proxy" networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 8118
    
    success "Anonymity mode enabled."
}
