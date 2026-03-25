# better-anonymity

## MacOS Security, Privacy & Anonymity Tools

This repository contains scripts and configuration files to automate the hardening of MacOS (Intel and Apple Silicon). It aims to enhance security, privacy, and anonymity by applying best practices inspired by the [drduh/macOS-Security-and-Privacy-Guide](https://github.com/drduh/macOS-Security-and-Privacy-Guide) and [privacy.sexy](https://privacy.sexy).

### Credits & Influences

A significant portion of the aggressive privacy tuning and "Privacy Over Security" configurations found within this toolkit's macOS hardening logic is directly influenced by and adapted from the excellent work over at **[privacy.sexy](https://github.com/undergroundwires/privacy.sexy)** by undergroundwires. We highly recommend checking out their project for comprehensive cross-platform privacy scripts.

### Command Aliases

When you run `better-anonymity install` (or "Install CLI Aliases"), the following shortcuts are added to your shell (`~/.zshrc`):

| Alias | Equivalent Command | Description |
| :--- | :--- | :--- |
| `torify` | `export ALL_PROXY=...` | Enables Tor SOCKS5 proxy for current shell session |
| `untorify` | `unset ALL_PROXY` | Disables Tor proxy for current shell session |
| `tor-run <cmd>` | `env ALL_PROXY=... <cmd>` | Runs a single command through Tor (e.g., `tor-run curl ifconfig.me`) |
| `stay-connected` | `b-a captive monitor` | Monitoring tool for flaky Wi-Fi / Captive Portals |
| `i2pify` | `export http_proxy=...` | Enables I2P HTTP proxy for current shell session |

## Disclaimer

**USE AT YOUR OWN RISK.**

These scripts modify system settings, network configurations, and application preferences. While every effort has been made to ensure safety, applying these settings may break functionality (e.g., Handoff, AirDrop, certain iCloud features).

* **Always backup your data before running these scripts.**
* Review the scripts before execution to understand what changes will be applied.
* It is recommended to test in a Virtual Machine first.

## Features

* **OS Hardening**: Disables telemetry, enables firewall, configures secure boot requirements.
* **Network Privacy**: DNS configuration, Privoxy setup for local proxying, MAC Spoofing.
* **Browser Hardening**: `user.js` for Firefox privacy.
* **Anonymity**: Scripts to assist with Tor configuration and I2P installation.
* **UX**: Automatic Sudo Keep-Alive to minimize password prompts during setup.

## Installation

Choose your preferred installation method:

### Option 1: Homebrew (Recommended)

Install directly using our custom Homebrew tap:

```bash
brew tap johnpatrickroach/better-anonymity
brew install better-anonymity
```

### Option 2: Pip (Python)

You can install the highly accessible Python wrapper directly from PyPI. This will automatically install dependencies and place the CLI in your `$PATH`.

```bash
pip install better-anonymity
```

*Note: On newer macOS versions, you might encounter an "externally-managed-environment" error. If so, we recommend using `pipx install better-anonymity`.*

### Option 3: Install from Source

If you prefer to run the raw Bash scripts or want to contribute to the codebase, clone the repository directly:

```bash
git clone https://github.com/johnpatrickroach/better-anonymity.git
cd better-anonymity
```

Then, manually install the global aliases (`b-a`):

```bash
./bin/better-anonymity install
```

## Configuration

By default, running `better-anonymity harden` will comprehensively execute every macOS privacy and security countermeasure built into the toolkit. 

However, you can surgically customize exactly which actions execute by modifying the `config/settings.json` file natively included in the repository.

```json
{
    "hardening": {
        "enable_firewall": true,
        "disable_analytics": false,
        "anonymize_hostname": true,
        "ensure_lockdown": false
    }
}
```

If you set any specific module to `false`, the hardening script will structurally bypass that component during execution without prompt. This is ideal for building tailored execution baselines that don't intrude on explicit network features you rely on.

## Quick Start (Recommended)

1. **First Run Setup**: Launch the interactive wizard to apply the security baseline.

    ```bash
    better-anonymity setup
    ```

2. **Check Your Score**: Analyze your system's current privacy/anonymity status.

    ```bash
    better-anonymity diagnose
    ```

3. **Interactive Menu**: Explore all features via the dashboard.

    ```bash
    better-anon
    ```

## Usage

You can use the interactive menu or individual commands. CLI aliases `better-anonymity`, `better-anon`, and `b-a` are interchangeable.

### Common Commands

* **Diagnosis**:

  ```bash
  b-a diagnose
  b-a --version
  ```

* **Explaining Commands**:
  Use the `--explain` flag with any command to see what it does without running it.

  ```bash
  b-a setup --explain
  b-a network-anon --explain
  ```

* **Hardening**:

  ```bash
  b-a harden    # Apply macOS hardening
  b-a ssh       # SSH Hardening menu
  ```

* **Tools**:

  ```bash
  b-a tor install
  b-a install signal
  b-a dns quad9
  b-a network-open  # Restore network defaults
  b-a network-anon  # Enable all anonymity services
  b-a captive monitor # Launch connectivity monitor
  ```

### Updates

Keep your installation current:

```bash
b-a check-update    # Check if updates are available
b-a update          # Auto-upgrades via Brew, Pip, or Git natively
b-a test            # Run unit tests
```

### Uninstallation & Restore

To remove the CLI aliases (`b-a`, `better-anon`) from your system:

```bash
better-anonymity uninstall
```

**New**: You will be prompted to:

1. **Restore System State**: Revert Hostname, DNS, and Firewall to their original values (captured during setup).
2. **Uninstall Tools**: Automatically remove tools installed by `better-anonymity` (e.g., Tor, Privoxy).
3. **Scrub Environment**: Remove the `~/.better-anonymity` cache and dynamically wipe the convenience alias blocks from your `~/.zshrc`.

*Note: Manual verification is recommended after uninstallation to ensure all desired changes are reverted.*

### Documentation

For detailed information on each module, please refer to the specific documentation:

* **[OS Hardening](docs/OS_HARDENING.md)**: Firewall, Analytics, Spotlight, Screen Saver.
* **[Network Privacy](docs/NETWORK.md)**: DNS configuration and Wi-Fi hygiene.
* **[Privoxy](docs/PRIVOXY.md)**: Local proxy for adblocking and privacy.
* **[Tor](docs/TOR.md)**: Anonymity network configuration.
* **[Firefox Hardening](docs/BROWSER.md)**: `user.js` configuration.
* **[GPG](docs/GPG.md)**: Strong cryptography settings.
* **[Password Generator](docs/PASSWORD.md)**: Strong passphrase generation.

### Shell Completions

To enable **zsh** completions (tab-autocomplete), add the following to your `.zshrc`:

```bash
# Add better-anonymity completions to fpath
echo 'fpath=(/path/to/better-anonymity/completions $fpath)' >> ~/.zshrc
echo 'autoload -Uz compinit && compinit' >> ~/.zshrc
```

## License

MIT
