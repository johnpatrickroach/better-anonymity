# better-anonymity
## MacOS Security, Privacy & Anonymity Tools

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

## Installation

First, clone the repository:

```bash
git clone https://github.com/phaedrus/better-anonymity.git
cd better-anonymity
```

Then choose your preferred installation method:

### Option 1: Homebrew (Recommended)

Install using the local formula:

```bash
brew install --HEAD ./Formula/better-anonymity.rb
```

### Option 2: Pip (Python)

If you have Python 3 installed, you can install directly:

```bash
pip install .
```

This will verify dependencies and install the `better-anonymity` (and `b-a`) commands to your Python bin path.
*Note: Ensure your Python bin directory is in your PATH.*

### Option 3: Manual Install

If you don't use Homebrew or Pip, manually install the global aliases:

```bash
./bin/better-anonymity install
```

This will create symlinks in `/usr/local/bin`, allowing you to run the tool from anywhere using any of the following aliases:

*   `better-anonymity`
*   `better-anon`
*   `b-a`

## Usage

Interactive Menu:
```bash
better-anonymity
# OR
better-anon
# OR
b-a
```

### Commands

- **Diagnosis & Scoring**: Check your system's privacy score.
  ```bash
  b-a diagnose
  ```

- **Hardening**: Apply macOS security settings.
  ```bash
  b-a harden
  ```

- **Anonymity Tools**: Install and manage tools.
  ```bash
  b-a install tor
  b-a dns quad9
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
