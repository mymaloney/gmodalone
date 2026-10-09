#!/usr/bin/env python3
r"""
List the mod's maps whose cubemaps were never built.

A map that has env_cubemap positions (BSP lump 42) but no cubemap textures
(materials/maps/<map>/c*.vtf) packed in its pakfile (lump 40) shows default
reflections. In GMod, "hl2a_build_graphs start cubemaps" rebuilds exactly
these; the same check runs in-game as hl2a_check_cubemaps.

  python tools/cubemap_report.py "C:/path/to/mod"     (the folder with maps/)
"""
import struct
import sys
from pathlib import Path


def state(bsp: Path):
    with bsp.open("rb") as f:
        head = f.read(8 + 64 * 16)
        if head[:4] != b"VBSP":
            return None

        def lump(i):
            return struct.unpack_from("<ii", head, 8 + i * 16)

        _, cube_len = lump(42)
        pak_ofs, pak_len = lump(40)
        packed = False
        if pak_len > 0:
            f.seek(pak_ofs)
            pak = f.read(pak_len).lower()
            packed = b"materials/maps/" in pak and (bsp.stem.lower() + "/c").encode() in pak
        return cube_len // 16, packed


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    maps = Path(sys.argv[1]) / "maps"
    missing, fine, none = [], 0, 0
    for bsp in sorted(maps.rglob("*.bsp")):
        if "graphs" in bsp.parts:
            continue
        s = state(bsp)
        if not s:
            continue
        count, packed = s
        rel = bsp.relative_to(maps).with_suffix("").as_posix()
        if count and not packed:
            missing.append(f"{rel} ({count} cubemaps)")
        elif count:
            fine += 1
        else:
            none += 1
    print(f"{fine} maps have their cubemaps, {none} have no env_cubemaps, {len(missing)} are missing them:")
    for m in missing:
        print("  " + m)


if __name__ == "__main__":
    main()
