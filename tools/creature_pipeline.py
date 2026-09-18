#!/usr/bin/env python3
"""One-command creature pipeline: species JSON -> references -> Meshy mesh -> rigged, animated contract files.

Stages (resumable; task ids live in tools/meshy_state.json under <species>.v<N>):
  refs      text-to-image side + front (nano-banana-pro, 9 credits each)
  mesh      multi-image-to-3D, Meshy 7, textured PBR 2k (30 credits)
  fetch     download the GLB to game/assets/creatures/<species>/work/<species>_i2m_v<N>.glb
  rig       tools/transplant_rig.py with the donor for the species' rig type
  sheets    rest sheet + posed QA renders
  json      pipeline block in game/data/creatures/<species>.json

Usage (repo root):
  python3 tools/creature_pipeline.py <species> [--stage refs|mesh|fetch|rig|sheets|json|all] [--version N] [--dry-run]
  python3 tools/creature_pipeline.py velociraptor --version 2        # redo a species
The Meshy key comes from MESHY_API_KEY or the Meshy MCP entry in ~/.claude.json.
"""
import argparse, base64, json, pathlib, subprocess, sys, time, urllib.request, urllib.error

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "game" / "data" / "creatures"
OUT = ROOT / "game" / "assets" / "creatures"
STATE = ROOT / "tools" / "meshy_state.json"
API = "https://api.meshy.ai/openapi"
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
DONORS = {"biped": "tools/standins/quaternius/Velociraptor.fbx", "biped_large": "tools/standins/quaternius/Trex.fbx",
          "quadruped": "tools/standins/quaternius/Triceratops.fbx"}
CLIP_MAP = ["Attack=attack_primary", "Jump=attack_heavy", "Death=death", "Idle=idle", "Run=run", "Walk=walk"]

# Reference wording that fixed the arm/leg confusion and the tail (roster PRD §4.2, C2b report).
BIPED_SIDE = ("Orthographic left-side profile of a {name}, accurate palaeoart, full body, spine horizontal and parallel to the ground, "
              "long stiff tail straight back. Only two legs touch the ground. Forelimbs SHORT and folded up against the chest, clawed hands "
              "tucked at the ribs far above the knees, clearly arms not legs. {look} neutral standing pose, flat even lighting, plain white "
              "background, no shadow, no text, whole animal visible with margin.")
BIPED_FRONT = ("Orthographic front view of the same {name} facing the camera head-on, accurate palaeoart, body horizontal so head and chest face "
               "the viewer, only two legs on the ground shoulder-width apart, SHORT forelimbs folded against the chest with hands tucked at the "
               "ribs high above the knees, clearly arms not legs. {look} neutral standing pose, flat even lighting, plain white background, no "
               "shadow, no text, whole animal visible with margin.")
QUAD_SIDE = ("Orthographic left-side profile of a {name}, accurate palaeoart, full body on four sturdy legs, all four feet on the ground, "
             "{look} neutral standing pose, flat even lighting, plain white background, no shadow, no text, whole animal visible with margin.")
QUAD_FRONT = ("Orthographic front view of the same {name} facing the camera head-on, accurate palaeoart, four legs on the ground, {look} neutral "
              "standing pose, flat even lighting, plain white background, no shadow, no text, whole animal visible with margin.")


def key():
    import os
    k = os.environ.get("MESHY_API_KEY")
    if not k:
        cfg = pathlib.Path.home() / ".claude.json"
        k = json.loads(cfg.read_text())["mcpServers"]["meshy-mcp-server"]["env"]["MESHY_API_KEY"]
    return k


def call(method, path, body=None):
    req = urllib.request.Request(f"{API}{path}", method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {key()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code} {method} {path}\n{e.read().decode()[:800]}")


def wait(path, tid, label):
    for _ in range(240):
        d = call("GET", f"{path}/{tid}")
        st = d.get("status")
        print(f"  {label} {st} {d.get('progress', '')}%", flush=True)
        if st in ("SUCCEEDED", "FAILED", "CANCELED"):
            if st != "SUCCEEDED":
                sys.exit(f"{label} {st}: {d.get('task_error')}")
            return d
        time.sleep(8)
    sys.exit(f"{label} timed out")


def state():
    return json.loads(STATE.read_text()) if STATE.exists() else {}


def save_state(s):
    STATE.write_text(json.dumps(s, indent=2) + "\n")


def record(species, ver, k, v):
    s = state(); s.setdefault(species, {}).setdefault(f"v{ver}", {})[k] = v; save_state(s)
    print(f"{species}.v{ver}.{k} = {v}")


def get(species, ver, k):
    return state().get(species, {}).get(f"v{ver}", {}).get(k)


def data_uri(p):
    return "data:image/png;base64," + base64.b64encode(pathlib.Path(p).read_bytes()).decode()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("species"); ap.add_argument("--stage", default="all"); ap.add_argument("--version", type=int, default=1)
    ap.add_argument("--dry-run", action="store_true"); ap.add_argument("--polycount", type=int, default=20000)
    a = ap.parse_args()
    sp = json.loads((SPEC / f"{a.species}.json").read_text())
    ver = a.version
    rig = sp.get("rig", "biped")
    big = sp.get("real_length_m", 0) >= 8.0 and rig == "biped"
    donor = DONORS["biped_large" if big else rig]
    name = sp["species"]
    look = sp.get("look", sp.get("texture_prompt", ""))
    side_t, front_t = (QUAD_SIDE, QUAD_FRONT) if rig == "quadruped" else (BIPED_SIDE, BIPED_FRONT)
    side_prompt = side_t.format(name=name, look=look)[:600]
    front_prompt = front_t.format(name=name, look=look)[:600]
    d = OUT / a.species; (d / "ref").mkdir(parents=True, exist_ok=True); (d / "work").mkdir(exist_ok=True)
    (d / "ref" / ".gdignore").touch(); (d / "work" / ".gdignore").touch()
    stages = ["refs", "mesh", "fetch", "rig", "sheets", "json"] if a.stage == "all" else [a.stage]
    if a.dry_run:
        print("SIDE:", side_prompt, "\nFRONT:", front_prompt, "\nDONOR:", donor); return

    if "refs" in stages:
        for view, prompt, ratio in (("side", side_prompt, "16:9"), ("front", front_prompt, "3:4")):
            if get(a.species, ver, f"ref_{view}"):
                print(f"ref_{view} exists, skipping"); continue
            tid = call("POST", "/v1/text-to-image", {"ai_model": "nano-banana-pro", "prompt": prompt, "aspect_ratio": ratio})["result"]
            record(a.species, ver, f"ref_{view}", tid)
            res = wait("/v1/text-to-image", tid, f"ref_{view}")
            url = res["image_urls"][0]
            dest = d / "ref" / f"{a.species}_{view}_v{ver}.png"
            urllib.request.urlretrieve(url, dest); print("  saved", dest.relative_to(ROOT))
    if "mesh" in stages:
        if get(a.species, ver, "i2m"):
            print("i2m exists, skipping")
        else:
            imgs = [data_uri(d / "ref" / f"{a.species}_{v}_v{ver}.png") for v in ("side", "front")]
            body = {"image_urls": imgs, "ai_model": "meshy-7", "should_texture": True, "enable_pbr": True, "texture_resolution": "2k",
                    "texture_prompt": sp.get("texture_prompt", "")[:600], "target_polycount": a.polycount, "should_remesh": True,
                    "target_formats": ["glb"]}
            tid = call("POST", "/v1/multi-image-to-3d", body)["result"]
            record(a.species, ver, "i2m", tid)
            wait("/v1/multi-image-to-3d", tid, "i2m")
    if "fetch" in stages:
        tid = get(a.species, ver, "i2m")
        res = call("GET", f"/v1/multi-image-to-3d/{tid}")
        url = res["model_urls"]["glb"]
        dest = d / "work" / f"{a.species}_i2m_v{ver}.glb"
        urllib.request.urlretrieve(url, dest); print("  saved", dest.relative_to(ROOT), dest.stat().st_size // 1024, "KB")
    if "rig" in stages:
        mesh = d / "work" / f"{a.species}_i2m_v{ver}.glb"
        cmd = [BLENDER, "--background", "--python", str(ROOT / "tools" / "transplant_rig.py"), "--", "--mesh", str(mesh.relative_to(ROOT)),
               "--donor", donor, "--species", a.species, "--map", *CLIP_MAP]
        out = subprocess.run(cmd, capture_output=True, text=True).stdout
        for line in out.splitlines():
            if line.startswith(("MESH", "REPAIR", "WARP", "WEIGHTS", "AUTHORED", "PIPELINE", "Traceback", "Error")) or "line " in line:
                print(line[:300])
        pipe = [l for l in out.splitlines() if l.startswith("PIPELINE ")]
        if pipe:
            record(a.species, ver, "rig_result", json.loads(pipe[0][9:]))
    if "sheets" in stages:
        subprocess.run([BLENDER, "--background", "--python", str(ROOT / "tools" / "render_glb.py"), "--", str(d / f"{a.species}.glb"), str(d / "sheet.png")], capture_output=True)
        anims = ",".join(str(p) for p in sorted((d / "anim").glob("*.glb")))
        qa = d / "work" / "qa"; qa.mkdir(exist_ok=True)
        subprocess.run([BLENDER, "--background", "--python", str(ROOT / "tools" / "render_posed.py"), "--", str(d / f"{a.species}.glb"), str(qa / "qa"),
                        "--frac", "0.5", "--view", "side", "--anim", anims], capture_output=True)
        print("  sheets:", d / "sheet.png", "and", qa)
    if "json" in stages:
        rr = get(a.species, ver, "rig_result") or {}
        p = SPEC / f"{a.species}.json"; j = json.loads(p.read_text()); pl = j.setdefault("pipeline", {})
        pl.update({"route": "skeleton_transplant_v2", "forward_axis": "+Z", "version": ver,
                   "mesh_source": f"res://assets/creatures/{a.species}/work/{a.species}_i2m_v{ver}.glb",
                   "reference": {"side": get(a.species, ver, "ref_side"), "front": get(a.species, ver, "ref_front")}, "i2m": get(a.species, ver, "i2m"),
                   "i2m_params": {"model": "meshy-7 multi-image", "polycount": a.polycount, "texture": "2k PBR"}, "credits_spent": 48,
                   "donor_rig": donor, "transplant_tool": "tools/transplant_rig.py",
                   "source_height_m": rr.get("source_height_m"), "source_length_m": rr.get("source_length_m"),
                   "repair": rr.get("repair"), "warp": rr.get("warp"), "weights": rr.get("weights"),
                   "clips": ["idle", "walk", "run", "attack_primary", "attack_heavy", "hit_react", "knockdown", "death", "alert"],
                   "authored_clips": rr.get("authored_clips")})
        p.write_text(json.dumps(j, indent=2) + "\n"); print("  json updated", p.relative_to(ROOT))


if __name__ == "__main__":
    main()
