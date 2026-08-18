--!strict

local ROOT_ENTITY = 1

return function(C, Contribution, WorldRule)
	return {
		name = "VoyageArrivalSystem",
			evaluate = function(view, emit)
				local voyage, hold = view:get(ROOT_ENTITY, C.Voyage, C.Hold)
				voyage = assert(voyage, "Arrival System needs Voyage")
				hold = assert(hold, "Arrival System needs Hold")
			local vesselRow = assert(view:query(C.Vessel)[1], "Arrival System needs one Vessel")
			local vessel = vesselRow[2]

			if voyage.mode == "Returning" and WorldRule.isPort(vessel.x, vessel.z) then
				emit(Contribution.transaction("VoyageArrivalSystem", {
					label = "ArriveAtPort",
					claims = { "voyage" },
					effects = {
						Contribution.insert(ROOT_ENTITY, {
							voyage:patch({
								mode = if #hold.fishIds > 0 then "DockedWithCatch" else "Docked",
								message = if #hold.fishIds > 0
									then "已安全返港。出售货舱内的鱼群，或收藏稀有鱼。"
									else "已安全返港。",
							}),
						}),
					},
				}))
			end
		end,
	}
end
