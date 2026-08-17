--!strict

local ROOT_ENTITY = 1

return function(C, Contribution, CatalogRule, WorldRule)
	return {
		name = "CatchSettlementSystem",
		evaluate = function(view, emit)
			local voyage, hold, economy = view:get(ROOT_ENTITY, C.Voyage, C.Hold, C.Economy)
			voyage = assert(voyage, "Settlement System needs Voyage")
			hold = assert(hold, "Settlement System needs Hold")
			economy = assert(economy, "Settlement System needs Economy")
			local vesselRow = assert(view:query(C.Vessel)[1], "Settlement System needs one Vessel")
			local vessel = vesselRow[2]
			local fishById = {}
			for _, row in ipairs(view:query(C.FishCatch)) do
				fishById[row[1]] = row[2]
			end

			for _, observationRow in ipairs(view:query(C.Observation)) do
				local observation = observationRow[2]
				local action = observation.payload.action
				if observation.kind == "FishingCommand" and (action == "SellAll" or action == "KeepRare") then
					local canSettle = voyage.mode == "DockedWithCatch" and WorldRule.isPort(vessel.x, vessel.z)
					if not canSettle then
						emit(Contribution.transaction("CatchSettlementSystem", {
							orderKey = string.format("%016d", observation.sequence),
							label = "RejectSettlement",
							claims = { "voyage" },
							effects = {
								Contribution.insert(ROOT_ENTITY, {
									voyage:patch({ message = "返港后才能出售或收藏渔获。" }),
								}),
							},
						}))
						continue
					end

					local effects = {}
					local claims = { "settlement", "voyage", "hold", "economy" }
					local revenue = 0
					local kept = 0
					for _, fishId in ipairs(hold.fishIds) do
						local fish = assert(fishById[fishId], "Hold references a missing FishCatch")
						table.insert(claims, "fish:" .. tostring(fishId))
						table.insert(effects, Contribution.collectionRemove(ROOT_ENTITY, C.Hold, "fishIds", fishId))
						if action == "KeepRare" and CatalogRule.isCollectible(fish.rarity) then
							kept += 1
							table.insert(effects, Contribution.collectionAdd(ROOT_ENTITY, C.Collection, "fishIds", fishId))
							table.insert(effects, Contribution.insert(fishId, {
								C.Trophy({ acquiredRound = voyage.round }),
							}))
						else
							revenue += fish.value
							table.insert(effects, Contribution.despawn(fishId))
						end
					end

					local message = if action == "SellAll"
						then string.format("全部渔获售出，收入 %d 金币。可以再次出航。", revenue)
						else string.format("收藏 %d 条稀有鱼，普通鱼售得 %d 金币。可以再次出航。", kept, revenue)
					table.insert(effects, Contribution.insert(ROOT_ENTITY, {
						economy:patch({ coins = economy.coins + revenue }),
						voyage:patch({ mode = "Docked", revealed = false, message = message }),
					}))

					emit(Contribution.transaction("CatchSettlementSystem", {
						orderKey = string.format("%016d", observation.sequence),
						label = if action == "SellAll" then "SellAllCatch" else "KeepRareCatch",
						claims = claims,
						effects = effects,
					}))
				end
			end
		end,
	}
end
