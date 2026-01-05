# OS Hardening Documentation

## Overview
The `scripts/macos_hardening.sh` script applies various system-level configurations to enhance the security and privacy of macOS. It is designed to be modular, but by default, it applies a broad set of "best practice" hardening rules.

## Features

### Firewall
There are several types of firewalls available for macOS. The **Application Layer Firewall** is a built-in, basic firewall which blocks incoming connections only. It does not monitor or block outgoing connections.

The script enables the firewall and **Stealth Mode**.
> Computer hackers scan networks so they can attempt to identify computers to attack. You can prevent your computer from responding to some of these scans by using stealth mode. When stealth mode is enabled, your computer does not respond to ICMP ping requests, and does not answer to connection attempts from a closed TCP or UDP port.

#### Signed Software Handling
To prevent built-in software as well as code-signed, downloaded software from being whitelisted automatically, the script sets `allowsigned` and `allowsignedapp` to `off`.
- If you run an unsigned app that is not listed in the firewall list, a dialog appears with options to Allow or Deny connections for the app.
- If you choose "Allow", macOS signs the application and automatically adds it to the firewall list.

### Analytics & Privacy
- **Diagnostic Reports**: Disabled. Prevents the system from sending daily diagnostic and usage data to Apple.
- **Crash Reporter**: Disabled. Crash data is kept local.
- **Siri Data Sharing**: Disabled. User voice command data is not sent to Apple for "grading".
- **Ad Tracking**: Limited (`com.apple.AdLib`).
- **Remote Events**: Disabled (`remoteappleevents`).
- **Firefox Telemetry**: Disabled (if installed).



### Spotlight
By default, Spotlight sends your search queries to Apple to provide "Suggestions" (news, weather, etc.).
- The script disables "Spotlight Suggestions", "Bing Web Scrapes", and other network-dependent search results.
- Spotlight is restricted to searching local files (Applications, Directories, etc.).

### System Security
- **Screen Saver**: Configured to ask for a password immediately (0-second delay) after the screen turns off or the screen saver starts.
- **Finder**: All file extensions are shown to prevent file type spoofing (e.g., `malware.pdf.exe` appearing as `malware.pdf`).

### Hostname Anonymization
When macOS first starts, you'll be greeted by Setup Assistant. If you enter your real name at the account setup process, be aware that your computer's name and local hostname will comprise that name (e.g., *John Appleseed's MacBook*) and thus will appear on local networks and in various preference files.

This script anonymizes your hostname (e.g., to "MacBook" or "Mac"). You can also verify and update this manually:
```bash
sudo scutil --set ComputerName MacBook
sudo scutil --set LocalHostName MacBook
```

### System Integrity Protection (SIP)
SIP restricts the root account and prevents unauthorized modification of protected files.
- **Verification**: `csrutil status` should return `System Integrity Protection status: enabled`.
- **Enabling**: 
    1.  Restart your Mac and hold **Command + R** to enter Recovery Mode.
    2.  Open **Terminal** from the Utilities menu.
    3.  Run: `csrutil enable`.
    4.  Restart.

### Disk Encryption (FileVault)
All Mac models with Apple silicon are encrypted by default. Enabling FileVault makes it so that you need to enter a password in order to access the data on your drive. The [EFF has a guide on generating strong but memorable passwords](https://www.eff.org/dice).

### Captive Portal Detection
- **Option**: Disable Captive Portal detection (`com.apple.captive.control`).
- **Effect**: Prevents macOS from connecting to Apple servers to check for internet connectivity on Wi-Fi join.
- **Warning**: May break login pages on public Wi-Fi (hotels, cafes). Use with caution.

Your FileVault password also acts as a firmware password that will prevent people that don't know it from booting from anything other than the designated startup disk, accessing Recovery, and reviving it with DFU mode.

FileVault will ask you to set a recovery key in case you forget your password. Keep this key stored somewhere safe. You'll have the option use your iCloud account to unlock your disk; however, anyone with access to your iCloud account will be able to unlock it as well.


### Gatekeeper
Gatekeeper tries to prevent non-notarized applications from running.
- If you try to run an app that isn't notarized, Gatekeeper will give you a warning.
- This can be bypassed by going to **Privacy & Security**, scrolling down to the bottom, and clicking **Open Anyway** on your app. Then Gatekeeper will allow you to run it.

**Warning**: Gatekeeper does not cover all binaries - only applications - so exercise caution when running other file types.

### Lockdown Mode
macOS offers Lockdown Mode, a security feature that disables several features across the OS, significantly reducing attack surface for attackers while keeping the OS usable. You can read about exactly what is disabled and decide for yourself if it is acceptable to you.

When Lockdown Mode is on, you can disable it per site in Safari on trusted sites.

### Homebrew Security
**Warning**: Homebrew requests "App Management" (or "Full Disk Access") permission to the terminal. This is a risk, as it allows any non-sandboxed application to execute code with global TCC permissions by modifying shell configuration (e.g., `.zshrc`). Granting this entitlement should be considered equivalent to disabling TCC entirely for the terminal session.

The script applies the following hardening to Homebrew:
- **Disables Analytics**: Prevents Homebrew from reporting usage data (`HOMEBREW_NO_ANALYTICS=1`).
- **Prevents Insecure Redirects**: Mandates secure connections (`HOMEBREW_NO_INSECURE_REDIRECT=1`).

**Persistence**: The script automatically appends these variables to your `~/.zshrc` file to ensure they remain active in future sessions.





## Usage
To run the hardening script:
```bash
sudo ./scripts/macos_hardening.sh --all
```

## Reverting
Most settings are changed via `defaults write`. To revert, you generally need to delete the key or set it to its previous value. There is currently no automated "undo" script, so backup your data or check the script source for the specific keys modified.
