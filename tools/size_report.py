#!/usr/bin/env python3
r"""
Report what could make the HL2 Alone addon smaller.

  * Size by folder and the largest files.
  * Duplicates: asset files byte-identical (path, size and CRC32) to a file
    in the base games' VPKs. Players have those games mounted, so these can
    be dropped. Same-path files that differ are replacements and are kept.
  * Probably unused: assets nothing references. References are traced from
    the maps (entities, material table, static props, embedded pakfile),
    materials (textures), models (materials, companion files), particles,
    sound scripts / soundscapes / songs, skyboxes, snow .smf files and the
    mod's data. Code can still load files by name (the original DLLs, Lua),
    so review the list before dropping anything.
  * Maps no chapter, level transition or menu background leads to.
  * Size reduction candidates: .wav music (convert to .ogg), uncompressed
    textures (DXT), uncompressed maps (bspzip -repack -compress).

Writes <out>/size_report.md plus plain path lists. duplicates.txt and
unused.txt can be passed to build_addon.py --exclude.

Usage (one line; in PowerShell use ` to continue lines, in cmd.exe ^):
  python tools/size_report.py --assets "C:\mods\HL2_AloneMod" --game "C:\Steam\steamapps\common\Half-Life 2" --game "C:\Steam\steamapps\common\GarrysMod" --out audit
"""

import argparse
import io
import lzma
import re
import struct
import sys
import zipfile
import zlib
from collections import defaultdict, deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_assets import output_parts, parse_entities  # noqa: E402

REPO = Path(__file__).resolve().parent.parent

ASSET_DIRS = ["materials", "models", "sound", "maps", "particles", "scenes", "media", "resource"]

# Prefixes kept regardless: UI and screen effects the DLLs / Lua load by name
KEEP_PREFIXES = (
    "materials/vgui/", "materials/console/", "materials/hud/", "materials/effects/",
    "materials/particle/", "resource/", "particles/hl2alone/",
)

# Files the GMod port itself loads by name
PORT_USES = ("sound/music/credits.wav",)  # amod_startcreditssong

# Content GMod can't use at all (the original's Bink videos: menu
# backgrounds and the outro)
NOT_USABLE_EXTS = (".bik",)

MODEL_COMPANIONS = (".vvd", ".phy", ".ani", ".vtx", ".dx90.vtx", ".dx80.vtx", ".sw.vtx", ".xbox.vtx")
SKY_SIDES = ("rt", "lf", "bk", "ft", "up", "dn")
SOUND_PREFIX_CHARS = ")^*#@<>!?&~+$"

# VTF high-res formats -> (bytes per pixel, has alpha)
UNCOMPRESSED_VTF = {0: (4, True), 1: (4, True), 2: (3, False), 3: (3, False), 11: (4, True),
                    12: (4, True), 16: (4, False)}


def norm(p: str) -> str:
    return p.replace("\\", "/").strip().lower().lstrip("/")


def human(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if abs(n) < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return str(n)


# --- BSP ---------------------------------------------------------------------------

def decompress_lump(data: bytes) -> bytes:
    if data[:4] != b"LZMA":
        return data
    actual, lzma_size = struct.unpack_from("<II", data, 4)
    props = data[12:17]
    d = props[0]
    dec = lzma.LZMADecompressor(lzma.FORMAT_RAW, filters=[{
        "id": lzma.FILTER_LZMA1, "dict_size": struct.unpack_from("<I", props, 1)[0],
        "lc": d % 9, "lp": (d // 9) % 5, "pb": d // 45}])
    return dec.decompress(data[17:17 + lzma_size], max_length=actual)


class Bsp:
    def __init__(self, path: Path):
        self.data = path.read_bytes()
        if self.data[:4] != b"VBSP":
            raise ValueError("not a VBSP file")

    def lump_raw(self, i: int) -> bytes:
        ofs, length, _v, _c = struct.unpack_from("<iiii", self.data, 8 + i * 16)
        return self.data[ofs:ofs + length]

    def lump(self, i: int) -> bytes:
        return decompress_lump(self.lump_raw(i))

    def compressed(self) -> bool:
        return any(self.lump_raw(i)[:4] == b"LZMA" for i in range(64))

    def entities(self):
        return parse_entities(self.lump(0).split(b"\0", 1)[0].decode("latin-1"))

    def materials(self):
        return [norm(s.decode("latin-1")) for s in self.lump(43).split(b"\0") if s]

    def static_prop_models(self):
        gl = self.lump_raw(35)
        if len(gl) < 4:
            return []
        (count,) = struct.unpack_from("<i", gl, 0)
        for k in range(count):
            gid, flags, _ver, ofs, length = struct.unpack_from("<iHHii", gl, 4 + k * 16)
            if gid != 0x73707270:  # 'sprp'
                continue
            data = self.data[ofs:ofs + length]
            if flags & 1:
                data = decompress_lump(data)
            (n,) = struct.unpack_from("<i", data, 0)
            return [norm(data[4 + j * 128:4 + (j + 1) * 128].split(b"\0", 1)[0].decode("latin-1"))
                    for j in range(n)]
        return []

    def pakfile(self):
        raw = self.lump_raw(40)
        try:
            return zipfile.ZipFile(io.BytesIO(raw))
        except zipfile.BadZipFile:
            return None


# --- VPK ---------------------------------------------------------------------------

def read_vpk_dir(path: Path, index: dict):
    """Adds {relative path: (size, crc32)} for every file in a *_dir.vpk."""
    data = path.read_bytes()
    sig, version, tree_size = struct.unpack_from("<III", data, 0)
    if sig != 0x55AA1234:
        return
    pos = 12 if version == 1 else 28

    def cstr():
        nonlocal pos
        end = data.index(b"\0", pos)
        s = data[pos:end].decode("latin-1")
        pos = end + 1
        return s

    while True:
        ext = cstr()
        if not ext:
            break
        while True:
            directory = cstr()
            if not directory:
                break
            while True:
                name = cstr()
                if not name:
                    break
                crc, preload, _arch, _ofs, length, _term = struct.unpack_from("<IHHIIH", data, pos)
                pos += 18 + preload
                rel = (f"{name}.{ext}" if directory.strip() == "" else f"{directory}/{name}.{ext}")
                index[norm(rel)] = (preload + length, crc)


# --- Reference tracing -------------------------------------------------------------

class Tracer:
    def __init__(self, files: dict):
        self.files = files            # rel path -> Path
        self.used = set()
        self.reasons = {}
        self.queue = deque()

    def mark(self, rel: str, why: str) -> bool:
        rel = norm(rel)
        if rel in self.files and rel not in self.used:
            self.used.add(rel)
            self.reasons[rel] = why
            self.queue.append(rel)
        return rel in self.files

    def material(self, name: str, why: str):
        n = norm(name)
        n = re.sub(r"^materials/", "", n)
        n = re.sub(r"\.(vmt|vtf)$", "", n)
        a = self.mark(f"materials/{n}.vmt", why)
        b = self.mark(f"materials/{n}.vtf", why)
        return a or b

    def texture(self, name: str, why: str):
        n = re.sub(r"\.vtf$", "", re.sub(r"^materials/", "", norm(name)))
        self.mark(f"materials/{n}.vtf", why)
        self.mark(f"materials/{n}.hdr.vtf", why)

    def model(self, name: str, why: str):
        n = norm(name)
        if not n.startswith("models/"):
            n = "models/" + n
        if self.mark(n, why):
            base = n[:-4]
            for ext in MODEL_COMPANIONS:
                self.mark(base + ext, why)

    def sound(self, name: str, why: str):
        n = norm(name).lstrip(SOUND_PREFIX_CHARS)
        n = re.sub(r"^sound/", "", n)
        return self.mark("sound/" + n, why)

    def skybox(self, name: str, why: str):
        n = norm(name).split("%")[0]
        for side in SKY_SIDES:
            self.material(f"skybox/{n}{side}", why)
            self.material(f"skybox/{n}_hdr{side}", why)

    def value(self, v: str, why: str, soundscripts: dict):
        """Resolve an arbitrary entity/data string to whatever asset it names."""
        n = norm(v)
        if not n or len(n) > 200:
            return
        if n.endswith(".mdl"):
            self.model(n, why)
        elif n.endswith((".wav", ".mp3", ".ogg")):
            self.sound(n, why)
        elif n.endswith((".vmt", ".spr")):
            self.material(n.replace(".spr", ".vmt"), why)
        elif n.endswith(".pcf"):
            self.mark(n if n.startswith("particles/") else "particles/" + n, why)
        elif n.endswith(".vcd"):
            self.mark(n, why)
        elif n in soundscripts:
            for w in soundscripts[n]:
                self.sound(w, why)
        elif "/" in n:
            self.material(n, why)

    # dependency scanning of used files
    def drain(self):
        while self.queue:
            rel = self.queue.popleft()
            path = self.files[rel]
            why = f"used by {rel}"
            if rel.endswith(".vmt"):
                self.scan_vmt(path.read_text(encoding="latin-1", errors="replace"), why)
            elif rel.endswith(".mdl"):
                try:
                    mats = mdl_materials(path.read_bytes())
                except (struct.error, ValueError) as e:
                    print(f"  couldn't read model {rel}: {e}")
                    mats = []
                for m in mats:
                    self.material(m, why)
            elif rel.endswith(".pcf"):
                for m in re.findall(rb"[\w/\\\-.]+\.vmt", path.read_bytes()):
                    self.material(m.decode("latin-1"), why)

    def scan_vmt(self, text: str, why: str):
        text = re.sub(r"//[^\n]*", "", text)
        for key, quoted, bare in re.findall(r'"?([$%]?\w+)"?[ \t]+(?:"([^"]*)"|([^\s"{}]+))', text):
            k, val = key.lower(), quoted or bare
            if k == "include":
                self.material(val, why)
            elif k.startswith("$") or k.startswith("%"):
                if "/" in val or "\\" in val:
                    self.texture(val, why)
                    self.material(val, why)


def mdl_materials(data: bytes):
    """Material paths a .mdl uses (cdmaterials x texture names)."""
    if data[:4] != b"IDST" or len(data) < 220:
        return []

    def cstr(ofs):
        end = data.find(b"\0", ofs)
        return data[ofs:end].decode("latin-1") if end > ofs else ""

    numtex, texidx, numcd, cdidx = struct.unpack_from("<iiii", data, 204)
    names = []
    for i in range(max(0, min(numtex, 512))):
        base = texidx + i * 64
        if base + 4 > len(data):
            break
        (name_ofs,) = struct.unpack_from("<i", data, base)
        names.append(cstr(base + name_ofs))
    dirs = []
    for i in range(max(0, min(numcd, 64))):
        if cdidx + i * 4 + 4 > len(data):
            break
        (ofs,) = struct.unpack_from("<i", data, cdidx + i * 4)
        dirs.append(cstr(ofs))
    dirs = [d.replace("\\", "/").rstrip("/") for d in dirs] or [""]
    return [(d + "/" + n) if d else n for d in dirs for n in names if n]


# --- Data from the mod (sound scripts, time_info, songs ...) -------------------------

def read_text(p: Path) -> str:
    raw = p.read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    return raw.decode("latin-1")


def script_files(assets: Path):
    roots = [REPO / "scripts", assets / "scripts"]
    for r in roots:
        if r.is_dir():
            yield from (p for p in r.rglob("*.txt") if "backup" not in p.as_posix().lower())


def load_soundscripts(assets: Path):
    """{script name: [waves]} plus every wave named in any script/soundscape."""
    scripts, all_waves = {}, set()
    for p in script_files(assets):
        text = re.sub(r"//[^\n]*", "", read_text(p))
        for name, body in re.findall(r'"([^"{}]+)"\s*\{((?:[^{}]|\{[^{}]*\})*)\}', text):
            waves = re.findall(r'"wave"\s+"([^"]+)"', body, re.I)
            if waves:
                scripts[norm(name)] = waves
        all_waves.update(re.findall(r'"wave"\s+"([^"]+)"', text, re.I))
    return scripts, all_waves


def data_strings(assets: Path):
    """Skies, songs, filters and other asset names in the mod's own data files."""
    skies, songs, filters = set(), set(), set()
    for p in (REPO / "resource").rglob("*.txt"):
        text = read_text(p)
        skies.update(re.findall(r'"Default(?:Night|Day)Sky"\s+"([^"]+)"', text, re.I))
        filters.update(re.findall(r'"FilterName"\s+"([^"]+)"', text, re.I))
        if "songs" in p.as_posix().lower():
            songs.update(re.findall(r'"(music[/\\][^"]+)"', text, re.I))
        if p.name.lower() == "skyboxs.txt":
            skies.update(v for v in re.findall(r'"[^"]+"\s+"([^"]+)"', text))
    return skies, songs, filters


# --- Report ------------------------------------------------------------------------

def wav_seconds(path: Path):
    """Duration of a .wav in seconds, or None if it can't be read. Walks the
    RIFF chunks, since editors often put LIST/bext/etc. before "fmt "."""
    try:
        with path.open("rb") as f:
            head = f.read(12)
            if len(head) < 12 or head[:4] != b"RIFF" or head[8:12] != b"WAVE":
                return None
            while True:
                chunk = f.read(8)
                if len(chunk) < 8:
                    return None
                cid, size = chunk[:4], struct.unpack("<I", chunk[4:])[0]
                if cid == b"fmt ":
                    fmt = f.read(min(size, 16))
                    if len(fmt) < 16:
                        return None
                    _tag, channels, rate, byte_rate, _align, bits = struct.unpack("<HHIIHH", fmt)
                    if byte_rate:
                        return path.stat().st_size / byte_rate  # also right for compressed (ADPCM) wavs
                    if rate and channels and bits:
                        return path.stat().st_size / (rate * channels * bits / 8)
                    return None
                f.seek(size + (size & 1), 1)  # chunks are word-aligned
    except (OSError, struct.error):
        return None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--assets", required=True, type=Path, help="folder with the mod's materials/models/sound/maps")
    ap.add_argument("--game", action="append", type=Path, default=[],
                    help="game folder to compare against (repeatable): its *_dir.vpk files are read")
    ap.add_argument("--out", type=Path, default=Path("audit"))
    args = ap.parse_args()
    assets = args.assets.resolve()
    args.out.mkdir(parents=True, exist_ok=True)

    # Inventory
    files = {}
    for d in ASSET_DIRS:
        root = assets / d
        if root.is_dir():
            for p in root.rglob("*"):
                if p.is_file():
                    files[norm(p.relative_to(assets).as_posix())] = p
    sizes = {rel: p.stat().st_size for rel, p in files.items()}
    total = sum(sizes.values())
    print(f"inventory: {len(files)} files, {human(total)}")

    # Base game VPKs
    vpk_index = {}
    for g in args.game:
        for v in g.rglob("*_dir.vpk"):
            try:
                read_vpk_dir(v, vpk_index)
            except Exception as e:  # noqa: BLE001
                print(f"  skipped {v}: {e}")
    print(f"base games: {len(vpk_index)} files indexed from {len(args.game)} folder(s)")

    duplicates, replacements = [], set()
    for rel, p in files.items():
        hit = vpk_index.get(rel)
        if hit:
            if hit[0] == sizes[rel] and hit[1] == (zlib.crc32(p.read_bytes()) & 0xFFFFFFFF):
                duplicates.append(rel)
            else:
                replacements.add(rel)
    dup_set = set(duplicates)

    # Reference tracing
    tracer = Tracer(files)
    soundscripts, all_waves = load_soundscripts(assets)
    skies, songs, filters = data_strings(assets)

    for rel in files:
        if rel.startswith(KEEP_PREFIXES):
            tracer.mark(rel, "kept: UI / effects loaded by name")
        elif rel in replacements:
            tracer.mark(rel, "replaces a stock game file")
    for w in all_waves:
        tracer.sound(w, "sound script / soundscape")
    for s in songs:
        tracer.sound(s, "songs list")
    for s in skies:
        tracer.skybox(s, "time_info / Skyboxs.txt")

    # Maps, keyed by path under maps/ ("bonus/x"); the mod's data uses the plain name
    maps = {rel[5:-4]: p for rel, p in files.items() if rel.startswith("maps/") and rel.endswith(".bsp")}
    base_of = {m: m.split("/")[-1] for m in maps}
    by_base = defaultdict(list)
    for m, b in base_of.items():
        by_base[b].append(m)

    def resolve_map(name):
        """Chapter / transition target -> map keys it can mean."""
        n = norm(name)
        return [n] if n in maps else by_base.get(n.split("/")[-1], [])

    for rel in PORT_USES:
        tracer.mark(rel, "loaded by the GMod port")
    map_info, reachable = {}, set()
    cc_used = {norm(f) for f in filters} | {"scripts/colorcorrection/cc_epic_filter.raw"}

    # Maps the player can reach: chapters, menu backgrounds, then level transitions
    for cfg in (REPO / "cfg").rglob("chapter*.cfg"):
        for m in re.findall(r"\bmap\s+([\w\-/\\]+)", cfg.read_text(errors="replace")):
            reachable.update(resolve_map(m))
    reachable.update(m for m, b in base_of.items() if b.startswith("background") or b == "portal_background")

    for name, p in sorted(maps.items()):
        why = f"map {name}"
        try:
            bsp = Bsp(p)
            info = {"compressed": bsp.compressed(), "targets": set()}
            ents = bsp.entities()
            map_materials = bsp.materials()
        except Exception as e:  # noqa: BLE001 - report and carry on
            print(f"  skipped map {name}: {e}")
            continue
        for kvs in ents:
            d = {k.lower(): v for k, v in kvs}
            cls = d.get("classname", "")
            if cls == "worldspawn" and d.get("skyname"):
                tracer.skybox(d["skyname"], why)
            if cls == "trigger_changelevel" and d.get("map"):
                info["targets"].add(d["map"].lower())
            if cls == "color_correction" and d.get("filename"):
                cc_used.add(norm(d["filename"]))
            for k, v in kvs:
                parts = output_parts(v)
                if parts:
                    if parts[1].lower() == "command":
                        info["targets"].update(m.lower() for m in re.findall(r"(?:changelevel2?|map)\s+([\w\-]+)", parts[2]))
                    continue
                tracer.value(v, why, soundscripts)
        for m in map_materials:
            tracer.material(m, why)
            base = re.sub(rf"^maps/({re.escape(name)}|{re.escape(base_of[name])})/", "", m)
            base = re.sub(r"(_wvt_patch|_-?\d+_-?\d+_-?\d+)$", "", base)
            tracer.material(base, why)
        try:
            for mdl in bsp.static_prop_models():
                tracer.model(mdl, why)
        except (struct.error, ValueError, lzma.LZMAError) as e:
            print(f"  couldn't read static props of {name}: {e}")
        try:
            pak = bsp.pakfile()
            for zi in (pak.infolist() if pak else []):
                if zi.filename.lower().endswith(".vmt"):
                    tracer.scan_vmt(pak.read(zi).decode("latin-1", "replace"), f"{why} (embedded material)")
        except (zipfile.BadZipFile, NotImplementedError, OSError, ValueError) as e:
            print(f"  couldn't read embedded content of {name}: {e}")
        for ext in (".nav", ".ain"):
            tracer.mark(f"maps/{name}{ext}", why)
            tracer.mark(f"maps/graphs/{base_of[name]}{ext}", why)
        smf = f"maps/snow_materials/{base_of[name]}.smf"
        if tracer.mark(smf, why):
            for v in re.findall(r'"Value"\s+"([^"]+)"', read_text(files[smf]), re.I):
                tracer.texture(v, f"snow materials of {name}")
                tracer.material(v, f"snow materials of {name}")
        map_info[name] = info
        tracer.drain()

    tracer.drain()

    # Reachable maps: follow transitions from the entry points
    frontier = list(reachable)
    while frontier:
        m = frontier.pop()
        for t in map_info.get(m, {}).get("targets", ()):
            for k in resolve_map(t):
                if k not in reachable:
                    reachable.add(k)
                    frontier.append(k)
    unreachable = sorted(m for m in maps if m not in reachable)

    # Maps are reported separately, not as unused; files named after a map go with it
    plain_names = set(base_of.values())
    for rel in files:
        if rel.startswith("maps/") and (rel.endswith(".bsp") or rel.split("/")[-1].split(".")[0] in plain_names):
            tracer.mark(rel, "map")

    not_usable = sorted(rel for rel in files if rel.endswith(NOT_USABLE_EXTS))
    unused = sorted(rel for rel in files
                    if rel not in tracer.used and rel not in dup_set and rel not in not_usable)

    # Colour-correction filters in the repo (copied by build_addon.py)
    cc_files = {norm(p.relative_to(REPO).as_posix()): p.stat().st_size
                for p in (REPO / "scripts" / "colorcorrection").rglob("*.raw")}
    cc_unused = sorted(c for c in cc_files if c not in cc_used)

    # Reduction candidates
    music = []
    for rel in files:
        if rel.endswith(".wav") and (rel.startswith("sound/music/") or any(norm(s).endswith(rel[6:]) for s in songs)):
            secs = wav_seconds(files[rel])
            music.append((rel, sizes[rel], secs))
    music.sort(key=lambda m: -m[1])
    music_bytes = sum(m[1] for m in music)
    music_ogg = sum((m[2] or 0) * 16000 for m in music)  # ~128 kbit/s Vorbis

    vtfs = []
    for rel in files:
        if rel.endswith(".vtf") and sizes[rel] > 256 * 1024 and rel not in dup_set:
            try:
                with files[rel].open("rb") as f:
                    head = f.read(64)
            except OSError:
                continue
            if head[:4] == b"VTF\0" and len(head) >= 56:
                fmt = struct.unpack_from("<i", head, 52)[0]
                if fmt in UNCOMPRESSED_VTF:
                    bpp, alpha = UNCOMPRESSED_VTF[fmt]
                    vtfs.append((rel, sizes[rel], sizes[rel] / bpp * (1.0 if alpha else 0.5)))
    vtfs.sort(key=lambda v: -v[1])

    uncompressed_maps = [(m, sizes[f"maps/{m}.bsp"]) for m, i in map_info.items() if not i["compressed"]]

    # --- write ---------------------------------------------------------------------
    def size_of(paths):
        return sum(sizes.get(p, 0) for p in paths)

    by_top = defaultdict(int)
    by_second = defaultdict(int)
    for rel, s in sizes.items():
        parts = rel.split("/")
        by_top[parts[0]] += s
        by_second["/".join(parts[:2]) if len(parts) > 2 else parts[0]] += s

    L = ["# HL2 Alone size report", "",
         f"Asset folder: {len(files)} files, **{human(total)}**.", "",
         "| Option | Saves | List |", "|---|---|---|",
         f"| Drop duplicates of base game files | {human(size_of(duplicates))} ({len(duplicates)} files) | `duplicates.txt` |",
         f"| Drop content GMod can't use (Bink videos) | {human(size_of(not_usable))} ({len(not_usable)} files) | `not_usable.txt` |",
         f"| Drop probably-unused assets (review first) | {human(size_of(unused))} ({len(unused)} files) | `unused.txt` |",
         f"| Drop unused colour-correction filters | {human(sum(cc_files[c] for c in cc_unused))} ({len(cc_unused)} files) | `unused.txt` |",
         f"| Drop unreachable maps (review first) | {human(sum(sizes[f'maps/{m}.bsp'] for m in unreachable))} ({len(unreachable)} maps) | `unreachable_maps.txt` |",
         f"| Drop menu-background maps (GMod can't use them as menu backgrounds) | {human(sum(sizes[f'maps/{m}.bsp'] for m in maps if base_of[m].startswith('background') or base_of[m] == 'portal_background'))} | n/a |",
         f"| Convert .wav music to .ogg | ~{human(max(0, music_bytes - music_ogg))} ({len(music)} files) | `music_wav.txt` |",
         f"| Compress uncompressed textures to DXT | ~{human(sum(v[1] - v[2] for v in vtfs))} ({len(vtfs)} files) | `uncompressed_vtf.txt` |",
         f"| Compress maps (`bspzip -repack -compress`) | ~{human(sum(s for _, s in uncompressed_maps) * 0.4)} ({len(uncompressed_maps)} maps, ~40% estimate) | n/a |",
         "",
         "Savings overlap a little (e.g. an unused .wav counts in both rows). "
         "Workshop downloads are compressed further on top of this.", "",
         "## Size by folder", "", "| Folder | Size |", "|---|---|"]
    L += [f"| {k} | {human(v)} |" for k, v in sorted(by_second.items(), key=lambda kv: -kv[1])[:30]]
    L += ["", "## Largest files", "", "| File | Size | Status |", "|---|---|---|"]
    for rel, s in sorted(sizes.items(), key=lambda kv: -kv[1])[:30]:
        status = ("duplicate" if rel in dup_set else "not usable in GMod" if rel in not_usable
                  else "unused?" if rel in unused else tracer.reasons.get(rel, ""))
        L.append(f"| {rel} | {human(s)} | {status} |")
    L += ["", "## Probably unused, by folder", "",
          "Nothing in the maps or the mod's data refers to these. The original DLLs or the Lua could "
          "still load some by name; scan the list before excluding it.", "",
          "| Folder | Files | Size |", "|---|---|---|"]
    folder_unused = defaultdict(list)
    for rel in unused:
        folder_unused["/".join(rel.split("/")[:2])].append(rel)
    for k, v in sorted(folder_unused.items(), key=lambda kv: -size_of(kv[1]))[:40]:
        L.append(f"| {k} | {len(v)} | {human(size_of(v))} |")
    if unreachable:
        L += ["", "## Maps nothing leads to", "",
              "Not a chapter start, menu background or level-transition target "
              "(test maps, old versions ...):", ""]
        L += [f"- `{m}` ({human(sizes[f'maps/{m}.bsp'])})" for m in unreachable]
    if music:
        L += ["", "## Largest .wav music", ""]
        L += [f"- `{r}` {human(s)}" + (f", {s_ / 60:.1f} min" if s_ else "") for r, s, s_ in music[:15]]

    (args.out / "size_report.md").write_text("\n".join(L) + "\n")
    (args.out / "duplicates.txt").write_text("# identical to a base game file\n" + "\n".join(sorted(duplicates)) + "\n")
    (args.out / "unused.txt").write_text(
        "# not referenced by maps or mod data - review before using with --exclude\n"
        + "\n".join(unused + cc_unused) + "\n")
    (args.out / "not_usable.txt").write_text("# GMod can't play these\n" + "\n".join(not_usable) + "\n")
    (args.out / "unreachable_maps.txt").write_text(
        "# not a chapter, menu background or transition target - review before using with --exclude\n"
        + "\n".join(f"maps/{m}.bsp" for m in unreachable) + "\n")
    (args.out / "music_wav.txt").write_text("\n".join(r for r, _, _ in music) + "\n")
    (args.out / "uncompressed_vtf.txt").write_text("\n".join(r for r, _, _ in vtfs) + "\n")
    print(f"wrote {args.out / 'size_report.md'} and path lists")


if __name__ == "__main__":
    main()
