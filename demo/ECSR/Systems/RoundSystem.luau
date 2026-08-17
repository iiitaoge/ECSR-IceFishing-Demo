--!strict

local ROOT_ENTITY = 1

local function orderKey(observation): string
	return string.format("%016d", observation.sequence)
end

return function(C, Contribution, RandomRule, WorldRule)
	return {
		name = "FishingRoundSystem",
		evaluate = function(view, emit)
			local voyage, hold, rngState = view:get(ROOT_ENTITY, C.Voyage, C.Hold, C.RngState)
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
									voyage:patch({ message = "先把本趟渔获出售或收藏，再开始新航次。" }),
								}),
							},
						}))
						continue
					end

					local grounds = {}
					for _, row in ipairs(view:query(C.SeaCell)) do
						if row[2].isFishingGround then
							table.insert(grounds, row)
						end
					end
					assert(#grounds > 0, "Fishing Round Rule needs at least one fishing ground")
					local nextSeed, targetIndex = RandomRule.integer(rngState.seed, 1, #grounds)
					local targetEntity = grounds[targetIndex][1]
					local targetCell = grounds[targetIndex][2]
					local nextRound = voyage.round + 1
					local signalKeys = WorldRule.signalKeys(targetCell.x, targetCell.z)
					local effects = {
						Contribution.insert(ROOT_ENTITY, {
							voyage:patch({
								mode = "Searching",
								round = nextRound,
								revealed = false,
								message = "海鸟在远海盘旋。观察线索，或启动声呐锁定鱼群。",
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
						local wantsIce = WorldRule.shouldFreeze(cell.x, cell.z, nextRound, targetCell.x, targetCell.z)

						if wantsIce then
							table.insert(effects, Contribution.insert(cellEntity, {
								C.Ice({ hardness = 1 }),
							}))
						elseif ice ~= nil then
							table.insert(effects, Contribution.remove(cellEntity, { C.Ice }))
						end

						if cellEntity == targetEntity then
							table.insert(effects, Contribution.insert(cellEntity, {
								C.FishSchool({ stock = 3, depth = 1 }),
							}))
						elseif oldSchool ~= nil then
							table.insert(effects, Contribution.remove(cellEntity, { C.FishSchool }))
						end

						if signalKeys[WorldRule.key(cell.x, cell.z)] then
							table.insert(effects, Contribution.insert(cellEntity, {
								C.Signal({ kind = "Birds", strength = 1 }),
							}))
						elseif oldSignal ~= nil then
							table.insert(effects, Contribution.remove(cellEntity, { C.Signal }))
						end
					end

					emit(Contribution.transaction("FishingRoundSystem", {
						orderKey = orderKey(observation),
						label = "BeginFishingRound",
						claims = { "round", "voyage", "vessel", "rng" },
						effects = effects,
					}))
				end
			end
		end,
	}
end
