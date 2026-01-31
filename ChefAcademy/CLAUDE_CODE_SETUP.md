# 🚀 Using Claude Code with Pip's Kitchen Garden

## What is Claude Code?

Claude Code is Anthropic's command-line tool that lets Claude directly edit your code files, run commands, and build your project. It's like pair programming with Claude!

---

## Setup Instructions

### 1. Install Claude Code

Open Terminal and run:
```bash
npm install -g @anthropic-ai/claude-code
```

Or if you prefer:
```bash
brew install claude-code
```

### 2. Navigate to Your Project

```bash
cd /path/to/PipsKitchenGarden
```

### 3. Make Sure CLAUDE.md is in Root

The `CLAUDE.md` file should be at the root of your Xcode project:
```
PipsKitchenGarden/
├── CLAUDE.md              ← This file!
├── PipsKitchenGarden/     ← Xcode project folder
│   ├── App/
│   ├── Models/
│   ├── Views/
│   └── ...
└── PipsKitchenGarden.xcodeproj
```

### 4. Start Claude Code

```bash
claude
```

---

## How to Use

### Basic Commands

Just talk to Claude naturally! Examples:

```
> Create the GardenView with a 2x2 grid of plots

> Add a CHOP mini-game where players tap to cut vegetables

> Fix the bug in HubView where coins don't update

> Make the harvest animation more bouncy
```

### Pro Tips

1. **Be specific about files:**
   ```
   > In Views/Garden/GardenView.swift, add a water button
   ```

2. **Reference the GDD:**
   ```
   > Following the Game Design Document, build the daily quest system
   ```

3. **Ask for explanations:**
   ```
   > Explain how GameState manages the inventory, then add a seed shop
   ```

4. **Iterate quickly:**
   ```
   > That looks good but make the animation faster
   ```

---

## Example Session

```
you> Create the Hub screen with Pip greeting, daily quest card, and 3 buttons for GROW/COOK/FEED

Claude> I'll create HubView.swift following the design in CLAUDE.md...
        [creates file]
        
you> The buttons should be bigger and more colorful

Claude> I'll update the button styling...
        [edits file]

you> Add a coin counter in the top right

Claude> Adding CoinDisplay component to the navigation bar...
        [edits file]

you> Perfect! Now create the Garden screen
```

---

## What Claude Code Knows

Because of `CLAUDE.md`, Claude Code understands:

✅ The game's GROW → COOK → FEED loop
✅ Visual style (vintage botanical watercolor)
✅ Color palette and fonts (AppTheme)
✅ File structure and where to put new files
✅ Existing models and how to use them
✅ Animation guidelines
✅ That this is a GAME for kids, not a boring app

---

## When to Use Claude Code vs Claude.ai

| Task | Use Claude Code | Use Claude.ai |
|------|-----------------|---------------|
| Writing Swift code | ✅ | ⚠️ Copy/paste needed |
| Creating new views | ✅ | ⚠️ |
| Fixing bugs | ✅ | ❌ |
| Refactoring | ✅ | ❌ |
| Brainstorming ideas | ⚠️ | ✅ |
| Design decisions | ⚠️ | ✅ |
| Creating documentation | Both work | Both work |
| Generating images | ❌ | ❌ (use Midjourney) |

---

## Useful Prompts for This Project

### Building Features
```
> Create the [feature] following the Game Design Document
> Build [view] with the same visual style as the onboarding screens
> Add [component] and make it reusable
```

### Mini-Games
```
> Create the CHOP mini-game where players tap at the right time to cut vegetables
> Build a MIX mini-game with circular gesture recognition
> Make a FLIP mini-game with swipe-up gesture and arc animation
```

### Animations
```
> Add a bouncy spring animation when [element] appears
> Create a particle effect for when players earn coins
> Animate Pip changing between poses smoothly
```

### Bug Fixes
```
> The [thing] isn't working because [problem]. Fix it.
> When I tap [button], nothing happens. Debug this.
> The layout breaks on smaller iPhones. Make it responsive.
```

---

## Keeping CLAUDE.md Updated

As you build, update CLAUDE.md with:
- New files you've created
- Models you've added
- Features that are complete
- Any design changes

This helps Claude Code stay in sync with your project!

---

## Need Help?

- **Claude Code docs:** https://docs.anthropic.com/claude-code
- **SwiftUI reference:** https://developer.apple.com/documentation/swiftui
- **This project's GDD:** `/Documentation/GameDesignDocument.md`

---

Happy coding! 🦔🎮
