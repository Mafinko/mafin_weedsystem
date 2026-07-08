local RESOURCE = GetCurrentResourceName()
local plants = {}
local targetZones = {}
local isHarvesting = false
local isProcessing = false
local dealerOpen = false
local textUIMessage
local spawnPlant
local dealerCoords = Config.Dealer.Locations[1].coords
local dealerHeading = Config.Dealer.Locations[1].heading or 0.0
local dealerBlip
local dealerPed
local dealerBusy = false

local function notify(message)
    ESX.ShowNotification(message)
end

local function targetEnabled()
    return Config.Interaction == 'target' and GetResourceState(Config.TargetResource) == 'started'
end

local function showTextUI(message)
    if textUIMessage == message then return end

    if textUIMessage then
        pcall(function()
            exports[Config.TextUIResource]:HideUI()
        end)
    end

    textUIMessage = message
    if message then
        pcall(function()
            exports[Config.TextUIResource]:TextUI(message, 'info')
        end)
    end
end

local function hideTextUI()
    showTextUI(nil)
end

local function removePlant(entity)
    local coords = plants[entity]
    if not coords then return end

    if targetEnabled() then
        exports[Config.TargetResource]:removeLocalEntity(entity, 'mafin_weedsystem_harvest')
    end

    plants[entity] = nil
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    SetTimeout(Config.Harvest.RespawnTime, function()
        if GetResourceState(RESOURCE) ~= 'started' then return end
        spawnPlant(coords, true)
    end)
end

AddEventHandler('mafin_weedsystem:client:harvest', function(entity)
    if isHarvesting or not entity or not plants[entity] then return end

    isHarvesting = true
    local completed = lib.progressCircle({
        duration = Config.Harvest.Duration,
        label = TranslateCap('harvesting'),
        position = Config.Progress.Position,
        useWhileDead = false,
        canCancel = Config.Progress.CanCancel,
        disable = Config.Progress.Disable,
        anim = {
            scenario = 'world_human_gardener_plant'
        }
    })

    if not completed then
        isHarvesting = false
        return
    end

    ESX.TriggerServerCallback('mafin_weedsystem:harvest', function(success, message)
        if success then
            removePlant(entity)
        elseif message then
            notify(message)
        end
        isHarvesting = false
    end)
end)

local function openLicenseMenu()
    local title = TranslateCap('license_buy', Config.License.Label, ESX.Math.GroupDigits(Config.License.Price))
    dealerOpen = true

    ESX.OpenContext('right', {
        { unselectable = true, title = TranslateCap('license_required') },
        { icon = 'fa-solid fa-id-card', title = title, value = 'buy' }
    }, function(_, element)
        if element.value ~= 'buy' then return end

        ESX.TriggerServerCallback('mafin_weedsystem:buyLicense', function(success, message)
            notify(message)
            if success then
                ESX.CloseContext()
                dealerOpen = false
            end
        end)
    end, function()
        dealerOpen = false
    end)
end

local function startProcessing()
    if isProcessing then return end

    ESX.TriggerServerCallback('mafin_weedsystem:startProcessing', function(status, message)
        if status == 'license_required' then
            openLicenseMenu()
        elseif status ~= 'started' and message then
            notify(message)
        end
    end)
end

local function stopProcessing()
    if not isProcessing then return end
    TriggerServerEvent('mafin_weedsystem:cancelProcessing')
end

RegisterNetEvent('mafin_weedsystem:setProcessing', function(state)
    isProcessing = state == true
end)

local function openDealer()
    if dealerOpen or dealerBusy then return end

    local options = {}

    for _, item in pairs(ESX.GetPlayerData().inventory or {}) do
        local price = Config.Dealer.Items[item.name]
        if price and item.count > 0 then
            local itemName = item.name
            local itemLabel = item.label
            local itemCount = item.count
            local unitPrice = price

            options[#options + 1] = {
                title = itemLabel,
                description = TranslateCap('dealer_unit_price', ESX.Math.GroupDigits(unitPrice)),
                icon = 'cannabis',
                iconColor = '#22c55e',
                arrow = true,
                metadata = {
                    { label = TranslateCap('dealer_available'), value = itemCount },
                    { label = TranslateCap('dealer_price'), value = ('$%s'):format(ESX.Math.GroupDigits(unitPrice)) }
                },
                onSelect = function()
                    local input = lib.inputDialog(TranslateCap('dealer_title'), {
                        {
                            type = 'number',
                            label = TranslateCap('dealer_amount'),
                            description = TranslateCap('dealer_amount_description'),
                            icon = 'hashtag',
                            default = Config.Dealer.SellAmount.min,
                            min = Config.Dealer.SellAmount.min,
                            max = math.min(Config.Dealer.SellAmount.max, itemCount),
                            precision = 0,
                            step = 1,
                            required = true
                        }
                    }, {
                        allowCancel = true,
                        size = 'sm'
                    })

                    dealerOpen = false
                    if not input then return end

                    local amount = math.floor(tonumber(input[1]) or 0)
                    TriggerServerEvent('mafin_weedsystem:sellDrug', itemName, amount)
                end
            }
        end
    end

    if #options == 0 then
        notify(TranslateCap('dealer_empty'))
        return
    end

    dealerOpen = true
    lib.registerContext({
        id = 'mafin_weedsystem_dealer_menu',
        title = TranslateCap('dealer_title'),
        position = 'top-right',
        canClose = true,
        options = options,
        onExit = function()
            dealerOpen = false
        end
    })
    lib.showContext('mafin_weedsystem_dealer_menu')
end

local function addTargetInteractions()
    targetZones.processing = exports[Config.TargetResource]:addSphereZone({
        coords = Config.Processing.Coords,
        radius = Config.Processing.Radius,
        debug = Config.Debug,
        drawSprite = true,
        options = {
            {
                name = 'mafin_weedsystem_process_start',
                icon = 'fa-solid fa-mortar-pestle',
                label = TranslateCap('process_target'),
                distance = 2.0,
                canInteract = function() return not isProcessing end,
                onSelect = startProcessing
            },
            {
                name = 'mafin_weedsystem_process_stop',
                icon = 'fa-solid fa-stop',
                label = TranslateCap('process_stop_target'),
                distance = 2.0,
                canInteract = function() return isProcessing end,
                onSelect = stopProcessing
            }
        }
    })

end

local function addDealerTarget()
    if not dealerPed or not DoesEntityExist(dealerPed) or not targetEnabled() then return end

    exports[Config.TargetResource]:removeLocalEntity(dealerPed, 'mafin_weedsystem_dealer')

    exports[Config.TargetResource]:addLocalEntity(dealerPed, {
        {
            name = 'mafin_weedsystem_dealer',
            icon = 'fa-solid fa-user-secret',
            label = TranslateCap('dealer_target'),
            distance = 2.0,
            canInteract = function()
                return not dealerBusy
            end,
            onSelect = openDealer
        }
    })
end

local function deleteDealerPed()
    if not dealerPed or not DoesEntityExist(dealerPed) then
        dealerPed = nil
        return
    end

    if targetEnabled() then
        exports[Config.TargetResource]:removeLocalEntity(dealerPed, 'mafin_weedsystem_dealer')
    end

    DeletePed(dealerPed)
    dealerPed = nil
end

local function spawnDealerPed()
    deleteDealerPed()

    RequestModel(Config.Dealer.Model)
    while not HasModelLoaded(Config.Dealer.Model) do Wait(50) end

    RequestCollisionAtCoord(dealerCoords.x, dealerCoords.y, dealerCoords.z)
    dealerPed = CreatePed(
        4,
        Config.Dealer.Model,
        dealerCoords.x,
        dealerCoords.y,
        dealerCoords.z - 1.0,
        dealerHeading,
        false,
        false
    )

    if not DoesEntityExist(dealerPed) then
        print(('[%s] Failed to create the dealer NPC.'):format(RESOURCE))
        dealerPed = nil
        SetModelAsNoLongerNeeded(Config.Dealer.Model)
        return
    end

    SetEntityAsMissionEntity(dealerPed, true, true)
    SetEntityHeading(dealerPed, dealerHeading)
    SetEntityInvincible(dealerPed, true)
    FreezeEntityPosition(dealerPed, true)
    SetBlockingOfNonTemporaryEvents(dealerPed, true)
    SetPedCanRagdoll(dealerPed, false)

    if Config.Dealer.Scenario and Config.Dealer.Scenario ~= '' then
        TaskStartScenarioInPlace(dealerPed, Config.Dealer.Scenario, 0, true)
    end

    addDealerTarget()
    SetModelAsNoLongerNeeded(Config.Dealer.Model)
end

local function addPlantTargets()
    for entity in pairs(plants) do
        exports[Config.TargetResource]:addLocalEntity(entity, {
            {
                name = 'mafin_weedsystem_harvest',
                icon = 'fa-solid fa-cannabis',
                label = TranslateCap('harvest_target'),
                distance = Config.Harvest.TargetDistance,
                canInteract = function()
                    return not isHarvesting and IsPedOnFoot(PlayerPedId())
                end,
                onSelect = function(data)
                    TriggerEvent('mafin_weedsystem:client:harvest', data.entity)
                end
            }
        })
    end
end

local function initializeTargetInteractions()
    addTargetInteractions()
    addDealerTarget()
    addPlantTargets()
end

local function createTextUILoop()
    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local action, message, entity

            local processDistance = #(coords - Config.Processing.Coords)
            local dealerDistance = #(coords - dealerCoords)
            local fieldDistance = #(coords - Config.Harvest.Center)

            if processDistance < 20.0 or dealerDistance < 20.0 or fieldDistance < Config.Harvest.ServerRadius then
                sleep = 250
            end

            if processDistance <= Config.Processing.Radius then
                sleep = 0
                action = isProcessing and stopProcessing or startProcessing
                message = TranslateCap(isProcessing and 'textui_process_stop' or 'textui_process')
            elseif dealerDistance <= Config.Dealer.Radius then
                sleep = 0
                action = openDealer
                message = TranslateCap('textui_dealer')
            elseif fieldDistance < Config.Harvest.ServerRadius and IsPedOnFoot(ped) then
                local nearestDistance = Config.Harvest.TargetDistance
                for plant in pairs(plants) do
                    if DoesEntityExist(plant) then
                        local distance = #(coords - GetEntityCoords(plant))
                        if distance < nearestDistance then
                            nearestDistance = distance
                            entity = plant
                        end
                    end
                end

                if entity then
                    sleep = 0
                    action = function()
                        TriggerEvent('mafin_weedsystem:client:harvest', entity)
                    end
                    message = TranslateCap('textui_harvest')
                end
            end

            if action and not dealerOpen then
                showTextUI(message)
                if IsControlJustReleased(0, Config.InteractKey) then
                    action()
                end
            else
                hideTextUI()
            end

            Wait(sleep)
        end
    end)
end

local function getGroundZ(x, y)
    RequestCollisionAtCoord(x, y, Config.Harvest.Center.z)

    for _ = 1, 30 do
        local found, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, false)
        if found then return groundZ end
        RequestCollisionAtCoord(x, y, Config.Harvest.Center.z)
        Wait(25)
    end

    return Config.Harvest.Center.z
end

local function generatePlantCoords(existingCoords)
    for _ = 1, 250 do
        local angle = math.random() * math.pi * 2
        local distance = math.sqrt(math.random()) * Config.Harvest.SpawnRadius
        local x = Config.Harvest.Center.x + math.cos(angle) * distance
        local y = Config.Harvest.Center.y + math.sin(angle) * distance
        local candidate = vector3(x, y, getGroundZ(x, y))
        local valid = true

        for i = 1, #existingCoords do
            if #(candidate - existingCoords[i]) < Config.Harvest.MinimumSpacing then
                valid = false
                break
            end
        end

        if valid then return candidate end
        Wait(0)
    end
end

spawnPlant = function(coords, addTarget)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    local plant = CreateObjectNoOffset(
        Config.Harvest.Model,
        coords.x,
        coords.y,
        coords.z + 1.5,
        false,
        false,
        false
    )

    local timeout = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(plant) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(25)
    end

    SetEntityCoordsNoOffset(plant, coords.x, coords.y, coords.z + 1.0, false, false, false)
    local grounded = PlaceObjectOnGroundProperly(plant)
    if not grounded then
        SetEntityCoordsNoOffset(plant, coords.x, coords.y, coords.z + 0.05, false, false, false)
    end

    SetEntityAsMissionEntity(plant, true, true)
    FreezeEntityPosition(plant, true)
    plants[plant] = GetEntityCoords(plant)

    if addTarget and targetEnabled() then
        exports[Config.TargetResource]:addLocalEntity(plant, {
            {
                name = 'mafin_weedsystem_harvest',
                icon = 'fa-solid fa-cannabis',
                label = TranslateCap('harvest_target'),
                distance = Config.Harvest.TargetDistance,
                canInteract = function()
                    return not isHarvesting and IsPedOnFoot(PlayerPedId())
                end,
                onSelect = function(data)
                    TriggerEvent('mafin_weedsystem:client:harvest', data.entity)
                end
            }
        })
    end

    return plant
end

local function createBlips()
    for _, data in ipairs(Config.Blips) do
        if data.enabled then
            if data.radius then
                local radius = AddBlipForRadius(data.coords.x, data.coords.y, data.coords.z, data.radius)
                SetBlipColour(radius, data.color)
                SetBlipAlpha(radius, 90)
            end

            local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
            SetBlipSprite(blip, data.sprite)
            SetBlipColour(blip, data.color)
            SetBlipScale(blip, 0.85)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(TranslateCap(data.label))
            EndTextCommandSetBlipName(blip)
        end
    end
end

local function updateDealerBlip()
    if dealerBlip and DoesBlipExist(dealerBlip) then
        RemoveBlip(dealerBlip)
        dealerBlip = nil
    end

    if not Config.Dealer.Blip.Enabled then return end

    dealerBlip = AddBlipForCoord(dealerCoords.x, dealerCoords.y, dealerCoords.z)
    SetBlipSprite(dealerBlip, Config.Dealer.Blip.Sprite)
    SetBlipColour(dealerBlip, Config.Dealer.Blip.Color)
    SetBlipScale(dealerBlip, Config.Dealer.Blip.Scale)
    SetBlipAsShortRange(dealerBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(TranslateCap('blip_drugdealer'))
    EndTextCommandSetBlipName(dealerBlip)
end

RegisterNetEvent('mafin_weedsystem:updateDealerLocation', function(coords)
    if not coords or not coords.x or not coords.y or not coords.z then return end

    dealerCoords = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    dealerHeading = tonumber(coords.heading) or 0.0
    updateDealerBlip()
    spawnDealerPed()
end)

RegisterNetEvent('mafin_weedsystem:psDispatchAlert', function(coords)
    if GetResourceState(Config.Dispatch.PSResource) ~= 'started' then return end
    if not coords or not coords.x or not coords.y or not coords.z then return end

    local alertCoords = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    local success, errorMessage = pcall(function()
        exports[Config.Dispatch.PSResource]:CustomAlert({
            coords = alertCoords,
            message = TranslateCap('dispatch_message'),
            dispatchCode = Config.Dispatch.Code,
            description = TranslateCap('dispatch_title'),
            radius = 0,
            sprite = Config.Dispatch.Sprite,
            color = Config.Dispatch.Color,
            scale = Config.Dispatch.Scale,
            length = Config.Dispatch.Duration,
            jobs = Config.Dispatch.Jobs
        })
    end)

    if not success then
        print(('[%s] ps-dispatch alert failed: %s'):format(RESOURCE, errorMessage))
    end
end)

RegisterNetEvent('mafin_weedsystem:playDealerExchange', function()
    if dealerBusy or not dealerPed or not DoesEntityExist(dealerPed) then return end

    local playerPed = PlayerPedId()
    local exchangeDealer = dealerPed
    if #(GetEntityCoords(playerPed) - GetEntityCoords(exchangeDealer)) > Config.Dealer.ServerRadius then return end

    dealerBusy = true
    local animation = Config.Dealer.ExchangeAnimation
    RequestAnimDict(animation.Dict)
    while not HasAnimDictLoaded(animation.Dict) do Wait(25) end

    ClearPedTasks(exchangeDealer)
    TaskTurnPedToFaceEntity(playerPed, exchangeDealer, 400)
    TaskTurnPedToFaceEntity(exchangeDealer, playerPed, 400)
    Wait(400)

    TaskPlayAnim(playerPed, animation.Dict, animation.PlayerClip, 8.0, -8.0, animation.Duration, 49, 0.0, false, false, false)
    TaskPlayAnim(exchangeDealer, animation.Dict, animation.DealerClip, 8.0, -8.0, animation.Duration, 49, 0.0, false, false, false)
    Wait(animation.Duration)

    StopAnimTask(playerPed, animation.Dict, animation.PlayerClip, 1.0)
    if DoesEntityExist(exchangeDealer) then
        StopAnimTask(exchangeDealer, animation.Dict, animation.DealerClip, 1.0)
    end
    RemoveAnimDict(animation.Dict)

    if DoesEntityExist(exchangeDealer) and exchangeDealer == dealerPed and Config.Dealer.Scenario and Config.Dealer.Scenario ~= '' then
        TaskStartScenarioInPlace(exchangeDealer, Config.Dealer.Scenario, 0, true)
    end

    dealerBusy = false
end)

CreateThread(function()
    math.randomseed(GetGameTimer() + PlayerId())
    createBlips()

    if Config.Interaction == 'target' then
        if targetEnabled() then
            initializeTargetInteractions()
        else
            print(('[%s] %s is not started; falling back to esx_textui.'):format(RESOURCE, Config.TargetResource))
            Config.Interaction = 'textui'
            createTextUILoop()
        end
    elseif Config.Interaction == 'textui' then
        createTextUILoop()
    else
        print(('[%s] Invalid Config.Interaction: %s'):format(RESOURCE, tostring(Config.Interaction)))
        return
    end

    TriggerServerEvent('mafin_weedsystem:requestDealerLocation')

    -- Wait until the field is streamed before resolving ground height. This prevents
    -- plants from floating or sinking when the resource starts while the player is far away.
    while #(GetEntityCoords(PlayerPedId()) - Config.Harvest.Center) > Config.Harvest.LoadDistance do
        Wait(1000)
    end

    RequestCollisionAtCoord(Config.Harvest.Center.x, Config.Harvest.Center.y, Config.Harvest.Center.z)
    RequestModel(Config.Harvest.Model)
    while not HasModelLoaded(Config.Harvest.Model) do Wait(50) end

    local generated = {}
    for _ = 1, Config.Harvest.MaxPlants do
        local coords = generatePlantCoords(generated)
        if coords then
            generated[#generated + 1] = coords
            spawnPlant(coords, targetEnabled())
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end

    hideTextUI()
    deleteDealerPed()
    if dealerBlip and DoesBlipExist(dealerBlip) then
        RemoveBlip(dealerBlip)
    end
    if targetEnabled() then
        for _, zone in pairs(targetZones) do
            exports[Config.TargetResource]:removeZone(zone)
        end
        for entity in pairs(plants) do
            exports[Config.TargetResource]:removeLocalEntity(entity, 'mafin_weedsystem_harvest')
        end
    end

    for entity in pairs(plants) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    SetModelAsNoLongerNeeded(Config.Harvest.Model)
end)
