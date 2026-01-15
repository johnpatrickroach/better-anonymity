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

## Telegram
**Protocol**: MTProto (Custom).
**Installation**: Run `better-anonymity install telegram`.
**Type**: Cloud-based messenger (Synced across devices).

### Security Warning
Unlike Signal or XMPP+OMEMO, **Telegram usage is NOT End-to-End Encrypted (E2EE) by default**.
-   **Cloud Chats**: Stored on Telegram's servers. Telegram holds the keys.
-   **Secret Chats**: Uses E2EE (Client-device to Client-device). **You MUST specifically use "Start Secret Chat" for private conversations.**

### Recommended Configuration
1.  **Privacy Settings**:
    -   **Phone Number**: Set "Who can see my phone number" to **Nobody** and "Who can find me by my number" to **My Contacts**.
    -   **Last Seen**: Set to **Nobody**.
    -   **Forwarded Messages**: Set "Who can link to my account when forwarding my messages" to **Nobody**.
2.  **Two-Step Verification (2FA)**:
    -   Go to **Settings** -> **Privacy and Security** -> **Two-Step Verification**.
    -   Enable a strong cloud password. This protects your account from SIM swapping or SMS interception attacks.
3.  **Use Secret Chats**:
    -   For any sensitive communication, always create a **Secret Chat**.
    -   Verify the encryption key image with your contact.

## Session
**Protocol**: Session Protocol (based on Signal + Lokinet onion routing).
**Installation**: Run `better-anonymity install session`.
**Type**: Decentralized, Anonymous Messenger.

### Key Advantages
1.  **No Phone Number Required**: You create an account by generating a Session ID (public key). No email or phone is linked.
2.  **No Central Servers**: Messages are routed through an onion-routing network (Lokinet), ensuring your IP address is hidden from the recipient and storage servers (swarms).
3.  **Metadata Minimization**: Session is designed to minimize metadata leakage.

### Usage
-   **Session ID**: Share your long Session ID to connect.
-   **Recovery Phrase**: **Write down your recovery phrase!** Since there is no central server or email recovery, losing your phrase means losing your account forever.


