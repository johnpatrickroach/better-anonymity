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

# Mock curl to prevent network access
curl() {
    # Check what we are downloading
    if [[ "$*" == *"google.com"* ]]; then
        return 0 # Simulate online
    elif [[ "$*" == *"raw.githubusercontent.com"* ]]; then
         # Return mock hosts content
         echo "# Title: StevenBlack/hosts"
         echo "0.0.0.0 ads.example.com"
         return 0
    fi
    echo "CURL_MOCK: $*"
    return 0
}

# Mock nc for port checks
nc() {
    local port="${@: -1}" # Last arg is usually port
    # Mock specific ports
    if [[ "$*" == *"-z"* ]]; then
        if [[ "$port" == "53" || "$port" == "5355" ]]; then
             if [ "${MOCK_ROOT_SERVICES_RUNNING:-false}" == "true" ]; then return 0; fi
        elif [[ "$port" == "8118" || "$port" == "9050" ]]; then
             if [ "${MOCK_USER_SERVICES_RUNNING:-false}" == "true" ]; then return 0; fi
        fi
        return 1
    fi
    return 0
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
# Mock grep using PATH interception (Function export unreliable for grep in subshells on some systems)
setup_path_mocks() {
    ORIGINAL_PATH="$PATH"
    MOCK_BIN=$(mktemp -d)
    trap 'rm -rf "$MOCK_BIN"' EXIT
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
    export PATH="$ORIGINAL_PATH"
    hash -r # Clear command cache
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
# Create a real temp file for hosts to verify Build & Swap logic
TEST_HOSTS=$(mktemp)
echo "127.0.0.1 localhost" > "$TEST_HOSTS"
export HOSTS_FILE="$TEST_HOSTS"

# Mock curl success
curl() { return 0; }
# Mock execute_sudo to allow cp/chmod on our temp file
execute_sudo() {
    shift # Remove description
    CMD="$1"
    shift
    # If command is cp or chmod, execute it for real on our temp file
    if [[ "$CMD" == "cp" ]] || [[ "$CMD" == "chmod" ]]; then
       "$CMD" "$@"
    else
       echo "EXEC: $CMD $*"
    fi
}

# Create temp config dir explicitly to avoid touching repo config
TEST_CONFIG_DIR=$(mktemp -d)
export CONFIG_DIR="$TEST_CONFIG_DIR"
mkdir -p "$TEST_CONFIG_DIR"
echo "0.0.0.0 ads.example.com" > "$TEST_CONFIG_DIR/hosts"

OUTPUT=$(network_update_hosts)

assert_contains "$OUTPUT" "Updating $TEST_HOSTS" "Should announce update"
assert_contains "$OUTPUT" "Applying new $TEST_HOSTS" "Should announce swap"

# Verify content
if grep -q "### BETTER-ANONYMITY-START" "$TEST_HOSTS"; then
    pass "Hosts file contains start marker"
else
    fail "Hosts file missing start marker"
fi

if grep -q "0.0.0.0 ads.example.com" "$TEST_HOSTS"; then
    pass "Hosts file contains blocklist content"
else
    fail "Hosts file missing blocklist content"
fi

# Cleanup
rm -f "$TEST_HOSTS"

# Test 7: Network Update Hosts (Update Existing)
# ----------------------------------------------
TEST_HOSTS_EXISTING=$(mktemp)
cat <<EOF > "$TEST_HOSTS_EXISTING"
127.0.0.1 localhost
### BETTER-ANONYMITY-START
0.0.0.0 old.ads.com
### BETTER-ANONYMITY-END
EOF
export HOSTS_FILE="$TEST_HOSTS_EXISTING"

OUTPUT=$(network_update_hosts)
assert_contains "$OUTPUT" "Stripping old blocklist" "Should announce removal of old list"
assert_contains "$OUTPUT" "Applying new $TEST_HOSTS_EXISTING" "Should apply new list"

# Verify old content is gone and new is present
if grep -q "old.ads.com" "$TEST_HOSTS_EXISTING"; then
    fail "Old blocklist content should be gone"
else
    pass "Old blocklist content removed"
fi

if grep -q "ads.example.com" "$TEST_HOSTS_EXISTING"; then
     pass "New blocklist content present"
else
     fail "New blocklist content missing"
fi

# Cleanup
rm -f "$TEST_HOSTS_EXISTING"
rm -rf "$TEST_CONFIG_DIR"
unset CONFIG_DIR


teardown_path_mocks

# New Network DNS Logic Suite
start_suite "Network DNS Logic"

# Mock updated networksetup for DNS tests
networksetup() {
    local cmd="$1"
    local service="$2"
    
    if [ "$cmd" == "-listallnetworkservices" ]; then
        echo "Wi-Fi"
        # echo "Ethernet"
    elif [ "$cmd" == "-getdnsservers" ]; then
        if [ "${MOCK_CURRENT_DNS:-empty}" == "empty" ]; then
             echo "There aren't any DNS Servers set on ${service}."
        else
             echo "$MOCK_CURRENT_DNS"
        fi
    elif [ "$cmd" == "-setdnsservers" ]; then
         echo "SET_DNS: $service ${*:3}"
    fi
}
export -f networksetup

# Mock execute_sudo to echo call for assertion
execute_sudo() {
    shift # Remove description
    # Save IFS, restore later, to prevent newline join
    local old_ifs="$IFS"
    IFS=" "
    local cmd="$*"
    IFS="$old_ifs"
    # Capture command execution
    echo "EXEC_SUDO: $cmd"
}
export -f execute_sudo

# Test 8: Set DNS Quad9
# ---------------------
MOCK_CURRENT_DNS="empty"
OUTPUT=$(network_set_dns "quad9")
assert_contains "$OUTPUT" "Setting DNS to Quad9" "Should announce Quad9"
assert_contains "$OUTPUT" "EXEC_SUDO: networksetup -setdnsservers Wi-Fi 9.9.9.9 149.112.112.112" "Should set Quad9 IPs"

# Test 9: Set DNS Localhost
# -------------------------
MOCK_CURRENT_DNS="8.8.8.8"
OUTPUT=$(network_set_dns "localhost")
assert_contains "$OUTPUT" "Setting DNS to Localhost" "Should announce Localhost"
assert_contains "$OUTPUT" "EXEC_SUDO: networksetup -setdnsservers Wi-Fi 127.0.0.1" "Should set Localhost IP"

# Test 10: Set DNS Default
# ------------------------
MOCK_CURRENT_DNS="127.0.0.1"
OUTPUT=$(network_set_dns "default")
assert_contains "$OUTPUT" "Resetting DNS to System Default" "Should announce Default"
assert_contains "$OUTPUT" "EXEC_SUDO: networksetup -setdnsservers Wi-Fi empty" "Should set empty"

# Test 11: Set DNS Idempotency (Skip if same)
# -------------------------------------------
MOCK_CURRENT_DNS="9.9.9.9 149.112.112.112"
OUTPUT=$(network_set_dns "quad9")
assert_contains "$OUTPUT" "DNS for Wi-Fi is already set" "Should detect existing config"
# Should NOT contain EXEC_SUDO describing networksetup setdnsservers
if echo "$OUTPUT" | grep -q "EXEC_SUDO: networksetup -setdnsservers"; then
    fail "Idempotency failed, networksetup executed."
    echo "DEBUG OUTPUT: $OUTPUT"
else
    pass "Idempotency verified (no networksetup executed)."
fi

# Test 12: Set DNS Idempotency (Default/Empty)
# --------------------------------------------
MOCK_CURRENT_DNS="empty"
OUTPUT=$(network_set_dns "default")
assert_contains "$OUTPUT" "DNS for Wi-Fi is already set to default" "Should detect existing default"

# Test 13: Detect Extra DNS Servers
# --------------------------------------------------
# Reset any previous variables
unset MOCK_CURRENT_DNS

# Override networksetup to return Extra servers + Target (Cloudflare has 1.1.1.1 1.0.0.1)
networksetup() {
    if [[ "$1" == "-listallnetworkservices" ]]; then
        echo "Wi-Fi"
    elif [[ "$1" == "-getdnsservers" ]]; then
        # Return Cloudflare (Both IPs) + Google (Extra)
        echo "1.1.1.1"
        echo "1.0.0.1"
        echo "8.8.8.8"
    else
        return 0
    fi
}

OUTPUT=$(network_set_dns "cloudflare")
assert_contains "$OUTPUT" "Setting DNS to Cloudflare" "Should announce setting Cloudflare"
assert_contains "$OUTPUT" "Detected extra/unwanted DNS servers" "Should warn about extra servers"
# Ensure it actually calls the set command (Using EXEC_SUDO marker from mock)
assert_contains "$OUTPUT" "EXEC_SUDO: networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1" "Should execute strict reset"


# Test 14: Safe Network Service Fallback
# --------------------------------------------------
# Reset any mocks
unset PLATFORM_ACTIVE_SERVICE
unset MOCK_CURRENT_DNS

# Mock detect_active_network to fail auto-detection
detect_active_network() {
    export PLATFORM_ACTIVE_SERVICE=""
}
export -f detect_active_network

# Mock networksetup to list multiple services
networksetup() {
    if [[ "$*" == *"-listallnetworkservices"* ]]; then
        echo "An asterisk (*) denotes that a network service is disabled."
        echo "Ethernet"
        echo "Wi-Fi"
        echo "Thunderbolt Bridge"
    fi
}
export -f networksetup

# Test Interactive Selection (Select 1: Ethernet)
# PS3 is sent to stderr, select output to stderr, echo $s to stdout.
# We pipe "1\n" to select "Ethernet"
SERVICE=$(echo "1" | get_safe_network_service 2>/dev/null)

if [ "$SERVICE" == "Ethernet" ]; then
    pass "Fallback prompt selected correct service (Ethernet)"
else
    fail "Fallback prompt failed. Expected 'Ethernet', got '$SERVICE'"
fi

# Test Interactive Selection (Select 2: Wi-Fi)
SERVICE_2=$(echo "2" | get_safe_network_service 2>/dev/null)

if [ "$SERVICE_2" == "Wi-Fi" ]; then
    pass "Fallback prompt selected correct service (Wi-Fi)"
else
    fail "Fallback prompt failed. Expected 'Wi-Fi', got '$SERVICE_2'"
fi

teardown_path_mocks
end_suite


