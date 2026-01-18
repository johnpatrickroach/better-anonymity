#!/bin/bash
# Verify active network detection logic
# This test attempts to verify the happy path basically, as mocking route failure is hard.

LIB_DIR="lib"
export LIB_DIR
source "lib/core.sh"
source "lib/platform.sh"

echo "Current Active Network Detection:"
detect_active_network
echo "Device: $PLATFORM_ACTIVE_DEVICE"
echo "Service: $PLATFORM_ACTIVE_SERVICE"

if [ -z "$PLATFORM_ACTIVE_DEVICE" ]; then
    echo "WARNING: No active device found (possibly offline)."
else
    echo "SUCCESS: Found active device."
fi

# We can try to force the fallback path by temporarily defining a mock route function?
# This is risky in shell script sourced from same file if not careful, 
# but since detect_active_network calls `route`, if we define `route` AFTER sourcing, it overrides.

echo "--- Testing Fallback Logic (Mocking 'route' failure) ---"
route() {
    return 1 # Fail always
}

# Reset variables
PLATFORM_ACTIVE_DEVICE=""
PLATFORM_ACTIVE_SERVICE=""

detect_active_network
echo "Fallback Device: $PLATFORM_ACTIVE_DEVICE"

if [ -n "$PLATFORM_ACTIVE_DEVICE" ]; then
    echo "SUCCESS: Fallback logic found a device ($PLATFORM_ACTIVE_DEVICE)."
else
    echo "WARNING: Fallback logic returned no device (Expected if no interfaces are 'active' in ifconfig)."
fi
