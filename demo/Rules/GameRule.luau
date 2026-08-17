--!strict

local Application = script.Parent.Parent
local ApplicationComponents = require(Application.Components)
local CatalogRule = require(script.Parent.CatalogRule)
local InitialStateRule = require(script.Parent.InitialStateRule)
local WorldRule = require(script.Parent.WorldRule)

local RoundSystem = require(Application.Systems.RoundSystem)
local ScanSystem = require(Application.Systems.ScanSystem)
local ReturnSystem = require(Application.Systems.ReturnSystem)
local IceBreakSystem = require(Application.Systems.IceBreakSystem)
local NavigationSystem = require(Application.Systems.NavigationSystem)
local ArrivalSystem = require(Application.Systems.ArrivalSystem)
local FishingSystem = require(Application.Systems.FishingSystem)
local SettlementSystem = require(Application.Systems.SettlementSystem)

local GameRule = {}

function GameRule.new(Matter, ECSR)
	local ProtocolComponents = require(ECSR.Components)
	local Contribution = require(ECSR.Components.Contribution)
	local ObservationCleanupSystem = require(ECSR.Systems.ObservationCleanupSystem)
	local FrameworkRule = require(ECSR.Rules.FrameworkRule)
	local RandomRule = require(ECSR.Rules.RandomRule)

	local C = ApplicationComponents.define(Matter, ProtocolComponents)
	local evolution = FrameworkRule.new(Matter, C, {
		initial = InitialStateRule.create(C, WorldRule, 20260816),
		phases = {
			{
				name = "intent",
				systems = {
					RoundSystem(C, Contribution, RandomRule, WorldRule),
					ScanSystem(C, Contribution, WorldRule),
					ReturnSystem(C, Contribution),
				},
			},
			{
				name = "ice",
				systems = { IceBreakSystem(C, Contribution, WorldRule) },
			},
			{
				name = "navigation",
				systems = { NavigationSystem(C, Contribution, WorldRule) },
			},
			{
				name = "arrival",
				systems = { ArrivalSystem(C, Contribution, WorldRule) },
			},
			{
				name = "harvest",
				systems = { FishingSystem(C, Contribution, RandomRule, CatalogRule) },
			},
			{
				name = "settlement",
				systems = { SettlementSystem(C, Contribution, CatalogRule, WorldRule) },
			},
			{
				name = "cleanup",
				systems = { ObservationCleanupSystem(C) },
				advanceTick = true,
			},
		},
	})

	return table.freeze({
		evolution = evolution,
		components = C,
		rootEntity = 1,
	})
end

return table.freeze(GameRule)
