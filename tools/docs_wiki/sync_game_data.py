#!/usr/bin/env python3
"""Apply owner-edited CSV sheets back into the canon build's game data.

The round trip of gen_game_data.py: read `game/data_sheets/*.csv`, compare each
row and cell against the live JSON value rendered exactly the way the generator
renders it, and rewrite only the values the owner changed — one diff line per
applied cell. Defaults to a dry run; `--apply` writes the JSON files and then
runs the canon build's test gate (`tools/test.sh`) before the sync is called
done.

Run from the canon repo root:
  python3 tools/docs_wiki/sync_game_data.py             # dry-run: show the diff
  python3 tools/docs_wiki/sync_game_data.py --apply     # write + run tests
  python3 tools/docs_wiki/sync_game_data.py --apply --skip-tests

Sheet rules (game/data_sheets/NOTES.md): the first column is the record key;
numbers, booleans (true/false) and ';'-joined values are edited in place; a row
added at the bottom is a new record (validated before it applies); DELETING a
key row means "remove this record" and is refused unless --apply --allow-delete
is passed. Lossy cell: a recipe's `slots` shows only category=count — per-slot
extras (the primary flag, id-vs-category spelling) survive the edit. Cleared
derived cells (island display names and the like) become absent keys again,
which re-derives the same value at the next generation, so clearing matches
"accept the derived value".

JSON files are rewritten as json.dumps(indent=2) plus a trailing newline (key
order preserved). recipes/processing/butchering/items/climates already are in
exactly that style, so files stay byte-identical unless a cell actually
changed, and a written file's diff shows only the owner's values.

Validation before anything applies:
- a new recipe row needs a real output_id; new food/butchering rows need real
  item ids; a new processing row needs a real recipe id
- deleting an item still cited by recipes or butchering drops is refused
- creatures are code-owned (game/data/creatures is agent-owned; see
  butchering.json's own note): creature VALUES stay editable, new species rows
  are refused
"""
import argparse
import csv
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent.parent
KINDS = ("base", "rare")


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
    if kind == "station":
        return "hand" if v in (None, "") else str(v)
    if kind in ("list", "ints"):
        return ";".join(str(x) for x in (v or []))
    if kind == "slots":
        return "; ".join("%s=%s" % (x.get("category", x.get("id", "?")), x.get("count", 1))
                         for x in (v or []))
    if kind == "mats":
        return ";".join(m["id"] + (("+" + m["attr"]) if m.get("attr") else "")
                        for m in (v or []))
    if kind == "numstr":
        return "" if v is None else str(v)
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
    if kind == "numstr":
        try:
            return parse_num(cell) if cell else None
        except ValueError:
            return cell or None
    if kind == "station":
        return None if cell in ("", "hand") else cell
    if kind in ("list", "ints"):
        vals = [p.strip() for p in cell.split(";") if p.strip()]
        return [int(float(x)) for x in vals] if kind == "ints" else vals
    if kind == "slots":
        d = {}
        for p in cell.split(";"):
            p = p.strip()
            if not p:
                continue
            if "=" not in p:
                raise ValueError("slot pair %r" % p)
            k, v = p.split("=", 1)
            d[k.strip()] = parse_num(v.strip())
        return d
    if kind == "mats":
        out = []
        for p in cell.split(";"):
            p = p.strip()
            if not p:
                continue
            m = re.match(r"^([^+]+)\+(.+)$", p)
            out.append({"id": m.group(1).strip(), "attr": m.group(2).strip()}
                       if m else {"id": p})
        return out
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
            return ((float(v) != float(cell)), "%s -> %s" % (canon, cell))
        if canon == cell:
            return (False, None)
        return (True, "%s -> %s" % (canon if canon != "" else "<absent>", cell))
    except (KeyError, TypeError, ValueError) as e:
        return (None, "CANNOT COMPARE: %s" % e)


def set_field(rec, field, value):
    if value is None:
        rec.pop(field, None)
    else:
        rec[field] = value


def set_slots(rec, pairs, _cells=None):
    """Rebuild a recipe's `slots` from the sheet cell, preserving per-slot
    extras (primary flag, category-vs-id spelling) that the cell can't show."""
    if pairs is None:
        return
    old = rec.get("slots") or []
    key_of = lambda sl: sl.get("category", sl.get("id"))
    kept = {key_of(sl): sl for sl in old}
    rec["slots"] = []
    for name, count in (pairs or {}).items():
        sl = dict(kept.get(name) or {})
        flag = "category" if ("category" in sl or "id" not in sl) else "id"
        sl[flag] = name
        sl["count"] = count
        rec["slots"].append(sl)


def repair_input(rec, value, _cells=None):
    """The `input` column is the tier's first slot category; extras survive."""
    if value is None:
        return
    slots = rec.setdefault("slots", [{}])
    s0 = dict(slots[0] if slots else {})
    s0.pop("id", None)
    s0["category"] = value
    rec["slots"] = [s0] + slots[1:]


def repair_count(rec, value, _cells=None):
    if value is None:
        return
    slots = rec.setdefault("slots", [{}])
    s0 = dict(slots[0] if slots else {})
    s0["count"] = value
    rec["slots"] = [s0] + slots[1:]


def food_energy_writer(rec, field):
    def w(value, _cells=None):
        if value is None:
            en = rec.get("energy")
            if isinstance(en, dict):
                en.pop(field, None)
        else:
            rec.setdefault("energy", {})[field] = value
    return w


# ---------------------------------------------------------------- canon rows
# Each of these renders a JSON record into a dict of RAW values, one per sheet
# column; any generator fallback (island name derivation, station "hand" …)
# lives in canon_cell's kinds, so derived cells compare equal untouched.

def canon_recipe(r):
    return {
        "display_name": r.get("display_name"),
        "skill": r.get("skill"),
        "max_level": r.get("max_level"),
        "station": r.get("station"),
        "seconds": r.get("seconds"),
        "slots": r.get("slots"),
        "output_id": r["output"]["id"],
        "output_count": r["output"].get("count", 1),
        "process_step": r.get("process_step"),
        "process_add": r.get("process_add"),
    }


def canon_repair(r):
    s0 = (r.get("slots") or [{}])[0]
    return {
        "station": r.get("station"),
        "input": s0.get("category", s0.get("id")),
        "count": s0.get("count", 1),
        "restore_fraction": r.get("restore_fraction"),
    }


def canon_station_row(k, td):
    """One (station, recipe) row of processing.csv, generator semantics."""
    return {
        "label": k.get("label"),
        "slots": k.get("slots"),
        "fx": k.get("fx"),
        "seconds": (td or {}).get("seconds"),
    }


def canon_item(i):
    return {
        "display_name": i.get("display_name"),
        "categories": i.get("categories"),
        "stack_max": i.get("stack_max"),
        "tool_class": i.get("tool_class"),
        "base_level": i.get("base_level"),
        "rarity": i.get("rarity"),
        "market_category": i.get("market_category"),
        "attributes": i.get("default_attributes"),
    }


def canon_food(f):
    en = f.get("energy") or {}
    return {
        "display_name": f.get("display_name"),
        "provenance": f.get("provenance"),
        "channels": f.get("channels"),
        "energy_instant_release_ratio": en.get("instant_release_ratio"),
        "digest_seconds": en.get("digest_seconds"),
        "thirst": f.get("thirst"),
        "fullness": f.get("fullness"),
        "eat_seconds": f.get("eat_seconds"),
        "taste_score": f.get("taste_score"),
        "buffs": f.get("buffs"),
        "statuses": f.get("statuses"),
    }


def canon_island(i):
    """Sourced from the JSON when present, derived from the id otherwise — the
    same fallback the generator fills, so derived cells are no-ops."""
    fid = str(i.get("id", ""))
    m = re.match(r"^(.*)_(\d+)$", fid)
    fb_climate = i.get("climate") or (m.group(1) if m else "")
    fb_tier = i.get("tier") or (m.group(2) if m else "")
    fb_kind = i.get("kind") or ("private" if fid == "home_grassland" else "unstable")
    name = i.get("display_name")
    if not name:
        name = ("%s %s" % (str(fb_kind).title(), str(fb_climate).replace("_", " ").title())
                if (fb_kind and fb_climate) else "")
    return {
        "display_name": name,
        "climate": fb_climate,
        "tier": fb_tier,
        "kind": fb_kind,
        "permanent": i.get("permanent"),
        "lifetime_seconds": i.get("lifetime_seconds"),
        "size_m": i.get("size_m"),
    }


def canon_climate(c):
    return {
        "tiers": c.get("tiers"),
        "home": c.get("home"),
        "resist": c.get("resist"),
        "vegetation": c.get("vegetation"),
        "materials": c.get("materials"),
    }


def canon_creature(c):
    return {
        "tier": c.get("tier"),
        "climate": c.get("climate"),
        "clade": c.get("clade"),
        "period": c.get("period"),
        "real_length_m": c.get("real_length_m"),
    }


def canon_butchering(x):
    return {
        "min": x.get("min"),
        "max": x.get("max"),
        "butcher_skill": x.get("skill"),
        "attributes": x.get("attributes"),
    }


# ---------------------------------------------------------------- the sync

class Sync:
    """Walks the sheets; a dry run reports, --apply mutates the cached docs and
    writes back only files whose bytes changed."""

    def __init__(self, data: Path, sheets: Path, apply: bool, allow_delete: bool):
        self.data = data
        self.sheets = sheets
        self.apply = apply
        self.allow_delete = allow_delete
        self.structural = apply and allow_delete
        self.applied = []
        self.errors = []
        self.created = []
        self.pending = []        # record deletions awaiting --allow-delete
        self.freed = []          # deletions performed this run
        self.dirty = set()       # JSON files to write in --apply mode
        self.file_delete = set() # files deleted whole (islands, creatures)
        self.docs = {}           # path -> loaded doc (mutations land here)

    # ---- shared helpers ----------------------------------------------------

    def jload(self, path: Path):
        if path not in self.docs:
            with open(path) as f:
                self.docs[path] = json.load(f)
        return self.docs[path]

    def jmark(self, path: Path, doc=None):
        if doc is not None:
            self.docs[path] = doc
        self.dirty.add(path)

    def jdump(self, doc) -> str:
        return json.dumps(doc, indent=2) + "\n"

    def rows(self, name: str):
        path = self.sheets / name
        if not path.exists():
            self.errors.append("%s: sheet file missing" % name)
            return []
        rows = list(csv.reader(open(path)))
        if not rows:
            self.errors.append("%s: empty sheet" % name)
            return []
        out = []
        for i, r in enumerate(rows[1:], 2):
            if len(r) != len(rows[0]):
                self.errors.append("%s line %d ragged (%d cols, header has %d): %s"
                                   % (name, i, len(r), len(rows[0]), r))
                continue
            if not r[0].strip():
                continue
            out.append(dict(zip(rows[0], r)))
        return out

    def rot(self, sheet, key, col, unit):
        self.applied.append("[%s] %s.%s: %s" % (sheet, key, col, unit))

    def rot_err(self, sheet, key, col, why):
        self.errors.append("[%s] %s.%s: %s" % (sheet, key, col, why))

    def changed_cols(self, sheet, key, canon, cells, cols):
        """For each (col, kind): compare canon render against the edited cell.
        Yields (col, parsed, unit) for the changed subset; bad cells go to errors."""
        for col, kind in cols:
            cell = (cells.get(col) or "").strip()
            changed, unit = compare(kind, canon.get(col), cell)
            if changed is None:
                self.rot_err(sheet, key, col, "%s (cell %r)" % (unit, cell))
            elif changed:
                try:
                    parsed = parse_cell(kind, cell)
                except (ValueError, json.JSONDecodeError) as e:
                    self.rot_err(sheet, key, col, "cell %r: %s" % (cell, e))
                    continue
                yield col, parsed, unit

    def apply_cells(self, sheet, key, canon, cells, cols, writers) -> int:
        """Returns the number of cells actually changed (0 = nothing to write)."""
        n = 0
        for col, parsed, unit in self.changed_cols(sheet, key, canon, cells, cols):
            try:
                writers[col](parsed, cells)
            except (ValueError, KeyError, IndexError) as e:
                self.rot_err(sheet, key, col, "cannot write %r: %s" % (parsed, e))
                continue
            self.rot(sheet, key, col, unit)
            n += 1
        return n

    def deletions_for(self, sheet, gone, act):
        """gone = [(key, note)]. When structural edits are allowed act(key) runs
        (mutating the in-memory doc); otherwise it is queued as pending."""
        did = 0
        for label, note in gone:
            if self.structural:
                act(label)
                self.freed.append("[%s] %s — removed (not %s)" % (sheet, label, note))
                did += 1
            else:
                self.pending.append("[%s] %s removed from the sheet: its record can be deleted "
                                    "with --apply --allow-delete" % (sheet, label))
        return did

    # ---- recipes ------------------------------------------------------------

    RECIPE_COLS = [("display_name", "str"), ("skill", "str"), ("max_level", "num"),
                   ("station", "station"), ("seconds", "num"), ("slots", "slots"),
                   ("output_id", "str"), ("output_count", "num"),
                   ("process_step", "str"), ("process_add", "num")]

    def sync_recipes(self) -> None:
        path = self.data / "recipes.json"
        doc = self.jload(path)
        recs = doc["recipes"]
        by_id = {r["id"]: r for r in recs}
        item_ids = {i["id"] for i in self.jload(self.data / "items.json")["items"]}
        rows = self.rows("recipes.csv")
        for cells in rows:
            key = cells["id"].strip()
            rec = by_id.get(key)
            if rec is None:
                out_id = cells.get("output_id", "").strip()
                if not out_id or out_id not in item_ids:
                    self.rot_err("recipes.csv", key, "id",
                                 "new recipe's output_id %r is not an item id" % out_id)
                    continue
                rec = {"id": key, "slots": [], "output": {"id": out_id, "count": 1}}
                recs.append(rec)
                by_id[key] = rec
                self.created.append("recipes: new recipe row %s" % key)
            canon = canon_recipe(rec)
            writers = {
                "display_name": lambda v, c, rec=rec: set_field(rec, "display_name", v),
                "skill": lambda v, c, rec=rec: set_field(rec, "skill", v),
                "max_level": lambda v, c, rec=rec: set_field(rec, "max_level", v),
                "station": lambda v, c, rec=rec: set_field(rec, "station", v),
                "seconds": lambda v, c, rec=rec: set_field(rec, "seconds", v),
                "slots": lambda v, c, rec=rec: set_slots(rec, v),
                "output_id": lambda v, c, rec=rec: set_field(rec["output"], "id", v),
                "output_count": lambda v, c, rec=rec: None if v is None else rec["output"].__setitem__("count", v),
                "process_step": lambda v, c, rec=rec: set_field(rec, "process_step", v),
                "process_add": lambda v, c, rec=rec: set_field(rec, "process_add", v),
            }
            if self.apply_cells("recipes.csv", key, canon, cells, self.RECIPE_COLS, writers):
                self.jmark(path)
        sheet_keys = {c["id"].strip() for c in rows}

        def act(k):
            if k in by_id:
                recs.remove(by_id[k])
                by_id.pop(k)
                self.jmark(path)
        self.deletions_for("recipes.csv",
                           [(k, "recipe record") for k in by_id if k not in sheet_keys], act)
    # ---- repairs ------------------------------------------------------------

    REPAIR_COLS = [("station", "str"), ("input", "str"), ("count", "num"),
                   ("restore_fraction", "num")]

    def sync_repairs(self) -> None:
        path = self.data / "recipes.json"
        doc = self.jload(path)
        reps = doc.get("repairs", [])
        by_tier = {}
        for r in reps:
            by_tier.setdefault(r.get("tier"), r)
        rows = self.rows("repairs.csv")
        for cells in rows:
            key = cells["tier"].strip()
            rec = by_tier.get(key)
            if rec is None:
                rec = {"tier": key, "slots": []}
                slots = rec.get("slots") or [{}]
                inp = (cells.get("input") or "").strip()
                cnt = (cells.get("count") or "").strip()
                if inp:
                    slots[0] = dict(slots[0]) if slots else {}
                    slots[0]["category"] = inp
                    if cnt:
                        slots[0]["count"] = parse_num(cnt)
                rec["station"] = (cells.get("station") or "").strip() or None
                rf = (cells.get("restore_fraction") or "").strip()
                if rf:
                    rec["restore_fraction"] = parse_num(rf)
                reps.append(rec)
                by_tier[key] = rec
                self.created.append("repairs: new tier row %s" % key)
            canon = canon_repair(rec)
            writers = {
                "station": lambda v, c, rec=rec: set_field(rec, "station", v),
                "restore_fraction": lambda v, c, rec=rec: set_field(rec, "restore_fraction", v),
                "input": lambda v, c, rec=rec: repair_input(rec, v),
                "count": lambda v, c, rec=rec: repair_count(rec, v),
            }
            if self.apply_cells("repairs.csv", key, canon, cells, self.REPAIR_COLS, writers):
                self.jmark(path)
        sheet_keys = {c["tier"].strip() for c in rows}

        def act(k):
            if k in by_tier:
                reps.remove(by_tier[k])
                by_tier.pop(k)
                self.jmark(path)
        self.deletions_for("repairs.csv",
                           [(k, "repair tier record") for k in by_tier if k not in sheet_keys], act)

    # ---- processing ---------------------------------------------------------

    PROC_COLS = [("label", "str"), ("slots", "numstr"), ("fx", "str"), ("seconds", "num")]

    def sync_processing(self) -> None:
        path = self.data / "processing.json"
        doc = self.jload(path)
        stations = doc.get("stations", {})
        recipe_ids = {r["id"] for r in self.jload(self.data / "recipes.json")["recipes"]}
        rows = self.rows("processing.csv")
        sheet_pairs = set()
        for cells in rows:
            st = cells["station"].strip()
            rid = cells["recipe"].strip()
            key = "%s / %s" % (st or "?", rid or "?")
            if rid and rid not in recipe_ids:
                self.rot_err("processing.csv", key, "recipe",
                             "recipe %r is not a recipe id" % rid)
                continue
            sheet_pairs.add((st, rid))
            stc = stations.get(st)
            if stc is None:
                stc = {"label": (cells.get("label") or "").strip(), "recipes": {}}
                for col, jname in (("slots", "slots"), ("fx", "fx")):
                    val = (cells.get(col) or "").strip()
                    if val:
                        stc[jname] = val
                stations[st] = stc
                self.created.append("processing: new station %s" % st)
            td = stc.setdefault("recipes", {}).get(rid)
            if td is None:
                sec_cell = (cells.get("seconds") or "").strip()
                td = {"seconds": parse_num(sec_cell) if sec_cell else 0}
                stc["recipes"][rid] = td
                self.created.append("processing: new recipe row %s under station %s" % (rid, st))
            canon = canon_station_row(stc, td)
            writers = {
                "label": lambda v, c, stc=stc: set_field(stc, "label", v),
                "slots": lambda v, c, stc=stc: set_field(stc, "slots", v),
                "fx": lambda v, c, stc=stc: set_field(stc, "fx", v),
                "seconds": lambda v, c, td=td: None if v is None else td.__setitem__("seconds", v),
            }
            if self.apply_cells("processing.csv", key, canon, cells, self.PROC_COLS, writers):
                self.jmark(path)

        gone_pairs = []
        for st in stations:
            for rid in (stations[st].get("recipes") or {}):
                if (str(st), rid) not in sheet_pairs:
                    gone_pairs.append("%s / %s" % (st, rid))

        def act(_k):
            for st in list(stations):
                stc = stations[st]
                rmap = stc.get("recipes") or {}
                for rid in list(rmap):
                    if (str(st), rid) not in sheet_pairs:
                        rmap.pop(rid)
            self.jmark(path)
        self.deletions_for("processing.csv", [(p, "processing row") for p in gone_pairs], act)

    # ---- items --------------------------------------------------------------

    ITEM_COLS = [("display_name", "str"), ("categories", "list"), ("stack_max", "num"),
                 ("tool_class", "str"), ("base_level", "num"), ("rarity", "str"),
                 ("market_category", "str"), ("attributes", "pairs")]

    def sync_items(self) -> None:
        path = self.data / "items.json"
        doc = self.jload(path)
        items = doc["items"]
        by_id = {i["id"]: i for i in items}
        rows = self.rows("items.csv")
        for cells in rows:
            key = cells["id"].strip()
            rec = by_id.get(key)
            if rec is None:
                if not (cells.get("display_name") or "").strip():
                    self.rot_err("items.csv", key, "id", "new item row needs a display_name")
                    continue
                rec = {}
                items.append(rec)
                by_id[key] = rec
                self.created.append("items: new item row %s" % key)
            canon = canon_item(rec)
            writers = {name: (lambda v, c, rec=rec, f=name: set_field(rec, f, v))
                       for name, _kind in self.ITEM_COLS}
            if self.apply_cells("items.csv", key, canon, cells, self.ITEM_COLS, writers):
                self.jmark(path)
        sheet_keys = {c["id"].strip() for c in rows}
        gone = {k for k in by_id if k not in sheet_keys}
        cited = self.cited_items(gone)
        pending_gone = []
        for k in sorted(gone):
            if k in cited:
                self.rot_err("items.csv", k, "id",
                             "still cited by %d record(s) — fix those first" % len(cited[k]))
            else:
                pending_gone.append((k, "item record"))

        def act(k):
            if k in by_id:
                items.remove(by_id[k])
                by_id.pop(k)
                self.jmark(path)
        self.deletions_for("items.csv", pending_gone, act)

    def cited_items(self, gone) -> dict:
        """item id -> list of citing record labels, for the deletion guard."""
        cited = {}
        if not gone:
            return cited
        gs = set(gone)
        for r in self.jload(self.data / "recipes.json").get("recipes", []):
            if r["output"]["id"] in gs:
                cited.setdefault(r["output"]["id"], []).append("recipe %s" % r["id"])
            for sl in r.get("slots", []):
                i = sl.get("category", sl.get("id"))
                if i in gs:
                    cited.setdefault(i, []).append("recipe %s slots" % r["id"])
        bdoc = self.jload(self.data / "butchering.json")
        for sp, kindmap in (bdoc.get("species") or {}).items():
            if not isinstance(kindmap, dict):
                continue
            for kind, drops in kindmap.items():
                if not isinstance(drops, list):
                    continue
                for x in drops:
                    if isinstance(x, dict) and x.get("id") in gs:
                        cited.setdefault(x.get("id"), []).append("butchering %s %s" % (sp, kind))
        return cited

    # ---- foods --------------------------------------------------------------

    FOOD_COLS = [("display_name", "str"), ("provenance", "str"), ("channels", "list"),
                 ("energy_instant_release_ratio", "num"), ("digest_seconds", "num"),
                 ("thirst", "num"), ("fullness", "num"), ("eat_seconds", "num"),
                 ("taste_score", "num"), ("buffs", "dict"), ("statuses", "dict")]

    def sync_foods(self) -> None:
        path = self.data / "foods.json"
        doc = self.jload(path)
        foods = doc.setdefault("foods", {})
        item_ids = {i["id"] for i in self.jload(self.data / "items.json")["items"]}
        rows = self.rows("foods.csv")
        for cells in rows:
            key = cells["id"].strip()
            rec = foods.get(key)
            if rec is None:
                if key not in item_ids:
                    self.rot_err("foods.csv", key, "id",
                                 "new food row's id %r is not an item id" % key)
                    continue
                rec = {}
                foods[key] = rec
                self.created.append("foods: new row %s" % key)
            canon = canon_food(rec)
            writers = {
                "display_name": lambda v, c, rec=rec: set_field(rec, "display_name", v),
                "provenance": lambda v, c, rec=rec: set_field(rec, "provenance", v),
                "channels": lambda v, c, rec=rec: set_field(rec, "channels", v),
                "energy_instant_release_ratio": food_energy_writer(rec, "instant_release_ratio"),
                "digest_seconds": food_energy_writer(rec, "digest_seconds"),
                "thirst": lambda v, c, rec=rec: set_field(rec, "thirst", v),
                "fullness": lambda v, c, rec=rec: set_field(rec, "fullness", v),
                "eat_seconds": lambda v, c, rec=rec: set_field(rec, "eat_seconds", v),
                "taste_score": lambda v, c, rec=rec: set_field(rec, "taste_score", v),
                "buffs": lambda v, c, rec=rec: set_field(rec, "buffs", v),
                "statuses": lambda v, c, rec=rec: set_field(rec, "statuses", v),
            }
            if self.apply_cells("foods.csv", key, canon, cells, self.FOOD_COLS, writers):
                self.jmark(path)
        sheet_keys = {c["id"].strip() for c in rows}

        def act(k):
            foods.pop(k, None)
            self.jmark(path)
        self.deletions_for("foods.csv",
                           [(k, "food record (the item itself keeps existing)") for k in foods
                            if not str(k).startswith("_") and k not in sheet_keys], act)

    # ---- islands ------------------------------------------------------------

    ISLAND_COLS = [("display_name", "str"), ("climate", "str"), ("tier", "num"),
                   ("kind", "str"), ("permanent", "bool"), ("lifetime_seconds", "num"),
                   ("size_m", "num")]

    def sync_islands(self) -> None:
        isldir = self.data / "islands"
        files = {f.name[:-5]: f for f in sorted(isldir.glob("*.json"))}
        rows = self.rows("islands.csv")
        for cells in rows:
            key = cells["id"].strip()
            f = files.get(key)
            if f is None:
                if key != key.lower() or "_" not in key:
                    self.rot_err("islands.csv", key, "id",
                                 "a new island id should follow <climate>_<tier> (%r)" % key)
                    continue
                f = isldir / (key + ".json")
                files[key] = f
                doc = {"id": key}
                for name, _kind in self.ISLAND_COLS:
                    val = (cells.get(name) or "").strip()
                    if val:
                        doc[name] = self.island_cast(name, val)
                self.jmark(f, doc)
                self.created.append("islands: new island file %s" % f.name)
                continue
            doc = self.jload(f)
            canon = canon_island(doc)
            writers = {}
            for name, _kind in self.ISLAND_COLS:
                writers[name] = (lambda v, c, doc=doc, jname=name: set_field(doc, jname, v))
            if self.apply_cells("islands.csv", key, canon, cells, self.ISLAND_COLS, writers):
                self.jmark(f)
        sheet_keys = {c["id"].strip() for c in rows}
        gone = [(k, "islands/%s.json" % k) for k, f in files.items() if k not in sheet_keys]

        def act(k):
            f = files.pop(k, None)
            if f is not None:
                self.file_delete.add(f)
        self.deletions_for("islands.csv", gone, act)

    @staticmethod
    def island_cast(name, val):
        if name in ("tier", "size_m", "lifetime_seconds"):
            return parse_num(val)
        if name == "permanent":
            return val.lower() in ("true", "yes", "1")
        return val

    # ---- climates -----------------------------------------------------------

    CLIMATE_COLS = [("tiers", "ints"), ("home", "bool"), ("resist", "list"),
                    ("vegetation", "list"), ("materials", "mats")]

    def sync_climates(self) -> None:
        path = self.data / "world/climates.json"
        doc = self.jload(path)
        rows = self.rows("climates.csv")
        for cells in rows:
            key = cells["climate"].strip()
            rec = doc.get(key)
            if rec is None:
                if not (cells.get("tiers") or "").strip():
                    self.rot_err("climates.csv", key, "tiers",
                                 "a new climate row needs a tier list (the generator skips tierless rows)")
                    continue
                rec = {}
                doc[key] = rec
                self.created.append("climates: new row %s" % key)
            canon = canon_climate(rec)
            writers = {name: (lambda v, c, rec=rec, f=name: set_field(rec, f, v))
                       for name, _kind in self.CLIMATE_COLS}
            if self.apply_cells("climates.csv", key, canon, cells, self.CLIMATE_COLS, writers):
                self.jmark(path)
        sheet_keys = {c["climate"].strip() for c in rows}

        def act(k):
            doc.pop(k, None)
            self.jmark(path)
        self.deletions_for("climates.csv",
                           [(k, "climate record") for k in doc
                            if k not in sheet_keys and not str(k).startswith("_")], act)

    # ---- creatures ----------------------------------------------------------

    CREATURE_COLS = [("tier", "num"), ("climate", "str"), ("clade", "str"),
                     ("period", "str"), ("real_length_m", "num")]

    def sync_creatures(self) -> None:
        cdir = self.data / "creatures"
        rows = self.rows("creatures.csv")
        wanted = {c["species"].strip(): c for c in rows}
        species_files = {}
        for f in sorted(cdir.glob("*.json")):
            try:
                d = self.jload(f)
            except (ValueError, OSError):
                continue
            if not isinstance(d, dict) or "species" not in d:
                continue  # ai.json / anim_events.json … are not species files
            sp = str(d.get("species"))
            if sp in species_files:
                self.rot_err("creatures.csv", sp, "species",
                             "species appears in two files (%s, %s)"
                             % (species_files[sp].name, f.name))
                continue
            species_files[sp] = f
        for sp, f in species_files.items():
            cf = wanted.get(sp)
            if cf is None:
                self.pending.append("[creatures.csv] %s removed from the sheet: file %s can be "
                                    "deleted with --apply --allow-delete" % (sp, f.name))
                continue
            doc = self.jload(f)
            canon = canon_creature(doc)
            writers = {name: (lambda v, c, doc=doc, jname=name: set_field(doc, jname, v))
                       for name, _kind in self.CREATURE_COLS}
            if self.apply_cells("creatures.csv", sp, canon, cf, self.CREATURE_COLS, writers):
                self.jmark(f)
        for sp in wanted:
            if sp not in species_files:
                self.rot_err("creatures.csv", sp, "species",
                             "new species rows are code-owned (game/data/creatures is agent-owned, "
                             "see butchering.json's own note); ask for the creature instead")

    # ---- butchering ---------------------------------------------------------

    BUTCHER_COLS = [("min", "num"), ("max", "num"), ("butcher_skill", "num"),
                    ("attributes", "pairs")]

    def sync_butchering(self) -> None:
        path = self.data / "butchering.json"
        doc = self.jload(path)
        species = doc.setdefault("species", {})
        item_ids = {i["id"] for i in self.jload(self.data / "items.json")["items"]}
        stem_by_sp = {}
        for f in sorted((self.data / "creatures").glob("*.json")):
            try:
                d = self.jload(f)
            except (ValueError, OSError):
                continue
            if isinstance(d, dict) and "species" in d:
                stem_by_sp[str(d.get("species")).lower().replace(" ", "_")] = f.name[:-5]
        rows = self.rows("butchering.csv")
        sheet_triples = {}
        for cells in rows:
            sp = cells["species"].strip()
            kind = cells["kind"].strip()
            item = cells["item"].strip()
            key = "%s/%s/%s" % (sp, kind, item)
            if kind not in KINDS:
                self.rot_err("butchering.csv", key, "kind", "must be base or rare")
                continue
            stem = stem_by_sp.get(sp)
            if stem is None:
                self.rot_err("butchering.csv", key, "species",
                             "no creature file matches species key %r" % sp)
                continue
            if item and item not in item_ids:
                self.rot_err("butchering.csv", key, "item", "%r is not an item id" % item)
                continue
            sheet_triples.setdefault(stem, {}).setdefault(kind, set()).add(item)
            smap = species.setdefault(stem, {"base": [], "rare": []})
            drops = smap.setdefault(kind, [])
            x = next((d for d in drops if isinstance(d, dict) and d.get("id") == item), None)
            if x is None:
                if not item:
                    self.rot_err("butchering.csv", key, "item", "row has no item id")
                    continue
                x = {"id": item}
                drops.append(x)
                self.created.append("butchering: new drop %s" % key)
            canon = canon_butchering(x)
            writers = {
                "min": lambda v, c, x=x: set_field(x, "min", v),
                "max": lambda v, c, x=x: set_field(x, "max", v),
                "butcher_skill": lambda v, c, x=x: set_field(x, "skill", v),
                "attributes": lambda v, c, x=x: set_field(x, "attributes", v),
            }
            if self.apply_cells("butchering.csv", key, canon, cells, self.BUTCHER_COLS, writers):
                self.jmark(path)

        gone_drops = []
        for stem, smap in species.items():
            if not isinstance(smap, dict):
                continue
            for kind in KINDS:
                drops = smap.get(kind) or []
                want = sheet_triples.get(stem, {}).get(kind, set())
                for d in drops:
                    if isinstance(d, dict) and str(d.get("id", "")) not in want:
                        gone_drops.append("%s/%s/%s" % (stem, kind, d.get("id", "?")))

        def act(_k):
            for stem, kinds in sheet_triples.items():
                smap = species.get(stem)
                if not isinstance(smap, dict):
                    continue
                for kind in KINDS:
                    drops = smap.get(kind) or []
                    keep = [d for d in drops
                            if not isinstance(d, dict)
                            or str(d.get("id", "")) in kinds.get(kind, set())]
                    if len(keep) != len(drops):
                        smap[kind] = keep
            self.jmark(path)
        self.deletions_for("butchering.csv", [(k, "butchering drop") for k in gone_drops], act)

    # ---- run ----------------------------------------------------------------

    def run(self) -> None:
        self.sync_recipes()
        self.sync_repairs()
        self.sync_processing()
        self.sync_items()
        self.sync_foods()
        self.sync_islands()
        self.sync_climates()
        self.sync_creatures()
        self.sync_butchering()

    # ---- write back ---------------------------------------------------------

    def write_back(self) -> int:
        written = 0
        for path in sorted(self.dirty):
            raw = path.read_text() if path.exists() else ""
            new = self.jdump(self.docs[path])
            if raw == new:
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(new)
            written += 1
        for path in sorted(self.file_delete):
            if path.exists():
                path.unlink()
                written += 1
        return written


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=str(HERE / "game/data"))
    ap.add_argument("--sheets", default=str(HERE / "game/data_sheets"))
    ap.add_argument("--apply", action="store_true", help="write the JSON files (default is a dry run)")
    ap.add_argument("--allow-delete", action="store_true",
                    help="with --apply: permit removed key rows to delete their records")
    ap.add_argument("--skip-tests", action="store_true", help="don't run the canon gate after --apply")
    args = ap.parse_args()
    data, sheets = Path(args.data), Path(args.sheets)
    s = Sync(data, sheets, args.apply, args.allow_delete)
    print("sync_game_data %s" % ("APPLY" if args.apply else "dry-run"))
    print("  data:   %s" % data)
    print("  sheets: %s" % sheets)
    s.run()
    for line in s.created:
        print("  + %s" % line)
    for line in s.applied:
        print("  ~ %s" % line)
    for line in s.pending:
        print("  ? %s" % line)
    for line in s.errors:
        print("  ! %s" % line)
    print("  %d applied cell(s); %d new record(s); %d deletion(s) performed, %d pending; "
          "%d file(s) to write" % (len(s.applied), len(s.created), len(s.freed), len(s.pending),
                                   len(s.dirty)))

    if s.errors:
        print("\nvalidation FAILED — nothing written; fix the listed cells first")
        sys.exit(1)
    if not args.apply:
        print("\ndry run done; %d pending deletion(s)" % len(s.pending) if s.pending else "dry run clean")
        sys.exit(0)
    if s.pending and not args.allow_delete:
        print("\n%d record deletion(s) pending but --allow-delete not passed — refusing; nothing written"
              % len(s.pending))
        sys.exit(2)
    n = s.write_back()
    print("  wrote %d file(s)" % n)

    if args.skip_tests:
        print("\n[--skip-tests] canon gate not run")
        return
    gate = subprocess.run(["bash", str(HERE / "tools/test.sh")], cwd=str(HERE))
    if gate.returncode:
        print("\n[gate] tools/test.sh FAILED (rc=%d); data is written but the build disagrees" % gate.returncode)
        sys.exit(gate.returncode)
    print("\n[gate] tools/test.sh PASS")


if __name__ == "__main__":
    main()
