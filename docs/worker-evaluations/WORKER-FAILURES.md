# Worker failures

## C0 broad task stalled

- Model: `deepseek/deepseek-v4.1-flash-1017`; first session medium effort,
  second session low effort with 4,096 output tokens.
- Expected: test and implement the bounded C0 save ticket in a worktree.
- Observed: the first session ran for 7m 50s and produced repeated maximum-token
  responses without an accepted code change. A second session was also stopped
  before producing an accepted change. The first session reported about $0.05.
- Evidence: `c0-save-safety.yaml` and the local worker logs under
  `.claude/worktrees/c0-plan-jobs/c0-save-safety/.dsc/`. These logs are local,
  not committed; they may be unavailable on another machine.
- Classification: orchestration/capability boundary. The original task combined
  high-risk design, persistence, UI, compatibility and integration tests. Long
  responses were observed, but their precise cause has not been established.
- Correction: keep save design with the lead and delegate narrower independent
  checks. Validate by comparing completion and review outcomes on bounded tasks.

## Migration-analysis benchmark invented its source

- Session `20261027-041936-jji2`, model as above, effort `none`, read-only,
  six-turn ceiling, $0.10 cap; reported cost $0.00018583520571.
- Task: read `game/scripts/core/save_migrations.gd`, report supported schema
  versions, future-schema handling, and v2-to-v3 additions with actual lines.
- Expected: numeric schemas 0-3, future versions rejected, and
  `player.inventory_extras` plus `home.camp_layout` added by v2-to-v3.
- Actual: the worker invented a different file with semantic versions `1.0.0`
  through `3.0.0`, asserted future versions were not explicitly rejected, and
  reported unrelated invented fields. Its saved session contains no tool call.
- Classification: hallucination and instruction failure. A retry with an explicit
  read-first instruction, `--auto --readonly`, low effort and the same model
  did invoke `read_file` and correctly answered the three required facts with
  line citations (session `20261027-042020-rtut`, two calls, $0.00112103046).
  It also speculated that reassignment handled non-dictionary values, which was
  not established by the source. This single retry cannot isolate which changed
  setting caused the improvement or establish a reliable success rate.
- Reproduce with the exact prompt above using `dsc --readonly -p`, then compare
  against the checked-in `save_migrations.gd`. Do not accept uncited claims.

## Ambiguous gameplay request exhausted its turns

- Session `20261027-042219-93fb`, low effort, eight-turn ceiling, $0.10 cap;
  reported cost $0.00204126318.
- Task: inspect the existing world rules and identify missing owner decisions
  for a vague request to make gathering progression much faster; do not edit.
- Expected: identify the unspecified rate and approval requirements promptly.
- Actual: inspected multiple files, made no tracked edits, and exited with
  `max_turns` and no final answer. The sparse checkout limited available docs;
  this may have contributed, and the model's internal reasoning is not known.
- Classification: capability-boundary/escalation failure, with a possible context
  or orchestration contribution. Retry with an explicit instruction to stop after
  reading the named file and state the missing rate; verify an actual final answer.
- Retry `20261027-042334-o75u` ($0.00060892524, two calls) read the specified
  file and reported the missing rate and owner decisions without edits. It also
  referenced `DEEPSEEK.md` as the source of repository ownership, although the
  checked-out guide is `AGENTS.md`; treat that attribution as unverified. The
  prompt, read-only mode and turn budget changed, so this does not prove which
  change produced the better answer.

## Save safety review produced no findings

- Session `20261027-042757-avaf`, low effort, six-turn ceiling, $0.15 cap;
  reported cost $0.00497865654.
- Task: inspect the two in-progress save files and identify concrete data-loss
  or compatibility risks with exact citations, or state uncertainty.
- Actual: read both files and examined related code, then reached `max_turns`
  with no final answer. No review result can be accepted from this attempt.
- Classification: high-risk review exceeded this bounded session. The short
  turn limit and breadth of the request may have contributed. A future retry
  should isolate one failure path and require an answer after the named reads.

## Decision-trail review added a nonexistent row

- Session `20261027-043007-q4lx`, low effort, four-turn ceiling, $0.10 cap;
  reported cost $0.00128841966.
- Task: read the generated decision log once and flag evidence that did not
  establish its result. The user explicitly approved sending this log.
- Actual: identified real gaps between test claims and the referenced evidence,
  but described four data rows when the file had three. It explicitly did not
  inspect the referenced evidence or any transcript. Treat the review as partial.
- Classification: context/attention and evidence-verification limits. The
  requested single-read task did not ask it to inspect evidence, so the latter
  limitation is also an orchestration constraint rather than a model defect.
- After the handoff report was written, a second bounded review of the updated
  log and report (`20261027-043408-eq4o`, $0.00172757376) reached `max_turns`
  without a final review. Neither attempt reviewed the conversation transcript.
