#!/bin/bash

# tests/unit_logic.sh
# Unit tests for logic flows (Network, Installers)

source "$(dirname "$0")/test_framework.sh"

# Mock core info/error
info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
error() { echo "[ERROR] $*"; }
success() { echo "[SUCCESS] $*"; }
# Mock execute_sudo to log and run if function exists
execute_sudo() { 
    shift # Remove description
    # Check if the command is a function we defined
    if declare -f "$1" > /dev/null; then
        "$@"
    else
        # For paths or unmocked commands, just echo
        echo "EXEC: $*"
    fi
}
die() { echo "DIED: $1"; }
# Mock require_brew
require_brew() { :; }

# Mock load_module to avoid errors in tests
load_module() { :; }
export -f load_module

# Mock Checks (Default to not installed so logic proceeds to install)
is_brew_installed() { return 1; }
is_cask_installed() { return 1; }
is_app_installed() { return 1; }
check_config_and_backup() {
    echo "CHECK_CALL: $*"
    return 0 
} 

install_brew_package() {
    echo "brew called with: install $1"
}

install_cask_package() {
    echo "brew called with: cask install $1"
} 



# Mock System Commands
networksetup() {
    echo "networksetup called with: $*"
}
dscacheutil() { :; }
killall() { :; }
brew() {
    echo "brew called with: $*"
}
mkdir() { command mkdir "$@"; }
# grep mock removed to allow usage of real grep (needed for logic checks)


# Load Libraries
source "$(dirname "$0")/../lib/network.sh"
source "$(dirname "$0")/../lib/installers.sh"

start_suite "Logic Flows"

# Test 1: Network Set DNS
# -----------------------
# Mock networksetup -listallnetworkservices
# The function calls it. We need to mock it returning services.
networksetup() {
    if [ "$1" == "-listallnetworkservices" ]; then
        echo "Wi-Fi"
        # echo "Ethernet" # keep it simple
    else
        # Verify the setting call
        echo "SET_DNS: $*"
    fi
}

# The loop in network.sh iterates over services.
# The expected output string needs to match exactly what echo "SET_DNS: ..." produces.
# Arguments passed: -setdnsservers "Wi-Fi" 9.9.9.9 149.112.112.112
OUTPUT=$(network_set_dns "quad9" | tr -d '\n')
# echo "DEBUG OUTPUT: $OUTPUT"
assert_contains "$OUTPUT" "SET_DNS: -setdnsserversWi-Fi9.9.9.9 149.112.112.112" "Should set Quad9 for Wi-Fi"

# Test 2: Installer Logic
# -----------------------
# Setup environment mocks
BREW_PREFIX="/tmp/mock_brew"
mkdir -p "$BREW_PREFIX/etc/privoxy"
# Create dummy source config/actions so cp works
mkdir -p config/privoxy
touch config/privoxy/config config/privoxy/user.action

PLATFORM_ARCH="arm64"

OUTPUT=$(install_privoxy)
assert_contains "$OUTPUT" "brew called with: install privoxy" "Should call brew install privoxy"
assert_contains "$OUTPUT" "brew called with: services restart privoxy" "Should restart privoxy"
assert_contains "$OUTPUT" "Copying user.action" "Should copy user.action"
assert_contains "$OUTPUT" "SET_DNS: -setwebproxy Wi-Fi 127.0.0.1 8118" "Should set HTTP proxy"
assert_contains "$OUTPUT" "SET_DNS: -setsecurewebproxy Wi-Fi 127.0.0.1 8118" "Should set HTTPS proxy"

# Test 3: Hostname Anonymization
# ------------------------------
# Mock scutil
scutil() {
    echo "SCUTIL: $*"
}
# Mock platform
PLATFORM_TYPE="Laptop"

source "$(dirname "$0")/../lib/macos_hardening.sh"
# Just test the single function
OUTPUT=$(hardening_anonymize_hostname)
assert_contains "$OUTPUT" "SCUTIL: --set ComputerName MacBook" "Should set ComputerName to MacBook for Laptops"

PLATFORM_TYPE="Desktop"
OUTPUT=$(hardening_anonymize_hostname)
assert_contains "$OUTPUT" "SCUTIL: --set ComputerName Mac" "Should set ComputerName to Mac for Desktops"


# Test 4: FileVault
# -----------------
# Mock fdesetup
fdesetup() {
    if [ "$1" == "status" ]; then
        echo "$MOCK_FDESETUP_STATUS"
    elif [ "$1" == "enable" ]; then
        echo "FDESETUP: ENABLED"
    fi
}
# Mock ask_confirmation
ask_confirmation() {
    if [ "$MOCK_USER_CONFIRM" == "yes" ]; then
        return 0
    else
        return 1
    fi
}

# Case A: Already On
MOCK_FDESETUP_STATUS="FileVault is On."
OUTPUT=$(hardening_ensure_filevault)
assert_contains "$OUTPUT" "FileVault is already enabled" "Should detect enabled FileVault"

# Case B: Off, User Declines
MOCK_FDESETUP_STATUS="FileVault is Off."
MOCK_USER_CONFIRM="no"
OUTPUT=$(hardening_ensure_filevault)
assert_contains "$OUTPUT" "Skipping FileVault" "Should skip if user declines"

# Case C: Off, User Accepts
MOCK_FDESETUP_STATUS="FileVault is Off."
MOCK_USER_CONFIRM="yes"
OUTPUT=$(hardening_ensure_filevault)
# Note: execute_sudo in this file just executes "$@"
assert_contains "$OUTPUT" "FDESETUP: ENABLED" "Should enable if user accepts"


source "$(dirname "$0")/../lib/platform.sh"

# Mock sw_vers and defaults
sw_vers() {
   if [ "$1" == "-productVersion" ]; then
       echo "$MOCK_OS_VER"
   fi
}

defaults() {
    if [ "$1" == "read" ] && [ "$2" == ".GlobalPreferences.plist" ] && [ "$3" == "LDMStatus" ]; then
        if [ "$MOCK_LDM_STATUS" == "missing" ]; then
            return 1
        else
            echo "$MOCK_LDM_STATUS"
            return 0
        fi
    else
         # Echo simple success for other defaults calls if any
         :
    fi
}
# Also mock open for the execute_sudo call
open() {
    echo "OPEN: $*"
}

# Test 5: Lockdown Mode
# ---------------------
# Case A: Old macOS (Skip)
MOCK_OS_VER="12.5.1"
detect_os_version > /dev/null # Update global vars
OUTPUT=$(hardening_ensure_lockdown)
assert_contains "$OUTPUT" "Lockdown Mode is not available" "Should skip on macOS 12"

# Case B: Ventura, Enabled
MOCK_OS_VER="13.0"
detect_os_version > /dev/null
MOCK_LDM_STATUS="1"
OUTPUT=$(hardening_ensure_lockdown)
assert_contains "$OUTPUT" "Lockdown Mode is already enabled" "Should detect enabled status"

# Case C: Ventura, Disabled, User Accepts
MOCK_OS_VER="13.5"
detect_os_version > /dev/null
MOCK_LDM_STATUS="0"
MOCK_USER_CONFIRM="yes"
OUTPUT=$(hardening_ensure_lockdown)
assert_contains "$OUTPUT" "Lockdown Mode is NOT enabled" "Should detect disabled status"
assert_contains "$OUTPUT" "Opening System Settings" "Should try to open settings"
assert_contains "$OUTPUT" "OPEN: x-apple.systempreferences:com.apple.LockdownMode" "Should open correct URL"

# Case D: Ventura, Disabled, User Declines
MOCK_OS_VER="14.2"
detect_os_version > /dev/null
MOCK_LDM_STATUS="missing" # Simulate missing key
MOCK_USER_CONFIRM="no"
OUTPUT=$(hardening_ensure_lockdown)
assert_contains "$OUTPUT" "Skipping Lockdown Mode" "Should skip if user declines"



# Test 6: Firewall
# ----------------
OUTPUT=$(hardening_enable_firewall)
assert_contains "$OUTPUT" "EXEC: /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on" "Should enable firewall"
assert_contains "$OUTPUT" "EXEC: /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on" "Should enable stealth mode"
assert_contains "$OUTPUT" "EXEC: /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off" "Should disable allow signed"
assert_contains "$OUTPUT" "EXEC: pkill -HUP socketfilterfw" "Should reload firewall"


# Test 7: Homebrew Hardening
# --------------------------
# Mock command -v brew to return success
MOCK_BREW_EXISTS=true
command() {
    if [ "$1" == "-v" ] && [ "$2" == "brew" ]; then
        if [ "$MOCK_BREW_EXISTS" == "true" ]; then return 0; else return 1; fi
    else
        # For other commands (mkdir etc) just return 0
        return 0
    fi
}
SUDO_USER="" # Mock no sudo user initially

# Mock HOME for zshrc test
TEST_7_HOME="$(mktemp -d /tmp/test_home_brew.XXXXXX)"
OLD_HOME="$HOME"
export HOME="$TEST_7_HOME"
touch "$HOME/.zshrc"

OUTPUT=$(hardening_secure_homebrew)

# Restore HOME
export HOME="$OLD_HOME"

echo "DEBUG OUTPUT (Brew): $OUTPUT"
assert_contains "$OUTPUT" "Disabling Homebrew Analytics" "Should try to disable analytics"
assert_contains "$OUTPUT" "brew called with: analytics off" "Should run brew analytics off"
assert_contains "$OUTPUT" "Set HOMEBREW_NO_INSECURE_REDIRECT=1" "Should set env var"
assert_contains "$OUTPUT" "SECURITY WARNING" "Should warn about TCC"
assert_contains "$OUTPUT" "Added HOMEBREW_NO_INSECURE_REDIRECT to .zshrc" "Should update zshrc (redirect)"
assert_contains "$OUTPUT" "Added HOMEBREW_NO_ANALYTICS to .zshrc" "Should update zshrc (analytics)"

# Verify file content
if grep -q "HOMEBREW_NO_INSECURE_REDIRECT=1" "$TEST_7_HOME/.zshrc"; then
    assert_equals "true" "true" "zshrc should contain insecure redirect"
else
    assert_equals "true" "false" "zshrc should contain insecure redirect"
fi

if grep -q "HOMEBREW_NO_ANALYTICS=1" "$TEST_7_HOME/.zshrc"; then
    assert_equals "true" "true" "zshrc should contain analytics"
else
    assert_equals "true" "false" "zshrc should contain analytics"
fi

# Cleanup
rm -rf "$TEST_7_HOME"

# Mock brew not found
MOCK_BREW_EXISTS=false
OUTPUT=$(hardening_secure_homebrew)
assert_contains "$OUTPUT" "Homebrew not found" "Should skip if brew not found"

# Cleanup mock
unset -f command



# Test 8: Hosts Hardening
# -----------------------
# Mock curl and tee ?
# We rely on execute_sudo logging for verification
OUTPUT=$(network_update_hosts)
# Note: Backup assertions removed because they depend on /etc/hosts-base NOT existing,
# which might not be true on the test machine.
# assert_contains "$OUTPUT" "Creating /etc/hosts-base backup" "Should backup hosts"
# assert_contains "$OUTPUT" "EXEC: cp /etc/hosts /etc/hosts-base" "Should run cp"

assert_contains "$OUTPUT" "EXEC: sh -c cat /etc/hosts-base > /etc/hosts" "Should restore base"
assert_contains "$OUTPUT" "Downloading blocklist to config/hosts" "Should download to file"
# Since curl is NOT sudo now, it runs directly. We need to check if 'curl' command mock was called if we mocked it,
# OR we rely on the INFO message "Blocklist downloaded successfully".
# Assuming curl exists on the system, it will try to download.
# If we are offline or it fails, we might get "Download failed".
# We should probably mock curl to return 0 and touch the file.
assert_contains "$OUTPUT" "EXEC: sh -c cat 'config/hosts' | tee -a /etc/hosts > /dev/null" "Should apply local blocklist"
assert_contains "$OUTPUT" "Hosts file updated successfully" "Should report success"

# Case: Base already exists
# We can't easily mock file existence check [ -f ... ] inside the function without mocking the shell test operator or the function itself.
# However, if we assume the first run creates it, the second run might not.
# Since we are not actually running real cp, the file check [ ! -f /etc/hosts-base ] will always be true or false depending on the REAL system or if we mock it.
# IMPORTANT: In a unit test environment on a real FS, /etc/hosts-base likely doesn't exist.
# But we don't want to actually check /etc/hosts-base on the user's machine!
# The script runs `[ ! -f "/etc/hosts-base" ]`.
# We should try to mock `[`. But `[` is a builtin.
# We will just accept that the test output depends on the real filesystem state for that check?
# No, checking /etc/hosts-base is harmless.
# If we want to test the "already exists" path, we'd need to mock it.
# For now, verification that the backup command IS called (assuming missing) is sufficient coverage for the "happy path".


# Test 9: DNSCrypt Installation
# -----------------------------
# Mock file existence for config (we are in tests dir, so we need to be careful with relative paths)
# The script uses $(pwd)/config/...
# In unit testing, we might not have that file.
# We'll create a dummy config/dnscrypt-proxy/dnscrypt-proxy.toml

# Test 9: DNSCrypt Installation
# -----------------------------
# Verify Safe Path Logic in Test
# We must ensure we don't overwrite real system files or delete project source files.

# Create a temporary simulation environment
TEST_ROOT=$(mktemp -d)
# Trap cleanup just in case
trap "rm -rf $TEST_ROOT" EXIT

# Mock BREW_PREFIX to point to our test root
# checks.sh or platform.sh might have already exported it.
# We override it for this test scope.
BREW_PREFIX="$TEST_ROOT/opt/homebrew"
export BREW_PREFIX
# Create destination dir
mkdir -p "$BREW_PREFIX/etc"

# Create a mock source directory structure mimicking the project
TEST_PROJECT_DIR="$TEST_ROOT/project"
mkdir -p "$TEST_PROJECT_DIR/config/dnscrypt-proxy"
touch "$TEST_PROJECT_DIR/config/dnscrypt-proxy/dnscrypt-proxy.toml"

# Switch to test project dir to make $(pwd) return the test path
# This mocks the user running the script from their project root
cd "$TEST_PROJECT_DIR" || exit 1

# Mock brew for this test
brew() {
    echo "EXEC: brew $*"
}

OUTPUT=$(install_dnscrypt)

# Verify Output
assert_contains "$OUTPUT" "Installing DNSCrypt-Proxy" "Should install"
assert_contains "$OUTPUT" "EXEC: brew install dnscrypt-proxy" "Should brew install"
assert_contains "$OUTPUT" "Applying configuration" "Should apply config"
assert_contains "$OUTPUT" "Restarting DNSCrypt-Proxy" "Should restart service"
assert_contains "$OUTPUT" "EXEC: brew services restart dnscrypt-proxy" "Should run restart command"

# Verify File Copy
if [ -f "$BREW_PREFIX/etc/dnscrypt-proxy.toml" ]; then
    assert_equals "true" "true" "Config file copied to correct Brew location"
else
    assert_equals "true" "false" "Config file copied to correct Brew location"
fi

# Cleanup
# Return to original dir before deleting test root
cd - > /dev/null || exit 1
rm -rf "$TEST_ROOT"
# Restore trap
trap - EXIT


# Test 10: PingBar Installation
# -----------------------------
# Mock swift, git, make, defaults
swift() { return 0; }
git() { 
    echo "EXEC: git $*"
    # Simulate clone by creating the directory
    if [ "$1" == "clone" ]; then
        # The last argument is the directory
        # Iterate to get last arg
        for last; do true; done
        mkdir -p "$last"
    fi
    return 0
}
make() { echo "EXEC: make $*"; return 0; }
defaults() { echo "EXEC: defaults $*"; return 0; }

OUTPUT=$(install_pingbar)

assert_contains "$OUTPUT" "Checking requirements for PingBar" "Should check requirements"
assert_contains "$OUTPUT" "Cloning PingBar" "Should clone"
assert_contains "$OUTPUT" "EXEC: git clone https://github.com/jedisct1/pingbar.git" "Should run git clone"
assert_contains "$OUTPUT" "Building PingBar" "Should build"
assert_contains "$OUTPUT" "EXEC: make bundle" "Should make bundle"
assert_contains "$OUTPUT" "Installing PingBar" "Should install"
assert_contains "$OUTPUT" "EXEC: make install" "Should make install"
assert_contains "$OUTPUT" "Configuring PingBar" "Should configure"
assert_contains "$OUTPUT" "EXEC: defaults write fr.jedisct1.PingBar RestoreDNS -bool true" "Should set RestoreDNS"
assert_contains "$OUTPUT" "EXEC: defaults write fr.jedisct1.PingBar LaunchAtLogin -bool true" "Should set LaunchAtLogin"

# Cleanup mocks
unset -f swift git make defaults


# Test 11: Unbound Installation
# -----------------------------
TEST_ROOT_UNBOUND=$(mktemp -d)
trap "rm -rf $TEST_ROOT_UNBOUND" EXIT
BREW_PREFIX="$TEST_ROOT_UNBOUND/opt/homebrew"
export BREW_PREFIX
mkdir -p "$BREW_PREFIX/etc/unbound"

TEST_PROJ_UNBOUND="$TEST_ROOT_UNBOUND/project"
mkdir -p "$TEST_PROJ_UNBOUND/config/unbound"
touch "$TEST_PROJ_UNBOUND/config/unbound/unbound.conf"
cd "$TEST_PROJ_UNBOUND" || exit 1

# Mocks
# Mocks
dscl() {
    # Check if we are checking for user existence
    if [[ "$*" == *"-list"* ]] && ([[ "$*" == *"/Users/unbound"* ]] || [[ "$*" == *"/Users/_unbound"* ]]); then
        return 1 # Not found, proceed to create
    fi
     # For Group/UID checks, we output nothing (simulating empty list) so grep fails (searching for ID)
    if [[ "$*" == *"-list"* ]]; then
        return 0
    fi
    # For creation commands
    echo "EXEC: dscl $*"
    return 0
}
unbound-anchor() { echo "EXEC: unbound-anchor $*"; return 0; }
unbound-control-setup() { echo "EXEC: unbound-control-setup $*"; return 0; }
unbound-checkconf() { echo "EXEC: unbound-checkconf $*"; return 0; }
chown() { echo "EXEC: chown $*"; return 0; }
chmod() { echo "EXEC: chmod $*"; return 0; }
brew() { echo "EXEC: brew $*"; return 0; }
networksetup() { echo "EXEC: networksetup $*"; return 0; }

OUTPUT=$(install_unbound)

assert_contains "$OUTPUT" "Installing Unbound" "Should install"
assert_contains "$OUTPUT" "EXEC: brew install unbound" "Should brew install"
assert_contains "$OUTPUT" "Finding available User ID" "Should find UID"
assert_contains "$OUTPUT" "Using UID 333" "Should use UID 333"
assert_contains "$OUTPUT" "EXEC: dscl . -create /Users/_unbound UniqueID 333" "Should create user with ID 333"
assert_contains "$OUTPUT" "EXEC: unbound-anchor -a" "Should fetch root key"
assert_contains "$OUTPUT" "EXEC: unbound-control-setup -d" "Should setup control"
assert_contains "$OUTPUT" "Copying configuration" "Should copy config"
assert_contains "$OUTPUT" "EXEC: unbound-checkconf" "Should check config"
assert_contains "$OUTPUT" "EXEC: chown -R _unbound:staff" "Should chown"
assert_contains "$OUTPUT" "EXEC: brew services start unbound" "Should start service"
assert_contains "$OUTPUT" "EXEC: networksetup -setdnsservers Wi-Fi 127.0.0.1" "Should set DNS"

# Verify Copy Command execution
assert_contains "$OUTPUT" "EXEC: cp" "Should run cp command base"
assert_contains "$OUTPUT" "unbound.conf" "Should contain unbound.conf"

# Cleanup
cd - > /dev/null || exit 1

# Test 12: DNS Verification
# -------------------------
# Mocks
sudo() { if [[ "$1" == "-v" ]]; then return 0; fi; "$@"; } # Mock sudo
scutil() { echo "  nameserver[0] : 127.0.0.1"; }
networksetup() { echo "127.0.0.1"; }
brew() {
    if [[ "$*" == "services list" ]]; then
       echo "Name           Status  User File"
       echo "dnscrypt-proxy started root /Library/LaunchDaemons/homebrew.mxcl.dnscrypt-proxy.plist"
       echo "unbound        started root /Library/LaunchDaemons/homebrew.mxcl.unbound.plist"
       echo "privoxy        started root /Library/LaunchDaemons/homebrew.mxcl.privoxy.plist"
    else
       echo "EXEC: brew $*"
    fi
}
dig() {
    # Check args to simulate specific responses
    if [[ "$*" == *"dnssec-failed"* ]]; then
        echo ";; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 15190"
    else
        echo ";; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 47039"
        echo ";; flags: qr rd ra ad; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1"
    fi
}

OUTPUT=$(network_verify_dns)

assert_contains "$OUTPUT" "Verifying DNS Configuration" "Should verify"
assert_contains "$OUTPUT" "dnscrypt-proxy is running" "Should check dnscrypt-proxy"
assert_contains "$OUTPUT" "unbound is running" "Should check unbound"
assert_contains "$OUTPUT" "privoxy is running" "Should check privoxy"
assert_contains "$OUTPUT" "System resolver is using localhost" "Should check system resolver"
assert_contains "$OUTPUT" "nameserver[0] : 127.0.0.1" "Should show scutil output"
assert_contains "$OUTPUT" "Wi-Fi is configured to use 127.0.0.1" "Should check networksetup"
assert_contains "$OUTPUT" "Testing Valid DNSSEC" "Should test valid DNSSEC"
assert_contains "$OUTPUT" "Valid DNSSEC signature verified" "Should PASS valid DNSSEC"
assert_contains "$OUTPUT" "Testing Invalid DNSSEC" "Should test invalid DNSSEC"
assert_contains "$OUTPUT" "Invalid DNSSEC rejected" "Should PASS invalid DNSSEC"


# Test 13: Security Verification
# ------------------------------
# Mock necessary tools
csrutil() { echo "System Integrity Protection status: enabled."; }
spctl() { echo "assessments enabled"; }
# Reuse brew mock but add analytics response
brew() {
    if [[ "$*" == "analytics" ]]; then
       echo "Analytics are disabled."
    else
       # Minimal default
       echo "brew command called: $*"
    fi
}
# Reuse fdesetup mock from Test 4, ensure status is On
MOCK_FDESETUP_STATUS="FileVault is On."

# Re-mock defaults (unset by Test 10)
defaults() {
    if [ "$1" == "read" ] && [ "$2" == ".GlobalPreferences.plist" ] && [ "$3" == "LDMStatus" ]; then
        if [ "$MOCK_LDM_STATUS" == "missing" ]; then
            return 1
        else
            echo "$MOCK_LDM_STATUS"
            return 0
        fi
    else
         :
    fi
}
MOCK_LDM_STATUS="1"
# Ensure OS version is high enough for Lockdown (Mocked in check_macos/platform but we might need to reset PLATFORM_OS_VER_MAJOR if it was changed? Test 5 changed MOCK_OS_VER)
MOCK_OS_VER="13.0"
detect_os_version > /dev/null

# socketfilterfw path mocking requires function override since it's a path
socketfilterfw() {
    if [[ "$*" == *"--getglobalstate"* ]]; then echo "Firewall is enabled. (State = 1)"; fi
    if [[ "$*" == *"--getstealthmode"* ]]; then echo "Stealth mode enabled"; fi
}

# BETTER PLAN: Update `lib/macos_hardening.sh` to use a variable `SOCKETFILTERFW_CMD="/usr/libexec/ApplicationFirewall/socketfilterfw"` at top of file, so we can override it in tests.
SOCKETFILTERFW_CMD="socketfilterfw"

OUTPUT=$(hardening_verify)
assert_contains "$OUTPUT" "Verifying Security Configuration" "Should verify security"
assert_contains "$OUTPUT" "Firewall is enabled" "Should check Firewall"
assert_contains "$OUTPUT" "Stealth Mode is enabled" "Should check Stealth Mode"
assert_contains "$OUTPUT" "FileVault is enabled" "Should check FileVault"
assert_contains "$OUTPUT" "SIP is enabled" "Should check SIP"
assert_contains "$OUTPUT" "Gatekeeper is enabled" "Should check Gatekeeper"
assert_contains "$OUTPUT" "Lockdown Mode is enabled" "Should check Lockdown Mode"
assert_contains "$OUTPUT" "Homebrew Analytics are disabled" "Should check Brew Analytics"


# Test 14: Firefox Installation
# -----------------------------
# Mock curl
curl() {
    echo "CURL: $*"
    # Create the dummy file so hdiutil attach works if it checks
    if [[ "$*" == *"-o"* ]]; then
        # Last arg should be URL, 2nd to last key (after -o) is path
        # Simple parsing for mock:
        # We know the script does curl -L -o "$dmg_path" "$url"
        # So $3 is path
        touch "$3"
    fi
}
# Mock hdiutil
hdiutil() {
    if [[ "$*" == *"attach"* ]]; then
        # Output typical hdiutil attach line
        echo "/dev/disk2s1  Apple_HFS   /Volumes/Firefox"
    elif [[ "$*" == *"detach"* ]]; then
         echo "CURL: hdiutil detach called"
    fi
}
# Mock codesign
codesign() {
    echo "Identifier=org.mozilla.firefox"
    echo "Authority=Mozilla Corporation"
}

# Mock cp to avoid real I/O failure
cp() {
    echo "CP: $*"
}

OUTPUT=$(install_firefox)
assert_contains "$OUTPUT" "Downloading Firefox" "Should download"
assert_contains "$OUTPUT" "Mounting DMG" "Should mount"
assert_contains "$OUTPUT" "Mounted at: /Volumes/Firefox" "Should parse mount point"
assert_contains "$OUTPUT" "Copying Firefox to /Applications" "Should copy"
assert_contains "$OUTPUT" "Verifying Code Signature" "Should verify signature"
assert_contains "$OUTPUT" "Firefox signature verified" "Should PASS signature check"

# Cleanup mocks
unset -f curl hdiutil codesign cp


# Test 15: Firefox Hardening
# --------------------------
# Setup fake home and profile
TEST_HOME="$(mktemp -d /tmp/test_home.XXXXXX)"
TEST_PROFILE_DIR="$TEST_HOME/Library/Application Support/Firefox/Profiles/abcd123.default-release"
mkdir -p "$TEST_PROFILE_DIR"
touch "$TEST_PROFILE_DIR/prefs.js"

# Mock curl
curl() {
    echo "CURL: $*"
    if [[ "$*" == *"-o"* ]]; then
        # Create dummy user.js
        # $3 is output path
        echo "// Arkenfox user.js" > "$3"
    fi
}

# Run test with modified HOME
# Save original HOME to restore later
OLD_HOME="$HOME"
export HOME="$TEST_HOME"

OUTPUT=$(harden_firefox)

# Restore HOME
export HOME="$OLD_HOME"

assert_contains "$OUTPUT" "Target Profile: abcd123.default-release" "Should detect profile"
assert_contains "$OUTPUT" "Backing up prefs.js" "Should backup prefs"
assert_contains "$OUTPUT" "Downloading Arkenfox user.js" "Should download"
assert_contains "$OUTPUT" "Applying configuration" "Should apply overrides"
assert_contains "$OUTPUT" "Firefox hardening complete" "Should complete"

if [ -f "$TEST_PROFILE_DIR/user.js" ]; then
    USER_JS_CONTENT=$(cat "$TEST_PROFILE_DIR/user.js")
    assert_contains "$USER_JS_CONTENT" "Arkenfox user.js" "Should install user.js"
    assert_contains "$USER_JS_CONTENT" "Restore previous session" "Should apply overrides"
else
    # Force a fail
    assert_equals "true" "false" "user.js should be created"
fi

# Check backup
BACKUP_EXISTS=$(ls "$TEST_PROFILE_DIR/prefs.js.backup."* >/dev/null 2>&1 && echo "yes" || echo "no")
assert_equals "yes" "$BACKUP_EXISTS" "Should create backup"

# Cleanup
rm -rf "$TEST_HOME"


# Test 16: Tor Installation
# -------------------------
TEST_HOME="$(mktemp -d /tmp/test_tor.XXXXXX)"

# Mock gpg
gpg() {
    # Since script redirects output to /dev/null, we cannot capture echo in OUTPUT.
    # We use a witness file to record calls.
    echo "GPG_CALL: $*" >> "$TEST_HOME/gpg_calls.log"
    
    if [[ "$*" == *"--list-keys"* ]]; then
        # Return 1 to simulate key missing, triggering import logic
        return 1
    fi
    if [[ "$*" == *"--verify"* ]]; then
        echo "Good signature from \"Tor Browser Developers"
        return 0
    fi
}

# Mock curl for version fetch
curl() {
    # Parse args for -o (download)
    local output_file=""
    local url=""
    local args=("$@")
    for ((i=0; i<${#args[@]}; i++)); do
        if [[ "${args[i]}" == "-o" ]]; then
            output_file="${args[i+1]}"
        fi
        # Assume last arg is URL usually, or we can check regex
        if [[ "${args[i]}" == http* ]]; then
            url="${args[i]}"
        fi
    done

    if [[ -n "$output_file" ]]; then
         touch "$output_file"
         echo "CURL: downloaded to $output_file"
         return 0
    fi
    
    # If fetching version page (no -o)
    if [[ "$*" == *"torproject.org/download/"* ]]; then
        echo "<html><a href=\"/dist/torbrowser/13.0.1/TorBrowser-13.0.1-macos_ALL.dmg\">Download</a></html>"
        return 0
    fi
    echo "CURL: unknown call $*"
}

# hdiutil, codesign, spctl mocks
hdiutil() {
    echo "/dev/disk2s1  Apple_HFS   /Volumes/Tor Browser"
}
codesign() {
    echo "Identifier=org.torproject.torbrowser"
    echo "Authority=Developer ID Application: The Tor Project, Inc (MADPSAYN6T)"
}
spctl() {
    echo "/Applications/Tor Browser.app: accepted"
}

OUTPUT=$(install_tor_browser)

assert_contains "$OUTPUT" "Latest Version detected: 13.0.1" "Should detect latest version"
assert_contains "$OUTPUT" "Downloading TorBrowser-13.0.1-macos_ALL.dmg" "Should download dmg"
assert_contains "$OUTPUT" "Downloading signature" "Should download signature"

# Check GPG calls from log
GPG_LOG=$(cat "$TEST_HOME/gpg_calls.log")
assert_contains "$GPG_LOG" "--list-keys 0xEF6E" "Should check for key"
assert_contains "$OUTPUT" "Importing Tor Browser Developers key" "Should import key"
assert_contains "$GPG_LOG" "--verify" "Should verify signature"
assert_contains "$OUTPUT" "PGP Signature Verified" "Should PASS signature verify"
assert_contains "$OUTPUT" "Code Signature matches The Tor Project (MADPSAYN6T)" "Should verify code signature"

# Cleanup
unset -f gpg curl hdiutil codesign spctl


# Test 17: GPG Setup
# ------------------
TEST_HOME="$(mktemp -d /tmp/test_gpg.XXXXXX)"
# Mock Home for this function
setup_gpg_mocked() {
    HOME="$TEST_HOME" setup_gpg
}
# Mock brew
brew() {
    echo "BREW_CALL: $*"
    return 0
}

OUTPUT=$(setup_gpg_mocked)

assert_contains "$OUTPUT" "Setting up GPG..." "Should start setup"
assert_contains "$OUTPUT" "Creating $TEST_HOME/.gnupg" "Should create dir"
assert_contains "$OUTPUT" "Copying hardened configuration" "Should copy config"

if [ -f "$TEST_HOME/.gnupg/gpg.conf" ]; then
    assert_equals "true" "true" "gpg.conf should exist"
else
    assert_equals "true" "false" "gpg.conf should exist"
fi

# Verify backup logic by running again
touch "$TEST_HOME/.gnupg/gpg.conf" # Ensure it exists timestamped
# Wait a sec to ensure backup name differs if we used seconds?
# The function uses $(date +%s), so running immediately might collide if fast. 
# But we just want to see "Existing gpg.conf found" msg.
OUTPUT_2=$(setup_gpg_mocked)
assert_contains "$OUTPUT_2" "Existing gpg.conf found" "Should detect existing config"
assert_contains "$OUTPUT_2" "Backup created" "Should create backup"

# Cleanup
rm -rf "$TEST_HOME"


rm -rf "$TEST_ROOT_UNBOUND"


# Test 18: Signal Installation
# ----------------------------
brew() {
    if [[ "$*" == *"list"* ]]; then
        return 1 # Simulate not installed
    fi
    echo "BREW_CALL: $*"
    return 0
}

OUTPUT=$(install_signal)
assert_contains "$OUTPUT" "Installing Signal Desktop" "Should start signal install"
assert_contains "$OUTPUT" "BREW_CALL: install --cask signal" "Should call brew cask install"
assert_contains "$OUTPUT" "Refer to docs/MESSENGERS.md" "Should show docs link"



# Test 19: Metadata Cleanup
# -------------------------
# Mock destructive commands to prevent actual deletion during test
defaults() { echo "DEFAULTS_CALL: $*"; return 0; }
rm() { echo "RM_CALL: $*"; return 0; }
qlmanage() { echo "QL_CALL: $*"; return 0; }
nvram() { echo "NVRAM_CALL: $*"; return 0; }
chflags() { echo "CHFLAGS_CALL: $*"; return 0; }
xattr() { echo "XATTR_CALL: $*"; return 0; }
chmod() { echo "CHMOD_CALL: $*"; return 0; }
getconf() { echo "/tmp/mock_cache"; return 0; }
ask_confirmation() { return 0; } # Auto-yes

# We will use PWD since we run from root
source "$(dirname "$0")/../lib/cleanup.sh"

OUTPUT=$(cleanup_metadata)
assert_contains "$OUTPUT" "Cleaning QuickLook Cache" "Should clean QL"
assert_contains "$OUTPUT" "QL_CALL: -r disablecache" "Should disable QL cache"
assert_contains "$OUTPUT" "DEFAULTS_CALL: delete" "Should delete defaults"
assert_contains "$OUTPUT" "NVRAM_CALL: -d" "Should clear NVRAM"
assert_contains "$OUTPUT" "RM_CALL: -rf" "Should call rm"
assert_contains "$OUTPUT" "CHFLAGS_CALL: -R uchg" "Should lock directories"

# Test 19b: Deep Cleanup (Mocks)
sysadminctl() { echo "SYSADMINCTL_CALL: $*"; }
xcrun() { echo "XCRUN_CALL: $*"; }
docker() { echo "DOCKER_CALL: $*"; }
npm() { echo "NPM_CALL: $*"; }
tccutil() { echo "TCCUTIL_CALL: $*"; }

OUTPUT=$(cleanup_dev_tools)
assert_contains "$OUTPUT" "DOCKER_CALL: system prune" "Should prune docker"
assert_contains "$OUTPUT" "NPM_CALL: cache clean" "Should clean npm"

OUTPUT=$(cleanup_ios_data)
assert_contains "$OUTPUT" "XCRUN_CALL: simctl erase" "Should erase simulators"

# Mock id for guest check
id() {
    if [[ "$*" == *"guest"* ]]; then return 0; fi
    return 1
}
OUTPUT=$(hardening_remove_guest)
assert_contains "$OUTPUT" "SYSADMINCTL_CALL: -deleteUser guest" "Should delete guest"

OUTPUT=$(hardening_reset_tcc)
assert_contains "$OUTPUT" "TCCUTIL_CALL: reset All" "Should reset TCC"


rm -rf "$TEST_ROOT_UNBOUND"
unset -f dscl unbound-anchor unbound-control-setup unbound-checkconf chown chmod brew networksetup

# Test 20: Password Vault
# -----------------------
# Mock GPG output
gpg() { echo "Encrypted Data"; return 0; }
# Source lib/vault.sh
source "$(dirname "$0")/../lib/vault.sh"

VAULT_DIR="/tmp/test_vault_$$" # Override for test

# Test Init
OUTPUT=$(vault_init)
assert_contains "$OUTPUT" "Initializing Vault" "Should init vault"
if [ -d "$VAULT_DIR" ]; then 
    echo "[PASS] Vault dir created"; 
else 
    echo "[FAIL] Vault dir missing"; 
    FAIL_COUNT=$((FAIL_COUNT+1)); 
fi

rm -rf "$VAULT_DIR"

# Test 21: Backup Tools
# ---------------------
tar() { echo "TAR_CALL: $*" >&2; return 0; }
hdiutil() { echo "HDIUTIL_CALL: $*"; return 0; }
tmutil() { echo "TMUTIL_CALL: $*" >&2; echo "Running = 1"; return 0; }

# Source lib/backup.sh
source "$(dirname "$0")/../lib/backup.sh"

mkdir -p "/tmp/src"

# Test Encrypt (capture stderr too)
OUTPUT=$(backup_encrypt_dir "/tmp/src" "/tmp/dst.gpg" 2>&1)
assert_contains "$OUTPUT" "Archiving and Encrypting" "Should start encrypt"
assert_contains "$OUTPUT" "TAR_CALL: zcvf - /tmp/src" "Should call tar"

# Test Volume
OUTPUT=$(backup_create_volume "Secret" "100M")
assert_contains "$OUTPUT" "Creating Encrypted DMG" "Should start volume creation"
assert_contains "$OUTPUT" "HDIUTIL_CALL: create Secret.dmg -encryption -size 100M" "Should call hdiutil"

# Test Audit (capture stderr)
OUTPUT=$(backup_audit_timemachine 2>&1)
assert_contains "$OUTPUT" "Auditing Time Machine" "Should audit TM"
assert_contains "$OUTPUT" "TMUTIL_CALL: status" "Should call tmutil status"


# Test 22: Wi-Fi Tools
# --------------------
check_root() { return 0; }


# Mock airport as a script because lib checks [ -x ]
MOCK_AIRPORT="/tmp/mock_airport_$$"
cat <<EOF > "$MOCK_AIRPORT"
#!/bin/bash
if [ "\$1" == "-z" ]; then
    echo "AIRPORT_DISASSOCIATE"
elif [ "\$1" == "-I" ]; then
    echo "     agile: On"
    echo "     SSID: TestNet"
    echo "     link auth: wpa2-psk"
fi
EOF
chmod +x "$MOCK_AIRPORT"

# Mock ifconfig
ifconfig() { 
    if [ "$1" == "en0" ] && [ "$2" == "ether" ]; then
        echo "IFCONFIG_SET: $3"
        return 0
    else
        # Mock current MAC read
        echo "ether 12:34:56:78:90:ab"
    fi
}

# Mock openssl
openssl() {
    # rand -hex 5 returns 10 chars
    echo "aabbccddee"
}

source "$(dirname "$0")/../lib/wifi.sh"
# Override AIRPORT_BIN after sourcing
AIRPORT_BIN="$MOCK_AIRPORT"

# Mock interface getter (override lib function)
wifi_get_interface() { echo "en0"; }

# Test Spoof
OUTPUT=$(wifi_spoof_mac)
rm -f "$MOCK_AIRPORT" # Cleanup
assert_contains "$OUTPUT" "AIRPORT_DISASSOCIATE" "Should disassociate"
assert_contains "$OUTPUT" "IFCONFIG_SET:" "Should set new mac"

# Re-create for Audit (cleanup deleted it)
cat <<EOF > "$MOCK_AIRPORT"
#!/bin/bash
if [ "\$1" == "-I" ]; then
    echo "     agile: On"
    echo "     SSID: TestNet"
    echo "     link auth: wpa2-psk"
fi
EOF
chmod +x "$MOCK_AIRPORT"
AIRPORT_BIN="$MOCK_AIRPORT"

# Test Audit
OUTPUT=$(wifi_audit)
rm -f "$MOCK_AIRPORT"
assert_contains "$OUTPUT" "Connected to: TestNet" "Should detect SSID"
assert_contains "$OUTPUT" "Encryption (wpa2-psk) appears modern" "Should detect WPA2"


# Test 23: SSH Tools
# ------------------
systemsetup() { echo "Remote Login: On"; }
ssh-keygen() { echo "SSH_KEYGEN_CALL: $*"; }

# Mock variables for module
ROOT_DIR="."
# mkdir -p "./config/ssh"
# touch "./config/ssh/ssh_config"
# touch "./config/ssh/sshd_config"

source "$(dirname "$0")/../lib/ssh.sh"

# Test Audit
OUTPUT=$(ssh_check_sshd_status)
assert_contains "$OUTPUT" "Checking SSH Server" "Should check status"
assert_contains "$OUTPUT" "Remote Login: On" "Should report status"

# Test Harden SSHD
# Mock ask_confirmation to yes
ask_confirmation() { return 0; }
cp() { echo "CP_CALL: $*"; }
chmod() { echo "CHMOD_CALL: $*"; }
chown() { echo "CHOWN_CALL: $*"; }
sshd() { echo "SSHD_TEST: $*"; }

OUTPUT=$(ssh_harden_sshd 2>&1)
assert_contains "$OUTPUT" "overwrite /etc/ssh/sshd_config" "Should warn"
assert_contains "$OUTPUT" "CHECK_CALL: ./config/ssh/sshd_config /etc/ssh/sshd_config sudo" "Should check config"
assert_contains "$OUTPUT" "SSHD_TEST: -t" "Should test config"

# Test Hash Hosts
command rm -f "$HOME/.ssh/known_hosts"
OUTPUT=$(ssh_hash_hosts)
# Fails because default path doesn't exist in test env, warn is expected
assert_contains "$OUTPUT" "No known_hosts file" "Should warn if missing"
# Touch file to test success
mkdir -p "$HOME/.ssh"
touch "$HOME/.ssh/known_hosts"
OUTPUT=$(ssh_hash_hosts)
assert_contains "$OUTPUT" "SSH_KEYGEN_CALL: -H -f" "Should hash hosts"


# Test 24: Misc Hardening
# -----------------------
# Mock sudo for grep check in sudoers
sudo() {
    if [ "$1" == "grep" ]; then
        # Simulate finding the bad line
        return 0 
    else
        execute_sudo "$@"
    fi
}
# Mock launchctl for umask
launchctl() { echo "LAUNCHCTL_CALL: $*"; }

# Source lib again to ensure mocks apply (though already sourced by earlier tests, logic might bind early)
# Actually, the function uses 'sudo' which is a function now.
source "$(dirname "$0")/../lib/macos_hardening.sh"

# Override MDNS_PLIST to non-existent for test
MDNS_PLIST="/tmp/non_existent_plist_$$"
OUTPUT=$(hardening_disable_bonjour)
assert_contains "$OUTPUT" "mDNSResponder plist not found" "Should warn if missing (mock default)"

# Mock systemsetup for remote events
systemsetup() { echo "SYSTEMSETUP_CALL: $*"; }

OUTPUT=$(hardening_configure_privacy)
assert_contains "$OUTPUT" "SYSTEMSETUP_CALL: -setremoteappleevents off" "Should disable remote events"

OUTPUT=$(hardening_disable_analytics)
assert_contains "$OUTPUT" "com.apple.AdLib" "Should disable AdLib"

OUTPUT=$(hardening_privacy_tweaks)
assert_contains "$OUTPUT" "DisableAirDrop" "Should disable AirDrop"

OUTPUT=$(hardening_disable_app_telemetry)
assert_contains "$(cat "$HOME/.zshrc")" "DOTNET_CLI_TELEMETRY_OPTOUT" "Should disable Dotnet Tel"

OUTPUT=$(hardening_secure_sudoers)
assert_contains "$OUTPUT" "Auditing sudoers" "Should audit"
assert_contains "$OUTPUT" "Sudoers contains 'env_keep" "Should find bad line"

OUTPUT=$(hardening_set_umask)
assert_contains "$OUTPUT" "Setting system umask" "Should set umask"
assert_contains "$OUTPUT" "LAUNCHCTL_CALL: config user umask 077" "Should call launchctl"

# Test Finder (defaults mock)
defaults() { echo "DEFAULTS_CALL: $*"; }
chflags() { echo "CHFLAGS_CALL: $*"; }
OUTPUT=$(hardening_harden_finder)
assert_contains "$OUTPUT" "Hardening Finder" "Should harden finder"
assert_contains "$OUTPUT" "DEFAULTS_CALL: write com.apple.finder AppleShowAllFiles -bool true" "Should show all files"
assert_contains "$OUTPUT" "CHFLAGS_CALL: nohidden" "Should unhide Library"




start_suite "Tor Manager"
source "$(dirname "$0")/../lib/tor_manager.sh"

# Test 25: Tor Service Management
# -------------------------------
# Mock pgrep
pgrep() {
    if [ "$1" == "-x" ] && [ "$2" == "tor" ]; then
        if [ "$MOCK_TOR_RUNNING" == "true" ]; then
            return 0
        else
            return 1
        fi
    fi
}
# Reuse brew mock
brew() {
    echo "BREW_CALL: $*"
    if [ "$1" == "services" ] && [ "$2" == "start" ]; then
        MOCK_TOR_RUNNING="true"
    fi
    if [ "$1" == "services" ] && [ "$2" == "stop" ]; then
        MOCK_TOR_RUNNING="false"
    fi
}

MOCK_TOR_RUNNING="false"
OUTPUT=$(tor_service_start)
assert_contains "$OUTPUT" "BREW_CALL: services start tor" "Should start tor service"
assert_contains "$OUTPUT" "Tor Service is running" "Should verify running"

MOCK_TOR_RUNNING="true"
OUTPUT=$(tor_service_stop)
assert_contains "$OUTPUT" "BREW_CALL: services stop tor" "Should stop tor service"
assert_contains "$OUTPUT" "Tor Service stopped" "Should verify stopped"

# Test 26: Tor Proxy Configuration
# --------------------------------
networksetup() {
    echo "NET_CALL: $*"
    if [ "$1" == "-getsocksfirewallproxy" ]; then
        if [ "$MOCK_PROXY_ENABLED" == "true" ]; then
            echo "Enabled: Yes"
            echo "Server: 127.0.0.1"
            echo "Port: 9050"
        else
            echo "Enabled: No"
        fi
    fi
}

OUTPUT=$(tor_enable_system_proxy)
assert_contains "$OUTPUT" "Enabling System SOCKS Proxy" "Should report enabling"
assert_contains "$OUTPUT" "NET_CALL: -setsocksfirewallproxy Wi-Fi 127.0.0.1 9050" "Should set proxy host port"
assert_contains "$OUTPUT" "NET_CALL: -setsocksfirewallproxystate Wi-Fi on" "Should set proxy state on"

OUTPUT=$(tor_disable_system_proxy)
assert_contains "$OUTPUT" "Disabling System SOCKS Proxy" "Should report disabling"
assert_contains "$OUTPUT" "NET_CALL: -setsocksfirewallproxystate Wi-Fi off" "Should set proxy state off"

MOCK_PROXY_ENABLED="true"
MOCK_TOR_RUNNING="true"
OUTPUT=$(tor_status)
assert_contains "$OUTPUT" "[RUNNING] Tor Service is active" "Should show running status"
assert_contains "$OUTPUT" "[ENABLED] System SOCKS Proxy is ON" "Should show enabled proxy"




start_suite "Lifecycle Managers"
source "$(dirname "$0")/../lib/lifecycle.sh"

# Test 27: Setup Wizard
# ---------------------
# Mock interactive confirming
ask_confirmation() {
    # We'll simulate 'yes' to all
    return 0 
}
header() {
    echo "HEADER: $1"
}

# Mock key underlying functions we expect to be called
hardening_enable_firewall() { echo "CALL: hardening_enable_firewall"; }
network_set_dns() { echo "CALL: network_set_dns $1"; }
network_update_hosts() { echo "CALL: network_update_hosts"; }
tor_install() { echo "CALL: tor_install"; }

OUTPUT=$(lifecycle_setup)
assert_contains "$OUTPUT" "HEADER: Better Anonymity - First Time Setup" "Should show setup wizard"

assert_contains "$OUTPUT" "CALL: hardening_enable_firewall" "Should apply hardening"
assert_contains "$OUTPUT" "CALL: network_set_dns quad9" "Should set DNS"
assert_contains "$OUTPUT" "CALL: network_update_hosts" "Should update hosts"
assert_contains "$OUTPUT" "CALL: tor_install" "Should install tor"

# Test 28: Daily Check
# --------------------
# Mock verify functions
hardening_verify() { echo "CALL: hardening_verify"; }
network_verify_dns() { echo "CALL: network_verify_dns"; }
tor_status() { echo "CALL: tor_status"; }
# Mock brew existence
command() { return 0; } 
# Mock hosts file existence for update check
# We can't easily mock file check [ -f ] without modifying source or filesystem.
# But we can check if it calls verify/dns/tor.

OUTPUT=$(lifecycle_daily)
assert_contains "$OUTPUT" "HEADER: Daily Health Check" "Should show daily header"

assert_contains "$OUTPUT" "CALL: hardening_verify" "Should verify security"
assert_contains "$OUTPUT" "CALL: network_verify_dns" "Should verify dns"
assert_contains "$OUTPUT" "CALL: tor_status" "Should check tor"

# Test 29: Update
# ---------------
# Undo 'command' mock from previous test, so mkdir works
unset -f command

# Mock git
git() {
    echo "GIT_CALL: $*"
    return 0
}
# Mock cd to prevent side effects
cd() { echo "CD_CALL: $1"; return 0; }
# Mock ROOT_DIR and .git dir
TEST_GIT_ROOT=$(mktemp -d)
mkdir "$TEST_GIT_ROOT/.git"
ROOT_DIR="$TEST_GIT_ROOT"
export ROOT_DIR

OUTPUT=$(lifecycle_update)
assert_contains "$OUTPUT" "Checking for 'better-anonymity' updates" "Should check update"
assert_contains "$OUTPUT" "CD_CALL" "Should cd"
assert_contains "$OUTPUT" "GIT_CALL: pull" "Should run git pull"


rm -rf "$TEST_GIT_ROOT/.git"


rm -rf "$TEST_GIT_ROOT"

# Test non-git repo
ROOT_DIR="/tmp/not_a_repo"
OUTPUT=$(lifecycle_update)
assert_contains "$OUTPUT" "Not a git repository" "Should fail if not git"



# Test 30: I2P Manager
# --------------------
start_suite "I2P Manager Tests"
source "$(dirname "$0")/../lib/i2p_manager.sh"

# Mock brew
brew() {
    echo "BREW_CALL: $*"
    return 0
}
# Mock i2prouter
i2prouter() {
    echo "I2P_CALL: $*"
    return 0
}
# Mock open
open() {
    echo "OPEN_CALL: $*"
    return 0
}
# Mock command check
command() {
    if [ "$1" == "-v" ]; then
        return 0 # simulate command found
    fi
    return 0
}

# Test Installation
OUTPUT=$(i2p_install)
assert_contains "$OUTPUT" "BREW_CALL: install i2p" "Should install i2p"

# Test Start
OUTPUT=$(i2p_start)
assert_contains "$OUTPUT" "I2P_CALL: start" "Should start i2p"

# Test Stop
OUTPUT=$(i2p_stop)
assert_contains "$OUTPUT" "I2P_CALL: stop" "Should stop i2p"

# Test Restart
OUTPUT=$(i2p_restart)
assert_contains "$OUTPUT" "I2P_CALL: restart" "Should restart i2p"

# Test Status
OUTPUT=$(i2p_status)
assert_contains "$OUTPUT" "I2P_CALL: status" "Should check status"

# Test Console
OUTPUT=$(i2p_console)
assert_contains "$OUTPUT" "OPEN_CALL: http://127.0.0.1:7657/home" "Should open console"

# end_suite removed to continue testing


# Test 31: KeePassXC Installer
# ----------------------------
start_suite "KeePassXC Installer"
source "$(dirname "$0")/../lib/installers.sh"

# Mock brew to trace calls
brew() {
    echo "BREW_CALL: $*"
    if [[ "$1" == "list" ]]; then
        return 1
    fi
    return 0
}


OUTPUT=$(install_keepassxc)
assert_contains "$OUTPUT" "BREW_CALL: install --cask keepassxc" "Should install keepassxc cask"
assert_contains "$OUTPUT" "Installing KeePassXC" "Should print info"

end_suite





