#!/usr/bin/env bash
# Read-only spec for the dsc1 task: game/data/structures.json piece_tiers and placed_kinds.
# Exit 0 only when every row matches the formulas and table in TASK.md and nothing else changed.
cd "$(dirname "$0")" || exit 2
python3 -I - <<'PY'
import json, math, subprocess, sys

fails = []
def bad(msg):
    fails.append(msg)
    print("FAIL", msg)

def r(x):  # TASK.md rounding: floor(x + 0.5)
    return int(math.floor(x + 0.5))

try:
    raw = open("game/data/structures.json", encoding="utf-8").read()
    d = json.loads(raw)
except Exception as e:
    print("FAIL structures.json does not parse:", e); sys.exit(1)

base = json.loads(subprocess.run(["git", "show", "4fabbba:game/data/structures.json"],
                                 capture_output=True, text=True, check=True).stdout)

# 1. Only piece_tiers and placed_kinds may change; every other top-level key is byte-for-byte the same value.
if set(d.keys()) != set(base.keys()):
    bad("top-level keys changed: %s" % sorted(set(d.keys()) ^ set(base.keys())))
for k in base:
    if k in ("piece_tiers", "placed_kinds"):
        continue
    if d.get(k) != base[k]:
        bad("top-level %s changed" % k)

# 2. Only structures.json may differ from the base commit (TASK.md / verify / .dsc are untracked or ignored).
diff = subprocess.run(["git", "diff", "--name-only", "4fabbba", "--", "."], capture_output=True, text=True).stdout.split()
untracked = subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], capture_output=True, text=True).stdout.split()
allowed = {"game/data/structures.json", "TASK.md", "verify_structures.sh"}
for f in diff + untracked:
    if f not in allowed:
        bad("file outside the task changed or added: %s" % f)

# 3. Formatting: 2-space indent, as the file has today (json.dumps(indent=2) style; a trailing newline is optional).
if raw.rstrip("\n") != json.dumps(d, indent=2, ensure_ascii=False):
    bad("structures.json is not written as json.dumps(data, indent=2, ensure_ascii=False)")

SIZE = {"foundation": 1.5, "wall": 1.0, "doorway": 0.85, "window": 0.85, "door": 0.5, "ceiling": 1.0,
        "roof": 1.0, "roof_peak": 1.0, "pillar": 0.5, "stairs": 1.5, "ramp": 0.75}
TIER_HP = {"thatch": 400, "wood": 1200, "stone": 3000, "metal": 7000}
PRIMARY = {"thatch": ("branch", 4), "wood": ("plank", 4), "stone": ("stone", 8), "metal": ("iron_ingot", 4)}
BINDING = {"thatch": ("fibre_stalk", 4), "wood": ("twine", 2), "stone": ("plank", 2), "metal": ("stone", 4)}
KEYS = ["model", "max_durability", "material_slots", "minimum_level", "maximum_level", "required_skill_node",
        "required_building_ability", "supported_building_effects"]

pt = d.get("piece_tiers", {})
if list(pt.keys()) != list(d["pieces"].keys()):
    bad("piece_tiers keys must be exactly the pieces keys in the same order: %s" % list(pt.keys()))
for piece, size in SIZE.items():
    row = pt.get(piece)
    if not isinstance(row, dict):
        bad("piece_tiers.%s missing" % piece); continue
    if list(row.keys()) != ["thatch", "wood", "stone", "metal"]:
        bad("piece_tiers.%s tiers must be thatch, wood, stone, metal in that order" % piece)
    for tier in TIER_HP:
        bp = row.get(tier)
        if not isinstance(bp, dict):
            bad("%s.%s missing" % (piece, tier)); continue
        if list(bp.keys()) != KEYS:
            bad("%s.%s keys/order %s" % (piece, tier, list(bp.keys())))
        want = {
            "model": "",
            "max_durability": r(TIER_HP[tier] * size),
            "material_slots": [
                {"role": "primary", "item": PRIMARY[tier][0], "quantity": max(1, r(PRIMARY[tier][1] * size)),
                 "counts_for_level": True, "counts_for_attributes": True},
                {"role": "binding", "item": BINDING[tier][0], "quantity": max(1, r(BINDING[tier][1] * size)),
                 "counts_for_level": True, "counts_for_attributes": False},
            ],
            "minimum_level": 1, "maximum_level": 60, "required_skill_node": "",
            "required_building_ability": 0, "supported_building_effects": ["durability"],
        }
        for k, v in want.items():
            got = bp.get(k)
            if got != v or type(got) is not type(v):
                bad("%s.%s.%s = %r, want %r" % (piece, tier, k, got, v))
        for s in bp.get("material_slots", []):
            if list(s.keys()) != ["role", "item", "quantity", "counts_for_level", "counts_for_attributes"]:
                bad("%s.%s slot key order %s" % (piece, tier, list(s.keys())))

# The two rows that were already there stay identical.
for piece in ("foundation", "wall"):
    if pt.get(piece) != base["piece_tiers"][piece]:
        bad("piece_tiers.%s changed from the base rows" % piece)

PLACED = {
    "default": (300, [("branch", 2), ("fibre_stalk", 2)]),
    "catapult": (200, [("plank", 4), ("rope", 2)]),
    "fence": (250, [("branch", 2), ("twine", 1)]),
    "gate": (300, [("branch", 3), ("twine", 1)]),
    "tent": (200, [("fibre_stalk", 4), ("branch", 2)]),
    "canvas_tent": (300, [("twine", 3), ("branch", 2)]),
    "log_shelter": (900, [("plank", 4), ("twine", 2)]),
    "straw_roll": (100, [("fibre_stalk", 3)]),
    "cabin_bed": (400, [("plank", 3), ("twine", 1)]),
    "basket": (150, [("fibre_stalk", 3)]),
    "sign": (150, [("branch", 2)]),
    "workbench": (500, [("branch", 4), ("twine", 2)]),
    "drying_rack": (250, [("branch", 3), ("twine", 1)]),
    "smoker": (500, [("stone", 4), ("clay", 2)]),
    "crock_pot": (400, [("clay", 3)]),
    "mortar": (400, [("stone", 3)]),
    "stone_grill": (600, [("stone", 5)]),
    "steamer": (400, [("clay", 2), ("branch", 2)]),
    "well": (1200, [("stone", 6), ("plank", 2)]),
    "bonfire": (300, [("branch", 3)]),
    "campfire": (200, [("branch", 2)]),
    "stone_fire_pit": (700, [("stone", 4)]),
    "makeshift_taming_pen": (600, [("branch", 4), ("twine", 2)]),
    "field_small": (300, [("branch", 2), ("fibre_stalk", 2)]),
    "field_large": (500, [("branch", 4), ("fibre_stalk", 4)]),
}
pk = d.get("placed_kinds", {})
if list(pk.keys()) != list(PLACED.keys()):
    bad("placed_kinds keys/order %s" % list(pk.keys()))
for kind, (hp, rep) in PLACED.items():
    row = pk.get(kind)
    want = {"max_durability": hp, "repair": [{"item": i, "quantity": q} for i, q in rep]}
    if row != want:
        bad("placed_kinds.%s = %r, want %r" % (kind, row, want))

# Every item named anywhere exists in items.json (no invented materials).
items = {r["id"] for r in json.load(open("game/data/items.json", encoding="utf-8"))["items"]}
for piece, row in pt.items():
    for tier, bp in row.items():
        for s in bp.get("material_slots", []):
            if s.get("item") not in items:
                bad("%s.%s uses unknown item %s" % (piece, tier, s.get("item")))
for kind, row in pk.items():
    for s in (row or {}).get("repair", []):
        if s.get("item") not in items:
            bad("placed_kinds.%s uses unknown item %s" % (kind, s.get("item")))

total = sum(len(v) for v in pt.values())
print("rows piece_tiers=%d placed_kinds=%d" % (total, len(pk)))
if fails:
    print("VERIFY FAIL count=%d" % len(fails)); sys.exit(1)
print("VERIFY PASS")
PY
