"""Build structure GLBs into game/assets/props/blender/.

Headless:  /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/structures/build.py -- [names...]
No names = every structure. Headless only (see lib.new_scene): never run it inside a live session.
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import lib  # noqa: E402
import structures  # noqa: E402

importlib.reload(lib)
importlib.reload(structures)


def build(name, keep=False):
    scn = lib.new_scene(name)
    objs = []
    for part, origin in structures.BUILDERS[name]():
        objs.append(part.to_object(scn.collection, origin))
    root = objs[0]
    for ob in objs[1:]:  # hinged leaves / arm hang under the main node, keeping their pivots
        ob.parent = root
    path = lib.export(scn, objs, name)
    return path


def main(args, keep=False):
    names = args or list(structures.BUILDERS)
    for n in names:
        build(n, keep)
    print("[structart] built %d" % len(names))


_args = globals().get("ARGS")
if _args is None:
    _args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
main(list(_args), bool(globals().get("KEEP", False)))
