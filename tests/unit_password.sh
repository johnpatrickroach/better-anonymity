#!/bin/bash

# tests/unit_password.sh
# Unit tests for password utilities

source "$(dirname "$0")/test_framework.sh"

# Mock core info/error
info() { echo "[INFO] $*"; }
error() { echo "[ERROR] $*"; }
# Define colors to match what might be expected or keep empty.
# If the lib uses them, they must be defined in the scope where lib is sourced if lib doesn't define them itself.
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'


# Load Library
# We need to make sure WORDLIST_PATH is correct relative to the library even when sourced here
# The library uses relative path from BASH_SOURCE, so it should resolve correctly regardless of where we call it from
source "$(dirname "$0")/../lib/password_utils.sh"

start_suite "Password Utilities"

# Test 1: Generation
# ------------------
# We can't predict random words, but we can check word count and structure
PWD_4=$(generate_password 4)
# Check if it has 3 spaces (4 words)
SPACES=$(echo "$PWD_4" | grep -o " " | wc -l | xargs)
assert_equals "3" "$SPACES" "Default generation should have 4 words (3 spaces)"

PWD_6=$(generate_password 6)
SPACES_6=$(echo "$PWD_6" | grep -o " " | wc -l | xargs)
assert_equals "5" "$SPACES_6" "6-word generation should have 6 words (5 spaces)"


# Test 2: Strength Check
# ----------------------
# Weak
OUTPUT=$(check_strength "password")
assert_contains "$OUTPUT" "Rating: ${RED}Weak${NC}" "Should detect weak password"

# Moderate (long but unique chars)
OUTPUT=$(check_strength "CorrectHorseBatteryStaple")
assert_contains "$OUTPUT" "Rating: ${GREEN}Strong${NC}" "Long camelcase should be at least strong"

# Strong Diceware
# 4 words
OUTPUT=$(check_strength "correct horse battery staple")
# echo "DEBUG OUTPUT (4 words): $OUTPUT"
assert_contains "$OUTPUT" "Rating: ${GREEN}Strong${NC}" "4 words should be strong"

OUTPUT=$(check_strength "correct horse battery staple one")
assert_contains "$OUTPUT" "Rating: ${GREEN}Excellent${NC}" "5 words should be excellent"

OUTPUT=$(check_strength "correct horse battery staple one two")
assert_contains "$OUTPUT" "Rating: ${GREEN}Excellent${NC}" "6 words is excellent"



# Test 3: Python Integration & Fallback
# -------------------------------------

# 1. Force Fallback (Simulate no Python)
# Save original function if any (probably not defined but `command -v` checks binary)
# To mock `python3`, we define a function. `command -v` in bash returns true for functions too usually?
# Actually `command -v` might return true for function, but valid usage in script is `if command -v python3`.
# Code: `if command -v python3 >/dev/null 2>&1; then`
# If I define `python3() { return 0; }`, `command -v` finds it.

python3() { return 127; } # Mock failure
PWD_FALLBACK=$(generate_password 4)
SPACES=$(echo "$PWD_FALLBACK" | grep -o " " | wc -l | xargs)
assert_equals "3" "$SPACES" "Fallback generation should work (4 words)"

# 2. Mock Python Success
python3() {
    # script is passed as -c arg, effectively.
    # The actual script calls: python3 -c "..." wordlist num_words
    # We just echo a dummy result
    echo "mocked python password output"
}
# We need `command -v` to succeed. It should.
PWD_PYTHON=$(generate_password 4)
assert_equals "mocked python password output" "$PWD_PYTHON" "Should use python if available"

# Restore? No need, end of suite.

end_suite
