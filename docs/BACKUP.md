# Secure Backup Guide

## The 3-2-1 Strategy
Follow the CISA recommended model:
1.  **3 Copies**: Keep 3 copies of any important file (1 primary + 2 backups).
2.  **2 Media Types**: Store backups on 2 different media types (e.g., HDD + Cloud).
3.  **1 Offsite**: Keep at least one copy offsite (e.g., Cloud or physical drive at another location).

## Better Anonymity Tools

### 1. File Encryption (Archives)
Use GPG to compress and encrypt directories.
```bash
# Encrypt
./bin/better-anonymity backup encrypt [directory]
# Result: backup-DATE.tar.gz.gpg
```
- Uses GPG symmetric encryption (password).
- Portable: Can be decrypted on any system with GnuPG.

### 2. Encrypted Volumes (DMG)
Create an encrypted container for files.
```bash
# Create Volume
./bin/better-anonymity backup volume [Name] [Size]
```
- Creates an AES-256 encrypted APFS Disk Image.
- Mount with `hdiutil mount [file.dmg]` or double-click in Finder.

### 3. Time Machine
Checks if configured.
```bash
./bin/better-anonymity backup audit
```
- **Note**: Ensure "Encrypt Backup Disk" is checked in macOS System Settings > Time Machine.

## Alternative Tools
- **Restic**: Fast, secure, efficient backup program.
- **Tresorit**: Zero-knowledge cloud storage.
