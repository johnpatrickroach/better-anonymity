import sys
sys.path.append('venv/lib/python3.11/site-packages')
import hjson
import json

with open("config/example.osx-config.hjson", "r") as f:
    config = hjson.load(f)

# Let's add some missing baseline configurations from better-anonymity
new_rules = [
    {
        "description": "Siri is disabled.",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "defaults read com.apple.assistant.support 'Assistant Enabled'",
                "command_pass": "0",
                "command_fail": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "command": "defaults write com.apple.assistant.support 'Assistant Enabled' -bool false"
        }
    },
    {
        "description": "Guest Login is disabled.",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled",
                "command_pass": "0",
                "command_fail": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false"
        }
    },
    {
        "description": "Firefox Telemetry is disabled.",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "defaults read /Library/Preferences/org.mozilla.firefox DisableTelemetry",
                "command_pass": "1",
                "command_fail": "0",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo defaults write /Library/Preferences/org.mozilla.firefox DisableTelemetry -bool TRUE"
        }
    }
]

for r in new_rules:
    config.append(r)

with open("config/example.osx-config.hjson", "w") as f:
    hjson.dump(config, f)

with open("config/example.osx-config.json", "w") as f:
    json.dump(config, f)

print("Successfully injected our baseline configurations.")
