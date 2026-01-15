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
        # Get random index (CSPRNG)
        local rand_idx
        if command -v openssl >/dev/null 2>&1; then
             # Use OpenSSL (standard on macOS)
             local hex
             hex=$(openssl rand -hex 4)
             rand_idx=$(( 0x$hex % count ))
        else
             # Fallback to /dev/urandom via od
             # Read 4 bytes as unsigned integer
             local rand_int
             rand_int=$(od -An -N4 -tu4 /dev/urandom | awk '{print $1}')
             rand_idx=$(( rand_int % count ))
        fi
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
        
        # Check predictability via average word length
        # Simple sentences like "I am a cat" have low avg length (2.5) vs diceware "correct horse battery staple" (~6)
        local total_chars
        # Count non-space chars
        total_chars=$(echo "$pwd" | tr -d ' ' | wc -c | xargs)
        # wc -c counts newline, so subtract 1 or rely on trimming. Bash string length is safer.
        local content_len=${#pwd}
        # Subtract spaces count roughly? simpler to just use stripped length
        local stripped="${pwd// /}"
        local stripped_len=${#stripped}
        
        # Bash doesn't do floating point, so multiply by 10
        local avg_len_x10=$(( (stripped_len * 10) / word_count ))
        
        if [ "$avg_len_x10" -lt 35 ]; then
             # Avg length < 3.5 characters
             ((score-=1))
             warn "Passphrase uses very short words. Avoid predictable sentences (e.g. 'I am a cat')."
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
