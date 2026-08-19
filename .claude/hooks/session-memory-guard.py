#!/usr/bin/env python3
"""Stop hook: refuse to end a working session until memory has been written.

Design decisions (Marina, 2026-08-19) — the reasoning matters more than the code:

  * EVENT: `Stop`. There is no SessionEnd event; `Stop` fires when Claude
    finishes responding, and exit 2 there means "do not stop, keep working"
    (not "kill the action", which is what exit 2 means in PreToolUse).

  * PROOF OF COMPLIANCE: the newest mtime among the project's memory `*.md`
    files, compared against this session's start time. Deliberately NOT a
    marker file written by Claude — a marker is a claim by the same actor
    the hook exists to distrust. An mtime is evidence produced by the act.

  * TRIGGER: only complains if this session actually did something — a file
    changed on disk, or a commit landed, both scoped to since-session-start.
    A read-only Q&A session must stay silent or the hook gets disabled.

  * NO ESCAPE HATCH: it blocks every turn until memory is written. Strongest
    guarantee, and it means a bug here wedges the session — hence the
    disable instructions in the blocking message.

  * FAIL-CLOSED, unlike the other two hooks in this directory. If it cannot
    evaluate its own check it says so loudly rather than exiting 0, because
    "I found nothing" and "I checked nothing" must not be the same exit code.
"""
import sys
import os
import json
import pathlib
import subprocess

DISABLE_HINT = (
    "To turn this off: remove the Stop entry from .claude/settings.json, "
    "or delete .claude/hooks/session-memory-guard.py"
)


def session_start(transcript_path):
    """Epoch seconds when this session began (transcript file creation)."""
    st = os.stat(transcript_path)
    return getattr(st, "st_birthtime", st.st_ctime)


def memory_dir(cwd):
    """~/.claude/projects/<cwd-with-slashes-as-dashes>/memory"""
    return pathlib.Path.home() / ".claude" / "projects" / cwd.replace("/", "-") / "memory"


def newest_memory_mtime(mem):
    times = [p.stat().st_mtime for p in mem.glob("*.md")]
    return max(times) if times else 0.0


def git(cwd, args):
    out = subprocess.run(
        ["git"] + args, cwd=cwd, capture_output=True, text=True, timeout=10
    )
    return out.stdout


def did_work(cwd, since):
    """True if this session changed files or landed commits."""
    # `--since` is inclusive, so compare timestamps strictly: a commit made in
    # the same second the session started belongs to the previous session.
    stamps = git(cwd, ["log", f"--since=@{int(since)}", "--format=%ct"]).split()
    if any(int(c) > since for c in stamps):
        return True
    for line in git(cwd, ["status", "--porcelain"]).splitlines():
        path = line[3:].split(" -> ")[-1].strip().strip('"')
        try:
            if os.path.getmtime(os.path.join(cwd, path)) > since:
                return True
        except OSError:
            continue
    return False


def main():
    data = json.load(sys.stdin)
    cwd = data.get("cwd") or os.getcwd()
    transcript = data.get("transcript_path")
    if not transcript or not os.path.exists(transcript):
        raise RuntimeError("no transcript_path — cannot determine session start")

    start = session_start(transcript)
    mem = memory_dir(cwd)

    if not did_work(cwd, start):
        sys.exit(0)                                  # read-only session: stay quiet
    if newest_memory_mtime(mem) > start:
        sys.exit(0)                                  # memory already written

    sys.stderr.write(
        "SESSION MEMORY NOT WRITTEN. This session changed files or landed "
        "commits, but no memory file has been updated.\n\n"
        f"Write or update a memory file in:\n  {mem}\n\n"
        "Follow the format in MEMORY.md (frontmatter with name/description/"
        "metadata.type), then add or update its one-line pointer in MEMORY.md. "
        "Update an existing file rather than creating a near-duplicate.\n\n"
        f"{DISABLE_HINT}\n"
    )
    sys.exit(2)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Fail CLOSED on purpose: an unevaluated check is not a passing check.
        sys.stderr.write(
            f"session-memory-guard could not run its check: {e}\n"
            "Treating this as unverified rather than clean. "
            f"{DISABLE_HINT}\n"
        )
        sys.exit(2)
