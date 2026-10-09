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
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Mod data read by Lua through data_static/hl2alone/<path>
DATA_GLOBS = [
    "resource/time_info/**/*.txt",
    "resource/songs/*.txt",
    "resource/localization/*.txt",
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
    "scripts/soundscapes*.txt",  # rain/snow/thunder layers (cl_weathersound.lua)
    "particles/particles_manifest.txt",
    "scripts/filters examples/*.amf",  # Effects panel example presets
    "resource/geo_guesser/**/*.res",  # Geo-Guesser maps, positions and macros
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


# Output-relative paths to leave out (from size_report.py lists via --exclude)
EXCLUDE = set()
excluded_bytes = 0


def find_list(f: Path):
    """An --exclude path as given, or relative to the repo root or tools/."""
    for candidate in (f, REPO / f, REPO / "tools" / f):
        if candidate.is_file():
            return candidate
    return None


def load_excludes(lists):
    for given in lists:
        f = find_list(given)
        if not f:
            print(f"warning  --exclude list not found, skipping: {given}")
            continue
        for line in f.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                EXCLUDE.add(line.replace("\\", "/").lower())


def copy(src: Path, dst: Path, rel: Path = None):
    global excluded_bytes
    if rel is not None and rel.as_posix() in EXCLUDE:
        excluded_bytes += src.stat().st_size
        return
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
            copy(f, out / lower_rel(f, REPO), lower_rel(f, REPO))
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


DEFAULT_EXCLUDE = REPO / "tools" / "cleanup_exclude.txt"

# Menu-background maps: GMod can't use them as menu backgrounds
BACKGROUND_MAPS_DIR = "maps/backgrounds/"


MUSIC_CACHE = REPO / ".cache" / "music_ogg"


def convert_music(src: Path, dst: Path) -> bool:
    """sound/music/x.wav -> x.ogg (Vorbis q5, ~160 kbit/s). Conversions are cached
    in .cache/music_ogg so --clean builds don't redo them."""
    cached = MUSIC_CACHE / (src.stem.lower() + ".ogg")
    if not cached.exists() or cached.stat().st_mtime < src.stat().st_mtime:
        cached.parent.mkdir(parents=True, exist_ok=True)
        print(f"convert  {src.name} -> .ogg")
        r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
                            "-c:a", "libvorbis", "-q:a", "5", str(cached)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            cached.unlink(missing_ok=True)
            print(f"warning  couldn't convert {src.name}, copying the .wav instead: {r.stderr.strip()[:200]}")
            return False
    copy(cached, dst.with_suffix(".ogg"))
    return True


def build_assets(out: Path, assets: Path, keep_backgrounds: bool, music_ogg: bool):
    vpks = list(assets.glob("*.vpk")) + list(assets.glob("vpk/**/*.vpk"))
    if vpks:
        print("note     VPKs found in the asset folder. GMod addons can't mount custom VPKs;")
        print("         extract any mod content from them first. (vpk/portal and vpk/lostcoast are")
        print("         stock game content - mount those games in GMod instead.)")

    for d in ASSET_DIRS:
        src = assets / d
        if not src.is_dir():
            continue
        n = fixed = converted = 0
        for f in src.rglob("*"):
            if f.is_file():
                rel = lower_rel(f, assets)
                relp = rel.as_posix()
                if relp in EXCLUDE or (not keep_backgrounds and relp.startswith(BACKGROUND_MAPS_DIR)):
                    EXCLUDE.add(relp)
                    copy(f, out / rel, rel)  # counts it as excluded
                    continue
                dst = out / rel
                if f.suffix.lower() == ".vmt" and fix_vmt_shader(f, dst):
                    fixed += 1
                elif music_ogg and relp.startswith("sound/music/") and relp.endswith(".wav") and convert_music(f, dst):
                    converted += 1
                else:
                    copy(f, dst)
                n += 1
        notes = [f"{fixed} VMTs switched to stock shaders"] if fixed else []
        if converted:
            notes.append(f"{converted} music files converted to .ogg")
        print(f"copied   {n} files from {d}/" + (f" ({', '.join(notes)})" if notes else ""))

    # Mod particle files go under particles/hl2alone/ so they only load in this gamemode
    for f in (assets / "particles").glob("*.pcf") if (assets / "particles").is_dir() else []:
        copy(f, out / "particles" / "hl2alone" / f.name.lower())


def human_mb(n):
    return f"{n / 1048576:.1f} MB"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", required=True, type=Path, help="addon output folder, e.g. garrysmod/addons/hl2alone")
    ap.add_argument("--assets", type=Path, help="folder with the mod's materials/models/sound/maps")
    ap.add_argument("--link-lua", action="store_true", help="symlink the gamemode instead of copying it")
    ap.add_argument("--clean", action="store_true", help="delete the output folder first")
    ap.add_argument("--exclude", action="append", type=Path, default=[],
                    help="file listing paths to leave out, one per line (e.g. size_report.py's duplicates.txt); repeatable")
    ap.add_argument("--no-default-exclude", action="store_true",
                    help=f"don't apply {DEFAULT_EXCLUDE.relative_to(REPO).as_posix()} (the reviewed cleanup list)")
    ap.add_argument("--keep-background-maps", action="store_true",
                    help="also copy maps/backgrounds/ (menu-background maps; ~400 MB)")
    ap.add_argument("--music-ogg", action="store_true",
                    help="convert sound/music/*.wav to .ogg with ffmpeg (~650 MB smaller)")
    args = ap.parse_args()

    if args.music_ogg and not shutil.which("ffmpeg"):
        sys.exit("--music-ogg needs ffmpeg on PATH (e.g. 'winget install ffmpeg', then open a new terminal)")
    if not args.no_default_exclude and DEFAULT_EXCLUDE.exists():
        args.exclude.insert(0, DEFAULT_EXCLUDE)
    load_excludes(args.exclude)
    out = args.out.resolve()
    if out == REPO or REPO in out.parents:
        sys.exit("--out must be outside the repository")
    if args.clean and out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True, exist_ok=True)

    build_lua(out, args.link_lua)
    build_data(out)
    if args.assets:
        build_assets(out, args.assets.resolve(), args.keep_background_maps, args.music_ogg)
    else:
        print("note     no --assets given; materials/models/sound/maps were not copied")

    if excluded_bytes:
        print(f"excluded {human_mb(excluded_bytes)} (cleanup list, --exclude files"
              + ("" if args.keep_background_maps else ", menu-background maps") + ")")
    print(f"done     {out}")


if __name__ == "__main__":
    main()
