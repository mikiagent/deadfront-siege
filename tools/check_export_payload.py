#!/usr/bin/env python3
"""Shipping-payload gate.

No argument: check that every shipping preset in game/export_presets.cfg excludes authoring
sources (work/, ref/, sheet.png, dev labs, tests). With a path (a .pck, or an export dir that
holds index.pck or pack.manifest.json + parts): parse the Godot pack directory, fail on any
forbidden file or when the pack is over the ceiling, and print the biggest contributors.

Usage: check_export_payload.py [PACK_OR_DIR] [--max-mb N] [--top N] [--soak]
  --soak  the pack is a WebSoak test build: scripts/dev (web_soak.gd) is allowed.
"""
from __future__ import annotations

import collections
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MB = 1_000_000  # decimal megabytes: the 220 MB ceiling means 220,000,000 bytes
SHIPPING = {"iOS", "Web", "PackCore", "PackAssets", "Server"}
# Every shipping preset's exclude_filter must contain these (dev-only or authoring sources).
REQUIRED_EXCLUDES = ["scripts/dev/*", "scenes/dev/*", "tests/*", "assets/creatures/*/ref/*",
                     "*/sheet.png", "assets/creatures/*/work/*", "assets/characters/*/work/*"]
# A file in the pack whose source path matches one of these fails the gate.
FORBIDDEN = [re.compile(p) for p in (r"^scripts/dev/", r"^scenes/dev/", r"^tests/",
                                     r"^assets/creatures/[^/]+/ref/", r"(^|/)sheet\.png",
                                     r"^assets/(creatures|characters)/[^/]+/work/")]


def check_presets() -> list[str]:
    text = (ROOT / "game/export_presets.cfg").read_text()
    errors = []
    for block in text.split("[preset.")[1:]:
        if ".options]" in block.split("\n", 1)[0]:
            continue
        name = re.search(r'^name="([^"]+)"', block, re.M)
        if not name or name.group(1) not in SHIPPING:
            continue
        pattern = re.search(r'^exclude_filter="([^"]*)"', block, re.M)
        have = [p.strip() for p in (pattern.group(1) if pattern else "").split(",")]
        for need in REQUIRED_EXCLUDES:
            if need not in have:
                errors.append(f"{name.group(1)}: exclude_filter is missing {need}")
    return errors


def read_pack(path: Path) -> bytes:
    if path.is_dir():
        if (path / "index.pck").is_file():
            return (path / "index.pck").read_bytes()
        man = json.loads((path / "pack.manifest.json").read_text())
        return b"".join((path / p).read_bytes() for p in man["parts"])
    return path.read_bytes()


def list_pack(data: bytes) -> list[tuple[str, int]]:
    """(path without res://, size) for every file in a Godot 4 pack (format 2 or 3)."""
    magic, fmt = struct.unpack_from("<4sI", data, 0)
    if magic != b"GDPC":
        raise SystemExit("not a Godot pack (magic %r)" % magic)
    flags = struct.unpack_from("<I", data, 20)[0]
    if flags & 1:
        raise SystemExit("pack directory is encrypted; cannot audit")
    off = 24 + 8  # magic, format, major, minor, patch, flags, file_base
    if fmt >= 3:
        off = struct.unpack_from("<Q", data, off)[0]  # directory offset
    else:
        off += 16 * 4  # reserved
    count = struct.unpack_from("<I", data, off)[0]
    off += 4
    files = []
    for _ in range(count):
        ln = struct.unpack_from("<I", data, off)[0]
        off += 4
        name = data[off:off + ln].rstrip(b"\0").decode()
        off += ln
        _ofs, size = struct.unpack_from("<QQ", data, off)
        off += 16 + 16 + 4  # offset, size, md5, flags
        files.append((name.removeprefix("res://"), size))
    return files


def source_of(name: str, imported: dict[str, str]) -> str:
    """Source path of a pack entry. Imported artifacts are .godot/imported/<file>-<md5 of res://path>.<ext>."""
    if name.startswith(".godot/imported/"):
        return imported.get(name[len(".godot/imported/"):].rsplit(".", 1)[0], name)
    return name.removesuffix(".remap").removesuffix(".import")


def audit_pack(target: Path, max_mb: float, top: int, soak: bool = False) -> list[str]:
    data = read_pack(target)
    files = list_pack(data)
    imported = {}
    for name, _ in files:
        if name.endswith(".import"):
            src = name.removesuffix(".import")
            imported[f"{Path(src).name}-{hashlib.md5(('res://' + src).encode()).hexdigest()}"] = src
    errors = []
    by_dir: collections.Counter[str] = collections.Counter()
    by_ext: collections.Counter[str] = collections.Counter()
    for name, size in files:
        src = source_of(name, imported)
        if any(rx.search(src) for rx in FORBIDDEN if not (soak and rx.pattern == r"^scripts/dev/")):
            errors.append(f"forbidden file in pack: {name}" + (f" (from {src})" if src != name else ""))
        by_dir["/".join(src.split("/")[:3])] += size
        by_ext[name.rsplit(".", 1)[-1]] += size
    total = len(data)
    print(f"[payload] pack {target} bytes={total} ({total / MB:.1f} MB) files={len(files)}")
    for k, v in by_dir.most_common(top):
        print(f"[payload]   {v / MB:8.1f} MB  {k}")
    print("[payload] by type: " + ", ".join(f"{k}={v / MB:.1f}MB" for k, v in by_ext.most_common(6)))
    if total > max_mb * MB:
        errors.append(f"pack is {total / MB:.1f} MB, over the {max_mb:.0f} MB ceiling")
    # A release page must not offer ?soak=1: its pack has no scripts/dev/web_soak.gd to load.
    html = target / "index.html" if target.is_dir() else None
    if not soak and html and html.is_file() and "--web-soak" in html.read_text():
        errors.append("release index.html carries the ?soak=1 hook")
    return errors


def main() -> None:
    args = sys.argv[1:]
    max_mb, top = 220.0, 12
    if "--max-mb" in args:
        i = args.index("--max-mb")
        max_mb = float(args[i + 1])
        del args[i:i + 2]
    if "--top" in args:
        i = args.index("--top")
        top = int(args[i + 1])
        del args[i:i + 2]
    soak = "--soak" in args
    if soak:
        args.remove("--soak")
    errors = check_presets()
    if args:
        errors += audit_pack(Path(args[0]), max_mb, top, soak)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        print("[payload] FAIL")
        raise SystemExit(1)
    print("[payload] shipping presets exclude authoring and dev files" + (" and the pack is clean" if args else ""))
    print("[payload] PASS")


if __name__ == "__main__":
    main()
