lib.callback.register('hospital:client:UseFirstAid', function()
    if LocalPlayer.state.isEscorting then
        lib.notify({ title = "You cannot do this right now.", type = 'error' })
        return
    end

    if IsPedGettingIntoAVehicle(cache.ped) then
        lib.notify({ title = "You cannot do this right now.", type = 'error' })
        return
    end

    local player = lib.getClosestPlayer(GetEntityCoords(cache.ped), 5.0)

    if not player then return end

    local playerId = GetPlayerServerId(player)
    TriggerServerEvent('hospital:server:UseFirstAid', playerId)
end)

lib.callback.register('hospital:client:canHelp', function()
    return exports.qbx_medical:getLaststand() and exports.qbx_medical:getLaststandTime() <= 300
end)

---@param targetId number playerId
RegisterNetEvent('hospital:client:HelpPerson', function(targetId)
    if GetInvokingResource() then return end
    if lib.progressCircle({
            duration = math.random(30000, 60000),
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
        lib.notify({ title = locale('success.revived'), type = 'success' })
        TriggerServerEvent('hospital:server:RevivePlayer', targetId)
    end

    ClearPedTasks(cache.ped)
end)