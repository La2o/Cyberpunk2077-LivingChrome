# Living Chrome - Cyberpunk 2077 mod

Cyber Engine Tweaks (Lua) mod. The user does not write code; Claude writes it and gives plain install/test steps.

## What it does
- Equipped cyberware earns XP from combat time, nearby kills, and usage per body area (`uses` in AREAS), levels 1-5; Lv 5 adds a mastery bonus.
- Each level adds a stat bonus by body area (see `AREAS` in init.lua).
- Each implant rolls a quirk once: Clean / Tuned (faster XP) / Glitchy (2x XP, bigger bonus, random combat malfunctions until max level).
- Each area has its own malfunction (`fault` in AREAS -> `FAULTS`). Ripperdoc services stabilize / re-roll for eddies.
- CET overlay window shows implants grouped by quirk, level, XP bar, bonus, mastery, kills, ripperdoc buttons, settings.

## Files
- `bin/x64/plugins/cyber_engine_tweaks/mods/LivingChrome/init.lua` - the whole mod. Balance values are in `LC.config` at the top.
- `README.txt` - player-facing install guide (keep it updated).
- Progress saves per playthrough to `living_chrome_save_<id>.txt` in the mod folder. The id is a random int stored in quest fact `living_chrome_save_id` (lives inside the game save). v0.1.0's shared `living_chrome_data.txt` is auto-imported into the first playthrough that gets an id, then renamed to `living_chrome_data_old.txt`.

## Status
- v0.3.0 tested in-game 2026-10-27 and packaged for Nexus (`dist/LivingChrome-0.3.0.zip`, page text in `nexus/`). Confirmed: all fault types, ripperdoc hook + stabilize/re-roll, mastery, settings file. Not yet seen in logs: activation XP ("Implant activation" line), second-playthrough switch. v0.3.0 contents: usage XP (stat-pool polling every 0.5s + `PlayerPuppet.OnStatusEffectApplied` for Sandevistan/Berserk/Kerenzikov buffs), Lv5 mastery bonuses, ripperdoc services (`RipperDocGameController` OnInitialize/OnUninitialize; money via TransactionSystem `Items.money`), malfunction types per area (`FAULTS`), settings (`SETTINGS` table: overlay + optional Native Settings UI), message queue. Uncertain APIs to watch for: `GetStatPoolValue(..., true)` returning percent, `RequestSettingStatPoolValue`, RipperDoc hook firing. Full mocked run: `scratchpad/sim/sim6.py` pattern (fake game + undefined-global detector).
- Git repo: https://github.com/La2o/Cyberpunk2077-LivingChrome (public, branch main; commits use the GitHub noreply email). Release v0.3.0 has the zip. Update CHANGELOG.md with each version.
- Nexus: mod 36175 (https://www.nexusmods.com/cyberpunk2077/mods/36175), account YGSnaffy. PUBLISHED 2026-10-27: description, Gameplay / Quality of Life / AI Assisted tags, 2 gallery images, main file 0.3.0, requirement CET >= 1.38.1. For updates: Files tab > Update, upload the new zip from `dist/`.
- v0.2.0 was tested in-game on 2026-10-27 (game 2.5, CET 1.38.1):
  - Confirmed working: mod loads, playthrough ID, implant scan (22 implants with real names), quirk rolls, addXp/level-ups, stabilizing, malfunction message + screen glitch on and off after 6s, clearGlitch(), real combat XP, kill counting, stat bonuses in the character menu.
  - Not yet tested: switching to another playthrough (Nomad ManualSave-14), uninstall(), and the two v0.2.1 fixes below in-game.
- Test setup on the user's PC: game at `D:\SteamLibrary\steamapps\common\Cyberpunk 2077` (also has RED4ext + Codeware). Copy init.lua there after edits. CET logs: `bin\x64\plugins\cyber_engine_tweaks\scripting.log` (buffered; flushes late). Test save: ManualSave-8 (Street Kid, from Nexus mod 19843; original in the scratchpad/rar).
- CET API lessons: `Game.ApplyEffectOnPlayer` / `Game.RemoveEffectPlayer` do NOT exist in CET 1.38. Use `StatusEffectHelper.ApplyStatusEffect/RemoveStatusEffect(player, TweakDBID)`. Status effects change a frame later, so never check the result in the same frame (that caused a double-applied, stuck glitch).
- v0.2.1 fixes:
  - `baseId` strips any tier ending via `TIER_PATTERNS` (Plus, Common..Legendary + digits, C#MK#, MK#), repeatedly. Old tier-specific keys are merged on load by `normalizeKeys` (keeps higher XP). Side effect: different models of one implant (Berserk C1..C4) share progress.
  - Reload re-roll: an untagged save gets a fingerprint (lifepath, gender, level, street cred, money, position/10m) stored with its new ID in `living_chrome_pending_ids.txt`; loading the same save again reuses the ID. Entry is dropped once a save carrying that ID is loaded. Game's own playthroughID is only exposed to the load-menu UI, not usable.
- Edit-script gotcha: Python heredoc edits once turned backslash-t / backslash-n inside Lua strings into real tab/newline characters (Lua syntax error). init.lua uses spaces only, so after scripted edits check that it contains no tab characters.
- Save safety: StatsSystem:AddModifier is not persisted (re-applied on load). The only persisted things are quest facts `living_chrome_save_id` and `living_chrome_glitch_active` (1 while our JohnnySicknessLow glitch is on; on load, if 1, the effect is removed). The glitch is only applied if the player doesn't already have it (never touch the story's own copy). `uninstall()` strips everything and disables the mod.
- Syntax check: `pip install lupa`, then `load()` the file in a lupa LuaRuntime.
- Every game API call is wrapped in pcall, so failures should be silent rather than crashes. When the user reports CET console errors, fix them first.

## Ideas for next versions
- Black-market "scav chrome" vendor with random modifiers
- Per-implant (not per-area) mastery perks, e.g. Kerenzikov lasts longer
- Package for Nexus Mods (zip with `bin/` at root, README, screenshots)

## Packaging
Zip `bin/` and `README.txt` at the zip root so players can drop `bin` into their Cyberpunk 2077 folder.
