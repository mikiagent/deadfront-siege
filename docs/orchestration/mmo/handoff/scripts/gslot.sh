#!/usr/bin/env bash
# Run a command while holding one of 5 machine-wide Godot slots (24 GB RAM box).
# Every Godot launch is forced silent (--audio-driver Dummy): the owner asked for no sound during tests.
# Usage: gslot.sh <cmd...>
L=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/locks
args=()
for a in "$@"; do
  args+=("$a")
  [[ "$a" == */Godot || "$a" == */Godot_mono || "$a" == godot || "$a" == godot4 ]] && args+=(--audio-driver Dummy)
done
# A run without its own perl alarm gets a ceiling: hung labs from killed agents once held all 5 slots for 6 h.
[[ "${args[0]}" != perl ]] && args=(perl -e "alarm ${GSLOT_MAX:-1200}; exec @ARGV" "${args[@]}")
export DEADFRONT_MUTE=1
# Inside the dsc sandbox only the project and /private/tmp are writable; Godot keeps user:// and logs under
# $HOME/Library/Application Support and segfaults at startup when it cannot create them, so point HOME at scratch.
if ! ( : > "$HOME/Library/Application Support/.gslot-probe" ) 2>/dev/null; then
  export HOME=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/godot-home
  mkdir -p "$HOME/Library/Application Support"
fi
rm -f "$HOME/Library/Application Support/.gslot-probe" 2>/dev/null
while :; do
  for i in 1 2 3 4 5; do
    lockf -s -t 0 "$L/slot$i" "${args[@]}"; rc=$?
    [[ $rc -ne 75 ]] && exit $rc   # 75 = lock busy (EX_TEMPFAIL)
  done
  sleep 3
done
