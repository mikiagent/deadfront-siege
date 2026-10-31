"""Alpha skin for the woolly rhino (owner's alpha sheet: reddish, shaggy). Recolours the Tripo albedo on the same UVs:
fur luminance is mapped onto a rufous ramp (dark chocolate -> fox red -> ginger tips) and brightened, because the game
darkens an alpha's colours on top (ai.json alpha.val_mult 0.6); pale horn pixels keep their own colour.
  python3 tools/gait/woolly_rhino/alpha_skin.py game/assets/creatures/woolly_rhino/woolly_rhino_Color_<task>.jpg \
      game/assets/creatures/woolly_rhino/woolly_rhino_alpha_albedo.jpg     (needs Pillow + numpy)
"""
import sys
import numpy as np
from PIL import Image
src, dst = sys.argv[1:3]
a = np.asarray(Image.open(src).convert("RGB")).astype(np.float32) / 255.0
L = a @ np.array([0.299, 0.587, 0.114], np.float32)
sat = a.max(2) - a.min(2)
t = np.clip(L * 1.8, 0, 1)[..., None]
dark, mid, light = np.array([0.15, 0.07, 0.04]), np.array([0.56, 0.30, 0.17]), np.array([0.90, 0.68, 0.46])
fur = np.where(t < 0.5, dark + (mid - dark) * (t / 0.5), mid + (light - mid) * ((t - 0.5) / 0.5))
horn = np.clip((L - 0.36) / 0.12, 0, 1) * np.clip(1 - sat / 0.25, 0, 1)
out = fur * (1 - horn[..., None]) + a * horn[..., None]
Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(dst, quality=90)
print("alpha skin", dst, "horn share %.3f" % float((horn > 0.5).mean()))
