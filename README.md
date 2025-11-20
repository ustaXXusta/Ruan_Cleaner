
# Ruan Cleaner

A safe, fast, and transparent macOS cleaner that helps you reclaim disk space by finding and removing system junk, caches, logs, duplicates, and temporary files—without ever compromising your system integrity or personal data.

---

## Philosophy

Ruan Cleaner was built on three core principles:

### 1. Safety First
Your Mac should never break because of a cleaner app. Ruan Cleaner implements multiple safety layers:
- **Dry-run mode** lets you preview exactly what will be deleted before any action is taken
- **System Integrity Protection (SIP) checks** ensure we never touch protected system files
- **Dependency validation** prevents removal of files that other applications rely on
- **Smart filtering** excludes critical system caches and user data from cleanup operations

### 2. Transparency Over Mystery
You deserve to know what's happening on your computer. Unlike commercial cleaners with hidden algorithms, Ruan Cleaner:
- Shows you the exact file paths of everything it finds
- Explains what each type of junk file is and why it's safe to remove
- Provides detailed scan results with file sizes and categories
- Never performs any action without your explicit consent

### 3. Privacy & Freedom
Your data belongs to you, not us:
- **100% local processing** - nothing leaves your Mac
- **Zero telemetry** - we don't collect usage data, analytics, or statistics
- **Open source** - every line of code is available for inspection
- **Completely free** - no premium tiers, no subscriptions, no ads

---

## What Ruan Cleaner Does

Ruan Cleaner intelligently identifies and removes various types of unnecessary files that accumulate over time:

### System Junk
- **Application caches** - Temporary data stored by apps that can be safely regenerated
- **System logs** - Old diagnostic logs that are no longer needed
- **Temporary files** - Files in `/tmp`, `/var/tmp`, and user temp directories
- **Downloaded installers** - DMG files and PKG installers sitting in your Downloads folder

### User Clutter
- **Duplicate files** - Identical files in different locations wasting space
- **Old downloads** - Files you downloaded months ago and forgot about
- **Trash bin** - Files waiting in the Trash to be permanently deleted

### Development Cleanup (Optional)
- **Xcode derived data** - Build artifacts from iOS/macOS development
- **Homebrew caches** - Downloaded package archives no longer needed
- **Node modules** - Cached npm/yarn packages from old projects

### Language Files (Advanced)
- **Unused localizations** - Remove language files for languages you don't use (requires careful selection)

---

## How It Works

Ruan Cleaner uses a three-phase approach to safely clean your Mac:

### Phase 1: Scanning
The app performs a comprehensive scan of known junk file locations:
1. Reads standard system cache directories (`~/Library/Caches`, `/Library/Caches`)
2. Identifies temporary files in system temp folders
3. Analyzes file modification dates to find stale data
4. Calculates the total reclaimable space for each category

### Phase 2: Review
You get full control over what gets deleted:
- Browse scan results organized by category
- View file paths, sizes, and last modified dates
- Select or deselect specific categories or individual files
- See the total space you'll recover before proceeding

### Phase 3: Cleanup
Only after your approval, Ruan Cleaner:
- Moves selected files to the Trash (not permanent deletion)
- Provides real-time progress updates
- Generates a cleanup report showing what was removed
- Gives you one last chance to restore files from Trash if needed

---

## Installation

### Prerequisites
- macOS 12.0 (Monterey) or later
- Swift 5.5+ (comes with Xcode or Swift toolchain)

### Quick Install (Recommended)

**1. Download or clone this repository**
```bash
git clone https://github.com/yourusername/ruan-cleaner.git
cd ruan-cleaner
```

**2. Run the automated setup script**
```bash
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Verify Swift is installed on your system
- Download any required dependencies
- Compile Ruan Cleaner in release mode for optimal performance
- Place the executable in `.build/release/`

**3. Launch the application**
```bash
swift run -c release
```

Or run the binary directly:
```bash
./.build/release/MacCleanerPro
```

---

### Manual Build

If you prefer to build manually or customize the build process:

```bash
# Build in release mode (optimized)
swift build -c release

# Build in debug mode (with debugging symbols)
swift build -c debug

# Run tests
swift test

# Clean build artifacts
swift package clean
```

---

### Creating a Standalone App Bundle

To create a double-clickable macOS app:

```bash
# Build first
swift build -c release

# Package into .app bundle and DMG installer
chmod +x package.sh
./package.sh
```

This creates:
- `Ruan Cleaner.app` - A standard macOS application bundle
- `RuanCleanerInstaller.dmg` - A disk image for easy distribution

You can then drag `Ruan Cleaner.app` to your Applications folder.

---

## Architecture

Ruan Cleaner is built with modern macOS development practices:

- **Language:** Swift (native performance, memory safety)
- **UI Framework:** SwiftUI (responsive, native macOS interface)
- **Design Pattern:** MVVM (Model-View-ViewModel) for clean separation of concerns
- **Minimum Target:** macOS 12.0 for modern API support

### Project Structure
```
MacCleanerPro/
├── Sources/
│   └── MacCleanerPro/
│       ├── Models/          # Data structures and business logic
│       ├── ViewModels/      # UI state management
│       ├── Views/           # SwiftUI interface components
│       └── Assets/          # Icons, colors, resources
├── Package.swift            # Swift Package Manager config
└── setup.sh                 # Automated build script
```

---

## Features

### Core Functionality
- **Comprehensive Scanning** - Deep analysis of system and user directories
- **Granular Control** - Choose exactly what to clean by category or individual file
- **Safety Mechanisms** - Dry-run mode, SIP checks, dependency validation
- **Real-time Progress** - Live updates during scanning and cleaning operations

### User Experience
- **Modern Dark Mode** - Beautiful interface that adapts to system appearance
- **Intuitive Navigation** - Simple, clear workflow from scan to cleanup
- **Detailed Reports** - Know exactly what was removed and how much space was recovered
- **Fast Performance** - Optimized algorithms for quick scans even on large drives

### Privacy & Security
- **No Network Access** - Everything runs locally on your Mac
- **No Telemetry** - Zero data collection or analytics
- **Open Source** - Full code transparency for security audits
- **Reversible Actions** - Files moved to Trash, not immediately deleted

---

## Frequently Asked Questions

**Q: Is it safe to use?**  
A: Yes. Ruan Cleaner only targets genuinely unnecessary files and includes multiple safety checks. It never touches user documents, photos, or essential system files.

**Q: Will cleaning break my applications?**  
A: No. Caches and temporary files are designed to be regenerated. Applications may take slightly longer to launch the first time after cleaning, but will rebuild their caches automatically.

**Q: How much space can I expect to recover?**  
A: This varies greatly depending on how long since your last cleanup. Typical users recover 5-20GB, but heavy users might recover 50GB or more.

**Q: Do I need to run this regularly?**  
A: Monthly or quarterly cleanups are usually sufficient. Ruan Cleaner is designed for occasional use, not as a constantly-running background process.

**Q: Can I undo a cleanup?**  
A: Files are moved to Trash, not immediately deleted. You can restore anything from Trash if needed before emptying it.

---

## Contributing

Ruan Cleaner is open source and welcomes contributions! Whether you want to:
- Report bugs or suggest features
- Improve documentation
- Submit code improvements
- Translate to other languages

Please feel free to open issues or pull requests on GitHub.

---

## License

Ruan Cleaner is free and open source software. See LICENSE file for details.

---

## Support

If you encounter issues:
1. Check the FAQ section above
2. Review existing GitHub issues
3. Open a new issue with details about your system and the problem

---

**Made with ❤️ for the macOS community. Keep your Mac clean, safe, and fast.**
```
