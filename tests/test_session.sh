#!/bin/bash

# tests/test_session.sh
# Unit tests for Session installation

source "$(dirname "$0")/test_framework.sh"

# Mock dependencies
TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$(dirname "$TEST_SCRIPT_DIR")"

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
error() { echo "[ERROR] $*"; }
success() { echo "[SUCCESS] $*"; }
require_brew() { :; }

# Mock install_cask_package
install_cask_package() {
    echo "install_cask_package called with: $1, $2"
}

# Source the library
source "$ROOT_DIR/lib/installers.sh"

start_suite "Session Installer"

# Test Case 1: Installation
OUTPUT=$(install_session)

assert_contains "$OUTPUT" "Installing Session" "Should announce installation"
# Check cask name is 'session'
assert_contains "$OUTPUT" "install_cask_package called with: session, Session.app" "Should call cask installer with correct args"

end_suite
