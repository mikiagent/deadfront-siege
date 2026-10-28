"""Draft a lossless, review-only split of a vision document.

No files are written by the preview. An application step (`apply_split`) can
write an explicitly reviewed split, but only when the proposal still matches a
freshly recomputed one against the current bytes; any drift, existing
destination, or write failure leaves the source document untouched.
"""
from __future__ import annotations

import hashlib
import os
import re
import stat
import tempfile
from pathlib import Path, PurePosixPath
from urllib.parse import quote, unquote

ROOT = Path(__file__).resolve().parents[2]
MAX_DOCUMENT_BYTES = 500_000
HEADING = re.compile(r"^ {0,3}(#{1,6})[ \t]+(.+?)[ \t]*\r?\n?$")
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
FRAGMENT_LINK = re.compile(r"\]\(\s*#([^\s)]+)(?:\s+[^)]*)?\)")


def _slug(value: str) -> str:
    # Match the wiki's heading IDs for plain-text headings.
    value = "".join(c for c in value.strip().lower()
                    if c.isalnum() or c.isspace() or c in "_-")
    return re.sub(r"\s+", "-", value)


def _headings(lines: list[str]) -> list[dict]:
    headings: list[dict] = []
    fence_char, fence_length = "", 0
    for index, line in enumerate(lines):
        stripped = line.rstrip("\r\n")
        match = FENCE.match(stripped)
        if match:
            mark, rest = match.groups()
            if not fence_char:
                fence_char, fence_length = mark[0], len(mark)
            elif mark[0] == fence_char and len(mark) >= fence_length and not rest.strip():
                fence_char, fence_length = "", 0
            continue
        if fence_char:
            continue
        match = HEADING.match(line)
        if not match:
            continue
        level = len(match.group(1))
        title = re.sub(r"[ \t]+#+[ \t]*$", "", match.group(2)).strip()
        # Markdown or HTML inside a heading can change its rendered text and ID.
        # Refuse rather than invent anchors that may break existing references.
        if not title or any(c in title for c in "[]<>`\\*_~&"):
            raise ValueError(f"Heading on line {index + 1} needs manual anchor review")
        headings.append({"index": index, "level": level, "title": title, "label": match.group(1)})
    return headings


def _with_ids(headings: list[dict]) -> list[dict]:
    counts: dict[str, int] = {}
    result = []
    for heading in headings:
        slug = _slug(heading["title"])
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        result.append({**heading, "anchor": slug + (f"-{count}" if count else "")})
    return result


def propose_refactor(path: str, *, root: Path | None = None) -> dict:
    """Return a reviewable split proposal for an existing docs/vision Markdown file."""
    root = Path(root or ROOT).resolve()
    if not isinstance(path, str) or "\\" in path or "\x00" in path:
        raise ValueError("Choose a Markdown file in docs/vision")
    rel = PurePosixPath(path)
    if (rel.is_absolute() or ".." in rel.parts or len(rel.parts) != 3
            or rel.parts[:2] != ("docs", "vision") or rel.suffix.lower() != ".md"):
        raise ValueError("Choose a Markdown file in docs/vision")
    source = root.joinpath(*rel.parts)
    # Reject symlinked ancestors too: resolving both the document and a
    # symlinked vision directory would otherwise make an outside file appear
    # to be inside the allowed base.
    for component in (source, source.parent, source.parent.parent):
        if component.is_symlink():
            raise ValueError("Symlinked document paths cannot be refactored")
    try:
        resolved = source.resolve(strict=True)
        if (not resolved.is_relative_to(root)
                or not resolved.is_relative_to((root / "docs" / "vision").resolve())
                or not resolved.is_file()):
            raise ValueError("Choose a Markdown file in docs/vision")
        raw = resolved.read_bytes()
    except OSError as exc:
        raise ValueError("Vision document is unavailable") from exc
    if len(raw) > MAX_DOCUMENT_BYTES:
        raise ValueError("Document exceeds the refactor proposal size limit")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError("Vision document is not UTF-8") from exc
    lines = text.splitlines(keepends=True)
    headings = _with_ids(_headings(lines))
    boundaries = [h for h in headings if h["level"] == 2]
    if len(boundaries) < 2:
        raise ValueError("Document needs at least two level-2 sections to split")
    preamble = "".join(lines[:boundaries[0]["index"]])
    sections = []
    warnings = []
    index_lines = [preamble, "\n" if preamble and not preamble.endswith("\n") else "", "\n"]
    source_stem = rel.stem
    for number, boundary in enumerate(boundaries, start=1):
        start = boundary["index"]
        end = boundaries[number]["index"] if number < len(boundaries) else len(lines)
        section_text = "".join(lines[start:end])
        section_headings = [h for h in headings if start <= h["index"] < end]
        local_headings = _with_ids(section_headings)
        filename_slug = re.sub(r"[^a-z0-9]+", "-", boundary["title"].lower()).strip("-")[:44] or "section"
        destination_name = f"{source_stem}--{number:02d}-{filename_slug}.md"
        destination = str(rel.parent / destination_name)
        if root.joinpath(*PurePosixPath(destination).parts).exists():
            warnings.append(f"Proposed destination already exists: {destination}")
        anchors = []
        for original, local in zip(section_headings, local_headings):
            anchors.append({"title": original["title"], "original": original["anchor"], "section": local["anchor"]})
            target = quote(destination_name, safe="-._~") + "#" + quote(local["anchor"], safe="-._~")
            index_lines.append(f"{original['label']} [{original['title']}]({target})\n")
        local_ids = {h["anchor"] for h in local_headings}
        for match in FRAGMENT_LINK.finditer(section_text):
            try:
                target = unquote(match.group(1))
            except ValueError:
                target = match.group(1)
            if target not in local_ids:
                warnings.append(f"{destination}: fragment #{target} leaves this section or needs anchor review")
        sections.append({"title": boundary["title"], "path": destination,
                         "start_line": start + 1, "end_line": end,
                         "content": section_text, "anchors": anchors})
    if preamble + "".join(section["content"] for section in sections) != text:
        raise AssertionError("Split would not preserve the source")
    warnings.append("Review links from other documents and redirects for fragment links before applying; no files were changed.")
    return {"source_path": path, "source_revision": hashlib.sha256(raw).hexdigest(),
            "original_bytes": len(raw), "section_count": len(sections),
            "preamble": preamble, "sections": sections, "index_preview": "".join(index_lines),
            "warnings": list(dict.fromkeys(warnings)), "review_required": True}


def _reviewed_matches_fresh(review: dict, fresh: dict) -> str | None:
    """Reason string when the reviewed proposal no longer matches a fresh one."""
    for key in ("source_revision", "preamble", "index_preview"):
        got = review.get(key)
        if not isinstance(got, str) or got != fresh[key]:
            return f"The proposal {key} no longer matches the document. Propose the split again and re-review."
    reviewed = review.get("sections")
    if not isinstance(reviewed, list) or len(reviewed) != len(fresh["sections"]):
        return "The proposal sections no longer match the document. Propose the split again and re-review."
    for got, want in zip(reviewed, fresh["sections"]):
        if not isinstance(got, dict):
            return "The proposal sections no longer match the document. Propose the split again and re-review."
        if any(got.get(key) != want[key] for key in ("path", "title", "start_line", "end_line", "content")):
            return "A section changed since this split was proposed. Propose the split again and re-review."
    return None


def apply_split(root: Path, request: object, backup_dir: Path | None = None) -> dict:
    """Write an explicitly reviewed split, exactly as freshly recomputed.

    The reviewed proposal is never trusted on its own: the current document is
    re-proposed and compared in full first. Then every destination is checked
    to be absent, the original is backed up, and sections are written before
    the source becomes the reviewable index. Any failure removes the written
    sections and leaves the source unchanged.
    """
    import plan_edits

    # Serialize with the wiki's line-edit saves. External editors do not use
    # this lock, so we also compare the source immediately before replacement.
    with plan_edits._APPLY_LOCK:
        return _apply_split(root, request, backup_dir)


def _apply_split(root: Path, request: object, backup_dir: Path | None = None) -> dict:
    import plan_edits

    root = Path(root or ROOT).resolve()
    if not isinstance(request, dict):
        raise ValueError("Expected the reviewed refactor request.")
    review = request.get("proposal")
    if not isinstance(review, dict):
        raise ValueError("Expected the reviewed proposal in the request.")
    fresh = propose_refactor(request.get("path"), root=root)
    reason = _reviewed_matches_fresh(review, fresh)
    if reason:
        raise ValueError(reason)
    source_rel = PurePosixPath(fresh["source_path"])
    source_path = root.joinpath(*source_rel.parts)
    raw = source_path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != fresh["source_revision"]:
        raise ValueError("The source changed while preparing the split. Propose the split again and re-review.")
    mode = stat.S_IMODE(source_path.stat().st_mode)
    destinations = [(root.joinpath(*PurePosixPath(s["path"]).parts), s) for s in fresh["sections"]]
    occupied = sorted(str(d.relative_to(root)) for d, _ in destinations
                      if d.exists() or d.is_symlink())
    if occupied:
        raise ValueError("Refusing to split: destination already exists: " + ", ".join(occupied))
    backups = backup_dir if backup_dir is not None else plan_edits._git_backup_dir(root)
    backups.mkdir(parents=True, exist_ok=True, mode=0o700)
    backup = backups / (fresh["source_revision"] + "--split.md")
    try:
        fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        if backup.read_bytes() != raw:
            raise ValueError("An unrelated file occupies the backup path; move it first.") from None
    else:
        with os.fdopen(fd, "wb") as f:
            f.write(raw)
            f.flush()
            os.fsync(f.fileno())
    # Track both identity and contents. If another process edits/replaces a
    # section during a failed split, cleanup must leave that file untouched.
    written: list[tuple[Path, int, int, str]] = []
    temp_name: str | None = None
    try:
        for destination, section in destinations:
            destination.parent.mkdir(parents=True, exist_ok=True)
            try:
                with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".wiki-split-",
                                                 delete=False) as f:
                    temp_name = f.name
                    f.write(section["content"].encode("utf-8"))
                    f.flush()
                    os.fsync(f.fileno())
                os.chmod(temp_name, mode)
                # link creates the destination exclusively and atomically. A
                # concurrent creator wins instead of having their file replaced.
                temp_stat = os.stat(temp_name, follow_symlinks=False)
                os.link(temp_name, destination, follow_symlinks=False)
                written.append((destination, temp_stat.st_dev, temp_stat.st_ino,
                                hashlib.sha256(section["content"].encode("utf-8")).hexdigest()))
                Path(temp_name).unlink()
                temp_name = None
            finally:
                if temp_name:
                    Path(temp_name).unlink(missing_ok=True)
                    temp_name = None
        with tempfile.NamedTemporaryFile(dir=source_path.parent, prefix=".wiki-split-",
                                         delete=False) as f:
            temp_name = f.name
            f.write(fresh["index_preview"].encode("utf-8"))
            f.flush()
            os.fsync(f.fileno())
        os.chmod(temp_name, mode)
        plan_edits._target(root, fresh["source_path"])
        if hashlib.sha256(source_path.read_bytes()).hexdigest() != fresh["source_revision"]:
            raise ValueError("The source changed while saving. Propose the split again and re-review.")
        os.replace(temp_name, source_path)
        temp_name = None
    except (OSError, ValueError, plan_edits.EditError) as exc:
        retained = []
        for target, dev, ino, digest in written:
            try:
                st = target.lstat()
                if (stat.S_ISREG(st.st_mode) and (st.st_dev, st.st_ino) == (dev, ino)
                        and hashlib.sha256(target.read_bytes()).hexdigest() == digest):
                    target.unlink()
                else:
                    retained.append(str(target.relative_to(root)))
            except FileNotFoundError:
                pass
            except OSError:
                retained.append(str(target.relative_to(root)))
        message = str(exc) if isinstance(exc, ValueError) else "Could not save the split; the source document was left in place."
        if retained:
            message += " Modified or inaccessible section files were preserved: " + ", ".join(retained)
        raise ValueError(message) from None
    finally:
        if temp_name:
            Path(temp_name).unlink(missing_ok=True)
    return {"ok": True, "source_path": fresh["source_path"], "sections_written": len(written),
            "written": [str(t[0].relative_to(root)) for t in written],
            "backup": str(backup.relative_to(root)) if backup.is_relative_to(root) else str(backup),
            "index_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest()}
