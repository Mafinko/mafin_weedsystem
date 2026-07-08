# Item installation

Choose the inventory used by your server.

## ox_inventory

1. Open `install/ox_inventory/items.lua`.
2. Copy both item entries inside the table in `ox_inventory/data/items.lua`.
3. Copy both PNG files from `install/ox_inventory/images` to `ox_inventory/web/images`.
4. Restart `ox_inventory` and `mafin_weedsystem` (a full server restart is recommended).
5. Keep `Config.AutoRegisterItems = false` in `mafin_weedsystem/config.lua` when using `ox_inventory`.

Do not replace the complete `ox_inventory/data/items.lua`; merge the two entries into its existing `return { ... }` table.

## Default ESX inventory

The resource already reads `data/items.json` and calls `ESX.AddItems` when `Config.AutoRegisterItems = true`. A copy of the definitions is included in `install/esx_default/items.json` for convenience. No manual SQL file is included.

