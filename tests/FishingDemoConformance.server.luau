--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)
local ECSR = ReplicatedStorage.ECSR
local GameRule = require(ReplicatedStorage.FishingDemo.Rules.GameRule)
local CargoUpgradeRule = require(ReplicatedStorage.FishingDemo.Rules.CargoUpgradeRule)

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

local function hold()
	return assert(evolution:view():get(rootEntity, C.Hold), "Hold is missing")
end

local function economy()
	return assert(evolution:view():get(rootEntity, C.Economy), "Economy is missing")
end

local function schools()
	return evolution:view():query(C.SeaCell, C.FishSchool)
end

local function navigateTo(x: number, z: number)
	local moveCount = 0
	local _, current = vessel()
	while current.x ~= x do
		command("Move", if x > current.x then 1 else -1, 0)
		moveCount += 1
		assert(moveCount < 64, "horizontal navigation did not converge")
		_, current = vessel()
	end
	while current.z ~= z do
		command("Move", 0, if z > current.z then 1 else -1)
		moveCount += 1
		assert(moveCount < 64, "vertical navigation did not converge")
		_, current = vessel()
	end
end

command("Sail")
assert(voyage().mode == "Searching" and voyage().round == 1, "Sail did not start the first multi-school voyage")
local _, startingVessel = vessel()
assert(startingVessel.x == 0 and startingVessel.z == 0, "Sail did not reset the Vessel at port")
assert(startingVessel.capacity == CargoUpgradeRule.initialCapacity(), "fresh vessel capacity must be 7")
local initialSchoolCount = #schools()
assert(initialSchoolCount >= 7, "a new voyage must generate multiple fish schools")
for _, row in ipairs(schools()) do
	assert(row[3].discovered == false, "new fish schools must start undiscovered")
end

command("Collect")
assert(#hold().fishIds == 0, "E must not collect a fish school from far away")
assert(string.find(voyage().message, "太远") ~= nil, "far-away collection should explain the discovery range")

local firstRow = assert(schools()[1], "first fish school is missing")
local firstCell = firstRow[2]
navigateTo(firstCell.x, firstCell.z)
local firstSchool = assert(evolution:view():get(firstRow[1], C.FishSchool), "first school disappeared before collection")
assert(firstSchool.discovered == true, "entering a school discovery range must reveal it")
command("Collect")
assert(#hold().fishIds == 1, "one E action must occupy exactly one cargo slot")
assert(evolution:view():get(firstRow[1], C.FishSchool) == nil, "collected fish school must disappear from the scene")

while #schools() > 0 do
	local row = assert(schools()[1], "remaining fish school row is missing")
	local cell = row[2]
	navigateTo(cell.x, cell.z)
	local before = #hold().fishIds
	local school = assert(evolution:view():get(row[1], C.FishSchool), "remaining school disappeared")
	assert(school.discovered == true, "nearby school was not discovered")
	command("Collect")
	assert(#hold().fishIds == before + 1, "collecting a school must add one cargo item")
end

local fullHold = hold()
local _, fullVessel = vessel()
assert(#fullHold.fishIds == fullVessel.capacity, "all seven schools should fill the initial cargo")
assert(voyage().mode == "ReadyToReturn", "full cargo must switch to return guidance")
command("Collect")
assert(#hold().fishIds == fullVessel.capacity, "a full cargo cannot collect another school")
assert(string.find(voyage().message, "已满") ~= nil, "full cargo should prompt the player to return")

command("Return")
assert(voyage().mode == "Returning", "return command must start from a loaded exploration")
navigateTo(0, 0)
assert(voyage().mode == "DockedWithCatch", "returning to the port must open cargo settlement")

local coinsBeforeSale = economy().coins
command("SellAll")
assert(voyage().mode == "Docked", "selling cargo should close the voyage")
assert(#hold().fishIds == 0, "selling cargo must clear the Hold")
assert(economy().coins > coinsBeforeSale, "selling fish schools must create coins")

local cargoUpgrade = assert(evolution:view():get(rootEntity, C.CargoUpgrade), "CargoUpgrade is missing")
local firstUpgradeCost = assert(CargoUpgradeRule.costForNextLevel(cargoUpgrade.cargoLevel), "cargo upgrade cost is missing")
local coinsBeforeUpgrade = economy().coins
assert(coinsBeforeUpgrade >= firstUpgradeCost, "the first full cargo run must fund a cargo upgrade")
command("UpgradeCargo")
local upgradedCargo = assert(evolution:view():get(rootEntity, C.CargoUpgrade), "CargoUpgrade disappeared")
local _, upgradedVessel = vessel()
assert(upgradedCargo.cargoLevel == 1, "cargo upgrade did not raise the cargo level")
assert(upgradedVessel.capacity == CargoUpgradeRule.capacityForLevel(1), "cargo upgrade did not update vessel capacity")
assert(economy().coins == coinsBeforeUpgrade - firstUpgradeCost, "cargo upgrade spent the exact cost")

command("Sail")
assert(voyage().round == 2 and voyage().mode == "Searching", "second voyage did not start")
assert(#schools() == initialSchoolCount, "the next voyage must regenerate multiple fish schools")
for _, row in ipairs(schools()) do
	assert(row[3].discovered == false, "new voyage must reset school discovery")
end

local _, vesselBeforeSeaUpgrade = vessel()
local capacityBeforeSeaUpgrade = vesselBeforeSeaUpgrade.capacity
command("UpgradeCargo")
local _, vesselAfterSeaUpgrade = vessel()
assert(vesselAfterSeaUpgrade.capacity == capacityBeforeSeaUpgrade, "capacity changed outside the port")
assert(string.find(voyage().message, "港口") ~= nil, "sea upgrade rejection should mention the port")

local trace = assert(evolution:view():get(rootEntity, C.EvolutionTrace), "EvolutionTrace is missing")
local latestTrace = trace.entries[#trace.entries]
assert(latestTrace.phases[2].phase == "ice", "ice phase ordering changed")
assert(latestTrace.phases[3].phase == "navigation", "navigation must follow ice breaking")
assert(latestTrace.phases[4].phase == "arrival", "arrival must follow navigation")
assert(latestTrace.phases[5].phase == "discovery", "discovery must follow arrival")

print("[ECSRFishingDemo] PASS")
