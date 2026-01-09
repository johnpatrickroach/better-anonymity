#!/bin/bash
echo "DEBUG: Checking Remote Login Status..."
echo "----------------------------------------"
echo "Current User: $(whoami)"
echo "----------------------------------------"

echo "CMD: systemsetup -getremotelogin (User)"
RES_USER=$(systemsetup -getremotelogin 2>&1)
echo "OUTPUT: '$RES_USER'"

if echo "$RES_USER" | grep -i "Off"; then
    echo "Logic Check (User): DETECTED OFF"
else
    echo "Logic Check (User): DETECTED ON/ERROR"
fi
echo "----------------------------------------"

echo "CMD: sudo systemsetup -getremotelogin (Root)"
RES_ROOT=$(sudo systemsetup -getremotelogin 2>&1)
echo "OUTPUT: '$RES_ROOT'"

if echo "$RES_ROOT" | grep -i "Off"; then
    echo "Logic Check (Root): DETECTED OFF"
else
    echo "Logic Check (Root): DETECTED ON/ERROR"
fi
echo "----------------------------------------"
