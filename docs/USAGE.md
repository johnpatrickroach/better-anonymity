# Usage Guide

## Getting Started

The easiest way to use this repository is through the master setup script:

```bash
./setup.sh
```

This interactive script will guide you through the various hardening and configuration options.

## Individual Modules

### OS Hardening (`scripts/macos_hardening.sh`)
This script modifies macOS system preferences to enhance security and privacy.
- **Firewall**: Enables the application firewall and stealth mode.
- **Analytics**: Disables sending diagnostic data to Apple.
- **Spotlight**: Prevents search terms from being sent to Apple.
- **Finder**: Shows file extensions and secures the screen saver.

Usage:
```bash
sudo ./scripts/macos_hardening.sh --all
```

### Network Privacy (`scripts/network_setup.sh`)
Configures your DNS settings to use privacy-respecting providers.
Supported providers: `quad9`, `mullvad`, `cloudflare`.

Usage:
```bash
sudo ./scripts/network_setup.sh mullvad
```

### Privoxy (`scripts/setup_privoxy.sh`)
Installs Privoxy via Homebrew and applies a configuration that blocks ads and tracking.
The proxy runs on `127.0.0.1:8118`. You will need to configure your system or browser to use this proxy.

### Tor (`scripts/setup_tor.sh`)
Installs and configures Tor. It exposes a SOCKS5 proxy on `127.0.0.1:9050`.

### GPG (`scripts/setup_gpg.sh`)
Installs GnuPG and `pinentry-mac`. It configures `gpg.conf` with strong algorithms (AES256, SHA512) and enables the gpg-agent.

## Browser Hardening
The file `config/firefox/user.js` contains settings to harden Firefox.
1. Locate your Firefox profile folder (usually in `~/Library/Application Support/Firefox/Profiles/xxxx.default`).
2. Copy `config/firefox/user.js` to that folder.
3. Restart Firefox.

## Backup & Recovery
Always backup your data before running these scripts. While many settings can be reversed via System Preferences, some `defaults write` commands may require manual reversion.
