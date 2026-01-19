# Privoxy Documentation

## What is Privoxy?
Privoxy is a non-caching web proxy with advanced filtering capabilities for enhancing privacy, modifying web page data and HTTP headers, controlling access, and removing ads and other obnoxious Internet junk.

## Configuration
Our configuration (`config/privoxy/config`) is designed for **Minimal Privacy**.

### Key Settings
- **Listen Address**: `127.0.0.1:8118` (Localhost only)
- **Toggle**: Enabled (can be disabled via web interface if configured)
- **Actions**:
  - `match-all.action`: Global defaults.
  - `default.action`: Standard filtering rules.

### Setup
The script `scripts/setup_privoxy.sh` (or `install-privoxy` command):
1.  Installs Privoxy via Homebrew.
2.  Copies `config` and **all** `*.action` and `*.filter` files from `config/privoxy/` to the installation directory. This allows you to easily add custom rules by simply dropping files into the config folder.
3.  Starts the Privoxy service.

### Browser Configuration
For Privoxy to work, you must configure your browser or system to use it as an HTTP/HTTPS proxy.

**Firefox Settings:**
1.  Go to Settings -> General -> Network Settings.
2.  Select "Manual proxy configuration".
3.  **HTTP Proxy**: `127.0.0.1` **Port**: `8118`
4.  Check "Also use this proxy for HTTPS".

## Advanced: Ad Blocking
Privoxy can be used as a powerful adblocker. You can download and update action files from community projects like [privoxy-blocklist](https://github.com/aminvakil/privoxy-blocklist) to block thousands of ad domains at the proxy level.
