"""Build every biome-prop GLB into game/assets/nature/biome/ and print one JSON line per asset.

Headless:  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P build_all.py -- [names...]
No names = every asset. Names may also be a group: vegetation, rocks, minerals.
Each asset is built, checked against its triangle budget (task BIOMEASSETS) and written; the run
exits non-zero if any asset is over budget, so the build is its own gate.
"""
import json
import os
import sys

sys.dont_write_bytecode = True  # keep __pycache__ out of the repo
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bp_lib  # noqa: E402
import minerals  # noqa: E402
import rocks  # noqa: E402
import vegetation  # noqa: E402

GROUPS = {"vegetation": vegetation.BUILDERS, "rocks": rocks.BUILDERS, "minerals": minerals.BUILDERS}
BUILDERS = {}
for g in GROUPS.values():
    BUILDERS.update(g)

# Triangle budgets from the task: small vegetation <= 800; mounds/logs/boulders <= 2500;
# (see the report for the minerals assumption)
# spires/mesas/cliffs <= 6000; anything else (crystals, rims, pebbles) <= 1500 # ASSUMPTION: the
# task gives no budget for the minerals group; they are small ground props like the vegetation.
BUDGET = {}
for k in ("reed_clump_a", "reed_clump_b", "plume_grass", "fern_clump_a", "fern_clump_b",
          "lily_pad_cluster", "aloe_flower"):
    BUDGET[k] = 800
for k in ("termite_mound_a", "termite_mound_b", "fallen_log_moss", "fallen_log_dry",
          "boulder_pile_a", "boulder_pile_b", "basalt_columns"):
    BUDGET[k] = 2500
for k in ("rock_spire_a", "rock_spire_b", "mesa_sandstone", "mesa_basalt", "cliff_chunk_red"):
    BUDGET[k] = 6000
for k in ("crystal_blue", "crystal_obsidian", "crystal_sulphur", "steam_vent", "hot_spring_rim",
          "pebble_patch"):
    BUDGET[k] = 1500


def main(names):
    if not names:
        names = list(BUILDERS)
    out = []
    over = []
    for n in names:
        if n in GROUPS:
            out.extend(main(list(GROUPS[n])))
            continue
        if n not in BUILDERS:
            raise SystemExit("unknown asset %r; known: %s" % (n, ", ".join(sorted(BUILDERS))))
        objs = BUILDERS[n]()
        info = bp_lib.export(objs, n)
        info["budget"] = BUDGET.get(n, 0)
        info["group"] = next((g for g, b in GROUPS.items() if n in b), "other")
        if info["tris"] > info["budget"]:
            over.append(info)
        out.append(info)
        print("[biomeprops] " + json.dumps(info))
    if over:
        for i in over:
            print("[biomeprops] OVER BUDGET %s: %d > %d tris" % (i["name"], i["tris"], i["budget"]))
        raise SystemExit(1)
    return out


_args = globals().get("ARGS")
if _args is None:
    _args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
main(list(_args))
