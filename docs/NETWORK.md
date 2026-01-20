# Network Privacy Documentation

## Overview

Network privacy is the first line of defense against tracking. The `scripts/network_setup.sh` script assists in configuring your DNS settings.

## DNS Configuration

Domain Name System (DNS) is the phonebook of the internet. By default, your ISP sees every domain you request.

### Supported Providers

1. **Quad9 (`9.9.9.9`)**
    * **Focus**: Security & Privacy.
    * **Features**: Blocks known malicious domains. Does not log IP addresses.
    * **Location**: Switzerland (GDPR compliant).

2. **Mullvad (`194.242.2.2`)**
    * **Focus**: Privacy & Anti-Tracking.
    * **Features**: Blocks ads and trackers (if configured) and logs nothing.
    * **Ownership**: Mullvad VPN.

3. **Cloudflare (`1.1.1.1`)**
    * **Focus**: Speed & Privacy.
    * **Features**: Claimed not to sell data, but is a large US corporation.
    * **Location**: USA (Five Eyes).

## DNS Encryption

Standard DNS traffic is unencrypted (plaintext), allowing ISPs and network snoops to see every domain you visit. To secure this, you can use encrypted DNS protocols.

### Protocols

* **DNSCrypt**: Authenticates and encrypts DNS traffic between your client and the resolver. Prevents MITM, spoofing, and sniffing. Unique protocol, requires dedicated client (dnscrypt-proxy).
* **DNS over HTTPS (DoH)**: Encapsulates DNS queries in HTTPS traffic. Harder to block or distinguish from web traffic. Supported natively by some browsers and OSs.
* **DNS over TLS (DoT)**: Wraps DNS in TLS on a dedicated port (853). Cleaner than DoH but easier to block by firewalls.

### Using DNSCrypt-Proxy

We provide an automated installer for `dnscrypt-proxy`, a powerful local DNS proxy that supports DNSCrypt, DoH, and anonymized DNS relays.

#### DNSCrypt Installation

```bash
./bin/better-anonymity install dnscrypt
```

This installs `dnscrypt-proxy` via Homebrew and applies a custom configuration:

* **Encrypted**: Uses Quad9 (Filter) and Cloudflare.
* **Port**: Listens on `127.0.0.1:5355`.
* **Servers**: You can find more servers at [dnscrypt.info/public-servers](https://dnscrypt.info/public-servers).

#### Advanced: Blocking Non-Encrypted DNS

To prevent apps from bypassing your encrypted DNS, you can block standard DNS (port 53) using Packet Filter (`pf`).
**Warning**: This may break internet access if dnscrypt-proxy is not running or configured correctly.

Add the following to your `pf.conf`:

```pf
block drop quick on !lo0 proto udp from any to any port = 53
block drop quick on !lo0 proto tcp from any to any port = 53
```

For more information, see [What is a DNS Leak?](https://www.dnsleaktest.com/what-is-a-dns-leak.html).

### PingBar

[PingBar](https://github.com/jedisct1/pingbar) is a menu bar utility for monitoring DNS latency and controlling `dnscrypt-proxy`.

#### PingBar Installation

```bash
./bin/better-anonymity install pingbar
```

* **Method**: Builds from source (requires `swift`). The installer will ask for confirmation before downloading/compiling.
* **Features**:
  * Graphical interface for DNSCrypt stats.
  * Automatically restores your custom DNS settings after passing a captive portal.
  * Launches at login.

### Unbound & DNSSEC

[Unbound](https://nlnetlabs.nl/projects/unbound/about/) is a validating, recursive, and caching DNS resolver. We configure it to perform full DNSSEC validation.

#### Unbound Installation

```bash
./bin/better-anonymity install unbound
```

* **Method**: Installs via Homebrew, creates `_unbound` user, and configures permissions.
* **Integrity Check**: The setup now verifies that the binary, `_unbound` user, `_unbound` group, and configuration file are all present before considering Unbound installed.
* **Configuration**:
  * Copies `config/unbound/unbound.conf`.
  * Fetches DNSSEC root anchor.
  * Generates control certificates.
  * **Note**: Sets Wi-Fi DNS server to `127.0.0.1`.

#### Validation

You can run the automated verification tool to confirm your configuration:

```bash
./bin/better-anonymity verify-dns
```

This tool checks:

1. **System Resolver**: Uses `scutil --dns` to confirm `127.0.0.1` is the resolver.
2. **Wi-Fi Settings**: Uses `networksetup` to confirm `127.0.0.1` is set.
3. **DNSSEC**: Runs `dig` to verify:
    * **Valid Signature**: `dig +dnssec icann.org` (Should be `NOERROR` with `ad` flag).
    * **Invalid Signature**: `dig www.dnssec-failed.org` (Should be `SERVFAIL`).

### Legacy Setup (NetworkSetup)

To set your DNS servers for all active network services without using dnscrypt-proxy:

### Network Setup Usage

To set your DNS servers for all active network services:

```bash
sudo ./scripts/network_setup.sh [provider]
# Example:
sudo ./scripts/network_setup.sh mullvad
```

*Note: This script flushes the DNS cache immediately after applying settings.*

## Captive Portal Monitor

When connecting to public Wi-Fi (coffee shops, airports), a "Captive Portal" often blocks internet access until you agree to terms. This blocks Tor, DNSCrypt, and other tools.

The Captive Portal Monitor helps you navigate this:

1. **Monitor**: Launches a new terminal window that constantly checks connectivity.
2. **Detection**: Alerts you if a portal is detected or if you are offline.
3. **Persistence**: Keeps checking until you are fully online.

### Captive Portal Usage

```bash
# Launch Monitor in a separate window (Best)
better-anonymity captive monitor

# Run in current terminal
better-anonymity captive run

# Check background status
better-anonymity captive status
```

> [!TIP]
> You can use the alias `stay-connected` to quickly launch the monitor in a new window.

## Hosts File Hardening

You can block known malware, adware, and unwanted domains by referencing a curated `/etc/hosts` blocklist.

### Hosts Usage

```bash
sudo ./bin/better-anonymity update-hosts
```

or select "Update Hosts Blocklist" from the interactive menu.

### How it works

1. **Backup**: The first time you run this, the script creates a backup of your original hosts file at `/etc/hosts-base`.
2. **Restore**: On every subsequent run, it restores `/etc/hosts` from `/etc/hosts-base` to ensure a clean state.
3. **Update**: It downloads the latest [StevenBlack/hosts](https://github.com/StevenBlack/hosts) list to `config/hosts` (creating a local cache) and appends it to `/etc/hosts`.

## Wi-Fi & MAC Address

*Future Feature*: We plan to add scripts for MAC address randomization. For now, ensure your "Private Wi-Fi Address" feature is enabled in macOS System Settings if available (dependent on OS version).
