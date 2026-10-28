#!/usr/bin/env python3
"""Generate the wiki's game-data truth pages + owner-editable CSV sheets.

Source of truth: the canon worktree's `game/data/*.json` (the build's own data).
Emits (all generated files carry a generation header; never hand-edit them):
  docs/current/recipes.md       recipe data + repair tiers + station times
  docs/current/world-biomes.md  island roster, per-climate flora/materials, fauna, butchering
  docs/current/items-traits.md  full item catalog with rarity/attributes, food effects, traits
  <data>/../data_sheets/*.csv   the same rows as flat spreadsheets the owner can edit
                                (Numbers / Excel / Google Sheets all open CSV natively)

Run from the canon repo root:  python3 tools/docs_wiki/gen_game_data.py
After editing a sheet, ask the agent to sync it back; the sync validates ids and
rewrites only the changed values (the round-trip lives in sync_game_data.py).
Generation refuses to replace a differing existing sheet or sheet notes unless
--force-sheets is explicitly passed. Sync owner edits first; forcing may discard them.
"""
import argparse
import csv
import json
import shutil
import tempfile
from collections import OrderedDict
from datetime import date
from pathlib import Path


def load(data: Path, name: str):
    with open(data / name) as f:
        return json.load(f)


def attrs(d) -> str:
    if isinstance(d, dict):
        return ", ".join("%s=%s" % (k, v) for k, v in d.items())
    if isinstance(d, list):
        return "; ".join(str(x) for x in d)
    return str(d)


def slots_txt(slots) -> str:
    parts = []
    for s in slots or []:
        key = s.get("category") or s.get("id") or "?"
        txt = "%s x%s" % (key, s.get("count", 1))
        if s.get("primary"):
            txt += " (primary)"
        parts.append(txt)
    return "; ".join(parts)


def write_md(lines, path: Path, title: str) -> None:
    body = lines[:]
    header = "> Generated %s by `tools/docs_wiki/gen_game_data.py` from the build's own data. Never hand-edit; re-run after any balance pass.\n" % date.today().isoformat()
    text = "# %s\n\n%s\n%s\n" % (title, header, "\n".join(body))
    path.write_text(text)


def write_csv(path: Path, header, rows) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)


def dict_cell(v) -> str:
    """A dict/list rendered JSON for a CSV cell; empty stays truly empty."""
    if not v:
        return ""
    return json.dumps(v)


def energy_cell(f) -> str:
    en = f.get("energy") or {}
    if not en:
        return ""
    return " ".join("%s=%s" % (k, v) for k, v in sorted(en.items()))


# ------------------------------------------------------------------ recipes

def gen_recipes(data: Path, docs: Path, sheets: Path) -> None:
    rec = load(data, "recipes.json")
    items = {r["id"]: r for r in load(data, "items.json")["items"]}
    proc = load(data, "processing.json")
    rows = rec["recipes"]

    name = lambda i: items.get(i, {}).get("display_name", str(i))
    L = []
    a = L.append
    a("`%d recipes` from `game/data/recipes.json`; station-only workflow times from `game/data/processing.json`." % len(rows))
    a("")
    a("These rows describe game data; a row alone does not prove that its output is playable. "
      "`min skill` is the recipe's minimum level gate when greater than zero; the gate also "
      "checks the resulting item level. Other gates may apply. `ability target` affects success "
      "chance rather than imposing a hard gate. `recipe max_level` is the configured output-level "
      "cap; the actual result also depends on materials, skill, and runtime bounds. Absent values use the defaults in "
      "`game/scripts/items/crafting.gd`: minimum 0, ability 0, and output cap 60.")
    a("")
    by_station = OrderedDict()
    for r in rows:
        by_station.setdefault(r.get("station") or "hand", []).append(r)
    for st, list_ in by_station.items():
        if st == "hand":
            a("## Hand crafting")
        else:
            kind = proc.get("stations", {}).get(st, {})
            a("## %s (%s)" % (kind.get("label", st), st))
            times = kind.get("recipes", {})
            if times:
                a("")
                a("Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: " + ", ".join("`%s` %ss" % (rid, td.get("seconds", "?")) for rid, td in sorted(times.items())) + ".")
        a("")
        a("| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |")
        a("|---|---|---|---|---|---|---|---|---|")
        for r in list_:
            out_row = "%s x%s" % (name(r["output"]["id"]), r["output"].get("count", 1))
            if r.get("outputs_by_primary"):
                out_row += " (by slot 1: %s)" % ", ".join("%s → %s" % (k, name(v["id"])) for k, v in r["outputs_by_primary"].items())
            skill = r.get("skill", "processing")
            step = []
            if r.get("process_step"):
                step.append("%s +%s" % (r["process_step"], r.get("process_add", 0)))
            a("| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                r["id"], out_row, slots_txt(r.get("slots")), skill,
                r.get("min_level", 0), max(0, r.get("required_ability", 0)), r.get("max_level", 60),
                r.get("seconds", "?"), "; ".join(step)))
        a("")
    reps = rec.get("repairs", [])
    if reps:
        a("## Repairs — per-tier cost")
        a("")
        a("One unit of the tier's material restores `restore_fraction` of max durability at the named station (ASSUMPTION values, W2-PROCESS/W2-CRAFT).")
        a("")
        a("| tier | station | input | restore |")
        a("|---|---|---|---|")
        for r in reps:
            a("| `%s` | `%s` | %s | %s |" % (r.get("tier", "?"), r.get("station", "?"), slots_txt(r.get("slots")), r.get("restore_fraction", "?")))
        a("")
    write_md(L, docs / "recipes.md", "Crafting recipes — game data catalog")

    write_csv(sheets / "recipes.csv",
              ["id", "display_name", "skill", "max_level", "station", "seconds", "slots", "output_id", "output_count", "process_step", "process_add"],
              [[r["id"], r.get("display_name", ""), r.get("skill", ""), r.get("max_level", ""),
                r.get("station") or "hand", r.get("seconds", ""),
                "; ".join("%s=%s" % (x.get("category", x.get("id", "?")), x.get("count", 1)) for x in (r.get("slots") or [])),
                r["output"]["id"], r["output"].get("count", 1), r.get("process_step", ""), r.get("process_add", "")] for r in rows])
    write_csv(sheets / "repairs.csv",
              ["tier", "station", "input", "count", "restore_fraction"],
              [[r.get("tier", ""), r.get("station", ""), (r.get("slots") or [{}])[0].get("category", ""),
                (r.get("slots") or [{}])[0].get("count", 1), r.get("restore_fraction", "")] for r in reps])
    write_csv(sheets / "processing.csv",
              ["station", "label", "slots", "fx", "recipe", "seconds"],
              [[sid, k.get("label", ""), k.get("slots", ""), k.get("fx", ""), rid, td.get("seconds", "")]
               for sid, k in sorted(proc.get("stations", {}).items())
               for rid, td in sorted((k.get("recipes") or {}).items())])


# ------------------------------------------------------------------ biomes

def island_row(i):
    """Island files vary in vintage; the id suffix encodes climate + tier, so fall back to it."""
    import re
    m = re.match(r"^(.*)_(\d+)$", str(i["id"]))
    climate = i.get("climate") or (m.group(1) if m else "")
    tier = i.get("tier") or (int(m.group(2)) if m else "")
    kind = i.get("kind") or ("private" if str(i["id"]) == "home_grassland" else "unstable")
    name = i.get("display_name") or ""
    if not name:
        name = "%s %s" % (kind.title(), climate.replace("_", " ").title())
    return [i["id"], name, climate, tier, kind, i.get("permanent", ""), i.get("lifetime_seconds", ""), str(i.get("size_m", ""))]


HEAT_TOKENS = {"heat_weak": 1, "heat_high": 2, "heat_volcanic": 3}
COLD_TOKENS = {"cold_weak": 1, "cold_high": 2}


def weather_section(rules, cl, a) -> None:
    """WEATHER: per-climate rain/storm odds (rules.json weather) and the heat/cold look (climates.json resist)."""
    w = rules.get("weather", {})
    if not w:
        return
    a("## Weather")
    a("")
    a("Code: `game/scripts/world/world_weather.gd` (state), `game/scripts/world/weather_fx.gd` (screen layer, light pulse, camera shake), "
      "`game/shaders/weather/`. Numbers: `game/data/world/rules.json` `weather`. Test: `game/tests/t_weather.gd`; lab: `scenes/dev/weather_lab.tscn`.")
    a("")
    modes = w.get("rain_modes", {})
    a("- **Rain** in three modes: every %s-%s s (first check %s s) the island rolls its climate's rain chance; a spell lasts "
      "%s-%s s in a mode picked by the climate's weights (default %s). Each mode has its own particle share, drop size and speed, "
      "darkening (grey wash and sun dimming up to half) and wet-ground strength (the terrain darkens and gets a sheen through the "
      "`weather_wet` shader global); only pouring rain splashes. Modes: %s. `WorldWeather.rain_mode` / `rain_level()` (1-3) are "
      "what the day/night dial reads; `rain_mode_changed` is the sound hook." % (
          w["rain_check_s"][0], w["rain_check_s"][1], w["first_check_s"], w["rain_len_s"][0], w["rain_len_s"][1],
          w.get("default_modes"), "; ".join("%s particles x%s, dark %s, wet %s" % (k, v["amount"], v["dark"], v["wet"]) for k, v in modes.items())))
    a("- **Storm** (pouring rain and lightning): a rain spell is a storm on the climate's storm roll and lasts %s-%s s. A strike "
      "every %s-%s s lands at a real ground point around the survivor, at a distance from the bands %s ([share, min m, max m]: "
      "some close, most mid, some far). It spawns a jagged bolt with two branches, a ground flash and a scorch that fades over 6 s "
      "(`LightningBolt`, unshaded additive quads, gl_compatibility-safe), a double flicker of the screen and a light from the "
      "strike's direction. Thunder lands the strike's distance / %s m/s later (near: at once; 2.5 km: 7.3 s) and the camera "
      "rumble scales down with log distance (up to %s m). `WorldWeather.lightning(position, distance)` / `thunder(distance)` are "
      "the sound hooks (no audio yet). ASSUMPTION: strikes damage nothing." % (
          w["storm_len_s"][0], w["storm_len_s"][1], w["lightning_gap_s"][0], w["lightning_gap_s"][1],
          w["lightning_bands"], w["sound_mps"], w["shake_m"]["thunder"]))
    a("- **Wet** (an effect box beside her, like bleed and poison: water-drop glyph, `UiTokens.WET` blue, drips and a sheen, a "
      "tooltip on press): rain soaks her to 1 / 2 / 3 stacks by mode, water to 3. Each stack lasts the status's duration in the "
      "open; heat (x(1 + %s x heat)) and a burning fire within %s m (+%s) dry her faster; sitting by a fire still clears it. Wet "
      "keeps heat fatigue x0.8, makes cold fatigue and the cold look x1.3 and resting recover x0.85." % (
          w["drying"]["heat_mult"], w["drying"]["fire_m"], w["drying"]["fire_mult"]))
    fw = rules.get("fire_weather", {})
    if fw:
        a("- **Rain on fires** (`game/scripts/world/fire_weather.gd`, rules.json `fire_weather`): an unsheltered fire burns fuel "
          "faster by mode (%s) and wears faster (%s); the stone firepit feels %s of that. Only pouring rain and storms soak a fire: "
          "a bonfire or campfire goes out in about 90 s of pouring (60 s of storm), the firepit in about 5 min. The flame shrinks and "
          "sputters and steam rises. No lighting or placing a fire in pouring rain without a roof (\"Too wet to light a fire\"). "
          "`WorldWeather.fire_out` is the hiss hook." % (fw["fuel_mult"], fw["wear_mult"], fw["permanent_share"]))
        sm = fw["smoke"]
        a("- **Smoke under a roof**: a roof (or ceiling) over the fire's module keeps the rain off, but smoke pools under it toward "
          "%s + %s x enclosure (walls 1, windows 0.8, doorways 0.5 on the module's four edges) over %s s, and clears in %s s once "
          "the fire is out or the roof is gone; an open-sided shelter stays thin. From %s it gives **Smoke Inhalation** (an ash-grey "
          "hazard box, cough puffs, grey tick numbers) within %s m under the roof: 0.4 Health a second per stack, stacks at %s; it "
          "ends 3 s after she leaves." % (sm["open_floor"], round(1 - sm["open_floor"], 2), sm["rise_s"], sm["vent_s"], sm["hurt_from"],
          sm["radius_m"], sm["stack_at"]))
    a("- **Heat** (by day where the climate asks for heat resistance): an orange screen edge in the combat red edge's style, a warm "
      "wash, a heat shimmer (high quality) and a slow sway up to %s m." % w["shake_m"]["heat"])
    a("- **Cold** (any hour where it asks for cold resistance): a blue-white edge, frost creeping in from the borders (corners first) "
      "and a shiver (%s m) on getting cold, on defrosting, and every %s-%s s while cold." % (
          w["shake_m"]["shiver"], w["shiver_gap_s"][0], w["shiver_gap_s"][1]))
    a("- **Strength**: severity = resistance need / 3 (0.4-1) x (0.4 + 0.6 x unmet share); the unmet share counts while climate "
      "fatigue charges it (heat by day, cold otherwise). Wet and Quenched cool the heat, sitting by a fire warms the cold.")
    a("- **Screen rules**: the layer is canvas layer -1, under every HUD layer, so HUD rects and the combat red edge draw over it; "
      "during a hunt or a red-edge status the weather edges drop to 35 %%. Weather shake never exceeds %s m; `--reduce-shake` turns "
      "off every camera shake (combat too)." % w["shake_m"]["max"])
    a("- **Idle by mood**: standing still, the survivor plays `idle_exhausted` (fatigue 75 %+) > `idle_cold` / `idle_heat` (weather feel 0.5+, the stronger) > `idle_tired` (50 %+) > `idle`, each only when its clip exists in `assets/characters/survivor/anim/` (the next in line otherwise), blended over 0.5 s; moving and busy clips win (`PlayerAnim.pick_idle`).")
    a("- **Debug**: `--weather=clear|drizzle|rain|pour|storm|heat|cold` holds a state; `--weather-quality=low|high` (low drops the shimmer; "
      "default low on iOS / Android).")
    a("")
    a("| climate | rain chance per check | storm share of spells | heat look by day | cold look |")
    a("|---|---|---|---|---|")
    for cid in sorted(cl):
        c = cl[cid]
        if cid.startswith("_") or not c.get("tiers"):
            continue
        res = c.get("resist", [])
        nh = max([HEAT_TOKENS.get(r, 0) for r in res] + [0])
        nc = max([COLD_TOKENS.get(r, 0) for r in res] + [0])
        nh += 1 if nh and ("sun" in res or "humidity" in res) else 0
        nc += 1 if nc and "wind" in res else 0
        odds = w.get("climates", {}).get(cid, {})
        look = lambda n: "-" if n == 0 else "%.2f-%.2f" % (min(1.0, max(0.4, n / 3.0)) * 0.4, min(1.0, max(0.4, n / 3.0)))
        a("| %s | %s | %s | %s | %s |" % (cid, odds.get("rain", 0), odds.get("storm", 0), look(nh), look(nc)))
    a("")
    a("The look columns run from fully resisted to fully unmet.")
    a("")
    a('## Sea and shore')
    a('')
    a('Code: `game/scripts/world/water.gdshader` (sea), `game/scripts/world/shore_wash.gdshader` (swash skin), `game/scripts/world/sea_waves.gd` (weather driver, skin and surf mask). Test: `game/tests/t_waves.gd`; lab: `scenes/dev/waves_lab.tscn`.')
    a('')
    a('- **Swell**: summed Gerstner waves along a prevailing wind (30 m and 17 m move the sea mesh; 9 m and, on high quality, 5.5 m only shade it per pixel). Crests are lighter and troughs darker so the swell reads from the high game camera; ripples and sun glints come from scrolling noise normals.')
    a("- **Shore**: two breaker foam lines run in from 0.55 m of depth to the waterline, half a cycle (7 s) apart, their timing jittered along the coast. Each then runs up the sand as a foam lip over a thin sheet of water, drains back leaving bubbles, and leaves a wet darkening line at that cycle's high mark which fades until the next one. Only sea-facing beaches get surf: none in or beside the river (6-14 m) or on inland water.")
    a('- **Weather**: sea state 0 (clear) to 1 (storm) = rain_amount x 0.5 + 0.5 in a storm (rain about 0.35), eased over about 6 s. Clear to storm: swell 0.08 to 0.40 m, chop 0.25 to 1.0, foam 0.55 to 1.0, swash run-up 0.07 to 0.20 m of height above the sea, a greyer sea, whitecaps on the crests from about half way, and the wind swings up to 0.5 rad.')
    a('- **Gameplay**: none. The logical sea stays at -0.05 m (`HarbourSite.WATER_Y`) for swimming, wading, harbours, walkability and building. Near the shore the swell only rises, never dips, so the drawn waterline stays on the logical one.')
    a('- **Opacity**: shallow water fades from 62 % at the waterline to solid at 1.6 m, so the bed shows in the shallows but never through open water.')
    a('- **Quality**: `--water-quality=low|high`; low (default on web and phones) uses 16 m sea quads instead of 8 m, three swell waves instead of four, and no glint layer.')
    a('')


def gen_biomes(data: Path, docs: Path, sheets: Path) -> None:
    cl = load(data, "world/climates.json")
    isl = [load(data, "islands/%s" % f.name) for f in sorted(Path(data, "islands").glob("*.json"))]
    but = load(data, "butchering.json").get("species", {})
    creatures = []
    for f in sorted(Path(data, "creatures").glob("*.json")):
        d = load(data, "creatures/%s" % f.name)
        if "species" in d:
            creatures.append((d, but.get(f.name.replace(".json", ""), {})))
    creatures.sort(key=lambda t: (t[0].get("tier", 0), t[0].get("species", "")))

    L = []
    a = L.append
    a("Sources: `game/data/islands/*.json`, `game/data/world/climates.json`, `game/data/world/rules.json` (weather), `game/data/world/sky.json`, `game/data/creatures/*.json`, `game/data/butchering.json`.")
    a("")
    a("## Island roster (%d)" % len(isl))
    a("")
    a("| island | name | climate | tier | kind | permanent | lifetime (s) |")
    a("|---|---|---|---|---|---|---|")
    for i in isl:
        r = island_row(i)
        a("| `%s` | %s | %s | %s | %s | %s | %s |" % tuple(r[:7]))
    a("")
    a("## Climates — flora & gatherable materials")
    a("")
    for cid in sorted(cl):
        c = cl[cid]
        if cid.startswith("_") or not c.get("tiers"):
            continue
        home = " — **the private home island**" if c.get("home") else ""
        a("### %s — tiers %s%s" % (cid, ", ".join("L%s" % t for t in c["tiers"]), home))
        a("")
        res = c.get("resist", [])
        if res:
            a("- Survival resist needed: %s." % ", ".join("`%s`" % r for r in res))
        veg = c.get("vegetation", [])
        if veg:
            a("- Vegetation families: %s." % ", ".join("`%s`" % v for v in veg))
        mats = []
        for m in c.get("materials", []):
            mats.append("`%s`%s" % (m["id"], " *(attr: %s)*" % m["attr"] if m.get("attr") else ""))
        if mats:
            a("- Gatherable materials (yellow-pip latent attr when noted): %s." % ", ".join(mats))
        a("")
    a("A climate's `materials` list is what its island generator may place; gather yields per family are the gather-system's own table (`world/rules.json`).")
    a("")
    weather_section(load(data, "world/rules.json"), cl, a)
    sky = load(data, "world/sky.json")
    if sky:
        base = sky.get("default", {})
        a("## Sky shadows — cloud cover and pteranodons")
        a("")
        a("Soft cloud shadows drift across the ground with the wind, the sun dips a little while a cloud covers the survivor, and 1-3 pteranodons glide in wide circles overhead. Only their shadows are drawn (the camera's narrow lens would show a flyer mid-screen, not at an edge); everything fades out at night. The terrain, grass, ground cover, dirt pads, water and painted cards darken; 3D props and creatures do not. Off on a phone browser and with `--skyshadows=off`. Code: `game/scripts/world/sky_shadows.gd`, `game/shaders/sky/sky_shadow.gdshaderinc`; numbers: `game/data/world/sky.json` (all ASSUMPTION look values).")
        a("")
        a("| climate | cloud cover | cloud darkening | wind (m/s) | flyers |")
        a("|---|---|---|---|---|")
        for cid in sorted(k for k in sky if not k.startswith("_") and k != "default"):
            c = dict(base)
            c.update(sky[cid])
            w = c.get("wind_mps", [0, 0])
            a("| %s | %d%% | %s | %s, %s | %s |" % (cid, round(float(c.get("cloud_cover", 0)) * 100), c.get("cloud_strength"), w[0], w[1], c.get("flyers")))
        a("")
        a("Shared: flyer shadow darkening %s, glide %s m/s, sun dip %s at full cover, web-renderer scale %s." % (
            base.get("flyer_strength"), base.get("glide_mps"), base.get("sun_dip"), base.get("compat_scale")))
        a("")
    a("## Fauna (%d species)" % len(creatures))
    a("")
    a("| tier | species | climate | clade | period | length (m) |")
    a("|---|---|---|---|---|---|")
    for d, _ in creatures:
        a("| %s | **%s** | %s | %s | %s | %s |" % (
            d.get("tier"), d.get("species"), d.get("climate"), d.get("clade", ""), d.get("period", ""), d.get("real_length_m", "")))
    a("")
    a("## Butchering drops per species")
    a("")
    a("`base` drops fall on every kill, counts scaled by the local survivor's best knife tier (+15% per tier above stone, 0.75x with no knife, never below 1) and Butchering level (+1% per level); `rare` drops need butcher skill at least the listed level and then roll a chance (default 0.12, +15% per knife tier, cap 0.6). Any part a Butchering skill node gates waits until that node is learned. Numbers: `game/data/loot_tables.json` `butcher`; code: `game/scripts/gather/loot_roller.gd` `roll_carcass`.")
    a("")
    for d, b in creatures:
        if not b:
            continue
        a("- **%s** — base: %s; rare: %s" % (
            d.get("species"),
            "; ".join("`%s` %s–%s" % (x["id"], x.get("min"), x.get("max")) for x in b.get("base", [])),
            "; ".join("`%s` %s–%s (skill %s)" % (x["id"], x.get("min"), x.get("max"), x.get("skill", "?")) for x in b.get("rare", []))))
    a("")
    write_md(L, docs / "world-biomes.md", "World — islands, biomes, flora & fauna")

    write_csv(sheets / "islands.csv",
              ["id", "display_name", "climate", "tier", "kind", "permanent", "lifetime_seconds", "size_m"],
              [island_row(i) for i in isl])
    write_csv(sheets / "climates.csv",
              ["climate", "tiers", "home", "resist", "vegetation", "materials"],
              [[cid, ";".join(str(t) for t in c.get("tiers", [])), c.get("home", ""), ";".join(c.get("resist", [])),
                ";".join(c.get("vegetation", [])),
                ";".join(m["id"] + (("+" + m["attr"]) if m.get("attr") else "") for m in c.get("materials", []))]
               for cid, c in sorted(cl.items()) if not cid.startswith("_") and c.get("tiers")])
    write_csv(sheets / "creatures.csv",
              ["species", "tier", "climate", "clade", "period", "real_length_m"],
              [[d.get("species"), d.get("tier"), d.get("climate"), d.get("clade", ""), d.get("period", ""), d.get("real_length_m", "")] for d, _ in creatures])
    rows = []
    for d, b in creatures:
        sp = str(d.get("species")).lower().replace(" ", "_")
        for kind in ("base", "rare"):
            for x in b.get(kind, []):
                at = x.get("attributes") or {}
                rows.append([sp, kind, x["id"], x.get("min", ""), x.get("max", ""), x.get("skill", ""),
                             ";".join("%s=%s" % kv for kv in at.items())])
    write_csv(sheets / "butchering.csv", ["species", "kind", "item", "min", "max", "butcher_skill", "attributes"], rows)


# ------------------------------------------------------------------ items/traits

def gen_items(data: Path, docs: Path, sheets: Path) -> None:
    items = load(data, "items.json")["items"]
    rar = load(data, "item_rarity.json")
    foods = load(data, "foods.json").get("foods", {})

    by_cat = OrderedDict()
    for it in items:
        for cat in it.get("categories", ["uncategorised"]):
            by_cat.setdefault(cat, []).append(it)

    L = []
    a = L.append
    a("`%d items` from `game/data/items.json`; per-item consumption effects from `game/data/foods.json`; rarity palette from `game/data/item_rarity.json`." % len(items))
    a("")
    a("Rarity: %s." % ", ".join("**%s** `%s`" % (k, v) for k, v in rar.get("colors", {}).items()))
    a("")
    a("Item *traits* are the attribute keys stamped on an instance: a def's `default_attributes` (its baseline), a gather material's latent attr (the yellow pip), an inherited attribute carried through crafting, or a butcher/gather roll. The pip/stacking rules live in `game/data/inventory.json`; bag specials in `game/data/bags.json`.")
    a("")
    a("## Categories with counts")
    a("")
    a(" · ".join("**%s** (%d)" % (k, len(v)) for k, v in sorted(by_cat.items(), key=lambda t: -len(t[1]))))
    a("")
    a("## Every item")
    a("")
    a("| id | name | lvl | stack | rarity | tool class | categories | attributes |")
    a("|---|---|---|---|---|---|---|---|")
    for it in sorted(items, key=lambda t: (t.get("base_level", 0), t["id"])):
        a("| `%s` | %s | %s | %s | %s | %s | %s | %s |" % (
            it["id"], it.get("display_name", ""), it.get("base_level", ""), it.get("stack_max", ""),
            it.get("rarity", ""), it.get("tool_class", ""),
            " · ".join(it.get("categories", [])), attrs(it.get("default_attributes", {}))))
    a("")
    a("## Food effects (FOODFX)")
    a("")
    a("Channels name what an item does; every number carries its `provenance` (`extracted-client` = the Durango:0 reconstruction, `restoration-evaluated` = evaluated but unverified, `new-design` = this build's own placeholder).")
    a("")
    a("| item | provenance | channels | energy | digest (s) | thirst | fullness | eat (s) | taste |")
    a("|---|---|---|---|---|---|---|---|---|")
    for fid, f in sorted(foods.items()):
        en = f.get("energy") or {}
        a("| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            fid, f.get("provenance", ""), " · ".join(str(x) for x in f.get("channels", [])),
            energy_cell(f), en.get("digest_seconds", ""), f.get("thirst", ""), f.get("fullness", ""),
            f.get("eat_seconds", ""), f.get("taste_score", "")))
    a("")
    a("## Per-food flavour, status & assumption notes")
    a("")
    for fid, f in sorted(foods.items()):
        parts = []
        if f.get("flavors"):
            parts.append("flavors %s" % attrs(f["flavors"]))
        if f.get("statuses"):
            parts.append("statuses %s" % attrs(f["statuses"]))
        if f.get("raw_risk"):
            parts.append("raw risk %s" % f["raw_risk"])
        if f.get("temperature"):
            parts.append("temperature %s" % f["temperature"]
                         + (" Lv%s" % f["temperature_level"] if f.get("temperature_level") else ""))
        for k in ("health", "fatigue"):
            if f.get(k):
                parts.append("%s %s" % (k, f[k]))
        if f.get("risk_status") or f.get("risk_level"):
            parts.append("raw-bite status %s Lv%s" % (f.get("risk_status", "stomachache"), f.get("risk_level", 1)))
        if f.get("catalog"):
            c = f["catalog"]
            parts.append("catalog `%s` %s (L60: %s + %s Energy, fullness %s%s%s)" % (
                c["game_id"], c["name"], c["instant_energy"], c["digestion_energy"], c["fullness"],
                ", " + c["buff"] if c.get("buff") else "", ", " + c["other"] if c.get("other") else ""))
        a("- **%s** — %s" % (f.get("display_name", fid), " — ".join(parts)))
        note = f.get("assumption", "")
        if note:
            a("  > *assumption:* %s" % note)
    a("")
    write_md(L, docs / "items-traits.md", "Items & traits — the full catalog")

    write_csv(sheets / "items.csv",
              ["id", "display_name", "categories", "stack_max", "tool_class", "base_level", "rarity", "market_category", "attributes",
               "food_energy"],
              [[i["id"], i.get("display_name", ""), ";".join(i.get("categories", [])), i.get("stack_max", ""),
                i.get("tool_class", ""), i.get("base_level", ""), i.get("rarity", ""), i.get("market_category", ""),
                ";".join("%s=%s" % kv for kv in (i.get("default_attributes") or {}).items()),
                i.get("food_energy", "")] for i in items])
    write_csv(sheets / "foods.csv",
              ["id", "display_name", "provenance", "channels", "energy_instant_release_ratio", "digest_seconds",
               "thirst", "fullness", "eat_seconds", "taste_score", "buffs", "statuses",
               "health", "fatigue", "temperature", "temperature_level", "risk_status", "risk_level"],
              [[fid, f.get("display_name", ""), f.get("provenance", ""), ";".join(str(x) for x in f.get("channels", [])),
                (f.get("energy") or {}).get("instant_release_ratio", ""), (f.get("energy") or {}).get("digest_seconds", ""),
                f.get("thirst", ""), f.get("fullness", ""), f.get("eat_seconds", ""), f.get("taste_score", ""),
                dict_cell(f.get("buffs")), dict_cell(f.get("statuses")),
                f.get("health", ""), f.get("fatigue", ""), f.get("temperature", ""), f.get("temperature_level", ""),
                f.get("risk_status", ""), f.get("risk_level", "")] for fid, f in sorted(foods.items())])


# ------------------------------------------------------------------ sheets notes

def write_sheet_notes(sheets: Path, names) -> None:
    (sheets / "NOTES.md").write_text(
        "# Editable game-data sheets — how to change the build\n\n"
        "These CSVs are **generated from** `game/data/*.json` (generator: `tools/docs_wiki/gen_game_data.py`).\n"
        "They are yours to edit — Numbers, Excel or Google Sheets all open them plain. So a sync can apply\n"
        "them safely:\n\n"
        "- **First column is the key** (`id`/`species`/`station`/...) — never rename a key of an existing\n"
        "  row; deleting a KEY row means \"remove this record\", and the sync will ask before doing it.\n"
        "- Numbers, booleans (`true`/`false`) are edited in place. List cells are `;`-joined values.\n"
        "- Keep the header row untouched. A **new row at the bottom** means \"new record\", validated\n"
        "  against real game ids before anything applies.\n"
        "- After a tuning pass, tell the agent to **sync sheets back**: it rewrites only changed values,\n"
        "  prints a diff of every applied cell, and the game's data tests run before it is called done.\n\n"
        "| Sheet | Syncs into | What it tunes |\n|---|---|---|\n"
        + "\n".join("| %s.csv | `%s` | %s |" % (n.csv_name, n.target, n.tune) for n in names)
        + "\n")


class SheetDoc:
    def __init__(self, csv_name, target, tune):
        self.csv_name = csv_name
        self.target = target
        self.tune = tune


def main() -> None:
    here = Path(__file__).resolve().parent.parent.parent  # this repo's root
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=str(here / "game/data"))
    ap.add_argument("--docs", default=str(here / "docs/current"))
    ap.add_argument("--sheets", default=str(here / "game/data_sheets"))
    ap.add_argument("--force-sheets", action="store_true",
                    help="replace differing sheets and notes, discarding unsynced edits")
    args = ap.parse_args()
    data, docs, sheets = Path(args.data), Path(args.docs), Path(args.sheets)

    # Stage every output before touching the destinations: even docs must not be
    # refreshed if a sheet conflict prevents completing the same generation.
    with tempfile.TemporaryDirectory(prefix="wildlands-docs-") as tmp:
        staged_docs, staged_sheets = Path(tmp) / "docs", Path(tmp) / "sheets"
        staged_docs.mkdir()
        staged_sheets.mkdir()
        gen_items(data, staged_docs, staged_sheets)
        gen_recipes(data, staged_docs, staged_sheets)
        gen_biomes(data, staged_docs, staged_sheets)
        write_sheet_notes(staged_sheets, [
            SheetDoc("recipes", "data/recipes.json", "craft inputs/outputs, times, gates"),
            SheetDoc("repairs", "data/recipes.json ·repairs", "per-tier repair cost/restore"),
            SheetDoc("processing", "data/processing.json", "station labels, slots, real convergence times"),
            SheetDoc("items", "data/items.json", "stack sizes, levels, rarity, default attributes"),
            SheetDoc("foods", "data/foods.json", "FOODFX channels/effects per consumable"),
            SheetDoc("islands", "data/islands/*.json", "island roster, tiers, lifetimes"),
            SheetDoc("climates", "data/world/climates.json", "tiers, resists, flora families, materials"),
            SheetDoc("creatures", "data/creatures/*.json", "species tier/climate rows"),
            SheetDoc("butchering", "data/butchering.json", "kill drops per species"),
        ])
        conflicts = [p.name for p in sorted(staged_sheets.iterdir())
                     if (sheets / p.name).exists()
                     and (sheets / p.name).read_bytes() != p.read_bytes()]
        if conflicts and not args.force_sheets:
            ap.exit(1, "Refusing to overwrite differing sheets or notes: %s\n"
                    "No outputs were written. Review and sync edits first, or use "
                    "--force-sheets to discard them explicitly.\n" % ", ".join(conflicts))

        for source_dir, dest_dir in ((staged_docs, docs), (staged_sheets, sheets)):
            dest_dir.mkdir(parents=True, exist_ok=True)
            for source in source_dir.iterdir():
                destination = dest_dir / source.name
                # Existing sheets and notes passed preflight; leave them alone so an edit
                # made after that check is not overwritten by a redundant copy.
                if source_dir == staged_sheets and destination.exists() and not args.force_sheets:
                    continue
                shutil.copyfile(source, destination)
        print("wrote docs/current/{items-traits,recipes,world-biomes}.md and %d sheets"
              % len(list(staged_sheets.glob("*.csv"))))


if __name__ == "__main__":
    main()
