#!/bin/bash

# tests/integration_cli.sh
# Integration tests for validation of CLI entrypoint

source "$(dirname "$0")/test_framework.sh"

start_suite "CLI Integration"

CLI_BIN="$(dirname "$0")/../bin/better-anonymity"

# Test 1: Help command
# --------------------
OUTPUT=$($CLI_BIN --help)
EXIT_CODE=$?

assert_equals "0" "$EXIT_CODE" "CLI should exit with 0 on --help"
assert_contains "$OUTPUT" "Usage: better-anonymity" "Output should contain usage info"

# Test 2: Invalid command
# -----------------------
# Capture stderr
OUTPUT=$($CLI_BIN invalid-command 2>&1)
EXIT_CODE=$?

assert_equals "1" "$EXIT_CODE" "CLI should exit with 1 on invalid command"
assert_contains "$OUTPUT" "Unknown command" "Output should report unknown command"

end_suite
