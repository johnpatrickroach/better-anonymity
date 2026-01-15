# I2P (Invisible Internet Project)

I2P is an anonymous network layer that allows for censorship-resistant, peer-to-peer communication. Anonymous connections are achieved by encrypting the user's traffic (by end-to-end encryption) and sending it through a volunteer-run network of roughly 55,000 computers distributed around the world.

## Installation

```bash
# Install I2P (CLI only)
better-anonymity i2p install

# Or via Menu
better-anonymity menu -> 5. Install I2P
```

## Setup & Usage

After installation, I2P runs as a background router.

### Basic Commands

```bash
# Start I2P Router
better-anonymity i2p start

# Stop I2P Router
better-anonymity i2p stop

# Check Status
better-anonymity i2p status
```

### Web Console

The I2P router is primarily managed via a web-based console hosted locally.

```bash
# Open Console
better-anonymity i2p console
```

This will open `http://127.0.0.1:7657/home` in your default browser. From there you can:
- View network status
- Configure bandwidth limits
- Access I2P sites (eepsites)
- Manage tunnels
- View I2P network graphs

## Application Configuration

Unlike Tor, I2P does not automatically proxy system traffic. You must configure individual applications to use the I2P tunnels.

### Web Browser (for .i2p sites)
To browse I2P eepsites:
1.  Open your browser's **Network Proxy** settings.
2.  Manual Proxy Configuration:
    *   **HTTP Proxy**: `127.0.0.1` Port: `4444`
    *   **HTTPS/SSL Proxy**: `127.0.0.1` Port: `4445`
3.  **No Proxy for**: `localhost, 127.0.0.1` (Required to access the console).

> [!TIP]
> Use a dedicated browser (e.g., Firefox or a separate profile) for I2P to keep your activity isolated from your regular web browsing.

### Terminal (CLI)
To route CLI tools through I2P (e.g., to curl an eepsite):
You can use the built-in alias (added to `~/.zshrc`):

```bash
i2pify
# Now tools respecting http_proxy will use I2P
curl -I http://i2p-projekt.i2p
```

Or manually:
```bash
export http_proxy=http://127.0.0.1:4444
export https_proxy=http://127.0.0.1:4445
```

## Verification

To verify I2P is working:
1. Start the router (`better-anonymity i2p start`).
2. Open the console (`better-anonymity i2p console`).
3. Check the sidebar for "Network: OK" (it may take a few minutes to bootstrap).

## Uninstall

To remove I2P:
```bash
brew uninstall i2p
```
