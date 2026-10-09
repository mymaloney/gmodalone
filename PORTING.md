# Porting Half-Life 2: Alone to Garry's Mod

The Source mod's own features (day/night, weather, epic filter, flashlight
flicker, song panel, view bob…) are compiled into `bin/client.dll` and
`bin/server.dll`. GMod can't load mod DLLs, and there is no source for them,
so the port rewrites each feature in Lua as a gamemode, `hl2alone`. It reads
the mod's existing data files (`resource/time_info`, `resource/songs`,
`cfg/…`, sound scripts), so you can keep editing them the same way.

The original Source mod files stay where they are in this repo as the
reference and data source. The port lives in:

```
gmod/                          GMod addon source
  addon.json
  gamemodes/hl2alone/
    hl2alone.txt               gamemode info + start-menu settings
    gamemode/
      shared.lua init.lua cl_init.lua
      core/                    KeyValues parser, data paths, convars, time_info, sound scripts
      modules/                 one file per feature (sv_ / cl_ / sh_ = realm)
tools/
  build_addon.py               assembles the installable addon
  audit_assets.py              scans maps + materials for porting problems
  size_report.py               finds duplicate / unused / convertible assets
```

## Getting started

1. **Mount the base games in GMod** (main menu → game controller icon):
   Half-Life 2, Episode One, Episode Two, plus Portal / Lost Coast if you use
   those maps. The original `gameinfo.txt` mounted these, and GMod does it
   through its mount menu instead.

2. **Build the addon** into your GMod install. `--assets` is the folder
   holding your `materials/`, `models/`, `sound/` and `maps/`:

   ```sh
   python tools/build_addon.py \
       --out "<Steam>/steamapps/common/GarrysMod/garrysmod/addons/hl2alone" \
       --assets "<path to your full HL2 Alone folder>"
   ```

   While you're iterating on Lua, add `--link-lua` so the gamemode folder is
   a symlink to this repo and edits reload live. On Windows this needs
   Developer Mode, or an admin shell.

3. **Run it.** Start GMod, pick **Half-Life 2: Alone** in the gamemode
   selector (bottom right), and Single Player. Load a map like
   `d1_trainstation_01_d`, or from the console: `hl2a_chapter hl2 1`.

4. **Audit your assets** to see what still needs porting:

   ```sh
   python tools/audit_assets.py --assets "<path to your full HL2 Alone folder>" --out audit
   ```

   This writes `audit/audit.md`, which lists custom console commands fired by
   the maps and materials that use shaders GMod doesn't have. Copy
   `audit/hl2alone_entity_classes.txt` to `garrysmod/data/` and run
   `hl2a_entcheck` in the GMod console. It lists the map entities GMod
   can't create.

## Reducing the addon's size

```
python tools/size_report.py --assets "<your full HL2 Alone folder>" --game "<Steam>/steamapps/common/Half-Life 2" --game "<Steam>/steamapps/common/GarrysMod" --out audit
```

Give `--assets` the same folder you pass to `build_addon.py --assets`, so the
lists match when you rebuild. To split long commands over several lines, end
each line with `` ` `` in PowerShell or `^` in cmd.exe.

Each `--game` folder's `*_dir.vpk` archives are read; include every game
the mod mounted (HL2, the episodes, Portal, Lost Coast) and GMod itself,
which bundles HL2 content. `audit/size_report.md` lists:

- **Duplicates:** files byte-identical to a base game file (path, size and
  CRC32). Players already have these. Same-path files that differ are
  replacements and are kept.
- **Probably unused:** assets nothing references, traced from the maps
  (entities, material table, static props, embedded content), materials,
  models, particles, sound scripts, soundscapes, songs, skyboxes, snow
  `.smf` files and the mod's data. The original DLLs or the Lua can still
  load files by name, so review this list. The report also covers unused
  colour-correction filters in this repo.
- **Unreachable maps:** maps that no chapter, level transition or menu
  background leads to. Their assets count as used until you drop the maps
  and re-run.
- **Candidates for conversion:** `.wav` music (to `.ogg`), uncompressed
  textures (to DXT), and uncompressed maps (`bspzip -repack -compress`).

`build_addon.py` already applies the low-risk cleanup by default:

- `tools/cleanup_exclude.txt`, a reviewed list: the Bink outro videos,
  maps nothing leads to, unused colour-correction filters and leftovers.
  Assets for original features (breathing, rain ambience, lightning,
  clouds/stars) are deliberately kept.
  `--no-default-exclude` turns it off.
- Menu-background maps (`maps/backgrounds/`, ~400 MB) are skipped, since
  GMod can't use them as menu backgrounds. `--keep-background-maps` keeps them.

Optional extras:

```
python tools/build_addon.py --out ... --assets ... --clean --music-ogg --exclude audit/duplicates.txt
```

- `--music-ogg` converts `sound/music/*.wav` to `.ogg` with ffmpeg
  (~650 MB smaller; install with `winget install ffmpeg`). Conversions are
  cached in `.cache/`, so later `--clean` builds are fast. The port finds the
  `.ogg` wherever the mod's data or maps still name the `.wav`.
- `--exclude <list>` drops anything else listed, e.g. `duplicates.txt`.

Use `--clean` when changing these, so files from earlier builds don't linger.

## Where things go in the built addon

| Built path | Source | Why |
|---|---|---|
| `gamemodes/hl2alone/` | `gmod/gamemodes/hl2alone/` | Lua gamemode |
| `data_static/hl2alone/…` | `resource/time_info`, `resource/songs`, fogs, thunder, `cfg/**`, `scripts/game_sounds_*` … | Read by Lua. Kept out of `scripts/`, where they would replace stock HL2 sounds in every gamemode. Lowercased; `.cfg` gets `.txt` appended (workshop whitelist). |
| `scripts/soundscapes_amod_*.txt` | `scripts/` | Loaded by the engine (verify; see below) |
| `scripts/colorcorrection/` | `scripts/colorcorrection/` | Loaded by the `color_correction` entity |
| `particles/hl2alone/` | `particles/` + assets | Added with `game.AddParticles` only in this gamemode |
| `resource/fonts/` | `resource/font.ttf`, `gamepadui/fonts` | GMod auto-loads addon fonts |
| `materials/ models/ sound/ maps/ …` | your asset folder | As-is, lowercased |

## Feature status

| Feature | Original | Status | Where |
|---|---|---|---|
| Per-map night atmosphere (skybox, env_sun, fog, filter) | time_info "Night" blocks | **Ported** | `sv_atmosphere.lua`, `cl_fog.lua` |
| Daytime maps (`amod_day`) | time_info "Day" blocks + brightening filter | **Not ported: separate project.** The maps' baked night lighting can't be made to look like day by post-processing (the original only brightened it with `cc_daytime.raw`); doing it properly needs relit maps (VRAD) or a dynamic sun (CSM) | n/a |
| time_info themes (snowey coast, hl2 beta) | time_info subfolders | **Ported:** `hl2a_timeinfo_theme` | `sh_timeinfo.lua` |
| Fog + FogCubeTriggers | client.dll | **Ported**, with blending | `cl_fog.lua` |
| Epic filter / colour correction | client.dll | **Ported** via `color_correction` entity; verify weight changes in-game | `sv_atmosphere.lua` |
| Saturation, vignette | client.dll + custom shader | **Ported** (Lua screen effects) | `cl_view.lua` |
| View bob, stand bob, jump/land punch | client.dll | **Approximated:** tune the formulas | `cl_view.lua`, `sv_player.lua` |
| Flashlight flicker + lag | client.dll | **Ported** (ProjectedTexture) | `cl_flashlight.lua` |
| Rain / snow / ash, intervals | func_precipitation + DLL | **Ported** (Lua particles); rain cfg radius used | `sv_weather.lua`, `cl_weather.lua` |
| Rain / snow / thunder ambience | client.dll soundscape layers (`RainSoundscape`, `RainSoundscapeKV`, `RainVolume`, Snow…/Thunder… keys) | **Ported:** the active soundscape is tracked server-side; its weather soundscape is layered on while it rains/snows (the port's weather, or the map's own `func_precipitation`). Thunder (`amod_weather_thunder`): each strike gets a random distance; close = bright flash, near-instant loud clap; far = dim flash, quieter clap up to ~5 s later | `sv_soundscapes.lua`, `cl_weathersound.lua` |
| Visible breath (`amod_do_breathing`) | server.dll timer + client.dll `amod_do_breath` | **Ported** from disassembly (fog_breath particle, `player/breathe2.wav`) | `sh_breath.lua` |
| Per-map bloom (`BloomEnabled`/`BloomScale`/`BloomScalarFactor`) | time_info + client.dll | **Approximated:** HDR maps scale `mat_bloom_scalefactor_scalar`; LDR maps get a DrawBloom pass. `hl2a_bloom 0` turns it off | `cl_bloom.lua` |
| Map brushes `brush_clouds`, `_brush_night`, `_brush_bg` | server.dll | **Ported** from disassembly | `sv_mappatches.lua` |
| Snow-covered maps (`maps/snow_materials/<map>.smf`, `ShowSnowOnMaps`) | client.dll | **Ported** from disassembly; originals restored on map unload | `cl_snowmaterials.lua` |
| Song panel, songs across levels | client.dll VGUI | **Ported:** basic Derma panel, `ToggleSongPanel` | `cl_music.lua` |
| Sound scripts | `scripts/game_sounds_*` | **Ported** (`sound.Add` at runtime) | `sh_sounds.lua` |
| Localization tokens | UTF-16 `resource/*` | **Ported** (`language.Add`) | `cl_localization.lua` |
| Chapter select | New Game panel + `cfg/<game>/chapterN.cfg` | **Ported:** panel (F1 / `togglenewgamepanel`, auto on background maps) + `hl2a_chapter` | `sh/sv/cl_chapters.lua` |
| HL2 movement speeds, god mode, suit | autoexec / DLL | **Ported** (`hl2a_*speed`, `amod_enable_god`) | `sv_player.lua` |
| Options panel | VGUI `.res` + DLL | **Ported** (`ToggleOptionsPanel`, Options button on chapter select); Daytime, Effects/Credits/Ending left out.  | `sh/sv/cl_options.lua` |
| Mirrored view, hide HUD, footsteps off, strafe roll, soundscapes off | DLL / engine cvars | **Ported** | `cl_options.lua`, `cl_view.lua`, `sh/sv_options.lua` |
| Post-processing: map colour grade (original "epic filter"), Faded TV curve (original TAB "screen filter"), saturation, vignette, bloom | client.dll gamma aliases + colour correction | **Ported**: the TAB filter's gamma curve recovered from disassembly and drawn as a screen effect. The Post-Processing & Effects panel's Look tab has presets (Default, Faded, Cinematic, Noir, Plain) over these; **F2** turns all post-processing on/off | `cl_screenfilter.lua`, `sv_atmosphere.lua`, `cl_effectspanel.lua` |
| Effects panel: view effects (B&W, lens dirt, TV overlays, blur, black boxes, claustrophobia, viewmodel), camera editor (smoothing, offsets, pitch limits), conditional console variables / screen overlays / lights, `.amf` presets, autoload | client.dll (`CEffectsPanel*`, view render code) | **Ported** from disassembly (convars, slider ranges and conversions, draw order, preset format). Lens dirt and blur used custom shaders: lens dirt is redrawn additively from its texture, blur uses GMod's screen blur. Lights parented by *targetname* won't find entities (names aren't networked to the client) | `cl_effects.lua`, `cl_effectspanel.lua`, `sv_effects.lua` |
| Weather panel (weather override/type/intensity/intervals, sun, thunder, breath, night skybox) | VGUI `.res` + client.dll | **Ported** (`toggleweatherpanel`, or the chapter select's Weather button); rain intensity formula and slider ranges from the DLL. The sky angle slider needed engine changes | `cl_weatherpanel.lua` |
| Lightning bolts with thunder | `materials/lightning/*` | **Added:** closer strikes may show a bolt in the clap's direction (the mod's lightning images if present, else a generated bolt); `hl2a_lightning_bolts 0` turns them off | `cl_weathersound.lua` |
| Background panel | VGUI `.res` + DLL | **TODO** (low priority) | n/a |
| Map Properties / Soundscape editors | client.dll | **TODO** (dev tools; low priority) | n/a |
| Clouds, stars, horizon fog (`r_clouds*`, `r_stars*`, `r_horizonfog*`) | engine changes in client.dll + time_info `clouds`/`stars`/`horizon` blocks | **Ported** as Lua meshes drawn after the 2D skybox, using the DLL's defaults and per-map settings. Geometry/UV details are approximations; tune in-game (`hl2a_sky_dump`, `hl2a_sky_reload`) | `cl_sky.lua` |
| GamepadUI main menu, bik menu backgrounds | gamepadui.dll | **Not portable.** GMod's main menu can't be replaced by a gamemode | n/a |
| Achievements (Void Walker, Broken Facility, Workaholic) | server.dll + `logic_achievement` | **Ported:** all 59 map events, toasts, `amod_show_achievements` | `sh/sv/cl_achievements.lua` |
| Episode One core/citadel countdowns (`amod_core_timer`) | server.dll | **Ported** from disassembly | `entities/entities/amod_core_timer.lua`, `sv_timers.lua` |
| Runtime map edits (`ep1_citadel_03_d`) | server.dll | **Ported** from disassembly | `sv_mappatches.lua` |
| Map-fired commands (`quit`, `amod_*`, `startupmenu`) | DLLs / engine | **Ported:** `quit` blocked, the rest handled | `sv/cl_mapcommands.lua` |
| `logic_achievement`, `env_hudhint` (missing in GMod) | engine entities | **Re-created in Lua** | `entities/entities/` |
| Blank `item_item_crate` models | server.dll | **Fixed:** defaults to the stock crate model | `sv_mappatches.lua` |
| Custom water shader (`radialfog_water`, 61 VMTs) | `shaders/fxc` | **Fallback:** build tool rewrites them to stock `Water` | `tools/build_addon.py` |
| Outro video on `ep2_outland_12a_d` (`amod_outrotest`) | server.dll + `.bik` | **Not portable:** the normal fade plays instead | n/a |
| Portal maps (`portal_*`) | Portal entities | **Not portable:** GMod has no portal entities | n/a |
| GeoGuesser mini-game | client.dll | **TODO** | n/a |

## Console commands

| Command | Does |
|---|---|
| `hl2a_chapter <game> <n>` | Load chapter `n` from `cfg/<game>/chapterN.cfg` (`hl2`, `ep1`, `ep2`, `portal`, `bonus`, `"lost coast"`) |
| `togglenewgamepanel` (F1) | Chapter select panel |
| `ToggleOptionsPanel` | Options panel |
| `ToggleEffectsPanel` | Post-Processing & Effects panel (also a button on the Options panel and chapter select) |
| `hl2a_sky_dump`, `hl2a_sky_reload` | Show / re-apply the current map's cloud, star and horizon-fog settings |
| `toggleweatherpanel` | Weather panel (original bind: `t`; also on the chapter select) |
| `hl2a_effects_list`, `hl2a_effects_load <name>`, `hl2a_effects_reset` | List / add / clear Effects panel presets (`data/hl2alone/effects/`, plus the mod's `examples/…`) |
| `Amod_ToggleFilter` / `hl2a_toggle_postprocess` (F2) | Post-processing on/off (`hl2a_postprocess`) |
| `hl2a_look_preset <Default\|Faded\|Cinematic\|Noir\|Plain>` | Apply a look preset; `tf1` / `tf2` switch Faded alone |
| `amod_do_breath` | Breathe once (fog puff + sound) |
| `hl2a_weathersound_debug` | Show the tracked soundscape and the rain/snow/thunder layers playing |
| `hl2a_thunder_test` | One thunder strike at a random distance (flash, delay, clap) |
| `amod_weather_snow_reload` | Re-apply the current map's `.smf` snow materials |
| `hl2a_snow_debug` | Show the current map's `.smf` rules and how many materials each matches |
| `ToggleSongPanel` | Song panel (original bind: `x`) |
| `hl2a_play_song <name>` | Play a song by display name |
| `ToggleEpicFilter` | Toggle colour correction (original bind: `p`) |
| `hl2a_timeinfo_dump` | Show the current map's time_info block |
| `hl2a_entcheck` | Report map entity classes GMod can't create |
| `hl2a_timer <core\|citadel> <seconds\|stop\|show>` | Drive the Episode One countdowns directly (testing) |
| `amod_show_achievements` | Achievement list with progress |
| `hl2a_achievements_reset` | Clear achievement progress |

All `amod_*` convars keep their original names and defaults; see
`core/sh_convars.lua`. GMod doesn't run the mod's `cfg/autoexec.cfg`, so put
any binds you want into your own GMod autoexec.

## What server.dll did at runtime

Some map behaviour isn't in the `.bsp` files at all; `server.dll` applied it
in code. The disassembly found:

- **`ep1_citadel_03_d`:**
  - removes every NPC except bullseyes, all `env_soundscape`s, and the
    advisor, alarm and combine set-pieces
  - adds the `music/away.mp3` song and a 7:30 core-collapse countdown
  - rewires the lift triggers and forces area portals open

  Ported in `sv_mappatches.lua`.
- **`amod_core_timer`:** countdown entity used in 13 ep1 maps. At zero:
  freeze the player, fade to black, explosion, reload the last save. GMod
  saves don't keep Lua state, so after the reload the countdown restarts
  from its full length.
- **`ep2_outland_12a_d`:** the `f_portal` fade plays the outro video
  instead. Not ported.
- **Every map:** removes `brush_clouds`, fires `Enable` on every
  `_brush_night` and resets `_brush_bg` to white. Ported in
  `sv_mappatches.lua`.

The 95 maps that fire `quit` do it from map logic; neither DLL refers to
it. The audit report's "Where traced commands come from" section shows the
exact chain. The port blocks it regardless.

## Things to verify in-game first

These rely on engine behaviour I couldn't test outside GMod:

- **Soundscapes:** GMod should load `scripts/soundscapes_*.txt` from addons.
  If the amod soundscapes don't play, they need registering another way.
  The mod's modified `scripts/soundscapes.txt` (a stock filename) isn't
  copied, to avoid overriding HL2's soundscapes globally. All soundscape
  files are also shipped as data, for the weather layers.
- **Weather soundscape tracking:** `sv_soundscapes.lua` re-implements the
  engine's choice of soundscape (closest in radius and in sight). If the
  rain sounds wrong for a room, compare `hl2a_weathersound_debug` with
  `developer 1` soundscape messages.
- **`data_static` reads:** the Lua reads data via the `DATA` path
  (`data_static/hl2alone/…`), falling back to `GAME`. Check the console at
  startup for `[HL2A] time_info: N maps`. 0 maps means the data isn't being
  found.
- **Colour-correction weight changes:** the filter is re-enabled to apply a
  new intensity. If transitions look wrong, switch to a Lua post-process.
- **Rain materials:** `particle/rain` and `particle/snow` are stock HL2
  materials. A purple checkerboard means they aren't mounted.
- **Map entities:** the maps were compiled for SDK 2013. Run the audit, then
  `hl2a_entcheck`. Anything missing needs a Lua SENT with the same
  classname, or a map edit.
- **Saturation strength:** the original used a custom shader whose strength
  is set in `materials/effects/view/saturation.vmt`. The port approximates
  it with `hl2a_saturation_amount` (default 1.2), so tune that to match.
- **`reload` after the countdown:** the timer runs `reload` to load the last
  save. If GMod refuses it, the player is killed instead, after 2 s.
- **Stock-path overrides:** materials/sounds in your asset folder that reuse
  stock HL2 paths will override them in *every* gamemode while the addon is
  installed.

## Suggested next steps

1. Get one map (`d1_trainstation_01_d`) loading cleanly. Run
   `hl2a_entcheck` for entity classes GMod lacks.
2. Play through `ep1_citadel_03_d` to check the map patch and countdown.
3. Rebuild the Weather/Options panels in Derma using the layouts in
   `resource/panels/` as reference.
4. Achievements and the remaining server.dll features.

## Naming

Player-facing text says "snowy" where the mod wrote "snowey"
(`HL2A.Spell`); map and folder names keep the original spelling, since
level changes and data lookups depend on them. The original's "screen
filter" and "epic filter" aren't called filters in the UI;
they're now effects in the Look tab's presets ("Colour grade", "Faded").
Their convars (`hl2a_screenfilter`, `amod_epic_filter`) keep their names
for compatibility.
