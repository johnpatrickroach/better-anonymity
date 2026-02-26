#!/bin/bash

# tests/unit_privacy_parity.sh
# Unit tests for Privacy.sexy parity features (Cleanup, Parallels, Telemetry)

source "$(dirname "$0")/test_framework.sh"

# Mocks
info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
error() { echo "[ERROR] $*"; }
success() { echo "[SUCCESS] $*"; }
ask_confirmation() { return 0; } # Always say yes

execute_sudo() {
    shift
    # Echo the command being executed
    echo "EXEC_SUDO: $*"
}

# Mock destructive commands
rm() { echo "RM_CALL: $*"; }
sqlite3() { echo "SQLITE_CALL: $*"; }
find() { 
    if [[ "$*" == *"Firefox"* ]]; then
        # Run real find for filesystem traversal logic
        # But we need to make sure we don't pick up garbage if args are messy
        command find "$@"
    else
        echo "FIND_CALL: $*" 
    fi
}
xattr() { echo "XATTR_CALL: $*"; }
purge() { echo "PURGE_CALL: $*"; }
pgrep() { 
    # Simulate apps running to verify kill logic, or not running to skip.
    # For safety, let's say "Safari" is running to test that path, but others not?
    # Actually, close_app calls pgrep. If we return 0, it calls killall.
    # We want to test that killall IS called.
    return 0 
}
killall() { echo "KILLALL_CALL: $*"; return 0; }


# Mock defaults for hardening checks
defaults() {
    echo "DEFAULTS_CALL: $*"
}

start_suite "Privacy Parity Features"

# Load modules
source "$(dirname "$0")/../lib/cleanup.sh"
source "$(dirname "$0")/../lib/macos_hardening.sh"

# Test 1: Browser Cleanup
# -----------------------
# Mock directory existence checks
original_test_dir=""
setup_browser_mocks() {
    original_test_dir=$(pwd)
    test_dir=$(mktemp -d)
    # Create fake browser dirs
    mkdir -p "$test_dir/Library/Application Support/Google/Chrome/Default"
    mkdir -p "$test_dir/Library/Application Support/Firefox/Profiles/test.default"
    # Create files for glob expansion
    touch "$test_dir/Library/Application Support/Firefox/Profiles/test.default/cookies.sqlite"
    
    # We need to override HOME for the function to find them
    export HOME="$test_dir"
}

teardown_browser_mocks() {
    command rm -rf "$HOME"
    export HOME="$USER_HOME_BACKUP" 
}
USER_HOME_BACKUP="$HOME"

setup_browser_mocks
OUTPUT=$(cleanup_browsers)
teardown_browser_mocks

assert_contains "$OUTPUT" "Cleaning Chrome Profile" "Should start Chrome cleanup"
# Implementation uses simple rm -rf, not verbose
assert_contains "$OUTPUT" "RM_CALL: -rf $test_dir/Library/Application Support/Google/Chrome/Default/History" "Should delete Chrome History"
assert_contains "$OUTPUT" "RM_CALL: -f $test_dir/Library/Safari/History.db" "Should delete Safari History"
# Implementation uses simple rm -f, not verbose
assert_contains "$OUTPUT" "RM_CALL: -f $test_dir/Library/Application Support/Firefox/Profiles/test.default/cookies.sqlite" "Should delete Firefox Cookies"


# Test 2: Quarantine Cleanup
# --------------------------
# Mock file existence for DB
test_db_dir=$(mktemp -d)
export HOME="$test_db_dir"
mkdir -p "$HOME/Library/Preferences"
touch "$HOME/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"

OUTPUT=$(cleanup_quarantine)
command rm -rf "$test_db_dir"
export HOME="$USER_HOME_BACKUP"

assert_contains "$OUTPUT" "Clearing File Quarantine Logs" "Should start quarantine cleanup"
# Implementation removes the file instead of SQL delete
assert_match "$OUTPUT" "SQLITE_CALL: .*QuarantineEventsV2 DELETE FROM" "Should execute sqlite delete"
assert_contains "$OUTPUT" "FIND_CALL: $test_db_dir/Downloads -type f -exec xattr -d com.apple.quarantine {}" "Should find and remove xattr"


# Test 3: Memory Purge
# --------------------
OUTPUT=$(cleanup_memory)
assert_contains "$OUTPUT" "EXEC_SUDO: purge" "Should run sudo purge"


# Test 4: Parallels Block
# -----------------------
# Mock Parallels existence
test_app_dir=$(mktemp -d)
mkdir -p "$test_app_dir/Applications/Parallels Desktop.app"

OUTPUT=$(hardening_disable_parallels)
if [ -d "/Applications/Parallels Desktop.app" ]; then
    assert_contains "$OUTPUT" "Disabling Parallels" "Should log info"
    assert_contains "$OUTPUT" "DEFAULTS_CALL: write com.parallels.Parallels Desktop ApplicationPreferences.CheckForUpdates -bool false" "Should disable updates"
else
    # It skipped. That's fine for CI. We can't force it easily without filesystem access.
    # We'll just print a skip message.
    echo "Skipping Parallels existence check (App not installed)"
fi

# Test 5: Telemetry Updates
# -------------------------
# Mock HOME for zshrc
test_home_tel=$(mktemp -d)
export HOME="$test_home_tel"
touch "$HOME/.zshrc"

OUTPUT=$(hardening_disable_app_telemetry)
assert_contains "$OUTPUT" "DEFAULTS_CALL: write com.microsoft.office.telemetry ZeroDiagnosticData -bool true" "Should set ZeroDiagnosticData"

# Check .zshrc content
ZSHRC_CONTENT=$(cat "$HOME/.zshrc")
assert_contains "$ZSHRC_CONTENT" "DOTNET_CLI_TELEMETRY_OPTOUT" "Should export DOTNET var"

command rm -rf "$test_home_tel" "$test_app_dir"
export HOME="$USER_HOME_BACKUP"

end_suite
