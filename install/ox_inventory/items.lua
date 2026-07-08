-- Copy these entries inside the existing return table in ox_inventory/data/items.lua.
-- Do not replace the entire ox_inventory items file.

return {
    ['cannabis'] = {
        label = 'Cannabis',
        weight = 3,
        stack = true,
        close = true,
        description = 'Freshly harvested cannabis.',
        client = {
            image = 'cannabis.png'
        }
    },

    ['marijuana'] = {
        label = 'Marijuana',
        weight = 2,
        stack = true,
        close = true,
        description = 'Processed marijuana ready for sale.',
        client = {
            image = 'marijuana.png'
        }
    }
}

