# Living Chrome - Cyberpunk 2077 mod

Cyber Engine Tweaks (Lua) mod. The user does not write code; Claude writes it and gives plain install/test steps.

## What it does
- Equipped cyberware earns XP from combat time and nearby kills, levels 1-5.
- Each level adds a stat bonus by body area (see `AREAS` in init.lua).
- Each implant rolls a quirk once: Clean / Tuned (faster XP) / Glitchy (2x XP, bigger bonus, random combat malfunctions until max level).
- CET overlay window shows level, XP bar, bonus, kills.

## Files
- `bin/x64/plugins/cyber_engine_tweaks/mods/LivingChrome/init.lua` - the whole mod. Balance values are in `LC.config` at the top.
- `README.txt` - player-facing install guide (keep it updated).
- Progress saves per playthrough to `living_chrome_save_<id>.txt` in the mod folder. The id is a random int stored in quest fact `living_chrome_save_id` (lives inside the game save). v0.1.0's shared `living_chrome_data.txt` is auto-imported into the first playthrough that gets an id, then renamed to `living_chrome_data_old.txt`.

## Status
- v0.2.1 installed in the user's game; v0.2.0 was tested in-game on 2026-10-27 (game 2.5, CET 1.38.1):
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
- Rejection events beyond the glitch effect (weapon jam, brief slowdown)
- Native Settings UI menu for the config values
- Package for Nexus Mods (zip with `bin/` at root, README, screenshots)

## Packaging
Zip `bin/` and `README.txt` at the zip root so players can drop `bin` into their Cyberpunk 2077 folder.
