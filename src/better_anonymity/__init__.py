# src/better_anonymity/__init__.py
import os
import subprocess
import sys
from pathlib import Path

def main():
    # The script is stored inside the package under bin/
    entry = Path(__file__).resolve().parent / "bin" / "better-anonymity"
    # If we are running from a source checkout (no installed bin script),
    # fall back to the repository root.
    if not entry.is_file():
        repo_root = Path(__file__).resolve().parents[2]
        entry = repo_root / "bin" / "better-anonymity"
    sys.exit(subprocess.call([str(entry)] + sys.argv[1:]))


if __name__ == "__main__":
    main()
__version__ = "1.0.4"
