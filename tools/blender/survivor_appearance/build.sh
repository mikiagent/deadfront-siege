#!/usr/bin/env bash
# Rebuilds every survivor hair option from the shipped head region, the two helmet shells from the shipped
# helmets and the face options (P4) from the head (headless Blender, 0 credits), and renders the inspection sheets. Usage: tools/blender/survivor_appearance/build.sh [sheet.png]
# Source: body/body_helmet.glb as shipped at 29ffa292 (the head with its baked hair), read from git so a re-run
# never starts from a processed file.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
B="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
OUT="$ROOT/game/assets/characters/survivor/hair"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$ROOT" show 29ffa292:game/assets/characters/survivor/body/body_helmet.glb > "$TMP/body_helmet.glb"
run() { "$B" -b --factory-startup -P "$HERE/$1" -- "${@:2}" 2>&1 | grep -E '^(SPLIT|PAINT|CROP|SHELL|FACE|DIFF|SHEET|WORST)|Error|Traceback' || true; }
run split_hair.py "$TMP/body_helmet.glb" "$OUT"
run paint_scalp.py "$OUT"
run crop_hair.py "$OUT"
SHEET="${1:-$TMP/sheet.png}"
run render_options.py "$(dirname "$SHEET")/renders" "$SHEET" \
  base="$ROOT/game/assets/characters/survivor/body/body_helmet.glb" \
  current="$OUT/head.glb,$OUT/hair_current.glb" buzz="$OUT/head_buzz.glb" bald="$OUT/head_bald.glb" \
  crop="$OUT/head.glb,$OUT/hair_crop.glb"
run clip_penetration.py "$ROOT/game/assets/characters/survivor" "$OUT/clip_penetration.json" \
  current="$OUT/hair_current.glb" crop="$OUT/hair_crop.glb"
# P3: the forager and hide_and_bone helmets as shells over the chosen head (sources as shipped at 29ffa292).
ARMOR="$ROOT/game/assets/characters/survivor/armor"
rm -f "$ARMOR/helmet_shells.json"
for KIT in forager hide_and_bone; do
  git -C "$ROOT" show 29ffa292:game/assets/characters/survivor/armor/$KIT/helmet.glb > "$TMP/$KIT.glb"
  run shell_helmet.py "$TMP/$KIT.glb" "$ARMOR/$KIT/helmet.glb" "$OUT/head.glb" \
    "$ROOT/game/assets/characters/survivor/body/body_chest.glb" "$ARMOR/helmet_shells.json"
done
# Under a helmet the hair piece hides and the default head is hair/head.glb (PlayerEquipment).
ROWS=(base="$ROOT/game/assets/characters/survivor/body/body_helmet.glb")
for KIT in forager hide_and_bone; do
  ROWS+=("${KIT}_default=$OUT/head.glb,$ARMOR/$KIT/helmet.glb" "${KIT}_buzz=$OUT/head_buzz.glb,$ARMOR/$KIT/helmet.glb"
         "${KIT}_bald=$OUT/head_bald.glb,$ARMOR/$KIT/helmet.glb")
done
run render_options.py "$(dirname "$SHEET")/renders_helmets" "${SHEET%.png}_helmets.png" views=front,side,34,back,portrait,iso "${ROWS[@]}"
run clip_penetration.py "$ROOT/game/assets/characters/survivor" "$ARMOR/helmet_clip_penetration.json" \
  forager="$ARMOR/forager/helmet.glb" hide_and_bone="$ARMOR/hide_and_bone/helmet.glb"
# P4: the face from hair/head.glb and the survivor atlas: clean shave, facial-hair decals, shell beards, brows, features.
FACE="$ROOT/game/assets/characters/survivor/face"
mkdir -p "$FACE"
run face_paint.py "$OUT" "$FACE"
BH="$ROOT/game/assets/characters/survivor/body/body_helmet.glb"
ROWS=(base="$BH")
for P in fh_clean fh_heavy_stubble fh_moustache fh_goatee fh_beard_short fh_beard_long br_straight br_arched br_bushy \
         ft_brow_scar ft_cheek_scar ft_freckles ft_face_paint ft_age_lines; do ROWS+=("$P=$BH,$FACE/$P.glb"); done
run render_options.py "$(dirname "$SHEET")/renders_face" "${SHEET%.png}_face.png" engine=eevee views=front,side,34,portrait "${ROWS[@]}"
# Under a helmet the default head is hair/head.glb and hide_and_bone hides the beard shell (kit.json "beard").
run render_options.py "$(dirname "$SHEET")/renders_face_helmets" "${SHEET%.png}_face_helmets.png" engine=eevee \
  views=front,side,34,portrait base="$BH" \
  forager_beard_long="$OUT/head.glb,$ARMOR/forager/helmet.glb,$FACE/fh_beard_long.glb" \
  forager_brows_bushy="$OUT/head.glb,$ARMOR/forager/helmet.glb,$FACE/br_bushy.glb" \
  hide_and_bone_beard_long="$OUT/head.glb,$ARMOR/hide_and_bone/helmet.glb,$FACE/fh_heavy_stubble.glb" \
  hide_and_bone_moustache_paint="$OUT/head.glb,$ARMOR/hide_and_bone/helmet.glb,$FACE/fh_moustache.glb,$FACE/ft_face_paint.glb"
PIECES=()
for P in fh_clean fh_heavy_stubble fh_moustache fh_goatee fh_beard_short fh_beard_long br_bushy ft_age_lines ft_face_paint; do
  PIECES+=("$P=$FACE/$P.glb"); done
run clip_penetration.py "$ROOT/game/assets/characters/survivor" "$FACE/face_clip_penetration.json" "${PIECES[@]}" \
  beard_short_shell="$FACE/fh_beard_short.glb@beard_" beard_long_shell="$FACE/fh_beard_long.glb@beard_" \
  vs:forager="$ARMOR/forager/helmet.glb" vs:hide_and_bone="$ARMOR/hide_and_bone/helmet.glb"
