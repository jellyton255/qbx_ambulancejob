local sharedConfig = require 'config.shared'
local serverConfig = require 'config.server'

---@alias source number

lib.callback.register('qbx_ambulancejob:server:getPlayerStatus', function(_, targetSrc)
	return exports.qbx_medical:GetPlayerStatus(targetSrc)
end)

local function registerArmory()
	for _, armory in pairs(sharedConfig.locations.armory) do
		exports.ox_inventory:RegisterShop(armory.shopType, armory)
	end
end

---@param playerId number
RegisterNetEvent('hospital:server:TreatWounds', function(playerId)
	local src = source

	lib.print.debug('hospital:server:TreatWounds', playerId)

	if GetInvokingResource() then return end
	local player = exports.qbx_core:GetPlayer(src)
	local patient = exports.qbx_core:GetPlayer(playerId)

	if player.PlayerData.job.type ~= 'ems' or not patient then return end

	if not exports.ox_inventory:RemoveItem(src, 'bandage', 1) then
		lib.print.warn("hospital:server:TreatWounds called by " .. src .. " but they didn't have a bandage.")
		return
	end
	lib.callback.await('qbx_medical:client:heal', playerId, 'full')
end)

local reviveCost = sharedConfig.reviveCost
local revivePayment = math.floor((reviveCost * 0.4) + 0.5)

---@param playerId number
RegisterNetEvent('hospital:server:RevivePlayer', function(playerId)
	if GetInvokingResource() then return end
	local player = exports.qbx_core:GetPlayer(source)
	local patient = exports.qbx_core:GetPlayer(playerId)

	if not patient then return end

	if player.PlayerData.job.type == 'ems' then
		patient.Functions.RemoveMoney("bank", reviveCost,
			"San Andreas Medical Network - Payment", {
				type = "purchase:services",
				subtype = 'medical',
				business = player.PlayerData.job.name,
			})
		exports.fd_banking:AddMoney(player.PlayerData.job.name, reviveCost - revivePayment,
			"San Andreas Medical Network - Payment", {
				type = "sale:services",
				subtype = 'medical',
				employee = player.PlayerData.citizenid,
				purchaser = patient.PlayerData.citizenid
			}
		)
		player.Functions.AddMoney("bank", revivePayment,
			"San Andreas Medical Network - Pay", {
				type = "commission:services",
				subtype = 'medical',
				business = player.PlayerData.job.name,
			}
		)

		TriggerClientEvent('hospital:client:SendBillEmail', patient.PlayerData.source, reviveCost)
	end

	exports.ox_inventory:RemoveItem(player.PlayerData.source, 'firstaid', 1)
	TriggerClientEvent('qbx_medical:client:playerRevived', patient.PlayerData.source)
end)

---@param targetId number
RegisterNetEvent('hospital:server:UseFirstAid', function(targetId)
	if GetInvokingResource() then return end
	local src = source
	local target = exports.qbx_core:GetPlayer(targetId)
	if not target then return end

	local canHelp = lib.callback.await('hospital:client:canHelp', targetId)
	if not canHelp then
		exports.qbx_core:Notify(src, locale('error.cant_help'), 'error')
		return
	end

	TriggerClientEvent('hospital:client:HelpPerson', src, targetId)
	local Player = exports.qbx_core:GetPlayer(src)
	local Player2 = exports.qbx_core:GetPlayer(targetId)

	exports.ef_prime:CreateLog("PlayerHospitalEnteredBed", "Used First Aid Kit", "green", nil, false, {
		author = {
			name = GetPlayerName(src) .. " (Citizen ID: " .. Player.PlayerData.citizenid .. ")"
		},
		fields = {
			{
				name = "Target",
				value = GetPlayerName(targetId) .. " (Citizen ID: " .. Player2.PlayerData.citizenid .. ")",
				inline = true
			},
		}
	}, src)
end)

lib.callback.register('qbx_ambulancejob:server:getNumDoctors', function()
	return exports.qbx_core:GetDutyCountType('ems')
end)


---@param src number
---@param event string
local function triggerEventOnEmsPlayer(src, event)
	local player = exports.qbx_core:GetPlayer(src)
	if player.PlayerData.job.type ~= 'ems' then
		lib.notify({ title = locale('error.not_ems'), type = 'error' })
		return
	end

	TriggerClientEvent(event, src)
end

lib.addCommand('status', {
	help = locale('info.check_health'),
}, function(source)
	triggerEventOnEmsPlayer(source, 'hospital:client:CheckStatus')
end)

lib.addCommand('heal', {
	help = locale('info.heal_player'),
}, function(source)
	triggerEventOnEmsPlayer(source, 'hospital:client:TreatWounds')
end)

lib.addCommand('revivep', {
	help = locale('info.revive_player'),
}, function(source)
	triggerEventOnEmsPlayer(source, 'hospital:client:RevivePlayer')
end)

-- Items
---@param src number
---@param item table
---@param event string
local function triggerItemEventOnPlayer(src, item, event)
	local player = exports.qbx_core:GetPlayer(src)
	if not player then return end

	if exports.ox_inventory:Search(src, 'count', item.name) == 0 then return end

	if player.PlayerData.metadata.isdead or player.PlayerData.metadata.inlaststand or Player(src).state.isCuffed then
		exports.qbx_core:Notify(src, "You cannot do this right now.", 'error')
		return
	end

	local removeItem = lib.callback.await(event, src)
	if not removeItem then return end

	exports.ox_inventory:RemoveItem(src, item.name, 1)
end

exports.qbx_core:CreateUseableItem('ifaks', function(source, item)
	triggerItemEventOnPlayer(source, item, 'hospital:client:UseIfaks')
end)

exports.qbx_core:CreateUseableItem('bandage', function(source, item)
	triggerItemEventOnPlayer(source, item, 'hospital:client:UseBandage')
end)

exports.qbx_core:CreateUseableItem('painkillers', function(source, item)
	triggerItemEventOnPlayer(source, item, 'hospital:client:UsePainkillers')
end)

exports.qbx_core:CreateUseableItem('firstaid', function(source, item)
	triggerItemEventOnPlayer(source, item, 'hospital:client:UseFirstAid')
end)

--[[
RegisterNetEvent('qbx_medical:server:playerDied', function()
	if GetInvokingResource() then return end
	local src = source
	alertAmbulance(src, locale('info.civ_died'))
end)
]]

AddEventHandler('onResourceStart', function(resource)
	if resource ~= GetCurrentResourceName() then return end

	registerArmory()
end)

RegisterNetEvent('QBCore:Everfall:EMS:Timeclock', function(player, ClockingIn)
	local source = player.PlayerData.source
	local department = "SAMS"
	local data = {
		Webhook = serverConfig.logWebhook,
		Icon = "https://files.jellyton.me/ShareX/2023/04/LSCFD-GTAV-Logo.png"
	}

	local name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
	local discordId = exports.ef_lib:GetDiscordID(source)
	local message
	if ClockingIn then
		message = ":inbox_tray:  **" .. name .. " (<@" .. discordId .. ">)** has clocked in for duty."
	else
		message = ":outbox_tray:  **" .. name .. " (<@" .. discordId .. ">)** has clocked out."
	end

	local fields
	if ClockingIn then
		fields = {
			{
				name = "CitizenID",
				value = player.PlayerData.citizenid,
				inline = true,
			},
			{
				name = "Grade",
				value = player.PlayerData.job.grade.name,
				inline = true,
			},
		}
	else
		fields = {
			{
				name = "CitizenID",
				value = player.PlayerData.citizenid,
				inline = true,
			},
			{
				name = "Time Patrolled",
				value = "Unknown",
				inline = true,
			},
		}
	end

	local embedData = {
		{
			['author'] = {
				['name'] = GetPlayerName(source),
				['icon_url'] = exports.ef_discord:GetPlayerAvatar(source),
			},
			['title'] = (ClockingIn and "Clock In") or "Clock Out",
			['color'] = (ClockingIn and 3858002) or 16068139,
			['description'] = message,
			['fields'] = fields,
			['thumbnail'] = {
				['url'] = data.Icon
			}
		}
	}

	PerformHttpRequest(data.Webhook, function()
	end, 'POST', json.encode({
		username = department .. ' Timeclock',
		avatar_url = data.Icon,
		embeds = embedData
	}), { ['Content-Type'] = 'application/json' })
end)

AddEventHandler('playerDropped', function()
	local src = source
	local player = exports.qbx_core:GetPlayer(src)

	if not player then return end
	if not player.PlayerData.job.onduty then return end
	if player.PlayerData.job.type ~= "ems" then return end

	TriggerEvent('QBCore:Everfall:EMS:Timeclock', player, false)
end)

RegisterNetEvent("QBCore:Everfall:EMSClockIn", function(_source)
	local src = source or _source
	local player = exports.qbx_core:GetPlayer(src)

	if not player then return end

	TriggerEvent('QBCore:Everfall:EMS:Timeclock', player, true)
end)

RegisterNetEvent("QBCore:Everfall:EMSClockOut", function(_source)
	local src = source or _source
	local player = exports.qbx_core:GetPlayer(src)

	if not player then return end

	TriggerEvent('QBCore:Everfall:EMS:Timeclock', player, false)
end)