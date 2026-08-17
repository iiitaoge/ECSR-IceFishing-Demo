--!strict

local WorldRule = {}

local MIN_X = -3
local MAX_X = 3
local MIN_Z = 0
local MAX_Z = 6

local FISHING_GROUNDS = table.freeze({
	["-2:4"] = true,
	["0:5"] = true,
	["2:4"] = true,
	["-1:6"] = true,
	["2:6"] = true,
})

local function key(x: number, z: number): string
	return tostring(x) .. ":" .. tostring(z)
end

local cells = {}
for z = MIN_Z, MAX_Z do
	for x = MIN_X, MAX_X do
		table.insert(cells, table.freeze({
			x = x,
			z = z,
			isPort = x == 0 and z == 0,
			isFishingGround = FISHING_GROUNDS[key(x, z)] == true,
		}))
	end
end
table.freeze(cells)

function WorldRule.key(x: number, z: number): string
	return key(x, z)
end

function WorldRule.cells()
	return cells
end

function WorldRule.isInside(x: number, z: number): boolean
	return x >= MIN_X and x <= MAX_X and z >= MIN_Z and z <= MAX_Z
end

function WorldRule.isPort(x: number, z: number): boolean
	return x == 0 and z == 0
end

function WorldRule.isValidStep(dx, dz): boolean
	return type(dx) == "number"
		and type(dz) == "number"
		and dx == math.floor(dx)
		and dz == math.floor(dz)
		and math.abs(dx) + math.abs(dz) == 1
end

function WorldRule.shouldFreeze(x: number, z: number, round: number, targetX: number, targetZ: number): boolean
	if WorldRule.isPort(x, z) or (x == targetX and z == targetZ) then
		return false
	end
	local signature = math.abs(x * 17 + z * 11 + round * 7)
	return signature % 4 ~= 0
end

function WorldRule.signalKeys(targetX: number, targetZ: number)
	local result = {}
	local count = 0
	for _, offset in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 } }) do
		local x = targetX + offset[1]
		local z = targetZ + offset[2]
		if WorldRule.isInside(x, z) and not WorldRule.isPort(x, z) then
			result[key(x, z)] = true
			count += 1
		end
		if count >= 2 then
			break
		end
	end
	return result
end

function WorldRule.direction(fromX: number, fromZ: number, toX: number, toZ: number): string
	local horizontal = if toX < fromX then "西" elseif toX > fromX then "东" else ""
	local vertical = if toZ < fromZ then "南" elseif toZ > fromZ then "北" else ""
	local direction = vertical .. horizontal
	return if direction == "" then "脚下" else direction
end

function WorldRule.distance(fromX: number, fromZ: number, toX: number, toZ: number): number
	return math.abs(toX - fromX) + math.abs(toZ - fromZ)
end

return table.freeze(WorldRule)
