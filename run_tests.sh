#!/bin/bash

# run_tests.sh
# Master test runner

set -e

# Run all test scripts in tests/
FAILED_TESTS=0

echo "Running All Tests..."
echo "========================================"

for test_script in tests/unit_*.sh tests/integration_*.sh; do
    if [ -f "$test_script" ]; then
        echo "Executing $test_script..."
        if ! bash "$test_script"; then
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        echo ""
    fi
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
