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


## Status 2026-09-17 late: parked

The self-built simulator library ran the game only under the Compatibility renderer (Godot disables Metal on the simulator; Vulkan/MoltenVK did not initialise either), at 1 fps and rendering nearly black, and a later variant broke the simulator link with undefined `_SDL_IsIPad` symbols. The export no longer merges it. Test on a real iPhone. If the simulator matters later, the remaining work is making Godot pick the Vulkan driver on the simulator build and confirming MoltenVK links.

## Status 2026-09-17 22:40: unblocked

The 21:06 library variant links fine (the `_SDL_IsIPad` failure did not reproduce; both the
official and the self-built libraries reference it and the app target resolves it).
`tools/export_ios.sh` merges the library again; `tools/sim_run.sh` builds, installs and
launches. Verified: the downloader shell screen renders, `-- --shell-auto --code=<code>`
downloads the packs from Vercel and starts the game (~7-10 fps in the simulator). Use the
simulator for flow and layout checks; judge lighting and performance on the phone.
Launch with console output: `xcrun simctl launch --console-pty <udid> com.durangolike.dev -- <args>`.
