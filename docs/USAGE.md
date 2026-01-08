# Usage Guide
## Getting Started

First, install the global CLI aliases for ease of use:

```bash
./bin/better-anonymity install
```

You can now use any of the following commands:
*   `better-anonymity`
*   `better-anon`
*   `b-a`

## Quick Start
Run the setup wizard to apply a security baseline:
```bash
b-a setup
```

## Interactive Mode
Simply run the command without arguments to start the menu:
```bash
b-a
```

## Command Reference

### System Diagnosis
Check your system's current security, privacy, and anonymity score.
```bash
b-a diagnose
```

### OS Hardening
Apply macOS security settings (Firewall, Analytics, etc).
```bash
b-a harden
```
- **Note**: This may require sudo credentials.

### System Cleanup
Perform aggressive cleanup of metadata, logs, and browser history.
```bash
b-a cleanup
```
- **Covers**: QuickLook, Finder, Browsers (Chrome/Safari), Quarantine Events, Memory.

### Network & DNS
Configure encrypted DNS providers.
```bash
b-a dns localhost   # Set DNS to Localhost (127.0.0.1) [Recommended if running DNSCrypt/Tor]
b-a dns quad9       # Set DNS to Quad9 (9.9.9.9)
b-a dns mullvad     # Set DNS to Mullvad
b-a dns cloudflare  # Set DNS to Cloudflare
```

### Tool Installation
Install and manage privacy tools via Homebrew.
```bash
b-a install tor      # Install Tor & Torsocks
b-a install i2p      # Install I2P
b-a install gpg      # Install GPG & Pinentry
b-a install signal   # Install Signal Desktop
```

### Global Config
Update the tool or run daily checks.
```bash
b-a update           # Git pull latest version
b-a check-update     # Check for updates
b-a daily            # Run daily health checks
b-a uninstall        # Remove CLI aliases
```

## Browser Hardening
The file `config/firefox/user.js` contains settings to harden Firefox.
1. Locate your Firefox profile folder (usually in `~/Library/Application Support/Firefox/Profiles/xxxx.default`).
2. Copy `config/firefox/user.js` to that folder.
3. Restart Firefox.

## Backup & Recovery
Always backup your data before running these scripts. While many settings can be reversed via System Preferences, some `defaults write` commands may require manual reversion.
