#!/usr/bin/env python3
r"""
Audit the mod's assets for Garry's Mod porting problems.

  * Maps (maps/*.bsp): entity classes used, and every amod_*/custom console
    command the maps fire (point_servercommand / point_clientcommand outputs).
    These commands came from the mod's DLLs and must be re-created in Lua.
  * Materials (materials/**/*.vmt): shaders that only exist in the mod's
    custom shader DLL (GMod can't load custom shaders).

Writes a report plus hl2alone_entity_classes.txt; copy the latter to
garrysmod/data/ and run `hl2a_entcheck` in-game to see which classes GMod
can't create.

Usage:
  python tools/audit_assets.py --assets "D:/mods/hl2alone" --out audit
"""

import argparse
import lzma
import re
import struct
from collections import Counter, defaultdict
from pathlib import Path

# Shaders shipped with GMod (case-insensitive). Anything else is suspect.
STOCK_SHADERS = {
    "lightmappedgeneric", "vertexlitgeneric", "unlitgeneric", "unlittwotexture", "worldvertextransition",
    "worldtwotextureblend", "lightmappedtwotexture", "water", "refract", "sprite", "spritecard", "cable",
    "splinerope", "modulate", "patch", "wireframe", "wireframe_dx9", "eyes", "eyerefract", "teeth", "sky",
    "decalmodulate", "monitorscreen", "shatteredglass", "core", "windowimposter", "engine_post",
    "screenspace_general", "subrect", "black", "pupil", "aftershock", "particlesphere", "volumeclouds",
    "lightmappedreflective", "vortwarp", "teeth", "unlitgeneric_dx6", "vertexlitgeneric_dx6",
    "lightmappedgeneric_dx9", "vertexlitgeneric_dx9", "unlitgeneric_dx9", "decalbasetimeslightmapalphablendselfillum",
    "debugtexturelightmap", "worldvertexalpha", "fillrate", "jellyfish", "flesh",
}

# Commands the engine/GMod handle natively; everything else fired by a map is reported
NATIVE_CMD_PREFIXES = (
    "r_", "mat_", "fog_", "sv_", "cl_", "snd_", "ent_", "fov", "god", "noclip", "give", "impulse",
    "changelevel", "map", "save", "load", "playgamesound", "play ", "echo", "exec", "wait",
)


def read_entity_lump(path: Path) -> str:
    data = path.read_bytes()
    if data[:4] != b"VBSP":
        raise ValueError("not a VBSP file")
    ofs, length, _ver, _cc = struct.unpack_from("<iiii", data, 8)
    lump = data[ofs:ofs + length]

    if lump[:4] == b"LZMA":
        actual, lzma_size = struct.unpack_from("<II", lump, 4)
        props = lump[12:17]
        d = props[0]
        lc, lp, pb = d % 9, (d // 9) % 5, d // 45
        dict_size = struct.unpack_from("<I", props, 1)[0]
        dec = lzma.LZMADecompressor(lzma.FORMAT_RAW, filters=[{
            "id": lzma.FILTER_LZMA1, "dict_size": dict_size, "lc": lc, "lp": lp, "pb": pb}])
        lump = dec.decompress(lump[17:17 + lzma_size], max_length=actual)

    return lump.split(b"\0", 1)[0].decode("latin-1")


def parse_entities(text: str):
    ents = []
    for block in re.findall(r"\{(.*?)\}", text, re.S):
        ents.append(re.findall(r'"([^"]*)"\s+"([^"]*)"', block))
    return ents


def output_parts(value: str):
    sep = "\x1b" if "\x1b" in value else ","
    parts = value.split(sep)
    return parts if len(parts) >= 5 else None


def audit_maps(assets: Path):
    classes = Counter()
    class_maps = defaultdict(set)
    commands = defaultdict(set)
    errors = []

    for bsp in sorted((assets / "maps").glob("*.bsp")):
        try:
            ents = parse_entities(read_entity_lump(bsp))
        except Exception as e:  # noqa: BLE001 - report and continue
            errors.append(f"{bsp.name}: {e}")
            continue

        for kvs in ents:
            cls = next((v for k, v in kvs if k == "classname"), None)
            if cls:
                classes[cls] += 1
                class_maps[cls].add(bsp.stem)

            for k, v in kvs:
                parts = output_parts(v)
                if parts and parts[1].lower() == "command":
                    cmd = parts[2].strip()
                    if cmd and not cmd.lower().startswith(NATIVE_CMD_PREFIXES):
                        commands[cmd].add(bsp.stem)
                elif "amod" in v.lower():
                    commands[f"{k} = {v}"].add(bsp.stem)

    return classes, class_maps, commands, errors


def audit_materials(assets: Path):
    shaders = Counter()
    examples = defaultdict(list)
    for vmt in (assets / "materials").rglob("*.vmt"):
        try:
            text = vmt.read_text(encoding="latin-1")
        except OSError:
            continue
        text = re.sub(r"//[^\n]*", "", text)
        m = re.match(r'\s*"?([^"{\s]+)"?\s*\{', text)
        if not m:
            continue
        shader = m.group(1).lower()
        shaders[shader] += 1
        if len(examples[shader]) < 5:
            examples[shader].append(vmt.relative_to(assets).as_posix())
    return shaders, examples


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--assets", required=True, type=Path)
    ap.add_argument("--out", type=Path, default=Path("audit"))
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    lines = ["# HL2 Alone asset audit", ""]

    classes, class_maps, commands, errors = audit_maps(args.assets)
    lines += [f"## Maps", "", f"{len(classes)} entity classes across the maps.", ""]
    if errors:
        lines += ["Unreadable maps:", *[f"- {e}" for e in errors], ""]

    lines += ["### Console commands fired by maps (need Lua implementations)", ""]
    for cmd in sorted(commands):
        maps = sorted(commands[cmd])
        lines.append(f"- `{cmd}` ({len(maps)} maps: {', '.join(maps[:6])}{' ...' if len(maps) > 6 else ''})")

    lines += ["", "### Entity classes", "", "| class | count | maps |", "|---|---|---|"]
    for cls, n in classes.most_common():
        lines.append(f"| {cls} | {n} | {len(class_maps[cls])} |")

    (args.out / "hl2alone_entity_classes.txt").write_text("\n".join(sorted(classes)) + "\n")

    shaders, examples = audit_materials(args.assets)
    lines += ["", "## Materials", "", "Shaders not in GMod (need a stock fallback or a Lua effect):", ""]
    custom = [s for s in shaders if s not in STOCK_SHADERS]
    for s in sorted(custom, key=lambda s: -shaders[s]):
        lines.append(f"- `{s}` x{shaders[s]} e.g. {', '.join(examples[s])}")
    if not custom:
        lines.append("- none")

    report = args.out / "audit.md"
    report.write_text("\n".join(lines) + "\n")
    print(f"wrote {report} and {args.out / 'hl2alone_entity_classes.txt'}")
    print("copy hl2alone_entity_classes.txt to garrysmod/data/ and run hl2a_entcheck in-game")


if __name__ == "__main__":
    main()
