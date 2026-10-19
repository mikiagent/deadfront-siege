"""DEADFRONT audio build. Renders every shipped .ogg, then writes events.json, creature_voices.json,
credits.json, CREDITS.md and a LUFS/size report. Re-runs skip unchanged files.
Usage: AUDIO_DL=<downloads> AUDIO_TMP=<scratch> python3 -I tools/audio/build_audio.py game
Downloads are not in git: fetch each source listed in game/data/audio/credits.json into its own
dir under AUDIO_DL (layout in srcs.py). Needs Homebrew ffmpeg and libsndfile (ffmpeg here has no
libvorbis, so oggenc.py encodes through libsndfile). Run Python with -I: it reads untrusted files.
"""
import collections, concurrent.futures as cf, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render as R
import srcs
from render import L, C

GAME = sys.argv[1] if len(sys.argv) > 1 else "."
ROOT = os.path.join(GAME, "assets", "audio")
JOBS = []          # (rel, kind, args, kwargs, category)
EVENTS = collections.OrderedDict()
SOURCES = {}       # rel -> [source keys]


def _keys(layers):
    return sorted(set(l["key"] for l in layers))


def one(rel, layers, lufs, cat, **kw):
    JOBS.append((rel, "one", layers, lufs, kw, cat))
    SOURCES[rel] = _keys(layers)
    return rel


def loop(rel, layers, lufs, length, cat, **kw):
    JOBS.append((rel, "loop", layers, lufs, dict(kw, length=length), cat))
    SOURCES[rel] = _keys(layers)
    return rel


def ev(name, files, bus, mode="3d", vol=0.0, pitch=(0.96, 1.04), maxi=4, cd=0.0, prio=50, unit=8.0, maxd=40.0, loop_=False, **extra):
    e = {"files": list(files), "bus": bus, "mode": mode, "volume_db": vol, "pitch": list(pitch),
         "max_instances": maxi, "cooldown": cd, "priority": prio}
    if mode == "3d":
        e["unit_size"] = unit
        e["max_distance"] = maxd
    if loop_:
        e["loop"] = True
    e.update(extra)
    EVENTS[name] = e


HP = "highpass=f=90"

# ------------------------------------------------------------------ UI (2D, UI bus)
def ui():
    f = [one("ui/click_%02d.ogg" % (i + 1), [L(k, af=HP)], -26, "ui") for i, k in enumerate(["k:ui-audio/click1.ogg", "k:ui-audio/click3.ogg", "k:ui-audio/click2.ogg", "k:interface-sounds/click_001.ogg"])]
    ev("ui_click", f, "UI", "2d", maxi=2, cd=0.03, prio=90)
    f = [one("ui/confirm_%02d.ogg" % i, [L("k:interface-sounds/confirmation_00%d.ogg" % i, af=HP)], -23, "ui") for i in (1, 2)]
    ev("ui_confirm", f, "UI", "2d", maxi=2, cd=0.05, prio=90)
    f = [one("ui/cancel_%02d.ogg" % i, [L("k:interface-sounds/back_00%d.ogg" % i, af=HP)], -23, "ui") for i in (1, 2)]
    ev("ui_cancel", f, "UI", "2d", maxi=2, cd=0.05, prio=90)
    f = [one("ui/panel_open_%02d.ogg" % i, [L("k:interface-sounds/open_00%d.ogg" % i, af=HP), L("k:rpg-audio/cloth%d.ogg" % i, gain=-9)], -23, "ui") for i in (1, 2)]
    ev("ui_panel_open", f, "UI", "2d", maxi=1, cd=0.12, prio=85)
    f = [one("ui/panel_close_%02d.ogg" % i, [L("k:interface-sounds/close_00%d.ogg" % i, af=HP), L("k:rpg-audio/cloth%d.ogg" % (i + 2), gain=-10)], -24, "ui") for i in (1, 2)]
    ev("ui_panel_close", f, "UI", "2d", maxi=1, cd=0.12, prio=85)
    f = [one("ui/error_%02d.ogg" % i, [L("k:interface-sounds/error_00%d.ogg" % n, af=HP)], -23, "ui") for i, n in ((1, 2), (2, 6))]
    ev("ui_error", f, "UI", "2d", maxi=1, cd=0.35, prio=88)
    f = [one("ui/notice_%02d.ogg" % i, [L("k:interface-sounds/pluck_00%d.ogg" % i, af=HP)], -27, "ui") for i in (1, 2)]
    ev("ui_notice", f, "UI", "2d", maxi=1, cd=0.25, prio=60)
    f = [one("ui/level_up_%02d.ogg" % i, [L("k:music-jingles/Pizzicato jingles/jingles_PIZZI%02d.ogg" % n)], -19, "ui", max_len=3.0, fade=0.4) for i, n in ((1, 3), (2, 10))]
    ev("ui_level_up", f, "UI", "2d", pitch=(1.0, 1.0), maxi=1, cd=1.0, prio=95)
    f = [one("ui/pickup_%02d.ogg" % i, [L(k, af=HP)], -25, "ui") for i, k in enumerate(["k:rpg-audio/handleSmallLeather.ogg", "k:rpg-audio/handleSmallLeather2.ogg", "k:rpg-audio/cloth4.ogg"], 1)]
    ev("ui_item_pickup", f, "UI", "2d", maxi=2, cd=0.2, prio=70)
    f = [one("ui/coin_%02d.ogg" % i, [L(k)], -23, "ui") for i, k in enumerate(["k:rpg-audio/handleCoins.ogg", "k:rpg-audio/handleCoins2.ogg"], 1)]
    ev("ui_coin", f, "UI", "2d", maxi=1, cd=0.2, prio=80)
    f = [one("ui/tstone_%02d.ogg" % i, [L("k:casino-audio/chips-collide-%d.ogg" % i, rate=0.82, af="lowpass=f=6000")], -23, "ui") for i in (1, 2, 3)]
    ev("ui_tstone", f, "UI", "2d", maxi=1, cd=0.2, prio=80)
    f = [one("ui/craft_done_%02d.ogg" % i, [L("k:impact-sounds/impactWood_medium_00%d.ogg" % i), L("k:interface-sounds/confirmation_00%d.ogg" % (i + 2), delay=0.07, gain=-5)], -21, "ui") for i in (1, 2)]
    ev("ui_craft_complete", f, "UI", "2d", maxi=1, cd=0.3, prio=85)


# ------------------------------------------------------------------ survivor
def survivor():
    step = dict(unit=6.0, maxd=28.0, pitch=(0.92, 1.08), maxi=3, cd=0.09, prio=40, vol=-1.0)
    def kb(prefix, n, lufs, extra=None):
        return [one("survivor/%s_%02d.ogg" % (prefix, i + 1), [L(k, af="highpass=f=70")], lufs, "footsteps", max_len=0.6, fade=0.08) for i, k in enumerate(n)] + (extra or [])
    sand = kb("step_sand", ["oga:oga-fantozzi-footsteps/x/Fantozzi-footsteps/ogg/Fantozzi-Sand%s.ogg" % s for s in ("L1", "L2", "L3", "R1", "R2", "R3")], -28)
    stone = kb("step_stone", ["oga:oga-fantozzi-footsteps/x/Fantozzi-footsteps/ogg/Fantozzi-Stone%s.ogg" % s for s in ("L1", "L2", "L3", "R1", "R2", "R3")], -28)
    dirt = kb("step_dirt", ["k:impact-sounds/footstep_grass_00%d.ogg" % i for i in range(5)], -28,
              [one("survivor/step_dirt_06.ogg", [C("bsb:1253", 6, af="highpass=f=70", lo=0.08, hi=0.6)], -28, "footsteps", max_len=0.6, fade=0.08)])
    wood = kb("step_wood", ["k:impact-sounds/footstep_wood_00%d.ogg" % i for i in range(5)], -28,
              [one("survivor/step_wood_06.ogg", [C("bsb:1516", 3, af="highpass=f=70", lo=0.08, hi=0.6)], -28, "footsteps", max_len=0.6, fade=0.08)])
    snow = kb("step_snow", ["k:impact-sounds/footstep_snow_00%d.ogg" % i for i in range(5)], -28,
              [one("survivor/step_snow_06.ogg", [C("bsb:3363", 4, af="highpass=f=70", lo=0.08, hi=0.6)], -28, "footsteps", max_len=0.6, fade=0.08)])
    water = [one("survivor/step_water_%02d.ogg" % (i + 1), [C("bsb:0690", i, af="highpass=f=80", lo=0.08, hi=0.6)], -27, "footsteps", max_len=0.6, fade=0.1) for i in range(6)]
    mud = [one("survivor/step_mud_%02d.ogg" % (i + 1), [C("bsb:0495", i, af="highpass=f=70", lo=0.08, hi=0.6)], -28, "footsteps", max_len=0.6, fade=0.1) for i in range(6)]
    for name, f in (("sand", sand), ("stone", stone), ("dirt", dirt), ("wood", wood), ("snow", snow), ("water", water), ("mud", mud)):
        ev("step_" + name, f, "SFX", **step)
    v = dict(unit=8.0, maxd=35.0, maxi=1, prio=80)
    f = [one("survivor/roll_%02d.ogg" % i, [L("k:rpg-audio/cloth%d.ogg" % i), L("bsb:%s" % b, delay=0.32, gain=-3, t=0.6)], -22, "survivor", max_len=1.1) for i, b in ((1, "1839"), (2, "1840"), (3, "1837"))]
    ev("survivor_roll", f, "SFX", cd=0.3, **v)
    f = [one("survivor/hurt_%02d.ogg" % (i + 1), [L("oga:oga-pain-sounds-emopreben/x/%s" % n, af=HP)], -20, "survivor", max_len=1.1, fade=0.15)
         for i, n in enumerate(["Painsounds v2 - Track 1 - Arrrch.ogg", "Painsounds v2 - Track 2 - Hurgh.ogg", "Painsounds v2 - Track 3 - Huuurh.ogg",
                                "Painsounds v2 - Track 4 - Arrggh .ogg", "Painsounds v2 - Track 5 - Urggh.ogg", "Painsounds v2 - Track 6 - hyyrdhh.ogg"])]
    ev("survivor_hurt", f, "SFX", cd=0.45, pitch=(0.97, 1.03), **v)
    f = [one("survivor/death_%02d.ogg" % (i + 1), [C("oga:oga-grunts-male-death-and-pain/death pain grunts.wav", i, af=HP, rel=20, lo=0.6, hi=2.6)], -19, "survivor", max_len=2.6, fade=0.4) for i in range(3)]
    ev("survivor_death", f, "SFX", cd=2.0, pitch=(1.0, 1.0), **v)
    f = [one("survivor/effort_%02d.ogg" % (i + 1), [L("oga:oga-15-vocal-male/x/slightscream-%02d.flac" % n, af=HP)], -23, "survivor", max_len=0.8, fade=0.1) for i, n in enumerate((2, 5, 8, 11))]
    ev("survivor_effort", f, "SFX", cd=0.6, **v)
    f = [one("survivor/eat_%02d.ogg" % (i + 1), [C(k, n, af=HP, lo=0.15, hi=1.2)], -22, "survivor", max_len=1.2, fade=0.1) for i, (k, n) in enumerate((("bsb:1113", 0), ("bsb:1114", 0), ("bsb:3081", 0), ("bsb:1114", 1)))]
    ev("survivor_eat", f, "SFX", cd=0.5, **v)
    f = [one("survivor/drink_%02d.ogg" % (i + 1), [C("bsb:%s" % k, 0, af=HP, lo=0.4, hi=1.8)], -22, "survivor", max_len=1.8, fade=0.2) for i, k in enumerate(("3247", "3248", "3249"))]
    ev("survivor_drink", f, "SFX", cd=0.8, **v)
    f = [one("survivor/sleep_%02d.ogg" % i, [L("bsb:%s" % k, af=HP)], -24, "survivor", max_len=3.5, fade=0.6) for i, k in ((1, "1406"), (2, "1407"))]
    ev("survivor_sleep", f, "SFX", cd=2.0, pitch=(0.98, 1.02), **v)
    f = [one("survivor/wake_%02d.ogg" % (i + 1), [C("bsb:1404", i, af=HP, lo=0.4, hi=2.0)], -24, "survivor", max_len=2.0, fade=0.3) for i in range(2)]
    ev("survivor_wake", f, "SFX", cd=2.0, **v)


# ------------------------------------------------------------------ gathering
def gather():
    g = dict(unit=8.0, maxd=35.0, maxi=3, cd=0.14, prio=60)
    f = [one("gather/chop_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactWood_heavy_00%d.ogg" % i), L("k:rpg-audio/chop.ogg", gain=-8, rate=1.0 + 0.04 * i)], -19, "gathering", max_len=0.9, fade=0.1) for i in range(5)]
    ev("gather_chop", f, "SFX", **g)
    f = [one("gather/mine_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactMining_00%d.ogg" % i)], -19, "gathering", max_len=0.9, fade=0.1) for i in range(5)]
    ev("gather_mine", f, "SFX", **g)
    twigs = [("bsb:1301", 0), ("bsb:1301", 3), ("bsb:1301", 6), ("bsb:1299", 2)]
    f = [one("gather/pick_%02d.ogg" % (i + 1), [C(k, n, lo=0.1, hi=0.6), C("bsb:2889", i, gain=-5, maxt=0.8, lo=0.3, hi=1.2)], -22, "gathering", max_len=0.9, fade=0.15) for i, (k, n) in enumerate(twigs)]
    ev("gather_pick", f, "SFX", **g)
    f = [one("gather/dig_%02d.ogg" % (i + 1), [C("bsb:1305", i, lo=0.12, hi=0.8), L("oga:oga-mud/x/mud_%02d.ogg" % (i * 3 + 2), gain=-8)], -21, "gathering", max_len=0.9, fade=0.12) for i in range(4)]
    ev("gather_dig", f, "SFX", **g)
    f = [one("gather/butcher_%02d.ogg" % (i + 1), [C("oga:oga-ripping-meat/rippingintomeat_0.mp3", i, lo=0.3, hi=1.2), C("bsb:0334", 0, gain=-8, rate=1.0 + 0.05 * i)], -21, "gathering", max_len=1.1, fade=0.15) for i in range(4)]
    ev("gather_butcher", f, "SFX", **g)
    f = [one("gather/craft_%02d.ogg" % (i + 1), [L(k)], -22, "gathering", max_len=0.7, fade=0.08) for i, k in enumerate(["k:impact-sounds/impactPlank_medium_000.ogg", "k:impact-sounds/impactPlank_medium_002.ogg", "k:impact-sounds/impactWood_light_001.ogg", "k:impact-sounds/impactWood_light_003.ogg"])]
    ev("gather_craft", f, "SFX", **g)
    f = [one("gather/depleted_tree_%02d.ogg" % i, [L("k:rpg-audio/creak%d.ogg" % i, rate=0.85), L("k:impact-sounds/impactWood_heavy_00%d.ogg" % (i + 2), rate=0.6, delay=0.55), C("bsb:1300", 0, delay=0.5, gain=-6, lo=0.1, hi=0.5)], -18, "gathering", max_len=2.4, fade=0.4) for i in (1, 2)]
    ev("node_depleted_tree", f, "SFX", unit=10.0, maxd=45.0, maxi=2, cd=0.4, prio=65)
    f = [one("gather/depleted_rock_%02d.ogg" % (i + 1), [C("bsb:1022", i, lo=0.4, hi=1.8), L("k:impact-sounds/impactMining_00%d.ogg" % i, rate=0.7, gain=-4)], -19, "gathering", max_len=1.8, fade=0.3) for i in range(2)]
    ev("node_depleted_rock", f, "SFX", unit=10.0, maxd=45.0, maxi=2, cd=0.4, prio=65)
    f = [one("gather/depleted_bush_%02d.ogg" % (i + 1), [C("bsb:1301", 8 + i, lo=0.1, hi=0.6), C("bsb:0137", i, gain=-3, maxt=1.0, lo=0.4, hi=1.4)], -22, "gathering", post=["acompressor=threshold=-24dB:ratio=4:attack=2:release=100:makeup=3"], max_len=1.2, fade=0.25) for i in range(2)]
    ev("node_depleted_bush", f, "SFX", unit=8.0, maxd=35.0, maxi=2, cd=0.4, prio=55)


# ------------------------------------------------------------------ combat
def combat():
    c = dict(unit=8.0, maxd=40.0, maxi=4, cd=0.03, prio=70)
    f = [one("combat/swing_light_%02d.ogg" % i, [L("oga:oga-swishes/x/swishes/swish-%d.wav" % i, af=HP)], -22, "combat", max_len=0.6, fade=0.08) for i in range(1, 7)]
    ev("swing_light", f, "SFX", pitch=(0.92, 1.08), **c)
    f = [one("combat/swing_heavy_%02d.ogg" % (i + 1), [L("bsb:%s" % k, rate=0.8, af="lowpass=f=3500")], -20, "combat", max_len=0.9, fade=0.1) for i, k in enumerate(("1795", "1796", "1800", "1801"))]
    ev("swing_heavy", f, "SFX", **c)
    f = [one("combat/flesh_small_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactPunch_medium_00%d.ogg" % i)], -20, "combat", max_len=0.5) for i in range(4)]
    ev("impact_flesh_small", f, "SFX", **c)
    f = [one("combat/flesh_medium_%02d.ogg" % (i + 1), [L("bsb:%d" % (2459 + i))], -19, "combat", post=["acompressor=threshold=-20dB:ratio=4:attack=1:release=80:makeup=2"], max_len=0.35, fade=0.06) for i in range(5)]
    ev("impact_flesh_medium", f, "SFX", **c)
    f = [one("combat/hide_large_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactPunch_heavy_00%d.ogg" % i), L("k:impact-sounds/impactSoft_heavy_00%d.ogg" % i, gain=-4, rate=0.8)], -18, "combat", max_len=0.7) for i in range(4)]
    ev("impact_hide_large", f, "SFX", unit=10.0, maxd=50.0, maxi=4, cd=0.03, prio=72)
    f = [one("combat/hide_huge_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactSoft_heavy_00%d.ogg" % i, rate=0.6), L("k:impact-sounds/impactPunch_heavy_00%d.ogg" % (3 - i), rate=0.7, gain=-3)], -17, "combat", post=["asubboost"], max_len=0.9) for i in range(4)]
    ev("impact_hide_huge", f, "SFX", unit=12.0, maxd=60.0, maxi=4, cd=0.03, prio=74)
    f = [one("combat/bone_%02d.ogg" % i, [L("oga:oga-deep-breaks/x/Deep Break %d.wav" % i)], -20, "combat", max_len=0.8, fade=0.1) for i in range(1, 6)]
    ev("impact_bone", f, "SFX", **c)
    f = [one("combat/crit_%02d.ogg" % i, [L("oga:oga-wet-breaks/x/Wet Break %d.wav" % i), L("k:impact-sounds/impactPunch_heavy_00%d.ogg" % (i - 1), gain=-3)], -17, "combat", max_len=0.8, fade=0.1) for i in range(1, 5)]
    ev("impact_crit", f, "SFX", **dict(c, prio=78))
    f = [one("combat/armour_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactWood_light_00%d.ogg" % i), L("k:rpg-audio/dropLeather.ogg", gain=-6)], -21, "combat", max_len=0.5) for i in range(4)]
    ev("armour_hit", f, "SFX", **c)
    f = [one("combat/stone_release_%02d.ogg" % (i + 1), [L("bsb:0549", rate=1.25 + 0.1 * i, af="highpass=f=200"), L("bsb:1798", gain=-6, delay=0.04)], -22, "combat", max_len=0.6) for i in range(2)]
    ev("proj_stone_release", f, "SFX", **c)
    f = [one("combat/stone_hit_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactGeneric_light_00%d.ogg" % i)], -21, "combat", max_len=0.5) for i in range(4)]
    ev("proj_stone_hit", f, "SFX", **c)
    f = [one("combat/arrow_release_%02d.ogg" % (i + 1), [L("bsb:0549", rate=1.0 + 0.06 * i), L("bsb:1799", gain=-8, delay=0.03)], -21, "combat", max_len=0.8) for i in range(2)]
    ev("proj_arrow_release", f, "SFX", **c)
    f = [one("combat/arrow_hit_%02d.ogg" % (i + 1), [C("bsb:0548", i, lo=0.15, hi=0.8)], -20, "combat", max_len=0.8, fade=0.1) for i in range(3)]
    ev("proj_arrow_hit", f, "SFX", **c)
    f = [one("combat/spear_release_%02d.ogg" % (i + 1), [L("bsb:1796", rate=0.85 - 0.05 * i), L("oga:oga-swishes/x/swishes/swish-%d.wav" % (9 + i), gain=-4)], -21, "combat", max_len=0.9) for i in range(2)]
    ev("proj_spear_release", f, "SFX", **c)
    f = [one("combat/spear_hit_%02d.ogg" % (i + 1), [C("bsb:0548", i + 1, rate=0.75, lo=0.15, hi=0.8), L("k:impact-sounds/impactPunch_heavy_00%d.ogg" % (i + 2), gain=-4)], -19, "combat", max_len=0.9) for i in range(2)]
    ev("proj_spear_hit", f, "SFX", **c)
    f = [one("combat/catapult_release_%02d.ogg" % i, [L("k:rpg-audio/creak%d.ogg" % (i + 1), rate=0.7), C("bsb:0572", i, rate=0.7, delay=0.2, gain=-2, lo=0.3, hi=1.2)], -19, "combat", max_len=1.6, fade=0.2) for i in (1, 2)]
    ev("proj_catapult_release", f, "SFX", unit=10.0, maxd=55.0, maxi=2, cd=0.2, prio=70)
    f = [one("combat/catapult_hit_%02d.ogg" % (i + 1), [C("bsb:1022", i + 2, lo=0.4, hi=1.8), L("k:impact-sounds/impactSoft_heavy_00%d.ogg" % i, rate=0.6)], -17, "combat", post=["asubboost"], max_len=1.8, fade=0.3) for i in range(2)]
    ev("proj_catapult_hit", f, "SFX", unit=12.0, maxd=60.0, maxi=2, cd=0.1, prio=75)
    f = [one("combat/knockdown_%02d.ogg" % (i + 1), [L("bsb:%d" % (2452 + i))], -19, "combat", max_len=1.2, fade=0.2) for i in range(4)]
    ev("knockdown_thud", f, "SFX", **c)
    f = [one("combat/fall_small_%02d.ogg" % (i + 1), [L("bsb:%d" % (2456 - 4 * i), rate=1.15)], -21, "combat", max_len=1.0, fade=0.2) for i in range(2)]
    ev("body_fall_small", f, "SFX", unit=6.0, maxd=30.0, maxi=3, cd=0.05, prio=60)
    f = [one("combat/fall_medium_%02d.ogg" % (i + 1), [L("bsb:%d" % (2453 + i))], -19, "combat", max_len=1.4, fade=0.25) for i in range(2)]
    ev("body_fall_medium", f, "SFX", unit=8.0, maxd=40.0, maxi=3, cd=0.05, prio=65)
    f = [one("combat/fall_large_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactSoft_heavy_00%d.ogg" % i, rate=0.55), L("bsb:%d" % (2454 + i), rate=0.6, gain=-3)], -17, "combat", post=["asubboost", "lowpass=f=4000"], max_len=1.8, fade=0.4) for i in range(2)]
    ev("body_fall_large", f, "SFX", unit=12.0, maxd=60.0, maxi=2, cd=0.05, prio=70)
    f = [one("combat/fall_huge_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactSoft_heavy_00%d.ogg" % (i + 2), rate=0.4), C("bsb:1022", i, rate=0.6, gain=-4, lo=0.4, hi=1.8), L("bsb:%d" % (2455 - i), rate=0.45, gain=-2)], -15, "combat", post=["asubboost", "lowpass=f=2500"], max_len=2.8, fade=0.8) for i in range(2)]
    ev("body_fall_huge", f, "SFX", unit=18.0, maxd=110.0, maxi=2, cd=0.05, prio=80)
    f = [one("combat/step_large_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactSoft_heavy_00%d.ogg" % i, rate=0.55, af="lowpass=f=1200")], -25, "combat", max_len=0.9, fade=0.2) for i in range(3)]
    ev("creature_step_large", f, "Creatures", unit=10.0, maxd=45.0, maxi=6, cd=0.05, prio=35, pitch=(0.9, 1.1))
    f = [one("combat/step_huge_%02d.ogg" % (i + 1), [L("k:impact-sounds/impactSoft_heavy_00%d.ogg" % (i + 1), rate=0.4), L("k:impact-sounds/impactPunch_heavy_00%d.ogg" % i, rate=0.45, gain=-6)], -21, "combat", post=["asubboost", "lowpass=f=900"], max_len=1.4, fade=0.4) for i in range(3)]
    ev("creature_step_huge", f, "Creatures", unit=16.0, maxd=90.0, maxi=6, cd=0.05, prio=45, pitch=(0.92, 1.08))


# ------------------------------------------------------------------ creatures
TIGER = "c:c03"; LION = "c:c11"; ALLI2 = "c:c01"; ALLI1 = "c:c04"; ALLIE = "c:c05"; HISS = "c:c06"
ELEPH = "c:c07"; ELK = "c:c08"; GEESE = "c:c10"; LOONS = "c:c12"; RATTLE = "c:c13"; SWANS = "c:c14"
GRIZ = "c:c21"; CRANE = "c:c22"; CRANE2 = "c:c23"; TREX = "oga:oga-t-rex-calls/t-rex_calls.mp3"
RASPY = "oga:oga-small-dino-raspy/small_dino_raspy_calls.mp3"
GOR = "oga:oga-gorilla/x/ogg/gorilla_snarl_0%d.ogg"; CAMEL = "oga:oga-camel/x/ogg/camel_0%d.ogg"
MON = "oga:oga-16-monster-growls/x/monster.%d.ogg"
BIG = dict(rel=18, lo=0.7, hi=3.2)
MID = dict(rel=20, lo=0.3, hi=2.0)
SMALL = dict(rel=20, lo=0.12, hi=1.2)
KINDS = {"idle": 3, "alert": 2, "attack": 3, "hurt": 3, "death": 2}
COLOURS = {
    "neutral": [],
    "dark": ["lowshelf=g=4:f=220", "highshelf=g=-6:f=2800", "equalizer=f=650:t=q:w=1.0:g=3"],
    "bright": ["highpass=f=140", "equalizer=f=1900:t=q:w=1.2:g=4", "highshelf=g=3:f=3500"],
}


def j(rate, v, step=0.035):
    """Small per-variation rate jitter so single-call sources still yield distinct variations."""
    return rate * (1.0 + step * (v - 1))


def carn_huge(kind, v):
    big = ["lowpass=f=5200", "asubboost", "aecho=0.8:0.55:70:0.18"]
    if kind == "idle":
        return [C(ALLI2, v, rate=j(0.66, v), **BIG), C(TIGER, v + 4, rate=0.5, gain=-8, af="lowpass=f=1600", **BIG)], big, 3.6
    if kind == "alert":
        return [C(TIGER, v, rate=0.55, **BIG), C(TREX, v + 2, rate=0.8, gain=-2, rel=18, lo=0.8, hi=4.0), C(ALLI1, v + 1, rate=0.7, gain=-5, **BIG)], big, 4.6
    if kind == "attack":
        return [C(TREX, v + 4, rate=j(0.85, v), rel=18, lo=0.8, hi=2.4), C(LION, v, rate=0.56, gain=-4, maxt=1.2, **BIG), L("k:impact-sounds/impactPunch_heavy_00%d.ogg" % v, rate=0.55, gain=-8)], big, 2.6
    if kind == "hurt":
        return [C(LION, v + 1, rate=j(0.6, v), maxt=0.9, **BIG), L(HISS, 0.5 + v, 0.7, rate=0.8, gain=-9), L(GOR % (v + 1), rate=0.6, gain=-4)], big, 1.7
    return [L(ELK, 0.1, 3.0, rate=j(0.45, v)), C(ALLI2, v + 2, rate=0.55, gain=-3, **BIG), C(TIGER, v + 7, rate=0.45, gain=-6, **BIG)], big, 5.0


def carn_large(kind, v):
    big = ["lowpass=f=6500", "asubboost", "aecho=0.8:0.5:50:0.15"]
    if kind == "idle":
        return [L(GRIZ, 0.9 + v * 1.2, 1.6, rate=j(0.75, v)), C(ALLIE, v, rate=0.85, gain=-6, **BIG)], big, 2.8
    if kind == "alert":
        return [L(GRIZ, 0.9 + v * 0.6, 3.0, rate=0.78), C(TIGER, v + 2, rate=0.7, gain=-4, **BIG)], big, 3.6
    if kind == "attack":
        return [C(TIGER, v + 5, rate=j(0.76, v), maxt=1.3, **BIG), L(MON % (v + 2), rate=0.85, gain=-6)], big, 1.9
    if kind == "hurt":
        return [L(GOR % ((v % 4) + 1), rate=j(0.74, v)), C(LION, v, rate=0.8, gain=-6, maxt=0.8, **BIG)], big, 1.3
    return [L(CAMEL % (v + 1), rate=0.62), L(GRIZ, 1.0, 3.5, rate=0.65, gain=-5)], big, 4.0


def carn_medium(kind, v):
    if kind == "idle":
        return [L("bsb:%d" % (1885 + v), t=1.6, rate=j(0.86, v)), C(CRANE, v, rate=0.9, gain=-9, **MID)], [], 2.0
    if kind == "alert":
        return [C(GEESE, v + 1, rate=0.78, **MID), L("bsb:%d" % (1881 + v), rate=0.9, gain=-3), L(RATTLE, 1.0 + v, 0.6, rate=1.0, gain=-12, af="highpass=f=2000")], [], 1.7
    if kind == "attack":
        return [L("bsb:%d" % (1882 + v % 2), rate=j(0.95, v)), L(HISS, 1.0 + v, 0.5, rate=1.1, gain=-6)], [], 1.2
    if kind == "hurt":
        return [C("bsb:1040", v, rate=0.72, maxt=0.9, **SMALL), L("bsb:%d" % (1884 - v), rate=1.05, gain=-6)], [], 1.0
    return [C(CRANE2, v + 1, rate=0.7, **MID), L("bsb:%d" % (1887 + v), rate=0.8, gain=-4, t=2.4)], [], 2.6


def carn_small(kind, v):
    if kind == "idle":
        return [C("bsb:%d" % (2769 + v), 0, rate=1.15, **SMALL), C(RASPY, v, rate=1.3, gain=-6, **SMALL)], ["highpass=f=250"], 1.0
    if kind == "alert":
        return [L("bsb:1762", rate=j(1.1, v)), L("bsb:%d" % (2764 + v), rate=1.4, gain=-4)], ["highpass=f=250"], 1.0
    if kind == "attack":
        return [C(RASPY, v, rate=j(1.45, v), **SMALL), L(HISS, 1.0 + v, 0.3, rate=1.6, gain=-10)], ["highpass=f=250"], 0.7
    if kind == "hurt":
        return [C("bsb:0453", v, rate=1.25, maxt=0.6, **SMALL), C(RASPY, v + 1, rate=1.6, gain=-8, **SMALL)], ["highpass=f=250"], 0.6
    return [C("bsb:2771", v, rate=0.95, **SMALL), C(RASPY, v, rate=1.1, gain=-6, **SMALL)], ["highpass=f=200"], 1.4


def herb_small(kind, v):
    if kind == "idle":
        return [C("bsb:%d" % (1658 + v % 2), v, rate=j(0.95, v), **SMALL), L("bsb:%04d" % (285 + v), rate=0.9, gain=-6)], [], 1.5
    if kind == "alert":
        return [L("bsb:0279", rate=j(0.8, v)), C("bsb:1550", v, rate=1.2, gain=-8, **MID)], [], 1.5
    if kind == "attack":
        return [C("bsb:1659", v + 2, rate=j(0.8, v), **SMALL), L("bsb:1543", rate=0.8, gain=-3)], [], 1.0
    if kind == "hurt":
        return [L("bsb:0279", t=0.8, rate=j(0.95, v, 0.06)), C("bsb:1659", v, rate=1.1, gain=-6, **SMALL)], [], 0.9
    return [C("bsb:1549", v, rate=0.85, **MID), C("bsb:1658", v, rate=0.8, gain=-6, **SMALL)], [], 2.0


def herb_medium(kind, v):
    if kind == "idle":
        return [C(GEESE, v + 3, rate=j(0.92, v), **MID), L(SWANS, 0.5 + v, 1.2, rate=0.9, gain=-6)], [], 1.6
    if kind == "alert":
        return [C(CRANE, v + 2, rate=0.88, **MID), C(GEESE, v, rate=0.85, gain=-4, **MID)], [], 1.7
    if kind == "attack":
        return [C(GEESE, v + 5, rate=j(0.78, v), **MID), L(HISS, 2.0 + v, 0.5, rate=1.2, gain=-9)], [], 1.1
    if kind == "hurt":
        return [C(CRANE2, v, rate=1.0, maxt=0.8, **MID), C("bsb:1040", v + 1, rate=0.9, gain=-6, **SMALL)], [], 0.9
    return [L(SWANS, 1.0 + v * 2, 2.5, rate=0.7), C(CRANE, v + 4, rate=0.7, gain=-4, **MID)], [], 2.6


def herb_large(kind, v):
    big = ["lowpass=f=6000", "asubboost"]
    if kind == "idle":
        return [L("bsb:%d" % (2382 + v), rate=j(0.72, v)), L(ELK, 0.1, 1.5, rate=0.7, gain=-8)], big, 3.0
    if kind == "alert":
        return [L(ELK, 0.1, 2.0, rate=j(0.62, v)), C("bsb:1548", v, rate=0.62, gain=-6, **MID), L(CAMEL % 1, rate=0.7, gain=-6)], big, 3.0
    if kind == "attack":
        return [L(CAMEL % (v % 2 + 1), t=1.2, rate=j(0.72, v)), L("bsb:0286", rate=0.6, gain=-2)], big, 1.6
    if kind == "hurt":
        return [C("bsb:1551", v, rate=0.78, maxt=1.0, **MID), L("bsb:2385", t=1.0, rate=0.85, gain=-6)], big, 1.2
    return [C("bsb:0845", v, rate=0.55, **BIG), L(CAMEL % 2, rate=0.6, gain=-5)], big, 4.0


def herb_huge(kind, v):
    big = ["lowpass=f=3200", "asubboost", "aecho=0.8:0.6:90:0.2"]
    if kind == "idle":
        return [L(ELEPH, 0.15, rate=j(0.5, v)), L("bsb:%d" % (2383 + v), rate=0.5, gain=-4), C(LOONS, v, rate=0.5, gain=-8, **MID)], big, 4.0
    if kind == "alert":
        return [L(ELEPH, 0.15, rate=j(0.45, v)), C(ALLI1, v, rate=0.6, gain=-4, **BIG)], big, 4.2
    if kind == "attack":
        return [L(CAMEL % (v % 2 + 1), rate=j(0.5, v)), L(ELEPH, 0.15, rate=0.42, gain=-3)], big, 3.0
    if kind == "hurt":
        return [L("bsb:2384", t=1.2, rate=j(0.55, v)), L(ELEPH, 0.15, rate=0.55, gain=-4)], big, 2.0
    return [C("bsb:0845", v + 2, rate=0.4, **BIG), L(ELEPH, 0.15, rate=0.38, gain=-3), C(ALLI2, v, rate=0.5, gain=-6, **BIG)], big, 5.5


def mammal_cat(kind, v):
    if kind == "idle":
        return [L("bsb:%d" % (1886 + v % 3), t=2.2, rate=j(0.78, v)), C(TIGER, v + 1, rate=0.9, gain=-10, **BIG)], ["lowpass=f=7000"], 2.5
    if kind == "alert":
        return [L("bsb:%d" % (1881 + v), rate=0.72), C(TIGER, v, rate=0.88, gain=-4, **BIG)], ["lowpass=f=7000"], 2.2
    if kind == "attack":
        return [L("bsb:1883", rate=j(0.78, v)), C("bsb:0817", v, rate=0.85, gain=-6, **MID)], [], 1.2
    if kind == "hurt":
        return [L("bsb:1884", t=0.8, rate=j(0.85, v)), C("bsb:0817", v + 2, rate=0.9, gain=-6, **MID)], [], 1.0
    return [C("bsb:1626", v, rate=0.8, **MID), L("bsb:1888", t=2.5, rate=0.7, gain=-6)], [], 2.6


def mammal_deer(kind, v):
    if kind == "idle":
        return [L(ELK, 0.1, 2.0, rate=j(0.98, v)), L("bsb:0287", rate=0.95, gain=-8)], [], 2.5
    if kind == "alert":
        return [L(ELK, 0.1, 1.5, rate=j(0.9, v)), L("bsb:0284", rate=0.72, gain=-6)], [], 2.0
    if kind == "attack":
        return [L("bsb:1543", rate=j(0.8, v)), L(ELK, 0.4, 0.6, rate=1.05, gain=-6)], [], 1.0
    if kind == "hurt":
        return [L("bsb:0460", t=1.0, rate=j(0.78, v)), L("bsb:0279", rate=0.62, gain=-6)], [], 1.1
    return [L(ELK, 0.1, 3.0, rate=0.72), C("bsb:0859", v, rate=0.65, gain=-6, **MID)], [], 3.0


SETS = {
    "carn_small": (carn_small, "small", "carnivore"), "carn_medium": (carn_medium, "medium", "carnivore"),
    "carn_large": (carn_large, "large", "carnivore"), "carn_huge": (carn_huge, "huge", "carnivore"),
    "herb_small": (herb_small, "small", "herbivore"), "herb_medium": (herb_medium, "medium", "herbivore"),
    "herb_large": (herb_large, "large", "herbivore"), "herb_huge": (herb_huge, "huge", "herbivore"),
    "mammal_cat": (mammal_cat, "medium", "carnivore"), "mammal_deer": (mammal_deer, "medium", "herbivore"),
}
SIZE_PARAMS = {  # loudness, attenuation and priority by body size
    "small": dict(lufs=-21, unit=5.0, maxd=32.0, prio=45),
    "medium": dict(lufs=-19, unit=8.0, maxd=48.0, prio=55),
    "large": dict(lufs=-17, unit=12.0, maxd=75.0, prio=65),
    "huge": dict(lufs=-16, unit=18.0, maxd=120.0, prio=75),
}
# ASSUMPTION: species pitch/colour picks are by ear-less judgement from size and build; owner should tune by listening.
SPECIES = {
    "compsognathus": ("carn_small", "bright", 1.35), "coelophysis": ("carn_small", "neutral", 1.0),
    "velociraptor": ("carn_medium", "neutral", 1.1), "deinonychus": ("carn_medium", "dark", 1.0),
    "utahraptor": ("carn_medium", "dark", 0.82), "dilophosaurus": ("carn_medium", "bright", 1.0),
    "allosaurus": ("carn_large", "neutral", 1.0), "tyrannosaurus": ("carn_huge", "dark", 0.88),
    "tarbosaurus": ("carn_huge", "neutral", 1.02), "smilodon": ("mammal_cat", "neutral", 1.0),
    "protoceratops": ("herb_small", "neutral", 1.0), "zebraceratops": ("herb_small", "bright", 1.15),
    "gallimimus": ("herb_medium", "neutral", 1.0), "megaloceros": ("mammal_deer", "neutral", 1.0),
    "triceratops": ("herb_large", "neutral", 0.95), "stegosaurus": ("herb_large", "bright", 1.05),
    "ankylosaurus": ("herb_large", "dark", 0.9), "styracosaurus": ("herb_large", "bright", 1.15),
    "brachiosaurus": ("herb_huge", "neutral", 1.0),
}


def creatures():
    used = collections.defaultdict(set)
    for sp, (s, col, _) in SPECIES.items():
        used[s].add(col)
    for s, (fn, size, diet) in SETS.items():
        sp = SIZE_PARAMS[size]
        for col in sorted(used[s]):
            for kind, n in KINDS.items():
                files = []
                for v in range(n):
                    layers, post, mx = fn(kind, v)
                    fade = 0.9 if kind == "death" else (0.25 if mx > 1.5 else 0.12)
                    lufs = sp["lufs"] - (2 if kind == "idle" else 0) + (1 if kind in ("alert", "death") else 0)
                    files.append(one("creatures/%s/%s_%s_%02d.ogg" % (s, col, kind, v + 1), layers, lufs, "creatures_" + size,
                                     post=post + COLOURS[col], max_len=mx, fade=fade))
                ev("cv_%s_%s_%s" % (s, col, kind), files, "Creatures", unit=sp["unit"], maxd=sp["maxd"], prio=sp["prio"] + (5 if kind in ("alert", "attack") else 0),
                   maxi=3 if size in ("small", "medium") else 2, cd=0.08, pitch=(0.96, 1.04))


# ------------------------------------------------------------------ ambience (2D stereo loops)
def ambience():
    A = lambda rel, layers, length=40.0, lufs=-27, ch=2, post=None: loop("ambience/%s.ogg" % rel, layers, lufs, length, "ambience", ch=ch, post=post)
    SQUASH = ["acompressor=threshold=-30dB:ratio=4:attack=5:release=200:makeup=4"]  # bubbling pops: tame the crest so the bed reaches its level
    beds = {
        "grassland_day": [L("bsb:0912", 20), L("bsb:0908", 10, gain=-6)],
        "grassland_night": [L("bsb:0110", 5), L("bsb:1470", 30, gain=-8)],
        "temperate_day": [L("bsb:0136", 40), L("bsb:0222", 60, gain=-6)],
        "temperate_night": [L("bsb:0315", 20), L("bsb:0555", 0, gain=-4, loop=True), L("bsb:0429", 0, gain=-7, loop=True)],
        "tropical_day": [L("c:c02", 100), L("bsb:3002", 5, gain=-10)],
        "tropical_night": [L("bsb:1470", 60), L("bsb:0997", 10, gain=-4)],
        "savannah_day": [L("bsb:1779", 2), L("bsb:0908", 40, gain=-6), L("bsb:2246", 0, gain=-12, loop=True)],
        "savannah_night": [L("bsb:1469", 40), L("bsb:1020", 0, gain=-3, loop=True)],
        "desert_day": [L("bsb:0147", 20), L("bsb:0595", 10, gain=-4)],
        "desert_night": [L("bsb:0595", 40, gain=-2), L("bsb:0425", 0, gain=-10, loop=True)],
        "swamp_day": [L("bsb:0691", 30), L("bsb:0998", 20, gain=-6)],
        "swamp_night": [L("bsb:0997", 40), L("bsb:1053", 5, gain=-6), L("bsb:1470", 100, gain=-8)],
        "tundra_day": [L("bsb:1450", 20), L("bsb:0147", 60, gain=-6)],
        "tundra_night": [L("bsb:0147", 50, gain=-2), L("bsb:1763", 0, t=8.0, gain=-12, delay=14.0)],
        "volcanic_day": [L("c:c15", 30), L("bsb:0149", 0, gain=-8, loop=True), L("bsb:0146", 10, gain=-10, af="lowpass=f=800")],
        "volcanic_night": [L("c:c15", 90), L("bsb:0149", 4, gain=-10, loop=True), L("bsb:0424", 0, gain=-10, loop=True), L("bsb:0146", 40, gain=-10, af="lowpass=f=600")],
    }
    for name, layers in beds.items():
        ev("amb_" + name, [A(name, layers, post=SQUASH if name.startswith("volcanic") else None)], "Ambience", "2d", pitch=(1, 1), maxi=1, prio=100, loop_=True)
    ev("amb_shore", [A("shore", [L("bsb:0915", 20), L("bsb:1046", 30, gain=-3)], lufs=-26)], "Ambience", "2d", pitch=(1, 1), maxi=1, prio=100, loop_=True)
    ev("amb_rain_light", [A("rain_light", [L("bsb:0124", 1)], length=38.0, lufs=-27)], "Ambience", "2d", pitch=(1, 1), maxi=1, prio=100, loop_=True)
    ev("amb_rain_heavy", [A("rain_heavy", [L("bsb:2717", 0), L("bsb:0740", 60, gain=-3)], length=36.0, lufs=-24)], "Ambience", "2d", pitch=(1, 1), maxi=1, prio=100, loop_=True)
    ev("amb_wind_strong", [A("wind_strong", [L("bsb:0146", 30), L("bsb:1450", 70, gain=-6)], lufs=-26)], "Ambience", "2d", pitch=(1, 1), maxi=1, prio=100, loop_=True)
    ev("amb_fire", [A("fire", [L("bsb:0987", 5)], length=30.0, lufs=-24, ch=1)], "Ambience", "3d", pitch=(1, 1), maxi=8, prio=40, unit=3.0, maxd=18.0, loop_=True)
    f = [one("ambience/thunder_%02d.ogg" % (i + 1), [C("bsb:%s" % k, 0, rel=30, lo=2.0, hi=12.0)], -19, "ambience", max_len=12.0, fade=2.0) for i, k in enumerate(("2718", "3113", "3115", "3179"))]
    ev("thunder", f, "Ambience", "2d", pitch=(0.9, 1.05), maxi=2, cd=4.0, prio=90)


# ------------------------------------------------------------------ music (2D stereo)
def music():
    M = lambda rel, key, lufs, ss=0.0, t=None, fade=3.0: one("music/%s.ogg" % rel, [L(key, ss, t)], lufs, "music", ch=2, max_len=t, fade=fade, trim=True, q=0.28)
    explore = [M("explore_forest", "oga:oga-beautiful-forest/beautiful_forest_16bit_44.1khz_1.wav", -21),
               M("explore_jungle", "oga:oga-epic-at-the-jungle/Epic at the Jungle.Wav", -21, t=118.0, fade=6.0)]
    ev("music_explore", explore, "Music", "2d", pitch=(1, 1), maxi=1, prio=100)
    ev("music_night", [M("night_solitude", "oga:oga-nighttime-solitude/Nighttime Solitude [CC0].wav", -22, t=120.0, fade=6.0)], "Music", "2d", pitch=(1, 1), maxi=1, prio=100)
    JOBS.append(("music/combat_pursuit.ogg", "one", [L("oga:oga-determined-pursuit/determined_pursuit_loop.wav")], -20,
                 dict(ch=2, fade=0, trim=False, q=0.28), "music"))
    SOURCES["music/combat_pursuit.ogg"] = ["oga:oga-determined-pursuit/determined_pursuit_loop.wav"]
    ev("music_combat", ["music/combat_pursuit.ogg"], "Music", "2d", pitch=(1, 1), maxi=1, prio=100, loop_=True)


def run_job(job):
    rel, kind, layers, lufs, kw, cat = job
    out = os.path.join(ROOT, rel)
    if kind == "one":
        lu, d = R.render(out, layers, lufs, **kw)
    else:
        kw = dict(kw)
        lu, d = R.render_loop(out, layers, lufs, kw.pop("length"), **kw)
    return rel, cat, lu, d, os.path.getsize(out)


def write_credits_md(files):
    """Human-readable CREDITS.md grouped by source recording, from the same rows as credits.json."""
    by_src = collections.OrderedDict()
    for rel, row in sorted(files.items()):
        for s in row["sources"]:
            k = (s.get("collection", ""), s["url"], s["original_file"])
            by_src.setdefault(k, {"src": s, "used": []})["used"].append(rel)
    lines = ["# Audio credits", "",
             "Every file under `game/assets/audio/` is listed here and, machine-readably, in `game/data/audio/credits.json`.",
             "All sources are CC0 1.0 or public domain: no attribution is legally required and commercial use is allowed.",
             "The authors are credited anyway. Files were trimmed, layered, pitch-shifted, filtered and loudness-normalised",
             "with ffmpeg (`tools/audio/build_audio.py`); creature voices are layered designs, not raw recordings.", ""]
    coll = None
    for (c, url, orig), v in sorted(by_src.items(), key=lambda kv: (kv[0][0], kv[1]["src"]["title"], kv[0][2])):
        if c != coll:
            coll = c
            lines += ["## %s" % c, "", "| Source | Author | Licence | Original file | Used in |", "|---|---|---|---|---|"]
        s = v["src"]
        used = v["used"]
        shown = ", ".join("`%s`" % u for u in used[:3]) + (" (+%d more)" % (len(used) - 3) if len(used) > 3 else "")
        lines.append("| [%s](%s) | %s | %s | `%s` | %s |" % (s["title"].replace("|", "/"), url, s["author"], s["licence"], orig.replace("|", "/"), shown))
        if lines[-2].startswith("|---"):
            pass
    out = []
    for i, l in enumerate(lines):  # blank line after each table
        out.append(l)
        if l.startswith("| [") and (i + 1 == len(lines) or lines[i + 1].startswith("## ")):
            out.append("")
    open(os.path.join(ROOT, "CREDITS.md"), "w").write("\n".join(out) + "\n")


def main():
    for fn in (ui, survivor, gather, combat, creatures, ambience, music):
        fn()
    results = {}
    with cf.ThreadPoolExecutor(max_workers=8) as ex:
        for rel, cat, lu, d, size in ex.map(run_job, JOBS):
            results[rel] = (cat, lu, d, size)
    # Credits: one row per shipped file, every contributing source with licence.
    files = {}
    for rel in sorted(results):
        rows = []
        for k in SOURCES[rel]:
            s = srcs.src(k)
            assert s["licence"] in srcs.ALLOWED, (rel, k, s["licence"])
            rows.append({k2: s[k2] for k2 in ("title", "author", "licence", "url", "original_file", "collection") if k2 in s})
            if "download" in s:
                rows[-1]["download"] = s["download"]
        files[rel] = {"sources": rows, "category": results[rel][0], "lufs": results[rel][1], "seconds": round(results[rel][2], 3), "bytes": results[rel][3]}
    os.makedirs(os.path.join(GAME, "data", "audio"), exist_ok=True)
    json.dump({"_about": "Every shipped file under res://assets/audio with its sources. Allowed licences only.", "allowed_licences": sorted(srcs.ALLOWED), "files": files},
              open(os.path.join(GAME, "data", "audio", "credits.json"), "w"), indent=1, sort_keys=True)
    sp = {k: {"set": s, "colour": c, "pitch": p} for k, (s, c, p) in sorted(SPECIES.items())}
    sets = {k: {"size": v[1], "diet": v[2]} for k, v in SETS.items()}
    json.dump({"_about": "Species -> voice set. Event = cv_<set>_<colour>_<kind>; pitch multiplies the event pitch. Colour is an offline EQ timbre (dark/neutral/bright) standing in for a formant shift.",
               "kinds": list(KINDS), "sets": sets, "species": sp},
              open(os.path.join(GAME, "data", "audio", "creature_voices.json"), "w"), indent=1)
    ambience_map = {c: {"day": "amb_%s_day" % b, "night": "amb_%s_night" % b} for c, b in {
        "grassland": "grassland", "savannah": "savannah", "temperate": "temperate", "tropical": "tropical", "blue_tropical": "tropical",
        "tundra": "tundra", "snowfield": "tundra", "desert": "desert", "swamp": "swamp", "volcanic": "volcanic"}.items()}
    json.dump({"_about": "AudioDirector event table. files are relative to res://assets/audio/. pitch is [min, max]; cooldown and max_instances are per event.",
               "ambience": {"climates": ambience_map, "default": "grassland", "shore": "amb_shore", "rain_light": "amb_rain_light", "rain_heavy": "amb_rain_heavy", "wind": "amb_wind_strong", "thunder": "thunder", "fire": "amb_fire"},
               "music": {"explore": "music_explore", "night": "music_night", "combat": "music_combat"},
               "events": EVENTS},
              open(os.path.join(GAME, "data", "audio", "events.json"), "w"), indent=1)
    write_credits_md(files)
    # Report: LUFS per category and size budget.
    by = collections.defaultdict(list)
    for rel, (cat, lu, d, size) in results.items():
        by[cat].append((lu, size, d))
    total = sum(r[3] for r in results.values())
    rep = {"total_bytes": total, "files": len(results), "categories": {}}
    for cat, rows in sorted(by.items()):
        lus = [r[0] for r in rows]
        rep["categories"][cat] = {"files": len(rows), "lufs_mean": round(sum(lus) / len(lus), 1), "lufs_min": min(lus), "lufs_max": max(lus),
                                  "bytes": sum(r[1] for r in rows), "seconds": round(sum(r[2] for r in rows), 1)}
    json.dump(rep, open(os.path.join(R.TMP, "report.json"), "w"), indent=1)
    print(json.dumps(rep, indent=1))
    # Stale files from earlier recipes must not ship.
    for dp, _, fs in os.walk(ROOT):
        for f in fs:
            if f.endswith(".ogg"):
                rel = os.path.relpath(os.path.join(dp, f), ROOT)
                if rel not in results:
                    print("stale (not in build):", rel)


if __name__ == "__main__":
    main()
