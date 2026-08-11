--!strict
-- Quest definitions (GDD.md §12).
--
-- The game had three working pillars — farming, fishing, cooking — and
-- nothing that told a new player to do any of them. You land in a field,
-- Kaya hands you a farm, and then the game says nothing at all. These
-- exist to answer "what now", and to walk a first-time player through
-- each pillar once before leaving them to it.
--
-- Objectives are counted from things that ALREADY happen. Every service
-- that awards an item calls QuestService.report at the same point, so a
-- quest never needs its own trigger volume, its own listener or its own
-- copy of the game rules — harvesting a crop advances a harvest
-- objective whether or not a quest is watching. Adding a quest here is a
-- data change and nothing else.
--
-- Chained by `requires` rather than being handed out by NPCs on a
-- schedule: the giver is flavour on the card, and the chain is what
-- controls pacing. That keeps the whole system independent of where an
-- NPC happens to be standing, which matters while NPCs do not move.

export type ObjectiveKind = "harvest" | "catch" | "cook" | "sell" | "earn" | "talk"

export type Objective = {
	kind: ObjectiveKind,
	-- Specific id to match (a crop id, fish id, NpcId...). nil counts any
	-- event of that kind, which is what most early objectives want:
	-- "catch 3 fish" should not care which.
	target: string?,
	count: number,
	description: string,
}

export type Reward = {
	gold: number?,
	seeds: { id: string, count: number }?,
	skill: { id: string, xp: number }?,
}

export type QuestDef = {
	id: string,
	title: string,
	giver: string, -- NpcId, flavour only
	summary: string,
	requires: string?, -- quest id that must be complete first
	objectives: { Objective },
	reward: Reward,
}

local QuestConfig = {}

-- Order matters only for display; `requires` is what gates availability.
local Quests: { QuestDef } = {
	{
		id = "FirstHarvest",
		title = "Something From Nothing",
		giver = "Kaya",
		summary = "Kaya gave you a field and a handful of seeds. Prove they were not wasted.",
		objectives = {
			{ kind = "harvest", count = 3, description = "Harvest any 3 crops" },
		},
		reward = { gold = 60, seeds = { id = "SpringrootOnion", count = 3 }, skill = { id = "Farming", xp = 40 } },
	},
	{
		id = "FirstCatch",
		title = "The Water Provides",
		giver = "Kaya",
		summary = "The cove has fed this valley longer than the fields have. Go and see.",
		requires = "FirstHarvest",
		objectives = {
			{ kind = "catch", count = 2, description = "Land any 2 fish" },
		},
		reward = { gold = 80, skill = { id = "Fishing", xp = 50 } },
	},
	{
		id = "FirstMeal",
		title = "Worth Cooking",
		giver = "Hinano",
		summary = "Hinano will not be impressed by ingredients. She wants a dish.",
		requires = "FirstCatch",
		objectives = {
			{ kind = "cook", count = 1, description = "Cook any dish" },
		},
		reward = { gold = 100, skill = { id = "Cooking", xp = 60 } },
	},
	{
		id = "MarketDay",
		title = "Market Day",
		giver = "Kaleb",
		summary = "Kaleb buys anything that grows, swims or was cooked well. Test him.",
		requires = "FirstMeal",
		objectives = {
			{ kind = "sell", count = 5, description = "Sell any 5 items to Kaleb" },
			{ kind = "earn", count = 400, description = "Hold 400 gold at once" },
		},
		reward = { gold = 150, seeds = { id = "SunpetalBerries", count = 4 } },
	},
	{
		id = "KnowTheValley",
		title = "Know The Valley",
		giver = "ElderSouta",
		summary = "Souta says a farmer who does not know their neighbours is only a tenant.",
		requires = "FirstMeal",
		objectives = {
			{ kind = "talk", target = "ElderSouta", count = 1, description = "Speak with Elder Souta" },
			{ kind = "talk", target = "Ren", count = 1, description = "Speak with Ren Amakusa" },
			{ kind = "talk", target = "Hinano", count = 1, description = "Speak with Chef Hinano" },
		},
		reward = { gold = 120 },
	},
	{
		id = "DeepWater",
		title = "Deep Water",
		giver = "Ren",
		summary = "Ren does not say what he is looking for out there. He does say the shallows will not have it.",
		requires = "FirstCatch",
		objectives = {
			{ kind = "catch", count = 8, description = "Land 8 fish in total" },
			{ kind = "catch", target = "MoonfinKoi", count = 1, description = "Land a Moonfin Koi" },
		},
		reward = { gold = 220, skill = { id = "Fishing", xp = 120 } },
	},
}

QuestConfig.Quests = Quests

local byId: { [string]: QuestDef } = {}
for _, quest in Quests do
	byId[quest.id] = quest
end
QuestConfig.ById = byId

-- Quests whose prerequisite is met and which aren't finished yet.
-- Returns them in definition order so the tracker is stable between
-- frames rather than reshuffling with table iteration.
function QuestConfig.availableFor(completed: { [string]: boolean }): { QuestDef }
	local open = {}
	for _, quest in Quests do
		if not completed[quest.id] and (quest.requires == nil or completed[quest.requires]) then
			table.insert(open, quest)
		end
	end
	return open
end

return QuestConfig
