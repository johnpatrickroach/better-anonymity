# MacOS Security, Privacy & Anonymity Tools

This repository contains scripts and configuration files to automate the hardening of MacOS (Intel and Apple Silicon). It aims to enhance security, privacy, and anonymity by applying best practices inspired by the [drduh/macOS-Security-and-Privacy-Guide](https://github.com/drduh/macOS-Security-and-Privacy-Guide).

## Disclaimer

**USE AT YOUR OWN RISK.**

These scripts modify system settings, network configurations, and application preferences. While every effort has been made to ensure safety, applying these settings may break functionality (e.g., Handoff, AirDrop, certain iCloud features). 

*   **Always backup your data before running these scripts.**
*   Review the scripts before execution to understand what changes will be applied.
*   It is recommended to test in a Virtual Machine first.

## Features

- **OS Hardening**: Disables telemetry, enables firewall, configures secure boot requirements.
- **Network Privacy**: DNS configuration, Privoxy setup for local proxying.
- **Browser Hardening**: `user.js` for Firefox privacy.
- **Anonymity**: Scripts to assist with Tor configuration.

## Usage
The easiest way to get started is to use the interactive CLI:

```bash
./bin/better-anonymity
```

Or run specific commands directly:

```bash
./bin/better-anonymity harden
./bin/better-anonymity dns mullvad
./bin/better-anonymity install tor
```

### Documentation
For detailed information on each module, please refer to the specific documentation:

- **[OS Hardening](docs/OS_HARDENING.md)**: Firewall, Analytics, Spotlight, Screen Saver.
- **[Network Privacy](docs/NETWORK.md)**: DNS configuration and Wi-Fi hygiene.
- **[Privoxy](docs/PRIVOXY.md)**: Local proxy for adblocking and privacy.
- **[Tor](docs/TOR.md)**: Anonymity network configuration.
- **[Firefox Hardening](docs/BROWSER.md)**: `user.js` configuration.
- **[GPG](docs/GPG.md)**: Strong cryptography settings.
- **[Password Generator](docs/PASSWORD.md)**: Strong passphrase generation.

## License

MIT
