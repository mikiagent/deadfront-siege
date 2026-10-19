"""Source registry: every downloaded file the audio build may read, with its licence metadata.
Licences were checked on the source pages (saved under audio-work/): Kenney License.txt (CC0),
BigSoundBank licence page (CC0 1.0), OpenGameArt licence field (CC0 only), Wikimedia Commons
extmetadata (CC0 or Public domain). Nothing here is attribution-required or non-commercial.
"""
import os

DL = os.environ.get("AUDIO_DL", "/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/audio-dl")  # one dir per source; see credits.json for URLs

ALLOWED = {"CC0-1.0", "Public Domain"}

KENNEY_PACKS = {
    "kenney-impact-sounds": "impact-sounds",
    "kenney-rpg-audio": "rpg-audio",
    "kenney-interface-sounds": "interface-sounds",
    "kenney-ui-audio": "ui-audio",
    "kenney-casino-audio": "casino-audio",
    "kenney-music-jingles": "music-jingles",
}

# OpenGameArt download dir -> (page slug, submitter, archive or file name)
OGA = {
    "oga-15-vocal-male": ("15-vocal-male-strainhurtpainjump-sounds", "qubodup", "slightscreams.7z"),
    "oga-16-monster-growls": ("16-monster-growls", "starninjas", "monster_-_starninjas.zip"),
    "oga-80-creature": ("80-cc0-creature-sfx", "rubberduck", "80-CC0-creature-SFX_0.zip"),
    "oga-80-creature-2": ("80-cc0-creture-sfx-2", "rubberduck", "80-CC0-creature-sfx-2.zip"),
    "oga-beautiful-forest": ("beautiful-forest-orchestra", "nene", "beautiful_forest_16bit_44.1khz_1.wav"),
    "oga-camel": ("camel-groan", "antumdeluge", "camel.zip"),
    "oga-deep-breaks": ("deep-bone-crackbreak-sfx", "zane-little-music", "deep_breaks.zip"),
    "oga-deep-monster-roar": ("cc0-deep-monster-roar", "trazzz123", "monster_roar.wav"),
    "oga-determined-pursuit": ("determined-pursuit-epic-orchestra-loop", "emmama", "determined_pursuit_loop.wav"),
    "oga-epic-at-the-jungle": ("epic-at-the-jungle", "indieteur", "Epic at the Jungle.Wav"),
    "oga-fantozzi-footsteps": ("fantozzis-footsteps-grasssand-stone", "qubodup", "Fantozzi-footsteps.7z"),
    "oga-gorilla": ("gorilla-sounds", "antumdeluge", "gorilla.zip"),
    "oga-grunts-male-death-and-pain": ("grunts-male-death-and-pain", "thebardofblasphemy", "death pain grunts.wav"),
    "oga-mud": ("25-cc0-mud-sfx", "rubberduck", "25-CC0-mud-sfx.zip"),
    "oga-nighttime-solitude": ("nighttime-solitude", "celestialghost8", "Nighttime Solitude [CC0].wav"),
    "oga-pain-sounds-emopreben": ("pain-sounds-by-emopreben", "emopreben", "painsounds.zip"),
    "oga-peludo-sand": ("water-splash-and-sand-footsteps", "peludo", "sand_footsteps_0.mp3"),
    "oga-ripping-meat": ("ripping-into-meat", "eldritch-grim", "rippingintomeat_0.mp3"),
    "oga-silent-beast": ("silent-beast-growls4", "pauliuw", "silent_beast_growl.mp3"),
    "oga-small-dino-raspy": ("small-dino-raspy-calls", "caveboytup", "small_dino_raspy_calls.mp3"),
    "oga-swishes": ("swishes-sound-pack", "artisticdude", "swishes.zip"),
    "oga-t-rex-calls": ("t-rex-calls", "caveboytup", "t-rex_calls.mp3"),
    "oga-water-splash": ("40-cc0-water-splash-slime-sfx", "rubberduck", "water-splash-slime-sfx.zip"),
    "oga-wet-breaks": ("fleshy-bone-breaksnap-sfx", "zane-little-music", "wet_breaks.zip"),
    "oga-wet-squish": ("8-wet-squish-slurp-impacts", "qubodup", "independent_nu_ljudbank-wet_squish_slurp_impacts.7z"),
}

# Commons dir -> (upload url, licence, author); licences checked against each File: page's extmetadata
COMMONS = {
    "c01": ("https://upload.wikimedia.org/wikipedia/commons/b/bf/27alligator2bellow.ogg", "Public Domain", "unknown (public domain, Wikimedia Commons)"),
    "c02": ("https://upload.wikimedia.org/wikipedia/commons/8/87/404114_felix-blume_toucans-singing-in-the-amazonian-rainforest-brazil.ogg", "CC0-1.0", "Felix Blume"),
    "c03": ("https://upload.wikimedia.org/wikipedia/commons/2/29/439280_schots_angry-tiger.wav", "CC0-1.0", "schots"),
    "c04": ("https://upload.wikimedia.org/wikipedia/commons/1/1a/Alligatorbellow1.ogg", "Public Domain", "unknown (public domain, Wikimedia Commons)"),
    "c05": ("https://upload.wikimedia.org/wikipedia/commons/d/db/Alligatorbellowedit.ogg", "Public Domain", "Borisblue"),
    "c06": ("https://upload.wikimedia.org/wikipedia/commons/5/5c/Alligatorhiss.ogg", "Public Domain", "unknown (public domain, Wikimedia Commons)"),
    "c07": ("https://upload.wikimedia.org/wikipedia/commons/4/40/Elephant_voice_-_trumpeting.ogg", "CC0-1.0", "Thagaval uzhavan (Wikimedia Commons)"),
    "c08": ("https://upload.wikimedia.org/wikipedia/commons/9/96/Elkbellow.ogg", "Public Domain", "unknown (public domain, Wikimedia Commons)"),
    "c09": ("https://upload.wikimedia.org/wikipedia/commons/d/d1/Geese_Honking_%28distant%29.ogg", "Public Domain", "U.S. Fish and Wildlife Service"),
    "c10": ("https://upload.wikimedia.org/wikipedia/commons/a/aa/Geese_Honking_%28loud%29.ogg", "Public Domain", "U.S. Fish and Wildlife Service"),
    "c11": ("https://upload.wikimedia.org/wikipedia/commons/7/7d/Lion_raring-sound1TamilNadu178.ogg", "Public Domain", "Thagaval uzhavan (Wikimedia Commons)"),
    "c12": ("https://upload.wikimedia.org/wikipedia/commons/1/13/Loons.ogg", "Public Domain", "unknown (public domain, Wikimedia Commons)"),
    "c13": ("https://upload.wikimedia.org/wikipedia/commons/2/22/Rattlesnake.ogg", "Public Domain", "unknown (public domain, Wikimedia Commons)"),
    "c14": ("https://upload.wikimedia.org/wikipedia/commons/4/48/Tundra_swans.ogg", "Public Domain", "U.S. Fish and Wildlife Service"),
    "c15": ("https://upload.wikimedia.org/wikipedia/commons/4/44/Yellowstone_sound_library_-_Artist_Paint_Pots_-_001.mp3", "Public Domain", "NPS & MSU Acoustic Atlas / Jennifer Jerrett"),
    "c16": ("https://upload.wikimedia.org/wikipedia/commons/c/c1/Yellowstone_sound_library_-_Bald_Eagle_-_002.mp3", "Public Domain", "NPS & MSU Acoustic Atlas / Jennifer Jerrett"),
    "c17": ("https://upload.wikimedia.org/wikipedia/commons/7/73/Yellowstone_sound_library_-_Bald_Eagle_-_003.mp3", "Public Domain", "NPS & MSU Acoustic Atlas / Jennifer Jerrett"),
    "c18": ("https://upload.wikimedia.org/wikipedia/commons/1/15/Yellowstone_sound_library_-_Canada_Geese_-_001.mp3", "Public Domain", "NPS & MSU Acoustic Atlas / Jennifer Jerrett"),
    "c19": ("https://upload.wikimedia.org/wikipedia/commons/9/91/Yellowstone_sound_library_-_Common_Raven_-_001.mp3", "Public Domain", "NPS / David Restivo"),
    "c20": ("https://upload.wikimedia.org/wikipedia/commons/4/41/Yellowstone_sound_library_-_Grizzly_Bear_vocalizations_-_001.mp3", "Public Domain", "NPS & MSU Acoustic Atlas / Jennifer Jerrett"),
    "c21": ("https://upload.wikimedia.org/wikipedia/commons/e/ef/Yellowstone_sound_library_-_Grizzly_Bears_Roar_-_001.mp3", "Public Domain", "NPS & MSU Acoustic Atlas / Jennifer Jerrett"),
    "c22": ("https://upload.wikimedia.org/wikipedia/commons/3/39/Yellowstone_sound_library_-_Sandhill_Crane_-_001.mp3", "Public Domain", "NPS & MSU Acoustic Atlas / Jennifer Jerrett"),
    "c23": ("https://upload.wikimedia.org/wikipedia/commons/a/a1/Yellowstone_sound_library_-_Sandhill_Crane_-_002.mp3", "Public Domain", "NPS / Shan Burson"),
}


def _bsb_slugs():
    work = os.path.join(os.path.dirname(DL), "audio-work")
    slugs = {"0554": "rope", "1950": "planted-cartoon-1", "1951": "planted-cartoon-2", "1952": "planted-cartoon-3"}
    for name in ("bsb_all.tsv", "bsb_q.tsv"):
        p = os.path.join(work, name)
        if os.path.exists(p):
            for line in open(p, encoding="utf-8"):
                parts = line.rstrip("\n").split("\t")
                if len(parts) >= 2 and parts[0] not in slugs:
                    slugs[parts[0]] = parts[1]
    return slugs


_BSB = None


def src(key):
    """key forms: 'bsb:1885', 'k:impact-sounds/impactMining_000.ogg', 'oga:oga-gorilla/ogg/gorilla_roar.ogg', 'c:c03'."""
    global _BSB
    kind, rest = key.split(":", 1)
    if kind == "bsb":
        if _BSB is None:
            _BSB = _bsb_slugs()
        d = os.path.join(DL, "bigsoundbank", rest)
        f = sorted(os.listdir(d))[0]
        slug = _BSB.get(rest, rest)
        return {"path": os.path.join(d, f), "title": slug.replace("-", " "), "author": "Joseph SARDIN (BigSoundBank.com)",
                "licence": "CC0-1.0", "url": "https://bigsoundbank.com/%s-s%s.html" % (slug, rest),
                "original_file": f, "collection": "BigSoundBank"}
    if kind == "k":
        pack, name = rest.split("/", 1)
        local = [d for d, p in KENNEY_PACKS.items() if p == pack][0]
        path = os.path.join(DL, local, "x", "Audio", name)
        return {"path": path, "title": "Kenney %s" % pack, "author": "Kenney (kenney.nl)", "licence": "CC0-1.0",
                "url": "https://kenney.nl/assets/%s" % pack, "original_file": name, "collection": "Kenney %s" % pack}
    if kind == "oga":
        local, name = rest.split("/", 1)
        slug, user, archive = OGA[local]
        path = os.path.join(DL, local, name)
        return {"path": path, "title": slug.replace("-", " "), "author": "%s (OpenGameArt)" % user, "licence": "CC0-1.0",
                "url": "https://opengameart.org/content/%s" % slug,
                "download": "https://opengameart.org/sites/default/files/%s" % archive,
                "original_file": name.split("/", 1)[1] if name.startswith("x/") else name, "collection": "OpenGameArt"}
    if kind == "c":
        url, lic, author = COMMONS[rest]
        d = os.path.join(DL, "commons", rest)
        f = sorted(os.listdir(d))[0]
        title = url.rsplit("/", 1)[1]
        # url is the File: page that carries the licence; download is the media file itself.
        return {"path": os.path.join(d, f), "title": title, "author": author, "licence": lic,
                "url": "https://commons.wikimedia.org/wiki/File:%s" % title, "download": url, "original_file": f,
                "collection": "Wikimedia Commons"}
    raise KeyError(key)
