# Better-Anonymity Command Reference

This document provides a comprehensive list of all commands and subcommands available in the `better-anonymity` CLI.

## Core Commands

| Command | Description |
| :--- | :--- |
| `better-anonymity menu` | Launches the interactive TUI menu (default). |
| `better-anonymity setup` | Runs the First-Time Setup Wizard interactively. |
| `better-anonymity auto` | Runs Setup in non-interactive mode (applies defaults). |
| `better-anonymity daily` | Runs daily health checks and updates blocklists. |
| `better-anonymity update` | Updates the `better-anonymity` codebase from git. |
| `better-anonymity check-update` | Checks for updates without installing. |
| `better-anonymity diagnose` | Runs a system privacy and security diagnosis score. |
| `better-anonymity test` | Runs the internal unit test suite. |
| `better-anonymity cleanup` | Clears system metadata, logs, and caches. |
| `better-anonymity uninstall` | Removes global CLI aliases. |

## Network & DNS

| Command | Subcommand / Argument | Description |
| :--- | :--- | :--- |
| `dns` | `[provider]` | Set system DNS. Providers: `dnscrypt-proxy`, `quad9`, `mullvad`, `cloudflare`, `localhost`, `default`. |
| `verify-dns` | | Checks for DNS leaks and validates DNSSEC. |
| `update-hosts` | | Updates the StevenBlack hosts file for ad-blocking. |
| `network-open` | | Restores standard network settings (disables local proxies). |
| `network-anon` | | Enables Anonymity Stack (Tor, I2P, Privoxy, DNSCrypt). |

## Tor Management

| Command | Subcommand | Description |
| :--- | :--- | :--- |
| `tor` | `start` | Start the Tor service (background). |
| | `stop` | Stop the Tor service. |
| | `restart` | Restart the service. |
| | `status` | Check running status and proxy configuration. |
| | `new-id` | Request a new circuit (Signal NEWNYM). |
| | `proxy-on` | Enable System SOCKS Proxy pointing to Tor. |
| | `proxy-off` | Disable System SOCKS Proxy. |
| | `enable-bridges` | Configure Tor Bridges (Rule-based or Custom). |
| | `disable-bridges` | Disable Tor Bridges (Direct connection). |
| | `verify-bridges` | Audit Bridge config and connectivity. |
| | `verify` | Verify Tor connection via check.torproject.org. |
| | `install` | Install Tor and verifying configuration. |

## Wi-Fi Privacy

| Command | Subcommand | Description |
| :--- | :--- | :--- |
| `wifi` | `audit` | Audits current Wi-Fi security (SSID, Encryption). |
| | `spoof-mac [new_mac]` | Spoofs MAC address. Auto-generates if argument is empty. |

## macOS Hardening

| Command | Description |
| :--- | :--- |
| `better-anonymity harden` | Runs the full hardening suite (Firewall, FileVault, Analytics, etc). |
| `better-anonymity verify-security` | Audits current security settings against baseline. |
| `better-anonymity misc-harden` | Applies miscellaneous tweaks (Finder, Sudoers, Guest Account). |
| `better-anonymity ssh audit-sshd` | Checks SSH Server configuration goodness. |
| `better-anonymity ssh harden-sshd` | Hardens SSH Server config. |
| `better-anonymity ssh harden-client` | Hardens SSH Client config. |
| `better-anonymity ssh hash-hosts` | Hashes `known_hosts` file. |

## Tool Installers

**Usage:** `better-anonymity install <tool>`

| Tool | Description |
| :--- | :--- |
| `firefox` | Installs Firefox Browser. |
| `tor-browser` | Installs Tor Browser Bundle. |
| `gpg` | Installs GnuPG. |
| `signal` | Installs Signal Messenger. |
| `session` | Installs Session Messenger. |
| `telegram` | Installs Telegram Desktop. |
| `keepassxc` | Installs KeePassXC Password Manager. |
| `onionshare` | Installs OnionShare. |
| `tor` | Installs Tor Service. |
| `i2p` | Installs I2P Router. |
| `privoxy` | Installs Privoxy. |
| `dnscrypt` | Installs DNSCrypt-Proxy. |
| `unbound` | Installs Unbound DNS Resolver. |
| `pingbar` | Installs PingBar menu bar tool. |
| `firefox-extensions` | Installs privacy extensions (e.g. uBlock Origin). |

## Services & Utilities

### I2P

| Command | Subcommand | Description |
| :--- | :--- | :--- |
| `i2p` | `start` | Start I2P Router. |
| `i2p` | `stop` | Stop I2P Router. |
| `i2p` | `restart` | Restart I2P Router. |
| `i2p` | `console` | Open I2P Router Console in browser. |
| `i2p` | `status` | Check status. |

### Captive Portal

| Command | Subcommand | Description |
| :--- | :--- | :--- |
| `captive` | `start` | Start monitor service in background. |
| `captive` | `stop` | Stop monitor service. |
| `captive` | `monitor` | Launch monitor in new terminal window (interactive). |
| `captive` | `status` | Check service status. |

### Vault & Backup

| Command | Subcommand | Description |
| :--- | :--- | :--- |
| `vault` | `write <key>` | Save a secret to the vault. |
| | `read <key>` | Retrieve a secret. |
| | `list` | List stored keys. |
| `backup` | `encrypt <src>` | Encrypt a directory to `.tar.gpg`. |
| | `decrypt <file>` | Decrypt a backup file. |
| | `volume <name> <size>` | Create an encrypted sparse bundle volume. |
| | `audit-tm` | Audit Time Machine encryption status. |

### Utilities

| Command | Description |
| :--- | :--- |
| `better-anonymity generate-password [len]` | Generates a high-entropy password (default len 6 words/chars depending on logic). |
