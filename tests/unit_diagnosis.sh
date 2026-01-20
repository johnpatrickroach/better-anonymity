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

# Mock path check
check_path() {
    if [[ "$1" == "/Applications/Firefox.app" ]] && [[ "$MOCK_FF_INSTALLED" == "on" ]]; then return 0; fi
    # Pattern match for profile dir
    if [[ "$1" == *"Firefox/Profiles"* ]] && [[ "$MOCK_FF_PROFILE" == "on" ]]; then return 0; fi
    return 1
}

# Mock grep to intercept sshd_config reads
grep() {
    local last_arg="${!#}"
    if [[ "$last_arg" == "/etc/ssh/sshd_config" ]]; then
        # Remove the last argument (the filename) and pipe mock content
        # usage: grep [options] pattern filename
        # We want: echo "$MOCK_SSH_CONFIG" | grep [options] pattern
        
        # Get all args except the last one
        local args=("${@:1:$#-1}")
        
        # We must use 'command grep' or 'builtin grep' (if available, usually not).
        # 'command grep' ensures we call the system grep, avoiding infinite recursion if we didn't check filename.
        # But we are mocking grep, so 'grep' calls us.
        # We need to call the REAL grep.
        if echo "$MOCK_SSH_CONFIG" | command grep "${args[@]}"; then
            return 0
        else
            return 1
        fi
    fi
    # Pass through normal grep usage
    command grep "$@"
}

# Mock section (Core)
section() {
    echo "SECTION: $1"
    shift
    for line in "$@"; do
        echo "$line"
    done
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

# Test 3: Firefox Not Installed (Privacy Bonus)
# ---------------------------------------------
# Reset to full pass state first
export MOCK_FW="on"
export MOCK_FW_STEALTH="on"
export MOCK_FV="on"
export MOCK_SIP="on"
export MOCK_GK="on"
export MOCK_SSH_OFF="on"
export MOCK_ANALYTICS="0"
export MOCK_ADLIMIT="1"
export MOCK_FF_TEL="1"
export MOCK_USER_JS="on"
export MOCK_SIGNAL="on"
export MOCK_KEEPASSXC="on"
export MOCK_TOR="on"
export MOCK_TOR_BROWSER="on"
export MOCK_I2P="on"
export MOCK_PRIVOXY="on"
export MOCK_GPG="on"
export MOCK_OPENSSL="on"
export MOCK_DNS_OUT="127.0.0.1"
export MOCK_SERVICE_RUNNING="on"

# Set Firefox to NOT installed
export MOCK_FF_INSTALLED="off"

OUTPUT=$(diagnosis_run)
if echo "$OUTPUT" | grep -q "Privacy.*: .*100/100"; then
    pass "Privacy Score 100 detected with Firefox not installed (Bonus applied)"
else
    fail "Privacy Score failed for Firefox bonus. Got:"
    echo "$OUTPUT" | grep "Privacy"
fi



# Test 4: SSH Hardening Scoring
# -----------------------------
# Case A: Remote Login OFF (Score 10)
export MOCK_SSH_OFF="on"
OUTPUT=$(diagnosis_run)
if echo "$OUTPUT" | grep -q "Security: .*100/100"; then
    pass "SSH: Off -> Full Score"
else
    fail "SSH: Off failed. Got:"
    echo "$OUTPUT" | grep "Security"
fi

# Case B: Remote Login ON + Weak Config (Score 0 or Partial)
export MOCK_SSH_OFF="off"
export MOCK_SSH_CONFIG=""
OUTPUT=$(diagnosis_run)
if echo "$OUTPUT" | grep -q "Security: .*90/100"; then # Lost 10 pts
    pass "SSH: On + Weak -> Correctly penalized"
else
    fail "SSH: On + Weak failed. Got:"
    echo "$OUTPUT" | grep "Security"
fi

# Case C: Remote Login ON + Partial Config (PermitRootLogin only) (Score 5)
export MOCK_SSH_CONFIG="PermitRootLogin no"
OUTPUT=$(diagnosis_run)
if echo "$OUTPUT" | grep -q "Security: .*95/100"; then # Lost 5 pts
    pass "SSH: On + Partial -> Correctly scored (5/10)"
else
    fail "SSH: On + Partial failed. Got:"
    echo "$OUTPUT" | grep "Security"
fi

# Case D: Remote Login ON + Full Hardening (Score 10)
export MOCK_SSH_CONFIG=$'PermitRootLogin no\nPasswordAuthentication no'
OUTPUT=$(diagnosis_run)
if echo "$OUTPUT" | grep -q "Security: .*100/100"; then
    pass "SSH: On + Hardened -> Full Score"
else
    fail "SSH: On + Hardened failed. Got:"
    echo "$OUTPUT" | grep "Security"
fi

end_suite
