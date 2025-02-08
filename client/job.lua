local config = require 'config.client'
local sharedConfig = require 'config.shared'

JobCached = QBX.PlayerData?.job

-- Events
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if job.type == 'ems' and job.onduty then
        TriggerServerEvent('QBCore:Everfall:EMSClockIn')
    elseif QBX.PlayerData.job.type == 'ems' and job.type ~= 'ems' then
        TriggerServerEvent('QBCore:Everfall:EMSClockOut')
    end

    JobCached = job
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    if QBX.PlayerData.job.type == 'ems' then
        if duty then
            TriggerServerEvent('QBCore:Everfall:EMSClockIn')
        else
            TriggerServerEvent('QBCore:Everfall:EMSClockOut')
        end
    end

    JobCached.onduty = duty
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if QBX.PlayerData.job.type == 'ems' and QBX.PlayerData.job.onduty then
        TriggerServerEvent('QBCore:Everfall:EMSClockIn')
    end

    JobCached = QBX.PlayerData.job
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if JobCached.type == 'ems' and JobCached.onduty then
        TriggerServerEvent('QBCore:Everfall:EMSClockOut')
    end

    JobCached = nil
end)

---Show patient's treatment menu.
---@param status string[]
local function showTreatmentMenu(status)
    local statusMenu = {}
    for i = 1, #status do
        statusMenu[i] = {
            title = status[i],
            event = 'hospital:client:TreatWounds',
        }
    end

    lib.registerContext({
        id = 'ambulance_status_context_menu',
        title = locale('menu.status'),
        options = statusMenu
    })

    lib.showContext('ambulance_status_context_menu')
end

---Check status of nearest player and show treatment menu.
---Intended to be invoked by client or server.
RegisterNetEvent('hospital:client:CheckStatus', function()
    local player = lib.getClosestPlayer(GetEntityCoords(cache.ped), 5.0)
    if not player then
        lib.notify({ title = locale('error.no_player'), type = 'error' })
        return
    end

    local playerId = GetPlayerServerId(player)

    local status = lib.callback.await('qbx_ambulancejob:server:getPlayerStatus', false, playerId)
    if #status.injuries == 0 then
        lib.notify({ title = locale('success.healthy_player'), type = 'success' })
        return
    end

    --[[
    for hash in pairs(status.damageCauses) do
        TriggerEvent('chat:addMessage', {
            color = { 255, 0, 0 },
            multiline = false,
            args = { locale('info.status'), WEAPONS[hash].damagereason }
        })
    end
    ]]

    if status.bleedLevel > 0 then
        TriggerEvent('chat:addMessage', {
            color = { 255, 0, 0 },
            multiline = false,
            args = { locale('info.status'), locale('info.is_status', status.bleedState) }
        })
    end

    showTreatmentMenu(status.injuries)
end)

---Use first aid on nearest player to revive them.
---Intended to be invoked by client or server.
RegisterNetEvent('hospital:client:RevivePlayer', function()
    local hasFirstAid = exports.ox_inventory:Search('count', 'firstaid') > 0
    if not hasFirstAid then
        lib.notify({ title = locale('error.no_firstaid'), type = 'error' })
        return
    end

    local player = lib.getClosestPlayer(GetEntityCoords(cache.ped), 5.0)
    if not player then
        lib.notify({ title = locale('error.no_player'), type = 'error' })
        return
    end

    if lib.progressCircle({
            duration = 5000,
            position = 'bottom',
            label = locale('progress.revive'),
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = false,
                car = false,
                combat = true,
                mouse = false,
            },
            anim = {
                dict = HealAnimDict,
                clip = HealAnim,
            },
        })
    then
        StopAnimTask(cache.ped, HealAnimDict, 'exit', 1.0)
        lib.notify({ title = locale('success.revived'), type = 'success' })
        TriggerServerEvent('hospital:server:RevivePlayer', GetPlayerServerId(player))
    else
        StopAnimTask(cache.ped, HealAnimDict, 'exit', 1.0)
        lib.notify({ title = locale('error.canceled'), type = 'error' })
    end
end)

---Use bandage on nearest player to treat their wounds.
---Intended to be invoked by client or server.
RegisterNetEvent('hospital:client:TreatWounds', function()
    local hasBandage = exports.ox_inventory:Search('count', 'bandage') > 0
    if not hasBandage then
        lib.notify({ title = locale('error.no_bandage'), type = 'error' })
        return
    end

    local player = lib.getClosestPlayer(GetEntityCoords(cache.ped), 5.0)
    if not player then
        lib.notify({ title = locale('error.no_player'), type = 'error' })
        return
    end

    if lib.progressCircle({
            duration = 5000,
            position = 'bottom',
            label = locale('progress.healing'),
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = false,
                car = false,
                combat = true,
                mouse = false,
            },
            anim = {
                dict = HealAnimDict,
                clip = HealAnim,
            },
        })
    then
        StopAnimTask(cache.ped, HealAnimDict, 'exit', 1.0)
        lib.notify({ title = locale('success.helped_player'), type = 'success' })
        TriggerServerEvent('hospital:server:TreatWounds', GetPlayerServerId(player))
    else
        StopAnimTask(cache.ped, HealAnimDict, 'exit', 1.0)
        lib.notify({ title = locale('error.canceled'), type = 'error' })
    end
end)

---Opens the hospital armory.
---@param armoryId integer id of armory to open
---@param stashId integer id of armory to open
local function openArmory(armoryId, stashId)
    if not QBX.PlayerData.job.onduty then return end
    exports.ox_inventory:openInventory('shop', { type = sharedConfig.locations.armory[armoryId].shopType, id = stashId })
end

---Toggles the on duty status of the player.
local function toggleDuty()
    TriggerServerEvent('QBCore:ToggleDuty')
    TriggerServerEvent('police:server:UpdateBlips')
end

---Sets up duty toggle, stash, armory, and elevator interactions using either target or zones.
if config.useTarget then
    CreateThread(function()
        for i = 1, #sharedConfig.locations.duty do
            exports.ox_target:addBoxZone({
                name = 'duty' .. i,
                coords = sharedConfig.locations.duty[i],
                size = vec3(1.5, 1, 2),
                rotation = 71,
                debug = config.debugPoly,
                options = {
                    {
                        icon = 'fa fa-clipboard',
                        label = locale('text.duty'),
                        onSelect = toggleDuty,
                        distance = 2,
                        groups = 'ambulance',
                    }
                }
            })
        end

        for i = 1, #sharedConfig.locations.armory do
            for ii = 1, #sharedConfig.locations.armory[i].locations do
                exports.ox_target:addBoxZone({
                    name = 'armory' .. i .. ':' .. ii,
                    coords = sharedConfig.locations.armory[i].locations[ii],
                    size = vec3(1, 1, 2),
                    rotation = -20,
                    debug = config.debugPoly,
                    options = {
                        {
                            icon = 'fa fa-clipboard',
                            label = locale('text.armory'),
                            onSelect = function()
                                openArmory(i, ii)
                            end,
                            distance = 1.5,
                            groups = 'ambulance',
                        }
                    }
                })
            end
        end
    end)
else
    CreateThread(function()
        for i = 1, #sharedConfig.locations.duty do
            lib.zones.box({
                coords = sharedConfig.locations.duty[i],
                size = vec3(1, 1, 2),
                rotation = -20,
                debug = config.debugPoly,
                onEnter = function()
                    local label = QBX.PlayerData.job.onduty and locale('text.onduty_button') or
                        locale('text.offduty_button')
                    lib.showTextUI(label)
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                inside = function()
                    OnKeyPress(toggleDuty)
                end,
            })
        end

        for i = 1, #sharedConfig.locations.armory do
            for ii = 1, #sharedConfig.locations.armory[i].locations do
                lib.zones.box({
                    coords = sharedConfig.locations.armory[i].locations[ii],
                    size = vec3(1, 1, 2),
                    rotation = -20,
                    debug = config.debugPoly,
                    onEnter = function()
                        if QBX.PlayerData.job.onduty then
                            lib.showTextUI(locale('text.armory_button'))
                        end
                    end,
                    onExit = function()
                        lib.hideTextUI()
                    end,
                    inside = function()
                        OnKeyPress(function()
                            openArmory(i, ii)
                        end)
                    end,
                })
            end
        end
    end)
end