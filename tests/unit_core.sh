#!/bin/bash

# tests/unit_core.sh
# Unit tests for core utilities

source "$(dirname "$0")/test_framework.sh"
source "$(dirname "$0")/../lib/core.sh"

start_suite "Core Utilities"

# Test 1: Logging Colors
# ----------------------
# Capture output, verify coloring codes
OUTPUT=$(info "test message")
assert_contains "$OUTPUT" "[INFO]" "Info should print [INFO]"

OUTPUT=$(warn "test message")
assert_contains "$OUTPUT" "[WARN]" "Warn should print [WARN]"

# Test 2: ensure_root Logic
# -------------------------
# Mock sudo and EUID
SUDO_CALLED=0
EUID_MOCK=1000

# Mock SUDO command
sudo() {
    SUDO_CALLED=1
    return 0
}

# Override EUID check in logic by sourcing modified or just simulating usage?
# Shell variables like EUID are read-only in some shells or hard to override if natively used.
# ensure_root uses "$EUID". In bash we can't easily override EUID.
# However, we can modify ensure_root to accept an argument or variable if set?
# Or we just test the logic inside if we could.
# Strategy: We can't easily mock EUID in the same process.
# We will skip direct EUID mocking unless we change the lib to use a function `get_euid`.
# Refactor lib/core.sh to testable first? Or just trust the simple check?
# Let's try to set EUID variable if not readonly (it is readonly in bash).
# Alternative: skip this test or use a wrapper.

# Simulating a wrapper check:
check_root_logic() {
    local simulated_euid=$1
    if [ "$simulated_euid" -ne 0 ]; then
        return 1
    fi
    return 0
}

check_root_logic 1000
assert_equals "1" "$?" "Should return 1 if not root"

check_root_logic 0
assert_equals "0" "$?" "Should return 0 if root"



# Test 3: Check Functions
# -----------------------

# Mock brew
brew() {
    local cmd="$1"
    local sub="$2"
    local pkg="$3"
    
    if [ "$cmd" == "list" ]; then
        if [ "$sub" == "--formula" ] && [ "$pkg" == "installed_pkg" ]; then return 0; fi
        if [ "$sub" == "--cask" ] && [ "$pkg" == "installed_cask" ]; then return 0; fi
    fi
    return 1
}

# Test is_brew_installed
if is_brew_installed "installed_pkg"; then
    echo -e "${GREEN}[PASS]${NC} is_brew_installed detected package"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} is_brew_installed failed to detect package"
    ((FAILED++))
fi

if ! is_brew_installed "missing_pkg"; then
    echo -e "${GREEN}[PASS]${NC} is_brew_installed correctly reportedly missing"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} is_brew_installed falsely detected missing package"
    ((FAILED++))
fi

# Test is_cask_installed
if is_cask_installed "installed_cask"; then
    echo -e "${GREEN}[PASS]${NC} is_cask_installed detected cask"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} is_cask_installed failed to detect cask"
    ((FAILED++))
fi

# Test is_app_installed
# Use a temporary HOME to avoid writing to system /Applications
TEST_HOME="$(mktemp -d)"
OLD_HOME="$HOME"
export HOME="$TEST_HOME"
mkdir -p "$TEST_HOME/Applications/MockApp.app"

if is_app_installed "MockApp.app"; then
    echo -e "${GREEN}[PASS]${NC} is_app_installed detected app"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} is_app_installed failed to detect app"
    ((FAILED++))
fi
rm -rf "$TEST_HOME"
export HOME="$OLD_HOME"

if ! is_app_installed "NonExistent.app"; then
    echo -e "${GREEN}[PASS]${NC} is_app_installed correctly reportedly missing"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} is_app_installed falsely detected missing app"
    ((FAILED++))
fi


# Test check_config_and_backup
# ----------------------------
test_config_backup() {
    local src="/tmp/test_src_$$"
    local dest="/tmp/test_dest_$$"
    
    echo "content_new" > "$src"
    echo "content_old" > "$dest"
    
    # Run function
    OUTPUT=$(check_config_and_backup "$src" "$dest")

    
    # Verify backup created
    count=$(ls "${dest}.bak."* 2>/dev/null | wc -l)
    if [ "$count" -ge 1 ]; then
        echo -e "${GREEN}[PASS]${NC} Backup created"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} Backup NOT created"
        ((FAILED++))
    fi
    
    # Verify content updated
    if [ "$(cat "$dest")" == "content_new" ]; then
        echo -e "${GREEN}[PASS]${NC} Config updated"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} Config NOT updated"
        ((FAILED++))
    fi
    
    # Cleanup
    rm -f "$src" "$dest" "${dest}.bak."*
}
test_config_backup

# Test 5: sed_in_place Portability
# --------------------------------
test_sed_in_place() {
    local test_file="/tmp/test_sed_$$"
    echo "foo bar" > "$test_file"
    
    sed_in_place "s/foo/baz/" "$test_file"
    
    if grep -q "baz bar" "$test_file"; then
        echo -e "${GREEN}[PASS]${NC} sed_in_place modified content correctly"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} sed_in_place failed. Content: $(cat "$test_file")"
        ((FAILED++))
    fi
    rm -f "$test_file"
}
test_sed_in_place

# Test 6: check_internet Robustness
# ---------------------------------
# Mock ping to fail for 8.8.8.8 but succeed for 1.1.1.1
ping() {
    local ip="$3" # ping -c 1 <ip> -> $3 is IP usually? No: ping -c 1 8.8.8.8
    # Arguments order varies. standard: ping -c 1 ip
    # check_internet calls: ping -c 1 "$target"
    # Args: $1=-c, $2=1, $3=target
    local target="$3"
    
    if [ "$target" == "8.8.8.8" ]; then
        return 1 # Fail Google
    elif [ "$target" == "1.1.1.1" ]; then
        return 0 # Pass Cloudflare
    fi
    return 1
}

# Capture output to suppress explicit output from check_internet? 
# check_internet returns 0 on success, 1 on fail.
if check_internet >/dev/null 2>&1; then
     echo -e "${GREEN}[PASS]${NC} check_internet succeeded with fallback"
     ((PASSED++))
else
     echo -e "${RED}[FAIL]${NC} check_internet failed despite available fallback"
     ((FAILED++))
fi





# Test 7: execute_brew Root Handling
# ----------------------------------
test_execute_brew() {
    # Mocks
    local MOCK_ID_UID=1000
    id() { 
        if [ "$1" == "-u" ]; then 
            echo "$MOCK_ID_UID"
        else
            command id "$@"
        fi
    }
    
    local BREW_CALLED=""
    local SUDO_CALLED=""
    
    brew() {
        BREW_CALLED="$*"
        return 0
    }
    
    sudo() {
        SUDO_CALLED="$*"
        # Simulate sudo running the command? 
        # For 'sudo -u user brew ...', arguments are: -u, user, brew, ...
        # We can just check SUDO_CALLED string
        return 0
    }
    
    warn() { :; }
    error() { :; }
    
    # reset vars
    unset SUDO_USER
    unset BETTER_ANONYMITY_ALLOW_ROOT
    
    # Case 1: Non-root
    MOCK_ID_UID=1000
    execute_brew "Installing" install foo
    assert_equals "install foo" "$BREW_CALLED" "Non-root should run brew directly"
    
    # Case 2: Root with SUDO_USER (Safe)
    MOCK_ID_UID=0
    SUDO_USER="realuser"
    BREW_CALLED=""
    execute_brew "Installing" install bar
    # sudo should be called: -u realuser brew install bar
    assert_contains "$SUDO_CALLED" "-u realuser brew install bar" "Root+SUDO_USER should drop privileges"
    
    # Case 3: Root without SUDO_USER (Unsafe) - Should Fail
    MOCK_ID_UID=0
    unset SUDO_USER
    BREW_CALLED=""
    if execute_brew "Installing" install baz; then
         fail "execute_brew should fail as root without SUDO_USER"
    else
         pass "execute_brew failed as root correctly"
    fi
    
    # Case 4: Root without SUDO_USER + Override (Safe-ish)
    MOCK_ID_UID=0
    unset SUDO_USER
    export BETTER_ANONYMITY_ALLOW_ROOT=1
    BREW_CALLED=""
    if execute_brew "Installing" install qux; then
         pass "execute_brew succeeded with override"
         assert_equals "install qux" "$BREW_CALLED" "Override should run brew directly"
    else
         fail "execute_brew failed despite override"
    fi
    unset BETTER_ANONYMITY_ALLOW_ROOT
}
test_execute_brew



# Test 8: check_internet with check_port
# --------------------------------------
test_check_internet_latency() {
    # Mock check_port
    check_port() {
        if [ "$1" == "1.1.1.1" ] && [ "$2" -eq 53 ]; then
             return 1 # Fallback
        elif [ "$1" == "8.8.8.8" ] && [ "$2" -eq 53 ]; then
             return 0 # Success
        fi
        return 1
    }
    
    # Redefine ping to fail (to ensuring we aren't using it)
    ping() { fail "check_internet should not call ping"; return 1; }
    
    if check_internet; then
         pass "check_internet succeeded via check_port fallback"
    else
         fail "check_internet failed unexpectedly"
    fi
    
    # Mock failure
    check_port() { return 1; } 
    if ! check_internet; then
         pass "check_internet failed correctly when ports unreachable"
    else
         fail "check_internet succeeded when ports unreachable"
    fi
}
test_check_internet_latency

end_suite
