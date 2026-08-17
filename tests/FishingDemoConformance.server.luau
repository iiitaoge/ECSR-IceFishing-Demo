--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)
local ECSR = ReplicatedStorage.ECSR
local GameRule = require(ReplicatedStorage.FishingDemo.Rules.GameRule)
local startPresentation = require(ReplicatedStorage.FishingDemo.Presentation)

assert(type(startPresentation) == "function", "Fishing presentation must compile as an inert platform adapter")

local application = GameRule.new(Matter, ECSR)
local evolution = application.evolution
local C = application.components
local rootEntity = application.rootEntity

local function command(action: string, dx: number?, dz: number?)
	evolution:observe("FishingCommand", { action = action, dx = dx, dz = dz })
	evolution:step()
	assert(#evolution:view():query(C.Observation) == 0, "every command Observation must be consumed")
end

local function voyage()
	return assert(evolution:view():get(rootEntity, C.Voyage), "Voyage is missing")
end

local function vessel()
	local row = assert(evolution:view():query(C.Vessel)[1], "Vessel is missing")
	return row[1], row[2]
end

local function schoolCell()
	local row = assert(evolution:view():query(C.SeaCell, C.FishSchool)[1], "FishSchool is missing")
	return row[1], row[2], row[3]
end

command("Sail")
assert(voyage().mode == "Searching" and voyage().round == 1, "Sail did not start the first voyage")
local _, startingVessel = vessel()
assert(startingVessel.x == 0 and startingVessel.z == 0, "Sail did not reset the Vessel at port")

command("Scan")
assert(voyage().revealed == true, "Scan did not reveal the fish school")
local _, targetCell = schoolCell()

local _, currentVessel = vessel()
local moveCount = 0
while currentVessel.x ~= targetCell.x do
	local dx = if targetCell.x > currentVessel.x then 1 else -1
	command("Move", dx, 0)
	moveCount += 1
	assert(moveCount < 32, "horizontal navigation did not converge")
	_, currentVessel = vessel()
end
while currentVessel.z ~= targetCell.z do
	local dz = if targetCell.z > currentVessel.z then 1 else -1
	command("Move", 0, dz)
	moveCount += 1
	assert(moveCount < 32, "vertical navigation did not converge")
	_, currentVessel = vessel()
end

assert(voyage().mode == "AtSchool", "arrival phase did not observe the post-navigation Vessel position")
assert(currentVessel.fuel < currentVessel.maxFuel, "route did not exercise the ice-break phase")
local trace = assert(evolution:view():get(rootEntity, C.EvolutionTrace), "EvolutionTrace is missing")
local latestTrace = trace.entries[#trace.entries]
assert(latestTrace.phases[2].phase == "ice", "ice phase ordering changed")
assert(latestTrace.phases[3].phase == "navigation", "navigation must follow ice breaking")
assert(latestTrace.phases[4].phase == "arrival", "arrival must follow navigation")

command("Net")
assert(voyage().mode == "ReadyToReturn", "net fishing did not complete the harvest")
local hold = assert(evolution:view():get(rootEntity, C.Hold), "Hold is missing")
assert(#hold.fishIds == 3, "one net must create three explicit FishCatch entities")

local rareCount = 0
local commonRevenue = 0
for _, fishId in ipairs(hold.fishIds) do
	local fish = assert(evolution:view():get(fishId, C.FishCatch), "Hold references a missing FishCatch")
	if fish.rarity == "Rare" or fish.rarity == "Epic" then
		rareCount += 1
	else
		commonRevenue += fish.value
	end
end
assert(rareCount > 0, "the deterministic first catch must demonstrate rare-fish sorting")

command("Return")
assert(voyage().mode == "Returning", "return intent did not start the return voyage")
_, currentVessel = vessel()
moveCount = 0
while currentVessel.x ~= 0 do
	local dx = if currentVessel.x > 0 then -1 else 1
	command("Move", dx, 0)
	moveCount += 1
	assert(moveCount < 32, "return navigation did not converge horizontally")
	_, currentVessel = vessel()
end
while currentVessel.z ~= 0 do
	local dz = if currentVessel.z > 0 then -1 else 1
	command("Move", 0, dz)
	moveCount += 1
	assert(moveCount < 32, "return navigation did not converge vertically")
	_, currentVessel = vessel()
end
assert(voyage().mode == "DockedWithCatch", "port arrival did not open settlement")

command("KeepRare")
assert(voyage().mode == "Docked", "settlement did not close the voyage")
hold = assert(evolution:view():get(rootEntity, C.Hold), "Hold is missing after settlement")
local collection = assert(evolution:view():get(rootEntity, C.Collection), "Collection is missing")
local economy = assert(evolution:view():get(rootEntity, C.Economy), "Economy is missing")
assert(#hold.fishIds == 0, "settlement did not empty the Hold")
assert(#collection.fishIds == rareCount, "rare FishCatch entities were not moved to Collection")
assert(economy.coins == commonRevenue, "common-fish sale value was not materialized")
for _, fishId in ipairs(collection.fishIds) do
	assert(evolution:view():get(fishId, C.FishCatch) ~= nil, "collected fish lost its FishCatch state")
	assert(evolution:view():get(fishId, C.Trophy) ~= nil, "collected rare fish did not gain Trophy state")
end

command("Sail")
assert(voyage().round == 2 and voyage().mode == "Searching", "settled state cannot begin a second round")
assert(#evolution:view():get(rootEntity, C.Collection).fishIds == rareCount, "new round erased the persistent collection")

print("[ECSRFishingDemo] PASS")
