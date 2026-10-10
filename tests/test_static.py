"""Checks that need no game: the Lua compiles, follows the gamemode's rules, and the tools parse."""
import ast
import re

import pytest

from conftest import GM, REPO, new_lua

LUA_FILES = sorted(GM.parent.rglob("*.lua"))


@pytest.mark.parametrize("path", LUA_FILES, ids=lambda p: str(p.relative_to(GM.parent)))
def test_lua_compiles(path):
    rt = new_lua()
    err = rt.eval('function(s, n) local f, e = loadstring(s, "@" .. n) return e end')(
        path.read_text(encoding="utf-8"), str(path.name))
    assert err is None, err


def test_hooks_not_registered_by_name():
    """hook.Add(event, id, someFunction): if that function ever returns a value (loadCarry
    returned false), GMod stops running the event's other hooks. Wrap it: function() f() end."""
    bad = []
    pat = re.compile(r'hook\.Add\(\s*"(\w+)",\s*"[^"]*",\s*([A-Za-z_][\w.:]*)\s*\)')
    for path in LUA_FILES:
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            m = pat.search(line)
            if m:
                bad.append(f"{path.relative_to(GM.parent)}:{n}: {line.strip()}")
    assert not bad, "hooks registered by name:\n" + "\n".join(bad)


def test_every_module_is_loaded():
    shared = (GM / "shared.lua").read_text(encoding="utf-8")
    listed = set(re.findall(r'"((?:core|modules)/[\w.]+\.lua)"', shared))
    present = {p.relative_to(GM).as_posix() for p in list((GM / "core").glob("*.lua")) + list((GM / "modules").glob("*.lua"))}
    assert present - listed == set(), f"not in shared.lua FILES: {sorted(present - listed)}"
    assert listed - present == set(), f"listed but missing: {sorted(listed - present)}"


def test_instrumentation_loads_first():
    shared = (GM / "shared.lua").read_text(encoding="utf-8")
    files = re.findall(r'^\s*"((?:core|modules)/[\w.]+\.lua)"', shared, re.M)
    assert files[0] == "core/sh_instrument.lua"


@pytest.mark.parametrize("path", sorted((REPO / "tools").glob("*.py")), ids=lambda p: p.name)
def test_tools_parse(path):
    ast.parse(path.read_text(encoding="utf-8"))
