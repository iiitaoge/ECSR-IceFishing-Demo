--!strict

local ROOT_ENTITY = 1

local function nearestAvailableSchool(view, C, vessel, WorldRule)
	local targetEntity = nil
	local targetSchool = nil
	local targetDistance = nil
	for _, row in ipairs(view:query(C.SeaCell, C.FishSchool)) do
		local cell = row[2]
		local school = row[3]
		if school.discovered and school.stock > 0 then
			local distance = WorldRule.distance(vessel.x, vessel.z, cell.x, cell.z)
			if distance <= WorldRule.interactionRange()
				and (targetDistance == nil or distance < targetDistance)
			then
				targetEntity = row[1]
				targetSchool = school
				targetDistance = distance
			end
		end
	end
	return targetEntity, targetSchool
end

return function(C, Contribution, WorldRule)
	return {
		name = "FishSchoolCollectionSystem",
		evaluate = function(view, emit)
			local voyage, hold = view:get(ROOT_ENTITY, C.Voyage, C.Hold)
			voyage = assert(voyage, "Fish School Collection System needs Voyage")
			hold = assert(hold, "Fish School Collection System needs Hold")
			local vesselRow = assert(view:query(C.Vessel)[1], "Fish School Collection System needs one Vessel")
			local vesselEntity = vesselRow[1]
			local vessel = vesselRow[2]

			for _, observationRow in ipairs(view:query(C.Observation)) do
				local observation = observationRow[2]
				if observation.kind == "FishingCommand" and observation.payload.action == "Collect" then
					local targetEntity, school = nearestAvailableSchool(view, C, vessel, WorldRule)
					local hasRoom = #hold.fishIds < vessel.capacity
					local canCollect = voyage.mode == "Searching" and targetEntity ~= nil and school ~= nil and hasRoom
					if not canCollect then
						local message
						if not hasRoom then
							message = string.format("货舱已满（%d/%d），无法获取新的鱼群，请回港出售。", #hold.fishIds, vessel.capacity)
						elseif voyage.mode ~= "Searching" then
							message = "当前阶段不能获取鱼群。"
						elseif targetEntity == nil then
							message = "距离鱼群太远，进入发现范围后才能按 E 获取。"
						else
							message = "这个鱼群暂时无法获取。"
						end
						emit(Contribution.transaction("FishSchoolCollectionSystem", {
							orderKey = string.format("%016d", observation.sequence),
							label = "RejectFishSchoolCollection",
							claims = { "voyage", "hold" },
							effects = {
								Contribution.insert(ROOT_ENTITY, {
									voyage:patch({
										mode = if not hasRoom and voyage.mode == "Searching" then "ReadyToReturn" else voyage.mode,
										message = message,
									}),
								}),
							},
						}))
						continue
					end

					local token = string.format("catch:%d", observation.sequence)
					local effects = {
						Contribution.spawn({
							C.FishCatch({
								species = school.species,
								displayName = school.displayName,
								rarity = school.rarity,
								value = school.value,
								round = voyage.round,
							}),
						}, token),
						Contribution.collectionAdd(ROOT_ENTITY, C.Hold, "fishIds", nil, token),
						Contribution.remove(targetEntity, { C.FishSchool }),
					}

					local nextHoldCount = #hold.fishIds + 1
					local remainingSchools = 0
					for _, row in ipairs(view:query(C.FishSchool)) do
						if row[1] ~= targetEntity and row[2].stock > 0 then
							remainingSchools += 1
						end
					end
					local shouldReturn = nextHoldCount >= vessel.capacity or remainingSchools == 0
					local message = if nextHoldCount >= vessel.capacity
						then string.format("鱼群已装舱，货舱已满（%d/%d）。请回港出售。", nextHoldCount, vessel.capacity)
						elseif remainingSchools == 0
						then string.format("已获取 %s，航区暂无其他鱼群。请回港出售。", school.displayName)
						else string.format("已获取 %s，价值 %d 金币。雷达正在寻找下一个鱼群。", school.displayName, school.value)

					table.insert(effects, Contribution.insert(ROOT_ENTITY, {
						voyage:patch({ mode = if shouldReturn then "ReadyToReturn" else "Searching", message = message }),
					}))

					emit(Contribution.transaction("FishSchoolCollectionSystem", {
						orderKey = string.format("%016d", observation.sequence),
						label = "CollectFishSchool",
						claims = { "voyage", "hold", "school:" .. tostring(targetEntity) },
						effects = effects,
					}))
				end
			end
		end,
	}
end
