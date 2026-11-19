# Cyberware Reflash — 0.1.0 RU/EN test build

**AI-assisted development:** This mod was developed with OpenAI Codex (AI assistance for code, UI, translations and documentation). See the validation notes for what has and has not been tested.

Requires Cyber Engine Tweaks, redscript and Codeware. Developed for the installed Cyberpunk 2077 2.5 mod collection.

## Where to reflash cyberware

1. Find a **quickhack vendor (netrunner)**: an NPC who sells combat quickhacks for your cyberdeck.
2. Stand within **3.2 metres** and look at the vendor.
3. Select **Cyberware reflash** under **NETRUNNER SERVICES** in the interaction list. You do not need to open the trading menu.
4. Choose equipped cyberware and one of its existing secondary bonuses. Improving that bonus is the default; replacing its stat is optional.
5. Set the value, review both costs and confirm.

If the option is missing, close the trading menu, look at the vendor and scroll through the interaction choices.

## Features

Normal and overclock limits are shown before confirmation. Exact values, +/- controls and maximum presets are available. Overclocking is limited to 120% of the normal maximum. The number of bonuses stays unchanged and duplicate stats are blocked.

Payment requires **both eddies and quickhack components**. Two icon cards show the cost and available balance. Confirmation is blocked when either balance is insufficient. T1 cyberware uses T2 quickhack components; T5, T5+ and T5++ use T5 components.

The price depends on cyberware quality, the selected stat and upgrade strength. Improving the current bonus is generally cheaper than replacing it. Overclocking above the normal maximum costs substantially more. Both eddies and component costs are shown before confirmation.

Language follows the game's on-screen language setting (Russian or English). The service interaction, UI, messages and all 36 stat labels are translated. Cyberware names use the game's own localization. Close and reopen the service after changing the language.

Firmware records are unique per operation and persist in `bin/x64/plugins/cyber_engine_tweaks/mods/CyberwareReflash/profiles.json`, with `profiles.json.bak` as backup. **Keep these files together with your saves.** A save containing reflashed cyberware depends on the mod and these definitions. To uninstall, return to a save made before reflashing; automatic restoration on uninstall is not implemented.

The code previews and verifies firmware before reserving payment, rechecks both balances, and refunds reservations if replacement fails. Actual application, resource handling and save reload still need live verification. Full-collection redscript compilation and LuaJIT logic checks pass; game APIs are stubbed in the LuaJIT tests. The earlier wizard UI and calculated limits have been confirmed in game, before this payment/localization update.

UI uses Codeware and studied Ink Playground examples by Pavel Siberx (MIT). No third-party interactionUI.lua library is included.
