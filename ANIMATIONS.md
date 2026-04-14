# ANIMATIONS.md — Animation Standards & Rules

All animation timing, engine choices, and haptic patterns for Pip's Kitchen Garden.
Every new animation MUST follow these rules. See `STYLES.md` for colors/fonts/spacing.

---

## 1. Animation Engine Decision Tree

Pick the right engine for the job:

| Need | Use | Reference |
|------|-----|-----------|
| Character movement on screen | `TimelineView(.animation)` + delta-time | `WalkingPipView` in GardenView.swift |
| Looping idle sprite (no position change) | `TimelineView(.periodic(from:by:))` | `PipWavingAnimatedView` in PipAnimations.swift |
| One-shot sprite (play once, hold last) | `OneShotFrameAnimationView` (Timer OK) | PipAnimations.swift |
| Property animations (scale, opacity, offset) | `withAnimation()` or `.animation(_:value:)` | Throughout app |
| Card-to-detail morph | `matchedGeometryEffect` + ZStack overlay | MorphTransition.swift |
| Haptic feedback | `Haptic.impact()` / `Haptic.notify()` | AppTheme.swift |

### BANNED for New Code

- `Timer.scheduledTimer` for continuous animation — use `TimelineView` instead (auto-pauses off-screen, no leak risk)
- Inline magic numbers — use `AnimationConstants` from AppTheme.swift
- Raw `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` — use shared `Haptic` enum

---

## 2. Standard Timing Curves (AnimationConstants)

Defined in `AppTheme.swift`. Use these instead of inline values.

### Springs
| Constant | Response | Damping | Use For |
|----------|----------|---------|---------|
| `.springQuick` | 0.3s | 0.6 | Buttons, small bounces |
| `.springMedium` | 0.4s | 0.7 | Cards, dialogs |
| `.springSlow` | 0.5s | 0.7 | Large elements, reveals |
| `.springBouncy` | 0.3s | 0.5 | Celebrations, pose changes |

### Easing
| Constant | Duration | Use For |
|----------|----------|---------|
| `.routeTransition` | 0.3s easeInOut | Tab switches, route changes |
| `.fadeQuick` | 0.15s easeInOut | Button press feedback |
| `.fadeMedium` | 0.3s easeInOut | Content appear/disappear |

### Morph
| Constant | Type | Use For |
|----------|------|---------|
| `.morphTransition` | spring(0.45, 0.85) | Card-to-detail matchedGeometryEffect |

### Frame Animation
| Constant | Value | Use For |
|----------|-------|---------|
| `.walkingFPS` | 8.0 | All character walking (~0.125s/frame) |
| `.wavingFPS` | 6.0 | Pip waving idle loop (~0.167s/frame) |
| `.walkSpeed` | 54 pts/sec | Character movement speed |

### Button Scales
| Constant | Value | Use For |
|----------|-------|---------|
| `.buttonPressScale` | 0.97 | Subtle squeeze (Primary/Secondary/Textured) |
| `.bouncyPressScale` | 0.9 | Bigger bounce (BouncyButtonStyle) |

---

## 3. Frame Animation Conventions

### Naming
```
[character]_[action]_frame_[##]
```
- Zero-padded 2-digit numbers, starting at `01` (not `00`)
- Lowercase, underscores as delimiters
- Examples: `pip_walking_frame_01`, `boy_walking_frame_10`, `girl_cooking_frame_05`

### Asset Specs
- Canvas: 1024x1024 transparent PNG
- Walking: 10-15 frames at 8fps
- Waving/idle: 15 frames at 6fps
- One-shot: variable frame count at 15-24fps

### Frame Cycling
- **Elapsed-time math** (preferred): `frameIndex = Int(elapsed / frameDuration) % count`
- Never use tick counters for new code — they drift on variable refresh rates
- Always clamp delta-time to `< 0.5s` to prevent teleporting after backgrounding

---

## 4. Transition Style Rules

| Context | Approach |
|---------|----------|
| Card-to-detail (recipe, seed, pantry) | `matchedGeometryEffect` morph via ZStack overlay |
| Route changes (RootRouterView) | `.easeInOut(duration: 0.3)` on route value |
| Tab switches | `.easeInOut(duration: 0.2)` |
| Cooking step-to-step | `.asymmetric(insertion: .move(.trailing), removal: .move(.leading))` + `.opacity` |
| Pip entrance | `AnyTransition.pipEntrance` (scale 0.5 + opacity) |
| Pip dialog appear | `.easeOut(0.3s)` after 0.5s delay |
| Mini-game completion | `.scale.combined(with: .opacity)` |

### matchedGeometryEffect Rules
- Source and destination MUST be in the same view hierarchy (use ZStack, NOT .fullScreenCover)
- Only one source per ID at a time
- Use `isSource: true` on whichever view is currently visible
- Animate with `AnimationConstants.morphTransition`
- Hero element = the most visually prominent shared element (usually the image)

---

## 5. Haptic Conventions

Shared `Haptic` enum in `AppTheme.swift`. Always use these wrappers.

| Action | Call | Feel |
|--------|------|------|
| Button tap | `Haptic.impact(.light)` | Gentle tap |
| Mini-game interaction (chop, stir) | `Haptic.impact(.medium)` | Solid tap |
| Heavy action (drop, slam) | `Haptic.impact(.heavy)` | Deep thud |
| Perfect hit | `Haptic.impact(.rigid)` | Sharp click |
| Success (harvest, 3 stars, badge) | `Haptic.notify(.success)` | Completion buzz |
| Wrong answer | `Haptic.notify(.warning)` | Warning buzz |
| Error (purchase fail) | `Haptic.notify(.error)` | Error pattern |
| Picker/selection change | `Haptic.selection()` | Subtle tick |
| Morph transition start | `Haptic.impact(.light)` | Gentle tap |

---

## 6. Performance Rules

1. **Max 2 sprite characters** animating simultaneously on screen
2. **Cap frame animations at 15fps** — display refresh handles interpolation
3. **Use `.drawingGroup()`** on complex ZStacks with many animated children
4. **Clamp delta-time to 0.5s** max to prevent teleporting after backgrounding
5. **Use `@State`** for animation state that shouldn't trigger parent redraws
6. **Prefer `TimelineView`** over `Timer` — auto-pauses when view is off-screen
7. **Use `AnimationConstants`** — never hardcode timing values in view files

---

## Button Styles

| Style | Background | Use For |
|-------|-----------|---------|
| `PrimaryButtonStyle` | Solid goldenWheat | Standard CTA |
| `SecondaryButtonStyle` | Parchment + border | Alternative actions |
| `TexturedButtonStyle` | Wooden botanical image | Key CTAs (visit garden, start cooking) |
| `BouncyButtonStyle` | Custom (per-use) | Interactive elements |

---

*Last Updated: April 13, 2026*
