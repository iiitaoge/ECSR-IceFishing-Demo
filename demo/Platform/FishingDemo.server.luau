--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Matter = require(ReplicatedStorage.Packages.Matter)
local ECSR = ReplicatedStorage.ECSR
local FishingDemo = ReplicatedStorage.FishingDemo
local GameRule = require(FishingDemo.Rules.GameRule)

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
	local voyage, economy, hold, collection, stateRoot = view:get(
		rootEntity,
		C.Voyage,
		C.Economy,
		C.Hold,
		C.Collection,
		C.StateRoot
	)
	assert(voyage ~= nil and economy ~= nil and hold ~= nil and collection ~= nil and stateRoot ~= nil)
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
	local target = nil
	for _, row in ipairs(view:query(C.SeaCell)) do
		local entityId = row[1]
		local cell = row[2]
		local ice, signal, school = view:get(entityId, C.Ice, C.Signal, C.FishSchool)
		local visibleSchool = voyage.revealed and school ~= nil
		table.insert(cells, {
			x = cell.x,
			z = cell.z,
			isPort = cell.isPort,
			ice = ice ~= nil,
			signal = if signal ~= nil then signal.kind else nil,
			school = if visibleSchool then { stock = school.stock } else nil,
		})
		if visibleSchool then
			target = { x = cell.x, z = cell.z, stock = school.stock }
		end
	end

	return {
		tick = stateRoot.tick,
		mode = voyage.mode,
		round = voyage.round,
		revealed = voyage.revealed,
		message = voyage.message,
		coins = economy.coins,
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
		target = target,
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
	task.defer(function()
		if player.Parent ~= nil then
			stateEvent:FireClient(player, snapshot())
		end
	end)
end)

print("[ECSRFishingDemo] server ready")
