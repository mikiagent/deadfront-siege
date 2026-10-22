# Web shader containment

## Shipped

- Web builds disable the current per-instance occlusion path. Native builds keep it, including the
  `--no-occlusion` baseline switch.
- `CardProp` now selects its instance-uniform-free shader for every web card and does not start the
  occlusion driver there.
- Added `game/tests/t_webshader.gd`, which loads the real home island in web containment mode,
  expands shader includes, and rejects any remaining instance uniform.

No Meshy credits were spent.

## Reproduction and result

Before the fix:

```text
[t_webshader] geometry=2168 instance_uniform_instances=310 items=4960 limit=1024
[t_webshader] FAIL count=2
```

After the fix:

```text
[t_webshader] geometry=2168 instance_uniform_instances=0 items=0 limit=1024
[t_webshader] PASS
```

Godot reserves 16 global shader-variable buffer items for each geometry instance that uses an
instance uniform. The 310 tall cards alone required 4,960 items on a web renderer capped at 1,024;
the complete native occlusion path measured 7,824 items. Merely returning early from
`make_card_occludable()` did not help because the tall-card material still compiled the instance
uniform include.

## Verification

- `t_card2d.gd`, `t_occlude2.gd`, and `t_switch2d.gd`: PASS.
- Local Compatibility/WebGL soak: PASS, 11 checkpoints including travel away and back. No
  `Too many instances`, script/parse error, WebGL context loss, or all-black frame.
- Release `tools/export_web.sh`: PASS, 322,531,108-byte pack under the 330 MB gate.
- `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Direct smoke with `-- --smoke --touch`: `[smoke] ok`, tap-only controls enabled.
- Browser evidence: `artifacts/web-shader-soak/` (not committed).

## Not fixed / next agent

- The WebGL soak emitted 100 `glCompressedTexImage2D` warnings because many painted sprite sources
  have dimensions that are not multiples of four while their imports use `compress/mode=4`.
  `checkpoint-01.png` visibly contains opaque dark sprite cards. The art pipeline should either pad
  those sprite textures or reimport them with a web-safe non-block format, then repeat the soak.
- Travel emitted one navigation synchronization warning for two overlapping rasterized edges.
- The dev-inclusive WebSoak pack is 343.3 MB and exceeds the release preset's 330 MB payload gate;
  the clean release pack passes. Raise the test-only cap explicitly when rebuilding a soak artifact.
- This is deliberate containment, not the final occlusion design. To restore web fades, replace the
  per-instance uniforms with a bounded global/indexed representation and keep `t_webshader.gd`
  below the 1,024-item limit.
