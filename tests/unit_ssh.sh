#!/bin/bash

# tests/unit_ssh.sh
# Unit tests for SSH Logic (Status Checking)

source "$(dirname "$0")/test_framework.sh"

# Helper functions for reporting
pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASSED++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAILED++)); }

# Mocks
info() { echo "INFO: $*"; }
warn() { echo "WARN: $*"; }
success() { echo "SUCCESS: $*"; }

# Mock sudo: Fail by default (simulating non-root with no password)
sudo() {
    return 1
}

# Mock launchctl
# We verify fallback logic by controlling output
launchctl() {
    if [[ "$1" == "list" ]] && [[ "$2" == "com.openssh.sshd" ]]; then
        if [ "$MOCK_LAUNCHCTL_SSH" == "on" ]; then
            return 0
        else
            return 1
        fi
    fi
    return 1
}

# Mock check_port (lib/core.sh usually provides this, we mock for isolation)
check_port() {
    if [ "$MOCK_PORT_SSH" == "on" ]; then return 0; else return 1; fi
}


start_suite "SSH Status Logic"

# Source library
# We need to make sure core.sh is not re-sourcing check_port if we mocked it,
# but lib/ssh.sh doesn't source core.sh itself usually, better-anonymity main does.
# We will define CORE mocks if needed.
source "$(dirname "$0")/../lib/ssh.sh"

# Test 1: Sudo fails, Launchctl succeeds (Service On)
# ---------------------------------------------------
MOCK_LAUNCHCTL_SSH="on"
MOCK_PORT_SSH="off"

OUTPUT=$(ssh_check_sshd_status)
if echo "$OUTPUT" | grep -q "Remote Login:.*On.*Service com.openssh.sshd is loaded"; then
    pass "Sudo Fail + Launchctl Success -> Detected ON"
else
    fail "Sudo Fail + Launchctl Success failed. Output:"
    echo "$OUTPUT"
fi

# Test 2: Sudo fails, Launchctl fails, Port succeeds (Service On via Port)
# ------------------------------------------------------------------------
MOCK_LAUNCHCTL_SSH="off"
MOCK_PORT_SSH="on"

OUTPUT=$(ssh_check_sshd_status)
if echo "$OUTPUT" | grep -q "Remote Login:.*On.*Listening on Port 22"; then
    pass "Launchctl Fail + Port Success -> Detected ON"
else
    fail "Launchctl Fail + Port Success failed. Output:"
    echo "$OUTPUT"
fi

# Test 3: All Fail (Service Off)
# ------------------------------
MOCK_LAUNCHCTL_SSH="off"
MOCK_PORT_SSH="off"

OUTPUT=$(ssh_check_sshd_status)
if echo "$OUTPUT" | grep -q "Remote Login:.*Off"; then
    pass "All Fail -> Detected OFF"
else
    fail "All Fail failed. Output:"
    echo "$OUTPUT"
fi

end_suite

start_suite "SSH Key Audit"

# Test 1: No SSH directory
export HOME="/tmp/nonexistent_home_$$"
OUTPUT=$(ssh_audit_keys)
if echo "$OUTPUT" | grep -q "No SSH directory found"; then
    pass "Audit -> Handled missing .ssh directory"
else
    fail "Audit -> Failed to handle missing .ssh directory. Output:"
    echo "$OUTPUT"
fi

# Test 2: With keys
export HOME=$(mktemp -d)
mkdir -p "$HOME/.ssh"
touch "$HOME/.ssh/id_rsa"
touch "$HOME/.ssh/id_ed25519"
touch "$HOME/.ssh/id_rsa.pub" # Should be skipped

# Mock ssh-keygen
ssh-keygen() {
    # -y -P "" -f <key>
    # If the key is id_rsa, let's pretend it HAS NO passphrase (succeeds)
    # If the key is id_ed25519, let's pretend it HAS a passphrase (fails)
    if [[ "$*" == *id_rsa* ]]; then
        return 0 # No passphrase
    else
        return 1 # Has passphrase
    fi
}

OUTPUT=$(ssh_audit_keys)

if echo "$OUTPUT" | grep -q '\[RISK\] Key uses RSA'; then
    pass "Audit -> Detected RSA key risk"
else
    fail "Audit -> Failed to detect RSA key. Output:"
    echo "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q '\[PASS\] Key uses strong encryption.*id_ed25519'; then
    pass "Audit -> Detected strong encryption"
else
    fail "Audit -> Failed to detect strong encryption. Output:"
    echo "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q '\[RISK\] Key (id_rsa) does NOT have a passphrase'; then
    pass "Audit -> Detected missing passphrase"
else
    fail "Audit -> Failed to detect missing passphrase. Output:"
    echo "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q '\[PASS\] Key (id_ed25519) requires a passphrase'; then
    pass "Audit -> Detected existing passphrase"
else
    fail "Audit -> Failed to detect existing passphrase. Output:"
    echo "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q '1/2 keys are protected by a passphrase'; then
    pass "Audit -> Correct summary counts"
else
    fail "Audit -> Incorrect summary counts. Output:"
    echo "$OUTPUT"
fi

rm -rf "$HOME"
end_suite
