# Browser Hardening (Firefox)

## Why Firefox?
Firefox is the most customizable mainstream browser and is independent of the Chromium ecosystem (Google). This makes it the best choice for privacy enthusiasts who want detailed control.

## user.js
The `user.js` file is a configuration file that can override hundreds of internal Firefox settings (`about:config`) that are not exposed in the standard UI.

### Our Configuration
Our `config/firefox/user.js` is a "setup and forget" base based on project like Arkenfox.
- **Telemetry**: Disabled.
- **Geolocation**: Disabled or spoofed.
- **Fingerprinting**: `privacy.resistFingerprinting` is enabled (making your browser look generic).
- **History/Cache**: Cleared on shutdown.

### Installation
1.  Open Firefox and go to `about:support`.
2.  Find the "Profile Folder" row and click "Show in Finder".
3.  Close Firefox completely.
4.  Copy `config/firefox/user.js` into that profile folder.
5.  Start Firefox.

### Trade-offs
- **Resist Fingerprinting** sets the timezone to UTC.
- Some sites may break if they rely on specific WebGL or canvas features.

## Automated Extensions
The `setup` and `harden` commands now automatically install essential privacy extensions:

### uBlock Origin
- **Id**: `uBlock0@raymondhill.net`
- **Action**: Automatically downloaded to your Firefox Profile's `extensions/` directory.
- **Verification**: On the next Firefox launch, you will be prompted to approve the new extension. This is a security feature to prevent silent installations.

