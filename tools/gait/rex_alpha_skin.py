"""SP-TYRANNOSAURUS: the Alpha's armoured slate skin (owner sheet trex_owner_sheet_3_armoured.png: blue-grey, pale ash
belly) as a recolour of the v2 base colour map, so the Alpha is a texture variant on the same mesh, rig and clips.
Luminance is mapped onto a dark-slate -> blue-grey -> ash ramp; the pink mouth and the bone-white teeth keep their colour.

usage: python3 (with Pillow) tools/gait/rex_alpha_skin.py <base_color.png> <out.jpg>
"""
import sys

from PIL import Image, ImageOps

src_img = Image.open(sys.argv[1]).convert("RGB")
lum = ImageOps.autocontrast(src_img.convert("L"), cutoff=1)
DARK, MID, PALE = (22, 26, 36), (66, 76, 92), (176, 178, 172)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


lut = []
for v in range(256):
    t = (v / 255) ** 1.25
    lut.append(lerp(DARK, MID, t / 0.6) if t < 0.6 else lerp(MID, PALE, (t - 0.6) / 0.4))
src, lp = src_img.load(), lum.load()
out_img = Image.new("RGB", src_img.size)
out = out_img.load()
for y in range(src_img.size[1]):
    for x in range(src_img.size[0]):
        r, g, b = src[x, y]
        out[x, y] = src[x, y] if (r > g + 22 and r > b + 22) or r + g + b > 600 else lut[lp[x, y]]
out_img.save(sys.argv[2], quality=92)
