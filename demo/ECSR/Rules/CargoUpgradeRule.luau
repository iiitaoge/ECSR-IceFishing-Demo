--!strict

local CargoUpgradeRule = {}

local INITIAL_CAPACITY = 7
local CAPACITY_STEP = 3
local COSTS = table.freeze({ 45, 110, 220 })

function CargoUpgradeRule.initialCapacity(): number
	return INITIAL_CAPACITY
end

function CargoUpgradeRule.maxLevel(): number
	return #COSTS
end

function CargoUpgradeRule.capacityForLevel(level: number): number
	return INITIAL_CAPACITY + level * CAPACITY_STEP
end

function CargoUpgradeRule.costForNextLevel(level: number): number?
	return COSTS[level + 1]
end

return table.freeze(CargoUpgradeRule)
