# Tor Browser Installation & Configuration

## Installation
The `install-tor` command automates the secure installation of the official Tor Browser:
1. **Fetches**: Detects and downloads the latest release from `torproject.org`.
2. **Verifies GPG**: Validates the download signature using the Tor Browser Developers' PGP key (`0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290`).
3. **Installs**: Copies the application to `/Applications`.
4. **Verifies Integrity**: checks the macOS code signature (Apple Developer ID `MADPSAYN6T`).

## Obfuscation (Pluggable Transports)
To hide your Tor traffic from your ISP or local network administrator, you should use **Pluggable Transports** (Bridges).

### Configuring Bridges in Tor Browser
Since the Tor Browser manages its own Tor instance, bridges must be configured within the application settings, not via external config files.

1.  Open **Tor Browser**.
2.  Go to **Settings** -> **Connection**.
3.  Under the "Bridges" section:
    *   **Option A**: Click "Choose a Bridge" to use a built-in bridge (e.g., `obfs4`).
    *   **Option B**: Click "Request a Bridge" to fetch a new bridge from Tor Project.
    *   **Option C**: Click "Add a Bridge Manually" if you have obtained a private bridge line.

### Obtaining Bridges
*   **Web**: Visit [bridges.torproject.org](https://bridges.torproject.org/)
*   **Email**: Send an email to `bridges@torproject.org` from a Gmail or Riseup address.

### Use Cases
*   **obfs4**: Makes Tor traffic look like random unencrypted TCP data. Good for general censorship circumvention.
*   **meek-azure**: Makes Tor traffic look like it is connecting to a Microsoft service. Good for heavy censorship.
*   **Snowflake**: Uses WebRTC ephemeral proxies.

## Security Notes
*   **Do not modify** the `torrc` file inside the bundle manually unless you know exactly what you are doing.
*   **Do not install** extensions. Tor Browser is carefully configured; adding extensions increases your fingerprint.
