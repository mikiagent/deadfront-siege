# Godot updater handoff

- Shipped `tools/update_godot.py`, a macOS Mono editor update checker and opt-in installer. It selects stable 4.7 patches, verifies the official release SHA-256 and Apple code signature, checks the editor version, and preserves the previous app alongside the replacement.
- Verified the live update check, a real 4.7.2 installation into a temporary directory, an upgrade from a temporary copy of 4.7.1 with its backup retained, the no-op path for an already current editor, and rejection of 4.8. `tools/smoke.sh` printed `SMOKE PASS` using the existing 4.7.1 installation.
- No failures. No Meshy credits spent. No game design assumptions.
- The installed editor and project pin were not changed. Before using 4.7.2 for the project, coordinate the pinned version, standard web editor and templates, and iOS simulator library. `tools/find_godot.sh` may select a different executable via `GODOT_PATH` or PATH.
