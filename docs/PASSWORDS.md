# Password Management and Authentication Guide

## Best Practices

### 1. Multi-Factor Authentication (MFA)
Enable MFA on all accounts.
- **WebAuthn / FIDO2** (Best): Hardware keys like YubiKey, or Platform Authenticators (TouchID, FaceID).
- **TOTP** (Better): Time-based codes (Google Authenticator, Raivo OTP).
- **SMS/Email** (Weak): Vulnerable to SIM swapping and phishing.

### 2. Passkeys
Passkeys are a replacement for passwords based on FIDO standards. They are phishing-resistant.
- **Use them** wherever supported (Apple, Google, Microsoft, GitHub, etc.).
- They sync via iCloud Keychain on macOS.

### 3. Strong Passwords & Diceware
If you must use a password, use a **password manager** and generate random passwords.
For master passwords or encryption keys you need to memorize, use the **Diceware** method:
- 5-6 random words (e.g., `correct horse battery staple`).
- High entropy and easier to type/remember than random characters.

---

## Better Anonymity Vault

`better-anonymity` includes a built-in, lightweight password vault powered by GPG.

### Features
- **Zero-knowledge**: Passwords are encrypted symmetrically (AES-256 by default via GPG) using a passphrase you choose.
- **Secure File Storage**: Secrets are stored as separate `.gpg` files in `~/.better-anonymity/vault/`.
- **Generation**: Includes a Diceware-style password generator.

### Usage

**Initialize/List**:
```bash
./bin/better-anonymity vault list
```

**Write (Create/Update)**:
```bash
./bin/better-anonymity vault write [name]
```
- You will be asked to generate a secure password or enter your own.
- You will be asked for a passphrase to encrypt the file (GPG agent may cache this).

**Read**:
```bash
./bin/better-anonymity vault read [name]
```
- Decrypts and displays the password.
- Automatically copies to clipboard (clears after 15s).

### Advanced: YubiKey Integration
Since this uses standard GPG, you can use a YubiKey with a GPG applet. If you configure GPG to use your key, you can switch to asymmetric encryption by modifying `lib/vault.sh` or simply use the default symmetric encryption with the YubiKey acting as a static password provider or using GPG-Agent smartcard support.
