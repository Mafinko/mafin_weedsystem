local RESOURCE = GetCurrentResourceName()
local processing = {}
local harvestCooldown = {}
local licenses = {}
local dealerIndex = 1
local dealerCoords = Config.Dealer.Locations[1].coords
local dealerHeading = Config.Dealer.Locations[1].heading or 0.0

local function resourceStarted(resource)
    return resource and GetResourceState(resource) == 'started'
end

local function sendDealerHint(location)
    local provider = Config.Phone.Provider
    if provider == 'none' then return end

    if provider == 'auto' then
        if resourceStarted(Config.Phone.LBResource) then
            provider = 'lb-phone'
        elseif resourceStarted(Config.Phone.OkokResource) then
            provider = 'okokPhone'
        else
            print(('[%s] Dealer moved, but no supported phone resource is running.'):format(RESOURCE))
            return
        end
    end

    local title = TranslateCap('dealer_phone_title')
    local message = TranslateCap('dealer_phone_message', TranslateCap(location.hint))

    if provider == 'lb-phone' then
        if not resourceStarted(Config.Phone.LBResource) then return end

        local success, errorMessage = pcall(function()
            exports[Config.Phone.LBResource]:NotifyEveryone('online', {
                app = Config.Phone.LBApp,
                title = title,
                content = message
            })
        end)

        if not success then
            print(('[%s] lb-phone notification failed: %s'):format(RESOURCE, errorMessage))
        end
        return
    end

    if provider == 'okokPhone' then
        if not resourceStarted(Config.Phone.OkokResource) then return end

        for _, playerId in ipairs(GetPlayers()) do
            local target = tonumber(playerId)
            local success, errorMessage = pcall(function()
                local phoneNumber = exports[Config.Phone.OkokResource]:getPhoneNumberFromSource(target)
                if not phoneNumber then return end

                exports[Config.Phone.OkokResource]:sendMessage({
                    sender = Config.Phone.Sender,
                    receiver = phoneNumber,
                    message = message
                })
            end)

            if not success then
                print(('[%s] okokPhone message failed for player %s: %s'):format(RESOURCE, target, errorMessage))
            end
        end
    end
end

local function changeDealerLocation(sendMessage)
    local locations = Config.Dealer.Locations
    if #locations == 0 then return end

    local nextIndex = dealerIndex
    if #locations > 1 then
        while nextIndex == dealerIndex do
            nextIndex = math.random(1, #locations)
        end
    end

    dealerIndex = nextIndex
    dealerCoords = locations[dealerIndex].coords
    dealerHeading = locations[dealerIndex].heading or 0.0
    TriggerClientEvent('mafin_weedsystem:updateDealerLocation', -1, {
        x = dealerCoords.x,
        y = dealerCoords.y,
        z = dealerCoords.z,
        heading = dealerHeading
    })

    if sendMessage then
        sendDealerHint(locations[dealerIndex])
    end
end

local function resolveCDDispatchResource()
    for _, resource in ipairs(Config.Dispatch.CDResources) do
        if resourceStarted(resource) then return resource end
    end
end

local function alertPolice(source, coords)
    if not Config.Dispatch.Enabled or math.random(1, 100) > Config.Dispatch.Chance then return end

    local provider = Config.Dispatch.Provider
    if provider == 'none' then return end

    if provider == 'auto' then
        if resolveCDDispatchResource() then
            provider = 'cd_dispatch'
        elseif resourceStarted(Config.Dispatch.PSResource) then
            provider = 'ps-dispatch'
        else
            print(('[%s] Police alert rolled, but no supported dispatch resource is running.'):format(RESOURCE))
            return
        end
    end

    if provider == 'cd_dispatch' then
        if not resolveCDDispatchResource() then return end

        TriggerEvent('cd_dispatch:AddNotification', {
            job_table = Config.Dispatch.Jobs,
            coords = coords,
            title = ('%s - %s'):format(Config.Dispatch.Code, TranslateCap('dispatch_title')),
            message = TranslateCap('dispatch_message'),
            flash = false,
            sound = 1,
            blip = {
                sprite = Config.Dispatch.Sprite,
                scale = Config.Dispatch.Scale,
                colour = Config.Dispatch.Color,
                flashes = false,
                text = TranslateCap('dispatch_title'),
                time = Config.Dispatch.Duration,
                radius = 0
            }
        })
        return
    end

    if provider == 'ps-dispatch' and resourceStarted(Config.Dispatch.PSResource) then
        TriggerClientEvent('mafin_weedsystem:psDispatchAlert', source, {
            x = coords.x,
            y = coords.y,
            z = coords.z
        })
    end
end

local function loadJson(path, fallback)
    local contents = LoadResourceFile(RESOURCE, path)
    if not contents or contents == '' then return fallback end

    local success, decoded = pcall(json.decode, contents)
    if not success or type(decoded) ~= 'table' then
        print(('[%s] Could not decode %s; using an empty value.'):format(RESOURCE, path))
        return fallback
    end

    return decoded
end

local function saveLicenses()
    local encoded = json.encode(licenses)
    local written = SaveResourceFile(RESOURCE, Config.License.File, encoded, #encoded)
    if not written then
        print(('[%s] Failed to save %s. Check resource write permissions.'):format(RESOURCE, Config.License.File))
    end
end

local function getPlayer(source)
    return ESX.GetPlayerFromId(source)
end

local function isNear(source, coords, radius)
    local ped = GetPlayerPed(source)
    if ped <= 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= radius
end

local function itemLabel(itemName)
    return ESX.GetItemLabel(itemName) or itemName
end

local function stopProcessing(source, messageKey)
    if not processing[source] then return end

    processing[source] = nil
    TriggerClientEvent('mafin_weedsystem:setProcessing', source, false)

    local xPlayer = getPlayer(source)
    if xPlayer and messageKey then
        xPlayer.showNotification(TranslateCap(messageKey))
    end
end

local function canSwap(xPlayer)
    local input = Config.Processing.Input
    local output = Config.Processing.Output

    if xPlayer.canSwapItem then
        return xPlayer.canSwapItem(input.item, input.count, output.item, output.count)
    end

    return xPlayer.canCarryItem(output.item, output.count)
end

local function scheduleProcessing(source, token)
    SetTimeout(Config.Processing.Duration, function()
        if processing[source] ~= token then return end

        local xPlayer = getPlayer(source)
        if not xPlayer then
            processing[source] = nil
            return
        end

        if not isNear(source, Config.Processing.Coords, Config.Processing.ServerRadius) then
            stopProcessing(source, 'processing_too_far')
            return
        end

        local input = Config.Processing.Input
        local output = Config.Processing.Output
        local inputItem = xPlayer.getInventoryItem(input.item)

        if not inputItem or inputItem.count < input.count then
            xPlayer.showNotification(TranslateCap('processing_not_enough', input.count, itemLabel(input.item)))
            stopProcessing(source)
            return
        end

        if not canSwap(xPlayer) then
            stopProcessing(source, 'processing_full')
            return
        end

        xPlayer.removeInventoryItem(input.item, input.count)
        xPlayer.addInventoryItem(output.item, output.count)
        xPlayer.showNotification(TranslateCap(
            'processed',
            input.count,
            itemLabel(input.item),
            output.count,
            itemLabel(output.item)
        ))

        scheduleProcessing(source, token)
    end)
end

CreateThread(function()
    licenses = loadJson(Config.License.File, {})

    if not Config.AutoRegisterItems then return end
    local items = loadJson(Config.ItemsFile, {})

    if ESX.AddItems then
        ESX.AddItems(items)
        print(('[%s] Loaded %s item definitions from %s.'):format(RESOURCE, #items, Config.ItemsFile))
    else
        print(('[%s] ESX.AddItems is unavailable (likely a custom inventory). Add the items from %s to that inventory.'):format(
            RESOURCE,
            Config.ItemsFile
        ))
    end
end)

CreateThread(function()
    changeDealerLocation(Config.Dealer.NotifyOnInitialLocation)

    while true do
        Wait(Config.Dealer.ChangeInterval)
        changeDealerLocation(true)
    end
end)

ESX.RegisterServerCallback('mafin_weedsystem:harvest', function(source, cb)
    local xPlayer = getPlayer(source)
    if not xPlayer or not isNear(source, Config.Harvest.Center, Config.Harvest.ServerRadius) then
        cb(false)
        return
    end

    local now = GetGameTimer()
    if harvestCooldown[source] and now - harvestCooldown[source] < Config.Harvest.Duration - 250 then
        cb(false)
        return
    end
    harvestCooldown[source] = now

    local reward = Config.Harvest.Reward
    local amount = math.random(reward.min, reward.max)
    if not xPlayer.canCarryItem(reward.item, amount) then
        cb(false, TranslateCap('inventory_full'))
        return
    end

    xPlayer.addInventoryItem(reward.item, amount)
    cb(true)
end)

ESX.RegisterServerCallback('mafin_weedsystem:startProcessing', function(source, cb)
    local xPlayer = getPlayer(source)
    if not xPlayer or not isNear(source, Config.Processing.Coords, Config.Processing.ServerRadius) then
        cb('invalid')
        return
    end

    if processing[source] then
        cb('started')
        return
    end

    if Config.License.Enabled then
        local identifier = xPlayer.getIdentifier()
        if not licenses[identifier] or not licenses[identifier][Config.License.Name] then
            cb('license_required', TranslateCap('license_required'))
            return
        end
    end

    local input = Config.Processing.Input
    local inputItem = xPlayer.getInventoryItem(input.item)
    if not inputItem or inputItem.count < input.count then
        cb('not_enough', TranslateCap('processing_not_enough', input.count, itemLabel(input.item)))
        return
    end

    local token = ('%s:%s:%s'):format(source, GetGameTimer(), math.random(100000, 999999))
    processing[source] = token
    TriggerClientEvent('mafin_weedsystem:setProcessing', source, true)
    xPlayer.showNotification(TranslateCap('processing_started'))
    scheduleProcessing(source, token)
    cb('started')
end)

ESX.RegisterServerCallback('mafin_weedsystem:buyLicense', function(source, cb)
    local xPlayer = getPlayer(source)
    if not xPlayer or not Config.License.Enabled or not isNear(source, Config.Processing.Coords, Config.Processing.ServerRadius) then
        cb(false, TranslateCap('license_required'))
        return
    end

    local identifier = xPlayer.getIdentifier()
    licenses[identifier] = licenses[identifier] or {}

    if licenses[identifier][Config.License.Name] then
        cb(false, TranslateCap('license_owned'))
        return
    end

    if xPlayer.getMoney() < Config.License.Price then
        cb(false, TranslateCap('license_no_money'))
        return
    end

    xPlayer.removeMoney(Config.License.Price, 'Weed processing license')
    licenses[identifier][Config.License.Name] = true
    saveLicenses()
    cb(true, TranslateCap('license_bought', Config.License.Label, ESX.Math.GroupDigits(Config.License.Price)))
end)

RegisterNetEvent('mafin_weedsystem:cancelProcessing', function()
    stopProcessing(source, 'processing_stopped')
end)

RegisterNetEvent('mafin_weedsystem:requestDealerLocation', function()
    TriggerClientEvent('mafin_weedsystem:updateDealerLocation', source, {
        x = dealerCoords.x,
        y = dealerCoords.y,
        z = dealerCoords.z,
        heading = dealerHeading
    })
end)

RegisterNetEvent('mafin_weedsystem:sellDrug', function(itemName, amount)
    local source = source
    local xPlayer = getPlayer(source)

    if not xPlayer or not isNear(source, dealerCoords, Config.Dealer.ServerRadius) then return end
    if type(itemName) ~= 'string' or type(amount) ~= 'number' then return end

    amount = math.floor(amount)
    if amount < Config.Dealer.SellAmount.min or amount > Config.Dealer.SellAmount.max then return end

    local unitPrice = Config.Dealer.Items[itemName]
    if not unitPrice then return end

    local item = xPlayer.getInventoryItem(itemName)
    if not item or item.count < amount then
        xPlayer.showNotification(TranslateCap('dealer_not_enough'))
        return
    end

    local total = ESX.Math.Round(unitPrice * amount)
    local saleCoords = GetEntityCoords(GetPlayerPed(source))
    xPlayer.removeInventoryItem(itemName, amount)

    if Config.Dealer.GiveBlackMoney then
        xPlayer.addAccountMoney('black_money', total, 'Weed sold')
    else
        xPlayer.addMoney(total, 'Weed sold')
    end

    xPlayer.showNotification(TranslateCap('dealer_sold', amount, item.label, ESX.Math.GroupDigits(total)))
    TriggerClientEvent('mafin_weedsystem:playDealerExchange', source)
    alertPolice(source, saleCoords)
end)

AddEventHandler('playerDropped', function()
    processing[source] = nil
    harvestCooldown[source] = nil
end)

RegisterNetEvent('esx:onPlayerDeath', function()
    stopProcessing(source)
end)
