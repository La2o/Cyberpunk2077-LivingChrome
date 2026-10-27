LIVING CHROME v0.3.0 - Cyberpunk 2077 mod
===========================================

Your cyberware levels up as you use it, and every implant rolls a hidden
quirk the first time you install it.

FEATURES
- Implant XP: every equipped implant earns XP from combat time and nearby
  kills, and extra XP for doing its own job while you fight:
    Frontal Cortex / OS  -> spending RAM (quickhacks); OS also from
                            Sandevistan / Berserk activations
    Nervous System       -> Kerenzikov activations
    Eyes / Hands / Arms  -> kills
    Skeleton / Immune /  -> taking damage
      Integumentary
    Circulatory          -> healing
    Legs / Arms          -> spending stamina (dashing, melee)
- Levels 1-5 each add a bonus based on the implant's body area:
    Frontal Cortex / OS / Eyes    -> Crit Chance
    Nervous System / Arms / Hands -> Crit Damage
    Skeleton / Circulatory        -> Max Health
    Immune / Integumentary        -> Armor
    Legs                          -> Max Stamina
- MASTERY: at Lv 5 an implant adds a second bonus (e.g. +2 Max RAM for the
  OS, +10 Armor for the Skeleton). Shown in the window.
- Quirks (rolled once per implant):
    Clean   (60%) - normal chrome
    Tuned   (25%) - learns 50% faster
    Glitchy (15%) - learns 2x faster and gets 25% bigger bonuses, but
                    malfunctions in combat until it reaches Lv 5 (or a
                    ripperdoc stabilizes it)
- Malfunctions depend on where the implant sits (6 seconds each):
    Eyes                    OPTICS FAULT   screen glitch, -15% Crit Chance
    Frontal Cortex / OS     RAM LEAK       screen glitch, RAM emptied
    Nervous System / Legs   MOTOR STUTTER  Stamina emptied, -10% Crit Chance
    Body systems            PLATING FAULT  -100 Armor
    Hands / Arms            SERVO JAM      -40% Crit Damage, -10% Crit Chance
- RIPPERDOC SERVICES: with a ripperdoc's screen open, open the CET overlay.
  The Living Chrome window lets you pay eddies to:
    Stabilize a Glitchy implant (6000) - no more malfunctions, keeps its perks
    Re-roll an implant's quirk   (3000) - always lands on a different quirk
- In-game window: open the Cyber Engine Tweaks overlay to see your implants
  grouped by quirk, with level, XP bar, bonus, mastery, kills, and STABLE /
  MASTERED tags.
- Settings: in the Living Chrome window (Settings section), and in the game's
  own Settings menu if you have the Native Settings UI mod installed.
  XP rates, malfunction chance/length, screen glitch on/off, on-screen
  messages, ripperdoc prices.
- On-screen messages queue up instead of overwriting each other; several
  level-ups at once show as one message.
- Optional hotkey "Show implant status" (bind it in CET's Hotkeys tab).
- Each playthrough / save has its own implant progress.
- Works alongside Wannabe Edgerunner and Cyberware-EX.

REQUIREMENTS
- Cyberpunk 2077 (PC, patch 2.5)
- Cyber Engine Tweaks 1.38 or newer
- Optional: Native Settings UI (adds a Living Chrome tab to Settings)

INSTALL
1. Install Cyber Engine Tweaks first.
2. Open your Cyberpunk 2077 game folder (Steam: right-click the game >
   Manage > Browse local files).
3. Copy the "bin" folder from this zip into that folder and merge when asked.
   You should end up with:
   Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\mods\LivingChrome\init.lua
4. Launch the game. The CET console should say "[Living Chrome] v0.3.0 loaded."
   After loading a save it also says "Playthrough <number> loaded."

CONSOLE COMMANDS (CET console)
  GetMod("LivingChrome").status()           list implants and progress
  GetMod("LivingChrome").addXp(500)         test: add XP to equipped implants
  GetMod("LivingChrome").forceMalfunction() test: trigger a malfunction
  GetMod("LivingChrome").forceMalfunction("limbs")
                                            test one type: optics, cortex,
                                            neural, body or limbs
  GetMod("LivingChrome").reset()            wipe progress and quirks (this save only)
  GetMod("LivingChrome").importOld()        copy your v0.1.0 progress into this save
  GetMod("LivingChrome").clearGlitch()      fix a malfunction screen glitch that won't go away
  GetMod("LivingChrome").uninstall()        remove all bonuses/effects before uninstalling

NOTES
- Leveling takes 400 / 1100 / 2200 / 3800 / 6000 total XP for Lv 1-5.
  Levels earned before v0.3.0 (when it was faster) are kept.
- Progress is stored per playthrough in living_chrome_save_<number>.txt files
  inside the mod folder. The number is a hidden tag stored in your game save,
  so saves made from the same playthrough share progress, and a new game
  starts fresh. Save your game once after loading so the tag sticks (reloading
  the exact same save before then keeps the same progress and quirks).
- Your settings are kept in living_chrome_settings.txt in the mod folder.
- UPDATING FROM v0.1.0: the first save you load takes over your old progress
  automatically (the old file is kept as living_chrome_data_old.txt). To give
  that progress to a different playthrough, load it and run importOld() in
  the CET console.
- Upgrading an implant to a higher tier keeps its level and quirk. (Swapping
  between models of the same implant, e.g. different Berserks, also keeps it.)
- More balance numbers are at the top of init.lua under "config".

SAFETY / UNINSTALLING
- Stat bonuses and malfunction penalties are never written into your game
  save; the mod re-adds bonuses each time you load. Remove the mod and they
  are simply gone.
- The malfunction screen glitch is only added if V doesn't already have that
  effect from the story, and if a save happens mid-glitch it is removed the
  next time you load with the mod installed. You can turn the screen glitch
  off in Settings.
- The only thing left in your save is a hidden ID number the game ignores.
- Clean uninstall: load your save, run GetMod("LivingChrome").uninstall()
  in the CET console, save the game, quit, then delete the LivingChrome
  folder. (Just deleting the folder also works in almost every case.)
- Reinstalling later picks your progress back up, since the progress files
  and the save's ID are kept.
- As with any mod, back up your saves before trying it:
  %USERPROFILE%\Saved Games\CD Projekt Red\Cyberpunk 2077
