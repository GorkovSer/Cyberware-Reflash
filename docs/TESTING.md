# Validation status — 0.1.0 alpha

## Confirmed

- Native vendor service opens the wizard in the tested local game collection.
- Cyberware/bonus lists and nonzero quality limits were visible in game before the payment/localization update.
- REDscript compiles together with 1214 scripts from the tested collection.
- Lua syntax passes for Lua 5.1.
- Actual Lua functions run in LuaJIT tests covering decimal separators, limits, overclock costs, preserving the previous bonus tariff, duplicates, component tiers, insufficient resources and split-payment pricing.
- Tests exercise fresh firmware record creation using CET's Update API, repeated calls, failed writes and safe retry after partial initialization.
- RU/EN stat labels and English messages are covered by logic tests.
- Icons for cash and T2–T5 quickhack components were found in the game's tweak database.

## Not yet confirmed in game

- Final payment icon layout and automatic English language selection.
- Applying a real bonus change and checking its gameplay effect.
- Spending both resources and refunding them on a rejected replacement.
- Saving, restarting the game, restoring firmware definitions and reloading that save.
- Broad compatibility across arbitrary mod collections and every quickhack vendor.

The LuaJIT tests mock game APIs and do not prove these pending behaviors. Source compilation and archive checks do not replace gameplay verification.

## Latest fix

Removed an invalid TweakDB:UpdateRecord call and use CET's TweakDB:Update API. Flat writes are checked; firmware records are cached as ready only after a complete successful update. This fix passed logic tests but still needs a fresh in-game creation check.
