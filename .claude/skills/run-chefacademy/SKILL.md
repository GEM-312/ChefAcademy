---
name: run-chefacademy
description: Build ChefAcademy on iPhone Simulator to verify a change against the real app.
---

# Run ChefAcademy

## Build

```bash
xcodebuild -scheme ChefAcademy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Build artifacts land in `~/Library/Developer/Xcode/DerivedData/ChefAcademy-*/Build/Products/Debug-iphonesimulator/ChefAcademy.app`.

## Launch in booted Simulator

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/ChefAcademy-*/Build/Products/Debug-iphonesimulator/ChefAcademy.app
xcrun simctl launch booted <bundle-id>
```

(Look up `<bundle-id>` via `plutil -p .../Info.plist | grep CFBundleIdentifier` if unknown.)

## Notes

- iPhone 17 Pro is the default dev target — adjust the destination name if Marina switches devices.
- For headless build verification (no launch), the build step alone is sufficient.
