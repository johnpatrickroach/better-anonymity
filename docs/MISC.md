# Miscellaneous Hardening & Privacy

This module includes various hardening checks and privacy enhancements that don't fit into specific categories like Network or SSH.

## Features

### 1. Hardening
- **Finder**:
    - Show all file extensions (prevents trojan spoofing like `doc.pdf.exe`).
    - Show hidden files (reveals hidden directories like `.git`, `.ssh`).
    - Disable extension change warning.
    - Unhide `~/Library`.
- **Bonjour**: Disables multicast advertisements (`mDNSResponder`) to prevent local network discovery (AirPlay target, Printer sharing, etc.).
- **Sudoers**: Audits `/etc/sudoers` for the dangerous `env_keep += "HOME MAIL"` configuration (CVE-2019-14287 related).
- **Umask**: Sets system umask to `077` (only user read/write) for new files.
- **Guest User**: Completely removes Guest accounts.
- **Captive Portal**: Disables connection attempts to Apple servers on Wi-Fi connect.

### 2. Privacy Tweaks
- **Spotlight**: Disables indexing entirely (Aggressive option) or restricts categories.
- **AirDrop**: Disables AirDrop discovery.
- **Dock**: Hides recent apps.
- **Telemetry**:
    - Disables **Microsoft Office** and **AutoUpdate** telemetry.
    - Disables **Google Update** checks.
    - Disables **.NET** and **PowerShell** telemetry variables.
    - Disables **Apple** AdLib and Remote Events.

### 3. TCC System Reset
- **reset-tcc**: Resets ALL privacy permissions (Camera, Microphone, Screen Recording, etc.) for ALL apps.
- **Use case**: Cleaning up a system before "starting fresh" without a reinstall.

## Usage

```bash
# Run all misc checks (interactive)
better-anonymity misc-harden

# Run via main menu
better-anonymity menu -> 23. Misc Hardening
```

## Warnings
- **Bonjour**: Disabling this breaks AirDrop, AirPlay, and Printer Discovery.
- **Umask**: `077` is very strict. Some shared folders might break.
- **Spotlight**: Disabling indexing breaks `cmd+space` search for files (apps usually still work).
- **TCC Reset**: You will be re-prompted for permissions by every app (Terminal, Zoom, Teams, etc.).
