---
description: Build and package the Zenith Commander app into a DMG installer for release.
---

# Release DMG

This skill automates the process of archiving the Xcode project and packaging it into a DMG file for distribution.

## Overview

The release process consists of two steps:
1. **Archive**: Generate an Xcode Archive and export the `.app` bundle
2. **Package**: Create a DMG installer from the exported app

## Prerequisites

- **Xcode**: Must be installed with command line tools
- **create-dmg**: Install via `brew install create-dmg`
- Scripts `custom-archive.sh` and `build-dmg.sh` must exist in the project root

## Steps

### 1. Detect Project Directory

Use the current active workspace directory. The project directory should contain:
- `custom-archive.sh`
- `build-dmg.sh`
- `*.xcodeproj` file

### 2. Generate Archive

// turbo
Run the archive script from the project directory:

```bash
./custom-archive.sh
```

This script will:
- Build the project using `xcodebuild archive`
- Export the `.app` to `./build/<App Name> <timestamp>/`
- Open Finder to show the exported app

### 3. Create DMG Installer

// turbo
After the archive is complete, run the DMG packaging script:

```bash
./build-dmg.sh
```

This script will:
- Find the exported app in `./build/`
- Create a DMG installer at `./dist/<App Name>.dmg`
- Open Finder to show the DMG file

## Output

After successful execution:
- **Archive**: `./build/<App Name>.xcarchive`
- **App**: `./build/<App Name> <timestamp>/<App Name>.app`
- **DMG**: `./dist/<App Name>.dmg`

## Notes

- The archive script disables code signing (`CODE_SIGNING_ALLOWED=NO`)
- If you need code signing, modify `custom-archive.sh` accordingly
- The DMG includes an Applications folder shortcut for easy installation
