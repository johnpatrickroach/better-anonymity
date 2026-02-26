import json
import sys
sys.path.append('venv/lib/python3.11/site-packages')
import hjson

new_rules = [
    {
        "description": "better-anonymity: Printer sharing is disabled (cupsctl).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "system_profiler SPPrintersDataType 2>/dev/null | grep -q 'Shared: Yes' && echo 0 || echo 1",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo cupsctl --no-share-printers --no-remote-any --no-remote-admin"
        }
    },
    {
        "description": "better-anonymity: FileVault is enabled.",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "fdesetup status | grep -q 'FileVault is On' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo fdesetup enable"
        }
    },
    {
        "description": "better-anonymity: IPv6 is disabled on all network interfaces.",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "if networksetup -listallnetworkservices | tail -n +2 | while read -r s; do networksetup -getinfo \"$s\" 2>/dev/null | grep '^IPv6:' | grep -qv 'Off' && exit 1; done; then echo 1; else echo 0; fi",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "networksetup -listallnetworkservices | tail -n +2 | while read -r s; do sudo networksetup -setv6off \"$s\"; done"
        }
    },
    {
        "description": "better-anonymity: Application Firewall is enabled via socketfilterfw.",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -q 'State = 1' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"
        }
    },
    {
        "description": "better-anonymity: Remote Apple Events are disabled (systemsetup).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "systemsetup -getremoteappleevents 2>/dev/null | grep -q 'Off' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo systemsetup -setremoteappleevents off"
        }
    },
    {
        "description": "better-anonymity: Wake on LAN is disabled (systemsetup).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "systemsetup -getwakeonnetworkaccess 2>/dev/null | grep -q 'Off' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo systemsetup -setwakeonnetworkaccess off"
        }
    },
    {
        "description": "better-anonymity: Remote Login is disabled (systemsetup).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "systemsetup -getremotelogin 2>/dev/null | grep -q 'Off' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo systemsetup -setremotelogin off"
        }
    }
]

with open("config/example.osx-config.json", "r") as f:
    existing = json.load(f)

# avoid dupes
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

print(f"Injected {len(new_rules)} custom non-default rules.")
