import re

# Read all shell scripts to find `defaults write` commands
import glob

defaults_cmds = []
for file in glob.glob('lib/*.sh'):
    with open(file, 'r') as f:
        for line in f:
            if 'defaults write' in line or 'defaults -currentHost write' in line:
                defaults_cmds.append(line.strip())

with open("found_defaults.txt", "w") as f:
    for c in defaults_cmds:
        f.write(c + "\n")

print(f"Found {len(defaults_cmds)} defaults write commands.")
