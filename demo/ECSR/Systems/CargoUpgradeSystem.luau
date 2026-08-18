--!strict

local ROOT_ENTITY = 1

return function(C, Contribution, CargoUpgradeRule)
	return {
		name = "CargoUpgradeSystem",
		evaluate = function(view, emit)
			local voyage, economy, hold, cargoUpgrade = view:get(
				ROOT_ENTITY,
				C.Voyage,
				C.Economy,
				C.Hold,
				C.CargoUpgrade
			)
			voyage = assert(voyage, "Cargo Upgrade System needs Voyage")
			economy = assert(economy, "Cargo Upgrade System needs Economy")
			hold = assert(hold, "Cargo Upgrade System needs Hold")
			cargoUpgrade = assert(cargoUpgrade, "Cargo Upgrade System needs CargoUpgrade")
			local vesselRow = assert(view:query(C.Vessel)[1], "Cargo Upgrade System needs one Vessel")
			local vesselEntity = vesselRow[1]
			local vessel = vesselRow[2]

			for _, observationRow in ipairs(view:query(C.Observation)) do
				local observation = observationRow[2]
				if observation.kind == "FishingCommand" and observation.payload.action == "UpgradeCargo" then
					local nextCost = CargoUpgradeRule.costForNextLevel(cargoUpgrade.cargoLevel)
					local canUpgrade = voyage.mode == "Docked"
						and #hold.fishIds == 0
						and nextCost ~= nil
						and economy.coins >= nextCost
					local message
					if voyage.mode ~= "Docked" then
						message = "只能在港口停靠时升级货舱。"
					elseif #hold.fishIds > 0 then
						message = "先出售货舱内的鱼群，再进行货舱升级。"
					elseif nextCost == nil then
						message = "货舱已达到最大容量。"
					elseif economy.coins < nextCost then
						message = string.format("升级货舱需要 %d 金币；当前只有 %d 金币。", nextCost, economy.coins)
					else
						local nextLevel = cargoUpgrade.cargoLevel + 1
						local nextCapacity = CargoUpgradeRule.capacityForLevel(nextLevel)
						local followingCost = CargoUpgradeRule.costForNextLevel(nextLevel) or 0
						message = string.format("货舱升级成功：容量提升至 %d 格。", nextCapacity)
						emit(Contribution.transaction("CargoUpgradeSystem", {
							orderKey = string.format("%016d", observation.sequence),
							label = "UpgradeCargo",
							claims = { "voyage", "economy", "hold", "vessel", "cargoUpgrade" },
							effects = {
								Contribution.insert(ROOT_ENTITY, {
									economy:patch({ coins = economy.coins - assert(nextCost) }),
									cargoUpgrade:patch({
										cargoLevel = nextLevel,
										nextCargoCost = followingCost,
									}),
									voyage:patch({ message = message }),
								}),
								Contribution.insert(vesselEntity, {
									vessel:patch({ capacity = nextCapacity }),
								}),
							},
						}))
						continue
					end

					if not canUpgrade then
						emit(Contribution.transaction("CargoUpgradeSystem", {
							orderKey = string.format("%016d", observation.sequence),
							label = "RejectCargoUpgrade",
							claims = { "voyage", "economy", "hold", "cargoUpgrade" },
							effects = {
								Contribution.insert(ROOT_ENTITY, {
									voyage:patch({ message = assert(message) }),
								}),
							},
						}))
					end
				end
			end
		end,
	}
end
