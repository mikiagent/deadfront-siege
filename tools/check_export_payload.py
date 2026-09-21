#!/usr/bin/env python3
"""Fail CI when authoring-source assets can leak into a shipping export."""
from pathlib import Path
import re, sys
root = Path(__file__).resolve().parents[1]
text = (root / "game/export_presets.cfg").read_text()
shipping = {"iOS", "Web", "PackAssets"}
errors = []
for block in text.split("[preset.")[1:]:
    name_match = re.search(r'^name="([^"]+)"', block, re.M)
    if not name_match or name_match.group(1) not in shipping:
        continue
    name = name_match.group(1)
    exclude = re.search(r'^exclude_filter="([^"]*)"', block, re.M)
    pattern = exclude.group(1) if exclude else ""
    if "assets/creatures/*/work/*" not in pattern:
        errors.append(f"{name}: creature work sources are not excluded")
    if not any(p in pattern for p in ("assets/characters/*/work/*", "assets/characters/survivor/work/*")):
        errors.append(f"{name}: character work sources are not excluded")
if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)
print("[payload] shipping presets exclude authoring work assets")
