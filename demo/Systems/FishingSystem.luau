--!strict

local ROOT_ENTITY = 1

return function(C, Contribution, RandomRule, CatalogRule)
	return {
		name = "NetFishingSystem",
		evaluate = function(view, emit)
			local voyage, hold, rngState = view:get(ROOT_ENTITY, C.Voyage, C.Hold, C.RngState)
			voyage = assert(voyage, "Fishing System needs Voyage")
			hold = assert(hold, "Fishing System needs Hold")
			rngState = assert(rngState, "Fishing System needs RngState")
			local vesselRow = assert(view:query(C.Vessel)[1], "Fishing System needs one Vessel")
			local vessel = vesselRow[2]

			for _, observationRow in ipairs(view:query(C.Observation)) do
				local observation = observationRow[2]
				if observation.kind == "FishingCommand" and observation.payload.action == "Net" then
					local schoolEntity = nil
					local school = nil
					for _, row in ipairs(view:query(C.SeaCell, C.FishSchool)) do
						local cell = row[2]
						if cell.x == vessel.x and cell.z == vessel.z then
							schoolEntity = row[1]
							school = row[3]
							break
						end
					end

					local capacity = vessel.capacity - #hold.fishIds
					local catchCount = if school ~= nil then math.min(3, school.stock, capacity) else 0
					if voyage.mode ~= "AtSchool" or schoolEntity == nil or catchCount <= 0 then
						emit(Contribution.transaction("NetFishingSystem", {
							orderKey = string.format("%016d", observation.sequence),
							label = "RejectNet",
							claims = { "voyage" },
							effects = {
								Contribution.insert(ROOT_ENTITY, {
									voyage:patch({ message = "必须先抵达仍有鱼的鱼群，并确保渔舱有空间。" }),
								}),
							},
						}))
						continue
					end

					local effects = {}
					local nextSeed = rngState.seed
					local rareCount = 0
					for index = 1, catchCount do
						local fish
						nextSeed, fish = CatalogRule.roll(RandomRule, nextSeed)
						if CatalogRule.isCollectible(fish.rarity) then
							rareCount += 1
						end
						local token = string.format("catch:%d:%d", observation.sequence, index)
						table.insert(effects, Contribution.spawn({
							C.FishCatch({
								species = fish.species,
								displayName = fish.displayName,
								rarity = fish.rarity,
								value = fish.value,
								round = voyage.round,
							}),
						}, token))
						table.insert(effects, Contribution.collectionAdd(ROOT_ENTITY, C.Hold, "fishIds", nil, token))
					end

					table.insert(effects, Contribution.insert(schoolEntity, {
						school:patch({ stock = school.stock - catchCount }),
					}))
					table.insert(effects, Contribution.insert(ROOT_ENTITY, {
						rngState:patch({ seed = nextSeed }),
						voyage:patch({
							mode = "ReadyToReturn",
							message = string.format("收网成功：%d 条鱼，其中 %d 条稀有。现在返港处理渔获。", catchCount, rareCount),
						}),
					}))

					emit(Contribution.transaction("NetFishingSystem", {
						orderKey = string.format("%016d", observation.sequence),
						label = "ResolveNetCatch",
						claims = { "school:" .. tostring(schoolEntity), "hold", "rng", "voyage" },
						effects = effects,
					}))
				end
			end
		end,
	}
end
