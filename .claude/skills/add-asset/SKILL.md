---
name: add-asset
description: Creates an Xcode .imageset from a loose PNG, moving the image into Assets.xcassets with a correct Contents.json. Use when the user wants to add an image to the asset catalog, says "add asset", "/add-asset", or hands over a PNG to wire into the app.
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

## Category defaults
- If filename starts with `farm_` → FarmItems
- If filename starts with `pip_` → Pip
- If filename contains `veggie` or matches a VegetableType → Vegetables
- If filename starts with `stove_` or `kitchen_` or `frying_` → Cooking
- Otherwise ask the user or use root of Assets.xcassets

## Asset catalog path
`/Users/pollakmarina/Dropbox/Mac/Desktop/ChefAcademy/ChefAcademy/Assets.xcassets/`
