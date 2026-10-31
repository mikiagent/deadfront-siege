# Extraction status: the source wiki is gone (checked 2026-10-22)

`12_REFERENCE_INDEX_AND_EXTRACTION_PLAN.md` describes how to pull the real tables (918 skill nodes,
720 recipes, 220 species, 352 foods). That is not possible any more. Results, so this is not retried
blindly:

| Attempt | Result |
|---|---|
| `https://kghj76138.github.io/durango-homecoming-guide/en/index.html` | 404 - GitHub Pages "Site not found" |
| `https://kghj76138.github.io/` and the bare guide dir | 404 |
| `https://kghj138.github.io/durango-homecoming-guide/en/index.html` (variant spelling) | 404 |
| `https://github.com/kghj76138` | account exists, **0 public repositories** (`api.github.com/users/kghj76138/repos` returns `[]`) |
| `archive.org/wayback/available?.../en/skills.html` | 200 but `archived_snapshots: {}` - never archived |
| `web.archive.org/web/2024/.../en/skills.html` | 404 |
| DuckDuckGo search for `"durango-homecoming-guide"` | no mirror |

## What this means for jobs

The pack is **context and a template, not a dataset**. Every job that touches these systems:

1. Reads the topic file for the *shape* of the mechanic (which channels exist, which formulas, which
   ordering), and implements that shape against this project's own data.
2. Treats every quantity as `# ASSUMPTION` unless a PRD in `docs/prd/` or a spec in
   `docs/design/durango-prompts/` gives it. The pack's own README says the same: reconstruction values
   must never overwrite intended original-style balancing.
3. Does not invent a full 918-node skill tree, a 720-row recipe table, or a 220-species list to fill
   the gap. Add the rows the game actually needs, and say so in the report.

If the wiki reappears (new host, or the account publishes the repo again), re-run the checks above
before writing `12`'s CSVs; until then those tables do not exist offline.
