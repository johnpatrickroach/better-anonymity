#!/bin/bash

# tests/unit_menus.sh
# Unit tests for Menus (Structural/Logic verification)

source "$(dirname "$0")/test_framework.sh"
# We don't source menus.sh directly usually because it defines functions but also could have side effects? 
# No, it just defines functions.
# source "$(dirname "$0")/../lib/menus.sh"
# But we need to mock things first.

ROOT_DIR="$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
LIB_DIR="$ROOT_DIR/lib"

start_suite "Menu Logic"

# Test 1: Lazy Loading Structure
# ------------------------------
# We verify via grep that appropriate branches have load_module calls.
# This prevents regression where someone removes the lazy load.

MENU_FILE="$LIB_DIR/menus.sh"

# Check Option 1 (Tor) - Submenu 1 (Install Browser)
if grep -A 5 "case \$tchoice in" "$MENU_FILE" | grep -q "load_module \"installers\""; then
    echo -e "${GREEN}[PASS]${NC} Tor Browser installation loads installers module"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Tor Browser installation missing lazy load"
    ((FAILED++))
fi

# Check Option 2 (I2P) - Should load i2p_manager outside case, but NOT installers
# We check the block for Option 2
# It starts at "2)" and ends at ";;"
# We expect "load_module \"i2p_manager\""
# We expect NO "load_module \"installers\"" in the immediate block (before prompts)

# Extract the block for case 2)
# Using awk with portable regex
BLOCK_2=$(awk '/^[[:space:]]*2\)/, /;;/' "$MENU_FILE")

if echo "$BLOCK_2" | grep -q 'load_module "i2p_manager"'; then
     echo -e "${GREEN}[PASS]${NC} I2P menu loads i2p_manager"
     ((PASSED++))
else
     echo -e "${RED}[FAIL]${NC} I2P menu missing i2p_manager load"
     ((FAILED++))
fi

if echo "$BLOCK_2" | grep -q 'load_module "installers"'; then
     echo -e "${RED}[FAIL]${NC} I2P menu incorrectly loads installers module"
     ((FAILED++))
else
     echo -e "${GREEN}[PASS]${NC} I2P menu correctly avoids loading installers"
     ((PASSED++))
fi

# Test 2: DNS Labels
# ------------------
# Check that Option 1 in Network menu calls network_set_dns "dnscrypt-proxy"
# We look for the line: 1) network_set_dns "dnscrypt-proxy" ;;

if grep -q '1) network_set_dns "dnscrypt-proxy" ;;' "$MENU_FILE"; then
    echo -e "${GREEN}[PASS]${NC} Menu uses correct 'dnscrypt-proxy' argument"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Menu uses incorrect DNS argument (expected \"dnscrypt-proxy\")"
    ((FAILED++))
fi

if grep -q 'echo "1) DNSCrypt Proxy (Localhost)' "$MENU_FILE"; then
    echo -e "${GREEN}[PASS]${NC} Menu uses correct DNSCrypt label"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Menu uses incorrect DNS label"
    ((FAILED++))
fi

end_suite
