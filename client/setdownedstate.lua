local config = require 'config.client'
local sharedConfig = require 'config.shared'
local textLocation = vec2(1.0, 1.40)
local textRequestOffset = vec2(0, 0.04)

local function getDoctorCount()
    return lib.callback.await('qbx_ambulancejob:server:getNumDoctors', 60000)
end

local doctorCount = getDoctorCount() or 0

local function displayRespawnText()
    local deathTime = exports.qbx_medical:getDeathTime()

    local updatedCount
    CreateThread(function()
        updatedCount = getDoctorCount()
    end)

    if updatedCount then
        lib.print.debug("updating count: ", updatedCount)
        doctorCount = updatedCount
    end

    if deathTime > 0 and doctorCount > 0 then
        qbx.drawText2d({ text = locale('info.respawn_txt', math.ceil(deathTime)), coords = textLocation, scale = 0.6 })
    else
        qbx.drawText2d({
            text = locale('info.respawn_revive', exports.qbx_medical:getRespawnHoldTimeDeprecated(),
                sharedConfig.checkInCost),
            coords = textLocation,
            scale = 0.6
        })
    end
end

---@param ped number
local function playDeadAnimation(ped)
    if IsInHospitalBed then
        if not IsEntityPlayingAnim(ped, InBedDict, InBedAnim, 3) then
            lib.requestAnimDict(InBedDict)
            TaskPlayAnim(ped, InBedDict, InBedAnim, 1.0, 1.0, -1, 1, 0, false, false, false)
        end
    else
        exports.qbx_medical:playDeadAnimation()
    end
end

---@param ped number
local function handleDead(ped)
    if not IsInHospitalBed then
        displayRespawnText()
    end

    playDeadAnimation(ped)
end

---Player is able to send a notification to EMS there are any on duty
local function handleRequestingEms()
    if not EmsNotified then
        qbx.drawText2d({ text = locale('info.request_help'), coords = textLocation - textRequestOffset, scale = 0.6 })
        if IsControlJustPressed(0, 47) then
            TriggerServerEvent('cd_dispatch:AddNotification', {
                job_table = { 'fire' },
                coords = GetEntityCoords(cache.ped),
                title = 'Downed Individual',
                message = 'Citizens reporting a downed individual.',
                flash = 0,
                unique_id = tostring(math.random(0000000, 9999999)),
                blip = {
                    sprite = 280,
                    scale = 1.2,
                    colour = 1,
                    flashes = false,
                    text = 'Downed Individual',
                    time = (5 * 60 * 1000),
                    sound = 1,
                }
            })
            --TriggerServerEvent('hospital:server:ambulanceAlert', locale('info.civ_down'))
            EmsNotified = true
        end
    else
        qbx.drawText2d({ text = locale('info.help_requested'), coords = textLocation - textRequestOffset, scale = 0.6 })
    end
end

local function handleLastStand()
    local updatedCount
    CreateThread(function()
        updatedCount = getDoctorCount()
    end)

    if updatedCount then
        lib.print.debug("updating count: ", updatedCount)
        doctorCount = updatedCount
    end

    local laststandTime = exports.qbx_medical:getLaststandTime()
    if laststandTime > config.laststandTimer or doctorCount == 0 then
        qbx.drawText2d({ text = locale('info.bleed_out', math.ceil(laststandTime)), coords = textLocation, scale = 0.6 })
    else
        qbx.drawText2d({ text = locale('info.bleed_out_help', math.ceil(laststandTime)), coords = textLocation, scale = 0.6 })
        handleRequestingEms()
    end
end

---Set dead and last stand states.
CreateThread(function()
    while true do
        local isDead = exports.qbx_medical:isDead()
        local inLaststand = exports.qbx_medical:getLaststand()
        if isDead or inLaststand then
            if isDead then
                handleDead(cache.ped)
            elseif inLaststand then
                handleLastStand()
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)