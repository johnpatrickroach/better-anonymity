#!/bin/bash

# tests/unit_sudoers_audit.sh
# Unit tests for Sudoers Audit Logic

source "$(dirname "$0")/test_framework.sh"

# Helper functions for reporting
pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASSED++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAILED++)); }

# Mocks
info() { echo "INFO: $*"; }
warn() { echo "WARN: $*"; }

# Mock grep (sudo grap)
# We test different grep outputs by exporting MOCK_GREP_OUTPUT
sudo() {
    if [[ "$1" == "grep" ]]; then
        echo "$MOCK_GREP_OUTPUT"
    else
        "$@"
    fi
}

start_suite "Sudoers Smart Audit"

# Source library (mocking sudo before source isn't enough if sourced functions call sudo directly,
# but our mock is defined before execution so it overrides)
source "$(dirname "$0")/../lib/macos_hardening.sh"


# Test 1: Clean/Standard Output (Should PASS silent)
# --------------------------------------------------
export MOCK_GREP_OUTPUT='/etc/sudoers:Defaults env_keep += "BLOCKSIZE"
/etc/sudoers:Defaults env_keep += "COLORFGBG COLORTERM"
/etc/sudoers:Defaults env_keep += "HOME MAIL"
/etc/sudoers:Defaults env_keep += "LC_ALL LANG TZ"'

OUTPUT=$(hardening_secure_sudoers)
if echo "$OUTPUT" | grep -q "audit passed"; then
    pass "Standard defaults (incl HOME/MAIL) -> Passed"
else
    fail "Standard defaults failed. Output:"
    echo "$OUTPUT"
fi
if echo "$OUTPUT" | grep -q "RISK"; then
    fail "Standard defaults triggered RISK warning."
fi


# Test 2: Unsafe/Unknown Variable (Should WARN)
# ---------------------------------------------
export MOCK_GREP_OUTPUT='/etc/sudoers:Defaults env_keep += "HOME MAIL"
/etc/sudoers:Defaults env_keep += "MY_SECRET_KEY"'

OUTPUT=$(hardening_secure_sudoers)
if echo "$OUTPUT" | grep -q "RISK"; then
    if echo "$OUTPUT" | grep -q "MY_SECRET_KEY"; then
        pass "Unsafe variable 'MY_SECRET_KEY' -> Detected"
    else
        fail "Unsafe variable detected but correct name missing."
    fi
else
    fail "Unsafe variable NOT detected. Output:"
    echo "$OUTPUT"
fi


# Test 3: Empty Output (Should PASS silent)
# -----------------------------------------
export MOCK_GREP_OUTPUT=""
OUTPUT=$(hardening_secure_sudoers)
if echo "$OUTPUT" | grep -q "looks clean"; then
    pass "Empty grep output -> Clean"
else
    fail "Empty output failed."
fi

# Test 4: Mixed Safe/Unsafe on same line
# --------------------------------------
export MOCK_GREP_OUTPUT='/etc/sudoers:Defaults env_keep += "LANG BAD_VAR TZ"'
OUTPUT=$(hardening_secure_sudoers)
if echo "$OUTPUT" | grep -q "RISK.*BAD_VAR"; then
    pass "Mixed line (LANG BAD_VAR TZ) -> Detected BAD_VAR"
else
    fail "Mixed line failed to detect BAD_VAR." 
fi
# Ensure LANG/TZ didn't trigger
if echo "$OUTPUT" | grep -q "RISK.*LANG"; then
    fail "Safe variable LANG falsely flagged in mixed line."
fi

end_suite
