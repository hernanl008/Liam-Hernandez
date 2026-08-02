--!strict
-- Skill trees for the three pillars (GDD.md §12). One flat XP curve for
-- all three for now (tune SkillTreeConfig.xpPerLevel if pacing feels off
-- once playtested) — a level grants one skill point, spent here on perks.
--
-- Each tree is a short linear chain (2 perks) rather than a branching
-- graph: enough to feel like real progression without needing a graph-
-- layout UI for a vertical slice. Add more perks/branches once the core
-- three pillars are proven out (docs/ROADMAP.md Phase 3).
--
-- Perks are all *action-scoped* (applied at the moment the player
-- harvests/catches/cooks) rather than requiring persistent ownership of
-- world objects — e.g. Farming's perks apply at harvest time, not by
-- tracking who planted which plot. That sidesteps needing per-player farm
-- plot ownership (a bigger architecture change, see GDD.md §7) while
-- still giving Farming real perks. See FarmingService.lua/FishingService
-- .lua/CookingService.lua for where each perk id is actually read.

export type SkillId = "Farming" | "Fishing" | "Cooking"

export type PerkDef = {
	id: string,
	displayName: string,
	description: string,
	requiredLevel: number,
	requires: string?, -- prerequisite perk id, must already be unlocked
	cost: number, -- skill points
}

export type SkillTreeDef = {
	id: SkillId,
	displayName: string,
	perks: { PerkDef },
}

local SkillTreeConfig = {}

SkillTreeConfig.xpPerLevel = 100

-- `Table.Field: Type = value` is NOT valid Luau outside `local`
-- declarations (the parser reads the colon as the start of a method
-- definition) — declare a typed local first, then assign.
local Trees: { [SkillId]: SkillTreeDef } = {
	Farming = {
		id = "Farming",
		displayName = "Farming",
		perks = {
			{
				id = "GreenThumb",
				displayName = "Green Thumb",
				description = "15% chance to harvest a bonus crop.",
				requiredLevel = 2,
				cost = 1,
			},
			{
				id = "NoTillNeeded",
				displayName = "No Till Needed",
				description = "Harvesting a plot leaves it tilled, ready to replant immediately.",
				requiredLevel = 3,
				requires = "GreenThumb",
				cost = 1,
			},
		},
	},
	Fishing = {
		id = "Fishing",
		displayName = "Fishing",
		perks = {
			{
				id = "QuickHands",
				displayName = "Quick Hands",
				description = "The hook window after a bite is 50% longer.",
				requiredLevel = 2,
				cost = 1,
			},
			{
				id = "TreasureHunter",
				displayName = "Treasure Hunter",
				description = "Junk/treasure pulls are twice as likely to be treasure.",
				requiredLevel = 4,
				requires = "QuickHands",
				cost = 1,
			},
		},
	},
	Cooking = {
		id = "Cooking",
		displayName = "Cooking",
		perks = {
			{
				id = "EfficientCook",
				displayName = "Efficient Cook",
				description = "20% chance to not consume ingredients when you start cooking.",
				requiredLevel = 2,
				cost = 1,
			},
			{
				id = "ShowStopper",
				displayName = "Show Stopper",
				description = "Dishes are never worse than Bronze tier.",
				requiredLevel = 4,
				requires = "EfficientCook",
				cost = 1,
			},
		},
	},
}
SkillTreeConfig.Trees = Trees

return SkillTreeConfig
