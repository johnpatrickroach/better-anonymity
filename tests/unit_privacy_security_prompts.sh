#!/bin/bash
# tests/unit_privacy_security_prompts.sh
# Verify "Privacy Over Security" prompt logic

source "$(dirname "$0")/test_framework.sh"

# Mock dependencies
ROOT_DIR="$(dirname "$0")/.."
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


# Cleanup
rm -f "$COMMANDS_RUN_FILE"

end_suite
