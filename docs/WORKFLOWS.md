# Workflows and Usability

Better Anonymity provides streamlined commands for managing your security lifecycle.

## 1. First-Time Setup
Recommended for new users or fresh installations.

```bash
better-anonymity setup
```

The setup wizard will guide you through:
1.  **System Hardening**: Enabling Firewall, Stealth Mode, Sudoers protection, etc.
2.  **Network Privacy**: Configuring Encrypted DNS (Quad9).
3.  **Ad Blocking**: Installing StevenBlack Hosts blocklist.
4.  **Tool Installation**: Installing Tor, GPG, and Signal.

## 2. Daily Health Check
Run this command regularly (e.g., daily or weekly) to verify your security posture.

```bash
better-anonymity daily
```

This performs:
- **Security Audit**: Firewall status, FileVault, SIP, Lockdown Mode.
- **DNS Verification**: Ensures real IP isn't leaking via DNS.
- **Tor Status**: Checks if Tor service is running.
- **Blocklist Update**: Checks for hosts file updates (optional).

## 3. Self-Update
Keep the `better-anonymity` toolkit up to date.

```bash
better-anonymity update
```

This pulls the latest code from the git repository.

## 4. Advanced Workflows
For specific tasks:
- **Tor Mode**: `better-anonymity tor proxy-on` (Route traffic via Tor)
- **Wi-Fi Audit**: `better-anonymity wifi audit` (Check security of current network)
- **Metadata Cleanup**: `better-anonymity cleanup-metadata` (Sanitize logs and caches)
