--!strict
-- Data-driven config for the fishing system. Tune numbers here; game logic
-- (rod casting, bite timing, catch minigame) lives in FishingService / FishingController.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type FishDef = {
	id: string,
	displayName: string,
	rarity: Rarity,
	zones: { string }, -- which DepthZones this fish can appear in
	baseWeight: NumberRange, -- kg, drives sell price + cooking yield
	bitePatience: NumberRange, -- seconds before a bite, min/max
	struggleDifficulty: number, -- 1-10, feeds the reel-in minigame
	sellPrice: number,
}

export type DepthZone = {
	id: string,
	displayName: string,
	minDepth: number, -- studs below water surface
	maxDepth: number,
	unlockLevel: number, -- player fishing level required
}

local FishingConfig = {}

FishingConfig.DepthZones: { DepthZone } = {
	{ id = "Shallows", displayName = "Shallows", minDepth = 0, maxDepth = 15, unlockLevel = 1 },
	{ id = "MidReef", displayName = "Mid Reef", minDepth = 15, maxDepth = 40, unlockLevel = 5 },
	{ id = "DeepTrench", displayName = "Deep Trench", minDepth = 40, maxDepth = 90, unlockLevel = 12 },
	{ id = "AbyssalRift", displayName = "Abyssal Rift", minDepth = 90, maxDepth = 200, unlockLevel = 20 },
}

FishingConfig.Fish: { FishDef } = {
	{
		id = "SilverMinnow",
		displayName = "Silver Minnow",
		rarity = "Common",
		zones = { "Shallows" },
		baseWeight = NumberRange.new(0.1, 0.5),
		bitePatience = NumberRange.new(1, 3),
		struggleDifficulty = 1,
		sellPrice = 5,
	},
	{
		id = "MoonfinKoi",
		displayName = "Moonfin Koi",
		rarity = "Rare",
		zones = { "MidReef" },
		baseWeight = NumberRange.new(1, 4),
		bitePatience = NumberRange.new(3, 6),
		struggleDifficulty = 5,
		sellPrice = 60,
	},
	-- Add more species here as the world/lore expands (region-locked fish, event fish, etc.)
}

return FishingConfig
