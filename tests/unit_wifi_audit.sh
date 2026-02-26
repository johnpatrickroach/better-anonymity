#!/bin/bash

# tests/unit_wifi_audit.sh
# Unit tests for Wi-Fi Audit Logic (Fallback)

source "$(dirname "$0")/test_framework.sh"

# Helper functions for reporting
pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASSED++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAILED++)); }

# Mocks
info() { echo "INFO: $*"; }
warn() { echo "WARN: $*"; }
error() { echo "ERROR: $*"; }
success() { echo "SUCCESS: $*"; }

# Mock wifi_get_interface
wifi_get_interface() {
    echo "en0"
}

# Mock networksetup
networksetup() {
    if [[ "$1" == "-getairportpower" ]]; then
        echo "Wi-Fi Power (en0): On"
    elif [[ "$1" == "-getairportnetwork" ]]; then
        if [ "$MOCK_NET_STATUS" == "connected" ]; then
            echo "Current Wi-Fi Network: MockFallbackWiFi"
        else
            echo "You are not associated with an AirPort network."
        fi
    fi
}

# Mock system_profiler
system_profiler() {
    if [ "$MOCK_NET_STATUS" == "connected" ]; then
        echo "Current Network Information:"
        echo "MockFallbackWiFi:"
    else
        echo ""
    fi
}

start_suite "Wi-Fi Audit Fallback"

# Source library
source "$(dirname "$0")/../lib/core.sh"
source "$(dirname "$0")/../lib/wifi.sh"

# Test 1: Fallback Logic (Airport Missing, Connected)
# ---------------------------------------------------
# Simulate missing airport binary by unsetting/clearing AIRPORT_BIN
AIRPORT_BIN=""
MOCK_NET_STATUS="connected"

OUTPUT=$(wifi_audit)

if echo "$OUTPUT" | grep -q "airport utility not found"; then
    if echo "$OUTPUT" | grep -q "Wi-Fi Status: CONNECTED (SSID: MockFallbackWiFi)"; then
         pass "Missing Airport Bin -> Fallback success (SSID found)"
    else
         fail "Missing Airport Bin -> Fallback failed to find SSID. Output:"
         echo "$OUTPUT"
    fi
else
    fail "Missing Airport Bin -> Did not trigger fallback warning."
    echo "$OUTPUT"
fi

# Test 2: Missing Airport -> Disconnected
# -----------------------------------------------------
MOCK_NET_STATUS="disconnected"

OUTPUT=$(wifi_audit 2>&1)

if echo "$OUTPUT" | grep -q "airport utility not found"; then
    if echo "$OUTPUT" | grep -q "Wi-Fi Status: DISCONNECTED"; then
        pass "Missing Airport Bin + Disconnected -> Handled correctly"
    else
        fail "Missing Airport Bin + Disconnected failed (wrong status). Output:"
        echo "$OUTPUT"
    fi
else
    fail "Missing Airport Bin + Disconnected failed (no fallback). Output:"
    echo "$OUTPUT"
fi

end_suite
