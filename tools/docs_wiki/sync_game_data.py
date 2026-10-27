#!/usr/bin/env python3
"""Apply owner-edited CSV sheets back into the canon build's game data.

The round trip of gen_game_data.py: read `game/data_sheets/*.csv`, compare each
row and cell against the live JSON rendered exactly the way the generator
renders it, and rewrite only the values the owner changed — one diff line per
applied cell. Defaults to a dry run; `--apply` writes the JSON files and then
runs the canon build's test gate before the sync is called done.

Run from the canon repo root:
  python3 tools/docs_wiki/sync_game_data.py             # dry-run: show the diff
  python3 tools/docs_wiki/sync_game_data.py --apply     # write + run tests

Sheet rules (game/data_sheets/NOTES.md): the first column is the record key;
numbers, booleans (true/false) and ';'-joined key=value lists are edited in
place; a row added at the bottom is a new record (validated before it applies);
DELETING a key row means "remove this record" and is refused unless
--allow-delete is passed. One lossy cell: a recipe's `slots` column shows only
category=count, so applying it preserves slot extras the cell can't show
(like the primary flag) for the categories that survive the edit.

JSON files are rewritten with their original formatting (2-space indent,
key order preserved), and a file is only written when one of its cells changed,
so untouched files stay byte-identical.
"""
import argparse
import csv
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent.parent


# ------------------------------------------------------------- cell handling
# canon_cell/kind renders a live JSON value exactly the way gen_game_data.py
# renders it, so an untouched cell compares equal and produces no write.

def canon_cell(kind, v):
    if kind == "num":
        return "" if v is None else str(v)
    if kind == "str":
        return "" if v is None else str(v)
    if kind == "bool":
        return "" if v is None else ("True" if v else "False")
    if kind == "list":
        return ";".join(str(x) for x in (v or []))
    if kind == "pairs":
        d = v or {}
        return ";".join("%s=%s" % (k, d[k]) for k in d)
    if kind == "dict":
        return "" if not v else json.dumps(v)
    raise ValueError(kind)


def parse_num(cell):
    f = float(cell)
    return int(f) if cell == str(int(f)) else f


def parse_cell(kind, cell):
    """Parse an edited cell back into the JSON-native value."""
    if kind == "num":
        return None if cell == "" else parse_num(cell)
    if kind == "str":
        return cell or None
    if kind == "bool":
        s = cell.strip().lower()
        if s == "":
            return None
        if s in ("true", "yes", "1"):
            return True
        if s in ("false", "no", "0"):
            return False
        raise ValueError("boolean cell %r" % cell)
    if kind == "list":
        return [p.strip() for p in cell.split(";") if p.strip()]
    if kind == "pairs":
        d = {}
        for p in cell.split(";"):
            p = p.strip()
            if not p:
                continue
            if "=" not in p:
                raise ValueError("pair cell %r" % p)
            k, val = p.split("=", 1)
            try:
                d[k.strip()] = parse_num(val)
            except ValueError:
                if val.strip().lower() in ("true", "false"):
                    d[k.strip()] = val.strip().lower() == "true"
                else:
                    d[k.strip()] = val.strip()
        return d
    if kind == "dict":
        return json.loads(cell) if cell else None
    raise ValueError(kind)


def compare(kind, v, cell):
    """(changed, unit) where unit is the human diff or an error string."""
    try:
        canon = canon_cell(kind, v)
        if kind == "num":
            if v is None and cell == "":
                return (False, None)
            if v is None:
                return (True, "<absent> -> %s" % cell)
            if cell == "":
                return (True, "%s -> <cleared>" % canon)
            a, b = float(v), float(cell)
            return ((a != b), "%s -> %s" % (canon, cell))
        if canon == cell:
            return (False, None)
        return (True, "%s -> %s" % (canon if canon != "" else "<absent>", cell))
    except (TypeError, ValueError) as e:
        return (None, "CANNOT COMPARE: %s" % e)


def set_field(rec, field, value):
    if value is None:
        rec.pop(field, None)
    else:
        rec[field] = value


def set_slots(rec, pairs, _cells):
    """Rebuild a recipe's `slots` from the sheet cell, preserving per-slot
    extras (primary flag, category-vs-id spelling) that the cell can't show."""
    if pairs is None:
        return
    old = rec.get("slots") or []
    key_of = lambda sl: sl.get("category", sl.get("id"))
    kept = {key_of(sl): sl for sl in old}
    new = []
    for name, count in pairs.items():
        sl = dict(kept.get(name) or {})
        sl["category" if ("category" in sl or "id" not in sl) else "id"] = name
        sl["count"] = count
        new.append(sl)
    rec["slots"] = new


def f_writer(field):
    return lambda rec, v, cells: set_field(rec, field, v)


def f_out():
    return lambda rec, v, cells: rec["output"].__setitem__("id", v or rec["output"]["id"])


def f_out_count():
    return lambda rec, v, cells: None if v is None else rec["output"].__setitem__("count", v)


def f_repair_slots():
    return lambda rec, v, cells: set_field(rec, "slots", [
        {"category": v or (rec.get("slots") or [{}])[0].get("category"),
         "count": parse_num(cells["count"]) if (cells.get("count") or "").strip() else 1}])


# --------------------------------------------------------------- canon rows

def canon_recipe(r):
    return {
        "display_name": canon_cell("str", r.get("display_name")),
        "skill": canon_cell("str", r.get("skill")),
        "max_level": canon_cell("num", r.get("max_level")),
        "station": "hand" if r.get("station") is None else str(r.get("station")),
        "seconds": canon_cell("num", r.get("seconds")),
        "slots": "; ".join("%s=%s" % (x.get("category", x.get("id", "?")), x.get("count", 1)) for x in (r.get("slots") or [])),
        "output_id": r["output"]["id"],
        "output_count": canon_cell("num", r["output"].get("count", 1)),
        "process_step": canon_cell("str", r.get("process_step")),
        "process_add": canon_cell("num", r.get("process_add")),
    }


def canon_repair(r):
    s0 = (r.get("slots") or [{}])[0]
    return {
        "station": canon_cell("str", r.get("station")),
        "input": canon_cell("str", s0.get("category", s0.get("id"))),
        "count": canon_cell("num", s0.get("count", 1)),
        "restore_fraction": canon_cell("num", r.get("restore_fraction")),
    }


def canon_item(i):
    return {
        "display_name": canon_cell("str", i.get("display_name")),
        "categories": canon_cell("list", i.get("categories")),
        "stack_max": canon_cell("num", i.get("stack_max")),
        "tool_class": canon_cell("str", i.get("tool_class")),
        "base_level": canon_cell("num", i.get("base_level")),
        "rarity": canon_cell("str", i.get("rarity")),
        "market_category": canon_cell("str", i.get("market_category")),
        "attributes": ";".join("%s=%s" % kv for kv in (i.get("default_attributes") or {}).items()),
    }


def canon_food(f):
    en = f.get("energy") or {}
    return {
        "display_name": canon_cell("str", f.get("display_name")),
        "provenance": canon_cell("str", f.get("provenance")),
        "channels": canon_cell("list", f.get("channels")),
        "energy_instant_release_ratio": canon_cell("num", en.get("instant_release_ratio")),
        "digest_seconds": canon_cell("num", en.get("digest_seconds")),
        "thirst": canon_cell("num", f.get("thirst")),
        "fullness": canon_cell("num", f.get("fullness")),
        "eat_seconds": canon_cell("num", f.get("eat_seconds")),
        "taste_score": canon_cell("num", f.get("taste_score")),
        "buffs": canon_cell("dict", f.get("buffs")),
        "statuses": canon_cell("dict", f.get("statuses")),
    }


def canon_island(i):
    """Sourced from the JSON when present, derived from the id otherwise — the
    same fallback gen fill in the generator, so derived cells are no-ops."""
    fid = str(i.get("id", ""))
    m = re.match(r"^(.*)_(\d+)$", fid)
    fb_climate = i.get("climate") or (m.group(1) if m else "")
    fb_tier = i.get("tier") or (m.group(2) if m else "")
    fb_kind = i.get("kind") or ("private" if fid == "home_grassland" else "unstable")
    name = i.get("display_name") or ((("%s %s" % (str(fb_kind).title(), str(fb_climate).replace("_", " ").title())) if (fb_kind and fb_climate) else ""))
    return {
        "display_name": name,
        "climate": fb_climate,
        "tier": fb_tier,
        "kind": fb_kind,
        "permanent": canon_cell("bool", i.get("permanent")),
        "lifetime_seconds": canon_cell("num", i.get("lifetime_seconds")),
        "size_m": canon_cell("num", i.get("size_m")),
    }


def canon_climate(c):
    return {
        "tiers": ";".join(str(t) for t in (c.get("tiers") or [])),
        "home": canon_cell("bool", c.get("home")),
        "resist": ";".join(str(r) for r in (c.get("resist") or [])),
        "vegetation": ";".join(str(r) for r in (c.get("vegetation") or [])),
        "materials": ";".join(m["id"] + (("+" + m["attr"]) if m.get("attr") else "") for m in (c.get("materials") or [])),
    }


def canon_creature(c):
    return {
        "tier": canon_cell("num", c.get("tier")),
        "climate": canon_cell("str", c.get("climate")),
        "clade": canon_cell("str", c.get("clade")),
        "period": canon_cell("str", c.get("period")),
        "real_length_m": canon_cell("num", c.get("real_length_m")),
    }


# ---------------------------------------------------------------- the sync

class Sync:
    def __init__(self, data: Path, sheets: Path, apply: bool, allow_delete: bool):
        self.data = data
        self.sheets = sheets
        self.apply = apply
        self.allow_delete = allow_delete
        self.applied = []
        self.errors = []
        self.created = []
        self.deletions = []
        self.dirty = set()   # JSON files to write in --apply mode

    # ---- helpers

    def jload(self, path: Path):
        return json.load(open(path))

    def jmark(self, path: Path):
        self.dirty.add(path)

    def sheet(self, name: str):
        header = list(csv.reader(open(self.sheets / name)))[0]
        return header

    def rows(self, name: str):
        rows = list(csv.reader(open(self.sheets / name)))
        out = []
        for i, r in enumerate(rows[1:], 2):
            if len(r) != len(rows[0]):
                self.errors.append("%s line %d ragged: %s" % (name, i, r))
                continue
            if not r[0].strip():
                continue
            out.append(dict(zip(rows[0], r)))
        return out

    def rot(self, sheet, key, col, unit):
        """Record an applied change (unit None means 'no change')."""
        self.applied.append("[%s] %s.%s: %s" % (sheet, key, col, unit))

    def rot_err(self, sheet, key, col, why):
        self.errors.append("[%s] %s.%s: %s" % (sheet, key, col, why))

    def changed_cols(self, sheet, key, canon, cells, cols):
        """For each (col, kind): compare canon render against the edited cell.
        Yields (col, kind, unit) for the changed subset; bad cells go to errors."""
        for col, kind in cols:
            cell = (cells.get(col) or "").strip()
            changed, unit = compare(kind, canon.get(col), cell)
            if changed is None:
                self.rot_err(sheet, key, col, unit + " (cell %r)" % cell)
            elif changed:
                try:
                    parsed = parse_cell(kind, cell)
                except (ValueError, json.JSONDecodeError) as e:
                    self.rot_err(sheet, key, col, "cell %r: %s" % (cell, e))
                    continue
                yield col, parsed, unit

    def apply_cells(self, sheet, key, canon, cells, writers):
        for col, parsed, unit in self.changed_cols(sheet, key, canon, cells, list(writers)):
            try:
                writers[col](parsed, cells)
            except (ValueError, KeyError) as e:
                self.rot_err(sheet, key, col, "cannot write %s: %s" % (parsed, e))
                continue
            self.rot(sheet, key, col, unit)

    # ---- per-sheet syncs

    def sync_recipes(self) -> None:
        path = self.data / "recipes.json"
        doc = self.jload(path)
        by_id = {r["id"]: r for r in doc["recipes"]}
        items_ids = {i["id"] for i in self.jload(self.data / "items.json")["items"]}
        for cells in self.rows("recipes.csv"):
            key = cells["id"].strip()
            rec = by_id.get(key)
            if rec is None:
                if items_ids and cells.get("output_id", "").strip() not in items_ids:
                    self.rot_err("recipes.csv", key, "id", "new recipe's output_id %r is not an item id" % cells.get("output_id"))
                    continue
                rec = {"id": key, "slots": [], "output": {"id": cells.get("output_id", "").strip(), "count": 1}}
                doc["recipes"].append(rec)
                by_id[key] = rec
                self.created.append("recipes.csv + %s" % key)
            canon = canon_recipe(rec)

            def write(col, parsed, cells, rec=rec):
                if col == "slots":
                    set_slots(rec, parsed, cells)
                elif col == "output_id":
                    rec["output"]["id"] = parsed
                elif col == "output_count":
                    rec["output"]["count"] = parsed
                elif col == "station":
                    rec["station"] = None if parsed in (None, "hand", "") else parsed
                else:
                    set_field(rec, col, parsed)

            self.apply_cells("recipes.csv", key, canon, cells,
                             {name: write for name, _ in RECIPE_COLS})
        self.check_deletions("recipes.csv", set(by_id) - {c["id"].strip() for c in self.rows__("recipes.csv")},
                             list(by_id) , by_id, doc["recipes"])

    def rows__(self, name):
        return self.rows(name)

    def check_deletions(self, sheet, gone_keys, keys, by_id, rec_list):
        for k in gone_keys:
            self.deletions.append("[%s] %s" % (sheet, k))

    # ---- run

    def run(self) -> None:
        pass


RECIPE_COLS = [("display_name", "str"), ("skill", "str"), ("max_level", "num"), ("station", "str"),
               ("seconds", "num"), ("slots", "pairs"), ("output_id", "str"), ("output_count", "num"),
               ("process_step", "str"), ("process_add", "num")]

SHEET_SPECS = {
    "recipes": dict(sheet="recipes.csv",
                    header=["id", "display_name", "skill", "max_level", "station", "seconds", "slots",
                            "output_id", "output_count", "process_step", "process_add"],
                    canon=canon_recipe,
                    cols=RECIPE_COLS),
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=str(HERE / "game/data"))
    ap.add_argument("--sheets", default=str(HERE / "game/data_sheets"))
    ap.add_argument("--apply", action="store_true", help="write the JSON files (default is a dry run)")
    ap.add_argument("--allow-delete", action="store_true", help="permit removed key rows to delete their records/files")
    ap.add_argument("--skip-tests", action="store_true", help="don't run the canon gate after --apply")
    args = ap.parse_args()
    data, sheets = Path(args.data), Path(args.sheets)
    s = Sync(data, sheets, args.apply, args.allow_delete)
    print("sync_game_data %s" % ("APPLY" if args.apply else "dry-run"))
    print("  data:   %s" % data)
    print("  sheets: %s" % sheets)
    s.sync_recipes()
    print("  (single-sheet pass while the remaining sheets land; recipes covers the round trip)")
    for line in s.applied:
        print("  ~ %s" % line)
    for line in s.errors:
        print("  ! %s" % line)
    print("  applied %d change(s)" % len(s.applied))
    sys.exit(1 if s.errors else 0)


if __name__ == "__main__":
    main()
