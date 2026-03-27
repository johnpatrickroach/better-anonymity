#!/bin/bash

# tests/unit_wifi_spoof.sh
# Unit tests for Wi-Fi Spoofing Logic (Fallback)

source "$(dirname "$0")/test_framework.sh"

# Setup environment
ROOT_DIR="$(dirname "$0")/.."
export ROOT_DIR

# Mock sudo keepalive BEFORE sourcing lib/core.sh to prevent password prompts
start_sudo_keepalive() { :; }
stop_sudo_keepalive() { :; }

# Pre-mock get_airport_bin to avoid error during source
get_airport_bin() { echo ""; }

# Source library (This will define wifi functions)
source "$(dirname "$0")/../lib/core.sh"
source "$(dirname "$0")/../lib/wifi.sh"

# == MOCKS ==
# Override library functions and commands

info() { echo "INFO: $*"; }
warn() { echo "WARN: $*"; }
error() { echo "ERROR: $*"; }
success() { echo "SUCCESS: $*"; }

# Mock wifi_get_interface (Override library)
wifi_get_interface() {
    echo "en0"
}

# Mock wifi_generate_mac (Override library)
wifi_generate_mac() {
    echo "02:00:00:00:00:01"
}

# Mock global vars
MOCK_IFACE_STATE="up"
MOCK_IFCONFIG_MAC="02:00:00:00:00:00"

# Mock networksetup
networksetup() {
   echo "Mock Networksetup called with: $*"
   if [[ "$1" == "-setairportpower" ]]; then
       if [[ "$3" == "off" ]]; then
           MOCK_IFACE_STATE="down"
       elif [[ "$3" == "on" ]]; then
           MOCK_IFACE_STATE="down" # Keep down to simulate race condition window
       fi
   fi
}

# Mock ifconfig (to simulate MAC change and Up/Down)
ifconfig() {
    # Handle UP/DOWN
    if [[ "$2" == "down" ]]; then
        MOCK_IFACE_STATE="down"
        echo "Mock: Interface DOWN"
        return 0
    elif [[ "$2" == "up" ]]; then
        MOCK_IFACE_STATE="up"
        echo "Mock: Interface UP"
        return 0
    fi

    # Handle Ether Change
    if [[ "$1" == "en0" ]] && [[ "$2" == "ether" ]]; then
        if [ "$MOCK_IFACE_STATE" == "down" ]; then
            MOCK_IFCONFIG_MAC="$3"
            return 0
        else
            echo "Mock: Cannot change MAC while UP (simulated failure)"
            return 1
        fi
    fi
    
    # Just reading?
    if [[ "$1" == "en0" ]]; then
        echo "ether $MOCK_IFCONFIG_MAC"
    fi
}

# Mock sudo
execute_sudo() {
    shift # Remove description
    if [[ "$1" == "-v" ]]; then
        echo "Mock sudo -v"
        return 0
    fi
    "$@"
}

# New mocks for LaunchDaemon tests
mktemp() {
    echo "/tmp/mock_temp_plist"
}

cp() {
    echo "Mock cp called: $*"
}

chown() {
    echo "Mock chown called: $*"
}

chmod() {
    echo "Mock chmod called: $*"
}

rm() {
    echo "Mock rm called: $*"
}

command() {
    if [[ "$1" == "-v" ]]; then
        builtin command -v "$2"
    elif [[ "$2" == "better-anonymity" ]]; then
        echo "/usr/local/bin/better-anonymity"
        return 0
    else
        "$@"
    fi
}

LAUNCHD_PLIST="/Library/LaunchDaemons/com.better-anonymity.macspoof.plist"
MOCK_FILE_EXISTS=false

# Override behavior for `[` check if it's the plist check
[() {
    if [[ "$1" == "-f" ]] && [[ "$2" == "$LAUNCHD_PLIST" ]]; then
        if [ "$MOCK_FILE_EXISTS" = true ]; then
            return 0
        else
            return 1
        fi
    fi
    # Fallback to builtin for other checks
    builtin [ "$@"
}

launchctl() {
    echo "Mock launchctl called: $*"
    if [[ "$1" == "load" ]]; then
        return 0
    elif [[ "$1" == "unload" ]]; then
        return 0
    fi
}

start_suite "Wi-Fi Spoof Fallback"


# Test 1: Missing Airport -> Trigger Power Cycle Fallback
# -----------------------------------------------------
AIRPORT_BIN=""
MOCK_POWER_STATE="on"
MOCK_IFCONFIG_MAC="02:00:00:00:00:00"
TARGET_MAC="02:AA:BB:CC:DD:EE"

OUTPUT=$(wifi_spoof_mac "$TARGET_MAC")

if echo "$OUTPUT" | grep -q "Using Power Cycle Race method."; then
    pass "Missing Airport Bin -> Fallback triggered"
else
    fail "Missing Airport Bin -> Fallback NOT triggered. Output:"
    echo "$OUTPUT"
fi

# Verify verification check passed
if echo "$OUTPUT" | grep -q "Verified: MAC address successfully changed"; then
    pass "MAC Verification -> Passed"
else
    fail "MAC Verification -> Failed. Output:"
    echo "$OUTPUT"
fi

end_suite

start_suite "Wi-Fi Spoof LaunchDaemon Install"

MOCK_FILE_EXISTS=false
OUTPUT=$(wifi_install_spoof_daemon)

if echo "$OUTPUT" | grep -q "Mock cp called: /tmp/mock_temp_plist $LAUNCHD_PLIST"; then
    pass "LaunchDaemon Install -> Created plist"
else
    fail "LaunchDaemon Install -> Failed to create plist. Output:"
    echo "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "Mock launchctl called: load $LAUNCHD_PLIST"; then
    pass "LaunchDaemon Install -> Loaded daemon"
else
    fail "LaunchDaemon Install -> Failed to load daemon. Output:"
    echo "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "MAC Spoofing will now run automatically at boot"; then
    pass "LaunchDaemon Install -> Success message displayed"
else
    fail "LaunchDaemon Install -> Failed success message. Output:"
    echo "$OUTPUT"
fi

end_suite

start_suite "Wi-Fi Spoof LaunchDaemon Uninstall"

MOCK_FILE_EXISTS=true
OUTPUT=$(wifi_uninstall_spoof_daemon)

if echo "$OUTPUT" | grep -q "Mock launchctl called: unload $LAUNCHD_PLIST"; then
    pass "LaunchDaemon Uninstall -> Unloaded daemon when exists"
else
    fail "LaunchDaemon Uninstall -> Failed to unload daemon. Output:"
    echo "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "Mock rm called: -f $LAUNCHD_PLIST"; then
    pass "LaunchDaemon Uninstall -> Removed plist when exists"
else
    fail "LaunchDaemon Uninstall -> Failed to remove plist. Output:"
    echo "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "MAC Spoofing will no longer run at boot"; then
    pass "LaunchDaemon Uninstall -> Success message displayed"
else
    fail "LaunchDaemon Uninstall -> Failed success message. Output:"
    echo "$OUTPUT"
fi

MOCK_FILE_EXISTS=false
OUTPUT=$(wifi_uninstall_spoof_daemon)

if echo "$OUTPUT" | grep -q "LaunchDaemon is not currently installed"; then
    pass "LaunchDaemon Uninstall -> Ignored when not installed"
else
    fail "LaunchDaemon Uninstall -> Handled incorrectly when not installed. Output:"
    echo "$OUTPUT"
fi

end_suite

start_suite "Wi-Fi Spoof LaunchDaemon Check"

MOCK_FILE_EXISTS=true
wifi_check_spoof_daemon
if [ $? -eq 0 ]; then
    pass "LaunchDaemon Check -> Detected when installed"
else
    fail "LaunchDaemon Check -> Failed to detect when installed"
fi

MOCK_FILE_EXISTS=false
wifi_check_spoof_daemon
if [ $? -eq 1 ]; then
    pass "LaunchDaemon Check -> Detected when not installed"
else
    fail "LaunchDaemon Check -> Failed to detect when not installed"
fi

end_suite
