#!/bin/bash

# tests/test_telegram.sh
# Unit tests for Telegram installation

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

start_suite "Telegram Installer"

# Test Case 1: Installation
OUTPUT=$(install_telegram)

assert_contains "$OUTPUT" "Installing Telegram..." "Should announce installation"
# Check cask name is lowercase telegram as per standard brew
assert_contains "$OUTPUT" "install_cask_package called with: telegram, Telegram.app" "Should call cask installer with correct args"

end_suite
