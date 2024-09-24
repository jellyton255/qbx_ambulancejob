local webhooks = exports.ef_nexus:GetWebhooks()

return {
    doctorCallCooldown = 1,   -- Time in minutes for cooldown between doctors calls
    wipeInvOnRespawn = false, -- Enable to disable removing all items from player on respawn
    depositSociety = function(society, amount, reason, metadata)
        exports.fd_banking:AddMoney(society, amount, reason, metadata)
    end,
    logWebhook = webhooks.Logging.EMSDuty
}