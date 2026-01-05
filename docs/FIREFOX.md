# Firefox Hardening Guide

## Arkenfox user.js
This tool uses the [Arkenfox user.js](https://github.com/arkenfox/user.js) to harden Firefox settings.
It is a template which provides a set of configuration options (in `user.js`) to improve privacy and security.

## Hardening Process
The `harden-firefox` command performs the following:
1. **Detects Profile**: automatically finds your default Firefox profile (`*.default-release` or `*.default`).
2. **Backups Config**: Creates a timestamped backup of your current `prefs.js`.
3. **Downloads Configuration**: Fetches the latest `user.js` from the Arkenfox repository.
4. **Applies Overrides**: Appends a small set of custom overrides (e.g., restoring previous session) to valid usability.
5. **Installs**: Copies the resulting `user.js` to your profile folder.

## Custom Overrides
Currently, the script applies a minimal set of overrides.
To add your own persistent changes that won't be overwritten by Arkenfox defaults, you can edit the `user.js` file in your profile directory directly, but be aware that running this tool again will overwrite `user.js`.

**Recommended Workflow for Customization:**
1. Run `better-anonymity harden-firefox`.
2. Open Firefox and verify settings.
3. If you need to change something (e.g. re-enable WebGL), you can try changing it in `about:config`.
    - Note: Arkenfox `user.js` enforces settings on startup. If you change a setting in `about:config` and `user.js` overrides it, it will reset on next launch.
    - To make it permanent, add your preference to the end of the `user.js` file in your profile folder.
