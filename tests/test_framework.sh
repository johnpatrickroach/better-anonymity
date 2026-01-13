#!/bin/bash

# tests/test_framework.sh
# Minimal bash testing framework

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


pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}
