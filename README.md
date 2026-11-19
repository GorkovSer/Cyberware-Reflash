# Cyberware Reflash (RU / EN)

Customize secondary cyberware bonuses at existing quickhack vendors through an in-game wizard.

**Experimental alpha.** The vendor interaction, wizard UI and calculated limits have been seen in game. Actual bonus replacement, payment/refund, save reload and automatic English selection still require live verification. Do not treat a successful compile as a complete gameplay test.

[Download the test build](https://github.com/GorkovSer/Cyberware-Reflash/releases) · [Русское руководство](README-RU.md) · [English guide](README-EN.md) · [Validation status](docs/TESTING.md)

## Features

- Improve an existing bonus or replace its stat, without adding bonus slots.
- 36 supported secondary stats, search, categories and cyberware icons.
- Quality-based limits, exact value entry and optional overclocking up to 120%.
- Payment in both eddies and quickhack components, shown as separate icon cards.
- Russian and English UI selected from the game's on-screen language setting.
- Per-operation firmware definitions persisted beside the CET mod.

## Requirements and installation

Developed against Cyberpunk 2077 2.5 with [Cyber Engine Tweaks](https://github.com/maximegmd/CyberEngineTweaks), [redscript](https://github.com/jac3km4/redscript) and [Codeware](https://github.com/psiberx/cp2077-codeware). Dependencies and game files are not included.

Install the release ZIP with Vortex, or extract its `bin` and `r6` directories into the Cyberpunk 2077 game directory. Restart the game. Look at a quickhack vendor from within 3.2 metres and select **Cyberware reflash** / **Перепрошивка имплантов**.

Keep a save from before your first reflash. Keep `profiles.json` and `profiles.json.bak` together with any save containing reflashed cyberware. Such saves depend on these definitions and the mod; automatic restoration on uninstall is not implemented.

## Build and logic checks

```sh
python tools/build.py
python -m pip install -r requirements-dev.txt
python tests/test_quote.py
```

The build uses only Python's standard library. Logic tests run the actual Lua functions in LuaJIT through Lupa, with mocked game APIs. REDscript compilation requires a local game installation and the dependencies above.

## Русский

Мод добавляет услугу перепрошивки дополнительных бонусов имплантов у продавцов скриптов. Можно усилить имеющийся бонус или заменить его на другую характеристику. Оплата берётся деньгами и компонентами скриптов; доступны разгон до 120% и интерфейс RU/EN.

Это тестовая альфа: отображение интерфейса и пределов подтверждено, а фактическое применение, оплата и загрузка сохранения ещё требуют проверки в игре. Полная инструкция и текущая формула цены — в [README-RU.md](README-RU.md).

## Credits

Codeware and the MIT-licensed Ink Playground examples are by Pavel Siberx. The relevant upstream notice is retained in [LICENSE-InkPlayground](LICENSE-InkPlayground). See [NOTICE.md](NOTICE.md).
