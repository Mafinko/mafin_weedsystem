# mafin_weedsystem

Lightweight ESX cannabis harvesting, processing and selling by **Mafin**.

## Features

- `ox_target` interactions by default (0.00 ms idle in normal use)
- cancellable `ox_lib` harvest progress circle
- `ox_lib` dealer context menu and amount input
- dealer NPC spawned at a server-synchronized location and rotated every 15 minutes
- paired player/dealer handover animation after successful sales
- dealer location hints through `lb-phone` or `okokPhone`
- configurable 25% police alert chance through `cd_dispatch` or `ps-dispatch`
- optional `esx_textui` interaction mode
- JSON item definitions and JSON-backed processing licenses
- Czech and English locales
- server-side distance, item, amount and inventory validation
- per-player, non-blocking processing timers
- no SQL installation file

## Installation

1. Put `mafin_weedsystem` in your resources folder.
2. Start dependencies before this resource:

   ```cfg
   ensure es_extended
   ensure ox_lib
   ensure ox_target
   ensure mafin_weedsystem
   ```

3. Set `Config.Locale`/the `esx:locale` convar to `cs` or `en`.
4. Edit positions, rewards, prices and interaction mode in `config.lua`.

To use ESX TextUI instead of target:

```lua
Config.Interaction = 'textui'
```

Then ensure `esx_textui` before this resource. If target mode is selected but `ox_target` is not running, the script automatically falls back to TextUI.

## Dealer, phone and dispatch

The dealer NPC model, scenario, locations and 15-minute rotation interval are configured in `Config.Dealer`. The exact dealer blip is disabled by default so players must use the broad phone hint. Set `Config.Dealer.Blip.Enabled = true` if you prefer an exact map marker.

`Config.Phone.Provider = 'auto'` selects `lb-phone` first, then `okokPhone`. You can force either provider or use `'none'`. Resource folder names and the anonymous sender are configurable.

`Config.Dispatch.Provider = 'auto'` selects `cd_dispatch`/`cd_dispatch3d` first, then `ps-dispatch`. A police alert is rolled server-side after a successful sale using `Config.Dispatch.Chance` (25 by default).

## JSON items

Items are defined in `data/items.json`. With the default ESX inventory, `Config.AutoRegisterItems = true` passes these definitions to `ESX.AddItems`; ESX may persist them through its own database layer. No manual SQL import is needed.

Custom inventories manage their own item registry. If one is enabled, copy the two definitions from `data/items.json` into that inventory's item configuration.

Ready-to-install `ox_inventory` definitions and the supplied transparent item images are included in the `install` folder. Follow `install/README.md` and set `Config.AutoRegisterItems = false` when using ox_inventory.

When `Config.License.Enabled = true`, purchased processing licenses are stored in `data/licenses.json` and do not use `esx_license` or its SQL table.

## Performance

Target mode creates event-driven target zones and local plant targets without a permanent proximity thread. TextUI mode uses one adaptive loop that sleeps while players are away from interaction areas. Actual profiler values still depend on the server build and installed dependencies.
