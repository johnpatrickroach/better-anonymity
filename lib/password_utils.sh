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
    
    # Count total lines efficiently
    local total_lines
    total_lines=$(wc -l < "$WORDLIST_PATH" | tr -d ' ')
    
    if [ "$total_lines" -eq 0 ]; then
        error "Wordlist is empty."
        return 1
    fi
    
    for (( i=0; i<num_words; i++ )); do
        # Get random line number (1 to total_lines)
        local rand_line
        
        # Generate 4 random bytes for a large integer space
        if command -v openssl >/dev/null 2>&1; then
             local hex
             hex=$(openssl rand -hex 4)
             # modulo arithmetic to get range 0..(total_lines-1), then +1
             rand_line=$(( (0x$hex % total_lines) + 1 ))
        else
             # Fallback
             local rand_int
             rand_int=$(od -An -N4 -tu4 /dev/urandom | awk '{print $1}')
             rand_line=$(( (rand_int % total_lines) + 1 ))
        fi
        
        # Extract specific line using head/tail (more robust than sed in some envs)
        # Use read to parse the line
        local raw_line
        raw_line=$(head -n "$rand_line" "$WORDLIST_PATH" | tail -n 1)
        
        local selected_word=""
        if [ -n "$raw_line" ]; then
            # Ensure standard IFS for splitting
            IFS=$' \t\n' read -r _ selected_word <<< "$raw_line"
        fi
        
        if [ -z "$selected_word" ]; then
             # Should practically never happen if wc -l is correct and file isn't changing
             # Safety break to prevent infinite loops
             local attempts=${attempts:-0}
             ((attempts++))
             if [ "$attempts" -gt 100 ]; then
                 error "Failed to extract words from wordlist after 100 attempts."
                 return 1
             fi
             
             i=$((i-1)) # Retry
             continue
        fi

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

        # Check for repeated words (low entropy)
        # We generally expect all words to be unique in a short passphrase
        local unique_count
        unique_count=$(echo "$pwd" | tr ' ' '\n' | sort | uniq | wc -l | xargs)
        
        if [ "$unique_count" -lt "$word_count" ]; then
            ((score-=2))
            warn "Passphrase contains repeated words. This reduces security significantly."
        fi
        
        # Note: This is detailed heuristic scoring, not a rigorous entropy calculation.
        # A true 4-word diceware phrase from a 7776-word list has ~51 bits of entropy.
        # This check ensures we don't accidentally rate "correct correct correct correct" as strong.
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
