"""Per-climate texture recipes for bake_terrain.py (W1-BIOME).

One entry per climate, four layers each (ground, dirt, sand, rock). Colours are sRGB hex and are the
final albedo: biomes.json tints default to white, so what is baked is what the ground shows.
Layer keys: base (fbm noise through a colour ramp), splats (noise-masked patches), ripples (dune
lines along v), cracks (voronoi edges), grain (fine multiplicative speckle).
"""


def rock(colors, crack="#3a3836", scale=5.0, seed=21, splats=None):
    return {
        "base": {"scale": scale, "detail": 8.0, "rough": 0.62, "colors": colors, "spread": 0.22, "seed": seed,
                 "fine": {"scale": 38.0, "amount": 0.3, "seed": seed + 1}},
        "splats": splats or [],
        "cracks": {"scale": 7.0, "width": 0.035, "color": crack, "strength": 0.8, "seed": seed + 2},
        "grain": {"scale": 120.0, "amount": 0.12},
    }


def soil(colors, seed=31, splats=None, scale=6.0):
    return {
        "base": {"scale": scale, "detail": 7.0, "rough": 0.6, "colors": colors, "spread": 0.2, "seed": seed,
                 "fine": {"scale": 45.0, "amount": 0.35, "seed": seed + 1}},
        "splats": splats or [],
        "grain": {"scale": 140.0, "amount": 0.14},
    }


def sand(colors, seed=41, ripples=0, splats=None):
    spec = {
        "base": {"scale": 3.0, "detail": 5.0, "rough": 0.5, "colors": colors, "spread": 0.2, "seed": seed,
                 "fine": {"scale": 60.0, "amount": 0.25, "seed": seed + 1}},
        "splats": splats or [],
        "grain": {"scale": 200.0, "amount": 0.10},
    }
    if ripples:
        spec["ripples"] = {"count": ripples, "warp": 4.0, "amount": 0.5, "sharp": 1.6, "seed": seed + 2}
    return spec


def grass(colors, seed=51, splats=None, stretch=(1.0, 1.0)):
    return {
        "base": {"scale": 5.0, "detail": 6.0, "rough": 0.6, "colors": colors, "spread": 0.2, "seed": seed,
                 "stretch": stretch, "fine": {"scale": 70.0, "amount": 0.45, "seed": seed + 1, "stretch": stretch}},
        "splats": splats or [],
        "grain": {"scale": 160.0, "amount": 0.16},
    }


def patch(colors, scale, lo, hi, seed, strength=1.0):
    return {"colors": colors, "scale": scale, "lo": lo, "hi": hi, "seed": seed, "strength": strength, "detail": 5.0}


RECIPES = {
    "grassland": {
        # Home meadow: lighter and yellower than temperate, short grass with clover and bare spots.
        "ground": grass(["#5a7a3c", "#6f8f4f", "#8aa862"], seed=121, splats=[
            patch(["#4f6e34", "#5c7c3c"], 4.0, 0.56, 0.68, 122, 0.6),
            patch(["#9a8a58", "#a89664"], 6.0, 0.7, 0.77, 123, 0.5)]),
        "dirt": soil(["#5c4430", "#70563d", "#86694c"]),
        "sand": sand(["#b8a274", "#c6b184", "#d4c094"]),
        "rock": rock(["#606060", "#72726f", "#88887f"]),
    },
    "temperate": {
        "ground": grass(["#2c5520", "#3f7430", "#5a8c3c"], splats=[
            patch(["#25481c", "#33602a"], 4.0, 0.55, 0.68, 61, 0.7),
            patch(["#6d6a3c", "#7d7646"], 6.0, 0.66, 0.74, 62, 0.5)]),
        "dirt": soil(["#4a3322", "#5f432c", "#76573a"]),
        "sand": sand(["#b8975c", "#c9aa6a", "#d6bb80"]),
        "rock": rock(["#535750", "#666b64", "#7d8079"], splats=[patch(["#4c6236", "#5b7040"], 4.0, 0.6, 0.72, 23, 0.6)]),
    },
    "savannah": {
        "ground": grass(["#7a6a3a", "#9a8650", "#b8a468"], stretch=(1.0, 3.0), splats=[
            patch(["#6a6634", "#77733c"], 4.0, 0.58, 0.7, 63, 0.6),
            patch(["#8a6040", "#9a6c48"], 7.0, 0.68, 0.76, 64, 0.6)]),
        "dirt": soil(["#6a4428", "#84583a", "#9a6a46"]),
        "sand": sand(["#c0a06a", "#ceb47b", "#dcc490"]),
        "rock": rock(["#6c6458", "#80786e", "#958c80"], crack="#4a4238"),
    },
    "tropical": {
        "ground": grass(["#1f5a22", "#2f7a2c", "#4a9638"], splats=[
            patch(["#185018", "#226622"], 3.5, 0.55, 0.66, 65, 0.8),
            patch(["#5aa040", "#6ab048"], 8.0, 0.68, 0.76, 66, 0.5)]),
        "dirt": soil(["#3a281a", "#4b3424", "#5e4230"]),
        "sand": sand(["#d8c48c", "#e2cf98", "#ecdcac"]),
        "rock": rock(["#4c5446", "#5b6450", "#6e765e"], splats=[patch(["#2f5a26", "#3c6a2e"], 4.0, 0.5, 0.64, 24, 0.8)]),
    },
    "blue_tropical": {
        "ground": grass(["#2a5e4a", "#3a7e62", "#56a080"], splats=[
            patch(["#205244", "#2a6052"], 3.5, 0.55, 0.66, 67, 0.8),
            patch(["#7ab8a0", "#88c4ac"], 8.0, 0.7, 0.78, 68, 0.4)]),
        "dirt": soil(["#4a3a2e", "#5a4636", "#6c5644"]),
        "sand": sand(["#e2d8b6", "#ece2c0", "#f6eed6"]),
        "rock": rock(["#7a7470", "#8a8580", "#a09890"], crack="#5a5450",
                     splats=[patch(["#c08070", "#cc8c7c"], 5.0, 0.66, 0.74, 25, 0.5)]),
    },
    "tundra": {
        # Frozen dirt with wind-packed snow lying in the hollows.
        "ground": soil(["#6e6a60", "#878478", "#9c9a90"], seed=71, splats=[
            patch(["#d6dee4", "#eef3f6"], 3.0, 0.5, 0.6, 72, 0.95),
            patch(["#62684a", "#6c7252"], 7.0, 0.66, 0.74, 73, 0.5)]),
        "dirt": soil(["#544a40", "#6a5f55", "#7c7064"]),
        "sand": sand(["#968e80", "#a8a294", "#bab4a8"]),
        "rock": rock(["#5c6064", "#6d7275", "#82878a"], splats=[patch(["#dfe6ea", "#eef2f4"], 4.0, 0.6, 0.7, 26, 0.8)]),
    },
    "snowfield": {
        "ground": sand(["#cdd6e0", "#e2e9f0", "#f4f7fa"], seed=81, splats=[
            patch(["#b4c2d2", "#c0ccda"], 3.0, 0.62, 0.72, 82, 0.6)]),
        "dirt": soil(["#787470", "#8a8682", "#9c9894"]),
        "sand": sand(["#b8bcc2", "#c8ccd0", "#d8dce0"]),
        "rock": rock(["#666c74", "#7a8088", "#90969e"], splats=[patch(["#e6ecf2", "#f4f7fa"], 3.5, 0.52, 0.62, 27, 0.9)]),
    },
    "desert": {
        "ground": sand(["#c49a5e", "#d9b77a", "#e8ca90"], seed=91, ripples=26, splats=[
            patch(["#b8864e", "#c08e56"], 3.0, 0.62, 0.72, 92, 0.5)]),
        "dirt": soil(["#9a6438", "#b07a48", "#c08c58"]),
        "sand": sand(["#d4b07a", "#e0c48c", "#ecd4a0"], ripples=34),
        "rock": rock(["#a07448", "#b98a5c", "#cca070"], crack="#7a5434", scale=4.0),
    },
    "swamp": {
        # Peat and mud with algae scum and standing water in the low spots.
        "ground": soil(["#2a2619", "#3a3324", "#4a4430"], seed=101, splats=[
            patch(["#46552a", "#556632"], 4.0, 0.56, 0.66, 102, 0.8),
            patch(["#1c1c16", "#24241c"], 5.0, 0.66, 0.72, 103, 0.8)]),
        "dirt": soil(["#2e2218", "#3b2c1f", "#4a3828"]),
        "sand": sand(["#6c6250", "#7d725a", "#8e846a"]),
        "rock": rock(["#40443c", "#4f5249", "#62655a"], splats=[patch(["#3a4a26", "#46582e"], 3.5, 0.5, 0.62, 28, 0.8)]),
    },
    "volcanic": {
        # Basalt with drifts of grey ash.
        "ground": rock(["#222120", "#33312f", "#46433f"], crack="#141313", seed=111, splats=[
            patch(["#5e5c5a", "#72706c"], 3.0, 0.56, 0.66, 112, 0.85)]),
        "dirt": soil(["#3c3836", "#4a4643", "#5a5653"]),
        "sand": sand(["#2e2c2a", "#3a3836", "#4a4744"]),
        "rock": rock(["#262526", "#2f2e2f", "#3e3c3d"], crack="#120f0e", splats=[
            patch(["#5a2a1a", "#6a3220"], 6.0, 0.7, 0.76, 29, 0.6)]),
    },
}
