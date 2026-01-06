#!/bin/bash

# tests/unit_diagnosis.sh
# Unit tests for Diagnosis & Scoring

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

# Mock core
header() { :; }
info() { echo "INFO: $*"; }
warn() { echo "WARN: $*"; }
success() { echo "SUCCESS: $*"; }

# Mock external commands for control
SOCKETFILTERFW_CMD="socketfilterfw"
socketfilterfw() {
    if [ "$1" == "--getglobalstate" ]; then
        if [ "$MOCK_FW" == "on" ]; then echo "enabled"; else echo "disabled"; fi
    elif [ "$1" == "--getstealthmode" ]; then
         if [ "$MOCK_FW_STEALTH" == "on" ]; then echo "enabled"; else echo "disabled"; fi
    fi
}
fdesetup() {
    if [ "$MOCK_FV" == "on" ]; then echo "FileVault is On"; else echo "Off"; fi
}
csrutil() {
    if [ "$MOCK_SIP" == "on" ]; then echo "enabled"; else echo "disabled"; fi
}
spctl() {
    if [ "$MOCK_GK" == "on" ]; then echo "assessments enabled"; else echo "disabled"; fi
}
systemsetup() {
    if [ "$MOCK_SSH_OFF" == "on" ]; then echo "Off"; else echo "On"; fi
}
defaults() {
    # Check key privacy args
    local domain=$2
    local key=$3
    if [ "$domain" == "/Library/Preferences/com.apple.loginwindow" ] && [ "$key" == "AutoSubmit" ]; then
        echo "$MOCK_ANALYTICS"
    elif [ "$domain" == "com.apple.AdLib" ] && [ "$key" == "forceLimitAdTracking" ]; then
        echo "$MOCK_ADLIMIT"
    elif [ "$domain" == "/Library/Preferences/org.mozilla.firefox" ] && [ "$key" == "DisableTelemetry" ]; then
        echo "$MOCK_FF_TEL"
    else
        echo "0"
    fi
}
is_brew_installed() {
    local pkg=$1
    if [ "$pkg" == "tor" ] && [ "$MOCK_TOR" == "on" ]; then return 0; fi
    if [ "$pkg" == "i2p" ] && [ "$MOCK_I2P" == "on" ]; then return 0; fi
    return 1
}
networksetup() {
    echo "$MOCK_DNS_OUT"
}

# Source Library
source "$(dirname "$0")/../lib/diagnosis.sh"

start_suite "System Diagnosis"

# Test 1: Full Pass (Score 100/100/100)
# -------------------------------------
MOCK_FW="on"
MOCK_FW_STEALTH="on"
MOCK_FV="on"
MOCK_SIP="on"
MOCK_GK="on"
MOCK_SSH_OFF="on" # Remote Login Off = Good

MOCK_ANALYTICS="0" # Disabled = Good
MOCK_ADLIMIT="1" # Enabled = Good
MOCK_FF_TEL="1" # Disabled = Good
# Brew Analytics mock is command based, hard to mock in function overrides without 'function brew()'.
# Let's override brew if present in lib? Diagnosis uses `command -v brew` then `brew analytics`.
brew() { echo "Analytics are disabled."; }

MOCK_TOR="on"
MOCK_I2P="on"
MOCK_DNS_OUT="9.9.9.9" 
# Airport check relies on file existence. We can't mock file check easily in bash without overriding [ ]?
# diagnosis.sh: if [ -x "...airport" ]
# We can't mock that easily. It might fail on generic env.
# But we can check if the score is somewhat high.

OUTPUT=$(diagnosis_run)
if echo "$OUTPUT" | grep -q "Security: .*100/100"; then
    pass "Security Score 100 detected"
else
    fail "Security Score failed for perfect run"
    echo "$OUTPUT" | grep "Security:"
fi

if echo "$OUTPUT" | grep -q "Anonymity: .*75/100" || echo "$OUTPUT" | grep -q "Anonymity: .*100/100"; then
    pass "Anonymity Score High (Account for airport check variability)"
else
    fail "Anonymity Score failed"
    echo "$OUTPUT" | grep "Anonymity:"
fi

# Test 2: Poor Security (Score < 50)
# ----------------------------------
MOCK_FW="off"
MOCK_FV="off"
MOCK_SIP="off"
MOCK_GK="off"
OUTPUT=$(diagnosis_run)
if echo "$OUTPUT" | grep -q "Security: .*20/100" || echo "$OUTPUT" | grep -q "Security: .*10/100"; then
    pass "Low Security Score detected"
else
    fail "Low Security Score failed. Got:"
    echo "$OUTPUT" | grep "Security:"
fi

end_suite
