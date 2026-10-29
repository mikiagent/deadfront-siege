"""Source of the UI icon set in game/assets/icons/ui/.

    python3 build.py           # redraw every icon into ../<id>.svg
    python3 build.py --check   # write nothing; fail if any SVG differs from what these sources draw

Each icons_*.py module fills a dict I of id -> {"l": [line elements], "s": [solid elements]} with
coordinates placed by hand on the 64 grid; geo.py and geo2.py only spell out the path syntax
(capsules, arcs, bands, knockout cuts). icons_a..f are the first pass (5-unit lines plus solids,
nudged by offsets.py); icons_g to icons_r are solid drawings centred optically by geo2.place.
Every id is drawn in exactly one module. To change an icon, edit its module and run build.py.
"""
import os
import sys
import importlib

sys.dont_write_bytecode = True  # keep __pycache__ out of the asset folder
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from geo import f  # noqa: E402
MODULES = ["icons_a", "icons_b", "icons_c", "icons_d", "icons_e", "icons_f", "icons_g", "icons_h", "icons_i", "icons_j", "icons_k", "icons_l", "icons_m", "icons_n", "icons_o", "icons_p", "icons_q", "icons_r", "icons_s"]
SOLID = {"icons_g", "icons_h", "icons_i", "icons_j", "icons_k", "icons_l", "icons_m", "icons_n", "icons_o", "icons_p", "icons_q", "icons_r", "icons_s"}
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n'
NOTE_LINE = '<!-- DEADFRONT UI icon "%s". 64 grid, live area 6-58, line 5, round caps and joins, white only. -->\n'
NOTE_SOLID = '<!-- DEADFRONT UI icon "%s". 64 grid, live area 6-58, solid shapes, white only. -->\n'


def render() -> dict:
    offsets = importlib.import_module("offsets").T
    out, owner = {}, {}
    for m in MODULES:
        I = importlib.import_module(m).I
        for k, v in I.items():
            if k in owner:
                sys.exit("icon %s is drawn in both %s and %s" % (k, owner[k], m))
            owner[k] = m
            body = HEAD + (NOTE_SOLID if m in SOLID else NOTE_LINE) % k
            t = None if m in SOLID else offsets.get(k)
            if t and len(t) == 3:  # (dx, dy, scale about the centre): only for solid-only icons, so line weight stays 5
                assert not v.get("l"), "icon %s has lines; change its geometry instead of scaling it" % k
                body += '<g transform="translate(%s %s) scale(%s)">\n' % (f(32 * (1 - t[2]) + t[0]), f(32 * (1 - t[2]) + t[1]), f(t[2]))
            elif t:
                body += '<g transform="translate(%s %s)">\n' % t
            if v.get("l"):
                body += '<g fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">\n' + "\n".join(v["l"]) + "\n</g>\n"
            if v.get("s"):
                body += '<g fill="#FFFFFF" stroke="#FFFFFF" stroke-width="1.5" stroke-linejoin="round">\n' + "\n".join(v["s"]) + "\n</g>\n"
            if t:
                body += "</g>\n"
            out[k + ".svg"] = body + "</svg>\n"
    return out


def main() -> None:
    drawn = render()
    have = {f for f in os.listdir(OUT) if f.endswith(".svg")}
    if "--check" in sys.argv:
        bad = sorted(f for f in drawn if f not in have or open(os.path.join(OUT, f)).read() != drawn[f])
        extra = sorted(have - set(drawn))
        for f in bad:
            print("[icons] DIFFERS %s" % f)
        for f in extra:
            print("[icons] NOT FROM SOURCE %s" % f)
        print("[icons] %s drawn=%d svgs=%d" % ("FAIL" if bad or extra else "PASS", len(drawn), len(have)))
        sys.exit(1 if bad or extra else 0)
    for f, txt in drawn.items():
        with open(os.path.join(OUT, f), "w") as fh:
            fh.write(txt)
    for f in sorted(have - set(drawn)):
        print("[icons] %s is not drawn by any module (delete it or add it to a module)" % f)
    print("[icons] wrote %d" % len(drawn))


if __name__ == "__main__":
    main()
