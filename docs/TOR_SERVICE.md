# Tor Service & System Proxy

This module allows you to run Tor as a background system service and optionally route your system traffic through it via SOCKS5.

## Installation

```bash
# Install Tor Service (CLI only)
better-anonymity tor install

# Or via Menu
better-anonymity menu -> 4. Install Tor Service & Browser -> 2. Install Tor Service
```

## Usage

### Managing the Service
The Tor service runs in the background using `brew services`.

```bash
# Start Tor
better-anonymity tor start

# Stop Tor
better-anonymity tor stop

# Check Status
better-anonymity tor status
# Note: If your active network interface cannot be reliably detected, 
# this command may warn you that it safely fell back to checking Wi-Fi status.
```

### System SOCKS Proxy ("Torify" System)
You can configure macOS to use Tor (127.0.0.1:9050) as the SOCKS proxy for your Wi-Fi connection.

> [!WARNING]
> This setting applies to **SOCKS-capable applications only** (e.g., Safari, Chrome, curl). Applications that ignore system proxy settings or use non-TCP protocols (UDP) may leak your real IP. Always use Tor Browser for critical anonymity.

```bash
# Enable System Proxy (requires sudo)
better-anonymity tor proxy-on

# Disable System Proxy
better-anonymity tor proxy-off
```

### Application Configuration
To maximize privacy, you can configure individual applications to use the Tor SOCKS5 proxy (`127.0.0.1:9050`).

**Terminal (CLI)**
To route command line traffic through Tor, you can use the built-in aliases (added to `~/.zshrc`):

```bash
# Enable Tor routing for current session
torify
# Check IP (should be different)
curl ifconfig.me
# Disable routing
untorify
```

Or manually:
```bash
export ALL_PROXY=socks5h://127.0.0.1:9050
```

**Messengers & Wallets**
Configure **SOCKS5** Proxy in settings (Telegram, Signal, Bitcoin, etc.):
- **Server**: `127.0.0.1`
- **Port**: `9050`
- **DNS**: Enable "Resolve queries via proxy" (sometimes called SOCKS5h) if available.

### Verification
To verify your traffic is routing through Tor:

1. Enable the System Proxy: `better-anonymity tor proxy-on`
2. Run a secure check (forces remote DNS):
   ```bash
   curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org | grep "Congratulations"
   ```
3. Visit [check.torproject.org](https://check.torproject.org) in Safari.

## Configuration
The configure file is located at:
`/usr/local/etc/tor/torrc` (Intel) or `/opt/homebrew/etc/tor/torrc` (Apple Silicon).

Default settings applied:
- `ControlPort 9051`
- `CookieAuthentication 1`
