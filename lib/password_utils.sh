#!/bin/bash

# lib/password_utils.sh
# Password generation and strength checking utilities

# Path to wordlist
WORDLIST_PATH="$(dirname "${BASH_SOURCE[0]}")/../config/eff_short_wordlist.txt"

# Generate a diceware-style password
# Usage: generate_password [num_words]
generate_password() {
    local num_words=${1:-4}
    local password=""
    
    if [ ! -f "$WORDLIST_PATH" ]; then
        error "Wordlist not found at $WORDLIST_PATH"
        return 1
    fi
    
    # Check if wordlist has content
    if [ ! -s "$WORDLIST_PATH" ]; then
         error "Wordlist is empty."
         return 1
    fi
    
    local mapfile_available=false
    if type mapfile >/dev/null 2>&1 || type readarray >/dev/null 2>&1; then
        mapfile_available=true
    fi

    local words=()
    # Read words into array. The EFF list format is usually "11111   abacus"
    # We strip the numbers
    while read -r line; do
        # Extract the second column (the word)
        word=$(echo "$line" | awk '{print $2}')
        if [[ -n "$word" ]]; then
            words+=("$word")
        fi
    done < "$WORDLIST_PATH"
    
    local count=${#words[@]}
    if [ "$count" -eq 0 ]; then
        error "No words parsed from wordlist."
        return 1
    fi
    
    for (( i=0; i<num_words; i++ )); do
        # Get random index
        local rand_idx=$(( RANDOM % count ))
        local selected_word="${words[$rand_idx]}"
        
        # Capitalize first letter? The prompt says "without a hint" but usually capitalization helps strength slightly
        # For simplicity and diceware purity, we often just use lower case separate by spaces or dashes.
        # EFF recommends spaces. Let's use spaces.
        if [ -z "$password" ]; then
            password="$selected_word"
        else
            password="$password $selected_word"
        fi
    done
    
    echo "$password"
}

# Check password strength
# Usage: check_strength "password"
check_strength() {
    local pwd="$1"
    local length=${#pwd}
    local score=0
    
    # 1. Length Check
    if [ "$length" -ge 12 ]; then
        ((score+=2))
    elif [ "$length" -ge 8 ]; then
        ((score+=1))
    fi
    
    # 2. Complexity Checks (basic) - Diceware phrases might fail these but length makes up for it.
    # We should detect if it looks like a passphrase (spaces)
    if [[ "$pwd" == *" "* ]]; then
        # It's a passphrase.
        local word_count
        word_count=$(echo "$pwd" | wc -w | xargs)
        if [ "$word_count" -ge 6 ]; then
             ((score+=4)) # Very Strong
        elif [ "$word_count" -ge 5 ]; then
             ((score+=3)) # Strong
        elif [ "$word_count" -ge 4 ]; then
             ((score+=2)) # Moderate
        else
             ((score+=1)) # Weakish passphrase
        fi
    else
        # Normal password complexity
        if [[ "$pwd" =~ [A-Z] ]]; then ((score++)); fi
        if [[ "$pwd" =~ [0-9] ]]; then ((score++)); fi
        if [[ "$pwd" =~ [^a-zA-Z0-9] ]]; then ((score++)); fi
    fi
    
    echo "Password Strength Analysis:"
    echo "Length: $length characters"
    
    if [ $score -ge 5 ]; then
        echo -e "Rating: ${GREEN}Excellent${NC}"
    elif [ $score -ge 3 ]; then
         echo -e "Rating: ${GREEN}Strong${NC}"
    elif [ $score -ge 2 ]; then
         echo -e "Rating: ${YELLOW}Moderate${NC}"
    else
         echo -e "Rating: ${RED}Weak${NC}"
    fi
    
    echo "Tip: Use effective diceware passphrases (4+ random words) for high security and memorability."
}
