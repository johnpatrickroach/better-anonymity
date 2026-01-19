# Firefox Hardening Guide (Arkenfox)

This tool automates the installation of the [Arkenfox user.js](https://github.com/arkenfox/user.js), a comprehensive configuration template for hardening Firefox privacy and security.

## Overview
Unlike simple configuration copiers, `better-anonymity` sets up a **maintainable Arkenfox environment** in your Firefox profile. It does not just overwrite your settings one-time; it installs the necessary tools for you to keep your browser hardened and updated.

### Components Installed
1.  **`updater.sh`**: The official Arkenfox update script. It downloads the latest `user.js` template and merges it with your `user-overrides.js`.
2.  **`prefsCleaner.sh`**: A utility to reset preferences that are no longer enforced by `user.js` (important for reverting changes).
3.  **`user-overrides.js`**: A file where your custom settings live. This file persists across updates.
4.  **`user.js`**: The generated configuration file loaded by Firefox on startup.

## The Hardening Process
When you run `better-anonymity harden-firefox`, the following steps occur:

1.  **Backup**: Your existing `prefs.js` and `user.js` are backed up with a timestamp (e.g., `prefs.js.backup.20231024...`).
2.  **Download Tools**: `updater.sh` and `prefsCleaner.sh` are downloaded directly from the Arkenfox repository to your profile directory.
3.  **Create Overrides**: A `user-overrides.js` file is created (or updated) with `better-anonymity` defaults (e.g., restoring session history).
4.  **Compile**: The `updater.sh` script is executed locally. It fetches the latest Arkenfox template, appends your overrides, and generates the final `user.js`.

## Customization (The Right Way)
**Do not edit `user.js` directly.** It will be overwritten the next time you update.

To change settings permanently:
1.  Open your Firefox profile folder (Go to `about:support` -> Profile Directory -> Open).
2.  Edit **`user-overrides.js`**.
3.  Add your custom preferences.
    ```javascript
    // Example: Re-enable WebGL
    user_pref("webgl.disabled", false);
    ```
4.  Run the **`updater.sh`** script in that directory (requires Terminal).
    ```bash
    cd /path/to/profile
    ./updater.sh
    ```
5.  Restart Firefox.

See the [Arkenfox Overrides Wiki](https://github.com/arkenfox/user.js/wiki/3.2-Overrides-[Common]) for common recipes.

## Maintenance
### Updating Arkenfox
To get the latest security improvements from Arkenfox:
1.  Close Firefox.
2.  Open Terminal and navigate to your profile directory.
3.  Run `./updater.sh`.
4.  (Optional) Run `./prefsCleaner.sh` to remove old, unused preferences.

### Cleaning Up
If you want to reset changes made by valid `user.js` entries that are no longer in the file (e.g. after removing an override), run:
```bash
./prefsCleaner.sh
```

## Key Trade-offs
Arkenfox is aggressive by default. Be aware of these common side effects:
-   **Timestamps & Fingerprinting**: `privacy.resistFingerprinting` (RFP) is enabled. Your browser expects you to be in the UTC timezone.
-   **Letterboxing**: The window size may be clamped to specific dimensions to prevent screen resolution fingerprinting.
-   **Session Clearing**: History and cache are cleared on shutdown by default (unless overridden).

For more details, please read the [Arkenfox Wiki](https://github.com/arkenfox/user.js/wiki).
