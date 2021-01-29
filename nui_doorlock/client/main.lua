ESX = nil
closestDoor, closestV, closestDistance, closestA, playerPed, playerCoords, playerNotActive, doorCount = nil, nil, nil, false, nil, nil, true

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(10)
	end
	ESX.PlayerData = ESX.GetPlayerData()
	-- Update the door list
	ESX.TriggerServerCallback('esx_doorlock:getDoorInfo', function(doorInfo)
		for doorID,values in pairs(doorInfo) do
			Config.DoorList[doorID] = values
		end
	end)
	if ESX.PlayerData.lastPosition then ESX.PlayerData.coords = ESX.PlayerData.lastPosition end

	playerCoords = vector3(ESX.PlayerData.coords.x, ESX.PlayerData.coords.y, ESX.PlayerData.coords.z)
	lastCoords = playerCoords
	updateDoors()
	playerNotActive = nil

end)


-- Set state for a door
RegisterNetEvent('esx_doorlock:setState')
AddEventHandler('esx_doorlock:setState', function(doorID, values)
	Config.DoorList[doorID] = values
end)

local last_x, last_y, lasttext
function DrawTextNUI(coords, text)
	local paused = false
	if IsPauseMenuActive() then paused = true end
	local onScreen,_x,_y = GetScreenCoordFromWorldCoord(coords.x,coords.y,coords.z)
	if _x ~= last_x or _y ~= last_y or text ~= lasttext or paused then
		if paused then SendNUIMessage ({action = "hide"}) else SendNUIMessage({action = "display", x = _x, y = _y, text = text}) end
		last_x, last_y, lasttext = _x, _y, text
		Citizen.Wait(0)
	end
end

function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Citizen.Wait(5)
    end
end

function dooranim(entity, state)
	Citizen.CreateThread(function()
    loadAnimDict("anim@heists@keycard@") 
    TaskPlayAnim(playerPed, "anim@heists@keycard@", "exit", 8.0, 1.0, -1, 16, 0, 0, 0, 0)
    Citizen.Wait(550)
	ClearPedTasks(playerPed)
	end)
end

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

function round(num, decimal)
	local mult = 10^(decimal)
	return math.floor(num * mult + 0.5) / mult
end

function updateDoors()
	local count = 0
	Citizen.Wait(1000)
	for _,doorID in ipairs(Config.DoorList) do
		if doorID.doors then
			for k,v in ipairs(doorID.doors) do
				count = count + 1
				if #(vector2(playerCoords.x, playerCoords.y) - vector2(v.objCoords.x, v.objCoords.y)) < 100 then
					v.object = GetClosestObjectOfType(v.objCoords, 1.0, v.objHash, false, false, false)
					if doorID.delete then
						SetEntityAsMissionEntity(v.object, 1, 1)
						DeleteObject(v.object)
						v.object = nil
					end
					if v.object then
						v.doorHash = GetHashKey('dl'.._..k)
						AddDoorToSystem(v.doorHash, v.objHash, v.objCoords, false, false, false)
						DoorSystemSetDoorState(v.doorHash, 4, false, false)
					end
				elseif v.object then RemoveDoorFromSystem(v.doorHash) end
			end
		else
			count = count + 1
			if #(vector2(playerCoords.x, playerCoords.y) - vector2(doorID.objCoords.x, doorID.objCoords.y)) < 100 then
				if doorID.slides then doorID.object = GetClosestObjectOfType(doorID.objCoords, 5.0, doorID.objHash, false, false, false) else
					doorID.object = GetClosestObjectOfType(doorID.objCoords, 1.0, doorID.objHash, false, false, false)
				end
				if doorID.delete then
					SetEntityAsMissionEntity(doorID.object, 1, 1)
					DeleteObject(doorID.object)
					doorID.object = nil
				end
				if doorID.object then
					doorID.doorHash = GetHashKey('dl'.._)
					AddDoorToSystem(doorID.doorHash, doorID.objHash, doorID.objCoords, false, false, false)
					DoorSystemSetDoorState(doorID.doorHash, 4, false, false)
				end
			elseif doorID.object then RemoveDoorFromSystem(doorID.doorHash) end
		end

		-- set text coords
		if not doorID.setText and doorID.doors then
			for k,v in ipairs(doorID.doors) do
				if k == 1 and v.object then
					doorID.textCoords = v.objCoords
				elseif k == 2 and v.object and doorID.textCoords then
					local textDistance = doorID.textCoords - v.objCoords
					doorID.textCoords = (doorID.textCoords - (textDistance / 2))
					doorID.setText = true
				end
			end
		elseif not doorID.setText and not doorID.doors and doorID.object then
			if not doorID.garage then
				local minDimension, maxDimension = GetModelDimensions(doorID.objHash)
				if doorID.fixText then dimensions = minDimension - maxDimension else dimensions = maxDimension - minDimension end
				local dx, dy = tonumber(string.sub(dimensions.x, 1, 6)), tonumber(string.sub(dimensions.y, 1, 6))
				local h = tonumber(string.sub(doorID.objHeading, 1, 1))
				if h == 9 or h == 8 or h == 2 then dx, dy = dy, dx end
				local maths = vector3(dx/2, dy/2, 0)
				doorID.textCoords = GetEntityCoords(doorID.object) - maths
				doorID.setText = true
			else
				doorID.textCoords = GetEntityCoords(doorID.object)
				doorID.setText = true
			end
			if doorID.slides then
				DoorSystemSetAutomaticDistance(doorID.doorHash, 25.0, false, false)
				if GetEntityHeightAboveGround(doorID.object) < 1 then
					doorID.textCoords = vector3(doorID.textCoords.x, doorID.textCoords.y, doorID.textCoords.z+1.6)
				end
			end
		end
	end
	doorCount = DoorSystemGetSize()
	if doorCount ~= 0 then print(('%s of %s doors are loaded'):format(doorCount, count)) end
	--print(playerCoords)
end

Citizen.CreateThread(function()
	while playerNotActive do Citizen.Wait(100) end
	while true do
		local distance = #(vector2(playerCoords.x, playerCoords.y) - vector2(lastCoords.x, lastCoords.y))
		if distance > 50 then
			updateDoors()
			--print(distance)
			lastCoords = playerCoords
		end
		Citizen.Wait(500)
	end
end)

Citizen.CreateThread(function()
	while not playerCoords do Citizen.Wait(0) end
	while true do
		Citizen.Wait(0)
		local letSleep, sleepLen, distance = true, 1000, 0
		if doorCount then
			for k,v in ipairs(Config.DoorList) do
				local isAuthorized = IsAuthorized(v)
				if v.setText then distance = #(v.textCoords - playerCoords) end
				if v.setText and distance < 50 then
					sleepLen = 300

					if v.doors and distance < (v.maxDistance * 2) then
						for k2, v2 in ipairs(v.doors) do
							local doorState = DoorSystemGetDoorState(v2.doorHash)
							v2.objCurrentHeading = GetEntityHeading(v2.object)
							if v.locked and IsDoorClosed(v2.doorHash) then 
								DoorSystemSetDoorState(v2.doorHash, 1, false, false)
								letSleep = true
							elseif not v.locked then
								DoorSystemSetDoorState(v2.doorHash, 0, false, false)
								letSleep = false
							else
								if round(v2.objCurrentHeading, 0) == round(v2.objHeading, 0) then
									DoorSystemSetDoorState(v2.doorHash, 4, false, false)
									letSleep = true
								else
									letSleep = false
								end
							end
						end
					elseif not v.doors and not v.slides and distance < (v.maxDistance * 2) then
						local doorState = DoorSystemGetDoorState(v.doorHash)
						v.objCurrentHeading = GetEntityHeading(v.object)
						if v.locked and IsDoorClosed(v.doorHash) then 
							DoorSystemSetDoorState(v.doorHash, 1, false, false)
							letSleep = true
						elseif not v.locked then
							DoorSystemSetDoorState(v.doorHash, 0, false, false)
							letSleep = false
						else
							if round(v.objCurrentHeading, 0) == round(v.objHeading, 0) then
								DoorSystemSetDoorState(v.doorHash, 4, false, false)
								letSleep = true
							else
								letSleep = false
							end
						end
					elseif v.slides and distance < 20 then
						local doorState = DoorSystemGetDoorState(v.doorHash)
						v.objCurrentHeading = GetEntityHeading(v.object)
						if v.locked and doorState ~= 1 then 
							DoorSystemSetDoorState(v.doorHash, 1, false, false)
							letSleep = true
						elseif doorState ~= 0 and not v.locked then
							DoorSystemSetDoorState(v.doorHash, 0, false, false)
							sleepLen = 50
						else
							sleepLen = 100
							letSleep = true
						end
					end
				end
				if v.setText and distance < v.maxDistance then
					closestDoor, closestV, closestDistance, closestA = k, v, distance, isAuthorized
				end
			end
			if letSleep then
				Citizen.Wait(sleepLen)
			end
		else Citizen.Wait(1000) end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		playerPed = PlayerPedId()
		playerCoords = GetEntityCoords(playerPed)
		if doorCount ~= nil and doorCount ~= 0 and closestDistance then
			closestDistance = #(closestV.textCoords - playerCoords)
			if closestDistance < closestV.maxDistance and closestV.setText then
				if not closestV.doors then
					local doorState = DoorSystemGetDoorState(closestV.doorHash)
					if closestV.locked and doorState ~= 1 then
						DrawTextNUI(closestV.textCoords, 'Locking')
					elseif not closestV.locked then
						if Config.ShowUnlockedText then DrawTextNUI(closestV.textCoords, 'Unlocked') else DrawTextNUI(closestV.textCoords, nil) end
					else
						DrawTextNUI(closestV.textCoords, 'Locked')
					end
				else
					local door = {}
					for k2,v2 in ipairs(closestV.doors) do
						local doorState = DoorSystemGetDoorState(v2.doorHash)
						if doorState == 1 and closestV.locked then door[k2] = true else door[k2] = false end
					end
					if door[1] and door[1] == door[2] then DrawTextNUI(closestV.textCoords, 'Locked')
					elseif not closestV.locked and Config.ShowUnlockedText then DrawTextNUI(closestV.textCoords, 'Unlocked')
					else DrawTextNUI(closestV.textCoords, 'Locking') end
				end
				if closestA and IsControlJustReleased(0, 38) then
					if not IsPedInAnyVehicle(playerPed) then dooranim(closestV.object, closestV.locked) end
					closestV.locked = not closestV.locked
					TriggerServerEvent('esx_doorlock:updateState', closestDoor, closestV) -- Broadcast new state of the door to everyone
				end
			else
				if closestDistance > closestV.maxDistance then
					DrawTextNUI(closestV.textCoords, nil)
				end
				closestDoor, closestV, closestDistance, closestA = nil, nil, nil, false
			end
		else Citizen.Wait(100) end
	end
end)

function IsAuthorized(doorID)
	if ESX.PlayerData.job == nil then
		return false
	end

	for _,job in pairs(doorID.authorizedJobs) do
		if job == ESX.PlayerData.job.name then
			return true
		end
	end

	return false
end
