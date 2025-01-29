--- Contains code relevant to the physical hospital building. Things like checking in, beds, spawning vehicles, etc.

local config = require 'config.server'
local sharedConfig = require 'config.shared'
local triggerEventHooks = require '@qbx_core.modules.hooks'
local doctorCalled = false

---@type table<string, table<number, boolean>>
local hospitalBedsTaken = {}

for hospitalName, hospital in pairs(sharedConfig.locations.hospitals) do
	hospitalBedsTaken[hospitalName] = {}
	for i = 1, #hospital.beds do
		hospitalBedsTaken[hospitalName][i] = false
	end
end

local function getOpenBed(hospitalName)
	local beds = hospitalBedsTaken[hospitalName]
	for i = 1, #beds do
		local isTaken = beds[i]
		if not isTaken then return i end
	end
end

lib.callback.register('qbx_ambulancejob:server:getOpenBed', function(_, hospitalName)
	return getOpenBed(hospitalName)
end)

---@param src number
local function billPlayer(src)
	local player = exports.qbx_core:GetPlayer(src)
	player.Functions.RemoveMoney('bank', sharedConfig.checkInCost,
		'San Andreas Medical Network: Medical Bills (Hospital)', {
			type = "purchase:services",
			subtype = "medical"
		})

	config.depositSociety('sams', sharedConfig.checkInCost, "Hospital Bills: " .. player.PlayerData.citizenid, {
		type = "sale:services",
		subtype = "medical",
		purchaser = player.PlayerData.citizenid,
	})

	TriggerClientEvent('hospital:client:SendBillEmail', src, sharedConfig.checkInCost)
end

RegisterNetEvent('qbx_ambulancejob:server:playerEnteredBed', function(hospitalName, bedIndex)
	local src = source

	if GetInvokingResource() then return end

	local playerState = Player(src).state

	if playerState?.isCarrying or playerState?.isEscorting then
		local target = playerState.isCarrying or playerState.isEscorting
		local targetState = Player(target)?.state

		if targetState then
			if playerState.isCarrying then
				playerState.isCarrying = false
				targetState.isCarried = false
			end

			if playerState.isEscorting then
				playerState.isEscorting = false
				targetState.isEscorted = false
			end
		end
	end

	billPlayer(src)

	if playerState then
		playerState.hospitalName = hospitalName
		playerState.bedIndex = bedIndex
	end

	hospitalBedsTaken[hospitalName][bedIndex] = true

	local player = exports.qbx_core:GetPlayer(src)

	if not player then return end

	exports.ef_prime:CreateLog("PlayerHospitalEnteredBed", "Hospital Bed", "green", nil, false, {
		author = {
			name = GetPlayerName(src) .. " (Citizen ID: " .. player.PlayerData.citizenid .. ")"
		},
		fields = {
			{
				name = "Hospital Name",
				value = hospitalName,
				inline = true
			},
			{
				name = "Bed Index",
				value = bedIndex,
				inline = true
			},
		}
	}, src)
end)

RegisterNetEvent('qbx_ambulancejob:server:playerLeftBed', function(hospitalName, bedIndex)
	if GetInvokingResource() then return end
	hospitalBedsTaken[hospitalName][bedIndex] = false
end)

AddEventHandler('playerDropped', function()
	local src = source

	local playerState = Player(src).state

	if not playerState?.hospitalName or not playerState?.bedIndex then return end

	hospitalBedsTaken[playerState.hospitalName][playerState.bedIndex] = false

	playerState.hospitalName = nil
	playerState.bedIndex = nil
end)

---@param playerId number
---@param hospitalName string
---@param bedIndex number
RegisterNetEvent('hospital:server:putPlayerInBed', function(playerId, hospitalName, bedIndex)
	if GetInvokingResource() then return end
	local src = source

	local playerState = Player(src).state
	if playerState.isCarrying or playerState.isEscorting then
		local target = playerState.isCarrying or playerState.isEscorting
		local targetState = Player(target)?.state

		if targetState then
			if playerState.isCarrying then
				playerState.isCarrying = false
				targetState.isCarried = false
			end

			if playerState.isEscorting then
				playerState.isEscorting = false
				targetState.isEscorted = false
			end
		end
	end

	TriggerClientEvent('qbx_ambulancejob:client:putPlayerInBed', playerId, hospitalName, bedIndex)
end)

lib.callback.register('qbx_ambulancejob:server:isBedTaken', function(_, hospitalName, bedIndex)
	return hospitalBedsTaken[hospitalName][bedIndex]
end)

local function sendDoctorAlert()
	if doctorCalled then return end
	doctorCalled = true
	local _, doctors = exports.qbx_core:GetDutyCountType('ems')
	for i = 1, #doctors do
		local doctor = doctors[i]
		exports.qbx_core:Notify(doctor, locale('info.dr_needed'), 'inform')
	end

	SetTimeout(config.doctorCallCooldown * 60000, function()
		doctorCalled = false
	end)
end

local function canCheckIn(source, hospitalName)
	local numDoctors = exports.qbx_core:GetDutyCountType('ems')
	if numDoctors >= sharedConfig.minForCheckIn then
		exports.qbx_core:Notify(source, locale('info.dr_alert'), 'inform')
		sendDoctorAlert()
		return false
	end

	if not triggerEventHooks('checkIn', { source = source, hospitalName = hospitalName }) then return false end

	return true
end

lib.callback.register('qbx_ambulancejob:server:canCheckIn', canCheckIn)

---Sends the patient to an open bed within the hospital
---@param src number the player doing the checking in
---@param patientSrc number the player being checked in
---@param hospitalName string name of the hospital matching the config where player should be placed
---@return boolean
local function checkIn(src, patientSrc, hospitalName)
	if not canCheckIn(patientSrc, hospitalName) then return false end

	local bedIndex = getOpenBed(hospitalName)
	if not bedIndex then
		exports.qbx_core:Notify(src, locale('error.beds_taken'), 'error')
		return false
	end

	local playerState = Player(src).state
	if playerState.isCarrying or playerState.isEscorting then
		local target = playerState.isCarrying or playerState.isEscorting
		local targetState = Player(target)?.state

		if targetState then
			if playerState.isCarrying then
				playerState.isCarrying = false
				targetState.isCarried = false
			end

			if playerState.isEscorting then
				playerState.isEscorting = false
				targetState.isEscorted = false
			end
		end
	end

	TriggerClientEvent('qbx_ambulancejob:client:checkedIn', patientSrc, hospitalName, bedIndex)

	return true
end

lib.callback.register('qbx_ambulancejob:server:checkIn', checkIn)

exports('CheckIn', checkIn)

local function respawn(src)
	local closestHospital
	if Player(src)?.state.jailTime then
		closestHospital = 'jail'
	else
		local coords = GetEntityCoords(GetPlayerPed(src))
		local closest = nil

		for hospitalName, hospital in pairs(sharedConfig.locations.hospitals) do
			if hospitalName ~= 'jail' then
				if not closest or #(coords - hospital.coords) < #(coords - closest) then
					closest = hospital.coords
					closestHospital = hospitalName
				end
			end
		end
	end

	local bedIndex = getOpenBed(closestHospital)
	if not bedIndex then
		exports.qbx_core:Notify(src, locale('error.beds_taken'), 'error')
		return
	end
	TriggerClientEvent('qbx_ambulancejob:client:checkedIn', src, closestHospital, bedIndex)
end

AddEventHandler('qbx_medical:server:playerRespawned', respawn)