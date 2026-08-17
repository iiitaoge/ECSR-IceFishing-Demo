--!strict

local ROOT_ENTITY = 1

local function findCell(view, C, x: number, z: number)
	for _, row in ipairs(view:query(C.SeaCell)) do
		local cell = row[2]
		if cell.x == x and cell.z == z then
			return row[1], cell
		end
	end
	return nil, nil
end

return function(C, Contribution, WorldRule)
	return {
		name = "VesselNavigationSystem",
		evaluate = function(view, emit)
			local voyage = assert(view:get(ROOT_ENTITY, C.Voyage), "Navigation System needs Voyage")
			local vesselRow = assert(view:query(C.Vessel)[1], "Navigation System needs one Vessel")
			local vesselEntity = vesselRow[1]
			local vessel = vesselRow[2]

			for _, observationRow in ipairs(view:query(C.Observation)) do
				local observation = observationRow[2]
				local payload = observation.payload
				if observation.kind == "FishingCommand" and payload.action == "Move" then
					local message = nil
					local nextX = vessel.x
					local nextZ = vessel.z
					local canMove = voyage.mode == "Searching" or voyage.mode == "Returning"

					if not canMove then
						message = "当前阶段不能操船。"
					elseif not WorldRule.isValidStep(payload.dx, payload.dz) then
						message = "航行指令必须是一个相邻海格。"
					else
						nextX = vessel.x + payload.dx
						nextZ = vessel.z + payload.dz
						local targetEntity = findCell(view, C, nextX, nextZ)
						if targetEntity == nil then
							message = "前方已经是海图边界。"
						elseif view:get(targetEntity, C.Ice) ~= nil then
							message = "前方浮冰仍未破开。"
						else
							local signal = view:get(targetEntity, C.Signal)
							message = if signal ~= nil
								then "海鸟叫声变密了，鱼群就在附近。"
								else "船沿开放水道继续前进。"
						end
					end

					local effects = {
						Contribution.insert(ROOT_ENTITY, {
							voyage:patch({ message = message }),
						}),
					}
					if canMove
						and WorldRule.isValidStep(payload.dx, payload.dz)
						and (nextX ~= vessel.x or nextZ ~= vessel.z)
					then
						local targetEntity = findCell(view, C, nextX, nextZ)
						if targetEntity ~= nil and view:get(targetEntity, C.Ice) == nil then
							table.insert(effects, Contribution.insert(vesselEntity, {
								vessel:patch({
									x = nextX,
									z = nextZ,
									headingX = payload.dx,
									headingZ = payload.dz,
								}),
							}))
						end
					end

					emit(Contribution.transaction("VesselNavigationSystem", {
						orderKey = string.format("%016d", observation.sequence),
						label = "ResolveVesselMove",
						claims = { "vessel", "voyage" },
						effects = effects,
					}))
				end
			end
		end,
	}
end
