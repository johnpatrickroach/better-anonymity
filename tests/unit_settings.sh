#!/bin/bash

# tests/unit_settings.sh
# Unit tests for settings idempotency (hardening, network, ssh)

source "$(dirname "$0")/test_framework.sh"

# Helper functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

# Mock ROOT_DIR
ROOT_DIR="$(dirname "$0")/.."
source "$(dirname "$0")/../lib/core.sh"
source "$(dirname "$0")/../lib/macos_hardening.sh"
source "$(dirname "$0")/../lib/network.sh"
source "$(dirname "$0")/../lib/ssh.sh"

start_suite "Settings Idempotency"

# Test 1: MacOS Hardening Checks
# ------------------------------
# Mock defaults
DEFAULTS_WRITE_CALLED=0

defaults() {
    local op=$1
    local domain=$2
    local key=$3
    
    if [ "$op" == "read" ]; then
        # Return correct expected values to simulate "Already Set" state
        if [[ "$domain" == *"Keystone.Agent"* ]]; then echo "0"; fi
        if [[ "$domain" == *"autoupdate2"* ]]; then echo "Manual"; fi
        if [[ "$domain" == *"office.telemetry"* ]]; then 
             if [[ "$key" == "ZeroDiagnosticData" ]]; then
                 echo "1"
             else
                 echo "0"
             fi
        fi
        return 0
    elif [ "$op" == "write" ]; then
        DEFAULTS_WRITE_CALLED=1
        echo "Written ($domain $key)"
    fi
}

# Scenario: Defaults already set correctly
DEFAULTS_WRITE_CALLED=0
hardening_disable_app_telemetry
if [ "$DEFAULTS_WRITE_CALLED" -eq 0 ]; then
    pass "Should NOT write defaults if already set"
else
    fail "Should NOT write defaults if already set"
fi

# Scenario: Defaults incorrect
# Redefine mock to return garbage
defaults() {
    local op=$1
    if [ "$op" == "read" ]; then
        echo "WRONG_VALUE"
        return 0
    elif [ "$op" == "write" ]; then
        DEFAULTS_WRITE_CALLED=1
    fi
}
DEFAULTS_WRITE_CALLED=0
hardening_disable_app_telemetry
if [ "$DEFAULTS_WRITE_CALLED" -eq 1 ]; then
    pass "Should write defaults if incorrect"
else
    fail "Should write defaults if incorrect"
fi


# Test 2: Network DNS Checks
# --------------------------
NETWORKSETUP_GET_RET=""
EXECUTE_SUDO_CALLED=0

# Mock networksetup
networksetup() {
    if [ "$1" == "-listallnetworkservices" ]; then
        echo "Wi-Fi"
    elif [ "$1" == "-getdnsservers" ]; then
        echo "$NETWORKSETUP_GET_RET"
    elif [ "$1" == "-setdnsservers" ]; then
        return 0
    fi
}
# Mock execute_sudo to track calls
execute_sudo() {
    local desc="$1"
    if [[ "$desc" == "Set DNS"* ]]; then
        EXECUTE_SUDO_CALLED=1
    fi
}

# Scenario: DNS already matches
NETWORKSETUP_GET_RET="9.9.9.9
149.112.112.112"
EXECUTE_SUDO_CALLED=0
network_set_dns "quad9"
if [ "$EXECUTE_SUDO_CALLED" -eq 0 ]; then
    pass "Should NOT set DNS if already matches"
else
    fail "Should NOT set DNS if already matches"
fi

# Scenario: DNS differs
NETWORKSETUP_GET_RET="1.1.1.1" # Cloudflare
EXECUTE_SUDO_CALLED=0
network_set_dns "quad9"
if [ "$EXECUTE_SUDO_CALLED" -eq 1 ]; then
    pass "Should set DNS if differs"
else
    fail "Should set DNS if differs"
fi


# Test 3: SSH Config Backup
# -------------------------
CHECK_CONFIG_RET=1
CHMOD_CALLED=0

# Mock check_config_and_backup
check_config_and_backup() {
    return "$CHECK_CONFIG_RET"
}

# Mock execute_sudo for chmod/chown
execute_sudo() {
    local desc="$1"
    if [[ "$desc" == "Set permissions"* ]]; then
        CHMOD_CALLED=1
    fi
}

# Scenario: Configs Identical (check_config returns 0)
CHECK_CONFIG_RET=0
CHMOD_CALLED=0
# Mock confirm/ensure_root
ask_confirmation() { return 0; }
ensure_root() { return 0; }
# Mock sshd
sshd() { return 0; }

ssh_harden_sshd >/dev/null 2>&1
# If update happens (helper returns 0), we chmod.
# If helper says "identical", it still returns 0 (per core.sh impl).
# So we basically always chmod if check_config_and_backup returns 0.
# The idempotency is inside check_config_and_backup (skipping the cp).
# So chmod being called is fine and expected as long as check succeeds.
if [ "$CHMOD_CALLED" -eq 1 ]; then
    pass "Should chmod if check_config succeeds"
else
    fail "Should chmod if check_config succeeds"
fi

# Test Failure case for check_config
CHECK_CONFIG_RET=1
CHMOD_CALLED=0
ssh_harden_sshd >/dev/null 2>&1
if [ "$CHMOD_CALLED" -eq 0 ]; then
    pass "Should NOT chmod if check_config fails"
else
    fail "Should NOT chmod if check_config fails. Called: $CHMOD_CALLED"
fi

end_suite

