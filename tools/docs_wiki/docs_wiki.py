#!/usr/bin/env python3
"""Wildlands MMO docs wiki: index the canon checkout and serve
a local site for marking canon / useful / stale, connecting conflicts and
running reconcile tasks (owner 2026-10-27: "navigate the docs and decide what
is canon and what is stale ... lower the overall context bloat").

Reads the live files on every request — nothing is copied — so the site always
shows the current bytes of each doc. Curated state lives in state.json next to
this file (gitignored; Export in the UI writes a portable copy).

Single source of truth (owner 2026-10-27): the canon line — the checkout this
tool lives in — owns every doc that is true today. The `main` checkout is the
archive line: its historical corpus is not indexed or searched by default.
An explicitly requested archive search or known historical Markdown path can
still be read directly.

  python3 tools/docs_wiki.py serve [--port 8899] [--open]

Uses only the Python standard library. Binds 127.0.0.1 only.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os

import phase_map
import re
import stat
import struct
import subprocess
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path, PurePosixPath
from urllib.parse import urlparse, parse_qs

APP_DIR = Path(__file__).resolve().parent
STATE_PATH = APP_DIR / "state.json"
ROOT = APP_DIR.parent.parent  # this checkout = the canon line (curated truth)
SHEETS_DIR = ROOT / "game" / "data_sheets"

DATE_RE = re.compile(r"20[0-9]{2}-[01][0-9]-[0-3][0-9]")
BANNER_RE = re.compile(r"superseded|historical record|archived|do not trust|historical", re.I)
SCAN_PATTERNS = ["*.md", "docs/**/*.md", "assets/concept-art/*.md", "research/*.md"]
SKIP_PARTS = {".git", ".godot", ".dsc", "node_modules", "artifacts", "export", "work"}


def main_root() -> Path | None:
    """The worktree holding the `main` branch, for explicit history lookups."""
    try:
        out = subprocess.run(
            ["git", "-C", str(ROOT), "worktree", "list", "--porcelain"],
            capture_output=True, text=True, check=True, timeout=10,
        ).stdout
    except Exception:
        return None
    candidate_root = None
    for line in out.splitlines():
        if line.startswith("worktree "):
            candidate_root = Path(line[len("worktree "):])
        elif line == "branch refs/heads/main" and candidate_root:
            return candidate_root
    return None


def title_of(path: Path, head: str) -> str:
    for line in head.splitlines()[:12]:
        line = line.strip()
        if line.startswith("# "):
            return line[2:].strip()
        if line.startswith("#!"):
            continue
        if line.startswith("===") or line.startswith("---"):
            continue
    name = path.stem.replace("_", " ").replace("-", " ")
    return name[:1].upper() + name[1:] if name else path.name


def system_of(path: str, title: str) -> str:
    p = path.lower()
    if "/orchestration/reports/" in p:
        return "Reports (execution)"
    if "/orchestration/" in p:
        return "Process & orchestration"
    if "/playtests/" in p:
        return "Playtests"
    if "/research/" in p or "durango-wild-lands" in p:
        return "Reference archive (Durango)"
    if "/concept-art/" in p or "/art/" in p or "style" in p or "benchmarks" in p:
        return "Art & asset pipeline"
    if "handoff" in p or "gauntlet" in p or p == "agents.md" or p == "readme":
        return "Protocol (per-session rules)"
    if "engine" in p or "vercel" in p or "deploy" in p:
        return "Engine & infra"
    if "save" in p or "persist" in p or "schema" in p:
        return "Save & persistence"
    if "server" in p or "multiplayer" in p or "contract" in p:
        return "Multiplayer & server"
    if "economy" in p or "market" in p or "trade" in p or "econ" in p:
        return "Economy & trading"
    if "tame" in p or "pet" in p or "mount" in p or "animal" in p:
        return "Taming, pets & mounts"
    if "creature" in p or "ai" in p or "combat" in p or "bestiar" in p:
        return "Creatures, AI & combat"
    if "craft" in p or "cook" in p or "food" in p or "recipe" in p:
        return "Crafting & cooking"
    if "skill" in p:
        return "Skills"
    if "inventory" in p or "item" in p or "bag" in p or "trait" in p:
        return "Inventory & items"
    if "island" in p or "world" in p or "biome" in p or "climate" in p or "gathering" in p:
        return "World, islands & biomes"
    if "ui" in p or "ux" in p or "screen" in p or "hud" in p or "icon" in p:
        return "UI & UX"
    if "story" in p or "quest" in p or "objective" in p:
        return "Story & objectives"
    if "/prd/" in p or "/vision/" in p:
        return "Vision & PRDs"
    if "/design/" in p or "durango-prompts" in p:
        return "Design"
    return "Other"


def scan_line(checkout: Path, line_name: str) -> list[dict]:
    out = []
    if not checkout.is_dir():
        return out
    for pattern in SCAN_PATTERNS:
        for f in checkout.glob(pattern):
            try:
                if not f.is_file() or not f.resolve().is_relative_to(checkout.resolve()):
                    continue
            except OSError:
                continue
            rel = f.relative_to(checkout).as_posix()
            if any(part in SKIP_PARTS for part in f.parts):
                continue
            try:
                stat = f.stat()
                head = f.read_text(errors="replace")[:4096]
            except OSError:
                continue
            if f.suffix != ".md":
                continue
            dates = DATE_RE.findall(head)
            banner = any(len(ln) < 260 and BANNER_RE.search(ln)
                         for ln in head.splitlines()[:8] if ln.startswith(">"))
            out.append({
                "key": f"{line_name}:{rel}",
                "line": line_name,
                "deep": line_name == "main",
                "path": rel,
                "title": title_of(f, head),
                "system": system_of(rel, head),
                "size": stat.st_size,
                "mtime": int(stat.st_mtime),
                "date": max(dates) if dates else "",
                "banner": banner,
            })
    return out


def build_index() -> dict:
    archive = main_root()
    # Never enumerate the archive: it remains available only via a known path.
    entries = {e["key"]: e for e in scan_line(ROOT, "canon")}
    # Inbound links among the indexed canon documents.
    inbound: dict[str, int] = {k: 0 for k in entries}
    broken: dict[str, int] = {k: 0 for k in entries}
    for key, e in entries.items():
        checkout = ROOT
        f = checkout / e["path"]
        try:
            text = f.read_text(errors="replace")
        except OSError:
            continue
        for url in re.findall(r"\]\(([^)#\s]+?\.md)\)", text):
            target = (f.parent / url).resolve()
            if not target.is_file():
                broken[key] += 1
                continue
            trel = target.relative_to(checkout).as_posix()
            tkey = f"{e['line']}:{trel}"
            if tkey in inbound:
                inbound[tkey] += 1
    systems: dict[str, list[str]] = {}
    for k, e in entries.items():
        systems.setdefault(e["system"], []).append(k)
    for s in systems:
        systems[s].sort(key=lambda k: entries[k]["title"].lower())
    return {
        "generated": int(time.time()),
        "canon_root": str(ROOT),
        "archive_root": str(archive) if archive else "",
        "docs": dict(sorted(entries.items())),
        "inbound": inbound,
        "broken": broken,
        # Retain the response field for existing clients without scanning history.
        "cross_line_diffs": [],
        "systems": systems,
    }


def read_archive_doc(key: str, archive: Path | None = None) -> str:
    """Read one explicitly named historical Markdown document, without listing history."""
    if not key.startswith("main:"):
        raise FileNotFoundError(key)
    path = key[len("main:"):]
    if not path or "\\" in path or "\x00" in path:
        raise FileNotFoundError(key)
    requested = PurePosixPath(path)
    if requested.is_absolute() or ".." in requested.parts or any(p in SKIP_PARTS for p in requested.parts):
        raise FileNotFoundError(key)
    # Match the historical wiki's supported source roots, rather than exposing
    # arbitrary files elsewhere in the archive checkout.
    in_source = (len(requested.parts) == 1 or requested.parts[0] in ("docs", "research")
                 or requested.is_relative_to(PurePosixPath("assets/concept-art")))
    if not in_source or requested.suffix.lower() != ".md":
        raise FileNotFoundError(key)
    archive = archive if archive is not None else main_root()
    if archive is None:
        raise FileNotFoundError(key)
    target = (archive / path).resolve(strict=True)
    if not target.is_relative_to(archive.resolve()) or not target.is_file():
        raise FileNotFoundError(key)
    return target.read_text(errors="replace")


def search_archive(query: str) -> list[dict]:
    """Search history only on explicit request; return small snippets, not bodies."""
    query = query.strip()
    if not query or len(query) > 200:
        raise ValueError("query must contain 1 to 200 characters")
    archive = main_root()
    if archive is None:
        return []
    needle = query.casefold()
    results = []
    for entry in scan_line(archive, "main"):
        try:
            body = read_archive_doc(entry["key"], archive)
        except OSError:
            continue
        location = body.casefold().find(needle)
        if location < 0 and needle not in (entry["path"] + " " + entry["title"]).casefold():
            continue
        # Bound the preview and collapse line breaks so callers can display it
        # without loading whole archive documents into their context.
        start = max(0, location - 80) if location >= 0 else 0
        excerpt = " ".join(body[start:start + 240].split())
        results.append({**entry, "excerpt": excerpt})
        if len(results) == 50:
            break
    return results


# ---------------------------------------------------------------- state seed

def load_state(index: dict) -> dict:
    if STATE_PATH.exists():
        try:
            state = json.loads(STATE_PATH.read_text())
            if isinstance(state, dict) and "docs" in state:
                seed_model_marks(state, save=True)
                return state
        except (OSError, ValueError):
            pass
    state = seed_state(index)
    seed_model_marks(state, save=True)
    return state


def seed_state(index: dict) -> dict:
    """Start the mark pass from things this session already established. Every
    seeded entry keeps by:"seed" so a human click can confirm or replace it."""
    docs = index["docs"]
    state: dict = {"docs": {}, "tasks": [], "dismissed": [], "updatedAt": int(time.time())}

    seeds = [
        ("archive", "Reconciled 2026-10-27. Truth for the ARCHIVE line only: main is parked; the game lives on claude/mmo-overhaul.", ["main:HANDOFF.md"]),
        ("conflict", "Differs across main and the canon line — reconcile: which sections are binding for the canon program?", ["canon:HANDOFF.md"]),
        ("useful", "Standing rules; still the working protocol on both lines.", ["main:GAUNTLET.md", "canon:GAUNTLET.md", "main:AGENTS.md", "canon:AGENTS.md"]),
        ("canon", "Measured Durango budget table; adopted as the authority 2026-10-27 (STYLE.md reconciled to it).", ["main:docs/art/durango-asset-benchmarks-and-tripo-prompts.md", "canon:docs/art/durango-asset-benchmarks-and-tripo-prompts.md"]),
        ("stale", "SUPERSEDED banner 2026-10-27: real-species policy dropped, Meshy text-to-3D pipeline + tri numbers superseded.", ["main:docs/prd/dinosaur-roster-and-3d-pipeline.md", "canon:docs/prd/dinosaur-roster-and-3d-pipeline.md"]),
        ("stale", "HISTORICAL RECORD banner 2026-09-17: milestone numbering diverges from what executed.", ["main:docs/orchestration/plan.md", "canon:docs/orchestration/plan.md"]),
        ("stale", "Engine choice stands, but the import/export specifics are historical; HANDOFF is the pipeline authority.", ["main:docs/engine-decision.md", "canon:docs/engine-decision.md"]),
    ]
    seeds = [(status, note, [k for k in keys if k in docs]) for status, note, keys in seeds]
    for status, note, keys in seeds:
        for key in keys:
            state["docs"][key] = {"status": status, "notes": note, "links": [], "by": "seed"}
    if index["canon_root"]:
        for key, e in docs.items():
            if state["docs"].get(key):
                continue
            if e["line"] == "canon" and e["system"] == "Reports (execution)":
                state["docs"][key] = {"status": "useful", "notes": "Execution history of the canon program; supersedes process plans.", "links": [], "by": "seed"}
            if e["line"] == "canon" and e["system"] == "Reference archive (Durango)":
                state["docs"][key] = {"status": "useful", "notes": "Field research; reference, not canon.", "links": [], "by": "seed"}
    return state


# ------------------------------------------------------------ model marks

MODEL_MARK_STATUSES = ("", "review", "rebuild", "delete", "redo-animations", "ok")

MODEL_MARK_SEEDS: tuple[tuple[str, str, str], ...] = (
    # Owner defect reports first seen in the 3D previewer, 2026-10-27.
    ("game/assets/creatures/deinonychus/deinonychus.glb", "rebuild",
     "Owner: rebuild from concept art — the model itself is bad and has a third leg."),
    ("game/assets/creatures/coelophysis/coelophysis.glb", "redo-animations",
     "Owner: walks and runs backwards, and never opens its mouth (the rig has no jaw bone). Corrupted keyframe times may read as the backwards gait — repair first, then judge."),
    ("game/assets/creatures/protoceratops/protoceratops.glb", "redo-animations",
     "Owner: the run is the walk animation — the run needs to be redone. (Data: the run clip is distinct but reads nearly in-place, same stance drift as the walk, so the redo verdict stands.)"),
    ("game/assets/creatures/tyrannosaurus/tyrannosaurus.glb", "review",
     "Owner: the mouth stretches when opened, as if taped to the snout — jaw weighting needs a look."),
    # Gait audit (tools/audit_gaits.py, 2026-10-27): stance-foot drift through the
    # stance window; correct in-place gaits push the foot backwards in rig space,
    # so clearly positive drift reads as an authored backwards walk.
    ("game/assets/creatures/gallimimus/gallimimus.glb", "review",
     "Audit: stance foot slides forward (+0.38 walk / +0.53 run) — both gaits read backwards; likely remirror rather than regenerate."),
    ("game/assets/creatures/compsognathus/compsognathus.glb", "review",
     "Audit: stance foot slides forward (+0.30 walk / +0.42 run) — both gaits read backwards; likely remirror rather than regenerate."),
    ("game/assets/creatures/utahraptor/utahraptor.glb", "review",
     "Audit: stance foot slides forward (+0.30 walk / +0.49 run) — both gaits read backwards; likely remirror rather than regenerate."),
    ("game/assets/creatures/velociraptor/velociraptor.glb", "review",
     "Audit: stance foot slides forward (+0.30 walk / +0.49 run) — both gaits read backwards; likely remirror rather than regenerate."),
    # Owner: both stegosaurus builds are good; keep them as regional variants.
    ("game/assets/creatures/stegosaurus/stegosaurus.glb", "ok",
     "Owner: regular and v1 are both good models — treat as regional variants."),
    ("game/assets/creatures/stegosaurus/v1/stegosaurus.glb", "ok",
     "Owner: v1 is a regional variant of the regular model; both are good."),
)


def seed_model_marks(state: dict, save: bool = False) -> None:
    """Seed state["models"] with owner-reported and audited model defects.

    Every seeded entry keeps by:"seed" so the viewer presents it as a
    suggestion; a mark saved by a person (a path already present) wins."""
    models = state.setdefault("models", {})
    added = False
    for path, status, note in MODEL_MARK_SEEDS:
        if path not in models:
            models[path] = {"status": status, "notes": note, "by": "seed"}
            added = True
    if added and save:
        STATE_PATH.write_text(json.dumps(state, indent=1))


def model_marks() -> dict:
    """Per-model marks for /api/models: state.json entries plus the seeds.

    On a checkout with no state.json yet, route through load_state so the doc
    seeds are written beside them instead of committing a docs-less state."""
    try:
        data = json.loads(STATE_PATH.read_text())
    except (OSError, ValueError):
        data = None
    if isinstance(data, dict):
        seed_model_marks(data, save=True)
        return data.get("models") or {}
    return load_state(get_index()).get("models") or {}


# ---------------------------------------------------------------- server

CACHED: dict | None = None


def get_index() -> dict:
    global CACHED
    CACHED = build_index()
    return CACHED


SHEET_NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*\.csv\Z")
JSON_TUNING_FILES = (
    "game/data/combat_tuning.json",
    "game/data/combat_counters.json",
    "game/data/world/rules.json",
    "game/data/statuses.json",
    "game/data/inventory.json",
    "game/data/farming.json",
    "game/data/food_buffs.json",
    "game/data/skills/trees.json",
    "game/data/creatures/ai.json",
    "game/data/bags.json",
    "game/data/structures.json",
    "game/data/blueprints.json",
    "game/data/water.json",
    "game/data/item_rarity.json",
    "game/data/world/domains.json",
    "game/data/world/market.json",
    "game/data/world/factions.json",
    "game/data/world/missions.json",
    "game/data/skills/occupations.json",
    "game/data/skills/pioneer_levels.json",
    "game/data/skills/survival.json",
    "game/data/skills/titles.json",
    "game/data/creatures/allosaurus.json",
    "game/data/creatures/ankylosaurus.json",
    "game/data/creatures/brachiosaurus.json",
    "game/data/creatures/coelophysis.json",
    "game/data/creatures/compsognathus.json",
    "game/data/creatures/deinonychus.json",
    "game/data/creatures/dilophosaurus.json",
    "game/data/creatures/gallimimus.json",
    "game/data/creatures/megaloceros.json",
    "game/data/creatures/protoceratops.json",
    "game/data/creatures/smilodon.json",
    "game/data/creatures/stegosaurus.json",
    "game/data/creatures/styracosaurus.json",
    "game/data/creatures/tarbosaurus.json",
    "game/data/creatures/triceratops.json",
    "game/data/creatures/tyrannosaurus.json",
    "game/data/creatures/utahraptor.json",
    "game/data/creatures/velociraptor.json",
    "game/data/creatures/zebraceratops.json",
)
TRAIT_MAP_SHEET = "json:game/data/world/rules.json#traits"


def read_sheet(name: str) -> dict:
    """Read an existing sheet without following links or allowing path traversal.

    The revision hashes the original bytes, including newlines and any BOM, so
    an exported proposal can be compared against the exact source it was based on.
    """
    if not SHEET_NAME_RE.fullmatch(name):
        raise ValueError("invalid sheet name")
    path = SHEETS_DIR / name
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    # lstat plus O_NOFOLLOW ensures a symlink is never exposed as a sheet.
    if path.is_symlink():
        raise FileNotFoundError(name)
    try:
        fd = os.open(path, flags)
    except OSError as exc:
        if path.is_symlink():
            raise FileNotFoundError(name) from exc
        raise
    with os.fdopen(fd, "rb") as f:
        if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
            raise FileNotFoundError(name)
        raw = f.read()
    try:
        parsed = list(csv.reader(io.StringIO(raw.decode("utf-8-sig"), newline=""), strict=True))
    except (UnicodeDecodeError, csv.Error) as exc:
        raise ValueError("invalid CSV encoding or syntax") from exc
    if not parsed or not parsed[0]:
        raise ValueError("sheet has no header")
    columns, rows = parsed[0], parsed[1:]
    if any(len(row) != len(columns) for row in rows):
        raise ValueError("sheet contains rows with inconsistent column counts")
    return {"name": name, "kind": "csv", "source_path": "game/data_sheets/" + name,
            "columns": columns, "editable_columns": columns[1:], "rows": rows,
            "revision": hashlib.sha256(raw).hexdigest()}


def read_json_sheet(name: str) -> dict:
    """Expose numeric leaves of explicitly curated game-data files as rows.

    JSON pointers are stable addresses only while the source revision matches.
    These read-only rows are a draft starting point, not an automatic writeback.
    """
    trait_map = name == TRAIT_MAP_SHEET
    if not trait_map and (not name.startswith("json:") or name[5:] not in JSON_TUNING_FILES):
        raise FileNotFoundError(name)
    source_path = "game/data/world/rules.json" if trait_map else name[5:]
    target = (ROOT / source_path).resolve(strict=True)
    if not target.is_relative_to((ROOT / "game/data").resolve()) or not target.is_file():
        raise FileNotFoundError(name)
    raw = target.read_bytes()
    try:
        doc = json.loads(raw.decode("utf-8-sig"), parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x)))
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise ValueError("invalid JSON source") from exc
    revision = hashlib.sha256(raw).hexdigest()
    if trait_map:
        attributes = doc.get("attributes") if isinstance(doc, dict) else None
        if not isinstance(attributes, dict) or any(not isinstance(v, str) for v in attributes.values()):
            raise ValueError("invalid trait attributes map")
        rows = [["/attributes/" + key.replace("~", "~0").replace("/", "~1"), key, effect]
                for key, effect in attributes.items()]
        return {"name": name, "kind": "trait-map", "source_path": source_path,
                "columns": ["parameter", "trait name", "documented effect"],
                "editable_columns": ["trait name", "documented effect"], "rows": rows,
                "revision": revision,
                "description": "Documented effects describe the data; they do not prove an effect is implemented."}
    rows = []

    def walk(value, path):
        if isinstance(value, dict):
            for key, item in value.items():
                # Underscored keys are explanatory metadata in these data files.
                if key.startswith("_"):
                    continue
                # Species definitions include model/animation pipeline and
                # appearance data; they are not gameplay tuning parameters.
                if (not path and source_path.startswith("game/data/creatures/")
                        and source_path != "game/data/creatures/ai.json"
                        and key in {"clips", "pipeline", "coloration", "eyes"}):
                    continue
                walk(item, path + "/" + key.replace("~", "~0").replace("/", "~1"))
        elif isinstance(value, list):
            for index, item in enumerate(value):
                walk(item, path + "/" + str(index))
        elif isinstance(value, (int, float)) and not isinstance(value, bool):
            value_type = "integer" if isinstance(value, int) else "number"
            rows.append([path, value_type, json.dumps(value, allow_nan=False)])
        elif (isinstance(value, str) and source_path == "game/data/world/rules.json"
              and re.fullmatch(r"/crafting/rare_attributes/\d+", path)):
            rows.append([path, "string", value])

    walk(doc, "")
    return {"name": name, "kind": "json", "source_path": source_path,
            "columns": ["parameter", "type", "value"], "editable_columns": ["value"],
            "rows": rows, "revision": revision,
            "description": "Values come from game data; inclusion does not prove the build uses every value."}


def list_sheets() -> list[dict]:
    """List regular CSV sheets and explicitly curated JSON sources."""
    result = []
    for path in sorted(SHEETS_DIR.glob("*.csv")):
        if not SHEET_NAME_RE.fullmatch(path.name) or path.is_symlink() or not path.is_file():
            continue
        sheet = read_sheet(path.name)
        result.append({key: sheet[key] for key in ("name", "kind", "source_path", "columns", "editable_columns")}
                      | {"row_count": len(sheet["rows"])})
    for source_path in JSON_TUNING_FILES:
        if not (ROOT / source_path).exists():
            continue
        sheet = read_json_sheet("json:" + source_path)
        result.append({key: sheet[key] for key in ("name", "kind", "source_path", "columns", "editable_columns", "description")}
                      | {"row_count": len(sheet["rows"])})
    if (ROOT / "game/data/world/rules.json").exists():
        sheet = read_json_sheet(TRAIT_MAP_SHEET)
        result.append({key: sheet[key] for key in ("name", "kind", "source_path", "columns", "editable_columns", "description")}
                      | {"row_count": len(sheet["rows"])})
    return result


IMAGE_ROOTS = ("docs/current/screens", "docs/reference", "docs/art", "assets/concept-art", "artifacts/web-shader-soak", "artifacts/wiki", "game/assets")
IMAGE_TYPES = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}


def read_image(path: str) -> tuple[bytes, str]:
    """Read an image under an allowlisted root, excluding symlink escapes."""
    if not path or "\\" in path or "\x00" in path:
        raise FileNotFoundError(path)
    requested = PurePosixPath(path)
    if requested.is_absolute() or ".." in requested.parts:
        raise FileNotFoundError(path)
    content_type = IMAGE_TYPES.get(requested.suffix.lower())
    if content_type is None:
        raise FileNotFoundError(path)
    target = (ROOT / str(requested)).resolve(strict=True)
    for image_root in IMAGE_ROOTS:
        allowed = (ROOT / image_root).resolve()
        if (requested.is_relative_to(PurePosixPath(image_root)) and target.is_relative_to(allowed)
                and allowed.is_relative_to(ROOT.resolve()) and target.is_file()):
            return target.read_bytes(), content_type
    raise FileNotFoundError(path)


def model_path(path: str) -> Path:
    """Resolve a GLB within game/assets, rejecting escapes and editor caches."""
    if not path or "\\" in path or "\x00" in path:
        raise FileNotFoundError(path)
    requested = PurePosixPath(path)
    if (requested.is_absolute() or ".." in requested.parts
            or not requested.is_relative_to(PurePosixPath("game/assets"))
            or requested.suffix.lower() != ".glb"
            or any(part.startswith(".") or part in SKIP_PARTS for part in requested.parts)):
        raise FileNotFoundError(path)
    allowed = (ROOT / "game/assets").resolve()
    target = (ROOT / str(requested)).resolve(strict=True)
    if not allowed.is_relative_to(ROOT.resolve()) or not target.is_relative_to(allowed) or not target.is_file():
        raise FileNotFoundError(path)
    if (target.suffix.lower() != ".glb"
            or any(part.startswith(".") or part in SKIP_PARTS for part in target.relative_to(allowed).parts)):
        raise FileNotFoundError(path)
    return target


GLB_HEADER_LEN = 12
GLB_CHUNK_HEADER_LEN = 8
GLB_JSON_CHUNK_TYPE = b"JSON"
GLB_JSON_CAP = 50_000_000  # a hostile-chunk ceiling; scanned JSONs are far below this


def read_glb_json(path: Path) -> dict | None:
    """The JSON chunk of a GLB header (first chunk), or None when not a GLB or unusable."""
    try:
        with open(path, "rb") as f:
            header = f.read(GLB_HEADER_LEN)
            if len(header) < GLB_HEADER_LEN or header[:4] != b"glTF":
                return None
            chunk = f.read(GLB_CHUNK_HEADER_LEN)
            if len(chunk) < GLB_CHUNK_HEADER_LEN or chunk[4:8] != GLB_JSON_CHUNK_TYPE:
                return None
            size = struct.unpack_from("<I", chunk, 0)[0]
            if size <= 0 or size > GLB_JSON_CAP:
                return None
            blob = f.read(size)
    except OSError:
        return None
    if len(blob) < size:
        return None
    try:
        doc = json.loads(blob)
    except (ValueError, UnicodeDecodeError):
        return None
    return doc if isinstance(doc, dict) else None


def glb_summary(path: Path) -> dict | None:
    """What a GLB carries for the viewer: mesh count, skins, animation clips."""
    doc = read_glb_json(path)
    if doc is None:
        return None
    return {
        "meshes": len(doc.get("meshes") or []),
        "skins": bool(doc.get("skins")),
        "clips": len(doc.get("animations") or []),
    }


def model_family(relative: str) -> tuple[str, str] | None:
    """The character/creature species folder a GLB belongs to, when there is one."""
    parts = relative.split("/")
    if parts[0:2] != ["game", "assets"]:
        return None
    parts = parts[2:]
    if len(parts) > 1 and parts[0] in ("characters", "creatures"):
        return (parts[0], parts[1])
    return None


def model_group(relative: str) -> str:
    """Selector bucket for the asset dropdown (owner's order: player, creatures,
    nature, props, generated; anything unusual falls into `other`)."""
    parts = relative.split("/")
    if parts[0:2] != ["game", "assets"]:
        return "other"
    if "generated" in parts[3:]:
        return "generated"
    top = parts[2] if len(parts) > 3 else ""
    return {"characters": "player", "creatures": "creatures",
            "nature": "nature", "props": "props"}.get(top, "other")


def norm_anim_name(name: str) -> str:
    """Comparable animation label; case and separators don't matter."""
    return name.lower().replace("_", " ").replace("-", " ").strip()


ANIM_STATUS_PATH = APP_DIR / "model-animations.json"


def load_anim_status() -> dict:
    """Owner-recorded per-species animation design status (wiki-maintenance.md)."""
    try:
        data = json.loads(ANIM_STATUS_PATH.read_text())
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


RIDER_PATH = "game/assets/characters/survivor/survivor.glb"


def mount_block(family: tuple[str, str]) -> dict | None:
    """Owner-recorded rider-on-saddle placement (mount.json) for the mounted view.

    Returns the saddle path, the rider path, and the rider armature root in the
    mount's glTF Y-up model space — the same matrix the engine's mount viewer uses.
    """
    try:
        data = json.loads(
            (ROOT / "game/assets" / family[0] / family[1] / "mount" / "mount.json").read_text())
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict):
        return None
    saddle = data.get("saddle")
    if not (isinstance(saddle, str) and saddle.endswith(".glb")
            and "/" not in saddle and "\\" not in saddle):
        return None
    matrix = data.get("rider_in_mount")
    if not (isinstance(matrix, list) and len(matrix) == 16
            and all(isinstance(v, (int, float)) and -1e9 < v < 1e9 for v in matrix)):
        return None
    rider = RIDER_PATH
    try:
        model_path(rider)
        model_path(f"game/assets/{family[0]}/{family[1]}/mount/{saddle}")
    except (OSError, ValueError):
        return None
    scale = data.get("scale")
    game_scale = None
    if isinstance(scale, dict):
        value = scale.get("game_m_per_source")
        if isinstance(value, (int, float)) and 0 < value < 1e4:
            game_scale = float(value)
    block = {
        "saddle": f"game/assets/{family[0]}/{family[1]}/mount/{saddle}",
        "rider": rider,
        "rider_in_mount": [float(v) for v in matrix],
    }
    if game_scale is not None:
        # The GLB is authored at source scale; the engine scales it to game
        # height. The previewer must reproduce that on the mount side only.
        block["scale"] = {"game_m_per_source": game_scale}
    return block


def list_models() -> list[dict]:
    """Index previewable GLBs under game/assets for the wiki asset selector.

    Entries carry `group` for the owner's ordering. A family ("characters" or
    "creatures" species) rig entry also carries `anims`: every clip file of that
    species — animation-only libraries first, then per-clip mesh exports (mesh +
    its own clip, that the game exports per motion) when no library file already
    covers the same motion. Per-clip export files stay out of the model list when
    a same-family rig exists to host them. `missing` and `cancelled` carry the
    owner-recorded animation design status for the species.
    """
    assets = ROOT / "game/assets"
    status = load_anim_status()
    libraries: dict[tuple[str, str], list[dict]] = {}
    covered: dict[tuple[str, str], set[str]] = {}
    export_files: dict[tuple[str, str], list[dict]] = {}
    export_meshes: list[dict] = []
    hosts: set[tuple[str, str]] = set()
    meshes: list[tuple[dict, tuple[str, str] | None]] = []
    for model in sorted(assets.rglob("*.glb")):
        relative = model.relative_to(ROOT).as_posix()
        try:
            model_path(relative)
        except (OSError, ValueError):
            continue
        summary = glb_summary(model)
        if summary is None or summary["meshes"] == 0:
            # Animation-only clip files cannot render alone; they become part of
            # the family rig's animation library. Malformed GLBs stay invisible.
            if summary and summary["clips"] and (family := model_family(relative)):
                libraries.setdefault(family, []).append({
                    "path": relative,
                    "name": model.stem.replace("_", " ").replace("-", " "),
                    "clips": summary["clips"],
                })
                covered.setdefault(family, set()).add(norm_anim_name(model.stem))
            continue
        entry = {
            "path": relative,
            "name": model.stem.replace("_", " ").replace("-", " "),
            "group": model_group(relative),
        }
        if "v1" in relative.split("/"):
            entry["variant"] = "v1"
        family = model_family(relative) if summary["skins"] else None
        if family and "anim" in relative.split("/") and summary["clips"]:
            # A species mesh that ships its own clip is a per-clip export of the
            # rig pass; the family host rig carries the motion in its library.
            export_files.setdefault(family, []).append({
                "path": relative,
                "name": model.stem.replace("_", " ").replace("-", " "),
                "clips": summary["clips"],
                "stem": norm_anim_name(model.stem),
            })
            export_meshes.append(entry)
            continue
        if family:
            hosts.add(family)
        meshes.append((entry, family))
    # A family host rig picks up per-clip export files not already covered by an
    # animation-only library file of the same motion.
    for family in hosts:
        lib, seen = libraries.setdefault(family, []), covered.setdefault(family, set())
        for item in export_files.get(family, []):
            if item["stem"] in seen:
                continue
            seen.add(item["stem"])
            lib.append(item)
    described = {"path", "name", "clips", "stem"}
    result: list[dict] = []
    blocks: dict[tuple[str, str], dict | None] = {}
    marks = model_marks()
    for entry, family in meshes:
        if family:
            if family in libraries:
                entry["anims"] = [
                    {key: clip[key] for key in clip if key in described}
                    for clip in libraries[family]
                ]
            if family not in blocks:
                blocks[family] = mount_block(family)
            if blocks[family] and "mount" not in entry["path"].split("/"):
                entry["mount"] = blocks[family]
        mark = marks.get(entry["path"])
        if mark:
            entry["mark"] = {"status": mark.get("status", ""), "notes": mark.get("notes", ""), "by": mark.get("by", "")}
            planned = status.get(f"{family[0]}/{family[1]}")
            if isinstance(planned, dict):
                cancelled = [c for c in planned.get("cancelled", [])
                             if isinstance(c, dict) and isinstance(c.get("name"), str) and c["name"]]
                marked = {norm_anim_name(c["name"]) for c in cancelled}
                have = covered.get(family, set())
                missing = [name for name in planned.get("expected", [])
                           if isinstance(name, str) and name
                           and norm_anim_name(name) not in have
                           and norm_anim_name(name) not in marked]
                if cancelled:
                    entry["cancelled"] = [
                        {"name": c["name"], **({"note": c["note"]} if isinstance(c.get("note"), str) and c["note"] else {})}
                        for c in cancelled
                    ]
                if missing:
                    entry["missing"] = missing
        result.append(entry)
    # Une-hosted exports (no family rig on this line) stay visible alone.
    for entry in export_meshes:
        if model_family(entry["path"]) not in hosts:
            result.append(entry)
    return result


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):  # quiet
        pass

    def _send(self, code: int, body: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj: dict) -> None:
        self._send(200, json.dumps(obj).encode(), "application/json")

    def _static(self, name: str) -> None:
        f = APP_DIR / name
        if not f.is_file():
            self._send(404, b"not found", "text/plain")
            return
        ctype = "text/html" if name.endswith(".html") else "text/css" if name.endswith(".css") else "text/javascript" if name.endswith(".js") else "application/octet-stream"
        self._send(200, f.read_bytes(), f"{ctype}; charset=utf-8")

    def do_GET(self) -> None:
        u = urlparse(self.path)
        if u.path == "/":
            self._static("app.html")
        elif u.path in ("/app.js", "/app.css", "/marked.min.js", "/boards.js", "/boards.css", "/tuning.js", "/tuning.css", "/models.js", "/models.css", "/plan.js", "/plan.css",
                        "/vendor/three/three.module.js", "/vendor/three/three.core.js",
                        "/vendor/three/GLTFLoader.js", "/vendor/three/OrbitControls.js",
                        "/vendor/three/BufferGeometryUtils.js", "/vendor/three/SkeletonUtils.js"):
            self._static(u.path.lstrip("/"))
        elif u.path == "/api/index":
            idx = get_index()
            self._json(idx)
        elif u.path == "/api/archive/search":
            query = (parse_qs(u.query).get("q") or [""])[0]
            try:
                self._json({"results": search_archive(query)})
            except ValueError:
                self._send(400, b"query must contain 1 to 200 characters", "text/plain; charset=utf-8")
        elif u.path == "/api/state":
            self._json(load_state(get_index()))
        elif u.path == "/api/sheets":
            try:
                self._json({"sheets": list_sheets()})
            except (OSError, ValueError):
                self._send(500, b"unable to read sheets", "text/plain; charset=utf-8")
        elif u.path == "/api/sheet":
            name = (parse_qs(u.query).get("name") or [""])[0]
            try:
                self._json(read_json_sheet(name) if name.startswith("json:") else read_sheet(name))
            except FileNotFoundError:
                self._send(404, b"unknown sheet", "text/plain; charset=utf-8")
            except ValueError:
                self._send(400, b"invalid sheet name or CSV", "text/plain; charset=utf-8")
            except OSError:
                self._send(500, b"unable to read sheet", "text/plain; charset=utf-8")
        elif u.path == "/api/image":
            path = (parse_qs(u.query).get("path") or [""])[0]
            try:
                body, content_type = read_image(path)
                self._send(200, body, content_type)
            except (OSError, ValueError):
                self._send(404, b"unknown image", "text/plain; charset=utf-8")
        elif u.path == "/api/models":
            self._json({"models": list_models()})
        elif u.path == "/api/phase":
            try:
                self._json(phase_map.merge(phase_map.load(ROOT), load_state(get_index()).get("phases", {})))
            except phase_map.PhaseError as exc:
                self._send(500, f"phase map broken: {exc}".encode("utf-8"), "text/plain; charset=utf-8")
        elif u.path == "/api/model":
            path = (parse_qs(u.query).get("path") or [""])[0]
            try:
                self._send(200, model_path(path).read_bytes(), "model/gltf-binary")
            except (OSError, ValueError):
                self._send(404, b"unknown model", "text/plain; charset=utf-8")
        elif u.path == "/api/doc":
            q = parse_qs(u.query)
            key = (q.get("key") or [""])[0]
            if key.startswith("main:"):
                try:
                    text = read_archive_doc(key)
                except (OSError, ValueError):
                    self._send(404, b"unknown doc", "text/plain")
                    return
                self._send(200, text.encode("utf-8"), "text/plain; charset=utf-8")
                return
            idx = get_index()
            if key not in idx["docs"]:
                self._send(404, b"unknown doc", "text/plain")
                return
            e = idx["docs"][key]
            f = ROOT / e["path"]
            try:
                text = f.read_text(errors="replace")
            except OSError:
                self._send(500, b"unreadable", "text/plain")
                return
            self._send(200, text.encode("utf-8"), "text/plain; charset=utf-8")
        else:
            self._send(404, b"not found", "text/plain")

    def do_POST(self) -> None:
        route = urlparse(self.path).path
        if route in ("/api/plan/analyze", "/api/plan/apply", "/api/plan/refactor"):
            self._plan_post(route)
            return
        if route not in ("/api/state", "/api/mark", "/api/phase"):
            self._send(404, b"not found", "text/plain")
            return
        n = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(n) or b"{}"
        if route == "/api/state":
            try:
                state = json.loads(raw)
                assert isinstance(state, dict) and isinstance(state.get("docs"), dict)
            except (ValueError, AssertionError):
                self._send(400, b"bad state", "text/plain")
                return
            try:
                prior_raw = json.loads(STATE_PATH.read_text())
                prior_docs = prior_raw.get("docs") if isinstance(prior_raw, dict) else None
            except (OSError, ValueError):
                prior_docs = None
            allow_shrink = state.pop("allow_shrink", False)
            if (isinstance(prior_docs, dict) and len(prior_docs) > len(state["docs"])
                    and allow_shrink is not True):
                # A partial client payload must not eat curated doc marks.
                self._send(409, b"doc marks would drop entries; send the full docs store or allow_shrink:true", "text/plain")
                return
            if "models" not in state or "phases" not in state:
                # Doc-mark posts come from the article UI; never let a stale
                # article payload clobber the model or phase marks beside them.
                try:
                    prior = json.loads(STATE_PATH.read_text())
                    if isinstance(prior, dict):
                        if "models" not in state and "models" in prior:
                            state["models"] = prior["models"]
                        if "phases" not in state and "phases" in prior:
                            state["phases"] = prior["phases"]
                except (OSError, ValueError):
                    pass
            state["updatedAt"] = int(time.time())
            STATE_PATH.write_text(json.dumps(state, indent=1))
            self._json({"ok": True, "updatedAt": state["updatedAt"]})
            return
        if route == "/api/phase":
            try:
                body = json.loads(raw)
                assert isinstance(body, dict)
                fid = body["id"]
                status = body.get("status", "")
                note = body.get("note", "")
                assert isinstance(fid, str) and isinstance(status, str) and isinstance(note, str)
                assert status in (("",)) + phase_map.STATUSES
                if status or note:
                    assert fid in {f["id"] for p in phase_map.load(ROOT)["phases"] for f in p["features"]}
            except (ValueError, AssertionError, KeyError, TypeError):
                self._send(400, b"bad phase mark", "text/plain")
                return
            state = load_state(get_index())
            phases = state.setdefault("phases", {})
            mark = {"status": status, "note": note, "by": "mark"} if (status or note) else None
            if mark:
                phases[fid] = mark
            else:
                phases.pop(fid, None)
            state["updatedAt"] = int(time.time())
            STATE_PATH.write_text(json.dumps(state, indent=1))
            self._json({"ok": True, "mark": mark})
            return
        try:
            body = json.loads(raw)
            assert isinstance(body, dict) and body.get("kind", "model") == "model"
            path = body["path"]
            status = body.get("status", "")
            note = body.get("note", "")
            assert isinstance(path, str) and isinstance(status, str) and isinstance(note, str)
            assert status in MODEL_MARK_STATUSES
            if status or note:
                model_path(path)
        except (ValueError, AssertionError, KeyError, TypeError):
            self._send(400, b"bad mark", "text/plain")
            return
        state = load_state(get_index())
        models = state.setdefault("models", {})
        mark = {"status": status, "notes": note, "by": "mark"} if (status or note) else None
        if mark:
            models[path] = mark
        else:
            models.pop(path, None)
        state["updatedAt"] = int(time.time())
        STATE_PATH.write_text(json.dumps(state, indent=1))
        self._json({"ok": True, "mark": mark})

    def _plan_post(self, route: str) -> None:
        """Accept plan operations only from this local wiki origin."""
        origin = urlparse(self.headers.get("Origin", ""))
        host = self.headers.get("Host", "").lower()
        allowed_hosts = {f"localhost:{self.server.server_port}", f"127.0.0.1:{self.server.server_port}"}
        if (origin.scheme != "http" or origin.netloc.lower() != host or host not in allowed_hosts
                or self.headers.get_content_type() != "application/json"):
            self._send(403, b"Request must come from this local wiki.", "text/plain; charset=utf-8")
            return
        try:
            n = int(self.headers.get("Content-Length", "0"))
            if n <= 0 or n > 700_000:
                raise ValueError("Invalid request size.")
            body = json.loads(self.rfile.read(n))
            if not isinstance(body, dict):
                raise ValueError("Expected a JSON object.")
        except (ValueError, UnicodeDecodeError):
            self._send(400, b"Invalid plan request.", "text/plain; charset=utf-8")
            return
        import plan_edits
        import plan_reconcile
        try:
            if route == "/api/plan/analyze":
                result = plan_reconcile.analyze(body.get("plan"), body.get("answers"))
            elif route == "/api/plan/refactor":
                import plan_refactor
                if body.get("action") == "apply":
                    result = plan_refactor.apply_split(ROOT, body)
                else:
                    result = plan_refactor.propose_refactor(body.get("path"))
            else:
                result = plan_edits.apply_vision_edits(ROOT, body)
        except plan_reconcile.ProviderUnavailable as exc:
            self._send(503, str(exc).encode("utf-8"), "text/plain; charset=utf-8")
            return
        except plan_edits.StaleEdit as exc:
            self._send(409, str(exc).encode("utf-8"), "text/plain; charset=utf-8")
            return
        except (plan_reconcile.PlanError, plan_edits.EditError, ValueError) as exc:
            self._send(400, str(exc).encode("utf-8"), "text/plain; charset=utf-8")
            return
        self._json(result)


def serve(port: int, open_browser: bool) -> None:
    idx = get_index()
    print(f"[wiki] truth (curated, this line)={ROOT}")
    print(f"[wiki] archive (not indexed)={idx['archive_root'] or '(main not checked out)'}")
    print(f"[wiki] indexed canon docs={len(idx['docs'])}")
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    url = f"http://localhost:{srv.server_port}"
    print(f"[wiki] serving {url}  (Ctrl-C stops)")
    if open_browser:
        webbrowser.open(url)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", nargs="?", default="serve", choices=["serve", "index"])
    ap.add_argument("--port", type=int, default=8899)
    ap.add_argument("--open", action="store_true")
    args = ap.parse_args()
    if args.cmd == "index":
        idx = build_index()
        for s, keys in sorted(idx["systems"].items()):
            print(f"{len(keys):4d}  {s}")
        print(f"total {len(idx['docs'])} docs; cross-line diffs: {len(idx['cross_line_diffs'])}")
    else:
        serve(args.port, args.open)


if __name__ == "__main__":
    main()
