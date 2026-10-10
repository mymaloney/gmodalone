"""
Shared test helpers.

Lua tests run the gamemode's real files under LuaJIT (lupa) against small
stubs of the GMod API; each tests/lua/*.lua file is one self-contained
scenario. Files are loaded with their in-game chunk names
("gamemodes/hl2alone/gamemode/..."), so the instrumentation treats them as
the gamemode's own.
"""
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
GM = REPO / "gmod" / "gamemodes" / "hl2alone" / "gamemode"
sys.path.insert(0, str(REPO / "tools"))

try:
    from lupa import luajit21 as _lua
except ImportError:  # pragma: no cover
    _lua = None


def new_lua():
    if _lua is None:
        pytest.skip("lupa with LuaJIT not installed (pip install lupa)")
    rt = _lua.LuaRuntime(unpack_returned_tuples=True)
    loader = rt.eval('''function( src, name )
        local f, err = loadstring( src, "@gamemodes/hl2alone/gamemode/" .. name )
        if not f then error( err, 2 ) end
        return f()
    end''')
    g = rt.globals()
    g.GM_LOAD = lambda rel: loader((GM / rel).read_text(encoding="utf-8"), rel)
    g.REPO_READ = lambda rel: (REPO / rel).read_text(encoding="latin-1")
    return rt


@pytest.fixture
def lua():
    return new_lua()
