--!strict

local ROOT_ENTITY = 1

return function(C, Contribution)
	return {
		name = "ReturnIntentSystem",
		evaluate = function(view, emit)
			local voyage, hold = view:get(ROOT_ENTITY, C.Voyage, C.Hold)
			voyage = assert(voyage, "Return Intent System needs Voyage")
			hold = assert(hold, "Return Intent System needs Hold")
			for _, observationRow in ipairs(view:query(C.Observation)) do
				local observation = observationRow[2]
				if observation.kind == "FishingCommand" and observation.payload.action == "Return" then
					local canReturn = (voyage.mode == "Searching" or voyage.mode == "ReadyToReturn") and #hold.fishIds > 0
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
										else "至少获取一个鱼群后才能返港。",
								}),
							}),
						},
					}))
				end
			end
		end,
	}
end
