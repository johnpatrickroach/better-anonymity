import json
import sys
sys.path.append('venv/lib/python3.11/site-packages')
import hjson

new_rules = [
    {
        "description": "better-anonymity: com.apple.Siri.agent is disabled via launchctl.",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "launchctl print-disabled system 2>/dev/null | grep -q '\"com.apple.Siri.agent\" => disabled' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo launchctl disable system/com.apple.Siri.agent"
        }
    },
    {
        "description": "better-anonymity: com.apple.assistantd is disabled via launchctl.",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "launchctl print-disabled system 2>/dev/null | grep -q '\"com.apple.assistantd\" => disabled' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo launchctl disable system/com.apple.assistantd"
        }
    },
    {
        "description": "better-anonymity: Diagnostic Info Submission is unloaded (com.apple.SubmitDiagInfo).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "launchctl print-disabled system 2>/dev/null | grep -q '\"com.apple.SubmitDiagInfo\" => disabled' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist"
        }
    },
    {
        "description": "better-anonymity: Media Sharing is unloaded (com.apple.mediaremoted).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "launchctl print-disabled system 2>/dev/null | grep -q '\"com.apple.mediaremoted\" => disabled' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.mediaremoted.plist"
        }
    },
    {
        "description": "better-anonymity: TFTP is disabled via launchctl.",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "launchctl print-disabled system 2>/dev/null | grep -q '\"com.apple.tftpd\" => disabled' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo launchctl disable system/com.apple.tftpd"
        }
    },
    {
        "description": "better-anonymity: Telnet is disabled via launchctl.",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "launchctl print-disabled system 2>/dev/null | grep -q '\"com.apple.telnetd\" => disabled' && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo launchctl disable system/com.apple.telnetd"
        }
    },
    {
        "description": "better-anonymity: LanguageModeling directory is locked (uchg).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "if [ -d ~/Library/LanguageModeling ]; then ls -ldO ~/Library/LanguageModeling | grep -q 'uchg' && echo 1 || echo 0; else echo 1; fi",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "command": "chflags -R uchg ~/Library/LanguageModeling"
        }
    },
    {
        "description": "better-anonymity: Spelling directory is locked (uchg).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "if [ -d ~/Library/Spelling ]; then ls -ldO ~/Library/Spelling | grep -q 'uchg' && echo 1 || echo 0; else echo 1; fi",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "command": "chflags -R uchg ~/Library/Spelling"
        }
    },
    {
        "description": "better-anonymity: Suggestions directory is locked (uchg).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "if [ -d ~/Library/Suggestions ]; then ls -ldO ~/Library/Suggestions | grep -q 'uchg' && echo 1 || echo 0; else echo 1; fi",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "command": "chflags -R uchg ~/Library/Suggestions"
        }
    },
    {
        "description": "better-anonymity: Quick Look Application Support is locked (uchg).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "if [ -d ~/Library/Application\\ Support/Quick\\ Look ]; then ls -ldO ~/Library/Application\\ Support/Quick\\ Look | grep -q 'uchg' && echo 1 || echo 0; else echo 1; fi",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "command": "chflags -R uchg ~/Library/Application\\ Support/Quick\\ Look"
        }
    },
    {
        "description": "better-anonymity: Guest User Account is deleted (dscl).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "dscl . -read /Users/Guest 2>/dev/null && echo 0 || echo 1",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo dscl . -delete /Users/Guest"
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

print(f"Injected {len(new_rules)} custom operational service and flag rules.")
