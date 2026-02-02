#!/bin/bash

# lib/network.sh
# Network config functions

network_set_dns() {
    local provider=$1
    local dns_servers=""

    case $provider in
        "localhost"|"dnscrypt-proxy"|"dnscrypt"|"unbound")
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
            dns_servers="empty"
            info "Resetting DNS to System Default (DHCP)..."
            ;;
        *)
            error "Unknown provider: $provider"
            return 1
            ;;
    esac

    services=$(networksetup -listallnetworkservices | grep -v '\*')
    
    # Use while read loop to avoid IFS issues with spaces in arguments
    echo "$services" | while read -r service; do
        if [ -z "$service" ]; then continue; fi
        
        current_dns=$(networksetup -getdnsservers "$service" | tr '\n' ' ' | sed 's/ $//')
        
        # Strict comparison to ensure NO extra servers are set (crucial for anonymity)
        if [ "$dns_servers" == "empty" ]; then
             if [[ "$current_dns" == *"There aren't any DNS Servers"* ]]; then
                 info "DNS for $service is already set to default (empty)."
                 continue
             fi
        else
             if [ "$current_dns" == "$dns_servers" ]; then
                 info "DNS for $service is already set to $dns_servers."
                 continue
             fi
        fi

        info "Configuring $service..."
        
        # Explain strict reset if we see the target servers but also extras
        if [[ "$dns_servers" != "empty" ]] && [[ "$current_dns" == *"$dns_servers"* ]]; then
             info "Detected extra/unwanted DNS servers ($current_dns). Resetting to strict list..."
        elif [[ "$dns_servers" != "empty" ]]; then
             info "DNS mismatch ($current_dns != $dns_servers). Overwriting..."
        fi

        # Requires sudo
        # Note: We must ensure standard IFS for word splitting of dns_servers
        execute_sudo "Set DNS for $service" networksetup -setdnsservers "$service" $dns_servers
    done
    
    execute_sudo "Flush DNS cache" dscacheutil -flushcache
    execute_sudo "Kill mDNSResponder" killall -HUP mDNSResponder
    info "DNS updated and cache flushed."
}

network_update_hosts() {
    local HOSTS_FILE="${HOSTS_FILE:-"/etc/hosts"}"
    info "Updating "$HOSTS_FILE" with StevenBlack blocklist..."
    local START_MARKER="### BETTER-ANONYMITY-START"
    local END_MARKER="### BETTER-ANONYMITY-END"
    
    # Use configurable config directory (defaults to config)
    local CONFIG_DIR="${CONFIG_DIR:-config}"
    local LOCAL_BLOCKLIST="$CONFIG_DIR/hosts"
    local BLOCKLIST_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

    # 1. Download Blocklist
    info "Downloading blocklist to $LOCAL_BLOCKLIST..."
    # Ensure config dir exists
    if [ ! -d "$CONFIG_DIR" ]; then mkdir -p "$CONFIG_DIR"; fi
    
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
    
    # 2. Prepare Block Content within Markers
    local TEMP_BLOCKLIST
    TEMP_BLOCKLIST=$(mktemp)
    
    echo "$START_MARKER" > "$TEMP_BLOCKLIST"
    echo "# StevenBlack Hosts Blocklist (Updated: $(date))" >> "$TEMP_BLOCKLIST"
    cat "$LOCAL_BLOCKLIST" >> "$TEMP_BLOCKLIST"
    echo "$END_MARKER" >> "$TEMP_BLOCKLIST"
    
    # 3. Apply to "$HOSTS_FILE" via Build & Swap
    local TEMP_HOSTS
    TEMP_HOSTS=$(mktemp)
    
    info "Preparing new hosts file..."
    
    # Check if markers exist to strip old block
    if grep -q "$START_MARKER" "$HOSTS_FILE"; then
        info "Stripping old blocklist from existing hosts..."
        # Use sed to delete the block range and write remainder to TEMP_HOSTS
        # We run this as current user since we only need read access to "$HOSTS_FILE"
        sed "/$START_MARKER/,/$END_MARKER/d" "$HOSTS_FILE" > "$TEMP_HOSTS"
    else
        info "No existing blocklist found. Using current hosts..."
        cat "$HOSTS_FILE" > "$TEMP_HOSTS"
    fi
    
    # Sanity Check: If original hosts wasn't empty, new one shouldn't be empty (unless it was ONLY the block)
    if [ ! -s "$TEMP_HOSTS" ] && [ -s "$HOSTS_FILE" ]; then
        # It's possible the file was only the block, or sed failed.
        # But commonly "$HOSTS_FILE" has localhost.
        # Let's check if it has localhost.
        if ! grep -q "localhost" "$HOSTS_FILE"; then
             # Original was weird, but okay.
             true
        elif ! grep -q "localhost" "$TEMP_HOSTS"; then
             warn "New hosts file seems corrupted (missing localhost). strict mode prevention."
             # Fallback: re-copy original
             cat "$HOSTS_FILE" > "$TEMP_HOSTS"
             # But this means we might double-append if the strip failed. 
             # Abort is safer?
             error "Failed to generate clean hosts file. Aborting."
             rm -f "$TEMP_BLOCKLIST" "$TEMP_HOSTS"
             return 1
        fi
    fi

    # Append new block
    info "Appending new blocklist..."
    cat "$TEMP_BLOCKLIST" >> "$TEMP_HOSTS"
    
    # Atomic Swap
    info "Applying new "$HOSTS_FILE" (requires sudo)..."
    execute_sudo "Update hosts file" cp "$TEMP_HOSTS" "$HOSTS_FILE"
    execute_sudo "Set hosts permissions" chmod 644 "$HOSTS_FILE"
    
    rm -f "$TEMP_BLOCKLIST" "$TEMP_HOSTS"
    
    # Flush cache
    execute_sudo "Flush DNS cache" dscacheutil -flushcache
    execute_sudo "Kill mDNSResponder" killall -HUP mDNSResponder
    info "Hosts file updated successfully. User content preserved."
}

# Check if a service is running using brew services or pgrep fallback
# Usage: check_service_status "brew_service_name" "process_name"
# If process_name is omitted, it defaults to brew_service_name
check_service_status() {
    local service_name="$1"
    local process_name="${2:-$service_name}"
    local running=1

    # 1. Check brew services (if available)
    if command -v brew &> /dev/null; then
         local services_list
         services_list=$(brew services list 2>/dev/null)
         
         if echo "$services_list" | grep -q "^$service_name .*started"; then
             running=0
         fi
    fi

    # 2. Fallback to pgrep (Process check)
    if [ $running -ne 0 ]; then
        if pgrep -x "$process_name" >/dev/null; then
            running=0
        fi
    fi

    return $running
}

network_check_services() {
    local net_service="$1"
    info "Checking Service Status..."

    # 1. Root Services by name
    if check_service_status "dnscrypt-proxy"; then
        info "[PASS] dnscrypt-proxy is running."
    else
        warn "[FAIL] dnscrypt-proxy is NOT running."
    fi

    if check_service_status "unbound"; then
        info "[PASS] unbound is running."
    else
        warn "[FAIL] unbound is NOT running."
    fi

    # 2. User Services
    if check_service_status "privoxy"; then
        info "[PASS] privoxy is running."
    else
        warn "[FAIL] privoxy is NOT running or not installed."
    fi

    # 3. Tor Service
    # Check for SOCKS proxy first as an indicator we SHOULD check for Tor
    if command -v networksetup &> /dev/null; then
        local socks_state
        socks_state=$(networksetup -getsocksfirewallproxy "$net_service")
        # Check if proxy is enabled and pointing to Tor port
        if echo "$socks_state" | grep -q "Enabled: Yes" && \
           echo "$socks_state" | grep -q "Server: 127.0.0.1" && \
           echo "$socks_state" | grep -q "Port: 9050"; then
             
             info "Tor SOCKS Proxy detected. Verifying Tor Service..."
             if check_service_status "tor"; then
                 info "[PASS] tor service is running."
             else
                 warn "[FAIL] tor service is NOT running but Proxy is enabled!"
             fi
        fi
    fi

    # 4. I2P Service
    if is_brew_installed "i2p"; then
       info "I2P installation detected."
       # I2p runs java with WrapperSimpleApp, harder to match exactly by name sometimes.
       # We check process or specific router status command if available.
       # Try helper first with known process name, or fall back to 'i2prouter status'
       
       if check_service_status "i2p" "i2prouter" || pgrep -f "net.i2p.router.Router" >/dev/null; then
           info "[PASS] I2P Router is running."
       else
            # Try i2prouter status as a last resort check
            if command -v i2prouter &>/dev/null && i2prouter status | grep -q "running"; then
                 info "[PASS] I2P Router is running."
            else
                 warn "[FAIL] I2P Router is installed but NOT running."
            fi
       fi
    fi
}

network_check_system_resolver() {
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
}

network_check_interface_dns() {
    local net_service="$1"
    info "Checking DNS Settings for $net_service..."
    local ns_out
    if ! command -v networksetup &> /dev/null; then
         warn "networksetup command not found. Skipping."
    else
        ns_out=$(networksetup -getdnsservers "$net_service")
        echo "$ns_out"
        if echo "$ns_out" | grep -q "127.0.0.1"; then
            info "[PASS] $net_service is configured to use 127.0.0.1."
        else
            warn "[FAIL] $net_service does NOT appear to use 127.0.0.1."
        fi
    fi
}

network_check_proxy_config() {
    local net_service="$1"
    info "Checking Privoxy (HTTP/HTTPS) Proxy Settings..."
    
    if ! command -v networksetup &> /dev/null; then
         warn "networksetup command not found. Skipping."
         return
    fi

    local proxy_out
    
    # Check webproxy (HTTP)
    proxy_out=$(networksetup -getwebproxy "$net_service")
    echo "$proxy_out"
    if echo "$proxy_out" | grep -q "Enabled: Yes" && \
       echo "$proxy_out" | grep -q "Server: 127.0.0.1" && \
       echo "$proxy_out" | grep -q "Port: 8118"; then
        info "[PASS] HTTP Proxy is using Privoxy (127.0.0.1:8118)."
    else
        warn "[FAIL] HTTP Proxy is NOT correctly configured for Privoxy."
    fi
    
    # Check securewebproxy (HTTPS)
    proxy_out=$(networksetup -getsecurewebproxy "$net_service")
    echo "$proxy_out"
    if echo "$proxy_out" | grep -q "Enabled: Yes" && \
       echo "$proxy_out" | grep -q "Server: 127.0.0.1" && \
       echo "$proxy_out" | grep -q "Port: 8118"; then
        info "[PASS] HTTPS Proxy is using Privoxy (127.0.0.1:8118)."
    else
        warn "[FAIL] HTTPS Proxy is NOT correctly configured for Privoxy."
    fi
}

network_test_dnssec() {
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
        echo "$digging" | grep "status:"
        echo "$digging" | grep "flags:"
    fi

    info "Testing Invalid DNSSEC (dnssec-failed.org)..."
    local digging_fail=$(dig www.dnssec-failed.org @127.0.0.1)
    if echo "$digging_fail" | grep -q "SERVFAIL"; then
        info "[PASS] Invalid DNSSEC rejected (SERVFAIL)."
    else
        warn "[FAIL] Invalid DNSSEC was NOT rejected (Expected SERVFAIL)."
        echo "$digging_fail" | grep "status:"
    fi
}

network_verify_anonymity() {
    info "Verifying Anonymity Network (DNS, Proxy, Tor)..."
    
    # Detect active network service
    local net_service
    net_service=$(get_safe_network_service) || return 1
    info "Targeting Network Service: $net_service"

    # 1. Check Service Status
    network_check_services "$net_service"

    # 2. Check System Resolver
    network_check_system_resolver

    # 3. Check Network Setup (DNS)
    network_check_interface_dns "$net_service"

    # 4. Check Proxy Settings
    network_check_proxy_config "$net_service"

    # 5. Check DNSSEC
    network_test_dnssec
}

# Unset Proxies and Restore Defaults
network_restore_default() {
    header "Restoring Network Defaults"
    
    # 1. Stop Anonymity Services
    info "Stopping privacy services..."
    manage_service "stop" "privoxy"
    manage_service "stop" "dnscrypt-proxy" "true"
    manage_service "stop" "unbound" "true"
    manage_service "stop" "tor" # Stop Tor if running
    # We do not forcibly stop I2P as it's often a long-running router, but could.
    # User requested 'network-open' which implies clearing anonymity routing.
    # Stopping services is consistent.
    if is_brew_installed "i2p"; then
         load_module "i2p_manager"
         i2p_stop
    fi

    # 2. Disable Proxies on Active Service
    local net_service
    net_service=$(get_safe_network_service) || return 1
    info "Disabling Proxies on $net_service..."
    execute_sudo "Disable HTTP Proxy" networksetup -setwebproxystate "$net_service" off
    execute_sudo "Disable HTTPS Proxy" networksetup -setsecurewebproxystate "$net_service" off
    execute_sudo "Disable SOCKS Proxy" networksetup -setsocksfirewallproxystate "$net_service" off
    
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
    if is_brew_installed "tor"; then
        manage_service "start" "tor"
    fi
    if is_brew_installed "i2p"; then
        load_module "i2p_manager"
        i2p_start
    fi
    
    # 2. Set DNS to Localhost (DNSCrypt/Unbound)
    info "Setting DNS to Localhost..."
    network_set_dns "localhost"
    
    # Detect active network service for Proxy
    local net_service
    net_service=$(get_safe_network_service) || return 1

    # 3. Enable Proxies (Privoxy)
    info "Enabling Privoxy on $net_service (127.0.0.1:8118)..."
    execute_sudo "Set HTTP Proxy" networksetup -setwebproxy "$net_service" 127.0.0.1 8118
    execute_sudo "Set HTTPS Proxy" networksetup -setsecurewebproxy "$net_service" 127.0.0.1 8118
    
    # 4. Enable SOCKS Proxy (Tor)
    if is_brew_installed "tor"; then
        info "Enabling Tor SOCKS Proxy on $net_service (127.0.0.1:9050)..."
        execute_sudo "Set SOCKS Proxy" networksetup -setsocksfirewallproxy "$net_service" 127.0.0.1 9050
        execute_sudo "Enable SOCKS Proxy" networksetup -setsocksfirewallproxystate "$net_service" on
    fi
    # Note: We do NOT set system proxy for I2P (4444/4445) to avoid conflict with Privoxy (8118).
    # I2P should be used via browser config or 'i2pify' alias.
    
    success "Anonymity mode enabled."
}

# Helper: Get Safe Network Service
get_safe_network_service() {
    # Try auto-detection via platform.sh
    if type -t detect_active_network | grep -q "function"; then
        detect_active_network >/dev/null # Suppress info logs from detection
    fi
    
    if [ -n "$PLATFORM_ACTIVE_SERVICE" ]; then
        echo "$PLATFORM_ACTIVE_SERVICE"
        return 0
    fi
    
    # Fallback: Prompts
    warn "Could not auto-detect active network service." >&2
    echo "Available services:" >&2
    
    local services
    # Get raw list, exclude headers
    services=$(networksetup -listallnetworkservices | grep -v 'An asterisk' | grep -v 'Start using')
    
    if [ -z "$services" ]; then
        error "No network services found!" >&2
        return 1
    fi

    # Interactive Selection
    # We use select which prints to stderr by default (good for us)
    PS3="Select active service: "
    select s in $services; do
        if [ -n "$s" ]; then
            echo "$s"
            return 0
        fi
        echo "Invalid selection." >&2
    done
}
