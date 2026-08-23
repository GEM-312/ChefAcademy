---
name: export-procreate
description: Extracts every PNG from Assets.xcassets into a flat, category-organized folder on the Desktop for AirDrop to iPad. Use when the user wants to color assets in Procreate, says "export for Procreate" / "/export-procreate", or asks to get the art onto the iPad — and to copy the colored PNGs back afterward.
allowed-tools: Bash,Glob
---

# Export Assets for Procreate

## Instructions

1. Create a timestamped export folder on Desktop: `~/Desktop/ChefAcademy_Assets_Export/`
2. Organize by subfolder matching asset catalog categories:
   - `Pip/` — all pip_* assets
   - `Vegetables/` — all veggie images
   - `FarmItems/` — all farm_* assets
   - `Backgrounds/` — background images
   - `AvatarCards/` — boy/girl card frames
   - `Cooking/` — frying_pan, knife, cutting_board, etc.
3. Copy every PNG from each `.imageset` folder into the matching export subfolder
4. Skip Contents.json files — only copy actual image files (.png, .jpg)
5. Report total count and folder location
6. Remind the user:
   - AirDrop the folder to iPad
   - Open in Procreate, color with transparency
   - Export as PNG with transparency from Procreate
   - Replace the matching file in the `.imageset` folder back in Xcode

## Asset catalog path
`/Users/pollakmarina/Dropbox/Mac/Desktop/ChefAcademy/ChefAcademy/Assets.xcassets/`

## After coloring
When the user says "done coloring" or "replace assets", find the colored PNGs and copy them back into the matching `.imageset` folders in Assets.xcassets, replacing the originals.
