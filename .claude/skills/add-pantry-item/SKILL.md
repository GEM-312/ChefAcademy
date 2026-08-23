---
name: add-pantry-item
description: Adds a new PantryItem case to the enum and fills in every required switch branch (displayName, emoji, imageName, shopPrice, shopCategory, shopScale, shopOffset, shopFrameHeight). Use when the user wants a new ingredient in the shop or pantry, or says "add pantry item" / "/add-pantry-item".
metadata:
  argument-hint: "[item-name]"
allowed-tools: Read,Edit,Grep
---

# Add New Pantry Item

## Instructions

1. Ask the user for (or infer from context):
   - **Case name** (camelCase, e.g., `lamb`, `chiliFlakes`)
   - **Display name** (e.g., "Lamb", "Chili Flakes")
   - **Emoji** (e.g., "🐑", "🌶️")
   - **Shop price** in coins (typical: 3-10)
   - **Shop category** (protein, dairy, oil, seasoning, grain, produce)

2. Read `RecipeCardExample.swift` to find the PantryItem enum

3. Add the new case to the enum

4. Add entries to ALL computed properties — search for every `switch self` in PantryItem:
   - `displayName` → the display string
   - `emoji` → the emoji
   - `imageName` → `"farm_{snake_case}"` (e.g., "farm_lamb")
   - `shopPrice` → coin cost
   - `shopCategory` → category string
   - `shopScale` → default 2.0 (adjust if image needs different zoom)
   - `shopOffset` → default -20 (Y offset to crop transparent top)
   - `shopFrameHeight` → default 100 (card height in shop grid)

5. Check if the image asset exists in Assets.xcassets/FarmItems/. If not, warn the user they need to add `farm_{name}.imageset`

6. Report what was added and any missing assets

## File location
`/Users/pollakmarina/Dropbox/Mac/Desktop/ChefAcademy/ChefAcademy/RecipeCardExample.swift`
