# Changelog

Git history starts at v0.2.1. Earlier versions were developed before the
folder was under version control; their history is recorded here.

## v0.3.0 - 2026-10-27
- Usage XP: implants learn from doing their own job while fighting
  (RAM spent, damage taken, healing, stamina spent, kills, and
  Sandevistan / Berserk / Kerenzikov activations), per body area.
- Mastery: at Lv 5 every implant adds a second, area-specific bonus.
- Ripperdoc services: with the ripperdoc screen open, pay eddies in the
  Living Chrome window to stabilize a Glitchy implant or re-roll a quirk.
- Malfunctions differ by body area: Optics Fault, RAM Leak, Motor Stutter,
  Plating Fault, Servo Jam. `forceMalfunction(kind)` tests each one.
- Window and `status()` group implants by quirk (Glitchy, Tuned, Clean)
  with colored headers, plus STABLE / MASTERED tags.
- Settings in the Living Chrome window and, with Native Settings UI, in the
  game's Settings menu; saved to `living_chrome_settings.txt`.
- On-screen messages queue instead of overwriting each other; simultaneous
  level-ups become one message.
- Balance: leveling is slower (400 / 1100 / 2200 / 3800 / 6000 XP, was
  150 / 400 / 800 / 1400 / 2200) and combat time gives 0.5 XP/s (was 1),
  since usage XP now adds on top. Existing levels are kept.
- Save file gains an 8th column (stable flag); older files still load.

Tested in-game 2026-10-27 (game 2.5, CET 1.38.1): loads without errors, all
five malfunction types, ripperdoc stabilize / re-roll at a real ripperdoc,
mastery and STABLE / MASTERED tags, settings saved. Not yet seen in-game:
XP from Sandevistan / Berserk / Kerenzikov activations, switching to a second
playthrough.

## v0.2.1 - 2026-10-27
- Fix: upgrading an implant no longer resets its level. Any tier ending on an
  item ID (`Plus`, `Common`..`Legendary` + digits, `C#MK#`, `MK#`) is stripped,
  so every tier of an implant shares one record. Old tier-specific records are
  merged on load, keeping the higher XP.
- Fix: reloading a save that was never saved with its playthrough ID no longer
  re-rolls every quirk. Untagged saves are remembered by a character
  fingerprint (lifepath, gender, level, street cred, money, position) and get
  their ID back when loaded again.

## v0.2.0 - 2026-10-27
- Per-playthrough progress: each save gets a hidden ID (quest fact
  `living_chrome_save_id`) and its own `living_chrome_save_<id>.txt`.
  v0.1.0 shared progress is imported into the first playthrough automatically;
  `importOld()` moves it to another one.
- Save safety: stat bonuses are never written into saves; the malfunction
  screen glitch is tracked with a quest fact and removed on load if a save
  caught it; the story's own copy of the effect is never touched.
- `uninstall()` removes all bonuses and effects before removing the mod.
- `clearGlitch()` removes a stuck malfunction screen glitch.
- Fixes found in the first in-game test (game 2.5, CET 1.38.1):
  - `Game.ApplyEffectOnPlayer` / `Game.RemoveEffectPlayer` don't exist in CET
    1.38, so the screen glitch never appeared. Switched to
    `StatusEffectHelper` / `StatusEffectSystem`.
  - Status effects apply a frame later; checking immediately made the mod think
    the glitch failed, apply it twice and never remove it (stuck glitch).
    Now applies once and verifies removal on later frames.

Confirmed in-game: implant scan (names, 22 implants), quirk rolls, XP and
level-ups from combat time and kills, stabilizing, stat bonuses in the
character menu, malfunctions (message, screen glitch on/off, natural combat
rolls), playthrough IDs, migration of old implant keys.

## v0.1.0
- First version: equipped cyberware earns XP from combat time and nearby kills,
  levels 1-5 with a stat bonus per body area.
- Quirks rolled once per implant: Clean / Tuned / Glitchy (Glitchy malfunctions
  in combat until max level).
- CET overlay window with level, XP bar, bonus and kills.
- Progress shared across all saves in one file.
