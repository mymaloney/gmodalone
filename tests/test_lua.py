"""Runs each tests/lua/test_*.lua scenario: the gamemode's real modules on GMod stubs."""
from pathlib import Path

import pytest

from conftest import new_lua

HERE = Path(__file__).resolve().parent / "lua"
SCENARIOS = sorted(HERE.glob("test_*.lua"))


@pytest.mark.parametrize("path", SCENARIOS, ids=lambda p: p.stem)
def test_scenario(path):
    rt = new_lua()
    run = rt.eval('''function( src, name )
        local f, err = loadstring( src, "@" .. name )
        if not f then error( err, 0 ) end
        f()
    end''')
    run((HERE / "stubs.lua").read_text(encoding="utf-8"), "tests/lua/stubs.lua")
    run(path.read_text(encoding="utf-8"), f"tests/lua/{path.name}")
