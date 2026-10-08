#!/usr/bin/env python3
r"""
Assemble the Garry's Mod addon for Half-Life 2: Alone.

Combines:
  * gmod/                       - the Lua gamemode (this repo)
  * data files from this repo   - time_info, songs, cfgs, sound scripts ...
  * --assets DIR                - your full copy of the Source mod
                                  (materials/, models/, sound/, maps/ ...)

into an addon folder, normally garrysmod/addons/hl2alone.

Examples:
  python tools/build_addon.py --out "C:/.../GarrysMod/garrysmod/addons/hl2alone" --assets "D:/mods/hl2alone"
  python tools/build_addon.py --out ... --link-lua      # symlink Lua for live editing
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Mod data read by Lua through data_static/hl2alone/<path>
DATA_GLOBS = [
    "resource/time_info/**/*.txt",
    "resource/songs/*.txt",
    "resource/localization/*.txt",
    "resource/amod_city_fogs.txt",
    "resource/thunder_locations.txt",
    "resource/Skyboxs.txt",
    "resource/gamelist.txt",
    "resource/games/*.txt",
    "resource/HL2_AloneMod_english.txt",
    "cfg/**/*.cfg",
    "cfg/AloneMod_Config.txt",
    "scripts/game_sounds_*.txt",
    "scripts/level_sounds_*.txt",
    "scripts/npc_sounds_*.txt",
    "particles/particles_manifest.txt",
]

# Files the engine reads directly, copied as-is into the addon root
ENGINE_GLOBS = [
    "scripts/soundscapes_amod_*.txt",
    "scripts/colorcorrection/**/*.raw",
]

# Folders copied from the asset directory
ASSET_DIRS = ["materials", "models", "sound", "maps", "scenes", "media", "resource/fonts"]

# data_static only allows certain extensions on the workshop
DATA_EXTS = {".txt", ".json", ".xml", ".csv", ".dat"}


def copy(src: Path, dst: Path):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def lower_rel(path: Path, root: Path) -> Path:
    # Source on Linux/macOS and the workshop both expect lowercase paths
    return Path(str(path.relative_to(root)).replace("\\", "/").lower())


def build_lua(out: Path, link: bool):
    src = REPO / "gmod"
    gm_dst = out / "gamemodes" / "hl2alone"

    copy(src / "addon.json", out / "addon.json")
    if gm_dst.is_symlink():
        gm_dst.unlink()
    elif gm_dst.exists():
        shutil.rmtree(gm_dst)
    gm_dst.parent.mkdir(parents=True, exist_ok=True)

    if link:
        gm_dst.symlink_to(src / "gamemodes" / "hl2alone", target_is_directory=True)
        print(f"linked   {gm_dst} -> repo")
    else:
        shutil.copytree(src / "gamemodes" / "hl2alone", gm_dst)
        print(f"copied   gamemode -> {gm_dst}")


def build_data(out: Path):
    n = 0
    for pattern in DATA_GLOBS:
        for f in REPO.glob(pattern):
            # Skip the mod author's backup folders
            if "backup" in f.as_posix().lower() or "_ignore" in f.as_posix().lower():
                continue
            rel = lower_rel(f, REPO)
            if rel.suffix not in DATA_EXTS:
                rel = rel.with_name(rel.name + ".txt")
            copy(f, out / "data_static" / "hl2alone" / rel)
            n += 1
    print(f"copied   {n} data files -> data_static/hl2alone/")

    n = 0
    for pattern in ENGINE_GLOBS:
        for f in REPO.glob(pattern):
            copy(f, out / lower_rel(f, REPO))
            n += 1
    print(f"copied   {n} soundscape / colour-correction files")

    fonts = [REPO / "resource" / "font.ttf", *(REPO / "gamepadui" / "fonts").glob("*.ttf")]
    for f in fonts:
        name = "hl2alone_cabal.ttf" if f.name == "font.ttf" else f.name.lower()
        copy(f, out / "resource" / "fonts" / name)

    for f in (REPO / "particles").glob("*.pcf"):
        copy(f, out / "particles" / "hl2alone" / f.name.lower())


# The mod's custom shader DLL isn't available in GMod; map its shaders onto
# the closest stock ones. Unknown extra parameters are ignored by the engine.
SHADER_FALLBACKS = {
    "radialfog_water": "Water",
    "radialfog_watercheap": "Water",
}
SHADER_RE = re.compile(r'^(\s*(?://[^\n]*\n\s*)*)"?([A-Za-z0-9_]+)"?', re.S)


def fix_vmt_shader(src: Path, dst: Path) -> bool:
    """Write dst with a stock shader if src uses a custom one. Returns True if rewritten."""
    text = src.read_text(encoding="latin-1")
    m = SHADER_RE.match(text)
    if not m or m.group(2).lower() not in SHADER_FALLBACKS:
        return False
    new = text[:m.start(2) - (1 if text[m.start(2) - 1] == '"' else 0)] + \
        f'"{SHADER_FALLBACKS[m.group(2).lower()]}"' + text[m.end():]
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(new, encoding="latin-1")
    return True


def build_assets(out: Path, assets: Path):
    vpks = list(assets.glob("*.vpk")) + list(assets.glob("vpk/**/*.vpk"))
    if vpks:
        print("note     VPKs found in the asset folder. GMod addons can't mount custom VPKs;")
        print("         extract any mod content from them first. (vpk/portal and vpk/lostcoast are")
        print("         stock game content - mount those games in GMod instead.)")

    for d in ASSET_DIRS:
        src = assets / d
        if not src.is_dir():
            continue
        n = fixed = 0
        for f in src.rglob("*"):
            if f.is_file():
                dst = out / lower_rel(f, assets)
                if f.suffix.lower() == ".vmt" and fix_vmt_shader(f, dst):
                    fixed += 1
                else:
                    copy(f, dst)
                n += 1
        print(f"copied   {n} files from {d}/" + (f" ({fixed} VMTs switched to stock shaders)" if fixed else ""))

    # Mod particle files go under particles/hl2alone/ so they only load in this gamemode
    for f in (assets / "particles").glob("*.pcf") if (assets / "particles").is_dir() else []:
        copy(f, out / "particles" / "hl2alone" / f.name.lower())


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", required=True, type=Path, help="addon output folder, e.g. garrysmod/addons/hl2alone")
    ap.add_argument("--assets", type=Path, help="folder with the mod's materials/models/sound/maps")
    ap.add_argument("--link-lua", action="store_true", help="symlink the gamemode instead of copying it")
    ap.add_argument("--clean", action="store_true", help="delete the output folder first")
    args = ap.parse_args()

    out = args.out.resolve()
    if out == REPO or REPO in out.parents:
        sys.exit("--out must be outside the repository")
    if args.clean and out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True, exist_ok=True)

    build_lua(out, args.link_lua)
    build_data(out)
    if args.assets:
        build_assets(out, args.assets.resolve())
    else:
        print("note     no --assets given; materials/models/sound/maps were not copied")

    print(f"done     {out}")


if __name__ == "__main__":
    main()
