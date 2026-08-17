--!strict

local ROOT_ENTITY = 1

return function(C, Contribution, WorldRule)
	return {
		name = "FishScanSystem",
		evaluate = function(view, emit)
			local voyage = assert(view:get(ROOT_ENTITY, C.Voyage), "Fish Scan System needs Voyage")
			local vesselRow = assert(view:query(C.Vessel)[1], "Fish Scan System needs one Vessel")
			local vessel = vesselRow[2]

			for _, observationRow in ipairs(view:query(C.Observation)) do
				local observation = observationRow[2]
				if observation.kind == "FishingCommand" and observation.payload.action == "Scan" then
					local message = "只有出航寻找鱼群时才能使用声呐。"
					local revealed = voyage.revealed
					if voyage.mode == "Searching" then
						local schoolRow = view:query(C.SeaCell, C.FishSchool)[1]
						if schoolRow ~= nil then
							local cell = schoolRow[2]
							message = string.format(
								"声呐锁定：鱼群在%s，距离 %d 格。规划一条省燃料的破冰路线。",
								WorldRule.direction(vessel.x, vessel.z, cell.x, cell.z),
								WorldRule.distance(vessel.x, vessel.z, cell.x, cell.z)
							)
							revealed = true
						end
					end

					emit(Contribution.transaction("FishScanSystem", {
						orderKey = string.format("%016d", observation.sequence),
						label = "ResolveFishScan",
						claims = { "voyage" },
						effects = {
							Contribution.insert(ROOT_ENTITY, {
								voyage:patch({ revealed = revealed, message = message }),
							}),
						},
					}))
				end
			end
		end,
	}
end
