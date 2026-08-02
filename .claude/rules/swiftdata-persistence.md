---
paths:
  - "**/FamilyProfile.swift"
  - "**/UserProfile.swift"
  - "**/PlayerData.swift"
  - "**/Allergen.swift"
  - "**/GameState.swift"
  - "**/SessionManager.swift"
---

# SwiftData / CloudKit rules (extracted from CLAUDE.md §1)

This is the highest cost-of-failure surface in the app. It loads **only** when you open a `@Model` or a core persistence file — an explicit-file-list glob, because the governed set is a small, known list (not a directory or a wildcard type).

- **All `@Model` properties MUST have default values** at declaration. CloudKit requires it; missing defaults crash the schema migration.
- **NO `@Relationship` macros** — link models via `UUID` fields. `FamilyProfile` → members via `familyID` query; `UserProfile` → `PlayerData` via `ownerID`.
- **NO `[String: Int]` dictionaries on `@Model`** — use `[CodableStruct]` arrays. SwiftData doesn't reliably persist dictionary types.
- **`.modelContainer(modelContainer)` MUST be on the WindowGroup.** Required for `@Environment(\.modelContext)` to resolve in any descendant. Missing this caused an infinite loop bug.
- **Use `do { try save() } catch { print(error) }` for SwiftData saves** — never `try?`. Silent failures destroyed child profiles for a week (March bug). Always log errors so they're diagnosable.
- **Codable backwards compatibility:** every new field on a persisted struct needs `decodeIfPresent(...) ?? defaultValue`. Old saved data doesn't have the new keys → crash without it.
