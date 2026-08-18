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
		name = "IceBreakSystem",
		evaluate = function(view, emit)
			local voyage = assert(view:get(ROOT_ENTITY, C.Voyage), "Ice Break System needs Voyage")
			local vesselRow = assert(view:query(C.Vessel)[1], "Ice Break System needs one Vessel")
			local vesselEntity = vesselRow[1]
			local vessel = vesselRow[2]

			for _, observationRow in ipairs(view:query(C.Observation)) do
				local observation = observationRow[2]
				local payload = observation.payload
				if observation.kind == "FishingCommand"
					and payload.action == "Move"
					and (voyage.mode == "Searching" or voyage.mode == "ReadyToReturn" or voyage.mode == "Returning")
					and WorldRule.isValidStep(payload.dx, payload.dz)
				then
					local cellEntity = findCell(view, C, vessel.x + payload.dx, vessel.z + payload.dz)
					local ice = if cellEntity ~= nil then view:get(cellEntity, C.Ice) else nil
					if cellEntity ~= nil and ice ~= nil then
						local hasFuel = vessel.fuel > 0
						local effects = {
							Contribution.insert(ROOT_ENTITY, {
								voyage:patch({
									message = if hasFuel
										then "船首撞碎浮冰，形成了新的航道。燃料 -1。"
										else "燃料耗尽，无法继续破冰。请沿已有航道返港。",
								}),
							}),
						}
						if hasFuel then
							table.insert(effects, Contribution.remove(cellEntity, { C.Ice }))
							table.insert(effects, Contribution.insert(vesselEntity, {
								vessel:patch({ fuel = vessel.fuel - 1 }),
							}))
						end
						emit(Contribution.transaction("IceBreakSystem", {
							orderKey = string.format("%016d", observation.sequence),
							label = if hasFuel then "BreakIce" else "RejectIceBreak",
							claims = { "ice:" .. tostring(cellEntity), "vessel", "voyage" },
							effects = effects,
						}))
					end
				end
			end
		end,
	}
end
