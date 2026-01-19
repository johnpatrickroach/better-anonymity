#!/bin/bash
# tests/unit_network.sh
# Unit tests for lib/network.sh

# Source the test framework
source "$(dirname "$0")/test_framework.sh"

# Mock required libraries
source "$(dirname "$0")/../lib/core.sh"
# Source the file under test
source "$(dirname "$0")/../lib/network.sh"

# Mocks
# ------------------------------------------------------------------------------

# Mock execute_sudo to just run the command or echo it
execute_sudo() {
    shift # Remove description
    "$@"
}

# Mock logging functions to capture output
info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
error() { echo "[ERROR] $*"; }
success() { echo "[SUCCESS] $*"; }

# Mock brew
brew() {
    if [[ "$*" == "services list" ]]; then
        if [ "${MOCK_ROOT_SERVICES_RUNNING:-false}" == "true" ]; then
            echo "dnscrypt-proxy started"
            echo "unbound        started"
        fi
        if [ "${MOCK_USER_SERVICES_RUNNING:-false}" == "true" ]; then
            echo "privoxy        started"
            echo "tor            started"
        fi
    else
        return 0
    fi
}

# Mock pgrep
pgrep() {
    local service="$2"
    # Fallback/specific control
    if [[ "$service" == "dnscrypt-proxy" && "${MOCK_PGREP_DNSCRYPT}" == "true" ]]; then return 0; fi

    if [[ "$service" == "dnscrypt-proxy" && "${MOCK_ROOT_SERVICES_RUNNING:-false}" == "true" ]]; then return 0; fi
    if [[ "$service" == "unbound" && "${MOCK_ROOT_SERVICES_RUNNING:-false}" == "true" ]]; then return 0; fi
    if [[ "$service" == "privoxy" && "${MOCK_USER_SERVICES_RUNNING:-false}" == "true" ]]; then return 0; fi
    if [[ "$service" == "tor" && "${MOCK_USER_SERVICES_RUNNING:-false}" == "true" ]]; then return 0; fi
    return 1
}

# Mock networksetup
networksetup() {
    if [[ "$1" == "-getdnsservers" ]]; then
        if [ "${MOCK_DNS_LOCALHOST:-false}" == "true" ]; then
            echo "127.0.0.1"
        else
            echo "8.8.8.8"
        fi
    elif [[ "$1" == "-getwebproxy" || "$1" == "-getsecurewebproxy" ]]; then
        if [ "${MOCK_PROXY_ENABLED:-false}" == "true" ]; then
            echo "Enabled: Yes"
            echo "Server: 127.0.0.1"
            echo "Port: 8118"
        else
            echo "Enabled: No"
        fi
    elif [[ "$1" == "-getsocksfirewallproxy" ]]; then
         if [ "${MOCK_SOCKS_ENABLED:-false}" == "true" ]; then
            echo "Enabled: Yes"
            echo "Server: 127.0.0.1"
            echo "Port: 9050"
        else
            echo "Enabled: No"
        fi
    else
        return 0
    fi
}

# Mock scutil
scutil() {
    if [[ "$1" == "--dns" ]]; then
        if [ "${MOCK_SYSTEM_RESOLVER_LOCALHOST:-false}" == "true" ]; then
            echo "nameserver[0] : 127.0.0.1"
        else
            echo "nameserver[0] : 192.168.1.1"
        fi
    fi
}

# Mock dig
dig() {
    if [[ "$*" == *"dnssec-failed"* ]]; then
        if [ "${MOCK_DNSSEC_VALID:-true}" == "true" ]; then
            echo ";; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 15190"
        else
            echo ";; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 15190"
        fi
    else
        if [ "${MOCK_DNSSEC_VALID:-true}" == "true" ]; then
            echo ";; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 47039"
            echo ";; flags: qr rd ra ad; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1"
        else
             echo ";; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 47039"
        fi
    fi
}

# Mock is_brew_installed
is_brew_installed() {
    if [[ "$1" == "i2p" ]]; then
        return 1 # Assume not installed for basic tests, or mock if needed
    fi
    return 0
}

detect_active_network() {
    export PLATFORM_ACTIVE_SERVICE="Wi-Fi"
}


# Mock grep using PATH interception (Function export unreliable for grep in subshells on some systems)
setup_path_mocks() {
    MOCK_BIN=$(mktemp -d)
    export PATH="$MOCK_BIN:$PATH"
    
    # Create mock grep
    cat << 'EOF' > "$MOCK_BIN/grep"
#!/bin/bash
# Debug:
# echo "DEBUG: grep mock called with args: $*" >> /tmp/grep_mock.log

# Parse args to find file and pattern
PATTERN=""
FILE=""
IS_QUIET=0

for arg in "$@"; do
    if [[ "$arg" == "-q" ]]; then
        IS_QUIET=1
    elif [[ -z "$PATTERN" ]] && [[ "$arg" != -* ]]; then
        PATTERN="$arg"
    elif [[ -n "$PATTERN" ]] && [[ -z "$FILE" ]]; then
        FILE="$arg"
    fi
done

if [[ "$FILE" == "/etc/hosts" ]]; then
    # Check against exported mock content
    if echo "$MOCK_HOSTS_CONTENT" | /usr/bin/grep -q "$PATTERN"; then
        exit 0
    else
        exit 1
    fi
fi
# Fallback
if [ -z "$FILE" ]; then
    cat - | /usr/bin/grep "$@"
else
    /usr/bin/grep "$@"
fi
EOF
    chmod +x "$MOCK_BIN/grep"
}

# Clean up mocks
teardown_path_mocks() {
    rm -rf "$MOCK_BIN"
}

# Tests
# ------------------------------------------------------------------------------

start_suite "Network Verification Tests"
setup_path_mocks

# Test 1: Full Success Scenario
# -----------------------------

MOCK_ROOT_SERVICES_RUNNING="true"
MOCK_USER_SERVICES_RUNNING="true"
MOCK_DNS_LOCALHOST="true"
MOCK_SYSTEM_RESOLVER_LOCALHOST="true"
MOCK_PROXY_ENABLED="true"
MOCK_SOCKS_ENABLED="true"
MOCK_DNSSEC_VALID="true"

OUTPUT=$(network_verify_anonymity)

assert_contains "$OUTPUT" "dnscrypt-proxy is running" "Should verify dnscrypt-proxy running"
assert_contains "$OUTPUT" "unbound is running" "Should verify unbound running"
assert_contains "$OUTPUT" "privoxy is running" "Should verify privoxy running"
assert_contains "$OUTPUT" "tor service is running" "Should verify tor running"
assert_contains "$OUTPUT" "System resolver is using localhost" "Should verify system resolver"
assert_contains "$OUTPUT" "Wi-Fi is configured to use 127.0.0.1" "Should verify interface DNS"
assert_contains "$OUTPUT" "HTTP Proxy is using Privoxy" "Should verify HTTP proxy"
assert_contains "$OUTPUT" "HTTPS Proxy is using Privoxy" "Should verify HTTPS proxy"
assert_contains "$OUTPUT" "Tor SOCKS Proxy detected" "Should detect SOCKS proxy"
assert_contains "$OUTPUT" "Valid DNSSEC signature verified" "Should verify valid DNSSEC"
assert_contains "$OUTPUT" "Invalid DNSSEC rejected" "Should verify invalid DNSSEC rejection"

# Test 2: Services Failure
# ------------------------
MOCK_ROOT_SERVICES_RUNNING="false"
MOCK_USER_SERVICES_RUNNING="false"
OUTPUT=$(network_verify_anonymity)
assert_contains "$OUTPUT" "dnscrypt-proxy is NOT running" "Should detect dnscrypt failure"
assert_contains "$OUTPUT" "privoxy is NOT running" "Should detect privoxy failure"

# Test 3: DNS Failure
# -------------------
MOCK_DNS_LOCALHOST="false"
MOCK_SYSTEM_RESOLVER_LOCALHOST="false"
OUTPUT=$(network_verify_anonymity)
assert_contains "$OUTPUT" "does NOT appear to use 127.0.0.1" "Should detect interface DNS failure"
assert_contains "$OUTPUT" "System resolver does NOT appear to use 127.0.0.1" "Should detect system resolver failure"

# Test 4: Proxy Failure
# ---------------------
MOCK_PROXY_ENABLED="false"
OUTPUT=$(network_verify_anonymity)
assert_contains "$OUTPUT" "HTTP Proxy is NOT correctly configured" "Should detect HTTP proxy failure"

# Test 5: DNSSEC Failure
# ----------------------
MOCK_DNSSEC_VALID="false"
OUTPUT=$(network_verify_anonymity)
assert_contains "$OUTPUT" "DNSSEC validation failed" "Should detect DNSSEC validation failure"

# Test 7: Service Check Fallback (Brew fails, pgrep succeeds)
# -----------------------------------------------------------
MOCK_ROOT_SERVICES_RUNNING="false"
MOCK_PGREP_DNSCRYPT="true"
OUTPUT=$(network_verify_anonymity)
assert_contains "$OUTPUT" "dnscrypt-proxy is running" "Should detect running service via fallback"
MOCK_PGREP_DNSCRYPT="false" # Reset



# Test 6: Network Update Hosts (Clean Install)
# --------------------------------------------
MOCK_HOSTS_CONTENT="127.0.0.1 localhost"
# Mock curl success
curl() { return 0; }
# Mock file read of config/hosts
cat() {
    if [[ "$*" == *"config/hosts"* ]]; then
        echo "0.0.0.0 ads.example.com"
    elif [[ "$*" == "/etc/hosts" ]]; then
        echo "$MOCK_HOSTS_CONTENT"
    else
        # In the update logic, we do `cat '$TEMP_BLOCKLIST'`.
        # Real cat would cat the file.
        # We need to simulate that or mock cat to return something predictable.
        # But wait, mktemp creates a real file in /tmp.
        # We should allow cat to work on /tmp files.
        if [[ "$*" == *"/tmp/"* ]] || [[ "$*" == *"/var/folders/"* ]]; then
             /bin/cat "$@"
        else
             echo "$*"
        fi
    fi
}
# Mock execute_sudo to capture the write
execute_sudo() {
    shift # Remove description
    local cmd_str="$*"
    echo "EXEC: $cmd_str"
    
    # Simulate side effects for logic flow
    if [[ "$cmd_str" == *"sed"* ]]; then
        # Simulate marker removal
        MOCK_HOSTS_CONTENT=$(echo "$MOCK_HOSTS_CONTENT" | sed '/### BETTER-ANONYMITY-START/,/### BETTER-ANONYMITY-END/d')
    fi
}
# grep function mock removed in favor of PATH mock
export -f cat
export -f curl
export -f execute_sudo
export MOCK_HOSTS_CONTENT

OUTPUT=$(network_update_hosts)
assert_contains "$OUTPUT" "Updating /etc/hosts" "Should announce update"
# The actual command string captured is: execute_sudo "Append blocklist" sh -c "cat '$TEMP_BLOCKLIST' | tee -a /etc/hosts > /dev/null"
# So checking for "tee -a /etc/hosts" should work if we check the EXEC output line.
assert_contains "$OUTPUT" "tee -a /etc/hosts" "Should trigger append"

# Test 7: Network Update Hosts (Update Existing)
# ----------------------------------------------
MOCK_HOSTS_CONTENT="127.0.0.1 localhost
### BETTER-ANONYMITY-START
0.0.0.0 old.ads.com
### BETTER-ANONYMITY-END"
export MOCK_HOSTS_CONTENT

OUTPUT=$(network_update_hosts)
assert_contains "$OUTPUT" "Removing old blocklist" "Should announce removal of old list"
assert_contains "$OUTPUT" "Applying blocklist" "Should apply new list"


teardown_path_mocks
end_suite

