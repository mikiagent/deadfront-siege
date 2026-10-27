#!/usr/bin/env python3
"""DEADFRONT docs wiki: index every markdown doc on the repo's lines and serve
a local site for marking canon / useful / stale, connecting conflicts and
running reconcile tasks (owner 2026-10-27: "navigate the docs and decide what
is canon and what is stale ... lower the overall context bloat").

Reads the live files on every request — nothing is copied — so the site always
shows the current bytes of each doc. Curated state lives in state.json next to
this file (gitignored; Export in the UI writes a portable copy).

  python3 tools/docs_wiki.py serve [--port 8899] [--open]

Uses only the Python standard library. Binds 127.0.0.1 only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

APP_DIR = Path(__file__).resolve().parent
STATE_PATH = APP_DIR / "state.json"
ROOT = APP_DIR.parent.parent  # the main checkout

DATE_RE = re.compile(r"20[0-9]{2}-[01][0-9]-[0-3][0-9]")
BANNER_RE = re.compile(r"superseded|historical record|archived|do not trust|historical", re.I)
SCAN_PATTERNS = ["*.md", "docs/**/*.md", "assets/concept-art/*.md", "research/*.md"]
SKIP_PARTS = {".git", ".godot", ".dsc", "node_modules", "artifacts", "export", "work"}


def canon_root() -> Path | None:
    """The worktree holding the claude/mmo-overhaul branch (same lookup the
    desktop launcher uses). Falls back to none when it is not checked out."""
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
        elif line == "branch refs/heads/claude/mmo-overhaul" and candidate_root:
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
    if "server" in p or "multiplayer" in p or "mmo" in p or "contract" in p:
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
    if "/prd/" in p:
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
            if not f.is_file():
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
    canon = canon_root()
    entries: dict[str, dict] = {}
    for line_name, checkout in (("main", ROOT), ("canon", canon)):
        for e in scan_line(checkout, line_name):
            entries[e["key"]] = e
    # inbound links within each line: markdown links that resolve to another indexed doc
    inbound: dict[str, int] = {k: 0 for k in entries}
    broken: dict[str, int] = {k: 0 for k in entries}
    for key, e in entries.items():
        checkout = ROOT if e["line"] == "main" else (canon or ROOT)
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
    # same doc on both lines: seed the cross-line reconcile view
    by_path: dict[str, list[str]] = {}
    for k, e in entries.items():
        by_path.setdefault(e["path"], []).append(k)
    cross = []
    for path, keys in by_path.items():
        if len(keys) < 2:
            continue
        idents = set()
        for k in keys:
            line = entries[k]["line"]
            checkout = ROOT if line == "main" else (canon or ROOT)
            f = checkout / entries[k]["path"]
            try:
                idents.add(hashlib.sha1(f.read_bytes()).hexdigest()[:8])
            except OSError:
                pass
        if len(idents) > 1:  # differs across lines
            cross.append(path)
    systems: dict[str, list[str]] = {}
    for k, e in entries.items():
        systems.setdefault(e["system"], []).append(k)
    for s in systems:
        systems[s].sort(key=lambda k: entries[k]["title"].lower())
    return {
        "generated": int(time.time()),
        "canon_root": str(canon) if canon else "",
        "docs": dict(sorted(entries.items())),
        "inbound": inbound,
        "broken": broken,
        "cross_line_diffs": sorted(cross),
        "systems": systems,
    }


# ---------------------------------------------------------------- state seed

def load_state(index: dict) -> dict:
    if STATE_PATH.exists():
        try:
            state = json.loads(STATE_PATH.read_text())
            if isinstance(state, dict) and "docs" in state:
                return state
        except (OSError, ValueError):
            pass
    return seed_state(index)


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


# ---------------------------------------------------------------- server

CACHED: dict | None = None


def get_index() -> dict:
    global CACHED
    CACHED = build_index()
    return CACHED


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
        elif u.path in ("/app.js", "/app.css", "/marked.min.js"):
            self._static(u.path.lstrip("/"))
        elif u.path == "/api/index":
            idx = get_index()
            self._json(idx)
        elif u.path == "/api/state":
            self._json(load_state(get_index()))
        elif u.path == "/api/doc":
            q = parse_qs(u.query)
            key = (q.get("key") or [""])[0]
            idx = get_index()
            if key not in idx["docs"]:
                self._send(404, b"unknown doc", "text/plain")
                return
            e = idx["docs"][key]
            checkout = ROOT if e["line"] == "main" else Path(idx["canon_root"] or ROOT)
            f = checkout / e["path"]
            try:
                text = f.read_text(errors="replace")
            except OSError:
                self._send(500, b"unreadable", "text/plain")
                return
            self._send(200, text.encode("utf-8"), "text/plain; charset=utf-8")
        else:
            self._send(404, b"not found", "text/plain")

    def do_POST(self) -> None:
        if urlparse(self.path).path != "/api/state":
            self._send(404, b"not found", "text/plain")
            return
        n = int(self.headers.get("Content-Length", 0))
        try:
            state = json.loads(self.rfile.read(n) or b"{}")
            assert isinstance(state, dict) and "docs" in state
        except (ValueError, AssertionError):
            self._send(400, b"bad state", "text/plain")
            return
        state["updatedAt"] = int(time.time())
        STATE_PATH.write_text(json.dumps(state, indent=1))
        self._json({"ok": True, "updatedAt": state["updatedAt"]})


def serve(port: int, open_browser: bool) -> None:
    idx = get_index()
    print(f"[wiki] main={ROOT}")
    print(f"[wiki] canon={idx['canon_root'] or '(not checked out)'}")
    print(f"[wiki] docs={len(idx['docs'])} cross-line-diffs={len(idx['cross_line_diffs'])}")
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
