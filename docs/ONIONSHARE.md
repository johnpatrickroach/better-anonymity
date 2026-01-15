# OnionShare

[OnionShare](https://onionshare.org/) is an open source tool that lets you securely and anonymously share files, host websites, and chat with friends using the Tor network. It allows you to create direct, ephemeral connections between users without relying on third-party cloud servers (like Dropbox or Google Drive).

## Why use OnionShare?

-   **Anonymity**: All connections are routed through the Tor network, hiding your IP address and location from the recipient and observers.
-   **Security**: Files are hosted directly from your computer. No third-party ever has access to your data.
-   **End-to-End Encryption**: Tor hidden services provide end-to-end encryption by default.
-   **Ephemeral**: You can configure shares to stop sharing automatically after they have been downloaded, ensuring they don't linger.

## Installation via Better Anonymity

You can install OnionShare easily using the CLI:

```bash
better-anonymity install onionshare
```

Or select it during the setup wizard:

```bash
better-anonymity setup
```

This will install the **OnionShare.app** to your `/Applications` folder via Homebrew Cask.

## Key Features

### 1. Share Files
Securely send files of any size.
1. Add files to OnionShare.
2. Click "Start Sharing".
3. Sends a `.onion` URL (e.g., `http://onionshare:password@megarandomstring.onion`) to your recipient.
4. The recipient opens the link in **Tor Browser** to download the file directly from your computer.

### 2. Receive Files
Allow others to upload files to you securely.
1. Choose "Receive Mode".
2. Start the server.
3. Share the URL.
4. Anyone with the URL can upload files, which are saved to your chosen directory.

### 3. Host a Website
Host a static HTML website directly from your Mac.
1. Drag your `index.html` and assets into OnionShare.
2. Start sharing.
3. You now have a live website accessible via Tor.

### 4. Anonymous Chat
Create a private, encrypted chat room.
1. Start a chat server.
2. Share the URL with friends.
3. Chat anonymously without logs or central servers.

## Recommendations

-   **Use Tor Browser**: Recipients MUST use Tor Browser to access your OnionShare links.
-   **Keep it Running**: Since files are hosted on your computer, you must keep OnionShare open and your computer awake until the transfer is complete.
-   **Network**: Ensure you are connected to the internet. If you are using `better-anonymity`'s strict Anonymity Mode, ensure Tor is working correctly. OnionShare bundles its own Tor process by default, so it usually works independently of the system Tor service.

## Security Note
OnionShare is extremely secure, but remember that if your computer is compromised (e.g., by malware), the files you are sharing might also be accessible to the attacker. Always ensure your macOS system is hardened using:

```bash
better-anonymity harden
better-anonymity verify-security
```
