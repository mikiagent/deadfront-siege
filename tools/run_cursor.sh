#!/usr/bin/env bash
# Drive Cursor's headless agent through one milestone prompt. The orchestrator
# (Claude Code) calls this so no prompt has to be pasted into the Cursor app.
# Usage: tools/run_cursor.sh <milestone-id> <prompt-file-under-docs/orchestration/prompts> ["extra instructions"]
# Logs to ~/Library/Caches/durango-cursor/<milestone>.log. Needs `cursor-agent login` once.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="$1"; FILE="$2"; EXTRA="${3:-}"
MODEL="${CURSOR_MODEL:-gpt-5.3-codex-high}"
LOGDIR="$HOME/Library/Caches/durango-cursor"; mkdir -p "$LOGDIR"
echo "===== START $NAME $(date +%H:%M) model=$MODEL =====" | tee -a "$LOGDIR/$NAME.log"
cursor-agent -p --force --trust --workspace "$ROOT" --model "$MODEL" --output-format text \
  "You are Cursor working on this repo. Read AGENTS.md, .cursor/rules/durango.mdc, and every docs/orchestration/prompts/addendum-*.md, then carry out docs/orchestration/prompts/$FILE completely. $EXTRA When every acceptance item passes, write the report the prompt names under docs/orchestration/reports/, run tools/smoke.sh, and commit with the message the prompt specifies. Do not start any other milestone. Finish by printing DONE $NAME and a five-line summary." 2>&1 | tee -a "$LOGDIR/$NAME.log"
echo "===== END $NAME exit=${PIPESTATUS[0]} $(date +%H:%M) =====" | tee -a "$LOGDIR/$NAME.log"
