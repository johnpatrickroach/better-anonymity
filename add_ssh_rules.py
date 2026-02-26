import json
import sys
sys.path.append('venv/lib/python3.11/site-packages')
import hjson

new_rules = [
    {
        "description": "better-anonymity: SSH Root Login is disabled (/etc/ssh/sshd_config).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config 2>/dev/null && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo sed -i '' 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config"
        }
    },
    {
        "description": "better-anonymity: SSH Password Authentication is disabled (/etc/ssh/sshd_config).",
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": "grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config 2>/dev/null && echo 1 || echo 0",
                "command_pass": "1",
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "sudo_command": "sudo sed -i '' 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config"
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

print(f"Injected {len(new_rules)} custom SSH rules.")
