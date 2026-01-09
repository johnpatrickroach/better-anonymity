#!/bin/bash
echo "Debugging Airport Path..."
echo "Checking legacy path:"
ls -l "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport" 2>/dev/null || echo "Legacy Not Found"

echo "Checking new path:"
ls -l "/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport" 2>/dev/null || echo "New Path Not Found"

echo "Listing Resources dir:"
ls -F "/System/Library/PrivateFrameworks/Apple80211.framework/Resources/" 2>/dev/null | head -n 10
