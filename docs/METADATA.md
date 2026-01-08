# Metadata and Artifact Cleanup

## Overview
macOS and its applications generate significant amounts of metadata and cache artifacts that can reveal user activity. The `cleanup-metadata` command attempts to remove or sanitize these.

## Cleaned Areas

### 1. QuickLook Cache
- **Description**: Storage of file thumbnails. Can persist even for encrypted/hidden volumes.
- **Action**: Clears cache via `qlmanage` and `rm`.

### 2. Finder Metadata
- **Description**: Recent folders, recent searches, desktop volume positions.
- **Action**: Clears `com.apple.finder.plist` entries.

### 3. System Caches
- **Bluetooth**: Device cache, history.
- **CUPS**: Printer job history.
- **Action**: Deletes cache files and preferences.

### 4. Language & Spelling
- **Description**: Learned words, spelling caches. Can reveal typed content.
- **Action**: **Deletes** and **Locks** (sets immutable flag) the following directories:
    - `~/Library/LanguageModeling`
    - `~/Library/Spelling`
    - `~/Library/Suggestions`

### 5. QuickLook Application Support
- **Description**: App-specific cache data.
- **Action**: Deletes and **Locks** `~/Library/Application Support/Quick Look`.

### 6. Application State
- **Description**: Saved windows, unsaved document states.
- **Action**: Clears `~/Library/Saved Application State`.

### 7. Siri Analytics
- **Description**: Local database of interaction metrics.
- **Action**: Deletes `~/Library/Assistant/SiriAnalytics.db`.

### 8. Wi-Fi NVRAM
- **Description**: Preferred network list stored in non-volatile RAM.
- **Action**: Clears specific NVRAM variables.

### 9. Browser Data (Aggressive)
- **Chrome**: History, Cache, History-journal.
- **Safari**: History, Cookies, Downloads, TopSites, and various Caches.
- **Firefox**: Cookies, Form History, Session Store (for all profiles).

### 10. System Artifacts
- **Quarantine Events**: Clears the `LSQuarantineEvent` database which tracks downloaded files.
- **Inactive Memory**: URL-like strings and sensitive data can persist in RAM. The script offers to run `sudo purge`.
- **Trash**: Empties trash on all volumes.

## Usage
Run via the CLI menu or directly:
```bash
sudo ./bin/better-anonymity cleanup-metadata
```

## Risks
- **Data Loss**: Unsaved changes in open applications may be lost if "Saved Application State" is cleared while they are open.
- **Usability**: Locking spelling dictionaries will prevent macOS from learning new words.
