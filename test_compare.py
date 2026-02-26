import re
import json

# Read our found defaults
with open("found_defaults.txt", "r") as f:
    defaults_lines = f.readlines()

new_configs = []
for line in defaults_lines:
    line = line.strip()
    # Simple regex to extract domain, key, type, value
    # e.g., defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0
    match = re.search(r'defaults(?:\s+-currentHost)?\s+write\s+(?:"([^"]+)"|\'([^\']+)\'|([^\s]+))\s+(?:"([^"]+)"|\'([^\']+)\'|([^\s]+))\s+-(bool|string|int|dict|dict-add)\s+(.*)', line)
    
    if not match:
        continue
        
    domain = match.group(1) or match.group(2) or match.group(3)
    key = match.group(4) or match.group(5) or match.group(6)
    rtype = match.group(7)
    rval = match.group(8)

    # Clean rval
    rval = rval.split()[0].strip('"\'')
    if rtype == "bool":
        if rval.lower() in ("false", "no", "0"):
            parsed_val = "0"
        else:
            parsed_val = "1"
    else:
        parsed_val = rval
    
    # Let's map this logic out
    new_configs.append({
        "line": line,
        "domain": domain,
        "key": key,
        "type": rtype,
        "val": parsed_val
    })

print(f"Parsed {len(new_configs)} configs from our script.")

# Now let's try to match them with the json rules
with open("config/example.osx-config.json", "r") as f:
    osx_config = json.load(f)

print(f"Loaded {len(osx_config)} rules from osx_config.")

overlap = 0

for rule in osx_config:
    # check if 'tests' has a domain/key we modify
    if "tests" not in rule: continue
    
    # let's just do a naive keyword search
    for test in rule["tests"]:
        cmd = test.get("command", "")
        for conf in new_configs:
            domain_name = conf["domain"].split("/")[-1].replace(".plist", "")
            if domain_name in cmd and conf["key"] in cmd:
                # We have an overlap!
                print(f"Overlap found! Rule: {rule['description']}")
                print(f"  test command: {cmd}")
                print(f"  osx-config expects: {test.get('command_pass', 'N/A')}")
                print(f"  our script sets: {conf['val']}")
                print("-" * 40)
                overlap += 1
                break

print(f"Total overlaps found: {overlap}")
