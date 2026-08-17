--!strict

local Components = {}

local DOMAIN_NAMES = table.freeze({
	"Voyage",
	"Vessel",
	"Economy",
	"Hold",
	"Collection",
	"RngState",
	"SeaCell",
	"Ice",
	"FishSchool",
	"Signal",
	"FishCatch",
	"Trophy",
})

function Components.define(matter, protocolComponents)
	return protocolComponents.define(matter, DOMAIN_NAMES)
end

function Components.names()
	return DOMAIN_NAMES
end

return table.freeze(Components)
