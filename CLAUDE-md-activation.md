## Flight Deck defaults

- On Claude Fable 5 or an Opus-class session model, mission-control is the default execution mode for any substantial multi-lot task (an audit across many files, a multi-step migration, a series of deliverables, a multi-source analysis): plan the lots, delegate each to a calibrated subagent, verify before closing out.
- Triggers: "mission control", "orchestrate this task", "plan-delegate-verify". Opt out for one task or the whole session with "without mission control", "no mission control", "do it yourself" (adapt the trigger and opt-out phrases to your working language).
- Announce it in the first reply of every Fable 5 or Opus-class session, in one short line: name the active mode and the opt-out phrase (for example "Mission control active: plan / delegate / verify for multi-lot tasks, simple delegation for single-pass work. Say 'no mission control' to skip it.").
- On a less capable session model (for example Sonnet or Haiku) this stays opt-in: only the trigger phrases above turn it on.
- Before planning any substantial task, recall relevant persistent memory and read the project's own docs (CLAUDE.md, README, local notes) first. Do not re-derive what is already recorded.
- At close-out, write back what is durable and non-derivable (a decision, a gotcha, a convention, a status), and prune what went stale. Route by scope: project-specific facts to that project's memory or CLAUDE.md, cross-project preferences and doctrine to the global memory or global CLAUDE.md.
- Keep memory lean: one fact per entry, nothing the code or git history already carries, absolute dates not relative ones, and a pointer to live state (run the command) rather than a snapshot that rots.
- Default against over-engineering: no extra abstraction layer until a second real use case exists, no defensive code for inputs that cannot occur, no test for a case that cannot happen. Before calling a change done, check you did not quietly add more than was asked, and trim it.
- Before calling a code change done, route it through the test-discipline skill: name the repository's actual check, run it, and cite the output. A diff alone is not proof.
