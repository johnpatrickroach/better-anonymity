import json
with open("config/example.osx-config.json", "r") as f:
    data = json.load(f)
    
for rule in data:
    desc = rule.get("description", "").lower()
    if any(k in desc for k in ["firewall", "filevault", "gatekeeper", "ipv6", "printer", "cupsctl"]):
        print(rule["description"])
