#!/usr/bin/env bash
# Done when: every first-player group lookup outside game/scripts/ui and game/scripts/items goes through
# PlayerRegistry with the call shape TASK.md maps, nothing outside the allowed files changed, every script
# still compiles, and the headless smoke boot passes. Prints VERIFY PASS / VERIFY FAIL.
set -u
cd "$(dirname "$0")"
BASE=e270de3
GS=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
G=/Applications/Godot_mono.app/Contents/MacOS/Godot
fail=0
bad() { echo "FAIL $*"; fail=1; }
left=$(grep -rln 'get_first_node_in_group("player")' game/scripts | grep -v -e '^game/scripts/ui/' -e '^game/scripts/items/')
[ -n "$left" ] && bad "still uses the group lookup: $(echo $left)"
n=$(grep -rc 'get_first_node_in_group("player")' game/scripts | awk -F: '{s+=$2} END{print s+0}')
[ "$n" -ne 6 ] && bad "expected exactly 6 lookups left (ui 5 + items/crafting 1), found $n"
for f in $(git diff --name-only $BASE -- . ; git ls-files --others --exclude-standard); do
  case "$f" in
    TASK.md|verify_registry.sh) ;;
    game/scripts/ui/*|game/scripts/items/*|game/scripts/player/*|game/scripts/combat/hunt.gd|game/scripts/core/player_registry.gd) bad "must not change $f" ;;
    game/scripts/*.gd) ;;
    *) bad "unexpected changed file $f" ;;
  esac
done
need() { grep -qF "$2" "$1" || bad "$1 lacks: $2"; }
need game/scripts/creatures/brains/creature_brain.gd 'PlayerRegistry.nearest(creature.global_position)'
need game/scripts/creatures/brains/pet_brain.gd 'PlayerRegistry.owner_of(creature)'
need game/scripts/creatures/creature.gd 'PlayerRegistry.owner_of(self)'
need game/scripts/creatures/creature.gd 'PlayerRegistry.credit_for(_source)'
need game/scripts/creatures/creature.gd 'PlayerRegistry.nearest(global_position)'
need game/scripts/combat/telegraph.gd 'PlayerRegistry.nearest(attacker.global_position)'
for f in core/save_game.gd core/main.gd core/game.gd core/world.gd combat/telegraph.gd world/world_weather.gd \
  world/taming_pen.gd world/build_grid.gd world/island_terrain.gd creatures/corpse.gd dev/web_soak.gd \
  dev/counter_matchup_probe.gd dev/bot_rest_probe.gd dev/earned_training_probe.gd dev/raid_fight_probe.gd \
  dev/progression_probe.gd dev/siege_probe.gd dev/bot_survivor.gd dev/raid_gear_probe.gd dev/camp_travel_probe.gd \
  dev/tyrant_window_probe.gd dev/cargo_capacity_probe.gd; do
  need "game/scripts/$f" 'PlayerRegistry.local()'
done
[ $fail -eq 0 ] || { echo "VERIFY FAIL (static checks)"; exit 1; }
out=$("$GS" perl -e 'alarm 240; exec @ARGV' $G --headless --path game --script /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w2p/parse_check.gd 2>&1)
echo "$out" | grep -E '^\[parse\]|SCRIPT ERROR|Parse Error' | head -20
echo "$out" | grep -q '^\[parse\] PASS' || bad "a script does not compile"
echo "$out" | grep -qE 'SCRIPT ERROR|Parse Error' && bad "script errors while loading"
sm=$(GODOT_PATH=$G "$GS" tools/smoke.sh --no-import 2>&1)
echo "$sm" | tail -3
echo "$sm" | grep -q 'SMOKE PASS' || bad "smoke"
[ $fail -eq 0 ] && { echo "VERIFY PASS"; exit 0; }
echo "VERIFY FAIL"; exit 1
