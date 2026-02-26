import re, json

with open("found_defaults.txt", "r") as f:
    lines = f.readlines()

new_tests = []
for line in lines:
    line = line.strip()
    # e.g. execute_sudo "Disable Guest Login" defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false
    # or defaults write com.apple.Siri 'StatusMenuVisible' -bool false
    
    # regex to match: defaults (?:-currentHost )?write (.+?) (.+?) -(bool|int|string) (.+)
    m = re.search(r'defaults (?:-currentHost )?write\s+([^\s]+)\s+([^\s]+|"[^"]+"|' + r"'[^']+')" + r'\s+-(bool|int|string|dict|dict-add)\s+(.+)', line)
    if not m:
        continue
    
    domain, key, typ, val = m.groups()
    domain = domain.strip('"\'')
    key = key.strip('"\'')
    val = val.strip('"\'').split()[0] # basic
    
    # We want to form a check for this.
    # command: defaults (?:-currentHost )?read {domain} {key}
    read_cmd = f"defaults read {domain} '{key}' 2>/dev/null"
    
    if typ == "bool":
        if val.lower() in ("false", "no", "0"):
            expected = "0"
        else:
            expected = "1"
    else:
        expected = val
        
    desc = f"better-anonymity baseline: {key} in {domain} is {expected}"
    
    test_obj = {
        "description": desc,
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": read_cmd,
                "command_pass": expected,
                "case_sensitive": "false"
            }
        ],
        "fix": {
            "command": line.replace("execute_sudo ", "").split("defaults write")[0] + "defaults write " + line.split("defaults write")[1]
        }
    }
    
    new_tests.append(test_obj)

print(f"Generated {len(new_tests)} new tests.")
