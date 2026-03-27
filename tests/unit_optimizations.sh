#!/bin/bash

# tests/unit_optimizations.sh
# Verify lazy loading and startup time

source "$(dirname "$0")/test_framework.sh"

start_suite "Optimizations & Lazy Loading"

BIN_PATH="$(cd "$(dirname "$0")/../bin" && pwd)/better-anonymity"

# 1. Verify 'help' does NOT load installers.sh
# We use bash -x (debug) to trace file loading.
# If installers.sh is sourced, it will show up in trace as `. .../lib/installers.sh` or similar.

# This might be noisy, but we can grep.
OUTPUT=$(bash -x "$BIN_PATH" help 2>&1)

if echo "$OUTPUT" | grep -q "lib/installers.sh"; then
    fail "Lazy Loading Failed: installers.sh was sourced during 'help'."
    # echo "$OUTPUT" | grep "installers.sh"
else
    pass "Lazy Loading Verified: installers.sh NOT sourced during 'help'."
fi

# Setup Mock Sudo to prevent password prompt
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT
echo '#!/bin/sh' > "$MOCK_DIR/sudo"
echo 'echo "MOCK SUDO: $*"' >> "$MOCK_DIR/sudo"
chmod +x "$MOCK_DIR/sudo"
export PATH="$MOCK_DIR:$PATH"

# 2. Verify 'install' DOES load installers.sh
OUTPUT=$(bash -x "$BIN_PATH" install gpg 2>&1)
# Note: install gpg tries to install. It might fail if not root or packages missing, but loading should happen.
# We expect to see installers.sh sourced.

if echo "$OUTPUT" | grep -q "lib/installers.sh"; then
    pass "Module Loading Verified: installers.sh sourced during 'install gpg'."
else
    fail "Module Loading Failed: installers.sh NOT sourced during 'install gpg'."
fi

# 3. Verify 'harden' loads macos_hardening.sh
# Pipe 'n' to avoid actual changes or hanging on prompts
# OUTPUT=$(echo -e "n\nn\nn\nn\nn" | bash -x "$BIN_PATH" harden 2>&1)
# if echo "$OUTPUT" | grep -q "lib/macos_hardening.sh"; then
#     pass "Module Loading Verified: macos_hardening.sh sourced during 'harden'."
# else
#     fail "Module Loading Failed: macos_hardening.sh NOT sourced during 'harden'."
# fi

end_suite
rm -rf "$MOCK_DIR"
