--!strict

local ROOT_ENTITY = 1

return function(C, Contribution, WorldRule)
	return {
		name = "FishDiscoverySystem",
		evaluate = function(view, emit)
			local voyage = assert(view:get(ROOT_ENTITY, C.Voyage), "Fish Discovery System needs Voyage")
			local vesselRow = assert(view:query(C.Vessel)[1], "Fish Discovery System needs one Vessel")
			local vessel = vesselRow[2]
			if voyage.mode ~= "Searching" then
				return
			end

			local effects = {}
			local claims = { "discovery", "voyage" }
			local discoveredCount = 0
			local firstName = nil
			local firstValue = nil
			for _, row in ipairs(view:query(C.SeaCell, C.FishSchool)) do
				local schoolEntity = row[1]
				local cell = row[2]
				local school = row[3]
				if not school.discovered
					and WorldRule.distance(vessel.x, vessel.z, cell.x, cell.z) <= WorldRule.discoveryRange()
				then
					table.insert(claims, "school:" .. tostring(schoolEntity))
					table.insert(effects, Contribution.insert(schoolEntity, {
						school:patch({ discovered = true }),
					}))
					discoveredCount += 1
					if firstName == nil then
						firstName = school.displayName
						firstValue = school.value
					end
				end
			end

			if discoveredCount == 0 then
				return
			end

			table.insert(effects, Contribution.insert(ROOT_ENTITY, {
				voyage:patch({
					revealed = true,
					message = string.format(
						"发现鱼群：%s，价值 %d 金币。靠近后按 E 获取。",
						assert(firstName),
						assert(firstValue)
					),
				}),
			}))

			emit(Contribution.transaction("FishDiscoverySystem", {
				label = "DiscoverFishSchool",
				claims = claims,
				effects = effects,
			}))
		end,
	}
end
