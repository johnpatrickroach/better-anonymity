import json
import sys
sys.path.append('venv/lib/python3.11/site-packages')
import hjson

new_rules = [
    {
        "description": "better-anonymity: DialogType in com.apple.CrashReporter is none",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "defaults read com.apple.CrashReporter 'DialogType' 2>/dev/null",
                "command_pass": "none",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "command": "defaults write com.apple.CrashReporter DialogType -string none"
        }
    },
    {
        "description": "better-anonymity: NSStatusItem Visible Siri in com.apple.systemuiserver is 0",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "defaults read com.apple.systemuiserver 'NSStatusItem Visible Siri' 2>/dev/null",
                "command_pass": "0",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "command": "defaults write com.apple.systemuiserver 'NSStatusItem Visible Siri' -int 0"
        }
    },
    {
        "description": "better-anonymity: checkInterval in com.google.Keystone.Agent is 0",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "defaults read com.google.Keystone.Agent 'checkInterval' 2>/dev/null",
                "command_pass": "0",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "command": "defaults write com.google.Keystone.Agent checkInterval -int 0"
        }
    }
]

with open("config/example.osx-config.json", "r") as f:
    existing = json.load(f)

for r in new_rules:
    if not any(e["description"] == r["description"] for e in existing):
        existing.append(r)

with open("config/example.osx-config.json", "w") as f:
    json.dump(existing, f, indent=4)

with open("config/example.osx-config.hjson", "r") as f:
    existing_h = hjson.load(f)

for r in new_rules:
    if not any(e["description"] == r["description"] for e in existing_h):
        existing_h.append(r)

with open("config/example.osx-config.hjson", "w") as f:
    hjson.dump(existing_h, f)

print(f"Injected {len(new_rules)} custom defaults rules.")
