# GPG Documentation

## Overview
GnuPG (GPG) is a complete and free implementation of the OpenPGP standard. It allows you to encrypt and sign your data and communications.

## Hardened Configuration
The default GPG configuration is compatible but not necessarily optimized for maximum security. Our configuration (`config/gpg/gpg.conf`) enforces stronger algorithms.

### Key Features
- **Strong Ciphers**: Prioritizes AES256 and AES192.
- **Strong Digests**: Prioritizes SHA512.
- **Information Leaks**: Disables emitting software versions and comments in signatures.
- **Key Format**: Enforces usage of long Key IDs to prevent collision attacks.

## Usage
The `setup-gpg` command installs GPG and applies the hardened configuration to `~/.gnupg/gpg.conf`.

### Security Note
This configuration is optimized for high security:
- **AES256/SHA512** enforced.
- **Short Key IDs** disabled to prevent collision attacks.
- **Banner limits** to reduce fingerprinting.

### Key Management
For the highest level of security, we recommend using a hardware token like a YubiKey.
- [YubiKey Guide (drduh)](https://github.com/drduh/YubiKey-Guide): Comprehensive guide to securely generating and storing GPG keys on a YubiKey.

### Common Commands
```bash
# Generate a new key
gpg --full-generate-key

# Encrypt a file
gpg --recipient [name] --encrypt [filename]

# Decrypt a file
gpg --decrypt [filename]
```
