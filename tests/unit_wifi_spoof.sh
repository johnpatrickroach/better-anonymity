#!/bin/bash

# tests/unit_wifi_spoof.sh
# Unit tests for Wi-Fi Spoofing Logic (Fallback)

source "$(dirname "$0")/test_framework.sh"

# Pre-mock get_airport_bin to avoid error during source
get_airport_bin() { echo ""; }

# Source library (This will define wifi functions)
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

# Mock networksetup (No longer used for spoofing, but maybe for get interface logic if not mocked)
networksetup() {
   echo "Mock Networksetup called with: $*"
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
    "$@"
}

start_suite "Wi-Fi Spoof Fallback"


# Test 1: Missing Airport -> Trigger Power Cycle Fallback
# -----------------------------------------------------
AIRPORT_BIN=""
MOCK_POWER_STATE="on"
MOCK_IFCONFIG_MAC="02:00:00:00:00:00"
TARGET_MAC="02:AA:BB:CC:DD:EE"

OUTPUT=$(wifi_spoof_mac "$TARGET_MAC")

if echo "$OUTPUT" | grep -q "Using ifconfig down/up method"; then
    pass "Missing Airport Bin -> Fallback triggered"
else
    fail "Missing Airport Bin -> Fallback NOT triggered. Output:"
    echo "$OUTPUT"
fi

# Verify verification check passed
if echo "$OUTPUT" | grep -q "Verified active MAC is now 02:AA:BB:CC:DD:EE"; then
    pass "MAC Verification -> Passed"
else
    fail "MAC Verification -> Failed. Output:"
    echo "$OUTPUT"
fi

end_suite
