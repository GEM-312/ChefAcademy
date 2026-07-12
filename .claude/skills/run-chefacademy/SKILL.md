---
name: run-chefacademy
description: Verify a ChefAcademy change against the real app on iPhone Simulator — confirm it builds and optionally launch it. Use when asked to build, run, launch, or screenshot ChefAcademy, or to check "does it compile / does it still build / did my change break the build". Does NOT run CLI xcodebuild (banned — see §7); reads the Xcode build log instead.
allowed-tools: Read, Grep, Glob, Bash
---

# Run ChefAcademy

**Hard constraint:** never run CLI `xcodebuild` on this project. Repeated CLI builds orphan `actool` and wedge the asset catalog (needs a Mac reboot). The `bash-guard.py` hook blocks it and CLAUDE.md §7 forbids it. Builds happen in Xcode; Claude's job is to (1) ask Marina to build, then (2) read the resulting log to confirm success or surface errors.

## 1. Build (Marina, in Xcode)

Ask Marina to build in Xcode: **⌘B** (or Product → Clean Build Folder → Build for a clean check). Wait for her to confirm the build finished before reading the log.

## 2. Verify the build (Claude, read the log)

Xcode writes a compressed `.xcactivitylog` per build. Read the newest one — do **not** trigger a build to produce it:

```bash
LOG=$(ls -t ~/Library/Developer/Xcode/DerivedData/ChefAcademy-*/Logs/Build/*.xcactivitylog 2>/dev/null | head -1)
echo "log: $LOG"
gunzip -c "$LOG" | strings | grep -iE "error:|BUILD (SUCCEEDED|FAILED)" | tail -40
```

- `BUILD SUCCEEDED` and no `error:` lines → the change compiles. Report it plainly.
- `BUILD FAILED` / `error:` lines → quote the errors with `file:line`, then fix and ask for a rebuild. Never claim success you didn't see in the log.
- No log found → the build hasn't run yet; ask Marina to build first.

## 3. Launch in the Simulator (optional)

`xcrun simctl` is fine (it is not `xcodebuild`). It installs/launches the `.app` Xcode already built:

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/ChefAcademy-*/Build/Products/Debug-iphonesimulator/ChefAcademy.app 2>/dev/null | head -1)
xcrun simctl install booted "$APP"
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")
xcrun simctl launch booted "$BUNDLE_ID"
```

## Notes

- iPhone 17 Pro is the default dev target (per CLAUDE.md build settings) — adjust the destination name if Marina switches devices.
- For build verification only (no launch), Step 2 is sufficient — no need to install/launch.
- Reset simulator data if the app misbehaves on stale state: `find ~/Library/Developer/CoreSimulator/Devices -name "default.store*" -path "*/Application Support/*" -exec rm -f {} \;`
