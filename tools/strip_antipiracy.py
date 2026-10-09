#!/usr/bin/env python3
r"""
Remove the mod's anti-piracy check from its maps.

Many maps carry a logic_auto that, on every map spawn, shows game_texts
("play this by downloading this on moddb.com/mods/half-life-2-alone-mod",
"dont play it on whatever your playing it on") and then fires "quit". This
rewrites each map's entity lump without it:

  * text entities (game_text, env_message, ...) named text_error* or whose
    message is one of those texts are deleted;
  * outputs that target a deleted entity, carry one of those texts, or fire
    "quit" / "exit" through a Command input are deleted (other commands in
    the same output are kept).

Nothing else in the map changes. An uncompressed entity lump is rewritten in
place at the same size (padded with whitespace); a compressed one is
written uncompressed at the end of the file. Running it twice is harmless.

Entity-lump override files (maps/<map>_l_0.lmp), which replace a map's
entities when present, are patched the same way.

build_addon.py runs this on every map it copies. To find and fix every copy
GMod might load (garrysmod/maps/ wins over addons, and the cubemap rebuild
saves unpatched maps there), point it at your whole garrysmod folder:
  python tools/strip_antipiracy.py "C:/GarrysMod/garrysmod" --dry-run   (just list)
  python tools/strip_antipiracy.py "C:/GarrysMod/garrysmod"             (fix them)
  python tools/strip_antipiracy.py path/to/one_map.bsp
--deep also searches the rest of each map file (e.g. its packed files)
and reports any other place the text appears.
"""

import argparse
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_assets import read_entity_lump  # noqa: E402

PIRACY_TEXT = re.compile(r"moddb\.com/mods/half-life-2-alone|whatever your playing it on", re.I)
TEXT_CLASSES = {"game_text", "env_message", "point_message", "env_hudhint", "game_text_tf"}
QUIT_COMMANDS = {"quit", "exit", "disconnect"}

BLOCK = re.compile(r"\{[^{}]*\}")
KV_LINE = re.compile(r'^(\s*)"([^"]*)"\s+"([^"]*)"\s*$')


def _parts(value: str):
    sep = "\x1b" if "\x1b" in value else ","
    parts = value.split(sep)
    return (sep, parts) if len(parts) >= 5 else (None, None)


def _block_kvs(block: str):
    return [(m.group(2), m.group(3)) for m in (KV_LINE.match(l) for l in block.splitlines()) if m]


def strip_text(text: str):
    """Returns (new entity text, entities removed, outputs removed or changed)."""
    blocks = list(BLOCK.finditer(text))

    # 1. Which entities go
    doomed_spans, doomed_names = set(), set()
    for m in blocks:
        kvs = _block_kvs(m.group(0))
        d = {k.lower(): v for k, v in kvs}
        cls = d.get("classname", "").lower()
        name = d.get("targetname", "")
        if cls == "worldspawn":
            continue
        by_name = cls in TEXT_CLASSES and name.lower().startswith("text_error")
        by_text = any(k.lower() in ("message", "text") and PIRACY_TEXT.search(v) for k, v in kvs)
        if by_name or by_text:
            doomed_spans.add(m.span())
            if name:
                doomed_names.add(name.lower())

    # 2. Rebuild, dropping those entities and the outputs that feed them or quit
    out, pos, outputs = [], 0, 0
    for m in blocks:
        out.append(text[pos:m.start()])
        pos = m.end()
        if m.span() in doomed_spans:
            continue
        lines = []
        for line in m.group(0).split("\n"):
            km = KV_LINE.match(line.rstrip("\r"))
            sep, parts = _parts(km.group(3)) if km else (None, None)
            if parts:
                target, inp, param = parts[0].lower(), parts[1].lower(), parts[2]
                if target in doomed_names or PIRACY_TEXT.search(param):
                    outputs += 1
                    continue
                if inp == "command":
                    cmds = [c for c in param.split(";") if c.strip()]
                    kept = [c for c in cmds if c.strip().split(" ")[0].lower() not in QUIT_COMMANDS]
                    if len(kept) != len(cmds):
                        outputs += 1
                        if not kept:
                            continue
                        parts[2] = ";".join(kept).strip()
                        cr = "\r" if line.endswith("\r") else ""
                        line = f'{km.group(1)}"{km.group(2)}" "{sep.join(parts)}"{cr}'
            lines.append(line)
        out.append("\n".join(lines))
    out.append(text[pos:])
    return "".join(out), len(doomed_spans), outputs


def patch_bsp(path: Path, dry_run: bool = False):
    """Strips the check from one map. Returns (entities removed, outputs changed)."""
    text = read_entity_lump(path)
    new, ents, outputs = strip_text(text)
    if (ents == 0 and outputs == 0) or dry_run:
        return ents, outputs

    with open(path, "r+b") as f:
        header = f.read(8 + 16)
        ofs, length, version, fourcc = struct.unpack_from("<iiii", header, 8)
        f.seek(ofs)
        compressed = f.read(4) == b"LZMA"
        data = new.encode("latin-1")
        if not compressed and len(data) + 1 <= length:
            f.seek(ofs)
            f.write(data + b" " * (length - 1 - len(data)) + b"\0")
        else:
            f.seek(0, 2)
            end = f.tell()
            pad = (-end) % 4
            f.write(b"\0" * pad)
            f.write(data + b"\0")
            f.seek(8)
            f.write(struct.pack("<iiii", end + pad, len(data) + 1, version, 0))
    return ents, outputs


LMP_HEADER = struct.Struct("<iiiii")  # offset, lump id, version, length, map revision


def patch_lmp(path: Path, dry_run: bool = False):
    """Same as patch_bsp for an entity-lump override file (<map>_l_0.lmp)."""
    data = path.read_bytes()
    ofs, lump_id, version, length, revision = LMP_HEADER.unpack_from(data)
    if lump_id != 0:
        return 0, 0
    text = data[ofs:ofs + length].split(b"\0", 1)[0].decode("latin-1")
    new, ents, outputs = strip_text(text)
    if (ents or outputs) and not dry_run:
        body = new.encode("latin-1") + b"\0"
        path.write_bytes(LMP_HEADER.pack(LMP_HEADER.size, 0, version, len(body), revision) + body)
    return ents, outputs


PHRASE = re.compile(rb"moddb\.com/mods/half-life-2-alone|whatever your playing it on", re.I)


def deep_hits(path: Path):
    """Offsets where the text appears anywhere in the file (packed files are often stored uncompressed)."""
    return [m.start() for m in PHRASE.finditer(path.read_bytes())]


def patch_tree(root: Path, dry_run: bool = False, quiet: bool = False, deep: bool = False):
    """Patches every .bsp and entity .lmp under root; returns (files changed, files scanned)."""
    if root.is_dir():
        files = sorted(list(root.rglob("*.bsp")) + list(root.rglob("*_l_0.lmp")))
    else:
        files = [root]
    changed = 0
    for f in files:
        try:
            fn = patch_lmp if f.suffix.lower() == ".lmp" else patch_bsp
            ents, outputs = fn(f, dry_run)
        except Exception as e:  # noqa: BLE001 - report and carry on
            print(f"warning  {f}: {e}")
            continue
        shown = f if not root.is_dir() else f.relative_to(root)
        if ents or outputs:
            changed += 1
            if not quiet:
                print(f"{'found   ' if dry_run else 'stripped'} {shown}: {ents} entities, {outputs} outputs")
        if deep:
            left = deep_hits(f)
            if left:
                print(f"{'text in ' if dry_run else 'still in'} {shown} at byte {', '.join(map(str, left[:5]))}"
                      + ("" if dry_run else " (outside the entity data: tell the port's author)"))
    return changed, len(files)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", type=Path, nargs="+", help="a .bsp/.lmp, or folders searched for them (e.g. your garrysmod folder)")
    ap.add_argument("--dry-run", action="store_true", help="only list what has the anti-piracy check")
    ap.add_argument("--deep", action="store_true", help="also search the whole of each map file for the text")
    args = ap.parse_args()
    for path in args.paths:
        if not path.exists():
            sys.exit(f"Not found: {path}")
        changed, total = patch_tree(path, args.dry_run, deep=args.deep)
        print(f"done     {path}: {changed} of {total} map files {'have the check' if args.dry_run else 'changed'}")


if __name__ == "__main__":
    main()
