--!strict

local ROOT_ENTITY = 1

return function(C, Contribution, WorldRule)
	return {
		name = "VoyageArrivalSystem",
		evaluate = function(view, emit)
			local voyage = assert(view:get(ROOT_ENTITY, C.Voyage), "Arrival System needs Voyage")
			local vesselRow = assert(view:query(C.Vessel)[1], "Arrival System needs one Vessel")
			local vessel = vesselRow[2]

			if voyage.mode == "Searching" then
				for _, row in ipairs(view:query(C.SeaCell, C.FishSchool)) do
					local cell = row[2]
					local school = row[3]
					if cell.x == vessel.x and cell.z == vessel.z and school.stock > 0 then
						emit(Contribution.transaction("VoyageArrivalSystem", {
							label = "ArriveAtFishSchool",
							claims = { "voyage" },
							effects = {
								Contribution.insert(ROOT_ENTITY, {
									voyage:patch({
										mode = "AtSchool",
										revealed = true,
										message = "鱼群就在船下！现在可以下网捕捞。",
									}),
								}),
							},
						}))
						return
					end
				end
			elseif voyage.mode == "Returning" and WorldRule.isPort(vessel.x, vessel.z) then
				emit(Contribution.transaction("VoyageArrivalSystem", {
					label = "ArriveAtPort",
					claims = { "voyage" },
					effects = {
						Contribution.insert(ROOT_ENTITY, {
							voyage:patch({
								mode = "DockedWithCatch",
								message = "已安全返港。出售全部渔获，或收藏稀有鱼并自动卖出普通鱼。",
							}),
						}),
					},
				}))
			end
		end,
	}
end
