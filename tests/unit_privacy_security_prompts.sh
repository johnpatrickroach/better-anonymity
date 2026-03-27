#!/bin/bash
# tests/unit_privacy_security_prompts.sh
# Verify "Privacy Over Security" prompt logic

source "$(dirname "$0")/test_framework.sh"

# Mock dependencies
ROOT_DIR="$(dirname "$0")/.."
export ROOT_DIR

# Mock sudo keepalive BEFORE sourcing lib/core.sh to prevent password prompts
start_sudo_keepalive() { :; }
stop_sudo_keepalive() { :; }

source "$ROOT_DIR/lib/core.sh"

# Captured commands for verification
COMMANDS_RUN_FILE="/tmp/commands_run_$$"

# Mocks
defaults() { echo "defaults $*" >> "$COMMANDS_RUN_FILE"; }
spctl() { echo "spctl $*" >> "$COMMANDS_RUN_FILE"; }
execute_sudo() { 
    # Extract command from args (shift past description)
    local desc="$1"
    shift
    echo "$@" >> "$COMMANDS_RUN_FILE"
}

# Mock ask_confirmation_with_info to control flow
# Return 0 (Yes/First Option) or 1 (No/Second Option) based on global var
CONFIRM_WITH_INFO_RESPONSE=0 
ask_confirmation_with_info() {
    if [ "$CONFIRM_WITH_INFO_RESPONSE" -eq 0 ]; then
        return 0 # Option 1 (Security)
    else
        return 1 # Option 2 (Privacy)
    fi
}

# Mock ask_confirmation for the secondary "Are you sure?" prompt
CONFIRM_RESPONSE=0
ask_confirmation() {
    if [ "$CONFIRM_RESPONSE" -eq 0 ]; then
        return 0 # Yes
    else
        return 1 # No
    fi
}

warn() { :; }
info() { :; }

source "$ROOT_DIR/lib/macos_hardening.sh"

start_suite "Privacy Over Security Logic"

# Test 1: Gatekeeper - Enforce Security (Default)
# -----------------------------------------------
CONFIRM_WITH_INFO_RESPONSE=0 # Choose Security
> "$COMMANDS_RUN_FILE"
hardening_enable_quarantine # Covers Gatekeeper & Quarantine

if grep -q "spctl --master-enable" "$COMMANDS_RUN_FILE"; then
    pass "Gatekeeper: Enforced Security"
else
    fail "Gatekeeper: Failed to enforce security"
fi

# Test 2: Gatekeeper - Privacy Over Security (Disable)
# ----------------------------------------------------
CONFIRM_WITH_INFO_RESPONSE=1 # Choose Privacy
CONFIRM_RESPONSE=0 # Confirm "Unsafe"
> "$COMMANDS_RUN_FILE"
hardening_enable_quarantine

if grep -q "spctl --master-disable" "$COMMANDS_RUN_FILE"; then
    pass "Gatekeeper: Disabled (Privacy Mode)"
else
    fail "Gatekeeper: Failed to disable in Privacy Mode"
fi

# Test 3: Quarantine - Enforce Security
# -------------------------------------
CONFIRM_WITH_INFO_RESPONSE=0 # Choose Security
> "$COMMANDS_RUN_FILE"
hardening_enable_quarantine

if grep -q "LSQuarantine -bool true" "$COMMANDS_RUN_FILE"; then
    pass "Quarantine: Enforced Security"
else
    fail "Quarantine: Failed to enforce security"
fi

# Test 4: Quarantine - Privacy (Disable)
# --------------------------------------
CONFIRM_WITH_INFO_RESPONSE=1 # Choose Privacy
CONFIRM_RESPONSE=0 # Confirm "Unsafe"
> "$COMMANDS_RUN_FILE"
hardening_enable_quarantine

if grep -q "LSQuarantine -bool false" "$COMMANDS_RUN_FILE"; then
    pass "Quarantine: Disabled (Privacy Mode)"
else
    fail "Quarantine: Failed to disable in Privacy Mode"
fi

# Test 5: Library Validation - Enforce Security
# ---------------------------------------------
CONFIRM_WITH_INFO_RESPONSE=0 # Choose Security
> "$COMMANDS_RUN_FILE"
hardening_enable_library_validation

if grep -q "DisableLibraryValidation -bool false" "$COMMANDS_RUN_FILE"; then
    pass "LibValidation: Enforced Security"
else
    fail "LibValidation: Failed to enforce security"
fi

# Test 6: Library Validation - Privacy (Disable)
# ----------------------------------------------
CONFIRM_WITH_INFO_RESPONSE=1 # Choose Privacy
CONFIRM_RESPONSE=0 # Confirm "Unsafe"
> "$COMMANDS_RUN_FILE"
hardening_enable_library_validation

if grep -q "DisableLibraryValidation -bool true" "$COMMANDS_RUN_FILE"; then
    pass "LibValidation: Disabled (Privacy Mode)"
else
    fail "LibValidation: Failed to disable in Privacy Mode"
fi


# Test 7: Manage Updates - Enable Strategy
# ----------------------------------------
CONFIRM_WITH_INFO_RESPONSE=0 # Choose Security (Enable)
> "$COMMANDS_RUN_FILE"
hardening_manage_updates

if grep -q "defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true" "$COMMANDS_RUN_FILE"; then
    pass "Updates: Enforced Security strategy (Enabled)"
else
    fail "Updates: Failed to enforce security strategy"
fi

# Test 8: Manage Updates - Disable Strategy
# -----------------------------------------
CONFIRM_WITH_INFO_RESPONSE=1 # Choose Privacy
CONFIRM_RESPONSE=0 # Accept Are you sure
> "$COMMANDS_RUN_FILE"
hardening_manage_updates

if grep -q "defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false" "$COMMANDS_RUN_FILE"; then
    pass "Updates: Disabled (Privacy Mode)"
else
    fail "Updates: Failed to disable in Privacy Mode"
fi

# Test 9: Secure Sleep
# --------------------
CONFIRM_WITH_INFO_RESPONSE=0 # Enable
> "$COMMANDS_RUN_FILE"
hardening_secure_sleep

if grep -q "pmset -a hibernatemode 25" "$COMMANDS_RUN_FILE"; then
    pass "Secure Sleep: Enabled"
else
    fail "Secure Sleep: Failed to enable"
fi

# Test 10: Disable IPv6
# ---------------------
networksetup() {
    if [[ "$1" == "-listallnetworkservices" ]]; then
        echo "An asterisk (*) denotes that a network service is disabled."
        echo "Wi-Fi"
    else
        echo "networksetup $*" >> "$COMMANDS_RUN_FILE"
    fi
}
export -f networksetup || true # Make sure it's available

CONFIRM_WITH_INFO_RESPONSE=0 # Enable
> "$COMMANDS_RUN_FILE"
hardening_disable_ipv6

if grep -q "networksetup -setv6off Wi-Fi" "$COMMANDS_RUN_FILE"; then
    pass "Disable IPv6: Executed for interfaces"
else
    fail "Disable IPv6: Failed to execute"
fi

# Test 11: Secure Terminals
# -------------------------
> "$COMMANDS_RUN_FILE"
hardening_secure_terminals

if grep -q "defaults write com.apple.Terminal SecureKeyboardEntry -bool true" "$COMMANDS_RUN_FILE"; then
    pass "Secure Terminals: Keyboard entry secured"
else
    fail "Secure Terminals: Failed to secure keyboard entry"
fi

# Cleanup
rm -f "$COMMANDS_RUN_FILE"

end_suite
