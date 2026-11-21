## Features

* [x] Test scaling perks on all supported maps.
* [x] Improve Exo Suit movement and slam VFX compatibility across maps.
* [x] Add Cashback Cocktail (Speed Cola).
* [x] Add Ethereal Razor (Juggernog).
* [x] Add Fighter's Fizz (Quick Revive).
* [x] Add Repairman Rum (Speed Cola).
* [x] Add Dam-A-Nade (Juggernog).
* [x] Implement two-page Aim-toggle perk menu for 4-perk machines.
* [x] Add Bandolier Bandit (Stamin-Up): +20% max ammo reserves per upgrade.
* [x] Add Blood Bullets (Stamin-Up): regenerates active clip over time based on clip size.
* [x] Add Nitrogen Cooled (Stamin-Up): slows nearby zombies within radius to a walk temporarily.
* [x] Add Vigor Rush (Double Tap): bullet weapons trigger small localized explosions on zombies.
* [x] Enhance Exo Suit mechanics inspired by Call of Duty: Advanced Warfare (`s1-gsc-dump-main`): -650 downward rocket velocity, drop-height damage/radius scaling, direct crush stomp kills (`MOD_CRUSH`), controller rumble, and mid-air hover stabilization.
* [x] Add Exo Slide mechanic from Call of Duty: Advanced Warfare (`s1-gsc-dump-main`): running/sprinting + Change Stance (`[{+stance}]` / `BUTTON_B`) to slide with crouch lock, 430->190 speed curve, thrusters and dirt friction sound, dust and spark FX, controller slide rumble, direct zombie collision damage, and jump-cancel into double jump.
* [x] Update Credits in README.md (Reaper Collection, Custom Perk Machines).

## Bugs to fix

* [x] Exo Slide Jump Cancel: matched the working sprint-cancel behavior (`self setstance("stand")`), added clean ground liftoff (`+5 Z`) with upward impulse (`280`) preserving slide momentum, and added automatic stance restoration to "stand" on natural slide completion.
* [x] Vigor Rush VFX: reduced to a single 1x instance of `impacts/fx_large_woodhit` (`wood_chunk_destory`) aligned to bullet entry normal, and completely removed the sound effect (`dst_disable_spark`).
* [x] Fix Bandolier Bandit max ammo reserves: implemented stash transfer mechanism feeding directly into reserve when below capacity, supporting `give ammo`, wallbuys, mystery box, and Max Ammo powerups.
* [x] Replace `%` and `%%` with `" percent"` in all HUD `iprintln` messages so percent boosts display properly without font glyph dot errors (`.` / `..`).

* [x] Fix weapon slot compatibility with the custom perk machines mod.
* [x] Fix health compatibility with the custom perk "Bloodthirst" from the custom perk machines mod.
* [x] Fix Perk Deny sound spam.
* [x] Add Perk Deny sound to new knife buy.
* [x] Reduce cooldown of winter's wail when a zombie hits you again after the first effect happened.
* [x] Fix Muscle Milk not working in Origins.
* [x] Fix MISSING_ACTIVATE_TRIGGER_TEXT and multiplayer prompt bleeding.
* [x] Fix Vulture Aid stink removing Zombie Blood invisibility.
* [x] Fix Exo slam explosion VFX on Origins (zm_tomb).
* [x] Fix Exo slam fall damage without touching invulnerability / god mode.
* [x] Fix Nitrogen Cooled prompt appearing when aiming (reserved ADS + breath sprint for future perk).
* [x] Fix Bandolier Bandit max ammo reserve capacity on Max Ammo powerups, `give ammo` command, and weapon purchases.
* [x] Fix Vigor Rush explosion VFX visibility across maps with particle overflow protection.
* [x] Fix Who's Who re-purchase at Quick Revive machine after shadow down and Fighter's Fizz revive.
* [x] Fix Fighter's Fizz revive incrementing solo Quick Revive purchase count and causing machine disappearance.
* [x] Fix Fighter's Fizz downed HUD countdown, weapon cycling, kill detection, and solo Quick Revive priority.
* [x] Fix Fighter's Fizz +sprint UI prompt displaying `UNBOUND` (updated to `[{+breath_sprint}]`).
* [x] Fix Who's Who and Fighter's Fizz compatibility glitch (clearing `whos_who_finishing`, preserving Solo Quick Revive lives, cleaning up spectator state to prevent indefinite solo game freezing).
* [x] Add Repairman Rum exploding boards when ripped off, scaling with Dam-A-Nade, and crawler out-of-bounds protection.
* [x] Reduce Ethereal Razor cleave radius by half (80 units).
* [x] Fix Ethereal Razor single zombie damage and eliminate infinite cleave damage recursion loop.
* [x] Fix Ethereal Razor melee kills awarding 130 points (MOD_MELEE) instead of 60 points.
