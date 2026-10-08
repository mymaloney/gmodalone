# HL2 Alone size report

Asset folder: 2577 files, **4.2 GB**.

| Option | Saves | List |
|---|---|---|
| Drop duplicates of base game files | 1.8 MB (27 files) | `duplicates.txt` |
| Drop content GMod can't use (Bink videos) | 204.7 MB (2 files) | `not_usable.txt` |
| Drop probably-unused assets (review first) | 61.2 MB (72 files) | `unused.txt` |
| Drop unused colour-correction filters | 4.9 MB (52 files) | `unused.txt` |
| Drop unreachable maps (review first) | 52.7 MB (4 maps) | `unreachable_maps.txt` |
| Drop menu-background maps (GMod can't use them as menu backgrounds) | 402.1 MB | n/a |
| Convert .wav music to .ogg | ~652.3 MB (35 files) | `music_wav.txt` |
| Compress uncompressed textures to DXT | ~245.6 MB (78 files) | `uncompressed_vtf.txt` |
| Compress maps (`bspzip -repack -compress`) | ~1.0 GB (141 maps, ~40% estimate) | n/a |

Savings overlap a little (e.g. an unused .wav counts in both rows). Workshop downloads are compressed further on top of this.

## Size by folder

| Folder | Size |
|---|---|
| maps | 2.0 GB |
| sound/music | 750.5 MB |
| materials/skybox | 472.4 MB |
| maps/backgrounds | 402.0 MB |
| media | 204.7 MB |
| maps/bonus_maps | 126.8 MB |
| materials/vgui | 86.4 MB |
| sound/playonce | 86.2 MB |
| maps/bonus | 74.4 MB |
| sound/ambient | 39.0 MB |
| materials/nature | 4.4 MB |
| materials/effects | 4.0 MB |
| sound/player | 1.5 MB |
| resource/time_info | 1.1 MB |
| materials/models | 1.0 MB |
| materials/ground | 854.3 KB |
| resource | 693.6 KB |
| materials/console | 342.1 KB |
| sound/gman | 327.2 KB |
| models/props_c17 | 312.8 KB |
| sound/physics | 261.9 KB |
| materials/lightning | 257.0 KB |
| models/props_wasteland | 190.8 KB |
| models/weapons | 188.0 KB |
| sound/npc | 159.6 KB |
| resource/localization | 158.7 KB |
| models/propper | 131.4 KB |
| resource/panels | 94.8 KB |
| particles | 75.8 KB |
| resource/vgui base | 49.8 KB |

## Largest files

| File | Size | Status |
|---|---|---|
| media/amod_outrovideo.bik | 140.8 MB | not usable in GMod |
| media/amod_outrovideo2.bik | 63.9 MB | not usable in GMod |
| maps/backgrounds/background01_d.bsp | 61.6 MB | map |
| sound/music/end.wav | 48.3 MB | songs list |
| maps/ep1_citadel_03_d.bsp | 47.3 MB | map |
| sound/music/portal_party_escort.wav | 44.0 MB | songs list |
| maps/backgrounds/background10_d.bsp | 38.4 MB | map |
| maps/ep1_citadel_01_d.bsp | 38.1 MB | map |
| sound/music/portal_android_hell.wav | 38.0 MB | songs list |
| sound/music/portal_self_esteem_fund.wav | 35.5 MB | songs list |
| maps/backgrounds/background07_d.bsp | 35.2 MB | map |
| sound/music/isolation.wav | 35.2 MB | songs list |
| maps/backgrounds/background06_d.bsp | 34.4 MB | map |
| maps/d2_coast_09_d.bsp | 34.4 MB | map |
| sound/music/isolation_reversed.wav | 33.6 MB | songs list |
| sound/music/gone.wav | 31.9 MB | songs list |
| maps/portal_07.bsp | 31.5 MB | map |
| sound/music/lab-practicum.wav | 31.4 MB | songs list |
| maps/backgrounds/background04_d.bsp | 31.1 MB | map |
| maps/backgrounds/background09_d.bsp | 30.8 MB | map |
| maps/bonus_maps/old_ep1_c17_01.bsp | 30.1 MB | map |
| maps/ep2_outland_09_d.bsp | 29.9 MB | map |
| maps/ep1_c17_01_d.bsp | 29.5 MB | map |
| maps/d2_prison_03_d.bsp | 29.4 MB | map |
| sound/music/portal_sef_slowed.wav | 28.6 MB | songs list |
| maps/ep2_outland_08_d.bsp | 28.2 MB | map |
| maps/backgrounds/background05_d.bsp | 27.6 MB | map |
| maps/d2_prison_05_d.bsp | 27.4 MB | map |
| maps/ep1_c17_02a_d.bsp | 26.9 MB | map |
| maps/d2_lostcoast_d.bsp | 26.2 MB | map |

## Probably unused, by folder

Nothing in the maps or the mod's data refers to these. The original DLLs or the Lua could still load some by name; scan the list before excluding it.

| Folder | Files | Size |
|---|---|---|
| sound/music | 2 | 42.2 MB |
| materials/skybox | 17 | 7.0 MB |
| sound/ambient | 5 | 4.8 MB |
| materials/nature | 19 | 4.3 MB |
| sound/playonce | 2 | 2.0 MB |
| materials/ground | 2 | 512.4 KB |
| materials/lightning | 4 | 171.3 KB |
| sound/player | 5 | 139.3 KB |
| models/weapons | 1 | 26.2 KB |
| maps/commentary todo.txt | 1 | 5.5 KB |
| maps/d1_trainstation_01_d_commentary.txt | 1 | 2.6 KB |
| maps/d1_canals_02_d_commentary.txt | 1 | 1.2 KB |
| maps/d1_trainstation_04_d_commentary.txt | 1 | 1.2 KB |
| materials/lostcoast | 1 | 1.1 KB |
| maps/d1_canals_03_d_commentary.txt | 1 | 788 B |
| maps/d1_trainstation_02_d_commentary.txt | 1 | 771 B |
| maps/d1_canals_01_d_commentary.txt | 1 | 460 B |
| maps/d1_trainstation_06_d_commentary.txt | 1 | 406 B |
| maps/d1_trainstation_05_d_commentary.txt | 1 | 404 B |
| maps/d1_canals_07_d_commentary.txt | 1 | 395 B |
| maps/d1_canals_01a_d_commentary.txt | 1 | 391 B |
| models/propper | 1 | 71 B |
| materials/engine | 1 | 69 B |
| media/startupvids.txt | 1 | 0 B |

## Maps nothing leads to

Not a chapter start, menu background or level-transition target (test maps, old versions ...):

- `amod_outro` (10.2 MB)
- `d1_trainstation_01_snowey` (25.2 MB)
- `devtest_thunder` (1.1 MB)
- `portal_08_old` (16.3 MB)

## Largest .wav music

- `sound/music/end.wav` 48.3 MB, 4.8 min
- `sound/music/portal_party_escort.wav` 44.0 MB, 4.4 min
- `sound/music/portal_android_hell.wav` 38.0 MB, 3.8 min
- `sound/music/portal_self_esteem_fund.wav` 35.5 MB, 3.5 min
- `sound/music/isolation.wav` 35.2 MB, 3.5 min
- `sound/music/isolation_reversed.wav` 33.6 MB, 3.3 min
- `sound/music/gone.wav` 31.9 MB, 3.2 min
- `sound/music/lab-practicum.wav` 31.4 MB, 3.1 min
- `sound/music/portal_sef_slowed.wav` 28.6 MB, 5.7 min
- `sound/music/confinement_ver_2.wav` 25.3 MB, 2.5 min
- `sound/music/sef_extended.wav` 22.9 MB, 4.5 min
- `sound/music/alone_extended.wav` 22.4 MB, 4.4 min
- `sound/music/absence_old.wav` 21.9 MB, 4.0 min
- `sound/music/background_song.wav` 20.3 MB, 4.0 min
- `sound/music/under.wav` 20.3 MB, 2.0 min
