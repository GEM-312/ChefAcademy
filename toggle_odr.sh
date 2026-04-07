#!/bin/bash
# Toggle ODR (On Demand Resources) on/off
# Usage: ./toggle_odr.sh off   — for Xcode device testing (all images bundled)
#        ./toggle_odr.sh on    — for TestFlight/App Store archive (images in asset packs)

set -e
cd "$(dirname "$0")"

PBXPROJ="ChefAcademy.xcodeproj/project.pbxproj"
ASSETS_DIR="ChefAcademy/Assets.xcassets"

if [ "$1" = "off" ]; then
    echo "🔴 Disabling ODR — all images will be bundled in the app..."

    # Disable in project settings
    sed -i '' 's/ENABLE_ON_DEMAND_RESOURCES = YES;/ENABLE_ON_DEMAND_RESOURCES = NO;/g' "$PBXPROJ"

    # Remove ODR tags from all asset Contents.json
    python3 -c "
import json, os, glob
count = 0
for path in glob.glob(os.path.join('$ASSETS_DIR', '**', 'Contents.json'), recursive=True):
    with open(path, 'r') as f:
        data = json.load(f)
    if 'properties' in data and 'on-demand-resource-tags' in data['properties']:
        del data['properties']['on-demand-resource-tags']
        if not data['properties']:
            del data['properties']
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
        count += 1
print(f'   Removed ODR tags from {count} assets')
"
    echo "✅ ODR disabled — run from Xcode to device, all images will load!"

elif [ "$1" = "on" ]; then
    echo "🟢 Restoring ODR from git..."

    # Restore original ODR settings from git
    git checkout -- "$PBXPROJ" "$ASSETS_DIR"

    echo "✅ ODR restored — ready for TestFlight archive!"

else
    echo "Usage: ./toggle_odr.sh [on|off]"
    echo "  off  — Disable ODR for Xcode device testing"
    echo "  on   — Restore ODR for TestFlight/App Store"
fi
