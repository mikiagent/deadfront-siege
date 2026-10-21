#!/usr/bin/env bash
# Milestone gate for SPRITES2D: M1-M2 -> stage 1 (cut-outs), M3+ -> stage 2 (+ mapping). The full gate runs at the end.
s=1; [ "${1:-1}" -ge 3 ] && s=2
exec bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_sprites2d.sh "$s"
