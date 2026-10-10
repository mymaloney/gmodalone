"""The build tools: anti-piracy stripping, the Workshop whitelist, the chapter audit."""
import lzma
import struct
import zlib

import pytest

import build_addon
import chapter_audit
import strip_antipiracy as sa
from audit_assets import read_entity_lump, parse_entities

PIRACY = '''{
"classname" "logic_auto"
"spawnflags" "1"
"OnMapSpawn" "text_error,Display,,0,-1"
"OnMapSpawn" "text_error2\x1bDisplay\x1b\x1b3.5\x1b-1"
"OnMapSpawn" "c,Command,quit,5,-1"
}
{
"classname" "game_text"
"targetname" "text_error"
"message" "play this by downloading this on moddb.com/mods/half-life-2-alone-mod"
}
{
"classname" "game_text"
"targetname" "text_error2"
"message" "dont play it on whatever your playing it on"
}
{
"classname" "logic_relay"
"OnTrigger" "c,Command,fadein 1,2,-1"
"OnTrigger" "c,Command,echo hi; quit,3,-1"
}
{
"classname" "game_text"
"targetname" "intro"
"message" "Chapter 1"
}
'''


def make_bsp(text: str, compressed=False) -> bytes:
    ents = text.encode("latin-1") + b"\0"
    if compressed:
        filt = [{"id": lzma.FILTER_LZMA1, "dict_size": 1 << 16, "lc": 3, "lp": 0, "pb": 2}]
        raw = lzma.compress(ents, format=lzma.FORMAT_RAW, filters=filt)
        props = bytes([(2 * 5 + 0) * 9 + 3]) + struct.pack("<I", 1 << 16)
        lump = b"LZMA" + struct.pack("<II", len(ents), len(raw)) + props + raw
    else:
        lump = ents
    body = b"X" * 64
    ofs = 8 + 64 * 16 + 4
    lumps = [(ofs, len(lump), 0, len(ents) if compressed else 0), (ofs + len(lump), len(body), 0, 0)] + [(0, 0, 0, 0)] * 62
    return b"VBSP" + struct.pack("<i", 20) + b"".join(struct.pack("<iiii", *l) for l in lumps) + struct.pack("<i", 1) + lump + body


def check_stripped(text):
    assert "moddb" not in text and "whatever your" not in text and ",quit," not in text and "text_error" not in text
    assert "fadein 1" in text and "echo hi" in text and "Chapter 1" in text


@pytest.mark.parametrize("compressed", [False, True])
def test_strip_bsp(tmp_path, compressed):
    p = tmp_path / "m.bsp"
    p.write_bytes(make_bsp(PIRACY, compressed))
    size = p.stat().st_size
    assert sa.patch_bsp(p) == (2, 4)
    assert sa.patch_bsp(p) == (0, 0), "running twice is harmless"
    check_stripped(read_entity_lump(p))
    if not compressed:
        assert p.stat().st_size == size, "rewritten in place"
    data = p.read_bytes()
    o, l, _, _ = struct.unpack_from("<iiii", data, 8 + 16)
    assert data[o:o + l] == b"X" * 64, "other lumps untouched"


def test_strip_lmp(tmp_path):
    ents = PIRACY.encode("latin-1") + b"\0"
    p = tmp_path / "m_l_0.lmp"
    p.write_bytes(struct.pack("<iiiii", 20, 0, 0, len(ents), 7) + ents)
    assert sa.patch_lmp(p) == (2, 4)
    data = p.read_bytes()
    ofs, lump_id, _v, length, rev = struct.unpack_from("<iiiii", data)
    assert lump_id == 0 and rev == 7
    check_stripped(data[ofs:ofs + length].split(b"\0")[0].decode("latin-1"))


def test_gma_reported(tmp_path, capsys):
    bsp = make_bsp(PIRACY)
    files = [("maps/x.bsp", bsp)]
    head = b"GMAD" + bytes([3]) + struct.pack("<QQ", 0, 0) + b"\0" + b"t\0d\0a\0" + struct.pack("<i", 1)
    for i, (n, d) in enumerate(files, 1):
        head += struct.pack("<I", i) + n.encode() + b"\0" + struct.pack("<qI", len(d), zlib.crc32(d))
    (tmp_path / "a.gma").write_bytes(head + struct.pack("<I", 0) + bsp)
    changed, _ = sa.patch_tree(tmp_path, dry_run=True)
    assert changed == 1 and "in .gma" in capsys.readouterr().out


@pytest.mark.parametrize("path,ok", [
    ("lua/autorun/x.lua", True), ("maps/d1_canals_01_d.bsp", True), ("maps/graphs/d1_canals_01_d.ain", True),
    ("materials/colorcorrection/cc.raw", True), ("data_static/hl2alone/videos/x.dat", True),
    ("data_static/hl2alone/maps/snow_materials/x.smf.txt", True), ("gamemodes/hl2alone/hl2alone.txt", True),
    ("scripts/colorcorrection/cc.raw", False), ("scripts/soundscapes_amod_canals.txt", False),
    ("html/hl2alone/video.html", False), ("maps/snow_materials/x.smf", False), ("models/x.sw.vtx", False),
    ("gamemodes/hl2alone/gamemode/x.txt", False), ("media/intro.bik", False),
])
def test_workshop_whitelist(path, ok):
    assert build_addon.workshop_allowed(path) == ok


def test_chapter_audit(tmp_path):
    text = '''{
"classname" "info_player_start"
"origin" "0 0 0"
}
{
"classname" "logic_auto"
"OnNewGame" "equip,Use,,0,-1"
}
{
"classname" "game_player_equip"
"targetname" "equip"
"weapon_crowbar" "1"
}
{
"classname" "weapon_pistol"
"origin" "100 0 0"
}
{
"classname" "env_global"
"globalstate" "antlion_allied"
}
{
"classname" "point_servercommand"
"OnUser1" "cmd,Command,give weapon_shotgun,0,-1"
}
'''
    p = tmp_path / "m.bsp"
    p.write_bytes(make_bsp(text))
    lines, globals_, autosaves = chapter_audit.audit(p)
    joined = "\n".join(lines)
    assert "OnNewGame -> equip.Use()  [game_player_equip]" in joined
    assert "weapon_crowbar" in joined and "give weapon_shotgun" in joined and "weapon_pistol x1" in joined
    assert globals_ == ["antlion_allied"] and autosaves == 0
