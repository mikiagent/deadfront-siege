#!/usr/bin/env python3
"""Generate the wiki's game-data truth pages + owner-editable CSV sheets.

Source of truth: the canon worktree's `game/data/*.json` (the build's own data).
Emits (all generated files carry a generation header; never hand-edit them):
  docs/current/recipes.md       recipe data + repair tiers + station times
  docs/current/world-biomes.md  island roster, per-climate flora/materials, fauna, butchering
  docs/current/items-traits.md  full item catalog with rarity/attributes, food effects, traits
  <data>/../data_sheets/*.csv   the same rows as flat spreadsheets the owner can edit
                                (Numbers / Excel / Google Sheets all open CSV natively)

Run from the canon repo root:  python3 tools/docs_wiki/gen_game_data.py
After editing a sheet, ask the agent to sync it back; the sync validates ids and
rewrites only the changed values (the round-trip lives in sync_game_data.py).
Generation refuses to replace a differing existing sheet or sheet notes unless
--force-sheets is explicitly passed. Sync owner edits first; forcing may discard them.
"""
import argparse
import csv
import json
import shutil
import tempfile
from collections import OrderedDict
from datetime import date
from pathlib import Path


def load(data: Path, name: str):
    with open(data / name) as f:
        return json.load(f)


def attrs(d) -> str:
    if isinstance(d, dict):
        return ", ".join("%s=%s" % (k, v) for k, v in d.items())
    if isinstance(d, list):
        return "; ".join(str(x) for x in d)
    return str(d)


def slots_txt(slots) -> str:
    parts = []
    for s in slots or []:
        key = s.get("category") or s.get("id") or "?"
        txt = "%s x%s" % (key, s.get("count", 1))
        if s.get("primary"):
            txt += " (primary)"
        parts.append(txt)
    return "; ".join(parts)


def write_md(lines, path: Path, title: str) -> None:
    body = lines[:]
    header = "> Generated %s by `tools/docs_wiki/gen_game_data.py` from the build's own data. Never hand-edit; re-run after any balance pass.\n" % date.today().isoformat()
    text = "# %s\n\n%s\n%s\n" % (title, header, "\n".join(body))
    path.write_text(text)


def write_csv(path: Path, header, rows) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)


def dict_cell(v) -> str:
    """A dict/list rendered JSON for a CSV cell; empty stays truly empty."""
    if not v:
        return ""
    return json.dumps(v)


def energy_cell(f) -> str:
    en = f.get("energy") or {}
    if not en:
        return ""
    return " ".join("%s=%s" % (k, v) for k, v in sorted(en.items()))


# ------------------------------------------------------------------ recipes

def gen_recipes(data: Path, docs: Path, sheets: Path) -> None:
    rec = load(data, "recipes.json")
    items = {r["id"]: r for r in load(data, "items.json")["items"]}
    proc = load(data, "processing.json")
    rows = rec["recipes"]

    name = lambda i: items.get(i, {}).get("display_name", str(i))
    L = []
    a = L.append
    a("`%d recipes` from `game/data/recipes.json`; station-only workflow times from `game/data/processing.json`." % len(rows))
    a("")
    a("These rows describe game data; a row alone does not prove that its output is playable. "
      "`min skill` is the recipe's minimum level gate when greater than zero; the gate also "
      "checks the resulting item level. Other gates may apply. `ability target` affects success "
      "chance rather than imposing a hard gate. `recipe max_level` is the configured output-level "
      "cap; the actual result also depends on materials, skill, and runtime bounds. Absent values use the defaults in "
      "`game/scripts/items/crafting.gd`: minimum 0, ability 0, and output cap 60.")
    a("")
    by_station = OrderedDict()
    for r in rows:
        by_station.setdefault(r.get("station") or "hand", []).append(r)
    for st, list_ in by_station.items():
        if st == "hand":
            a("## Hand crafting")
        else:
            kind = proc.get("stations", {}).get(st, {})
            a("## %s (%s)" % (kind.get("label", st), st))
            times = kind.get("recipes", {})
            if times:
                a("")
                a("Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: " + ", ".join("`%s` %ss" % (rid, td.get("seconds", "?")) for rid, td in sorted(times.items())) + ".")
        a("")
        a("| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |")
        a("|---|---|---|---|---|---|---|---|---|")
        for r in list_:
            out_row = "%s x%s" % (name(r["output"]["id"]), r["output"].get("count", 1))
            skill = r.get("skill", "processing")
            step = []
            if r.get("process_step"):
                step.append("%s +%s" % (r["process_step"], r.get("process_add", 0)))
            a("| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                r["id"], out_row, slots_txt(r.get("slots")), skill,
                r.get("min_level", 0), max(0, r.get("required_ability", 0)), r.get("max_level", 60),
                r.get("seconds", "?"), "; ".join(step)))
        a("")
    reps = rec.get("repairs", [])
    if reps:
        a("## Repairs — per-tier cost")
        a("")
        a("One unit of the tier's material restores `restore_fraction` of max durability at the named station (ASSUMPTION values, W2-PROCESS/W2-CRAFT).")
        a("")
        a("| tier | station | input | restore |")
        a("|---|---|---|---|")
        for r in reps:
            a("| `%s` | `%s` | %s | %s |" % (r.get("tier", "?"), r.get("station", "?"), slots_txt(r.get("slots")), r.get("restore_fraction", "?")))
        a("")
    write_md(L, docs / "recipes.md", "Crafting recipes — game data catalog")

    write_csv(sheets / "recipes.csv",
              ["id", "display_name", "skill", "max_level", "station", "seconds", "slots", "output_id", "output_count", "process_step", "process_add"],
              [[r["id"], r.get("display_name", ""), r.get("skill", ""), r.get("max_level", ""),
                r.get("station") or "hand", r.get("seconds", ""),
                "; ".join("%s=%s" % (x.get("category", x.get("id", "?")), x.get("count", 1)) for x in (r.get("slots") or [])),
                r["output"]["id"], r["output"].get("count", 1), r.get("process_step", ""), r.get("process_add", "")] for r in rows])
    write_csv(sheets / "repairs.csv",
              ["tier", "station", "input", "count", "restore_fraction"],
              [[r.get("tier", ""), r.get("station", ""), (r.get("slots") or [{}])[0].get("category", ""),
                (r.get("slots") or [{}])[0].get("count", 1), r.get("restore_fraction", "")] for r in reps])
    write_csv(sheets / "processing.csv",
              ["station", "label", "slots", "fx", "recipe", "seconds"],
              [[sid, k.get("label", ""), k.get("slots", ""), k.get("fx", ""), rid, td.get("seconds", "")]
               for sid, k in sorted(proc.get("stations", {}).items())
               for rid, td in sorted((k.get("recipes") or {}).items())])


# ------------------------------------------------------------------ biomes

def island_row(i):
    """Island files vary in vintage; the id suffix encodes climate + tier, so fall back to it."""
    import re
    m = re.match(r"^(.*)_(\d+)$", str(i["id"]))
    climate = i.get("climate") or (m.group(1) if m else "")
    tier = i.get("tier") or (int(m.group(2)) if m else "")
    kind = i.get("kind") or ("private" if str(i["id"]) == "home_grassland" else "unstable")
    name = i.get("display_name") or ""
    if not name:
        name = "%s %s" % (kind.title(), climate.replace("_", " ").title())
    return [i["id"], name, climate, tier, kind, i.get("permanent", ""), i.get("lifetime_seconds", ""), str(i.get("size_m", ""))]


def gen_biomes(data: Path, docs: Path, sheets: Path) -> None:
    cl = load(data, "world/climates.json")
    isl = [load(data, "islands/%s" % f.name) for f in sorted(Path(data, "islands").glob("*.json"))]
    but = load(data, "butchering.json").get("species", {})
    creatures = []
    for f in sorted(Path(data, "creatures").glob("*.json")):
        d = load(data, "creatures/%s" % f.name)
        if "species" in d:
            creatures.append((d, but.get(f.name.replace(".json", ""), {})))
    creatures.sort(key=lambda t: (t[0].get("tier", 0), t[0].get("species", "")))

    L = []
    a = L.append
    a("Sources: `game/data/islands/*.json`, `game/data/world/climates.json`, `game/data/creatures/*.json`, `game/data/butchering.json`.")
    a("")
    a("## Island roster (%d)" % len(isl))
    a("")
    a("| island | name | climate | tier | kind | permanent | lifetime (s) |")
    a("|---|---|---|---|---|---|---|")
    for i in isl:
        r = island_row(i)
        a("| `%s` | %s | %s | %s | %s | %s | %s |" % tuple(r[:7]))
    a("")
    a("## Climates — flora & gatherable materials")
    a("")
    for cid in sorted(cl):
        c = cl[cid]
        if cid.startswith("_") or not c.get("tiers"):
            continue
        home = " — **the private home island**" if c.get("home") else ""
        a("### %s — tiers %s%s" % (cid, ", ".join("L%s" % t for t in c["tiers"]), home))
        a("")
        res = c.get("resist", [])
        if res:
            a("- Survival resist needed: %s." % ", ".join("`%s`" % r for r in res))
        veg = c.get("vegetation", [])
        if veg:
            a("- Vegetation families: %s." % ", ".join("`%s`" % v for v in veg))
        mats = []
        for m in c.get("materials", []):
            mats.append("`%s`%s" % (m["id"], " *(attr: %s)*" % m["attr"] if m.get("attr") else ""))
        if mats:
            a("- Gatherable materials (yellow-pip latent attr when noted): %s." % ", ".join(mats))
        a("")
    a("A climate's `materials` list is what its island generator may place; gather yields per family are the gather-system's own table (`world/rules.json`).")
    a("")
    a("## Fauna (%d species)" % len(creatures))
    a("")
    a("| tier | species | climate | clade | period | length (m) |")
    a("|---|---|---|---|---|---|")
    for d, _ in creatures:
        a("| %s | **%s** | %s | %s | %s | %s |" % (
            d.get("tier"), d.get("species"), d.get("climate"), d.get("clade", ""), d.get("period", ""), d.get("real_length_m", "")))
    a("")
    a("## Butchering drops per species")
    a("")
    a("`base` drops fall on every kill, counts scaled by the local survivor's best knife tier (+15% per tier above stone, 0.75x with no knife, never below 1) and Butchering level (+1% per level); `rare` drops need butcher skill at least the listed level and then roll a chance (default 0.12, +15% per knife tier, cap 0.6). Any part a Butchering skill node gates waits until that node is learned. Numbers: `game/data/loot_tables.json` `butcher`; code: `game/scripts/gather/loot_roller.gd` `roll_carcass`.")
    a("")
    for d, b in creatures:
        if not b:
            continue
        a("- **%s** — base: %s; rare: %s" % (
            d.get("species"),
            "; ".join("`%s` %s–%s" % (x["id"], x.get("min"), x.get("max")) for x in b.get("base", [])),
            "; ".join("`%s` %s–%s (skill %s)" % (x["id"], x.get("min"), x.get("max"), x.get("skill", "?")) for x in b.get("rare", []))))
    a("")
    write_md(L, docs / "world-biomes.md", "World — islands, biomes, flora & fauna")

    write_csv(sheets / "islands.csv",
              ["id", "display_name", "climate", "tier", "kind", "permanent", "lifetime_seconds", "size_m"],
              [island_row(i) for i in isl])
    write_csv(sheets / "climates.csv",
              ["climate", "tiers", "home", "resist", "vegetation", "materials"],
              [[cid, ";".join(str(t) for t in c.get("tiers", [])), c.get("home", ""), ";".join(c.get("resist", [])),
                ";".join(c.get("vegetation", [])),
                ";".join(m["id"] + (("+" + m["attr"]) if m.get("attr") else "") for m in c.get("materials", []))]
               for cid, c in sorted(cl.items()) if not cid.startswith("_") and c.get("tiers")])
    write_csv(sheets / "creatures.csv",
              ["species", "tier", "climate", "clade", "period", "real_length_m"],
              [[d.get("species"), d.get("tier"), d.get("climate"), d.get("clade", ""), d.get("period", ""), d.get("real_length_m", "")] for d, _ in creatures])
    rows = []
    for d, b in creatures:
        sp = str(d.get("species")).lower().replace(" ", "_")
        for kind in ("base", "rare"):
            for x in b.get(kind, []):
                at = x.get("attributes") or {}
                rows.append([sp, kind, x["id"], x.get("min", ""), x.get("max", ""), x.get("skill", ""),
                             ";".join("%s=%s" % kv for kv in at.items())])
    write_csv(sheets / "butchering.csv", ["species", "kind", "item", "min", "max", "butcher_skill", "attributes"], rows)


# ------------------------------------------------------------------ items/traits

def gen_items(data: Path, docs: Path, sheets: Path) -> None:
    items = load(data, "items.json")["items"]
    rar = load(data, "item_rarity.json")
    foods = load(data, "foods.json").get("foods", {})

    by_cat = OrderedDict()
    for it in items:
        for cat in it.get("categories", ["uncategorised"]):
            by_cat.setdefault(cat, []).append(it)

    L = []
    a = L.append
    a("`%d items` from `game/data/items.json`; per-item consumption effects from `game/data/foods.json`; rarity palette from `game/data/item_rarity.json`." % len(items))
    a("")
    a("Rarity: %s." % ", ".join("**%s** `%s`" % (k, v) for k, v in rar.get("colors", {}).items()))
    a("")
    a("Item *traits* are the attribute keys stamped on an instance: a def's `default_attributes` (its baseline), a gather material's latent attr (the yellow pip), an inherited attribute carried through crafting, or a butcher/gather roll. The pip/stacking rules live in `game/data/inventory.json`; bag specials in `game/data/bags.json`.")
    a("")
    a("## Categories with counts")
    a("")
    a(" · ".join("**%s** (%d)" % (k, len(v)) for k, v in sorted(by_cat.items(), key=lambda t: -len(t[1]))))
    a("")
    a("## Every item")
    a("")
    a("| id | name | lvl | stack | rarity | tool class | categories | attributes |")
    a("|---|---|---|---|---|---|---|---|")
    for it in sorted(items, key=lambda t: (t.get("base_level", 0), t["id"])):
        a("| `%s` | %s | %s | %s | %s | %s | %s | %s |" % (
            it["id"], it.get("display_name", ""), it.get("base_level", ""), it.get("stack_max", ""),
            it.get("rarity", ""), it.get("tool_class", ""),
            " · ".join(it.get("categories", [])), attrs(it.get("default_attributes", {}))))
    a("")
    a("## Food effects (FOODFX)")
    a("")
    a("Channels name what an item does; every number carries its `provenance` (`extracted-client` = the Durango:0 reconstruction, `restoration-evaluated` = evaluated but unverified, `new-design` = this build's own placeholder).")
    a("")
    a("| item | provenance | channels | energy | digest (s) | thirst | fullness | eat (s) | taste |")
    a("|---|---|---|---|---|---|---|---|---|")
    for fid, f in sorted(foods.items()):
        en = f.get("energy") or {}
        a("| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            fid, f.get("provenance", ""), " · ".join(str(x) for x in f.get("channels", [])),
            energy_cell(f), en.get("digest_seconds", ""), f.get("thirst", ""), f.get("fullness", ""),
            f.get("eat_seconds", ""), f.get("taste_score", "")))
    a("")
    a("## Per-food flavour, status & assumption notes")
    a("")
    for fid, f in sorted(foods.items()):
        parts = []
        if f.get("flavors"):
            parts.append("flavors %s" % attrs(f["flavors"]))
        if f.get("statuses"):
            parts.append("statuses %s" % attrs(f["statuses"]))
        if f.get("raw_risk"):
            parts.append("raw risk %s" % f["raw_risk"])
        if f.get("temperature"):
            parts.append("temperature %s" % f["temperature"])
        a("- **%s** — %s" % (f.get("display_name", fid), " — ".join(parts)))
        note = f.get("assumption", "")
        if note:
            a("  > *assumption:* %s" % note)
    a("")
    write_md(L, docs / "items-traits.md", "Items & traits — the full catalog")

    write_csv(sheets / "items.csv",
              ["id", "display_name", "categories", "stack_max", "tool_class", "base_level", "rarity", "market_category", "attributes"],
              [[i["id"], i.get("display_name", ""), ";".join(i.get("categories", [])), i.get("stack_max", ""),
                i.get("tool_class", ""), i.get("base_level", ""), i.get("rarity", ""), i.get("market_category", ""),
                ";".join("%s=%s" % kv for kv in (i.get("default_attributes") or {}).items())] for i in items])
    write_csv(sheets / "foods.csv",
              ["id", "display_name", "provenance", "channels", "energy_instant_release_ratio", "digest_seconds",
               "thirst", "fullness", "eat_seconds", "taste_score", "buffs", "statuses"],
              [[fid, f.get("display_name", ""), f.get("provenance", ""), ";".join(str(x) for x in f.get("channels", [])),
                (f.get("energy") or {}).get("instant_release_ratio", ""), (f.get("energy") or {}).get("digest_seconds", ""),
                f.get("thirst", ""), f.get("fullness", ""), f.get("eat_seconds", ""), f.get("taste_score", ""),
                dict_cell(f.get("buffs")), dict_cell(f.get("statuses"))] for fid, f in sorted(foods.items())])


# ------------------------------------------------------------------ sheets notes

def write_sheet_notes(sheets: Path, names) -> None:
    (sheets / "NOTES.md").write_text(
        "# Editable game-data sheets — how to change the build\n\n"
        "These CSVs are **generated from** `game/data/*.json` (generator: `tools/docs_wiki/gen_game_data.py`).\n"
        "They are yours to edit — Numbers, Excel or Google Sheets all open them plain. So a sync can apply\n"
        "them safely:\n\n"
        "- **First column is the key** (`id`/`species`/`station`/...) — never rename a key of an existing\n"
        "  row; deleting a KEY row means \"remove this record\", and the sync will ask before doing it.\n"
        "- Numbers, booleans (`true`/`false`) are edited in place. List cells are `;`-joined values.\n"
        "- Keep the header row untouched. A **new row at the bottom** means \"new record\", validated\n"
        "  against real game ids before anything applies.\n"
        "- After a tuning pass, tell the agent to **sync sheets back**: it rewrites only changed values,\n"
        "  prints a diff of every applied cell, and the game's data tests run before it is called done.\n\n"
        "| Sheet | Syncs into | What it tunes |\n|---|---|---|\n"
        + "\n".join("| %s.csv | `%s` | %s |" % (n.csv_name, n.target, n.tune) for n in names)
        + "\n")


class SheetDoc:
    def __init__(self, csv_name, target, tune):
        self.csv_name = csv_name
        self.target = target
        self.tune = tune


def main() -> None:
    here = Path(__file__).resolve().parent.parent.parent  # this repo's root
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=str(here / "game/data"))
    ap.add_argument("--docs", default=str(here / "docs/current"))
    ap.add_argument("--sheets", default=str(here / "game/data_sheets"))
    ap.add_argument("--force-sheets", action="store_true",
                    help="replace differing sheets and notes, discarding unsynced edits")
    args = ap.parse_args()
    data, docs, sheets = Path(args.data), Path(args.docs), Path(args.sheets)

    # Stage every output before touching the destinations: even docs must not be
    # refreshed if a sheet conflict prevents completing the same generation.
    with tempfile.TemporaryDirectory(prefix="wildlands-docs-") as tmp:
        staged_docs, staged_sheets = Path(tmp) / "docs", Path(tmp) / "sheets"
        staged_docs.mkdir()
        staged_sheets.mkdir()
        gen_items(data, staged_docs, staged_sheets)
        gen_recipes(data, staged_docs, staged_sheets)
        gen_biomes(data, staged_docs, staged_sheets)
        write_sheet_notes(staged_sheets, [
            SheetDoc("recipes", "data/recipes.json", "craft inputs/outputs, times, gates"),
            SheetDoc("repairs", "data/recipes.json ·repairs", "per-tier repair cost/restore"),
            SheetDoc("processing", "data/processing.json", "station labels, slots, real convergence times"),
            SheetDoc("items", "data/items.json", "stack sizes, levels, rarity, default attributes"),
            SheetDoc("foods", "data/foods.json", "FOODFX channels/effects per consumable"),
            SheetDoc("islands", "data/islands/*.json", "island roster, tiers, lifetimes"),
            SheetDoc("climates", "data/world/climates.json", "tiers, resists, flora families, materials"),
            SheetDoc("creatures", "data/creatures/*.json", "species tier/climate rows"),
            SheetDoc("butchering", "data/butchering.json", "kill drops per species"),
        ])
        conflicts = [p.name for p in sorted(staged_sheets.iterdir())
                     if (sheets / p.name).exists()
                     and (sheets / p.name).read_bytes() != p.read_bytes()]
        if conflicts and not args.force_sheets:
            ap.exit(1, "Refusing to overwrite differing sheets or notes: %s\n"
                    "No outputs were written. Review and sync edits first, or use "
                    "--force-sheets to discard them explicitly.\n" % ", ".join(conflicts))

        for source_dir, dest_dir in ((staged_docs, docs), (staged_sheets, sheets)):
            dest_dir.mkdir(parents=True, exist_ok=True)
            for source in source_dir.iterdir():
                destination = dest_dir / source.name
                # Existing sheets and notes passed preflight; leave them alone so an edit
                # made after that check is not overwritten by a redundant copy.
                if source_dir == staged_sheets and destination.exists() and not args.force_sheets:
                    continue
                shutil.copyfile(source, destination)
        print("wrote docs/current/{items-traits,recipes,world-biomes}.md and %d sheets"
              % len(list(staged_sheets.glob("*.csv"))))


if __name__ == "__main__":
    main()
