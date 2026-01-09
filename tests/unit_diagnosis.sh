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

# Mock sudo to bypass password prompt and use mocked functions
sudo() {
    "$@"
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
# Test 1: Full Pass (Score 100/100/100)
# -------------------------------------
export MOCK_FW="on"
export MOCK_FW_STEALTH="on"
export MOCK_FV="on"
export MOCK_SIP="on"
export MOCK_GK="on"
export MOCK_SSH_OFF="on"

export MOCK_ANALYTICS="0"
export MOCK_ADLIMIT="1"
export MOCK_FF_TEL="1"
export MOCK_USER_JS="on"     # find find
export MOCK_FF_INSTALLED="on" # check_dir_exists /App/Firefox.app
export MOCK_FF_PROFILE="on"   # check_dir_exists Profiles

export MOCK_SIGNAL="on"
export MOCK_KEEPASSXC="on"

# Brew function
brew() { echo "Analytics are disabled."; }

export MOCK_TOR="on"
export MOCK_TOR_BROWSER="on"
export MOCK_I2P="on"
export MOCK_PRIVOXY="on"
export MOCK_GPG="on"
export MOCK_OPENSSL="on"

export MOCK_DNS_OUT="127.0.0.1"
export MOCK_SERVICE_RUNNING="on"

# Mock pgrep
pgrep() {
    if [ "$MOCK_SERVICE_RUNNING" == "on" ]; then return 0; else return 1; fi
}


# Mock find (for user.js)
find() {
    if [ "$MOCK_USER_JS" == "on" ]; then echo "/path/to/user.js"; else echo ""; fi
}

# Mock command -v for gpg/openssl
command() {
    if [ "$1" == "-v" ]; then
        local tool="$2"
        if [ "$tool" == "brew" ] && [ "${MOCK_BREW:-on}" == "on" ]; then return 0; fi
        if [ "$tool" == "gpg" ] && [ "$MOCK_GPG" == "on" ]; then return 0; fi
        if [ "$tool" == "openssl" ] && [ "$MOCK_OPENSSL" == "on" ]; then return 0; fi
        # Default behavior:
        type "$tool" >/dev/null 2>&1
    else
        # Pass through
        builtin command "$@"
    fi
}

is_brew_installed() {
    local pkg=$1
    if [ "$pkg" == "tor" ] && [ "$MOCK_TOR" == "on" ]; then return 0; fi
    if [ "$pkg" == "i2p" ] && [ "$MOCK_I2P" == "on" ]; then return 0; fi
    if [ "$pkg" == "privoxy" ] && [ "$MOCK_PRIVOXY" == "on" ]; then return 0; fi
    return 1
}

is_cask_installed() {
    local pkg=$1
    if [ "$pkg" == "signal" ] && [ "$MOCK_SIGNAL" == "on" ]; then return 0; fi
    if [ "$pkg" == "keepassxc" ] && [ "$MOCK_KEEPASSXC" == "on" ]; then return 0; fi
    return 1
}

is_app_installed() {
    local app=$1
    if [ "$app" == "Signal.app" ] && [ "$MOCK_SIGNAL" == "on" ]; then return 0; fi
    if [ "$app" == "KeePassXC.app" ] && [ "$MOCK_KEEPASSXC" == "on" ]; then return 0; fi
    if [ "$app" == "Tor Browser.app" ] && [ "$MOCK_TOR_BROWSER" == "on" ]; then return 0; fi
    return 1
}

networksetup() {
    echo "$MOCK_DNS_OUT"
}

# Mock airport
check_airport_exists() {
    return 0 # Always pass in test
}

# Mock dir check
check_dir_exists() {
    local d="$1"
    if [ "$d" == "/Applications/Firefox.app" ] && [ "$MOCK_FF_INSTALLED" == "on" ]; then return 0; fi
    if [[ "$d" == *"Firefox/Profiles"* ]] && [ "$MOCK_FF_PROFILE" == "on" ]; then return 0; fi
    return 1
}

OUTPUT=$(diagnosis_run)
if echo "$OUTPUT" | grep -q "Security: .*100/100"; then
    pass "Security Score 100 detected"
else
    fail "Security Score failed for perfect run. Output:"
    echo "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "Privacy.*: .*100/100"; then
    pass "Privacy Score 100 detected"
else
    fail "Privacy Score failed for perfect run. Output:"
    echo "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "Anonymity: .*100/100"; then
    pass "Anonymity Score 100 detected"
else
    fail "Anonymity Score failed for perfect run. Output:"
    echo "$OUTPUT"
fi

# Test 2: Poor Security (Score < 50)
# ----------------------------------
MOCK_FW="off"
MOCK_FV="off"
MOCK_SIP="off"
MOCK_GK="off"
OUTPUT=$(diagnosis_run)
if echo "$OUTPUT" | grep -q "Security: .*20/100" || echo "$OUTPUT" | grep -q "Security: .*10/100" || echo "$OUTPUT" | grep -q "Security: .*40/100"; then
    pass "Low Security Score detected"
else
    fail "Low Security Score failed. Got:"
    echo "$OUTPUT" | grep "Security:"
fi

end_suite
