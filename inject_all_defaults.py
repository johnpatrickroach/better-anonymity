import os
import re
import json
import glob
import sys

sys.path.append('venv/lib/python3.11/site-packages')
import hjson

# Get all bash lines
sh_files = glob.glob('lib/*.sh')
lines = []
for f in sh_files:
    with open(f, 'r') as file:
        lines.extend(file.readlines())

new_rules = []

def add_rule(desc, cmd_read, cmd_pass, cmd_fix, sudo_fix=False):
    rule = {
        "description": desc,
        "confidence": "recommended",
        "tests": [
            {
                "type": "exact match",
                "command": cmd_read,
                "command_pass": str(cmd_pass),
                "case_sensitive": "false"
            }
        ],
        "fix": {}
    }
    if sudo_fix:
        rule["fix"]["sudo_command"] = cmd_fix
    else:
        rule["fix"]["command"] = cmd_fix
    new_rules.append(rule)

# 1. Parse 'defaults write'
for line in lines:
    line = line.strip()
    if line.startswith('#'): continue
    if "defaults write" in line or "defaults -currentHost write" in line:
        if "$" in line: continue # skip variable-based defaults
        
        # Regex to capture defaults arguments
        m = re.search(r'defaults(?:\s+-currentHost)?\s+write\s+(?:("[^"]+"|\'[^\']+\'|[^\s]+))\s+(?:("[^"]+"|\'[^\']+\'|[^\s]+))\s+-(bool|string|int|dict|dict-add)\s+(.*)', line)
        if not m: continue
        
        domain = m.group(1).strip('"\'')
        key = m.group(2).strip('"\'')
        rtype = m.group(3)
        rval = m.group(4).split()[0].strip('"\'')
        
        if rtype == "bool":
            expected = "0" if rval.lower() in ("false", "no", "0") else "1"
        else:
            expected = rval
            
        desc = f"better-anonymity: {key} in {domain} is {expected}"
        cmd_read = f"defaults read {domain} '{key}' 2>/dev/null"
        cmd_fix = line[line.find("defaults"):]
        # Remove trailing redirection if present
        cmd_fix = cmd_fix.split(" 2>/dev/null")[0].split(" >/dev/null")[0]
        
        is_sudo = "execute_sudo" in line
        if is_sudo:
            cmd_fix = "sudo " + cmd_fix
        
        if not any(r['description'] == desc for r in new_rules):
            add_rule(desc, cmd_read, expected, cmd_fix, sudo_fix=is_sudo)

# 2. Parse systemsetup
for line in lines:
    line = line.strip()
    if line.startswith('#'): continue
    if "systemsetup -set" in line and "$" not in line:
        m = re.search(r'systemsetup -set([a-z]+) (on|off)', line, re.IGNORECASE)
        if m:
            prop = m.group(1)
            val = m.group(2).lower()
            desc = f"better-anonymity: systemsetup {prop} is {val}"
            expected = "On" if val == "on" else "Off"
            cmd_read = f"systemsetup -get{prop} 2>/dev/null | cut -d':' -f2 | tr -d ' '"
            cmd_fix = "sudo systemsetup -set" + prop + " " + val
            if not any(r['description'] == desc for r in new_rules):
                add_rule(desc, cmd_read, expected, cmd_fix, sudo_fix=True)

# 3. Parse pmset
for line in lines:
    line = line.strip()
    if line.startswith('#'): continue
    if "pmset -a" in line and "$" not in line:
        m = re.search(r'pmset -a ([a-z]+) ([0-9]+)', line)
        if m:
            prop = m.group(1)
            val = m.group(2)
            desc = f"better-anonymity: pmset {prop} is {val}"
            cmd_read = f"pmset -g custom | grep -w '{prop}' | awk '{{print $2}}' | head -n 1"
            cmd_fix = f"sudo pmset -a {prop} {val}"
            if not any(r['description'] == desc for r in new_rules):
                add_rule(desc, cmd_read, val, cmd_fix, sudo_fix=True)

# 4. Filter against existing rules
with open("config/example.osx-config.json", "r") as f:
    existing_config = json.load(f)

filtered_rules = []
for rule in new_rules:
    cmd_fix = rule["fix"].get("command", rule["fix"].get("sudo_command", ""))
    is_existing = False
    search_terms = []
    
    if "defaults" in cmd_fix:
        m = re.search(r'better-anonymity: (.+) in (.+) is', rule['description'])
        if m:
            key = m.group(1)
            domain = m.group(2).split("/")[-1].replace(".plist", "")
            search_terms = [domain, key]
    elif "systemsetup" in cmd_fix:
        m = re.search(r'systemsetup ([a-z]+) is', rule['description'])
        if m:
            search_terms = [m.group(1)]
    elif "pmset" in cmd_fix:
        m = re.search(r'pmset ([a-z]+) is', rule['description'])
        if m:
            search_terms = ["pmset", m.group(1)]
            
    for ex_rule in existing_config:
        for t in ex_rule.get("tests", []):
            cmd = t.get("command", "")
            # If our key terms are in the existing command, skip it
            if len(search_terms) > 0 and all(term in cmd for term in search_terms):
                is_existing = True
                break
        if is_existing:
            break
            
    if not is_existing:
        filtered_rules.append(rule)

print(f"Total commands parsed: {len(new_rules)}")
print(f"Existing ones filtered: {len(new_rules) - len(filtered_rules)}")
print(f"Injecting {len(filtered_rules)} NEW rules.")

# 5. Save back to files
with open("config/example.osx-config.hjson", "r") as f:
    config_hjson = hjson.load(f)

for r in filtered_rules:
    config_hjson.append(r)
    existing_config.append(r)

with open("config/example.osx-config.hjson", "w") as f:
    hjson.dump(config_hjson, f)

with open("config/example.osx-config.json", "w") as f:
    json.dump(existing_config, f, indent=4)
