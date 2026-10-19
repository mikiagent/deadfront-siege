"""Per-climate texture recipes for bake_terrain.py (W1-BIOME).

One entry per climate, four layers each (ground, dirt, sand, rock). Colours are sRGB hex and are the
final albedo: biomes.json tints default to white, so what is baked is what the ground shows.
Layer keys: base (fbm noise through a colour ramp), splats (noise-masked patches, or "dots": voronoi
specks for blade tips, pebbles, leaf litter, pits), bands (strata), cells (voronoi stones: tone,
dome, gaps), cracks (gap lines only), detail (high-frequency overlay, linear greys around 0.5),
grain (fine multiplicative speckle), cap (linear albedo peak; bright sets clip under
gl_compatibility otherwise).

The review of the first bake found flat cloud noise with a fifth of the Poly Haven set's pixel-level
detail; bake_terrain.py now fails a layer whose detail is under the Poly Haven layer it replaces.
"""


def det(scale, amount, seed, dark=0.25, light=0.75, stretch=(1.0, 1.0), detail=1.0):
    """High-frequency overlay; dark/light may be linear (r, g, b) to carry hue variation."""
    return {"scale": scale, "amount": amount, "seed": seed, "dark": dark, "light": light,
            "stretch": stretch, "detail": detail, "lo": 0.3, "hi": 0.7}


def dots(colors, scale, size, share, seed, strength=1.0):
    return {"kind": "dots", "colors": colors, "scale": scale, "size": size, "share": share,
            "seed": seed, "strength": strength, "tex_scale": 30.0}


def patch(colors, scale, lo, hi, seed, strength=1.0):
    return {"colors": colors, "scale": scale, "lo": lo, "hi": hi, "seed": seed, "strength": strength, "detail": 5.0}


def grass(colors, seed=51, splats=None, tips="#a8b860", gaps="#3a2e1e", litter=None, stretch=(1.0, 1.0), cap=None):
    """Aerial meadow: cloud base, hue patches, then blade tips, soil gaps and litter as specks."""
    sp = list(splats or [])
    sp.append(dots([tips, tips], 170.0, 0.42, 0.45, seed + 3, 0.7))
    sp.append(dots([gaps, gaps], 120.0, 0.38, 0.22, seed + 4, 0.8))
    if litter:
        sp.append(dots(litter, 46.0, 0.5, 0.12, seed + 5, 0.9))
    spec = {
        "base": {"scale": 5.0, "detail": 6.0, "rough": 0.6, "colors": colors, "spread": 0.22, "seed": seed,
                 "stretch": stretch, "fine": {"scale": 70.0, "amount": 0.45, "seed": seed + 1, "stretch": stretch}},
        "splats": sp,
        "detail": [det(480.0, 0.95, seed + 6, (0.18, 0.2, 0.16), (0.8, 0.82, 0.66)),
                   det(160.0, 0.6, seed + 7, 0.3, 0.7, stretch=(1.0, 3.0))],
        "grain": {"scale": 160.0, "amount": 0.16},
    }
    if cap:
        spec["cap"] = cap
    return spec


def soil(colors, seed=31, splats=None, scale=6.0, pebble="#8a7a66", grit="#241a12", litter=None, cap=None):
    """Bare earth: clods, pebbles and dark grit specks over a mottled base."""
    sp = list(splats or [])
    sp.append(dots([pebble, "#b0a490"], 70.0, 0.42, 0.28, seed + 3, 0.85))
    sp.append(dots([pebble, pebble], 28.0, 0.38, 0.1, seed + 4, 0.75))
    sp.append(dots([grit, grit], 210.0, 0.4, 0.4, seed + 5, 0.8))
    if litter:
        sp.append(dots(litter, 40.0, 0.5, 0.14, seed + 6, 0.85))
    spec = {
        "base": {"scale": scale, "detail": 7.0, "rough": 0.6, "colors": colors, "spread": 0.22, "seed": seed,
                 "fine": {"scale": 45.0, "amount": 0.35, "seed": seed + 1}},
        "splats": sp,
        "detail": [det(520.0, 1.0, seed + 7, 0.06, 0.94), det(260.0, 0.7, seed + 9, 0.2, 0.8),
                   det(130.0, 0.7, seed + 8, 0.25, 0.75)],
        "grain": {"scale": 140.0, "amount": 0.2},
    }
    if cap:
        spec["cap"] = cap
    return spec


def sand(colors, seed=41, ripples=0, splats=None, shells="#e8e0d0", cap=None):
    sp = list(splats or [])
    sp.append(dots([shells, shells], 90.0, 0.32, 0.06, seed + 3, 0.6))
    spec = {
        "base": {"scale": 3.0, "detail": 5.0, "rough": 0.5, "colors": colors, "spread": 0.2, "seed": seed,
                 "fine": {"scale": 60.0, "amount": 0.25, "seed": seed + 1}},
        "splats": sp,
        "detail": [det(600.0, 0.7, seed + 4, 0.3, 0.7)],
        "grain": {"scale": 200.0, "amount": 0.12},
    }
    if ripples:
        spec["ripples"] = {"count": ripples, "warp": 4.0, "amount": 0.5 if ripples > 12 else 0.25, "sharp": 1.6, "seed": seed + 2}
    if cap:
        spec["cap"] = cap
    return spec


def rock(colors, seed, cells, splats=None, bands=None, speck=0.9, cap=None):
    """Each climate passes its own cells (and bands) so no two rock sets share a pattern."""
    spec = {
        "base": {"scale": 3.0, "detail": 8.0, "rough": 0.65, "colors": colors, "spread": 0.16, "seed": seed,
                 "fine": {"scale": 38.0, "amount": 0.3, "seed": seed + 1}},
        "splats": splats or [],
        "bands": bands or [],
        "cells": cells,
        "detail": [det(440.0, speck, seed + 2, 0.15, 0.85), det(110.0, 0.6, seed + 3, 0.3, 0.7)],
        "grain": {"scale": 120.0, "amount": 0.14},
    }
    if cap:
        spec["cap"] = cap
    return spec


def stones(scale, seed, width=0.05, color="#2a2826", tone=0.12, dome=0.3, randomness=1.0, stretch=(1.0, 1.0),
           strength=0.85, wobble=0.07, fade=0.75):
    return {"scale": scale, "seed": seed, "width": width, "color": color, "tone": tone, "dome": dome,
            "randomness": randomness, "stretch": stretch, "strength": strength, "wobble": wobble, "fade": fade}


RECIPES = {
    "grassland": {
        # Home meadow: lighter and yellower than temperate, short grass with clover and bare spots.
        "ground": grass(["#5a7a3c", "#6f8f4f", "#8aa862"], seed=121, tips="#c4cc78", gaps="#4a3c26", splats=[
            patch(["#4f6e34", "#5c7c3c"], 4.0, 0.56, 0.68, 122, 0.6),
            patch(["#9a8a58", "#a89664"], 6.0, 0.7, 0.77, 123, 0.5),
            patch(["#8c9c4c", "#98a454"], 2.5, 0.5, 0.62, 124, 0.35)]),
        "dirt": soil(["#5c4430", "#70563d", "#86694c"], seed=131),
        "sand": sand(["#b8a274", "#c6b184", "#d4c094"], seed=141),
        # Granite boulders: rounded cells, salt-and-pepper speck, lichen.
        "rock": rock(["#606060", "#72726f", "#88887f"], 151, [
            stones(5.0, 152, width=0.06, dome=0.4, tone=0.12),
            stones(16.0, 153, width=0.03, dome=0.0, tone=0.06, strength=0.5)],
            splats=[dots(["#a8a878", "#b8b488"], 60.0, 0.45, 0.12, 154, 0.7)], speck=1.0),
    },
    "temperate": {
        "ground": grass(["#33491e", "#465f28", "#5e7636"], seed=51, tips="#9aa85a", gaps="#3a2c1c",
                        litter=["#6a4a2a", "#86643a"], splats=[
            patch(["#2c401a", "#36501f"], 4.0, 0.55, 0.68, 61, 0.7),
            patch(["#6d6a3c", "#7d7646"], 6.0, 0.66, 0.74, 62, 0.5),
            patch(["#56702e", "#62803a"], 2.5, 0.5, 0.62, 63, 0.4)]),
        "dirt": soil(["#4a3322", "#5f432c", "#76573a"], seed=31, litter=["#5a3e22", "#7a5a34"]),
        "sand": sand(["#b8975c", "#c9aa6a", "#d6bb80"], seed=41),
        # Fractured slate with moss in the joints.
        "rock": rock(["#535750", "#666b64", "#7d8079"], 21, [
            stones(4.5, 22, width=0.035, dome=0.35, tone=0.14, stretch=(1.0, 1.6), randomness=0.9),
            stones(13.0, 23, width=0.025, dome=0.0, tone=0.05, strength=0.55)],
            splats=[patch(["#4c6236", "#5b7040"], 4.0, 0.6, 0.72, 24, 0.6)]),
    },
    "savannah": {
        "ground": grass(["#7a6a3a", "#9a8650", "#b8a468"], seed=63, stretch=(1.0, 3.0), tips="#d8c890",
                        gaps="#6a4a2a", splats=[
            patch(["#6a6634", "#77733c"], 4.0, 0.58, 0.7, 64, 0.6),
            patch(["#8a6040", "#9a6c48"], 7.0, 0.68, 0.76, 65, 0.6)]),
        "dirt": soil(["#6a4428", "#84583a", "#9a6a46"], seed=66, pebble="#a88a6a"),
        "sand": sand(["#c0a06a", "#ceb47b", "#dcc490"], seed=67),
        # Red sandstone strata with bedding fractures.
        "rock": rock(["#7a5a44", "#8c6c52", "#9e7e62"], 68, [
            stones(3.0, 69, width=0.035, dome=0.15, tone=0.1, stretch=(1.0, 5.0), color="#3e2a1e")],
            bands=[{"count": 11, "warp": 2.5, "seed": 70, "amount": 0.55, "blend": "MIX",
                    "colors": ["#6a4a36", "#9a7458", "#7e5c44", "#b08a68"]}]),
    },
    "tropical": {
        "ground": grass(["#2a6e24", "#3c8c30", "#58a640"], seed=71, tips="#a8cc5a", gaps="#2a2014",
                        litter=["#5a4a24", "#7a6a30"], splats=[
            patch(["#185018", "#226622"], 3.5, 0.55, 0.66, 72, 0.8),
            patch(["#5aa040", "#6ab048"], 8.0, 0.68, 0.76, 73, 0.5)]),
        "dirt": soil(["#3a281a", "#4b3424", "#5e4230"], seed=74, litter=["#4a3a1a", "#6a5228"]),
        "sand": sand(["#d8c48c", "#e2cf98", "#ecdcac"], seed=75, cap=0.72),
        # Mossy rounded boulders.
        "rock": rock(["#4c5446", "#5b6450", "#6e765e"], 76, [
            stones(6.5, 77, width=0.065, dome=0.45, tone=0.1)],
            splats=[patch(["#2f5a26", "#3c6a2e"], 4.0, 0.5, 0.64, 78, 0.8),
                    dots(["#3c6a2e", "#4a7a34"], 50.0, 0.5, 0.3, 79, 0.8)]),
    },
    "blue_tropical": {
        "ground": grass(["#2a5e4a", "#3a7e62", "#56a080"], seed=81, tips="#8cc4a0", gaps="#24302a", splats=[
            patch(["#205244", "#2a6052"], 3.5, 0.55, 0.66, 82, 0.8),
            patch(["#7ab8a0", "#88c4ac"], 8.0, 0.7, 0.78, 83, 0.4)]),
        "dirt": soil(["#4a3a2e", "#5a4636", "#6c5644"], seed=84),
        "sand": sand(["#e2d8b6", "#ece2c0", "#f6eed6"], seed=85, shells="#f0c8c0", cap=0.74),
        # Pale pitted coral limestone.
        "rock": rock(["#8a8480", "#9a9590", "#aca49c"], 86, [
            stones(3.5, 87, width=0.03, dome=0.1, tone=0.08, strength=0.6, color="#5a5450")],
            splats=[patch(["#c08070", "#cc8c7c"], 5.0, 0.66, 0.74, 88, 0.5),
                    dots(["#4a4642", "#5a5450"], 95.0, 0.38, 0.4, 89, 0.85),
                    dots(["#3a3634", "#4a4642"], 30.0, 0.35, 0.15, 90, 0.7)], cap=0.6),
    },
    "tundra": {
        # Frozen dirt with wind-packed snow lying in the hollows.
        "ground": soil(["#6e6a60", "#878478", "#9c9a90"], seed=91, pebble="#a09a90", splats=[
            patch(["#c6ced6", "#dce2e8"], 3.0, 0.5, 0.6, 92, 0.95),
            patch(["#62684a", "#6c7252"], 7.0, 0.66, 0.74, 93, 0.5)], cap=0.72),
        "dirt": soil(["#544a40", "#6a5f55", "#7c7064"], seed=94),
        "sand": sand(["#968e80", "#a8a294", "#bab4a8"], seed=95),
        # Frost-shattered angular blocks with frost in the joints.
        "rock": rock(["#5c6064", "#6d7275", "#82878a"], 96, [
            stones(9.0, 97, width=0.045, dome=0.15, tone=0.15),
            stones(3.0, 98, width=0.06, dome=0.0, tone=0.0, strength=0.7)],
            splats=[patch(["#c8d0d6", "#d8dee2"], 4.0, 0.6, 0.7, 99, 0.8)], cap=0.72),
    },
    "snowfield": {
        # Wind-crusted snow: sastrugi ripples and blue shadows; capped so gl_compatibility keeps the texture.
        "ground": dict(sand(["#b4c0cc", "#cad4de", "#dce4ec"], seed=101, ripples=9, shells="#9aaabc", splats=[
            patch(["#98aabe", "#a8b8ca"], 3.0, 0.6, 0.72, 102, 0.7)], cap=0.8), floor_ref="sand"),
        # Slush and frozen mud.
        "dirt": soil(["#3e3a36", "#524c46", "#645e56"], seed=103, pebble="#7a7470", grit="#1e1c1a", splats=[
            patch(["#9aa8b2", "#b0bcc4"], 3.5, 0.56, 0.66, 104, 0.8),
            patch(["#5a6670", "#66727c"], 6.0, 0.6, 0.7, 105, 0.6)], cap=0.6),
        "sand": sand(["#a8b0b8", "#bac2ca", "#ccd2d8"], seed=106, cap=0.8),
        # Dark granite boulders with snow caps.
        "rock": rock(["#585e66", "#6a7078", "#7e848c"], 107, [
            stones(5.0, 108, width=0.06, dome=0.5, tone=0.12)],
            splats=[patch(["#d0d8e0", "#dfe5ea"], 3.5, 0.52, 0.62, 109, 0.9)], cap=0.8),
    },
    "desert": {
        "ground": dict(sand(["#c49a5e", "#d9b77a", "#e8ca90"], seed=111, ripples=26, shells="#a07848", splats=[
            patch(["#b8864e", "#c08e56"], 3.0, 0.62, 0.72, 112, 0.5)], cap=0.7), floor_ref="sand"),
        "dirt": soil(["#9a6438", "#b07a48", "#c08c58"], seed=113, pebble="#c8a07a", grit="#5a3a20", cap=0.7),
        "sand": sand(["#d4b07a", "#e0c48c", "#ecd4a0"], seed=114, ripples=34, cap=0.7),
        # Cross-bedded sandstone: wavy strata, long blocks, wind pits.
        "rock": rock(["#a07448", "#b98a5c", "#cca070"], 115, [
            stones(2.5, 116, width=0.03, dome=0.12, tone=0.08, stretch=(1.0, 6.0), color="#5a3a24")],
            bands=[{"count": 17, "warp": 6.0, "warp_scale": 3.0, "seed": 117, "amount": 0.5, "blend": "MIX",
                    "colors": ["#9a6a40", "#c49464", "#a87850", "#d4a878"]}],
            splats=[dots(["#7a5434", "#8a6040"], 70.0, 0.4, 0.2, 118, 0.7)], cap=0.7),
    },
    "swamp": {
        # Peat and mud with algae scum and standing water in the low spots.
        "ground": soil(["#3e3622", "#524830", "#665a38"], seed=121, pebble="#6a6040", grit="#18140c",
                       litter=["#3a3a1a", "#4a4a20"], splats=[
            patch(["#5a7a2e", "#6e9038"], 4.0, 0.56, 0.66, 122, 0.9),
            patch(["#1c1c16", "#24241c"], 5.0, 0.66, 0.72, 123, 0.8)]),
        "dirt": soil(["#2e2218", "#3b2c1f", "#4a3828"], seed=124, pebble="#5a4a38", grit="#140e08"),
        "sand": sand(["#6c6250", "#7d725a", "#8e846a"], seed=125),
        # Dark wet boulders with algae.
        "rock": rock(["#40443c", "#4f5249", "#62655a"], 126, [
            stones(5.5, 127, width=0.07, dome=0.4, tone=0.1, color="#1a1c16")],
            splats=[patch(["#3a4a26", "#46582e"], 3.5, 0.5, 0.62, 128, 0.8),
                    dots(["#4a6a2a", "#5a7a30"], 80.0, 0.45, 0.25, 129, 0.7)]),
    },
    "volcanic": {
        # Cooled lava plates under ash drifts, scoria grit.
        "ground": rock(["#222120", "#33312f", "#46433f"], 131, [
            stones(3.0, 132, width=0.03, dome=0.2, tone=0.1, color="#141313", strength=0.7)],
            splats=[patch(["#5e5c5a", "#72706c"], 3.0, 0.56, 0.66, 133, 0.85),
                    dots(["#6a6664", "#7a7672"], 140.0, 0.4, 0.3, 134, 0.8),
                    dots(["#4a2418", "#5a2c1c"], 60.0, 0.4, 0.08, 135, 0.8)]),
        # Charred soil and grit.
        "dirt": soil(["#241e1c", "#332a26", "#433830"], seed=136, pebble="#5a524c", grit="#0e0a08", splats=[
            patch(["#4a2a1c", "#5a3222"], 5.0, 0.62, 0.72, 137, 0.6)]),
        "sand": sand(["#2e2c2a", "#3a3836", "#4a4744"], seed=138, shells="#6a6662"),
        # Columnar basalt seen from above: near-regular hexagonal joints, vesicle pits, rust.
        "rock": rock(["#262526", "#2f2e2f", "#3e3c3d"], 139, [
            stones(8.0, 140, width=0.05, dome=0.3, tone=0.14, randomness=0.55, color="#0e0c0c", wobble=0.03, fade=0.35)],
            splats=[patch(["#5a2a1a", "#6a3220"], 6.0, 0.7, 0.76, 141, 0.6),
                    dots(["#121010", "#1a1818"], 110.0, 0.4, 0.35, 142, 0.85)]),
    },
}

# Snowfield and desert ground are snow and dune sand, so their recipes set floor_ref="sand".
# The Poly Haven layer each set replaces. bake_terrain.py measures its relative detail and fails any
# baked layer that has less.
REFERENCE = {"ground": "aerial_grass_rock_diff_1k.jpg", "dirt": "brown_mud_leaves_01_diff_1k.jpg",
             "sand": "aerial_beach_01_diff_1k.jpg", "rock": "rocky_trail_diff_1k.jpg"}
