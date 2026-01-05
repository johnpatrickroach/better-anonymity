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

# Test 3: MacBook Detection
# -------------------------
MOCK_MODEL="MacBookPro18,3"
detect_model
assert_equals "Laptop" "$PLATFORM_TYPE" "Should detect MacBook as Laptop"
assert_equals "MacBookPro18,3" "$PLATFORM_MODEL" "Should capture correct model ID"

# Test 4: Mac Mini Detection
# --------------------------
MOCK_MODEL="Macmini9,1"
detect_model
assert_equals "Desktop" "$PLATFORM_TYPE" "Should detect Mac Mini as Desktop"

end_suite
