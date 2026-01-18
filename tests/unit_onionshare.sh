#!/bin/bash

# tests/test_onionshare.sh
# Unit tests for OnionShare installation

source "$(dirname "$0")/test_framework.sh"

# Mock dependencies
TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$(dirname "$TEST_SCRIPT_DIR")"

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
error() { echo "[ERROR] $*"; }
success() { echo "[SUCCESS] $*"; }
require_brew() { :; }

# Mock install_cask_package to verify it's called
install_cask_package() {
    echo "install_cask_package called with: $1, $2"
}

# Source the library to test
source "$ROOT_DIR/lib/installers.sh"

start_suite "OnionShare Installer"

# Test Case 1: Installation
OUTPUT=$(install_onionshare)

assert_contains "$OUTPUT" "Installing OnionShare..." "Should announce installation"
assert_contains "$OUTPUT" "install_cask_package called with: onionshare, OnionShare.app" "Should call cask installer with correct args"


# End
end_suite
