#!/usr/bin/env python3
r"""
What each chapter start gives the player, and how the campaign saves.

For every chapter (cfg/<game>/chapterN.cfg) it reads that map and reports:
  * what a new game on it hands out: logic_auto OnNewGame outputs (and what
    they target), game_player_equip contents, "give" commands, and the suit /
    weapons / ammo lying near the player start;
  * env_global story flags it sets (antlion_allied, citizens_passive ...);
  * its autosaves (logic_autosave, trigger_autosave), which the port turns
    into checkpoints.
Then a summary: maps with no autosaves, and every env_global the campaign uses.

  python tools/chapter_audit.py "<mod folder>/maps" > chapter_audit.txt
  python tools/chapter_audit.py "<mod folder>/maps" --all     (every map, not just chapter starts)
"""
import argparse
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_assets import read_entity_lump, parse_entities, output_parts  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
NEAR_START = 384  # units: items this close to a player start count as a starting kit
KIT = re.compile(r"^(item_suit|item_battery|item_healthkit|item_healthvial|item_ammo_|item_box_|weapon_)", re.I)


def chapters():
    out = []
    for cfg in sorted((REPO / "cfg").glob("*/chapter*.cfg"), key=lambda p: (p.parent.name, int(re.sub(r"\D", "", p.stem) or 0))):
        m = re.search(r"^\s*map\s+(\S+)", cfg.read_text(errors="replace"), re.M)
        if m:
            out.append((f"{cfg.parent.name} {cfg.stem}", m.group(1).lower()))
    return out


def origin(e):
    try:
        return tuple(float(v) for v in e.get("origin", "").split()[:3])
    except ValueError:
        return None


def audit(bsp: Path):
    ents = [dict(kvs) | {"_kvs": kvs} for kvs in parse_entities(read_entity_lump(bsp))]
    by_name = defaultdict(list)
    for e in ents:
        if e.get("targetname"):
            by_name[e["targetname"].lower()].append(e)
    lines = []

    # New game logic
    for e in ents:
        if e.get("classname") != "logic_auto":
            continue
        for k, v in e["_kvs"]:
            if k.lower() != "onnewgame":
                continue
            p = output_parts(v)
            if not p:
                continue
            target, inp, param = p[0], p[1], p[2]
            what = ", ".join(sorted({t.get("classname", "?") for t in by_name.get(target.lower(), [])})) or target
            lines.append(f"  OnNewGame -> {target}.{inp}({param})  [{what}]")

    for e in ents:
        cls = e.get("classname", "")
        if cls == "game_player_equip":
            kit = [k for k, _ in e["_kvs"] if KIT.match(k)]
            lines.append(f"  game_player_equip '{e.get('targetname', '')}': {', '.join(kit) or '(empty)'}")
        for k, v in e["_kvs"]:
            p = output_parts(v)
            if p and p[1].lower() == "command" and re.search(r"\b(give|impulse)\b", p[2], re.I):
                lines.append(f"  {cls} '{e.get('targetname', '')}' {k} -> command \"{p[2]}\"")

    starts = [origin(e) for e in ents if e.get("classname") == "info_player_start" and origin(e)]
    near = defaultdict(int)
    for e in ents:
        cls = e.get("classname", "")
        o = origin(e)
        if KIT.match(cls) and o and any(math.dist(o, s) <= NEAR_START for s in starts):
            near[cls] += 1
    if near:
        lines.append("  lying at the start: " + ", ".join(f"{c} x{n}" for c, n in sorted(near.items())))

    globals_ = []
    for e in ents:
        if e.get("classname") == "env_global":
            globals_.append(e.get("globalstate", "?").lower())
            lines.append(f"  env_global '{e.get('targetname', '')}': {e.get('globalstate', '?')} "
                         f"initialstate={e.get('initialstate', '0')} spawnflags={e.get('spawnflags', '0')}")

    autosaves = sum(1 for e in ents if e.get("classname") in ("logic_autosave", "trigger_autosave"))
    lines.append(f"  autosaves: {sum(1 for e in ents if e.get('classname') == 'logic_autosave')} logic_autosave, "
                 f"{sum(1 for e in ents if e.get('classname') == 'trigger_autosave')} trigger_autosave")
    return lines, globals_, autosaves


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("maps", type=Path, help="the mod's maps folder")
    ap.add_argument("--all", action="store_true", help="every map in the folder, not only chapter starts")
    args = ap.parse_args()
    if not args.maps.is_dir():
        sys.exit(f"Not a folder: {args.maps}")

    if args.all:
        todo = [(p.stem, p.stem.lower()) for p in sorted(args.maps.glob("*.bsp"))]
    else:
        todo = chapters()

    no_saves, all_globals = [], defaultdict(set)
    for label, name in todo:
        bsp = args.maps / f"{name}.bsp"
        print(f"== {label}: {name}")
        if not bsp.is_file():
            print("  (map not found)")
            continue
        try:
            lines, globals_, autosaves = audit(bsp)
        except Exception as e:  # noqa: BLE001
            print(f"  (couldn't read: {e})")
            continue
        print("\n".join(lines))
        if autosaves == 0:
            no_saves.append(name)
        for g in globals_:
            all_globals[g].add(name)

    print("\n== maps with no autosaves (a death there goes back to the map's start)")
    print("\n".join(f"  {m}" for m in no_saves) or "  none")
    print("\n== env_global story flags used")
    for g, maps in sorted(all_globals.items()):
        print(f"  {g}: {len(maps)} map(s), e.g. {sorted(maps)[0]}")


if __name__ == "__main__":
    main()
