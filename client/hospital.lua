local config = require 'config.client'
local sharedConfig = require 'config.shared'
local bedObject
local bedOccupyingData
local cam
local hospitalOccupying
local bedIndexOccupying
local playerState = LocalPlayer.state
local Interactions = {}

---Teleports the player to lie down in bed and sets the player's camera.
local function setBedCam()
    DoScreenFadeOut(1000)

    while not IsScreenFadedOut() do
        Wait(100)
    end

    if IsPedDeadOrDying(cache.ped, true) then
        local pos = GetEntityCoords(cache.ped)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(cache.ped), 0, false)
    end

    if not bedOccupyingData then
        lib.print.error("No bed data found for", hospitalOccupying, bedIndexOccupying)
        return
    end

    bedObject = GetClosestObjectOfType(bedOccupyingData.coords.x, bedOccupyingData.coords.y, bedOccupyingData.coords.z,
        1.0, bedOccupyingData.model, false, false, false)

    FreezeEntityPosition(bedObject, true)

    SetEntityCoords(cache.ped, bedOccupyingData.coords.x, bedOccupyingData.coords.y, bedOccupyingData.coords.z + 0.02,
        true, true, true, false)

    Wait(500)

    FreezeEntityPosition(cache.ped, true)

    lib.requestAnimDict(InBedDict)

    TaskPlayAnim(cache.ped, InBedDict, InBedAnim, 8.0, 1.0, -1, 1, 0, false, false, false)
    SetEntityHeading(cache.ped, bedOccupyingData.coords.w)

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 1, true, true)
    AttachCamToPedBone(cam, cache.ped, 31085, 0, 1.0, 1.0, true)
    SetCamFov(cam, 90.0)
    local heading = GetEntityHeading(cache.ped)
    heading = (heading > 180) and heading - 180 or heading + 180
    SetCamRot(cam, -45.0, 0.0, heading, 2)

    DoScreenFadeIn(1000)

    Wait(1000)
    FreezeEntityPosition(cache.ped, true)
end

local function putPlayerInBed(hospitalName, bedIndex, isRevive, skipOpenCheck)
    lib.print.info('putPlayerInBed', hospitalName, bedIndex, isRevive, skipOpenCheck, IsInHospitalBed)

    if IsInHospitalBed then
        lib.print.warn("IsInHospitalBed: Player already in bed")
        return
    end

    if not skipOpenCheck then
        if lib.callback.await('qbx_ambulancejob:server:isBedTaken', false, hospitalName, bedIndex) then
            lib.notify({ title = locale('error.beds_taken'), type = 'error' })
            return
        end
    end

    lib.print.info("In Bed")

    hospitalOccupying = hospitalName
    bedIndexOccupying = bedIndex
    bedOccupyingData = sharedConfig.locations.hospitals[hospitalName].beds[bedIndex]
    IsInHospitalBed = true

    exports.qbx_medical:DisableDamageEffects()
    exports.qbx_medical:disableRespawn()

    CanLeaveBed = false

    setBedCam()

    CreateThread(function()
        lib.print.info("Starting healing thread (something goes wrong with respawning somewhere here probably)")
        Wait(5)
        if isRevive or isRevive == nil then
            lib.notify({ title = locale('success.being_helped'), type = 'success' })
            Wait(config.aiHealTimer * 1000)
            TriggerEvent('hospital:client:Revive')
        else
            lib.print.info("Can leave ped since no revive.")
            CanLeaveBed = true
        end
    end)

    TriggerServerEvent('qbx_ambulancejob:server:playerEnteredBed', hospitalName, bedIndex)
end

RegisterNetEvent('qbx_ambulancejob:client:putPlayerInBed', function(hospitalName, bedIndex)
    putPlayerInBed(hospitalName, bedIndex, true, true)
end)

---Notifies doctors, and puts player in a hospital bed.
local function checkIn(hospitalName)
    local canCheckIn = lib.callback.await('qbx_ambulancejob:server:canCheckIn', false, hospitalName)
    if not canCheckIn then return end

    if lib.progressCircle({
            duration = 2000,
            position = 'bottom',
            label = locale('progress.checking_in'),
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true,
                mouse = false,
            },
            anim = {
                clip = 'base',
                dict = 'missheistdockssetup1clipboard@base',
                flag = 16
            },
            prop = {
                {
                    model = 'prop_notepad_01',
                    bone = 18905,
                    pos = vec3(0.1, 0.02, 0.05),
                    rot = vec3(10.0, 0.0, 0.0),
                },
                {
                    model = 'prop_pencil_01',
                    bone = 58866,
                    pos = vec3(0.11, -0.02, 0.001),
                    rot = vec3(-120.0, 0.0, 0.0)
                }
            }
        })
    then
        lib.callback('qbx_ambulancejob:server:checkIn', false, nil, cache.serverId, hospitalName)
    else
        lib.notify({ title = locale('error.canceled'), type = 'error' })
    end
end

RegisterNetEvent('qbx_ambulancejob:client:checkedIn', function(hospitalName, bedIndex)
    putPlayerInBed(hospitalName, bedIndex, true, true)
end)

---Set up check-in and getting into beds using either target or zones
if config.useTarget then
    CreateThread(function()
        for hospitalName, hospital in pairs(sharedConfig.locations.hospitals) do
            if hospital.checkIn then
                exports.sleepless_interact:addCoords({
                    id = hospitalName .. '_checkin',
                    coords = hospital.checkIn,
                    renderDistance = 7.5,
                    activeDistance = 2.5,
                    debug = config.debugPoly,
                    options = {
                        {
                            label = locale('text.check'),
                            icon = 'fas fa-clipboard',
                            onSelect = function()
                                checkIn(hospitalName)
                            end,
                        },
                        {
                            label = "Check Carried Person In",
                            icon = "fa fa-clipboard",
                            canInteract = function()
                                return playerState.isCarrying or playerState.isEscorting
                            end,
                            onSelect = function()
                                local player = playerState.isCarrying or playerState.isEscorting
                                if player then
                                    TriggerServerEvent('hospital:server:putPlayerInBed', player, hospitalName,
                                        lib.callback.await("qbx_ambulancejob:server:getOpenBed", false, hospitalName))
                                end
                            end,
                        }
                    }
                })

                Interactions[#Interactions + 1] = hospitalName .. '_checkin'
            end

            for i = 1, #hospital.beds do
                local bed = hospital.beds[i]
                exports.ox_target:addBoxZone({
                    name = hospitalName .. '_bed_' .. i,
                    coords = bed.coords.xyz,
                    size = vec3(1.7, 1.9, 2),
                    rotation = bed.coords.w,
                    debug = config.debugPoly,
                    options = {
                        {
                            canInteract = function()
                                return not IsInHospitalBed
                            end,
                            onSelect = function()
                                putPlayerInBed(hospitalName, i, true)
                            end,
                            icon = 'fas fa-clipboard',
                            label = locale('text.bed'),
                            distance = 1.5,
                        },
                        {
                            canInteract = function()
                                return (playerState.isCarrying or playerState.isEscorting) and not IsInHospitalBed
                            end,
                            onSelect = function()
                                local player = playerState.isCarrying or playerState.isEscorting
                                if player then
                                    TriggerServerEvent('hospital:server:putPlayerInBed', player, hospitalName, i)
                                end
                            end,
                            icon = 'fas fa-clipboard',
                            label = locale('text.put_bed'),
                            distance = 1.5,
                        }
                    }
                })
            end
        end
    end)
end

local rightOffset = -1

---Plays animation to get out of bed and resets variables
local function leaveBed()
    lib.requestAnimDict('switch@franklin@bed')
    FreezeEntityPosition(cache.ped, false)
    SetEntityInvincible(cache.ped, false)
    SetEntityHeading(cache.ped, bedOccupyingData.coords.w + 90)
    TaskPlayAnim(cache.ped, 'switch@franklin@bed', 'sleep_getup_rubeyes', 100.0, 1.0, -1, 8, -1, false, false, false)

    Wait(4000)
    ClearPedTasks(cache.ped)

    local newX = bedOccupyingData.coords.x + rightOffset * math.sin(math.rad(bedOccupyingData.coords.w))
    local newY = bedOccupyingData.coords.y + rightOffset * math.cos(math.rad(bedOccupyingData.coords.w))
    SetEntityCoords(cache.ped, newX, newY, bedOccupyingData.coords.z - 1.0)

    TriggerServerEvent('qbx_ambulancejob:server:playerLeftBed', hospitalOccupying, bedIndexOccupying)
    FreezeEntityPosition(bedObject, true)
    RenderScriptCams(false, true, 200, true, true)
    DestroyCam(cam, false)

    hospitalOccupying = nil
    bedIndexOccupying = nil
    bedObject = nil
    bedOccupyingData = nil
    IsInHospitalBed = false
    exports.qbx_medical:EnableDamageEffects()

    if QBX.PlayerData.metadata.injail then return end

    TriggerEvent('prison:client:Enter', QBX.PlayerData.metadata.injail)
end

---Shows player option to press key to leave bed when available.
CreateThread(function()
    while true do
        if IsInHospitalBed and CanLeaveBed then
            lib.showTextUI(locale('text.bed_out'))
            while IsInHospitalBed and CanLeaveBed do
                OnKeyPress(leaveBed)
                Wait(0)
            end
            lib.hideTextUI()
        else
            Wait(1000)
        end
    end
end)

---Reset player settings that the server is storing
local function onPlayerUnloaded()
    if bedIndexOccupying then
        TriggerServerEvent('qbx_ambulancejob:server:playerLeftBed', hospitalOccupying, bedIndexOccupying)
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerUnload', onPlayerUnloaded)

AddEventHandler('onResourceStop', function(resourceName)
    if cache.resource ~= resourceName then return end
    lib.hideTextUI()
    onPlayerUnloaded()

    for _, interaction in ipairs(Interactions) do
        exports.sleepless_interact:removeById(interaction)
    end
end)