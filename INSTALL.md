# Installing Ruan Cleaner

## Install the app

1. Open **`RuanCleanerInstaller.dmg`**.
2. Drag **Ruan Cleaner** into **Applications**.
3. Open it. If macOS blocks it: **System Settings → Privacy & Security → Open Anyway**.
4. Give it Full Disk Access: **System Settings → Privacy & Security → Full Disk Access → +**, choose Ruan Cleaner, switch it on, then quit (**Cmd+Q**) and reopen the app.

After every update or rebuild, remove the old Ruan Cleaner entry from Full Disk Access (**–**) and add the new one (**+**). macOS treats each build as a new app.

## Build it yourself

Requirements: macOS 12 or later, Xcode or the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/ustaXXusta/Ruan_Cleaner.git
cd Ruan_Cleaner
./package.sh
```

This creates `Ruan Cleaner.app` and `RuanCleanerInstaller.dmg` in the project folder. Install from the DMG as above.

To run without packaging (development):

```bash
swift run
```

See [README.md](README.md) for how to use the app and what it cleans.
