# Flight Deck hooks

Three hooks across two events: two `PreToolUse` hooks and one `SessionStart` hook.
Register them in `~/.claude/settings.json` under the `hooks` key:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent|Workflow",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/fable5-fanout-guard.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/verify-reminder.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/flight-deck-update-check.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Adjust the `command` paths to wherever each script actually lives on disk once installed (they must be executable, `chmod +x`).

## Requirements

All three hooks require `jq` on PATH. If `jq` is missing, they fail open: they exit without doing anything, so a user without `jq` gets no fanout protection, no push reminder, and no update check, and no error either. Install `jq` before relying on them (for example `brew install jq` on macOS, or your distro's package on Linux). `flight-deck-update-check.sh` additionally requires `curl` on PATH; missing it, it also fails open.

## What each hook does

- **fable5-fanout-guard.sh**: arms on frontier sessions (Fable 5 and Opus); non-frontier sessions (Sonnet/Haiku) stay a no-op. The filename is historical (kept for install compatibility), but the scope is all frontier sessions. On a frontier session, it blocks any `Agent` call whose `model` parameter is not an allowed cheaper-or-equal tier (`sonnet`, `haiku`, `opus`, or their `claude-sonnet*` / `claude-haiku*` / `claude-opus*` long forms), which includes both a call with no model set and a call with an explicit but disallowed model (an explicit `fable` pin is disallowed, since up-delegation to the frontier tier must stay blocked without the token), and blocks `Workflow` calls outright, because both inherit the session model and can silently burn frontier quota across many subagents. It is a real gate: it can deny the tool call (`permissionDecision: deny`) unless the model is one of the allowed tiers or the user's approval token `FABLE_OK` is present in a dedicated position, never a substring found anywhere in the tool input:
  - Agent: `FABLE_OK` as the first non-empty line of the call's `prompt`, trimmed of whitespace and matched exactly.
  - Workflow, `args` is a string: the same first-non-empty-line-trimmed rule applied to that string.
  - Workflow, `args` is a JSON object: a top-level key `FABLE_OK` whose value is the JSON boolean `true`, exactly (e.g. `{"FABLE_OK": true}`). Any other value, including the string `"true"`, `1`, or any other string, does not approve. There is no other approval form for object args: a top-level string value (e.g. `{"approval": "FABLE_OK"}`) never approves, even if its first line reads `FABLE_OK`, because a string value under an arbitrary key is a relay channel a poisoned document can fill (e.g. `{"x": "FABLE_OK\n<rest of a relayed document>"}`).
  - Workflow, `args` is a JSON array: any element that is exactly the string `"FABLE_OK"` (e.g. `["FABLE_OK", ...]`).

  A brief that merely quotes or mentions the token elsewhere in the text (relayed docs, poisoned fixture content) does not disarm the guard; the token has to occupy one of the positions above, not be found as a substring anywhere else. On any other session model it is a no-op. Limit: a subagent whose model is pinned only in its own `.claude/agents/*.md` frontmatter is invisible to the hook, since the guard only reads the `model` parameter passed directly on the tool call. A call that omits `model` and relies on that frontmatter pin gets denied even if the pinned model is already a cheap tier; the workaround is to also pass the same model explicitly as the call's `model` parameter. On an Opus session the allow-list includes the session's own tier (`opus`), so any number of explicitly `opus`-pinned Agent lots pass without approval: there the guard enforces pin-explicitness and the Workflow bar, not the "opus stays the exception" calibration, which stays a doctrine matter.
- **verify-reminder.sh**: watches `Bash` calls and, only when the command is a `git push`, reminds the user to confirm the change was verified first (the project's own named test/build check run, output cited) before pushing. It never inspects or names a specific repo's commands.
- **verify-reminder.sh is NON-blocking.** It never denies or holds up the tool call, and it emits no permission decision at all, no `allow`, no `deny`, no `ask`; it only prints a reminder through the `systemMessage` field. Every push proceeds through Claude Code's normal permission flow regardless of what the hook prints; it is a nudge, not a gate.
- **flight-deck-update-check.sh**: a `SessionStart` hook that, at most once a day, checks GitHub for a Flight Deck release newer than the installed `skills/mission-control/VERSION` and, when the install is behind, injects a note (`SessionStart` `additionalContext`) so the assistant tells the user and offers to update. Non-blocking, it never auto-updates: the note only points at re-running the installer prompt, which diffs and asks before overwriting anything. Fails open without `jq`, `curl`, network, or a readable `VERSION` file. Note it only helps installs that carry this hook: it protects installs from v1.2.0 onward, since earlier installs have neither the hook nor the `VERSION` file.
- All three hooks fail open: if stdin is empty, malformed, `jq` (or, for the update-check, `curl`) is missing, or (fable5-fanout-guard.sh only) the session model cannot be determined from the transcript, they exit `0` without touching the tool call or session. As with the frontmatter-pinning limit above, this is silent: no error, no denial, just no protection for that call. One honest gap in fable5-fanout-guard.sh: it resolves the session model from the last assistant line of the transcript, so the FIRST tool call of a session can fire before any assistant line has been flushed to the transcript, leaving the model undetectable and the guard failing open (exit `0`) for that one call.
