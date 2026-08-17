--!strict

local CatalogRule = {}

local ORDER = table.freeze({
	"IceHerring",
	"ArcticCod",
	"AuroraSalmon",
	"CrystalHalibut",
})

local WEIGHTS = table.freeze({
	IceHerring = 40,
	ArcticCod = 30,
	AuroraSalmon = 23,
	CrystalHalibut = 7,
})

local ENTRIES = table.freeze({
	IceHerring = table.freeze({ species = "IceHerring", displayName = "冰海鲱", rarity = "Common", value = 12 }),
	ArcticCod = table.freeze({ species = "ArcticCod", displayName = "北极鳕", rarity = "Common", value = 18 }),
	AuroraSalmon = table.freeze({ species = "AuroraSalmon", displayName = "极光鲑", rarity = "Rare", value = 55 }),
	CrystalHalibut = table.freeze({ species = "CrystalHalibut", displayName = "水晶比目鱼", rarity = "Epic", value = 140 }),
})

function CatalogRule.roll(randomRule, seed: number)
	local nextSeed, species = randomRule.weighted(seed, WEIGHTS, ORDER)
	return nextSeed, assert(ENTRIES[species], "Catalog Rule selected an unknown species")
end

function CatalogRule.isCollectible(rarity: string): boolean
	return rarity == "Rare" or rarity == "Epic"
end

return table.freeze(CatalogRule)
