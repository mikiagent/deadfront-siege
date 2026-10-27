# DeepSeek worker update patch proposal

These are proposals, not changes to production worker configuration.

1. **Require evidence of reads for source-analysis tasks.** The migration
   benchmark invented a file and made no tool call. A candidate task footer is:
   `Read the named source file before answering. Cite exact lines. If the read
   fails, report the failure; do not infer file contents.` Verify on the same
   task and on unrelated source files. A concrete, unapplied candidate is
   `patches/candidate-read-first.patch`. Roll back by removing the footer.
2. **Decompose high-risk assignments.** The broad C0 task stalled. Keep save
   design and integration with the lead; give workers one fixture, validator or
   narrowly scoped regression at a time. Compare accepted work and review time
   against the broad task. Roll back by restoring the previous task template.
3. **Add a source-analysis gate.** A disposable harness could check that the
   worker session contains a read call and that reported citations resolve to
   the requested file. A read call alone cannot prove the answer is correct, so
   retain an independent factual check. Evaluate false positives before changing
   the CLI. No infrastructure patch has been applied.

Priority is based on observed severity, not a measured improvement. Verify any
candidate in disposable worktrees before seeking approval for shared settings.
