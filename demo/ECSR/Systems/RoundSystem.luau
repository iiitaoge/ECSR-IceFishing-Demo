--!strict

local ROOT_ENTITY = 1

local function orderKey(observation): string
	return string.format("%016d", observation.sequence)
end

return function(C, Contribution, RandomRule, WorldRule, CatalogRule)
	return {
		name = "FishingRoundSystem",
		evaluate = function(view, emit)
			local voyage, hold, rngState = view:get(
				ROOT_ENTITY,
				C.Voyage,
				C.Hold,
				C.RngState
			)
			voyage = assert(voyage, "Fishing Round System needs Voyage")
			hold = assert(hold, "Fishing Round System needs Hold")
			rngState = assert(rngState, "Fishing Round System needs RngState")
			local vesselRow = assert(view:query(C.Vessel)[1], "Fishing Round System needs one Vessel")
			local vesselEntity = vesselRow[1]
			local vessel = vesselRow[2]

			for _, observationRow in ipairs(view:query(C.Observation)) do
				local observation = observationRow[2]
				if observation.kind == "FishingCommand" and observation.payload.action == "Sail" then
					if voyage.mode ~= "Docked" or #hold.fishIds > 0 then
						emit(Contribution.transaction("FishingRoundSystem", {
							orderKey = orderKey(observation),
							label = "RejectSail",
							claims = { "voyage" },
							effects = {
								Contribution.insert(ROOT_ENTITY, {
									voyage:patch({ message = "先把本趟渔获出售，再开始新航次。" }),
								}),
							},
						}))
						continue
					end

					local grounds = {}
					for _, row in ipairs(view:query(C.SeaCell)) do
						local cell = row[2]
						if cell.isFishingGround then
							table.insert(grounds, row)
						end
					end
					assert(#grounds > 0, "Fishing Round Rule needs at least one accessible fishing ground")

					local nextSeed = rngState.seed
					local schoolsByEntity = {}
					for _, row in ipairs(grounds) do
						local cell = row[2]
						local ground = assert(
							WorldRule.fishingGround(cell.x, cell.z),
							"Fishing Round Rule selected a SeaCell without a fishing-ground definition"
						)
						local tier = 0
						local fish
						nextSeed, fish = CatalogRule.roll(RandomRule, nextSeed, tier)
						schoolsByEntity[row[1]] = {
							stock = ground.stock,
							depth = ground.depth,
							tier = tier,
							discovered = false,
							species = fish.species,
							displayName = fish.displayName,
							rarity = fish.rarity,
							value = fish.value,
						}
					end

					local nextRound = voyage.round + 1
					local effects = {
						Contribution.insert(ROOT_ENTITY, {
							voyage:patch({
								mode = "Searching",
								round = nextRound,
								revealed = false,
								message = string.format(
									"新航次已出港：%d 个鱼群已进入航区。雷达会指向最近目标，靠近后按 E 获取。",
									#grounds
								),
							}),
							rngState:patch({ seed = nextSeed }),
						}),
						Contribution.insert(vesselEntity, {
							vessel:patch({ x = 0, z = 0, headingX = 0, headingZ = 1, fuel = vessel.maxFuel }),
						}),
					}

					for _, row in ipairs(view:query(C.SeaCell)) do
						local cellEntity = row[1]
						local cell = row[2]
						local ice, oldSchool, oldSignal = view:get(cellEntity, C.Ice, C.FishSchool, C.Signal)
						local school = schoolsByEntity[cellEntity]

						-- Every school is an open-water destination. Other cells retain
						-- the existing deterministic ice-break route and fuel cost.
						local iceHardness = if cell.isPort or school ~= nil
							then nil
							else WorldRule.iceHardness(cell.x, cell.z, nextRound, 0, 0)

						if iceHardness ~= nil then
							table.insert(effects, Contribution.insert(cellEntity, { C.Ice({ hardness = iceHardness }) }))
						elseif ice ~= nil then
							table.insert(effects, Contribution.remove(cellEntity, { C.Ice }))
						end

						if school ~= nil then
							table.insert(effects, Contribution.insert(cellEntity, { C.FishSchool(school) }))
						elseif oldSchool ~= nil then
							table.insert(effects, Contribution.remove(cellEntity, { C.FishSchool }))
						end

						if oldSignal ~= nil then
							table.insert(effects, Contribution.remove(cellEntity, { C.Signal }))
						end
					end

					emit(Contribution.transaction("FishingRoundSystem", {
						orderKey = orderKey(observation),
						label = "BeginFishingRound",
						claims = { "round", "voyage", "vessel", "rng", "schools" },
						effects = effects,
					}))
				end
			end
		end,
	}
end
