--!strict

local InitialStateRule = {}

function InitialStateRule.create(C, worldRule, initialSeed: number)
	local entities = {
		{
			C.Vessel({ x = 0, z = 0, headingX = 0, headingZ = 1, fuel = 14, maxFuel = 14, capacity = 6 }),
		},
	}

	for _, cell in ipairs(worldRule.cells()) do
		table.insert(entities, {
			C.SeaCell({
				x = cell.x,
				z = cell.z,
				isPort = cell.isPort,
				isFishingGround = cell.isFishingGround,
			}),
		})
	end

	return {
		root = {
			C.Voyage({
				mode = "Docked",
				round = 0,
				revealed = false,
				message = "船已停靠。点击“出航”开始第一趟破冰捕鱼。",
			}),
			C.Economy({ coins = 0 }),
			C.Hold({ fishIds = {} }),
			C.Collection({ fishIds = {} }),
			C.RngState({ seed = initialSeed }),
			C.EvolutionTrace({ entries = {}, maxEntries = 64 }),
			C.ObservationJournal({ nextSequence = 1, entries = {}, maxEntries = 128 }),
		},
		entities = entities,
	}
end

return table.freeze(InitialStateRule)
