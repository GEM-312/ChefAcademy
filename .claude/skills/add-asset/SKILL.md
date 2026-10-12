---
name: add-asset
description: Creates an Xcode .imageset from a loose PNG, moving the image into Assets.xcassets with a correct Contents.json. Also installs station-matched art that passed in ~/Dropbox/Mac/Desktop/Art Inbox/matched. Use when the user wants to add an image to the asset catalog, says "add asset", "/add-asset", "install from the inbox", or hands over a PNG to wire into the app.
metadata:
  argument-hint: "[path-to-png] [category]"
allowed-tools: Bash,Read,Write,Glob
---

# Add Asset to Xcode Asset Catalog

## Instructions

1. Parse the user's message for: `<png_path>` and optional `[category]` (e.g., Cooking, Vegetables, FarmItems, Pip, Backgrounds)
2. Derive the asset name from the filename (strip extension, keep snake_case)
3. Check if the imageset already exists in Assets.xcassets — warn if overwriting
4. Create the imageset folder and Contents.json:

```
Assets.xcassets/{Category}/{asset_name}.imageset/
  ├── {asset_name}.png
  └── Contents.json
```

5. Contents.json format:
```json
{
  "images" : [{ "filename" : "{asset_name}.png", "idiom" : "universal" }],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

6. Copy the PNG into the imageset folder
7. Report: asset name, category, and how to use it: `Image("{asset_name}")`

## Art Inbox mode (no path given, or "from the inbox")

New art from OpenArt goes through `tools/art_match.py`. A launchd watcher matches anything dropped in `~/Dropbox/Mac/Desktop/Art Inbox/` to the stations' contrast and sepia, then evaluates it.

1. List the PASSED files in `Art Inbox/matched/*.png`. Skip `*_compare.png`, and skip `matched/failed/` and `matched/installed/`. **Never install from `failed/`.** If the user asks for a failed file anyway, show its failing checks and stop.
2. For each file, one at a time:
   - Read its `_compare.png` so you see the before/after and the PASS lines.
   - Ask Marina for the asset name and category. Ask only ONE question at a time.
3. Install with steps 3–7 below. Use the matched PNG, renamed to `{asset_name}.png`.
4. Move the matched PNG and its `_compare.png` into `Art Inbox/matched/installed/` so they aren't offered again.

## Category defaults
- If filename starts with `farm_` → FarmItems
- If filename starts with `pip_` → Pip
- If filename contains `veggie` or matches a VegetableType → Vegetables
- If filename starts with `stove_` or `kitchen_` or `frying_` → Cooking
- Otherwise ask the user or use root of Assets.xcassets

## Asset catalog path
`/Users/pollakmarina/Dropbox/Mac/Desktop/ChefAcademy/ChefAcademy/Assets.xcassets/`
