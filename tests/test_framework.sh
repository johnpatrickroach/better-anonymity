#!/bin/bash

# tests/test_framework.sh
# Minimal bash testing framework

# Export TERM to prevent "TERM environment variable not set" errors in CI
export TERM="${TERM:-xterm-256color}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

start_suite() {
    echo "Running Test Suite: $1"
    echo "----------------------------------------"
}

end_suite() {
    echo "----------------------------------------"
    echo "Tests Completed."
    echo -e "Passed: ${GREEN}$PASSED${NC}"
    echo -e "Failed: ${RED}$FAILED${NC}"
    
    if [ $FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" == "$actual" ]; then
        echo -e "${GREEN}[PASS]${NC} $message"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $message"
        echo "       Expected: '$expected'"
        echo "       Actual:   '$actual'"
        ((FAILED++))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}[PASS]${NC} $message"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $message"
        echo "       Could not find '$needle' in output"
        echo "       ACTUAL: $haystack"
        ((FAILED++))
    fi
}

assert_match() {
    local haystack="$1"
    local regex="$2"
    local message="$3"

    if [[ "$haystack" =~ $regex ]]; then
        echo -e "${GREEN}[PASS]${NC} $message"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $message"
        echo "       Regex '$regex' did not match output"
        echo "       ACTUAL: $haystack"
        ((FAILED++))
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}[PASS]${NC} $message"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $message"
        echo "       File not found: $file"
        ((FAILED++))
    fi
}


pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

# ========================================
# Global Test Mocks (No User Interaction)
# ========================================

# Prevent sudo from prompting for passwords
sudo() {
    # Mock sudo to prevent password prompts
    # If called with -v (validate), just succeed
    if [[ "$1" == "-v" ]]; then
        return 0
    fi
    # If called with -n (non-interactive), run the command
    if [[ "$1" == "-n" ]]; then
        shift
        "$@"
        return $?
    fi
    # For other cases, try to run the command without actually using sudo
    # This allows the command to run (if it doesn't need actual sudo), or fail safely
    shift
    "$@"
    return $?
}
export -f sudo
