#!/usr/bin/env python3
"""Meshy pipeline driver for the creature roster.

Reads the roster from game/data/creatures/<species>.json and walks each species
through: text-to-3d preview -> refine -> rig -> animate -> download.

State lives in tools/meshy_state.json. The i2m command resumes recorded tasks;
rig, animation and motion commands also resume recorded task IDs.

Usage:
  MESHY_API_KEY=... python3 tools/meshy.py balance
  MESHY_API_KEY=... python3 tools/meshy.py library [--search bite] [--category Fighting]
  MESHY_API_KEY=... python3 tools/meshy.py preview <species>
  MESHY_API_KEY=... python3 tools/meshy.py i2m     <species> [--attempt 2]
  MESHY_API_KEY=... python3 tools/meshy.py refine  <species>
  MESHY_API_KEY=... python3 tools/meshy.py rig     <species>
  MESHY_API_KEY=... python3 tools/meshy.py animate <species> --actions 0,12,44
  MESHY_API_KEY=... python3 tools/meshy.py motion  <species> --clip attack_heavy
  MESHY_API_KEY=... python3 tools/meshy.py status  [species]
  MESHY_API_KEY=... python3 tools/meshy.py fetch   <species>
"""
import argparse, base64, copy, json, os, pathlib, struct, sys, time, urllib.request, urllib.error, urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "game" / "data" / "creatures"
OUT = ROOT / "game" / "assets" / "creatures"
STATE = ROOT / "tools" / "meshy_state.json"
API = "https://api.meshy.ai/openapi"

# Verified against the live API 2026-09-17. These pairings are enforced
# server-side and the docs do not spell them out:
#   smart-topology  requires ai_model meshy-t2 and is triangle-only
#   meshy-7         accepts model_type standard only
GEN = dict(ai_model="meshy-t2", model_type="smart-topology", topology="triangle",
           target_polycount=12000, should_remesh=False,
           target_formats=["glb"], auto_size=True)


def key():
    k = os.environ.get("MESHY_API_KEY")
    if not k:
        sys.exit("MESHY_API_KEY is not set")
    return k


def call(method, path, body=None):
    req = urllib.request.Request(
        f"{API}{path}", method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {key()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code} {method} {path}\n{e.read().decode()}")


def state():
    return json.loads(STATE.read_text()) if STATE.exists() else {}


def save(s):
    temporary = STATE.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(s, indent=2) + "\n")
    temporary.replace(STATE)


def spec(name):
    p = SPEC / f"{name}.json"
    if not p.exists():
        sys.exit(f"no spec at {p}")
    return json.loads(p.read_text())


def record(name, stage, value):
    s = state()
    s.setdefault(name, {})[stage] = value
    save(s)
    print(f"{name}.{stage} = {value}")


def wait(path, tid, label):
    """Poll a task to a terminal state. Returns the final payload."""
    for _ in range(180):
        d = call("GET", f"{path}/{tid}")
        st = d.get("status")
        print(f"  {label} {st} {d.get('progress', '')}%", flush=True)
        if st in ("SUCCEEDED", "FAILED", "CANCELED"):
            if st != "SUCCEEDED":
                sys.exit(f"{label} {st}: {d.get('task_error')}")
            return d
        time.sleep(10)
    sys.exit(f"{label} timed out")


def cmd_balance(a):
    print(call("GET", "/v1/balance"))


def cmd_library(a):
    q = []
    if a.search: q.append("search=" + urllib.parse.quote(a.search))
    if a.category: q.append(f"category={a.category}")
    lib = call("GET", "/v1/animations/library" + ("?" + "&".join(q) if q else ""))
    for x in lib:
        print(f"{x['action_id']:>4}  {x['category']:<14} {x['sub_category']:<18} {x['name']}")
    print(f"\n{len(lib)} actions. Every preview URL is /biped/ - there are no "
          f"quadruped presets in this library.")


def cmd_preview(a):
    sp = spec(a.species)
    body = dict(GEN, mode="preview", prompt=sp["prompt"])
    tid = submit(a.species, "preview", "/v2/text-to-3d", body)
    wait("/v2/text-to-3d", tid, "preview")


def cmd_i2m(a):
    """Resume an existing image-to-3D task; a new numbered attempt is explicit."""
    sp = spec(a.species)
    stage = "i2m" if a.attempt == 1 else f"i2m_v{a.attempt}"
    tid = state().get(a.species, {}).get(stage)
    if not tid:
        ref = OUT / a.species / "ref" / f"{a.species}_side.png"
        if not ref.is_file():
            sys.exit(f"Accepted reference missing: {ref}")
        body = dict(GEN, image_url="data:image/png;base64," +
                    base64.b64encode(ref.read_bytes()).decode("ascii"),
                    should_texture=True, enable_pbr=True,
                    texture_resolution="2k", texture_prompt=sp["texture_prompt"])
        tid = call("POST", "/v1/image-to-3d", body)["result"]
        record(a.species, stage, tid)
    result = wait("/v1/image-to-3d", tid, stage)
    url = result.get("model_urls", {}).get("glb")
    if not url:
        sys.exit("Succeeded task has no GLB URL")
    work = OUT / a.species / "work"
    work.mkdir(parents=True, exist_ok=True)
    (work / ".gdignore").touch()
    dest = work / f"{a.species}_i2m_v{a.attempt}.glb"
    urllib.request.urlretrieve(url, dest)
    print(dest)


def cmd_refine(a):
    prev = state().get(a.species, {}).get("preview")
    if not prev:
        sys.exit("run preview first")
    sp = spec(a.species)
    body = {"mode": "refine", "preview_task_id": prev, "enable_pbr": True,
            "texture_resolution": "2k"}
    if sp.get("texture_prompt"):
        body["texture_prompt"] = sp["texture_prompt"]
    tid = submit(a.species, "refine", "/v2/text-to-3d", body)
    wait("/v2/text-to-3d", tid, "refine")


def submit(name, stage, path, body):
    tid = state().get(name, {}).get(stage)
    if not tid:
        tid = call("POST", path, body)["result"]
        record(name, stage, tid)
    return tid


def cmd_rig(a):
    sp = spec(a.species)
    if sp.get("rig") == "quadruped":
        sys.exit(f"{a.species} is a quadruped. The rigging API only supports "
                 f"bipeds - rig this one in the Meshy web UI, then drop the "
                 f"rigged GLB into {OUT / a.species}.")
    ref = state().get(a.species, {}).get("i2m") or state().get(a.species, {}).get("refine")
    if not ref:
        sys.exit("run i2m or refine first")
    body = {"input_task_id": ref, "height_meters": sp.get("height_meters", 1.7)}
    tid = submit(a.species, "rig", "/v1/rigging", body)
    wait("/v1/rigging", tid, "rig")


def cmd_animate(a):
    rig = state().get(a.species, {}).get("rig")
    if not rig:
        sys.exit("run rig first")
    ids = [int(x) for x in a.actions.split(",")]
    tid = submit(a.species, f"anim_{'_'.join(map(str, ids))}", "/v1/animations",
                 {"rig_task_id": rig, "action_ids": ids})
    wait("/v1/animations", tid, "animate")
    print(f"  {len(ids)} actions x 3 credits = {len(ids) * 3} credits")


def cmd_motion(a):
    sp = spec(a.species)
    if sp.get("rig") == "quadruped":
        sys.exit("Text to Motion rejects quadruped rigs. Biped only.")
    rig = state().get(a.species, {}).get("rig")
    if not rig:
        sys.exit("run rig successfully before spending on motion")
    prompt = sp["clips"][a.clip]
    # ASSUMPTION: four seconds allows anticipation, strike, and recovery/hold.
    tid = submit(a.species, f"motion_{a.clip}", "/v1/text-to-motion",
                 {"prompt": prompt, "mode": "prime", "duration": 4})
    d = wait("/v1/text-to-motion", tid, "motion")
    rig = state().get(a.species, {}).get("rig")
    if rig:
        at = submit(a.species, f"anim_{a.clip}", "/v1/animations",
                    {"rig_task_id": rig, "motion_task_id": tid})
        wait("/v1/animations", at, "apply")


def cmd_status(a):
    s = state()
    for name in ([a.species] if a.species else sorted(s)):
        print(f"\n{name}")
        for stage, tid in s.get(name, {}).items():
            print(f"  {stage:<22} {tid}")


def split_glb(source, destination, clip, index=0):
    """Select/rename animation JSON only; preserve binary mesh and transforms."""
    raw = source.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", raw)
    if magic != b"glTF" or version != 2 or length != len(raw):
        raise ValueError(f"Invalid GLB: {source}")
    size, kind = struct.unpack_from("<II", raw, 12)
    if kind != 0x4e4f534a:
        raise ValueError("First GLB chunk is not JSON")
    doc = json.loads(raw[20:20+size])
    animations = doc.get("animations", [])
    if index >= len(animations):
        raise ValueError(f"Missing animation {index}: {source}")
    animation = copy.deepcopy(animations[index])
    animation["name"] = clip
    doc["animations"] = [animation]
    encoded = json.dumps(doc, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    tail = raw[20+size:]
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(struct.pack("<4sII", b"glTF", 2, 20+len(encoded)+len(tail)) +
                           struct.pack("<II", len(encoded), kind) + encoded + tail)


def cmd_fetch(a):
    """Fetch recorded stages into the contract layout without changing geometry."""
    directory = OUT / a.species
    work = directory / "work"
    work.mkdir(parents=True, exist_ok=True)
    (work / ".gdignore").touch()
    presets = spec(a.species).get("pipeline", {}).get("preset_actions", {})

    def download(url, dest):
        if not url:
            raise ValueError(f"Task has no GLB for {dest}")
        dest.parent.mkdir(parents=True, exist_ok=True)
        if not dest.exists():
            urllib.request.urlretrieve(url, dest)
        return dest

    for stage, tid in state().get(a.species, {}).items():
        if stage == "rig":
            task = call("GET", f"/v1/rigging/{tid}")
        elif stage.startswith("anim_"):
            task = call("GET", f"/v1/animations/{tid}")
        elif stage.startswith("i2m") or stage in ("preview", "refine"):
            endpoint = "/v1/image-to-3d" if stage.startswith("i2m") else "/v2/text-to-3d"
            task = call("GET", f"{endpoint}/{tid}")
        else:
            continue
        if task.get("status") != "SUCCEEDED":
            print(f"Skip {stage}: {task.get('status')}")
            continue
        result = task.get("result") or {}
        if stage == "rig":
            model = download(result.get("rigged_character_glb_url"), directory / f"{a.species}.glb")
            for source_name, clip in (("walking", "walk"), ("running", "run")):
                url = result.get("basic_animations", {}).get(f"{source_name}_glb_url")
                if url:
                    raw = download(url, work / f"rig_{clip}.glb")
                    split_glb(raw, directory / "anim" / f"{clip}.glb", clip)
                else:
                    print(f"No separate {clip}; inspect embedded clips in {model}")
        elif stage.startswith("anim_"):
            raw = download(result.get("animation_glb_url"), work / f"{stage}.glb")
            suffix = stage[5:]
            if suffix.replace("_", "").isdigit():
                for index, action in enumerate(map(int, suffix.split("_"))):
                    clips = [name for name, value in presets.items() if value == action]
                    if len(clips) != 1:
                        raise ValueError(f"Missing unique preset_actions mapping for {action}")
                    split_glb(raw, directory / "anim" / f"{clips[0]}.glb", clips[0], index)
            else:
                split_glb(raw, directory / "anim" / f"{suffix}.glb", suffix)
        else:
            suffix = "i2m_v1" if stage == "i2m" else stage
            download(task.get("model_urls", {}).get("glb"), work / f"{a.species}_{suffix}.glb")



P = argparse.ArgumentParser(description=__doc__,
                            formatter_class=argparse.RawDescriptionHelpFormatter)
sub = P.add_subparsers(dest="cmd", required=True)
for n, fn, args in [
    ("balance", cmd_balance, []),
    ("library", cmd_library, [("--search", {}), ("--category", {})]),
    ("preview", cmd_preview, [("species", {})]),
    ("i2m", cmd_i2m, [("species", {}), ("--attempt", {"type": int, "choices": [1, 2], "default": 1})]),
    ("refine", cmd_refine, [("species", {})]),
    ("rig", cmd_rig, [("species", {})]),
    ("animate", cmd_animate, [("species", {}), ("--actions", {"required": True})]),
    ("motion", cmd_motion, [("species", {}), ("--clip", {"required": True})]),
    ("status", cmd_status, [("species", {"nargs": "?"})]),
    ("fetch", cmd_fetch, [("species", {})]),
]:
    sp_ = sub.add_parser(n)
    for an, kw in args:
        sp_.add_argument(an, **kw)
    sp_.set_defaults(func=fn)

if __name__ == "__main__":
    a = P.parse_args()
    a.func(a)
