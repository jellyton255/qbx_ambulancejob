local sharedConfig = require 'config.shared'
InBedDict = 'anim@gangops@morgue@table@'
InBedAnim = 'body_search'
IsInHospitalBed = false
HealAnimDict = 'mini@cpr@char_a@cpr_str'
HealAnim = 'cpr_pumpchest'
EmsNotified = false
CanLeaveBed = true
OnPainKillers = false

---Revives player, healing all injuries
---Intended to be called from client or server.
RegisterNetEvent('hospital:client:Revive', function()
    lib.print.info('hospital:client:Revive', 'IsInHospitalBed', IsInHospitalBed)

    if IsInHospitalBed then
        lib.requestAnimDict(InBedDict)
        TaskPlayAnim(cache.ped, InBedDict, InBedAnim, 8.0, 1.0, -1, 1, 0, false, false, false)
        TriggerEvent('qbx_medical:client:playerRevived')
        lib.callback.await('qbx_medical:server:resetHungerAndThirst')
        CanLeaveBed = true

        lib.print.info("Healed in hospital, we are clear to leave the bed now.")
    end

    EmsNotified = false
end)

RegisterNetEvent('qbx_medical:client:playerRevived', function()
    EmsNotified = false
end)

---Sends player phone email with hospital bill.
---@param amount number
RegisterNetEvent('hospital:client:SendBillEmail', function(amount)
    if GetInvokingResource() then return end
    SetTimeout(math.random(2500, 4000), function()
        local charInfo = QBX.PlayerData.charinfo
        local gender = charInfo.gender == 1 and locale('info.mrs') or locale('info.mr')
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = locale('mail.sender'),
            subject = locale('mail.subject'),
            message = locale('mail.message', gender, charInfo.lastname, amount),
            button = {}
        })
    end)
end)

---Sets blips for stations on map
CreateThread(function()
    for _, station in pairs(sharedConfig.locations.stations) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 61)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 25)
        AddTextEntry(station.label, station.label)
        BeginTextCommandSetBlipName(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)

function OnKeyPress(cb)
    if IsControlJustPressed(0, 38) then
        lib.hideTextUI()
        cb()
    end
end