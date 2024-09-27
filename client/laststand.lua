local isEscorting = false

---@param bool boolean
---TODO: this event name should be changed within qb-policejob to be generic
AddEventHandler('hospital:client:SetEscortingState', function(bool)
    isEscorting = bool
end)

---Use first aid pack on nearest player.
lib.callback.register('hospital:client:UseFirstAid', function()
    if isEscorting then
        exports.qbx_core:Notify(locale('error.impossible'), 'error')
        return
    end

    if IsPedGettingIntoAVehicle(ped) then
        exports.qbx_core:Notify("You cannot do this right now.", 'error')
        return
    end

    local player = GetClosestPlayer()
    if player then
        local playerId = GetPlayerServerId(player)
        TriggerServerEvent('hospital:server:UseFirstAid', playerId)
    end
end)

lib.callback.register('hospital:client:canHelp', function()
    return exports.qbx_medical:getLaststand() and exports.qbx_medical:getLaststandTime() <= 300
end)