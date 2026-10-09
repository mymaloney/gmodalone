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
import fnmatch
import os
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
]

# Colour-correction lookups: the Workshop only allows .raw under
# materials/colorcorrection/, so they move there (HL2A.ColorCorrectionPath
# maps the old scripts/ paths). The mod's soundscapes play from Lua, out of
# data_static (cl_weathersound.lua): the engine-read scripts/ copies aren't
# allowed on the Workshop.
CC_GLOB = "scripts/colorcorrection/**/*.raw"

# Folders copied from the asset directory (media/ only feeds --videos)
ASSET_DIRS = ["materials", "models", "sound", "maps", "scenes", "resource/fonts"]

# Asset files Lua reads as data: moved into data_static (with .txt appended)
ASSET_DATA_PREFIXES = ("maps/snow_materials/",)

# The Workshop's file whitelist (gmad's include/AddonWhiteList.h). Anything
# else is refused on upload, so the build leaves it out and reports it.
# "*" matches across folders; "!" entries cancel earlier matches.
WORKSHOP_WHITELIST = [
    "lua/*.lua", "scenes/*.vcd", "particles/*.pcf", "resource/fonts/*.ttf", "scripts/vehicles/*.txt",
    "resource/localization/*/*.properties", "maps/*.bsp", "maps/*.lmp", "maps/*.nav", "maps/*.ain",
    "maps/thumb/*.png", "sound/*.wav", "sound/*.mp3", "sound/*.ogg", "materials/*.vmt", "materials/*.vtf",
    "materials/*.png", "materials/*.jpg", "materials/*.jpeg", "materials/colorcorrection/*.raw",
    "models/*.mdl", "models/*.phy", "models/*.ani", "models/*.vvd",
    "models/*.vtx", "!models/*.sw.vtx", "!models/*.360.vtx", "!models/*.xbox.vtx",
    "gamemodes/*/*.txt", "!gamemodes/*/*/*.txt", "gamemodes/*/*.fgd", "!gamemodes/*/*/*.fgd",
    "gamemodes/*/logo.png", "gamemodes/*/icon24.png", "gamemodes/*/gamemode/*.lua",
    "gamemodes/*/entities/effects/*.lua", "gamemodes/*/entities/weapons/*.lua", "gamemodes/*/entities/entities/*.lua",
    "gamemodes/*/backgrounds/*.png", "gamemodes/*/backgrounds/*.jpg", "gamemodes/*/backgrounds/*.jpeg",
    "data_static/*.txt", "data_static/*.dat", "data_static/*.json", "data_static/*.xml", "data_static/*.csv",
    "shaders/fxc/*.vcs",
]


def workshop_allowed(rel: str) -> bool:
    ok = False
    for w in WORKSHOP_WHITELIST:
        if w.startswith("!"):
            if fnmatch.fnmatchcase(rel, w[1:]):
                ok = False
        elif not ok:
            ok = fnmatch.fnmatchcase(rel, w)
    return ok

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
    for f in REPO.glob(CC_GLOB):
        rel = lower_rel(f, REPO / "scripts" / "colorcorrection")
        copy(f, out / "materials" / "colorcorrection" / rel, lower_rel(f, REPO))
        n += 1
    print(f"copied   {n} colour-correction files -> materials/colorcorrection/")

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

# Assets of original features the port dropped (Geo-Guesser)
DROPPED_DIRS = ("materials/vgui/geo_guesser/",)


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
                if relp in EXCLUDE or relp.startswith(DROPPED_DIRS) or (not keep_backgrounds and relp.startswith(BACKGROUND_MAPS_DIR)):
                    EXCLUDE.add(relp)
                    copy(f, out / rel, rel)  # counts it as excluded
                    continue
                dst = out / rel
                if relp.startswith(ASSET_DATA_PREFIXES):
                    copy(f, out / "data_static" / "hl2alone" / (relp if relp.endswith(".txt") else relp + ".txt"))
                elif f.suffix.lower() == ".vmt" and fix_vmt_shader(f, dst):
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


def copy_graphs(out: Path, gmod: Path, navmesh: bool, cubemaps: bool = False):
    """Node graphs (and navmeshes, and maps with rebuilt cubemaps) GMod made
    for the addon's maps (hl2a_build_graphs in-game) replace the mod's."""
    maps_dir = out / "maps"
    if not maps_dir.is_dir():
        print("note     --gmod-dir: no maps in the addon yet (use it together with --assets)")
        return
    graphs = navs = rebuilt = 0
    added = 0
    for bsp in list(maps_dir.rglob("*.bsp")):
        rel = bsp.relative_to(maps_dir).with_suffix("")
        if rel.parts[0] == "graphs":
            continue
        ain = gmod / "maps" / "graphs" / rel.with_suffix(".ain")
        if ain.is_file():
            dst = maps_dir / "graphs" / rel.with_suffix(".ain")
            old = dst.stat().st_size if dst.is_file() else 0
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ain, dst)
            added += ain.stat().st_size - old
            graphs += 1
        newbsp = gmod / "maps" / rel.with_suffix(".bsp")
        if cubemaps and newbsp.is_file():
            added += newbsp.stat().st_size - bsp.stat().st_size
            shutil.copy2(newbsp, bsp)
            rebuilt += 1
        nav = gmod / "maps" / rel.with_suffix(".nav")
        if navmesh and nav.is_file():
            dst = maps_dir / rel.with_suffix(".nav")
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(nav, dst)
            added += nav.stat().st_size
            navs += 1
    sign = "+" if added >= 0 else "-"
    print(f"copied   {graphs} rebuilt node graphs" + (f", {navs} navmeshes" if navmesh else "")
          + (f", {rebuilt} maps with rebuilt cubemaps" if cubemaps else "")
          + f" from {gmod} ({sign}{human_mb(abs(added))})")
    if graphs == 0:
        print("note     no rebuilt graphs found: run 'hl2a_build_graphs start' in GMod first")


VIDEO_CACHE = REPO / ".cache" / "videos"


def convert_videos(out: Path, assets: Path):
    """media/*.bik -> data_static/hl2alone/videos/<name>.dat (WebM: VP9 + Opus) for cl_video.lua.
    .dat because the Workshop allows no video files; the player doesn't care.
    Conversions are cached in .cache/videos."""
    media = assets / "media"
    biks = sorted(media.glob("*.bik")) if media.is_dir() else []
    if not biks:
        print("note     --videos: no .bik files in the asset folder's media/")
        return
    dst_dir = out / "data_static" / "hl2alone" / "videos"
    total = 0
    for bik in biks:
        cached = VIDEO_CACHE / (bik.stem.lower() + ".webm")
        if not cached.exists() or cached.stat().st_mtime < bik.stat().st_mtime:
            cached.parent.mkdir(parents=True, exist_ok=True)
            print(f"convert  {bik.name} -> .webm (this takes a while)")
            r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(bik),
                                "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "33", "-row-mt", "1",
                                "-deadline", "good", "-cpu-used", "4",
                                "-c:a", "libopus", "-b:a", "128k", str(cached)],
                               capture_output=True, text=True)
            if r.returncode != 0:
                cached.unlink(missing_ok=True)
                print(f"warning  couldn't convert {bik.name}: {r.stderr.strip()[:300]}")
                continue
        dst_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(cached, dst_dir / (cached.stem + ".dat"))
        total += cached.stat().st_size
    print(f"copied   videos -> data_static/hl2alone/videos/ ({human_mb(total)})")


def enforce_whitelist(out: Path):
    """Removes files the Workshop would refuse (gmpublisher/gmad stop on them) and says what they were."""
    dropped = {}
    for root, dirs, files in os.walk(out):  # doesn't follow a --link-lua symlink
        for name in files:
            f = Path(root) / name
            rel = f.relative_to(out).as_posix().lower()
            if rel == "addon.json" or workshop_allowed(rel):
                continue
            ext = f.suffix.lower() or "(none)"
            top = rel.split("/")[0]
            entry = dropped.setdefault((top, ext), [0, rel])
            entry[0] += 1
            f.unlink()
    if dropped:
        print("removed  files the Workshop doesn't allow:")
        for (top, ext), (count, example) in sorted(dropped.items()):
            print(f"           {count:5d} x {ext:8s} in {top}/  (e.g. {example})")



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
    ap.add_argument("--videos", action="store_true",
                    help="convert the mod's Bink videos (media/*.bik) to WebM with ffmpeg, for in-game playback")
    ap.add_argument("--gmod-dir", type=Path,
                    help="your garrysmod folder: copy the node graphs rebuilt in-game (hl2a_build_graphs) into the addon")
    ap.add_argument("--navmesh", action="store_true",
                    help="with --gmod-dir, also copy generated navmeshes (maps/*.nav)")
    ap.add_argument("--cubemaps", action="store_true",
                    help="with --gmod-dir, also use the maps GMod saved with rebuilt cubemaps (maps/*.bsp)")
    ap.add_argument("--music-ogg", action="store_true",
                    help="convert sound/music/*.wav to .ogg with ffmpeg (~650 MB smaller)")
    args = ap.parse_args()

    if (args.music_ogg or args.videos) and not shutil.which("ffmpeg"):
        sys.exit("--music-ogg and --videos need ffmpeg on PATH (e.g. 'winget install ffmpeg', then open a new terminal)")
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
        if args.videos:
            convert_videos(out, args.assets.resolve())
    else:
        print("note     no --assets given; materials/models/sound/maps were not copied")
    if args.gmod_dir:
        copy_graphs(out, args.gmod_dir.resolve(), args.navmesh, args.cubemaps)

    enforce_whitelist(out)
    if excluded_bytes:
        print(f"excluded {human_mb(excluded_bytes)} (cleanup list, --exclude files"
              + ("" if args.keep_background_maps else ", menu-background maps") + ")")
    print(f"done     {out}")


if __name__ == "__main__":
    main()
