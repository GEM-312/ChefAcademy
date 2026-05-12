#!/bin/bash
#
# verify-doc-drift.sh — Authority-doc drift detector
#
# Cross-checks CLAUDE.md, STYLES.md, ANIMATIONS.md, ASSETS.md against
# the actual codebase + asset catalog. Flags claims that no longer hold.
#
# Catches the May 12 class of bugs:
#   - Wrong color hex values transcribed into CLAUDE.md
#   - ASSETS.md "~285 imagesets" when actual is 722
#   - STYLES.md "All clear" claim that hasn't been re-verified
#   - Tokens referenced in docs that no longer exist in AppTheme.swift
#
# Exit code: 0 if clean, 1 if any drift detected.
#
# Usage:
#   ./verify-doc-drift.sh
#

set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

TOTAL_ERRORS=0
section() { echo ""; echo "── $1 ──"; }
ok() { echo "  ✓ $1"; }
err() { echo "  ✗ $1"; TOTAL_ERRORS=$((TOTAL_ERRORS + 1)); }

echo "════════════════════════════════════════════════════════════════"
echo "  Doc Drift Check — $(date -u +%Y-%m-%d)"
echo "════════════════════════════════════════════════════════════════"

# ──────────────────────────────────────────────────────────────────
# 1. Color hex values in CLAUDE.md + STYLES.md match the asset catalog
# ──────────────────────────────────────────────────────────────────
section "1. Color hex values vs Assets.xcassets/AppColors"

HEX_ERRORS=$(python3 - <<'PY'
import json, re, sys
from pathlib import Path

catalog = Path("ChefAcademy/Assets.xcassets/AppColors")
if not catalog.exists():
    print("  ⚠ AppColors directory missing — skipping color check")
    sys.exit(0)

def hex_from_components(c):
    def to_int(v):
        v = v.strip()
        if v.startswith("0x"): return int(v, 16)
        return round(float(v) * 255)
    return f"{to_int(c['red']):02X}{to_int(c['green']):02X}{to_int(c['blue']):02X}"

actual = {}
for d in catalog.glob("*.colorset"):
    name = d.name.replace(".colorset", "")
    try:
        contents = json.loads((d / "Contents.json").read_text())
        actual[name] = hex_from_components(contents["colors"][0]["color"]["components"])
    except (KeyError, json.JSONDecodeError):
        continue

docs = ["ChefAcademy/CLAUDE.md", "STYLES.md"]
errors = 0
seen = set()  # (doc_path, token) to dedupe multiple line matches

for doc_path in docs:
    p = Path(doc_path)
    if not p.exists():
        continue
    for line_num, line in enumerate(p.read_text().split("\n"), 1):
        # For each token, look on this line for: token-name, then a hex AFTER it
        # within ~50 chars on the same line, with no OTHER token name in between
        for token, actual_hex in actual.items():
            # Token name not in line → skip
            tok_match = re.search(rf"\b{re.escape(token)}\b", line)
            if not tok_match:
                continue
            # Look for a hex immediately after the token (within 50 chars, on same line)
            after = line[tok_match.end():tok_match.end() + 60]
            hex_match = re.search(r"#([0-9A-Fa-f]{6})\b", after)
            if not hex_match:
                continue
            # Make sure no OTHER known token name appears between token and hex
            between = after[:hex_match.start()]
            other_token_in_between = False
            for other in actual:
                if other != token and re.search(rf"\b{re.escape(other)}\b", between):
                    other_token_in_between = True
                    break
            if other_token_in_between:
                continue
            claimed = hex_match.group(1).upper()
            key = (doc_path, token, claimed)
            if key in seen:
                continue
            seen.add(key)
            if claimed != actual_hex.upper():
                print(f"  ✗ {doc_path}:{line_num} '{token}' claims #{claimed}, actual #{actual_hex}")
                errors += 1

if errors == 0:
    print(f"  ✓ All {len(actual)} colorset hex values match doc claims")
sys.exit(errors)
PY
)
HEX_RC=$?
[ -n "$HEX_ERRORS" ] && echo "$HEX_ERRORS"
TOTAL_ERRORS=$((TOTAL_ERRORS + HEX_RC))

# ──────────────────────────────────────────────────────────────────
# 2. Imageset inventory count in ASSETS.md
# ──────────────────────────────────────────────────────────────────
section "2. Imageset inventory count in ASSETS.md"

ACTUAL_COUNT=$(find ChefAcademy/Assets.xcassets -name "*.imageset" -type d 2>/dev/null | wc -l | tr -d ' ')
CLAIMED=$(grep -oE 'Inventory:[^0-9]*~?([0-9]+)' ASSETS.md 2>/dev/null | grep -oE '[0-9]+' | head -1)

if [ -z "$CLAIMED" ]; then
    err "ASSETS.md doesn't have a parseable 'Inventory: ~N' total claim"
else
    DIFF=$((ACTUAL_COUNT - CLAIMED))
    ABS_DIFF=${DIFF#-}
    if [ "$ABS_DIFF" -gt 30 ]; then
        err "ASSETS.md claims ~$CLAIMED imagesets, actual is $ACTUAL_COUNT (drift: $DIFF)"
    else
        ok "Inventory ~$CLAIMED claimed vs $ACTUAL_COUNT actual (within ±30)"
    fi
fi

# ──────────────────────────────────────────────────────────────────
# 3. .swift files referenced in CLAUDE.md still exist
# ──────────────────────────────────────────────────────────────────
section "3. Key file references in CLAUDE.md"

MISSING=0
for f in $(grep -oE '`[A-Z][a-zA-Z]+\.swift`' ChefAcademy/CLAUDE.md 2>/dev/null | tr -d '`' | sort -u); do
    if ! [ -f "ChefAcademy/$f" ]; then
        err "Referenced in CLAUDE.md but missing on disk: $f"
        MISSING=$((MISSING + 1))
    fi
done
[ $MISSING -eq 0 ] && ok "All .swift files referenced in CLAUDE.md exist"

# ──────────────────────────────────────────────────────────────────
# 4. Color.AppTheme.* tokens referenced in docs exist in AppTheme.swift
# ──────────────────────────────────────────────────────────────────
section "4. Color.AppTheme.* tokens referenced in docs exist"

MISSING=0
for tok in $(grep -ohE 'Color\.AppTheme\.[a-zA-Z]+' ChefAcademy/CLAUDE.md STYLES.md ANIMATIONS.md ASSETS.md 2>/dev/null \
    | sed 's/.*Color\.AppTheme\.//' | sort -u); do
    if ! grep -qE "static let $tok\b" ChefAcademy/AppTheme.swift; then
        err "Color.AppTheme.$tok referenced in docs but not in AppTheme.swift"
        MISSING=$((MISSING + 1))
    fi
done
[ $MISSING -eq 0 ] && ok "All Color.AppTheme.* token references valid"

# ──────────────────────────────────────────────────────────────────
# 5. AnimationConstants.* tokens referenced exist
# ──────────────────────────────────────────────────────────────────
section "5. AnimationConstants.* tokens referenced in docs exist"

MISSING=0
for tok in $(grep -ohE 'AnimationConstants\.[a-zA-Z]+' ChefAcademy/CLAUDE.md STYLES.md ANIMATIONS.md 2>/dev/null \
    | sed 's/.*AnimationConstants\.//' | sort -u); do
    if ! grep -qE "static let $tok\b" ChefAcademy/AppTheme.swift; then
        err "AnimationConstants.$tok referenced in docs but not defined"
        MISSING=$((MISSING + 1))
    fi
done
[ $MISSING -eq 0 ] && ok "All AnimationConstants.* token references valid"

# ──────────────────────────────────────────────────────────────────
# 6. AppSpacing.* tokens referenced exist
# ──────────────────────────────────────────────────────────────────
section "6. AppSpacing.* tokens referenced in docs exist"

MISSING=0
for tok in $(grep -ohE 'AppSpacing\.[a-zA-Z]+' ChefAcademy/CLAUDE.md STYLES.md ANIMATIONS.md 2>/dev/null \
    | sed 's/.*AppSpacing\.//' | sort -u); do
    if ! grep -qE "static let $tok\b" ChefAcademy/AppTheme.swift; then
        err "AppSpacing.$tok referenced in docs but not defined"
        MISSING=$((MISSING + 1))
    fi
done
[ $MISSING -eq 0 ] && ok "All AppSpacing.* token references valid"

# ──────────────────────────────────────────────────────────────────
# 7. Font.AppTheme.* tokens referenced exist
# ──────────────────────────────────────────────────────────────────
section "7. Font.AppTheme.* tokens referenced in docs exist"

MISSING=0
for tok in $(grep -ohE 'Font\.AppTheme\.[a-zA-Z0-9]+' ChefAcademy/CLAUDE.md STYLES.md ANIMATIONS.md 2>/dev/null \
    | sed 's/.*Font\.AppTheme\.//' | sort -u); do
    # Exclude 'rounded' (it's a func, not a let)
    [ "$tok" = "rounded" ] && continue
    if ! grep -qE "static let $tok\b" ChefAcademy/AppTheme.swift; then
        err "Font.AppTheme.$tok referenced in docs but not defined"
        MISSING=$((MISSING + 1))
    fi
done
[ $MISSING -eq 0 ] && ok "All Font.AppTheme.* token references valid"

# ──────────────────────────────────────────────────────────────────
# 8. Standing-decision claims still hold
# ──────────────────────────────────────────────────────────────────
section "8. Standing-decision claims"

# 8a. GardenHubView orphaned (zero non-self references)
GHV_REFS=$(grep -rn "GardenHubView" ChefAcademy/ --include='*.swift' 2>/dev/null \
    | grep -v 'GardenHubView.swift:' | wc -l | tr -d ' ')
if [ "$GHV_REFS" -gt 0 ]; then
    err "CLAUDE.md says GardenHubView is orphaned, but $GHV_REFS references found"
else
    ok "GardenHubView still orphaned (zero non-self references)"
fi

# 8b. Zero inline DispatchQueue.main.asyncAfter
ASYNC_AFTER=$(grep -rn "DispatchQueue.main.asyncAfter" ChefAcademy/ --include='*.swift' 2>/dev/null \
    | grep -v "^.*://" | wc -l | tr -d ' ')
if [ "$ASYNC_AFTER" -gt 0 ]; then
    err "Architecture Rules say zero inline asyncAfter, but $ASYNC_AFTER found"
else
    ok "Zero inline DispatchQueue.main.asyncAfter (Pass F invariant holds)"
fi

# 8c. Tab cases in code match the doc's 6 visible tabs
# Doc claims: home, garden, shop, kitchen, bodyBuddy, playLearn
DOC_TABS="home garden shop kitchen bodyBuddy playLearn"
CODE_TABS=$(grep -oE 'case (home|garden|shop|kitchen|bodyBuddy|playLearn|recipes)' ChefAcademy/ChefAcademyApp.swift 2>/dev/null \
    | sort -u | sed 's/case //' | tr '\n' ' ')
TAB_MISSING=0
for t in $DOC_TABS; do
    if ! echo "$CODE_TABS" | grep -q "\b$t\b"; then
        err "CLAUDE.md tab '$t' missing from Tab enum"
        TAB_MISSING=$((TAB_MISSING + 1))
    fi
done
[ $TAB_MISSING -eq 0 ] && ok "All 6 visible tabs in CLAUDE.md exist in Tab enum"

# ──────────────────────────────────────────────────────────────────
# Footer staleness check
# ──────────────────────────────────────────────────────────────────
section "9. Doc footer dates"

NOW_DAYS=$(date -u +%s)
for f in ChefAcademy/CLAUDE.md STYLES.md ANIMATIONS.md ASSETS.md TEACHING.md; do
    # Reference docs use a "Last Updated: <date>" footer.
    # Chronological logs (TEACHING.md) use the topmost "## Session: <date>" header.
    DATE_STR=$(grep -oE 'Last Updated[^*]+' "$f" 2>/dev/null | head -1 | grep -oE '[A-Z][a-z]+ [0-9]+, [0-9]{4}' | head -1)
    if [ -z "$DATE_STR" ]; then
        # Fallback: scan for the topmost dated session header (chronological logs)
        DATE_STR=$(grep -oE '^## Session: [A-Z][a-z]+ [0-9]+, [0-9]{4}' "$f" 2>/dev/null | head -1 | grep -oE '[A-Z][a-z]+ [0-9]+, [0-9]{4}')
    fi
    if [ -z "$DATE_STR" ]; then
        echo "  ⚠ $f has no parseable 'Last Updated' footer or '## Session: <date>' header"
        continue
    fi
    FILE_DAYS=$(date -j -f "%B %d, %Y" "$DATE_STR" +%s 2>/dev/null || date -d "$DATE_STR" +%s 2>/dev/null)
    if [ -z "$FILE_DAYS" ]; then
        echo "  ⚠ $f: couldn't parse '$DATE_STR'"
        continue
    fi
    AGE_DAYS=$(( (NOW_DAYS - FILE_DAYS) / 86400 ))
    if [ $AGE_DAYS -gt 30 ]; then
        err "$f footer is $AGE_DAYS days old ('$DATE_STR') — consider a sweep"
    else
        ok "$f footer is $AGE_DAYS days old"
    fi
done

# ──────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
if [ $TOTAL_ERRORS -eq 0 ]; then
    echo "  ✓ ALL CHECKS PASSED — no doc drift detected."
    exit 0
else
    echo "  ✗ $TOTAL_ERRORS drift(s) detected. See above."
    exit 1
fi
