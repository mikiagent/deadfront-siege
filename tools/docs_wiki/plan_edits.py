"""Apply explicitly reviewed, revision-pinned edits to existing vision files."""
from __future__ import annotations

import hashlib
import os
import re
import stat
import tempfile
import threading
from pathlib import Path, PurePosixPath

MAX_DOC_BYTES = 2_000_000
MAX_EDIT_CHARS = 200_000
_APPLY_LOCK = threading.Lock()

class EditError(Exception):
    pass

class StaleEdit(EditError):
    pass


def _target(root: Path, value: object) -> Path:
    if not isinstance(value, str) or not value or '\\' in value or '\x00' in value:
        raise EditError('Invalid document path.')
    p = PurePosixPath(value)
    if p.is_absolute() or '..' in p.parts or not p.is_relative_to(PurePosixPath('docs/vision')) or p.suffix.lower() != '.md':
        raise EditError('Only existing Markdown files in docs/vision can be edited.')
    root = root.resolve()
    target = root.joinpath(*p.parts)
    # Reject symlinks at each path component, including the final document.
    for parent in (target, *target.parents):
        if parent == root:
            break
        if parent.is_symlink():
            raise EditError('Symlinked document paths cannot be edited.')
    try:
        resolved = target.resolve(strict=True)
    except OSError as exc:
        raise EditError('Document no longer exists.') from exc
    if not resolved.is_relative_to((root / 'docs/vision').resolve()) or not resolved.is_file():
        raise EditError('Document is outside docs/vision or is not a file.')
    return target


def _git_backup_dir(root: Path) -> Path:
    marker = root / '.git'
    if marker.is_dir():
        gitdir = marker.resolve()
    else:
        try:
            line = marker.read_text().strip()
            if not line.startswith('gitdir: '):
                raise ValueError('not a Git worktree')
            raw = Path(line[8:])
            gitdir = (raw if raw.is_absolute() else root / raw).resolve(strict=True)
        except (OSError, ValueError) as exc:
            raise EditError('Could not find the Git worktree backup directory.') from exc
    return gitdir / 'wildlands-wiki-backups'


def apply_vision_edits(root: Path, request: object, backup_dir: Path | None = None) -> dict:
    with _APPLY_LOCK:
        return _apply_vision_edits(root, request, backup_dir)


def _apply_vision_edits(root: Path, request: object, backup_dir: Path | None = None) -> dict:
    if not isinstance(request, dict):
        raise EditError('Expected an edit proposal.')
    path = request.get('path')
    baseline = request.get('base_sha256')
    edits = request.get('edits')
    if not isinstance(baseline, str) or not re.fullmatch(r'[0-9a-f]{64}', baseline):
        raise EditError('A source SHA-256 revision is required.')
    if not isinstance(edits, list) or not 1 <= len(edits) <= 20:
        raise EditError('Provide 1 to 20 reviewed replacements for one document.')
    target = _target(root, path)
    try:
        raw = target.read_bytes()
        mode = stat.S_IMODE(target.stat().st_mode)
    except OSError as exc:
        raise EditError('Could not read the source document.') from exc
    if len(raw) > MAX_DOC_BYTES:
        raise EditError('Source document is too large to edit here.')
    if hashlib.sha256(raw).hexdigest() != baseline:
        raise StaleEdit('The document changed since this proposal was prepared. Re-run the review.')
    try:
        source = raw.decode('utf-8')
    except UnicodeDecodeError as exc:
        raise EditError('The document is not UTF-8.') from exc
    replacements = []
    for edit in edits:
        if not isinstance(edit, dict):
            raise EditError('Invalid replacement.')
        old, new = edit.get('old_text'), edit.get('new_text')
        if not isinstance(old, str) or not isinstance(new, str) or not old or len(old) > MAX_EDIT_CHARS or len(new) > MAX_EDIT_CHARS:
            raise EditError('Each replacement needs bounded original and new text.')
        if old == new:
            raise EditError('A replacement does not change the document.')
        if source.count(old) != 1:
            raise StaleEdit('A proposed original passage is missing or occurs more than once. Re-run the review.')
        start = source.index(old)
        replacements.append((start, start + len(old), new))
    replacements.sort()
    if any(left[1] > right[0] for left, right in zip(replacements, replacements[1:])):
        raise EditError('Proposed replacements overlap.')
    result = source
    for start, end, new in reversed(replacements):
        result = result[:start] + new + result[end:]
    encoded = result.encode('utf-8')
    if len(encoded) > MAX_DOC_BYTES:
        raise EditError('Resulting document is too large.')
    backups = backup_dir if backup_dir is not None else _git_backup_dir(root)
    try:
        backups.mkdir(parents=True, exist_ok=True, mode=0o700)
        backup = backups / (baseline + '.md')
        try:
            fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            if backup.read_bytes() != raw:
                raise EditError('Existing backup does not match the original document.')
        else:
            with os.fdopen(fd, 'wb') as f:
                f.write(raw); f.flush(); os.fsync(f.fileno())
        # Check again after backup creation; avoid overwriting a concurrent edit.
        _target(root, path)
        if hashlib.sha256(target.read_bytes()).hexdigest() != baseline:
            raise StaleEdit('The document changed while saving. Re-run the review.')
        temp_name = None
        try:
            with tempfile.NamedTemporaryFile(dir=target.parent, prefix='.wiki-edit-', delete=False) as f:
                temp_name = f.name
                f.write(encoded); f.flush(); os.fsync(f.fileno())
            os.chmod(temp_name, mode)
            if hashlib.sha256(target.read_bytes()).hexdigest() != baseline:
                raise StaleEdit('The document changed while saving. Re-run the review.')
            os.replace(temp_name, target)
            temp_name = None
        finally:
            if temp_name:
                Path(temp_name).unlink(missing_ok=True)
    except OSError as exc:
        raise EditError('Could not save the document; the original was left in place.') from exc
    return {'ok': True, 'path': path, 'sha256': hashlib.sha256(encoded).hexdigest()}
