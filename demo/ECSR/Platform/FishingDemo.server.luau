--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The player operates the vessel through UI/keyboard commands. A Roblox
-- character would only duplicate the visual subject and obstruct the scene.
Players.CharacterAutoLoads = false

local function suppressCharacter(player: Player)
	if player.Character ~= nil then
		player.Character:Destroy()
	end
	player.CharacterAdded:Connect(function(character)
		character:Destroy()
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	suppressCharacter(player)
end

local Matter = require(ReplicatedStorage.Packages.Matter)
local ECSR = ReplicatedStorage.ECSR
local FishingDemo = ReplicatedStorage.FishingDemo
local GameRule = require(FishingDemo.Rules.GameRule)
local WorldRule = require(FishingDemo.Rules.WorldRule)

local application = GameRule.new(Matter, ECSR)
local evolution = application.evolution
local C = application.components
local rootEntity = application.rootEntity

local function remote(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing ~= nil then
		assert(existing:IsA("RemoteEvent"), name .. " must be a RemoteEvent")
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = ReplicatedStorage
	return created
end

local commandEvent = remote("ECSRFishingCommand")
local stateEvent = remote("ECSRFishingState")

local function snapshot()
	local view = evolution:view()
	local voyage, economy, cargoUpgrade, hold, collection, stateRoot = view:get(
		rootEntity,
		C.Voyage,
		C.Economy,
		C.CargoUpgrade,
		C.Hold,
		C.Collection,
		C.StateRoot
	)
	assert(
		voyage ~= nil
			and economy ~= nil
			and cargoUpgrade ~= nil
			and hold ~= nil
			and collection ~= nil
			and stateRoot ~= nil
	)
	local vesselRow = assert(view:query(C.Vessel)[1], "Fishing Demo needs one Vessel")
	local vessel = vesselRow[2]

	local fishById = {}
	for _, row in ipairs(view:query(C.FishCatch)) do
		local fishId = row[1]
		local fish = row[2]
		fishById[fishId] = {
			id = fishId,
			species = fish.species,
			displayName = fish.displayName,
			rarity = fish.rarity,
			value = fish.value,
			round = fish.round,
			trophy = view:get(fishId, C.Trophy) ~= nil,
		}
	end

	local function fishList(ids)
		local result = {}
		for _, fishId in ipairs(ids) do
			local fish = fishById[fishId]
			if fish ~= nil then
				table.insert(result, fish)
			end
		end
		return result
	end

	local cells = {}
	local nearestHidden = nil
	local nearestHiddenDistance = nil
	local nearbySchool = nil
	local remainingSchools = 0
	for _, row in ipairs(view:query(C.SeaCell)) do
		local entityId = row[1]
		local cell = row[2]
		local ice, signal, school = view:get(entityId, C.Ice, C.Signal, C.FishSchool)
		local visibleSchool = school ~= nil and school.discovered
		local distance = WorldRule.distance(vessel.x, vessel.z, cell.x, cell.z)
		if school ~= nil then
			remainingSchools += 1
			if not school.discovered
				and (nearestHiddenDistance == nil or distance < nearestHiddenDistance)
			then
				nearestHidden = { x = cell.x, z = cell.z }
				nearestHiddenDistance = distance
			end
			if school.discovered
				and distance <= WorldRule.interactionRange()
				and (nearbySchool == nil or distance < nearbySchool.distance)
			then
				nearbySchool = {
					x = cell.x,
					z = cell.z,
					distance = distance,
					species = school.species,
					displayName = school.displayName,
					rarity = school.rarity,
					value = school.value,
				}
			end
		end
		table.insert(cells, {
			x = cell.x,
			z = cell.z,
			isPort = cell.isPort,
			ice = if ice ~= nil then ice.hardness else nil,
			signal = if signal ~= nil then signal.kind else nil,
			school = if visibleSchool
				then {
					stock = school.stock,
					tier = school.tier,
					species = school.species,
					displayName = school.displayName,
					rarity = school.rarity,
					value = school.value,
				}
				else nil,
		})
	end

	local radarTarget = nil
	local radarDistance = nil
	local radarIntensity = 0
	local radarDirection = nil
	if nearestHidden ~= nil then
		radarTarget = nearestHidden
		radarDistance = assert(nearestHiddenDistance)
		local bounds = WorldRule.bounds()
		local maxDistance = (bounds.maxX - bounds.minX) + (bounds.maxZ - bounds.minZ)
		radarIntensity = 1 - math.clamp(radarDistance / math.max(1, maxDistance), 0, 1)
		radarDirection = WorldRule.direction(vessel.x, vessel.z, nearestHidden.x, nearestHidden.z)
	end

	local bounds = WorldRule.bounds()
	return {
		tick = stateRoot.tick,
		mode = voyage.mode,
		round = voyage.round,
		revealed = voyage.revealed,
		message = voyage.message,
		coins = economy.coins,
		cargoUpgrade = {
			cargoLevel = cargoUpgrade.cargoLevel,
			maxCargoLevel = cargoUpgrade.maxCargoLevel,
			nextCargoCost = cargoUpgrade.nextCargoCost,
		},
		vessel = {
			x = vessel.x,
			z = vessel.z,
			headingX = vessel.headingX,
			headingZ = vessel.headingZ,
			fuel = vessel.fuel,
			maxFuel = vessel.maxFuel,
			capacity = vessel.capacity,
		},
		hold = fishList(hold.fishIds),
		collection = fishList(collection.fishIds),
		cells = cells,
		bounds = bounds,
		schoolsRemaining = remainingSchools,
		target = radarTarget,
		radar = {
			target = radarTarget,
			distance = radarDistance,
			intensity = radarIntensity,
			direction = radarDirection,
			remaining = remainingSchools,
		},
		nearbySchool = nearbySchool,
	}
end

local function broadcast()
	stateEvent:FireAllClients(snapshot())
end

commandEvent.OnServerEvent:Connect(function(player, action, payload)
	if action == "Sync" then
		stateEvent:FireClient(player, snapshot())
		return
	end
	if type(action) ~= "string" then
		return
	end

	local command = { action = action }
	if type(payload) == "table" then
		command.dx = payload.dx
		command.dz = payload.dz
	end

	local ok, failure = xpcall(function()
		evolution:observe("FishingCommand", command)
		evolution:step()
	end, debug.traceback)
	if not ok then
		warn("[ECSRFishingDemo] command failed\n" .. tostring(failure))
	end
	broadcast()
end)

Players.PlayerAdded:Connect(function(player)
	suppressCharacter(player)
	task.defer(function()
		if player.Parent ~= nil then
			stateEvent:FireClient(player, snapshot())
		end
	end)
end)

print("[ECSRFishingDemo] server ready")
