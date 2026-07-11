#!/usr/bin/env python3
"""PreToolUse design-system guard for ChefAcademy (CLAUDE.md §3).

Fires only when Claude is about to `git commit`. Scans the ADDED (`+`) lines of
the staged diff for hardcoded design values that §3 bans, and hard-blocks the
commit (exit 2) so they get fixed before landing — the automated version of the
"pre-commit audit grep" that §3 only described in prose.

Scope is deliberately tight to avoid false positives:
  * only ADDED lines of the staged diff (your own change, not pre-existing code)
  * only ChefAcademy/*.swift (the flat source tree)
  * skips the token-DEFINITION files where these literals legitimately live
    (AppTheme.swift, AdaptiveLayout.swift)
  * skips comment-only added lines
  * matches only UNAMBIGUOUS violations — e.g. a numeric corner radius, an
    inline hex color, `.system(size:)`. Ambiguous smells from the §3 grep that
    have legitimate token-backed forms (bare RoundedRectangle with an AppSpacing
    token, Timer.scheduledTimer in the walk engines) are intentionally NOT here.

Any error → exit 0 (fail open: never break a normal commit).
"""
import sys
import os
import re
import json
import subprocess

# Files where these literals are DEFINED, not misused. §3 exempts them.
EXEMPT_FILES = {"AppTheme.swift", "AdaptiveLayout.swift"}

# (label, compiled pattern) — each an unambiguous §3 violation.
PATTERNS = [
    ("Color.black literal (use Color.AppTheme.sepia)", re.compile(r"Color\.black\b")),
    ("Color.white literal (use a Color.AppTheme token)", re.compile(r"Color\.white\b")),
    ("inline hex color (define a Color.AppTheme token)", re.compile(r"Color\(hex:")),
    ("hardcoded system font (use Font.AppTheme.*)", re.compile(r"\.system\(\s*size:")),
    ("inline spring (use AnimationConstants.spring*)", re.compile(r"\.spring\(response:")),
    ("inline easing (use AnimationConstants.*)", re.compile(r"\.ease(?:InOut|In|Out)\(duration:")),
    ("hardcoded corner radius (use AppSpacing)", re.compile(r"RoundedRectangle\(cornerRadius:\s*\d")),
    ("DispatchQueue.main.asyncAfter (use Task @MainActor — §2)", re.compile(r"DispatchQueue\.main\.asyncAfter")),
]


def find_violations(diff_text):
    """Return [(file, label, snippet)] for §3 violations in added lines."""
    violations = []
    current = None  # current file basename, or None if exempt/irrelevant
    for line in diff_text.splitlines():
        if line.startswith("+++ b/"):
            path = line[6:]
            base = os.path.basename(path)
            # only track flat ChefAcademy/*.swift, skip token-definition files
            current = base if (
                path.startswith("ChefAcademy/")
                and base.endswith(".swift")
                and base not in EXEMPT_FILES
            ) else None
            continue
        if current is None or not line.startswith("+") or line.startswith("+++"):
            continue
        added = line[1:]
        if added.lstrip().startswith("//"):  # comment-only added line
            continue
        for label, pat in PATTERNS:
            if pat.search(added):
                violations.append((current, label, added.strip()))
    return violations


def git_diff(project_dir, args):
    try:
        out = subprocess.run(
            ["git", "diff"] + args + ["-U0", "--", "ChefAcademy/*.swift"],
            cwd=project_dir, capture_output=True, text=True, timeout=10,
        )
        return out.stdout
    except Exception:
        return ""


def main():
    try:
        data = json.load(sys.stdin)
        cmd = data.get("tool_input", {}).get("command", "") or ""
    except Exception:
        sys.exit(0)

    # Only act on a real `git commit` invocation.
    if not re.search(r"\bgit\b[^\n]*\bcommit\b", cmd):
        sys.exit(0)

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()

    diff = git_diff(project_dir, ["--cached"])
    # `git commit -a/--all` stages tracked files at commit time — include them.
    if re.search(r"\bcommit\b[^\n]*\s-\w*a|\b--all\b", cmd):
        diff += "\n" + git_diff(project_dir, [])

    violations = find_violations(diff)
    if not violations:
        sys.exit(0)

    lines = "\n".join(
        f"  • {f}: {label}\n      {snippet}" for f, label, snippet in violations[:20]
    )
    extra = "" if len(violations) <= 20 else f"\n  … and {len(violations) - 20} more."
    sys.stderr.write(
        "BLOCKED: staged diff has hardcoded design values (CLAUDE.md §3 — zero "
        "hardcoded colors/fonts/spacing/animation). Replace with AppTheme / "
        "AppSpacing / AnimationConstants tokens, then re-commit. If a needed "
        "token is genuinely missing, ADD it to AppTheme.swift with a comment — "
        "never inline.\n\n" + lines + extra + "\n"
    )
    sys.exit(2)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        sample = (
            "+++ b/ChefAcademy/FooView.swift\n"
            "+        .foregroundColor(Color.black)\n"
            "+        // Color.black in a comment should be ignored\n"
            "+        .font(.system(size: 20))\n"
            "+        RoundedRectangle(cornerRadius: 12)\n"
            "+        RoundedRectangle(cornerRadius: AppSpacing.card)\n"
            "+        .background(Color.AppTheme.cream)\n"
            "+++ b/ChefAcademy/AppTheme.swift\n"
            "+    static let black = Color.black  // definition file, exempt\n"
        )
        for v in find_violations(sample):
            print(v)
        sys.exit(0)
    main()
