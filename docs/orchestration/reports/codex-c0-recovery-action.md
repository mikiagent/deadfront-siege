# C0 backup recovery action

## Shipped

- The existing game's save-protection screen offers Restore backup when a primary save is missing or invalid and a valid, compatible backup exists. It warns that progress since the backup is lost.
- A damaged primary is copied byte for byte to a uniquely named `.corrupt-...` file beside the save before restoration. The backup is retained. A valid primary, a save from a newer schema, or an invalid backup cannot be replaced by this action. Saving remains blocked until the restored world loads successfully.
- The restore is staged and checked before promotion. If staging or promotion fails, the original and backup are left in place; staged files may remain for investigation. This does not guarantee durable disk flush or atomic replacement on every filesystem.
- Added isolated file and UI regressions, and extended the existing lab to exercise the button and reload an actual player from a backup. All test saves use unique temporary paths, not the player's `user://` save.

## Verification

Godot 4.7.1 Mono on macOS, branch `codex/c0-save-recovery`:

- `tools/test.sh`: `[tests] PASS`.
- `tools/smoke.sh --no-import`: `SMOKE PASS`.
- `c0_restore_regression.gd`: `C0 RESTORE PASS` for missing and damaged primaries, future and valid primaries, and invalid backup preservation.
- `c0_recovery_ui_regression.gd`: `C0 RECOVERY UI PASS` for button eligibility, target size, and a backup becoming invalid before activation.
- Existing `c0_save_guard_regression.gd`, `c0_save_write_regression.gd`, and `c0_save_compat_regression.gd`: pass; compatibility fixtures cover schemas 0, 1, 2, and 3.
- `--lab=c0_save_recovery_lab --c0-restore-action`: `C0 RESTORE ACTION PASS`; the button signal restored a fixture, preserved the damaged original, and loaded the player's inventory.
- Visible native Godot at 390x844: recovery warning and button were visually inspected. The button was exercised by a synthetic signal, not a physical touch.

The regressions are invoked with `Godot --headless --path game --script res://tests/<name>.gd`; the lab flags follow `--`. No Meshy credits were spent. No worker evaluation or audit was performed.

## Next agent

Verify physical mobile touch, safe-area behavior on a notched device, and filesystem behavior in any intended web export. Browser persistence and power-loss durability remain unverified. The UI cannot automatically recover a backup that is itself invalid or from a newer version. Preserve those files for manual recovery. Material fusion and other undecided gameplay rules remain pending design approval. Do not merge or deploy this branch without authorization.
