# Cyberware Reflash — 0.1.0 RU/EN test build

**AI-assisted development:** This mod was developed with OpenAI Codex (AI assistance for code, UI, translations and documentation). See the validation notes for what has and has not been tested.

Requires Cyber Engine Tweaks, redscript and Codeware. Developed for the installed Cyberpunk 2077 2.5 mod collection.

Look at a quickhack vendor from within 3.2 metres and select **Cyberware reflash**. Select equipped cyberware, then an existing secondary bonus. Improving that bonus is the default; choosing a replacement stat is optional. Search and categories help navigate the 36 supported stats.

Normal and overclock limits are shown before confirmation. Exact values, +/- controls and maximum presets are available. Overclocking is limited to 120% of the normal maximum. The number of bonuses stays unchanged and duplicate stats are blocked.

Payment requires **both eddies and quickhack components**. Two icon cards show the cost and available balance. Confirmation is blocked when either balance is insufficient. T1 cyberware uses T2 quickhack components; T5, T5+ and T5++ use T5 components.

The nominal tariff uses tier bases 15/30/60/90/120 and an operation fee of 5. It grows quadratically up to the normal maximum, then reaches 3x at 110% and 8x at 120%. Improving the same stat charges the tariff difference plus the fee. T5+ and T5++ have 15% and 35% surcharges. Eddies cost 180 times the nominal tariff; components cost one tenth of the nominal tariff, rounded up. For example, nominal tariff 725 costs **73 components + 130,500 eddies**.

Language follows the game's on-screen language setting (Russian or English). The service interaction, UI, messages and all 36 stat labels are translated. Cyberware names use the game's own localization. Close and reopen the service after changing the language.

Firmware records are unique per operation and persist in `bin/x64/plugins/cyber_engine_tweaks/mods/CyberwareReflash/profiles.json`, with `profiles.json.bak` as backup. **Keep these files together with your saves.** A save containing reflashed cyberware depends on the mod and these definitions. To uninstall, return to a save made before reflashing; automatic restoration on uninstall is not implemented.

The code previews and verifies firmware before reserving payment, rechecks both balances, and refunds reservations if replacement fails. Actual application, resource handling and save reload still need live verification. Full-collection redscript compilation and LuaJIT logic checks pass; game APIs are stubbed in the LuaJIT tests. The earlier wizard UI and calculated limits have been confirmed in game, before this payment/localization update.

UI uses Codeware and studied Ink Playground examples by Pavel Siberx (MIT). No third-party interactionUI.lua library is included.
