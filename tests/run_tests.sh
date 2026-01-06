#!/bin/bash

# tests/run_tests.sh
# Master test runner

set -e

# Switch to the project root (one level up from tests/)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(dirname "$DIR")"
cd "$PROJECT_ROOT"

# Run all test scripts in this directory
FAILED_TESTS=0

echo "Running All Tests..."
echo "========================================"

run_suite() {
    local test_script="$1"
    if [ -f "$test_script" ]; then
        echo "Executing $test_script..."
        # We run the script from project root
        if ! bash "$test_script"; then
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        echo ""
    else
        echo "WARNING: Test script not found: $test_script"
    fi
}


# run_suite "tests/unit_installer.sh" # Merged into others or standalone? Let's assume standard set.
# Checking file list... installer tests might be inside logic or separate. 
# Listing said: unit_logic.sh, unit_settings.sh. unit_core.sh exists. 
# I will use globs if I am unsure, but explict is better for ordering.
# Let's check listing first? No, I'll use the glob pattern inside the script to be safe against missing files, or just list the known ones.
# Providing a safe glob-based runner is better if files change.

# Reverting to safer glob pattern
for test_script in tests/unit_*.sh tests/integration_*.sh; do
    run_suite "$test_script"
done

if [ $FAILED_TESTS -gt 0 ]; then
    echo "========================================"
    echo "FAILURE: $FAILED_TESTS test suites failed."
    exit 1
else
    echo "========================================"
    echo "SUCCESS: All test suites passed."
    exit 0
fi
