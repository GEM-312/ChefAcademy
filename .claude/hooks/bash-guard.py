#!/usr/bin/env python3
"""PreToolUse Bash guard for ChefAcademy.

Hard-blocks two mistakes that CLAUDE.md only described in prose:
  1. Killing actool/ibtoold — wedges the asset catalog and needs a Mac reboot.
  2. Inlining a secret into a Bash command — leaks into settings.local.json forever.

Reads the tool-call JSON on stdin; exit 2 blocks the call and shows the message
to Claude. Any parse error → exit 0 (fail open: never break normal commands).
"""
import sys
import re
import json

try:
    data = json.load(sys.stdin)
    cmd = data.get("tool_input", {}).get("command", "") or ""
except Exception:
    sys.exit(0)

# 1. actool / ibtoold kill guard (the Mac-reboot mistake)
if re.search(r"\b(pkill|killall)\b.*(actool|ibtoold)", cmd) or \
   re.search(r"\bkill\b.*(actool|ibtoold)", cmd):
    sys.stderr.write(
        "BLOCKED: killing actool/ibtoold wedges the asset catalog and needs a "
        "Mac reboot (CLAUDE.md Roadmap → Durable constraints). Quit/relaunch "
        "Xcode instead; never pkill these.\n"
    )
    sys.exit(2)

# 2. CLI xcodebuild build guard. Repeated CLI builds orphan actool and wedge
# the asset catalog (needs a Mac reboot). Match only a real build INVOCATION —
# `xcodebuild` followed (same command segment) by a build action or a
# build-config flag — so prose/commit messages that merely mention the word,
# and info-only calls like `xcodebuild -version`, are not blocked.
if re.search(
    r"\bxcodebuild\b[^\n;&|]*?\s"
    r"(build|clean|test|archive|analyze|install|docbuild|"
    r"-scheme|-project|-workspace|-target|-destination|-configuration|"
    r"-sdk|-arch|-derivedDataPath|-resultBundlePath|-only-testing)\b",
    cmd,
):
    sys.stderr.write(
        "BLOCKED: CLI xcodebuild builds are banned in ChefAcademy — repeated "
        "CLI builds orphan actool and wedge the asset catalog (needs a Mac "
        "reboot). Build in Xcode (Clean Build Folder -> Build) or read the "
        "xcactivitylog. (CLAUDE.md §7 / Roadmap durable constraints)\n"
    )
    sys.exit(2)

# 3. inlined-secret guard (CLAUDE.md §11). Require a real secret-shaped value
# (a long token), so merely *mentioning* the patterns (docs, commit messages,
# grep) doesn't trip it — only an actual inlined key/token does.
_SECRET = (
    r"sk-ant-[A-Za-z0-9_-]{16,}"
    r"|(?:PROXY_TOKEN|ANTHROPIC_API_KEY)\s*=\s*['\"]?[A-Za-z0-9_-]{16,}"
    r"|Authorization:\s*Bearer\s+[A-Za-z0-9._-]{16,}"
)
if re.search(_SECRET, cmd):
    sys.stderr.write(
        "BLOCKED: this command looks like it inlines a secret. Per CLAUDE.md §11, "
        "`export VAR=...` in your own shell (or `export VAR=$(cat gitignored-file)`) "
        "and run the bare command — never put the secret in the command string.\n"
    )
    sys.exit(2)

sys.exit(0)
