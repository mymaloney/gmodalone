#!/usr/bin/env python3
r"""
Show how a map starts: what its logic_auto entities trigger, followed a
few steps down the I/O chain, plus the fades, scenes and commands involved.
For finding why a map hangs (e.g. a black screen waiting on a scene).

  python tools/map_logic.py "<mod folder>/maps/ep1_citadel_00_d.bsp"
  python tools/map_logic.py "<mod folder>/maps/ep1_citadel_00_d" --depth 6 --find fade

(--depth and --find are optional.)
"""
import argparse
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_assets import read_entity_lump, parse_entities, output_parts  # noqa: E402

INTERESTING = ("env_fade", "logic_choreographed_scene", "scripted_sequence", "point_clientcommand",
               "point_servercommand", "point_viewcontrol", "env_screenoverlay", "trigger_changelevel",
               "logic_relay", "env_message", "game_text", "ambient_generic")
KEYS = ("SceneFile", "duration", "holdtime", "rendercolor", "Command", "message", "m_iszEntry",
        "m_iszPlay", "spawnflags", "StartDisabled", "map", "landmark")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("bsp", type=Path)
    ap.add_argument("--depth", type=int, default=4)
    ap.add_argument("--find", help="also show every entity whose name contains this")
    args = ap.parse_args()
    if args.bsp.suffix.lower() != ".bsp":
        args.bsp = args.bsp.with_name(args.bsp.name + ".bsp")
    if not args.bsp.is_file():
        sys.exit(f"No such map: {args.bsp}\n(point it at the mod's own maps folder, e.g. <mod folder>/maps/ep1_citadel_00_d.bsp)")

    ents = [dict(kvs) | {"_kvs": kvs} for kvs in parse_entities(read_entity_lump(args.bsp))]
    by_name = defaultdict(list)
    for e in ents:
        if e.get("targetname"):
            by_name[e["targetname"].lower()].append(e)

    def label(e):
        extra = [f'{k}="{e[k]}"' for k in KEYS if k in e]
        return f'{e.get("classname")} \'{e.get("targetname", "")}\' ' + " ".join(extra)

    def outputs(e):
        for k, v in e["_kvs"]:
            p = output_parts(v)
            if p:
                yield k, p[0], p[1], p[2], p[3]

    seen = set()

    def walk(e, depth, indent):
        for out, target, inp, param, delay in outputs(e):
            print(f"{indent}{out} -> {target}.{inp}({param}) +{delay}s")
            if depth <= 0:
                continue
            for t in by_name.get(target.lower(), []):
                key = id(t)
                print(f"{indent}    = {label(t)}")
                if key not in seen:
                    seen.add(key)
                    walk(t, depth - 1, indent + "      ")

    print("== start-up chain (logic_auto)")
    for e in ents:
        if e.get("classname") == "logic_auto":
            print(label(e))
            walk(e, args.depth, "  ")

    print("\n== fades, scenes, commands, view controls")
    for e in ents:
        if e.get("classname") in INTERESTING[:9]:
            print(label(e))

    if args.find:
        print(f"\n== entities named *{args.find}*")
        for e in ents:
            if args.find.lower() in e.get("targetname", "").lower():
                print(label(e))
                for out, target, inp, param, delay in outputs(e):
                    print(f"  {out} -> {target}.{inp}({param}) +{delay}s")


if __name__ == "__main__":
    main()
