"""The phase map: dependency-ranked feature tracker for the wiki.

`tools/docs_wiki/phase-map.json` is the authored truth: phases from the
load-bearing foundations (Phase 0) up to polish, each holding features with
dependency edges and seed statuses. A browser status change is a mark under
state.json's `phases` key; the merged view is what /api/phase serves. The JSON
must always stay valid: unique ids, resolvable dependencies, one status
vocabulary, sources that exist in this checkout, and no dependency cycles.
"""
from __future__ import annotations

import json
import re
from pathlib import Path, PurePosixPath

STATUSES = ("done", "next", "later", "decided-against")
MAX_BYTES = 500_000
ID_PATTERN = re.compile(r"[a-z][a-z0-9-]{0,47}")
PHASE_MIN, PHASE_MAX = 0, 99
MAX_PHASES = 12
MAX_FEATURES_PER_PHASE = 60
MAX_TEXT_CHARS = 2_000
MAX_PATH_CHARS = 200


class PhaseError(ValueError):
    pass


def _text(value: object, limit: int = MAX_TEXT_CHARS, allow_empty: bool = False) -> bool:
    return isinstance(value, str) and (len(value) > 0 or allow_empty) and len(value) <= limit


def _clean_path(value: object) -> str:
    if not isinstance(value, str) or "\\" in value or "\x00" in value:
        raise PhaseError("Feature source must be a repository path.")
    p = PurePosixPath(value)
    if (not value or p.is_absolute() or ".." in p.parts or len(value) > MAX_PATH_CHARS
            or len(p.parts) < 2):
        raise PhaseError(f"Feature source must be a relative repository path: {value!r}")
    return value


def _check_source(root: Path, value: str) -> None:
    _clean_path(value)
    resolved = (root / value).resolve(strict=False)
    if not resolved.is_relative_to(root) or not resolved.is_file():
        raise PhaseError(f"Feature source is not a file in this checkout: {value}")


def _cycle_check(graph: dict[str, list[str]]) -> None:
    state: dict[str, int] = {}
    chain: list[str] = []

    def visit(node: str) -> None:
        if state.get(node) == 1:
            cycle = chain[chain.index(node):] + [node]
            raise PhaseError("Dependency cycle: " + " -> ".join(cycle))
        if state.get(node) == 2:
            return
        state[node] = 1
        chain.append(node)
        for dep in graph[node]:
            visit(dep)
        chain.pop()
        state[node] = 2

    for node in graph:
        visit(node)


def validate(root: Path, data: object) -> dict:
    """Validate the authored map, raising PhaseError with a readable reason."""
    root = Path(root).resolve()
    if not isinstance(data, dict):
        raise PhaseError("The phase map must be a JSON object.")
    if not _text(data.get("goal")):
        raise PhaseError("The map needs a goal sentence.")
    phases = data.get("phases")
    if not isinstance(phases, list) or not 1 <= len(phases) <= MAX_PHASES:
        raise PhaseError(f"Provide 1 to {MAX_PHASES} phases.")
    numbers: list[int] = []
    features: dict[str, dict] = {}
    for phase in phases:
        if not isinstance(phase, dict) or not isinstance(phase.get("phase"), int):
            raise PhaseError("Each phase needs an integer 'phase' number.")
        number = phase["phase"]
        if not PHASE_MIN <= number <= PHASE_MAX:
            raise PhaseError(f"Phase number {number} is outside 0-99.")
        numbers.append(number)
        if not _text(phase.get("title")) or not _text(phase.get("theme"), allow_empty=True):
            raise PhaseError(f"Phase {number} needs a title and theme.")
        listed = phase.get("features")
        if not isinstance(listed, list) or not listed or len(listed) > MAX_FEATURES_PER_PHASE:
            raise PhaseError(f"Phase {number} needs 1 to {MAX_FEATURES_PER_PHASE} features.")
        for feature in listed:
            if not isinstance(feature, dict):
                raise PhaseError(f"Phase {number}: features must be objects.")
            fid = feature.get("id")
            if not isinstance(fid, str) or not ID_PATTERN.fullmatch(fid):
                raise PhaseError(f"Bad feature id: {fid!r} (kebab-case, <= 48 chars).")
            if fid in features:
                raise PhaseError(f"Duplicate feature id: {fid}")
            if not _text(feature.get("title")):
                raise PhaseError(f"Feature {fid} needs a title.")
            if feature.get("status") not in STATUSES:
                raise PhaseError(f"Feature {fid}: status must be one of {', '.join(STATUSES)}.")
            depends = feature.get("depends")
            if not isinstance(depends, list) or not all(isinstance(d, str) for d in depends):
                raise PhaseError(f"Feature {fid}: 'depends' must be a list of ids.")
            if not _text(feature.get("source"), MAX_PATH_CHARS):
                raise PhaseError(f"Feature {fid}: source must name the shaping document.")
            for extra in ("note",):
                if extra in feature and not _text(feature[extra], allow_empty=True):
                    raise PhaseError(f"Feature {fid}: 'note' must be text.")
            features[fid] = feature
    if numbers != sorted(numbers) or len(set(numbers)) != len(numbers):
        raise PhaseError("Phases must be numbered strictly ascending, no repeats.")
    graph: dict[str, list[str]] = {}
    for fid, feature in features.items():
        deps = feature["depends"]
        missing = sorted({d for d in deps if not isinstance(d, str) or d not in features})
        if missing:
            raise PhaseError(f"Feature {fid} depends on unknown ids: {', '.join(missing)}")
        if fid in deps:
            raise PhaseError(f"Feature {fid} cannot depend on itself.")
        graph[fid] = list(deps)
    for fid, feature in features.items():
        _check_source(root, feature["source"])
    _cycle_check(graph)
    return data


def load(root: Path) -> dict:
    path = root / "tools" / "docs_wiki" / "phase-map.json"
    raw = path.read_bytes()
    if len(raw) > MAX_BYTES:
        raise PhaseError("phase-map.json exceeds the size limit.")
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as exc:
        raise PhaseError(f"phase-map.json is not valid UTF-8 JSON: {exc}") from exc
    return validate(root, data)


def merge(data: dict, marks: object) -> dict:
    """Overlay per-feature marks; never mutate the authored map."""
    result = {"goal": data["goal"], "updated": data.get("updated") or "", "phases": [],
              "marks": {}}
    if not isinstance(marks, dict):
        marks = {}
    for phase in data["phases"]:
        out_features = []
        for feature in phase["features"]:
            item = dict(feature)
            mark = marks.get(feature["id"])
            if isinstance(mark, dict):
                status = mark.get("status", "")
                note = mark.get("note", "")
                if status in STATUSES:
                    item["status"] = status
                if isinstance(note, str) and note:
                    if note != item.get("note"):
                        item["seed_note"] = item.get("note", "")
                    item["note"] = note
                item["by"] = "mark"
                result["marks"][feature["id"]] = {"status": status, "note": note}
            out_features.append(item)
        result["phases"].append({**phase, "features": out_features})
    return result
