#!/usr/bin/env python3
"""PreToolUse design-system guard for ChefAcademy (CLAUDE.md §3 + §4).

Fires only when Claude is about to `git commit`. Scans the ADDED (`+`) lines of
the staged diff for hardcoded design values and hand-made buttons, and
hard-blocks the commit (exit 2) so they get fixed before landing.

What blocks (decided Oct 23 2026 — every category blocks, none only warns):
  * colors      Color.black/.white/.red…, Color(hex:), Color(red:), .foregroundColor(.white)…
  * fonts       .system(size:), .font(.title)-style system fonts, rounded(size: 44)
  * animations  inline spring / easing / linear / timingCurve
  * strokes, corners, shadows   lineWidth: 2, cornerRadius 12, .shadow(radius: 8)
  * spacing, padding, frames    spacing: 6, .padding(10), .frame(width: 140)
  * buttons     .buttonStyle(.plain), and a Button that draws its own
                .background() instead of a shared style (texturedButton, choiceCard…)
  * DispatchQueue.main.asyncAfter (§2)

Zero is allowed (`spacing: 0`, `.padding(0)`): it means "none", not a design value.
A one-screen size belongs in a named `private enum Layout` at the top of the
file — `static let recipeCircle: CGFloat = 140` doesn't match any pattern.

Escape hatch for a real exception, on the offending line (or anywhere in the
Button block):  // design-guard: allow — <reason>
The reason is required; an allow without one is itself reported.

Not checked on purpose: .offset (map/scene positions), .opacity, .scaleEffect,
rotation degrees.

Scope: only ADDED lines (old code never blocks a commit), only ChefAcademy/*.swift,
skipping the token-definition files (AppTheme.swift, AdaptiveLayout.swift).

Any error → exit 0 (fail open: never break a normal commit).

Modes:
  (hook)        reads the PreToolUse JSON on stdin
  --all         report every hit in the whole source tree (the sweep backlog)
  --ratchet     --all, then exit 1 if the total rose above .design-guard-baseline (CI)
  --selftest    run the built-in good/bad examples; exit 1 if any is wrong
"""
import sys
import os
import re
import json
import glob
import shlex
import subprocess
import collections

# Files where these literals are DEFINED, not misused. §3 exempts them.
EXEMPT_FILES = {"AppTheme.swift", "AdaptiveLayout.swift"}

# A non-zero number: 2, 1.5, 0.5 — but not 0 or 0.0
NUM = r"(?:[1-9]\d*(?:\.\d+)?|0\.\d*[1-9]\d*)"
SYSTEM_COLORS = r"(?:black|white|red|blue|green|yellow|orange|gray|grey|purple|pink|brown|cyan|mint|teal|indigo)"
SYSTEM_FONTS = r"(?:largeTitle|title|title2|title3|headline|subheadline|body|callout|footnote|caption|caption2)"
SHARED_BUTTON_STYLES = re.compile(
    r"texturedButton|choiceCard|primaryButton|secondaryButton|"
    r"TexturedButtonStyle|ChoiceCardStyle|PrimaryButtonStyle|SecondaryButtonStyle"
)

# (category, label, compiled pattern)
PATTERNS = [
    ("color", "system color (use a Color.AppTheme token)",
     re.compile(rf"\bColor\.{SYSTEM_COLORS}\b")),
    ("color", "inline hex color (define a Color.AppTheme token)", re.compile(r"Color\(hex:")),
    ("color", "inline RGB color (define a Color.AppTheme token)", re.compile(r"Color\(\s*(?:\.sRGB\s*,\s*)?red:")),
    ("color", "system color shorthand (use a Color.AppTheme token)",
     re.compile(rf"\.(?:foregroundColor|foregroundStyle|fill|background|stroke|tint|accentColor)\(\s*\.{SYSTEM_COLORS}\b")),
    ("font", "hardcoded system font (use Font.AppTheme.*)", re.compile(r"\.system\(\s*size:")),
    ("font", "system text style (use Font.AppTheme.*)", re.compile(rf"\.font\(\s*\.{SYSTEM_FONTS}\s*\)")),
    ("font", "raw font size (use a Font.AppTheme token or a Layout name)",
     re.compile(rf"\.rounded\(\s*size:\s*{NUM}")),
    ("animation", "inline spring (use AnimationConstants.spring*)",
     re.compile(r"\.(?:spring|interpolatingSpring)\(\s*(?:response|mass|stiffness|duration):")),
    ("animation", "inline easing (use AnimationConstants.*)",
     re.compile(r"\.(?:easeInOut|easeIn|easeOut|linear)\(\s*duration:")),
    ("animation", "inline timing curve (use AnimationConstants.*)", re.compile(r"\.timingCurve\(")),
    ("stroke", "raw stroke width (use AppSpacing.strokeThin/Medium/Bold)", re.compile(rf"lineWidth:\s*{NUM}")),
    ("corner", "raw corner radius (use AppSpacing.*CornerRadius)", re.compile(rf"cornerRadius(?:\(|:)\s*{NUM}")),
    ("shadow", "raw shadow radius (use a token)", re.compile(rf"\.shadow\(.*?\bradius:\s*{NUM}")),
    ("spacing", "raw stack spacing (use AppSpacing.*)", re.compile(rf"\bspacing:\s*{NUM}")),
    ("spacing", "raw padding (use AppSpacing.*)",
     re.compile(rf"\.padding\(\s*(?:\.[a-zA-Z]+\s*,\s*|\[[^\]]*\]\s*,\s*)?{NUM}")),
    ("spacing", "raw EdgeInsets (use AppSpacing.*)", re.compile(rf"EdgeInsets\([^)]*:\s*{NUM}")),
    ("frame", "raw frame size (use a token, AdaptiveCardSize, or a Layout name)",
     re.compile(rf"\.frame\([^)]*\b(?:width|height|minWidth|maxWidth|minHeight|maxHeight|idealWidth|idealHeight):\s*{NUM}")),
    ("button", "plain button style (use texturedButton / choiceCard / BouncyButtonStyle)",
     re.compile(r"\.buttonStyle\(\s*(?:\.plain|PlainButtonStyle\(\))\s*\)")),
    ("concurrency", "DispatchQueue.main.asyncAfter (use Task @MainActor — §2)",
     re.compile(r"DispatchQueue\.main\.asyncAfter")),
]

ALLOW = re.compile(r"design-guard:\s*allow\b\s*[—\-:]*\s*(.*)")
COMMENT = re.compile(r"(?<![:\\])//.*$")   # a trailing // comment (not the // in https://)


def allow_state(text):
    """None = no allow-comment; True = allowed with a reason; False = allow without a reason."""
    m = ALLOW.search(text)
    if not m:
        return None
    return len(re.findall(r"\w", m.group(1))) >= 3


def line_violations(text):
    """[(category, label)] for one source line (comments stripped)."""
    stripped = text.lstrip()
    if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
        return []
    code = COMMENT.sub("", text)
    return [(cat, label) for cat, label, pat in PATTERNS if pat.search(code)]


def button_blocks(lines):
    """Yield (start, end, text) for each `Button` call + its modifier chain (0-based, inclusive)."""
    i = 0
    while i < len(lines):
        line = COMMENT.sub("", lines[i])
        m = re.search(r"\bButton\s*[({]", line)
        if not m:
            i += 1
            continue
        # walk brackets from "Button" until the call (and any trailing closure) closes
        depth, started, j, k = 0, False, i, m.start()
        end = None
        while j < len(lines) and end is None:
            src = COMMENT.sub("", lines[j])
            while k < len(src):
                c = src[k]
                if c in "({":
                    depth += 1
                    started = True
                elif c in ")}":
                    depth -= 1
                    if started and depth == 0:
                        rest = src[k + 1:].strip()
                        # a trailing label closure may follow: Button(action: x) { … }
                        nxt = rest or next((l.strip() for l in lines[j + 1:j + 2]), "")
                        if not nxt.startswith("{"):
                            end = j
                            break
                k += 1
            if end is None:
                j += 1
                k = 0
        if end is None:
            return
        # the modifier chain: following lines that start with "."
        chain_end = end
        while chain_end + 1 < len(lines) and lines[chain_end + 1].lstrip().startswith("."):
            chain_end += 1
        yield i, chain_end, "\n".join(lines[i:chain_end + 1])
        i = end + 1


def hand_made_buttons(lines, added):
    """Line numbers (1-based) of Buttons that draw their own background with no shared style."""
    hits = []
    for start, end, text in button_blocks(lines):
        code = "\n".join(COMMENT.sub("", l) for l in text.splitlines())
        if ".background(" not in code or SHARED_BUTTON_STYLES.search(code):
            continue
        if not any((n + 1) in added for n in range(start, end + 1)):
            continue
        hits.append((start + 1, end + 1, text))
    return hits


def check_file(name, lines, added):
    """[(file, lineno, category, label, snippet)] for the added lines of one file."""
    out = []
    flagged = hand_made_buttons(lines, added)
    # lines already inside a flagged Button block: report the button once, not its .plain line too
    in_flagged = {n for start, end, _ in flagged for n in range(start, end + 1)}
    for n in sorted(added):
        if n < 1 or n > len(lines):
            continue
        text = lines[n - 1]
        allowed = allow_state(text)
        if allowed is False:
            out.append((name, n, "allow", "design-guard: allow needs a reason", text.strip()))
            continue
        if allowed:
            continue
        for cat, label in line_violations(text):
            if cat == "button" and n in in_flagged:
                continue
            out.append((name, n, cat, label, text.strip()))
    for start, end, text in flagged:
        allowed = allow_state(text)
        if allowed:
            continue
        if allowed is False:
            out.append((name, start, "allow", "design-guard: allow needs a reason", lines[start - 1].strip()))
            continue
        out.append((name, start, "button",
                    "Button draws its own background (use texturedButton / choiceCard)",
                    lines[start - 1].strip()))
    return out


def tracked(path):
    base = os.path.basename(path)
    return path.startswith("ChefAcademy/") and base.endswith(".swift") and base not in EXEMPT_FILES


def added_lines(diff_text):
    """{path: set(new-file line numbers)} from a -U0 diff."""
    result = collections.defaultdict(set)
    path, n = None, 0
    for line in diff_text.splitlines():
        if line.startswith("+++ "):
            p = line[6:] if line.startswith("+++ b/") else None
            path = p if p and tracked(p) else None
            continue
        m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
        if m:
            n = int(m.group(1))
            continue
        if path is None:
            continue
        if line.startswith("+"):
            result[path].add(n)
            n += 1
    return result


def git(project_dir, args):
    try:
        return subprocess.run(["git"] + args, cwd=project_dir,
                              capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return ""


def stages_tracked_files(cmd):
    """True if this `git commit` stages tracked files itself (-a / --all).

    Parsed with shlex, not matched with a regex: shlex understands shell
    quoting, so a flag that only appears inside the commit message
    (`git commit -m "add -a flag"`) lands in a single argument and is not
    mistaken for a real flag.
    """
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        # Unbalanced quotes: we cannot tell. Scan the unstaged diff anyway --
        # an unchecked diff must not pass as a clean one (CLAUDE.md S10).
        return True
    if "commit" not in tokens:
        return False
    for tok in tokens[tokens.index("commit") + 1:]:
        if tok == "--all":
            return True
        # single-dash short flags combine: -a, -am, -va all stage tracked files
        if tok.startswith("-") and not tok.startswith("--") and "a" in tok[1:]:
            return True
    return False


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
    with_worktree = stages_tracked_files(cmd)

    # `git commit -a/--all` stages tracked files at commit time — check the
    # working tree then; otherwise check exactly what is staged.
    diff_args = ["diff", "HEAD"] if with_worktree else ["diff", "--cached"]
    added = added_lines(git(project_dir, diff_args + ["-U0", "--", "ChefAcademy/*.swift"]))

    violations = []
    for path, nums in added.items():
        if with_worktree:
            try:
                with open(os.path.join(project_dir, path), errors="ignore") as f:
                    content = f.read()
            except OSError:
                continue
        else:
            content = git(project_dir, ["show", f":{path}"])
        violations += check_file(os.path.basename(path), content.splitlines(), nums)

    if not violations:
        sys.exit(0)

    lines = "\n".join(
        f"  • {f}:{n}: {label}\n      {snippet}" for f, n, _, label, snippet in violations[:20]
    )
    extra = "" if len(violations) <= 20 else f"\n  … and {len(violations) - 20} more."
    sys.stderr.write(
        "BLOCKED: staged diff has hardcoded design values or hand-made buttons "
        "(CLAUDE.md §3/§4). Use AppTheme / AppSpacing / AnimationConstants / "
        "AdaptiveCardSize tokens, a named `private enum Layout` value for a "
        "one-screen size, or a shared button style, then re-commit. A real "
        "exception gets `// design-guard: allow — <reason>` on that line.\n\n"
        + lines + extra + "\n"
    )
    sys.exit(2)


def report_all(src_dir):
    """--all: every hit in the source tree, as if every line were new."""
    per_file = collections.defaultdict(collections.Counter)
    for p in sorted(glob.glob(os.path.join(src_dir, "*.swift"))):
        name = os.path.basename(p)
        if name in EXEMPT_FILES:
            continue
        with open(p, errors="ignore") as f:
            lines = f.read().splitlines()
        for _, _, cat, _, _ in check_file(name, lines, set(range(1, len(lines) + 1))):
            per_file[name][cat] += 1
    totals = collections.Counter()
    for c in per_file.values():
        totals.update(c)
    total = sum(totals.values())
    print(f"design-guard --all: {total} hits in {len(per_file)} files")
    for cat, n in totals.most_common():
        print(f"  {cat:12} {n}")
    print()
    for name, c in sorted(per_file.items(), key=lambda kv: -sum(kv[1].values())):
        print(f"  {sum(c.values()):4}  {name:38} " + " ".join(f"{k}={v}" for k, v in c.most_common()))
    return total


def ratchet(src_dir, baseline_path):
    """--ratchet: fail (exit 1) if the whole-tree total rose above the saved baseline.

    The baseline only goes down: after a sweep commit lowers the total, lower the
    number in the baseline file in the same commit.
    """
    with open(baseline_path) as f:
        baseline = int(f.read().strip())
    total = report_all(src_dir)
    print()
    if total > baseline:
        print(f"RATCHET FAILED: {total} hits, baseline is {baseline} (+{total - baseline}). "
              "New hardcoded values or hand-made buttons got in; fix them (see the list above).")
        sys.exit(1)
    if total < baseline:
        print(f"Ratchet OK: {total} hits, below the baseline of {baseline}. "
              f"Lower .design-guard-baseline to {total} to lock in the progress.")
    else:
        print(f"Ratchet OK: {total} hits, same as the baseline.")
    sys.exit(0)


def selftest():
    # (source line, expected categories)
    lines_cases = [
        (".foregroundColor(Color.black)", ["color"]),
        (".foregroundColor(.white)", ["color"]),
        (".fill(Color(red: 0.2, green: 0.3, blue: 0.4))", ["color"]),
        (".background(Color.AppTheme.cream)", []),
        ("// Color.black in a comment", []),
        (".font(.system(size: 20))", ["font"]),
        (".font(.title)", ["font"]),
        (".font(.AppTheme.rounded(size: 44))", ["font"]),
        (".font(.AppTheme.rounded(size: Layout.star))", []),
        (".font(.AppTheme.title)", []),
        ("withAnimation(.spring(response: 0.3)) {", ["animation"]),
        (".animation(.linear(duration: 2), value: x)", ["animation"]),
        (".animation(AnimationConstants.springQuick, value: x)", []),
        (".stroke(Color.AppTheme.sage, lineWidth: 1.5)", ["stroke"]),
        (".stroke(Color.AppTheme.sage, lineWidth: AppSpacing.strokeMedium)", []),
        ("RoundedRectangle(cornerRadius: 12)", ["corner"]),
        (".cornerRadius(12)", ["corner"]),
        (".cornerRadius(AppSpacing.cardCornerRadius)", []),
        (".shadow(color: Color.AppTheme.sepia.opacity(0.1), radius: 8, x: 0, y: 4)", ["shadow"]),
        ("VStack(spacing: 6) {", ["spacing"]),
        ("VStack(spacing: 0) {", []),
        ("VStack(spacing: AppSpacing.xs) {", []),
        (".padding(10)", ["spacing"]),
        (".padding(.horizontal, 20)", ["spacing"]),
        (".padding([.top, .bottom], 4)", ["spacing"]),
        (".padding(.top, 0)", []),
        (".padding(AppSpacing.md)", []),
        (".frame(width: 140, height: 140)", ["frame"]),
        ("Spacer().frame(height: 20)", ["frame"]),
        (".frame(maxWidth: .infinity)", []),
        (".frame(width: Layout.recipeCircle)", []),
        ("static let recipeCircle: CGFloat = 140", []),
        (".buttonStyle(.plain)", ["button"]),
        (".buttonStyle(BouncyButtonStyle())", []),
        ("DispatchQueue.main.asyncAfter(deadline: .now() + 1) {", ["concurrency"]),
        (".offset(x: 120, y: -40)", []),
        ('Link("Help", destination: URL(string: "https://x.com/a")!)', []),
    ]
    failures = []
    for text, want in lines_cases:
        got = sorted({c for c, _ in line_violations(text)})
        if got != sorted(want):
            failures.append(f"line {text!r}: want {want}, got {got}")

    def run(src, added=None):
        lines = src.strip("\n").splitlines()
        nums = set(range(1, len(lines) + 1)) if added is None else added
        return [(c, n) for _, n, c, _, _ in check_file("T.swift", lines, nums)]

    hand_made = """
Button(action: { go() }) {
    Text("Go")
        .background(Color.AppTheme.sage)
}
.buttonStyle(.plain)
"""
    shared = """
Button(action: { go() }) {
    Text("Go")
}
.texturedButton(tint: Color.AppTheme.buttonGo)
"""
    card_with_inner_bg = """
Button { pick() } label: {
    Circle().background(Color.AppTheme.parchment)
}
.choiceCard(isSelected: true)
"""
    allowed = """
Button(action: { tap() }) { // design-guard: allow — map hotspot picture
    Image("barn").background(Color.AppTheme.cream)
}
.buttonStyle(BouncyButtonStyle())
"""
    allowed_no_reason = """
VStack(spacing: 6) { // design-guard: allow
"""
    block_cases = [
        ("hand-made button", hand_made, None, [("button", 1)]),
        ("hand-made button, untouched lines", hand_made, set(), []),
        ("shared style", shared, None, []),
        ("choice card with inner background", card_with_inner_bg, None, []),
        ("allow with reason", allowed, None, []),
        ("allow without reason", allowed_no_reason, None, [("allow", 1)]),
    ]
    for label, src, added, want in block_cases:
        got = run(src, added)
        if got != want:
            failures.append(f"{label}: want {want}, got {got}")

    diff = "+++ b/ChefAcademy/FooView.swift\n@@ -10,0 +11,2 @@\n+a\n+b\n" \
           "+++ b/ChefAcademy/AppTheme.swift\n@@ -1,0 +1 @@\n+c\n"
    if dict(added_lines(diff)) != {"ChefAcademy/FooView.swift": {11, 12}}:
        failures.append(f"added_lines: got {dict(added_lines(diff))}")

    total = len(lines_cases) + len(block_cases) + 1
    if failures:
        print("\n".join(failures))
        print(f"selftest: {len(failures)} of {total} FAILED")
        sys.exit(1)
    print(f"selftest: all {total} cases pass")
    sys.exit(0)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        selftest()
    here = os.path.dirname(os.path.abspath(__file__))
    src = os.path.join(here, "..", "..", "ChefAcademy")
    if len(sys.argv) > 1 and sys.argv[1] == "--all":
        report_all(src)
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] == "--ratchet":
        ratchet(src, os.path.join(here, "..", "..", ".design-guard-baseline"))
    main()
