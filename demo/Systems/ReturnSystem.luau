--!strict

local ROOT_ENTITY = 1

return function(C, Contribution)
	return {
		name = "ReturnIntentSystem",
		evaluate = function(view, emit)
			local voyage = assert(view:get(ROOT_ENTITY, C.Voyage), "Return Intent System needs Voyage")
			for _, observationRow in ipairs(view:query(C.Observation)) do
				local observation = observationRow[2]
				if observation.kind == "FishingCommand" and observation.payload.action == "Return" then
					local canReturn = voyage.mode == "ReadyToReturn"
					emit(Contribution.transaction("ReturnIntentSystem", {
						orderKey = string.format("%016d", observation.sequence),
						label = if canReturn then "BeginReturn" else "RejectReturn",
						claims = { "voyage" },
						effects = {
							Contribution.insert(ROOT_ENTITY, {
								voyage:patch({
									mode = if canReturn then "Returning" else voyage.mode,
									message = if canReturn
										then "渔舱已封好。沿破开的航道返回南侧港口。"
										else "下网完成后才能返港。",
								}),
							}),
						},
					}))
				end
			end
		end,
	}
end
