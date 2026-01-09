#!/bin/bash
SOCKETFILTERFW_CMD="/usr/libexec/ApplicationFirewall/socketfilterfw"

echo "CMD: $SOCKETFILTERFW_CMD --getstealthmode"
OUTPUT=$("$SOCKETFILTERFW_CMD" --getstealthmode)
echo "OUTPUT: '$OUTPUT'"

if echo "$OUTPUT" | grep -q "enabled"; then
    echo "RESULT: DETECTED (grep enabled)"
else
    echo "RESULT: NOT DETECTED (grep enabled failed)"
fi 

if echo "$OUTPUT" | grep -q "Stealth mode enabled"; then
    echo "RESULT: DETECTED (grep Stealth mode enabled)"
fi
