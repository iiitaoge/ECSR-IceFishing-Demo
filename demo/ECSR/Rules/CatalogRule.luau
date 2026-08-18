--!strict

local CatalogRule = {}

local ORDER = table.freeze({
	"IceHerring",
	"ArcticCod",
	"AuroraSalmon",
	"CrystalHalibut",
})

local WEIGHTS_BY_TIER = table.freeze({
	[0] = table.freeze({
		IceHerring = 40,
		ArcticCod = 30,
		AuroraSalmon = 23,
		CrystalHalibut = 7,
	}),
	[1] = table.freeze({
		IceHerring = 30,
		ArcticCod = 30,
		AuroraSalmon = 30,
		CrystalHalibut = 10,
	}),
	[2] = table.freeze({
		IceHerring = 20,
		ArcticCod = 25,
		AuroraSalmon = 35,
		CrystalHalibut = 20,
	}),
	[3] = table.freeze({
		IceHerring = 10,
		ArcticCod = 20,
		AuroraSalmon = 40,
		CrystalHalibut = 30,
	}),
})

local VALUE_MULTIPLIERS = table.freeze({
	[0] = 1,
	[1] = 1.25,
	[2] = 1.6,
	[3] = 2,
})

local ENTRIES = table.freeze({
	IceHerring = table.freeze({ species = "IceHerring", displayName = "冰海鲱", rarity = "Common", value = 12 }),
	ArcticCod = table.freeze({ species = "ArcticCod", displayName = "北极鳕", rarity = "Common", value = 18 }),
	AuroraSalmon = table.freeze({ species = "AuroraSalmon", displayName = "极光鲑", rarity = "Rare", value = 55 }),
	CrystalHalibut = table.freeze({ species = "CrystalHalibut", displayName = "水晶比目鱼", rarity = "Epic", value = 140 }),
})

function CatalogRule.roll(randomRule, seed: number, tier: number)
	local weights = assert(WEIGHTS_BY_TIER[tier], "Catalog Rule received an unknown fishing-ground tier")
	local multiplier = assert(VALUE_MULTIPLIERS[tier], "Catalog Rule received an unknown value tier")
	local nextSeed, species = randomRule.weighted(seed, weights, ORDER)
	local entry = assert(ENTRIES[species], "Catalog Rule selected an unknown species")
	return nextSeed, table.freeze({
		species = entry.species,
		displayName = entry.displayName,
		rarity = entry.rarity,
		value = math.floor(entry.value * multiplier),
	})
end

function CatalogRule.isCollectible(rarity: string): boolean
	return rarity == "Rare" or rarity == "Epic"
end

return table.freeze(CatalogRule)
