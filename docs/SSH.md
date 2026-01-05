# SSH Security

Secure Shell (SSH) is a critical protocol for remote administration and secure file transfer. Hardening SSH is essential to prevent unauthorized access and protect traffic privacy.

## Server Hardening (sshd)
The **ssh daemon** (`sshd`) listens for incoming connections. By default on macOS, "Remote Login" enables `sshd`.

### Better-Anonymity Configuration
We provide a hardened `sshd_config` based on industry best practices (e.g., [drduh/config](https://github.com/drduh/config)).

**Key Features:**
- **Protocol 2 Only**: Disables insecure legacy protocols.
- **Key-Based Auth Only**: Disables Password Authentication. You MUST use SSH keys.
- **Strong Crypto**: Restricts Ciphers, MACs, and KexAlgorithms to modern, secure options (e.g., `chacha20-poly1305`, `curve25519`).
- **No Root Login**: Prevents direct root access.

**Usage:**
1. Generate keys on your client machine (`ssh-keygen -t ed25519`).
2. Add public key to `~/.ssh/authorized_keys` on the macOS host.
3. Run hardening:
   ```bash
   better-anonymity ssh harden-sshd
   ```
4. Restart Remote Login.

## Client Hardening
Your outgoing SSH connections also leak information. The client config (`~/.ssh/config`) controls how you connect to others.

**Features of Hardened Client Config:**
- **VisualHostKey**: Displays a visual pattern of the host key to help humans detect changes (MitM).
- **HashKnownHosts**: Hashes entries in `known_hosts` so if your file is stolen, attackers can't see where you've connected.
- **VerifyHostKeyDNS**: Uses DNS (SSHFP) to verify host keys if available.

**Usage:**
```bash
better-anonymity ssh harden-client
```

## Tunnels and Proxies
SSH can be used as a poor-man's VPN or Proxy.

### SOCKS Proxy
Create a local SOCKS5 proxy that routes traffic through a remote server:
```bash
ssh -D 8080 user@remote-host
```
Then configure Firefox/System to use SOCKS proxy at `127.0.0.1:8080`.

### Local Forwarding (Tunnel)
Access a service on a remote network (e.g., local web server on port 80) via your machine:
```bash
ssh -L 8080:localhost:80 user@remote-host
```
Access it at `http://localhost:8080`.

## Auditing
Check if your SSH Server is running:
```bash
better-anonymity ssh audit-sshd
```
