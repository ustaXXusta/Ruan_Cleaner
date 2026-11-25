<p align="center">
  <img src="ruan_logo.png" alt="RUAN" width="420" />
</p>

<p align="center"><b>A safe, fast and transparent cleaner for macOS.</b><br/>
Finds caches, logs, temporary files, old downloads and the leftovers of apps you already deleted, shows you exactly what it found, and removes only what you approve.</p>

---

## Contents

- [Install](#install)
- [First launch](#first-launch)
- [How to use it](#how-to-use-it)
- [What it cleans](#what-it-cleans)
- [Safety](#safety)
- [Build from source](#build-from-source)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## Install

**Requirements:** macOS 12 (Monterey) or later. Apple Silicon and Intel are both supported.

1. Download **`RuanCleanerInstaller.dmg`** from this repository (or build it yourself, see [Build from source](#build-from-source)).
2. Double-click the DMG.
3. Drag **Ruan Cleaner** into your **Applications** folder.
4. Eject the DMG.

## First launch

Ruan Cleaner is not signed with a paid Apple developer certificate, so macOS asks you to confirm the first time.

1. Open **Ruan Cleaner** from Applications. If macOS says it can't be opened, click **Done**.
2. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Ruan Cleaner. Confirm with your password.

### Give it Full Disk Access (important)

Without this, macOS hides most cache folders from the app. Scans come out small and can stall while macOS waits on permission prompts. The app shows a yellow warning while access is off; click it to jump to the right settings page.

1. **System Settings → Privacy & Security → Full Disk Access**
2. Click **+**, pick **Ruan Cleaner** in Applications, and switch it on.
3. Quit Ruan Cleaner (**Cmd+Q**) and open it again.

> **After updating or rebuilding the app**, macOS treats it as a new app and the permission resets.
> Remove the old Ruan Cleaner entry from the list with **–**, add the new one with **+**, and restart the app.

---

## How to use it

1. **Scan.** Press **SCAN**. All categories are scanned at the same time; the ring shows progress and the status line shows which categories are still running.
2. **Review.** Press **REVIEW** to see everything that was found:
   - Categories on the left, with their size. The checkbox selects or deselects a whole category.
   - Files on the right, grouped by app or folder. Click a group to expand it.
   - Folders smaller than 5 MB are collected in one **"Small folders under 5 MB"** group to keep the list short.
   - **COPY PATH** copies a file's or folder's location, so you can check it in Finder.
3. **Choose.** Uncheck anything you want to keep. **SELECTED** at the bottom shows the total across *all* categories, not just the one on screen.
4. **Clean.** Press **CLEAN** (dashboard) or **CLEAN SELECTED** (review screen). A confirmation lists exactly what will be removed from each category, and how. Nothing happens until you confirm. Press **STOP** at any time to cancel.
5. **Check the result.** After cleaning, the app shows what was deleted, what went to the Trash, and how much your free disk space actually changed.

> **Items moved to the Trash still use space.** Old Downloads and App Leftovers go to the Trash so you can restore them. Empty the Trash to get that space back.

---

## What it cleans

| Category | What's in it | Selected by default | Removal |
|---|---|---|---|
| **System Caches** | `~/Library/Caches`. Apps rebuild these when needed. | Yes | Deleted |
| **Application Caches** | Only folders named *Cache*, *Code Cache*, *GPUCache*, *CachedData* and similar inside app data and app containers. Settings, saves and documents are never touched. | Yes | Deleted |
| **Browser Data** | Cache files of Chrome, Safari, Firefox, Edge, Brave, Opera and Arc. Logins, history and bookmarks are not touched. | Yes | Deleted |
| **Logs & Crash Reports** | `~/Library/Logs` and crash reports older than one day. | Yes | Deleted |
| **Temporary Files** | Your temp folder, files older than two days. | Yes | Deleted |
| **Old Downloads** | Items that landed in Downloads 30+ days ago and haven't been opened since. | **No** | Trash |
| **App Leftovers** | Settings, caches, containers, saved state and login agents left behind by apps you deleted. | **No** | Trash |

### App Leftovers

Dragging an app to the Trash only removes the app itself. Its data stays in `~/Library`, which is why free space doesn't come back after an uninstall. Ruan Cleaner:

1. builds a list of every app on your Mac: the Applications folders, apps Spotlight knows about anywhere else (external drives, Steam, Setapp…), and apps that are running right now;
2. checks the places apps keep data: Application Support, Containers, Caches, Preferences, Saved Application State, HTTPStorages, WebKit, Logs and LaunchAgents;
3. lists anything that belongs to an app that is no longer on the Mac, grouped by app name.

Apple's own folders are never listed. When it can't tell, it assumes the app is still installed, so it may miss some leftovers but won't flag real data. Still, **review this category before selecting it.**

---

## Safety

- **Allow-list, not block-list.** A file can only be removed if it sits in a cache, log or temp folder, in Downloads, or is an app leftover found by the scan. Everything else is refused, whatever the scan found.
- **Never touched:** Documents, Desktop, Pictures, Movies, Music, iCloud Drive, cloud storage folders, Mail, Messages, Keychains, Preferences of installed apps, iPhone backups, and anything outside your home folder.
- **Each file appears once.** If a file could fit two categories, it's listed in one only, so unchecking it really unchecks it.
- **Recent files are skipped.** Logs and temp files that are still being written are left alone.
- **Checked again at delete time.** Ownership, locks and permissions are checked right before every deletion; refused files are marked with a yellow shield and the reason is shown.
- **Always asks first.** Every clean shows a confirmation with the full breakdown.
- **Local only.** No network access, no telemetry, no accounts.

---

## Build from source

You need Xcode or the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/ustaXXusta/Ruan_Cleaner.git
cd Ruan_Cleaner
./package.sh
```

`package.sh` builds a release version, creates **`Ruan Cleaner.app`** with its images and icon, signs it for local use, and makes **`RuanCleanerInstaller.dmg`**. Then install it as described in [Install](#install).

For development:

```bash
swift build            # debug build
swift run              # run without packaging
```

The logo and app icon are generated by `tools/make_logo.py` (Python 3 + Pillow + NumPy).

### Project layout

```
Sources/MacCleanerPro/
├── AppMain.swift
├── Models/      ScanItem/ScanGroup/ScanResult, categories, app state and totals
├── Services/    ScannerService, LeftoverFinder, CleanerService, SafetyManager,
│                PermissionManager, SystemMetricsService
├── Views/       Dashboard, review screen, matrix background, theme
└── Assets/      ruan_wordmark.png
tools/make_logo.py   logo and icon generator
package.sh           build + .app + DMG
```

---

## Troubleshooting

**The scan is very small or seems stuck.**
Full Disk Access is almost certainly off (yellow warning on the dashboard). Turn it on as described in [First launch](#first-launch) and restart the app. A category that stops responding for 45 seconds is skipped and listed as "Skipped", so a scan can't hang forever.

**"Ruan Cleaner can't be opened" / "unidentified developer".**
System Settings → Privacy & Security → **Open Anyway**.

**I cleaned, but free space didn't go up as much as expected.**
- Items in **Old Downloads** and **App Leftovers** are in the Trash. Empty the Trash.
- Time Machine keeps local snapshots of recently deleted files. macOS removes them on its own after a while, or when space runs low.
- Some apps (browsers especially) start rebuilding their caches right away.

**Some items show a yellow shield or a red triangle.**
Yellow: skipped on purpose by the safety check. Red: macOS refused the delete. Hover over the icon to see the reason.

---

## FAQ

**Is it safe?**
It only removes files from cache, log and temp folders, your Downloads (to the Trash) and leftovers of deleted apps (to the Trash), and asks before every clean. See [Safety](#safety).

**Will cleaning break my apps?**
No. Caches and temp files are made to be rebuilt. An app may start a little slower the first time after cleaning.

**Can I undo a cleanup?**
Old Downloads and App Leftovers are in the Trash until you empty it. Caches, logs and temp files are deleted for real, since that's the only way to free their space immediately.

**How often should I run it?**
Once a month is plenty. It doesn't run in the background.

---

## Contributing

Issues and pull requests are welcome: bug reports, feature ideas, translations.

## License

Free and open source.

<p align="center"><b>Keep your Mac clean, safe and fast.</b></p>
