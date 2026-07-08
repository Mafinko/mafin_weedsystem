Config = {}

Config.Locale = GetConvar('esx:locale', 'en')
Config.Debug = false

-- 'target' = ox_target with no permanent client polling loop.
-- 'textui' = esx_textui with an adaptive proximity loop.
Config.Interaction = 'target'
Config.TargetResource = 'ox_target'
Config.TextUIResource = 'esx_textui'
Config.InteractKey = 38 -- E

Config.Progress = {
    Position = 'bottom',
    CanCancel = true,
    Disable = {
        move = true,
        car = true,
        combat = true,
        sprint = true
    }
}

Config.ItemsFile = 'data/items.json'
Config.AutoRegisterItems = true -- ESX default inventory only; custom inventories need their own item definitions.

Config.Harvest = {
    Center = vector3(2220.72, 5582.52, 53.81),
    ServerRadius = 90.0,
    LoadDistance = 100.0,
    SpawnRadius = 48,
    MaxPlants = 25,
    MinimumSpacing = 4.0,
    Model = `prop_weed_02`,
    Duration = 3500,
    RespawnTime = 45000,
    Reward = { item = 'cannabis', min = 5, max = 10 },
    TargetDistance = 1.8
}

Config.Processing = {
    Coords = vector3(2329.02, 2571.29, 46.68),
    Radius = 1.5,
    ServerRadius = 5.0,
    Duration = 7000,
    Input = { item = 'cannabis', count = 3 },
    Output = { item = 'marijuana', count = 1 }
}

Config.Dealer = {
    ChangeInterval = 30 * 60 * 1000,
    NotifyOnInitialLocation = false,
    Locations = {
        { coords = vector3(-1172.02, -1571.98, 4.66), hint = 'dealer_hint_vespucci' },
        { coords = vector3(987.16, -2529.39, 28.30), hint = 'dealer_hint_docks' },
        { coords = vector3(1138.19, -463.20, 66.85), hint = 'dealer_hint_mirrorpark' },
        { coords = vector3(1702.71, 3591.52, 35.62), hint = 'dealer_hint_sandy' },
        { coords = vector3(-79.06, 6418.36, 31.49), hint = 'dealer_hint_paleto' },
        { coords = vector3(807.26, -2226.16, 29.31), hint = 'dealer_hint_lamesa' }
    },
    Radius = 1.5,
    ServerRadius = 5.0,
    GiveBlackMoney = true,
    Items = {
        marijuana = 91
    },
    SellAmount = { min = 1, max = 50 },
    Blip = {
        Enabled = false, -- Keep false when players should locate the dealer from the phone hint.
        Sprite = 378,
        Color = 6,
        Scale = 0.85
    }
}

Config.Phone = {
    Provider = 'auto', -- 'auto', 'lb-phone', 'okokPhone', or 'none'
    LBResource = 'lb-phone',
    OkokResource = 'okokPhone',
    LBApp = 'Messages',
    Sender = 'Unknown Dealer'
}

Config.Dispatch = {
    Enabled = true,
    Chance = 25,
    Provider = 'auto', -- 'auto', 'cd_dispatch', 'ps-dispatch', or 'none'
    CDResources = { 'cd_dispatch', 'cd_dispatch3d' },
    PSResource = 'ps-dispatch',
    Jobs = { 'police' },
    Code = '10-66',
    Sprite = 51,
    Color = 1,
    Scale = 1.2,
    Duration = 5
}

Config.License = {
    Enabled = false,
    Name = 'weed_processing',
    Label = 'Weed Processing License',
    Price = 15000,
    File = 'data/licenses.json'
}

Config.Blips = {
    {
        enabled = true,
        coords = Config.Harvest.Center,
        label = 'blip_weedfield',
        sprite = 496,
        color = 25,
        radius = 100.0
    },
    {
        enabled = true,
        coords = Config.Processing.Coords,
        label = 'blip_weedprocessing',
        sprite = 496,
        color = 25
    }
}
