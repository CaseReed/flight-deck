# Flight Deck hooks

Two `PreToolUse` hooks. Register them in `~/.claude/settings.json` under the `hooks` key:

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
    ]
  }
}
```

Adjust the `command` paths to wherever each script actually lives on disk once installed (they must be executable, `chmod +x`).

## Requirements

Both hooks require `jq` on PATH. If `jq` is missing, they fail open: they exit without doing anything, so a user without `jq` gets no fanout protection and no push reminder, and no error either. Install `jq` before relying on them (for example `brew install jq` on macOS, or your distro's package on Linux).

## What each hook does

- **fable5-fanout-guard.sh**: on a Fable 5 session, blocks any `Agent` call whose `model` parameter is not an allowed cheaper tier (`sonnet`, `haiku`, `opus`, or their `claude-sonnet*` / `claude-haiku*` / `claude-opus*` long forms), which includes both a call with no model set and a call with an explicit but disallowed model, and blocks `Workflow` calls outright, because both inherit the session model and can silently burn frontier quota across many subagents. It is a real gate: it can deny the tool call (`permissionDecision: deny`) unless the model is one of the allowed tiers or the user's approval token `FABLE_OK` is present. On any other session model it is a no-op. Limit: a subagent whose model is pinned only in its own `.claude/agents/*.md` frontmatter is invisible to the hook, since the guard only reads the `model` parameter passed directly on the tool call. A call that omits `model` and relies on that frontmatter pin gets denied even if the pinned model is already a cheap tier; the workaround is to also pass the same model explicitly as the call's `model` parameter.
- **verify-reminder.sh**: watches `Bash` calls and, only when the command is a `git push`, reminds the user to confirm the change was verified first (the project's own named test/build check run, output cited) before pushing. It never inspects or names a specific repo's commands.
- **verify-reminder.sh is NON-blocking.** It never denies or holds up the tool call, and it emits no permission decision at all, no `allow`, no `deny`, no `ask`; it only prints a reminder through the `systemMessage` field. Every push proceeds through Claude Code's normal permission flow regardless of what the hook prints; it is a nudge, not a gate.
- Both hooks fail open: if stdin is empty, malformed, `jq` is missing, or (fable5-fanout-guard.sh only) the session model cannot be determined from the transcript, they exit `0` without touching the tool call. As with the frontmatter-pinning limit above, this is silent: no error, no denial, just no protection for that call.
