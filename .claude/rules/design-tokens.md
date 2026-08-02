---
paths:
  - "**/AppTheme.swift"
  - "**/AdaptiveLayout.swift"
---

# You're editing the design-token SOURCE (extracted from CLAUDE.md §3 + Standing context)

These files (`Color.AppTheme` / `Font.AppTheme` / `AppSpacing` / `AnimationConstants` / `AdaptiveCardSize`) are the **definition** of the design system — so they are the one place raw literals legitimately live and are **exempt** from §3's no-hardcoded-values rule. This rule loads only when you open a token-source file; it does the opposite of the `*View.swift` rule, which forbids the very literals that belong here.

- **This is the ONE place raw literals belong.** Need a value that doesn't exist yet? ADD a token here, with a comment saying what it's for — never inline a one-off at the call site.
- **Token values are mirrored in `STYLES.md` / `ANIMATIONS.md` / `ASSETS.md`.** After changing any hex value, size, or count, run `./verify-doc-drift.sh` before committing — those docs are drift-checked against these files and a mismatch is a known bug class.
- **Colors back onto `Assets.xcassets/AppColors/`** for Dark Mode. A new `Color.AppTheme` needs its color set there too, or dark mode falls back wrong.
