# Secure Messengers Documentation

## Overview
This document outlines recommended secure messaging practices and configurations.

## Signal
**Protocol**: Signal Protocol (Double-Ratchet E2EE).
**Installation**: Run `install-signal` or use the main menu option.
**Requirements**: A mobile phone number is required to register.
**Security**: Signal is considered the gold standard for secure messaging.
- **Disappearing Messages**: Enable this for sensitive chats.
- **Screen Lock**: Enable in Desktop settings to secure the app when away.

## XMPP (Jabber)
**Protocol**: Extensible Messaging and Presence Protocol (Federated).
**Encryption**: **OMEMO** is required for End-to-End Encryption. Do not use plain XMPP/OTR if modern multi-device support is needed.

### Recommend Clients
We recommend using **Browser-Based Clients** to leverage the browser's sandbox security model.
- **Converse.js**: A popular web-based XMPP client.
- **Movim**: A social platform on top of XMPP.

If utilizing a native client, ensure it is open-source and audited (e.g., **Dino** or **Gajim** on Linux/macOS).

## iMessage
**Protocol**: APNs / Apple proprietary E2EE.
**Scope**: Apple Ecosystem only.

### Hardening Configuration
Since iMessage is built-in, adhere to these practices:

1.  **Contact Key Verification**:
    - Enable this to ensure you are messaging the correct device keys.
    - Go to **Settings** -> **[Your Name]** -> **Contact Key Verification**.

2.  **iCloud Backup Risks**:
    - **Warning**: Standard iCloud Backups store the encryption key for your messages on Apple's servers. This technically grants Apple (and law enforcement via legal process) access to your messages.

3.  **Mitigation (Advanced Data Protection)**:
    - Enable **Advanced Data Protection (ADP)** for iCloud.
    - Go to **Settings** -> **[Your Name]** -> **iCloud** -> **Advanced Data Protection**.
    - This moves the decryption keys to your trusted devices *only*, restoring true E2EE for backups.
    - **Alternative**: Completely disable Messages in iCloud / iCloud Backup.
