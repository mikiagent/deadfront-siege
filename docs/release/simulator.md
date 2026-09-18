# Running on the iPhone simulator

Godot 4.7.1's official iOS templates (standard and Mono) ship the simulator slice as **x86_64 only**, and Xcode 27's simulators are arm64 only with no Rosetta boot, so out of the box the game cannot run in a simulator on an Apple Silicon Mac.

Fix (done 2026-09-17): build Godot's iOS simulator template ourselves.

```
git clone --depth 1 --branch 4.7.1-stable https://github.com/godotengine/godot.git
cd godot && uvx --from scons scons platform=ios target=template_debug arch=arm64 ios_simulator=yes vulkan=no metal=yes module_mono_enabled=no -j10
# ~2 minutes on the M5 Pro. Outputs bin/libgodot.ios.template_debug.arm64.simulator.a (+ libgodot_camera...)
cp bin/libgodot*.arm64.simulator.a "$HOME/Library/Application Support/Godot/sim_arm64_4.7.1/"
```

`tools/export_ios.sh` folds that library into the exported project's simulator slice with `lipo` whenever it is present. Then:

```
xcrun simctl boot "iPhone 17 Pro"
tools/sim_run.sh            # export, build, install, launch, screenshot
tools/sim_run.sh --no-export
```

Notes: the game is GDScript-only, so a non-Mono library is fine even though the editor is the Mono build. Simulator frame rate is low (software-ish Metal); judge layout and flow, not performance. When Godot is upgraded, rebuild the library for the new version.
