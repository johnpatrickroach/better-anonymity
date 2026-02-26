#!/bin/bash

# tests/unit_platform.sh
# Unit tests for platform detection

source "$(dirname "$0")/test_framework.sh"

# Mock the uname command
uname() {
    echo "$MOCK_ARCH"
}

# Mock info/warn/error to suppress output during tests, or capture it if needed
info() { :; }
warn() { :; }
error() { :; }

start_suite "Platform Detection"

# Test 1: Intel detection
# ---------------------
MOCK_ARCH="x86_64"
# Source the library (it runs detection on load usually, or if calling function)
# Ideally detection function is separate
source "$(dirname "$0")/../lib/platform.sh"

detect_arch
assert_equals "x86_64" "$PLATFORM_ARCH" "Should detect Intel architecture"
assert_equals "/usr/local" "$BREW_PREFIX" "Should use /usr/local for Intel"

# Test 2: ARM detection
# ---------------------
MOCK_ARCH="arm64"
detect_arch
assert_equals "arm64" "$PLATFORM_ARCH" "Should detect ARM architecture"
assert_equals "/opt/homebrew" "$BREW_PREFIX" "Should use /opt/homebrew for ARM"

start_suite "Model Detection"


# Mock sysctl
sysctl() {
    echo "$MOCK_MODEL"
}

# Mock pmset for battery
pmset() {
    if [[ "$*" == *"-g batt"* ]]; then
        if [ "$MOCK_BATTERY" == "1" ]; then
            echo "InternalBattery"
        else
            echo ""
        fi
    fi
}

# Test 3: MacBook Detection
# -------------------------
MOCK_MODEL="MacBookPro18,3"
MOCK_BATTERY=1
detect_model
assert_equals "Laptop" "$PLATFORM_TYPE" "Should detect MacBook as Laptop"
assert_equals "MacBookPro18,3" "$PLATFORM_MODEL" "Should capture correct model ID"

# Test 4: Mac Mini Detection
# --------------------------
MOCK_MODEL="Macmini9,1"
MOCK_BATTERY=0
detect_model
assert_equals "Desktop" "$PLATFORM_TYPE" "Should detect Mac Mini as Desktop"

# Test 5: has_battery Logic
# -------------------------
MOCK_BATTERY=1
if has_battery; then
    echo -e "${GREEN}[PASS]${NC} has_battery detected battery"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} has_battery failed to detect battery"
    ((FAILED++))
fi

MOCK_BATTERY=0
if ! has_battery; then
    echo -e "${GREEN}[PASS]${NC} has_battery correctly reported no battery"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} has_battery falsely detected battery"
    ((FAILED++))
fi

# Test 6: detect_active_network Fallback
# --------------------------------------
# Mock route, networksetup, ifconfig

# Helper to control route failure
MOCK_ROUTE_FAIL=0
route() {
    if [ "$MOCK_ROUTE_FAIL" -eq 1 ]; then
        return 1
    else
        echo "interface: en0"
    fi
}

# Mock networksetup service order
networksetup() {
    if [ "$1" == "-listnetworkserviceorder" ]; then
        echo "(1) Wi-Fi"
        echo "(Hardware Port: Wi-Fi, Device: en0)"
        echo "(2) Ethernet"
        echo "(Hardware Port: Ethernet, Device: en1)"
    elif [ "$1" == "-listallnetworkservices" ]; then # Called by helper/other functions?
         echo "Wi-Fi"
    elif [ "$1" == "-getdnsservers" ]; then
         echo "8.8.8.8"
    fi
}

# Mock ifconfig
ifconfig() {
    local dev="$1"
    if [ "$dev" == "en0" ] && [ "$MOCK_EN0_ACTIVE" -eq 1 ]; then
        echo "status: active"
    else
        echo "status: inactive"
    fi
}

# Case A: Happy Path (route works)
MOCK_ROUTE_FAIL=0
detect_active_network
if [ "$PLATFORM_ACTIVE_DEVICE" == "en0" ]; then
    echo -e "${GREEN}[PASS]${NC} detect_active_network happy path detected en0"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} detect_active_network happy path failed. Got: $PLATFORM_ACTIVE_DEVICE"
    ((FAILED++))
fi

# Case B: Fallback (route fails, scan services)
MOCK_ROUTE_FAIL=1
MOCK_EN0_ACTIVE=1 # en0 is active in ifconfig
PLATFORM_ACTIVE_DEVICE="" # Reset

detect_active_network
if [ "$PLATFORM_ACTIVE_DEVICE" == "en0" ]; then
    echo -e "${GREEN}[PASS]${NC} detect_active_network fallback detected active en0"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} detect_active_network fallback failed. Got: $PLATFORM_ACTIVE_DEVICE"
    ((FAILED++))
fi

end_suite
