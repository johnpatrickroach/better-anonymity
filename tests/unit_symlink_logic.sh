#!/bin/bash
# tests/verify_symlink_logic.sh

source "$(dirname "$0")/test_framework.sh"

# Create a dummy structure to simulate the symlink environment
mkdir -p tmp/bin tmp/lib
echo "#!/bin/bash" > tmp/bin/target_script
echo "SOURCE=\"\${BASH_SOURCE[0]}\"" >> tmp/bin/target_script
echo "while [ -h \"\$SOURCE\" ]; do" >> tmp/bin/target_script
echo "    DIR=\"\$( cd -P \"\$( dirname \"\$SOURCE\" )\" >/dev/null 2>&1 && pwd )\"" >> tmp/bin/target_script
echo "    SOURCE=\"\$(readlink \"\$SOURCE\")\"" >> tmp/bin/target_script
echo "    [[ \$SOURCE != /* ]] && SOURCE=\"\$DIR/\$SOURCE\"" >> tmp/bin/target_script
echo "done" >> tmp/bin/target_script
echo "DIR=\"\$( cd -P \"\$( dirname \"\$SOURCE\" )\" >/dev/null 2>&1 && pwd )\"" >> tmp/bin/target_script
echo "echo \"Resolved DIR: \$DIR\"" >> tmp/bin/target_script
chmod +x tmp/bin/target_script

# Create a symlink
ln -sf "$(pwd)/tmp/bin/target_script" tmp/symlink_script

# Run the symlink
OUTPUT=$(./tmp/symlink_script)
EXPECTED="$(pwd)/tmp/bin"

if [[ "$OUTPUT" == *"$EXPECTED"* ]]; then
    pass "Symlink resolved correctly to $EXPECTED"
else
    fail "Symlink resolution failed. Got: $OUTPUT"
    exit 1
fi

# Cleanup
rm -rf tmp
