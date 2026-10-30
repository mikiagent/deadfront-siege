---
name: goldfish-review
description: Review a WildLands package brief, design doc or finished branch with a fresh-context subagent that has not seen the conversation, checking it against canonical design and for missing decisions. Use before building a package and before integrating one.
---

# Goldfish review

Proposed 2026-10-30 in `docs/orchestration/reports/claude-studio-workflow.md`. The idea comes from
Google's Elephant-Goldfish Model (Apache-2.0, https://github.com/google/elephant-goldfish-model):
the agent that holds the context writes, a reviewer with no conversation history reviews. EGM runs
five reviewer stages with interactive gates; this project runs one or two read-only reviewers and
no questions, because Milan works asynchronously and pays for every agent.

A review in the same context as the author is not a goldfish review. If you cannot spawn a fresh
subagent, say so and stop.

## Two modes

**design** (before code). Target: a brief from `package-brief` or a doc under `docs/design/`.
The reviewer answers:
1. Does every requirement trace to a quoted canonical source (vision, design doc, Durango prompt,
   a dated Milan decision)? List any that do not: those are invented rules.
2. What does the implementer still have to decide? Each one is either a Milan gate or needs an
   `# ASSUMPTION:` default written down now.
3. Does it contradict another canonical doc, `docs/current/`, or the code as it is? Quote both.
4. Can every acceptance item fail? A test that cannot fail is a blocker.
5. Scope creep: anything beyond the roadmap row or Milan's ask.

**branch** (before integration). Target: `git diff claude/mmo-overhaul...claude/mmo-<key>` plus
the brief and the package report. The reviewer answers:
1. Does the diff do what the brief says, and nothing else? List out-of-scope files.
2. Did it touch integrator-only or another package's files?
3. Any gameplay or balance change not in the brief (numbers, rules, new mechanics)?
4. Are the new tests real (fail on the base, pass on the branch)? Rerun them; do not trust the report.
5. Does `docs/current/` describe what the code now does, without rewriting `docs/vision/`?

## How to spawn

Use the Agent tool with a general-purpose agent. Give it only: the target path(s), the mode, the
five questions above, the read order from `docs/agent-context.md`, and this instruction: "You are
read-only. Do not edit files. You have not seen the discussion that produced this; judge only what
is written and what the repository shows." Do not paste your own conclusions into the prompt.

One reviewer is the default. Add a second only for FABLE-CRITICAL work (saves, economy, capture,
combat/progression): give it the same prompt so the two can be compared.

## Rounds

Cap 3 rounds per target. Round 1 reviews everything. Round 2+ gets the previous findings and the
new diff only, and re-checks just those fixes. Each finding names its problem class (for example
"food consumed before validation", "test cannot fail", "hot file edited without hook") so the
builder fixes every instance of that class, not only the line cited. Record the round number and
findings in the package report. After round 3 with Blockers left, stop and escalate.

Review depth follows GAUNTLET's risk class: OPUS-SAFE one reviewer, FABLE-CRITICAL two. If
`docs/review.md` exists, the reviewer reads it first.

## Output

The reviewer returns findings as `Blocker | Major | Nit`, each with file/line and the source it
relies on. The lead writes them to `docs/orchestration/briefs/<key>.review.md` (design) or appends
to the package report (branch), then fixes or rejects each one with a reason. Blockers stop the
package. Findings about Milan's design choices go to Milan as one question, not as edits to vision.
