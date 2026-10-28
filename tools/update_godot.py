#!/usr/bin/env python3
"""Check or install the latest stable Godot 4.7 Mono editor on macOS.

Usage: tools/update_godot.py [--install] [--version 4.7.2] [--app /path/Godot_mono.app]
Without --install, this only checks. The project and export templates are not changed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from datetime import datetime

API = "https://api.github.com/repos/godotengine/godot/releases"
SERIES = (4, 7)  # The project currently pins Godot 4.7.1.
VERSION_RE = re.compile(r"^(\d+)\.(\d+)(?:\.(\d+))?$")


def version_tuple(version):
    match = VERSION_RE.fullmatch(version)
    if not match:
        raise ValueError(f"Invalid version: {version}")
    return tuple(int(part or 0) for part in match.groups())


def request(url):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "deadfront-godot-updater"})
    return urllib.request.urlopen(req, timeout=60)


def run(*args):
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.strip()


def app_version(app):
    executable = app / "Contents/MacOS/Godot"
    result = run(str(executable), "--version")
    match = re.match(r"^(\d+\.\d+(?:\.\d+)?)\.stable\.mono\.official(?:\.|$)", result)
    if not match:
        raise ValueError(f"Expected an official stable Mono build, got: {result}")
    return match.group(1), result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--install", action="store_true", help="install the selected version, preserving the old app")
    parser.add_argument("--version", help="specific stable 4.7 version; defaults to latest 4.7 patch")
    parser.add_argument("--app", type=Path, default=Path("/Applications/Godot_mono.app"), help="destination app bundle")
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise ValueError("This updater is for macOS only.")
    app = args.app.expanduser().absolute()
    if app.suffix != ".app" or app.is_symlink():
        raise ValueError("Destination must be a non-symlink .app bundle.")
    if args.version:
        selected = version_tuple(args.version)
        if selected[:2] != SERIES:
            raise ValueError("This project uses Godot 4.7; choose a 4.7 release.")
        with request(f"{API}/tags/{args.version}-stable") as response:
            release = json.load(response)
    else:
        with request(f"{API}?per_page=100") as response:
            releases = json.load(response)
        candidates = []
        for release_item in releases:
            tag = release_item.get("tag_name", "")
            match = re.fullmatch(r"(\d+\.\d+(?:\.\d+)?)-stable", tag)
            if match and not release_item.get("draft") and not release_item.get("prerelease"):
                number = version_tuple(match.group(1))
                if number[:2] == SERIES:
                    candidates.append((number, release_item))
        if not candidates:
            raise ValueError("Could not find a stable 4.7 release in the official release list.")
        release = max(candidates, key=lambda item: item[0])[1]
    if release.get("draft") or release.get("prerelease"):
        raise ValueError("Refusing a draft or prerelease.")
    tag = release["tag_name"]
    if not tag.endswith("-stable"):
        raise ValueError(f"Unexpected release tag: {tag}")
    target = tag[:-len("-stable")]
    if version_tuple(target)[:2] != SERIES or (args.version and target != args.version):
        raise ValueError(f"Unexpected release version: {target}")
    current = None
    if app.exists():
        current, display = app_version(app)
        print(f"Installed at {app}: {display}", flush=True)
    else:
        print(f"No app installed at {app}", flush=True)
    print(f"Selected stable 4.7 release: {target}", flush=True)
    print("Project pin, standard web editor, export templates and iOS simulator library are not updated.", flush=True)
    if not args.install:
        print("Run again with --install to install it.")
        return
    if current and version_tuple(current) >= version_tuple(target):
        print("Installed version is already at least as new; no changes made.")
        return
    if not app.parent.is_dir() or not os.access(app.parent, os.W_OK):
        raise ValueError(f"Destination parent must exist and be writable: {app.parent}")
    processes = run("/bin/ps", "-axo", "command=").splitlines()
    executable = str(app / "Contents/MacOS/Godot")
    if any(line.strip() == executable or line.strip().startswith(executable + " ") for line in processes):
        raise ValueError(f"Quit Godot at {app} before installing.")
    name = f"Godot_v{target}-stable_mono_macos.universal.zip"
    assets = [asset for asset in release.get("assets", []) if asset.get("name") == name]
    if len(assets) != 1:
        raise ValueError(f"Expected exactly one official asset named {name}.")
    asset = assets[0]
    digest = asset.get("digest", "")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise ValueError("Official release did not provide a SHA-256 digest; refusing to install.")
    url = asset["browser_download_url"]
    expected_url = f"https://github.com/godotengine/godot/releases/download/{tag}/{name}"
    if url != expected_url:
        raise ValueError("Unexpected asset URL.")
    with tempfile.TemporaryDirectory(prefix=".godot-update-", dir=app.parent) as tmp:
        temp = Path(tmp)
        archive = temp / name
        print(f"Downloading {name}...", flush=True)
        h = hashlib.sha256()
        with request(url) as response, archive.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
                h.update(chunk)
        if h.hexdigest() != digest.removeprefix("sha256:"):
            raise ValueError("Downloaded archive failed SHA-256 verification.")
        with zipfile.ZipFile(archive) as z:
            for entry in z.infolist():
                parts = Path(entry.filename).parts
                if entry.filename.startswith("/") or ".." in parts:
                    raise ValueError("Unsafe path in downloaded archive.")
        unpacked = temp / "unpacked"
        unpacked.mkdir()
        run("/usr/bin/ditto", "-x", "-k", str(archive), str(unpacked))
        apps = list(unpacked.glob("*.app"))
        if len(apps) != 1:
            raise ValueError("Expected one app bundle in the archive.")
        staged = apps[0]
        run("/usr/bin/codesign", "--verify", "--deep", "--strict", str(staged))
        run("/usr/bin/codesign", "--verify", "--test-requirement", '=anchor apple generic and identifier "org.godotengine.godot" and certificate leaf[subject.OU] = "6K46PWY5DM"', str(staged))
        staged_version, display = app_version(staged)
        if version_tuple(staged_version) != version_tuple(target):
            raise ValueError(f"Downloaded editor reports unexpected version: {display}")
        backup = None
        if app.exists():
            backup = app.with_name(f"{app.stem}-backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}.app")
            if backup.exists():
                raise ValueError(f"Backup already exists: {backup}")
            app.rename(backup)
        try:
            staged.rename(app)
        except BaseException:
            if backup and not app.exists():
                backup.rename(app)
            raise
        print(f"Installed {display} at {app}")
        if backup:
            print(f"Previous app preserved at {backup}")
    print("Check tools/find_godot.sh to confirm which executable your environment selects.")
    print("Coordinate the project pin and matching export tools/templates before using the new editor on the project.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        print(f"Update failed: {exc}", file=sys.stderr)
        sys.exit(1)
