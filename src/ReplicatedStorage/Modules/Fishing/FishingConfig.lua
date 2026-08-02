--!strict
-- Data-driven config for the fishing system. Tune numbers here; game logic
-- (rod casting, bite timing, catch minigame) lives in FishingService / FishingController.
-- Reel-in timing tolerance is widened by PlayerDataService's assistMode
-- flag (GDD.md §3 "Assist Mode") via RhythmScoring, not modeled here.

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
	nightOnly: boolean?, -- only biteable while DayCycleService.isNight() — see LORE_BIBLE.md §5 (Ren)
	spectacle: boolean?, -- GDD.md §11: triggers the celebratory catch banner/shake on FishingController
	description: string, -- shown in the Compendium (GDD.md §12); "???" is shown instead until discovered
}

export type DepthZone = {
	id: string,
	displayName: string,
	minDepth: number, -- studs below water surface
	maxDepth: number,
	unlockLevel: number, -- player fishing level required
}

export type PullType = "Junk" | "Treasure"

export type PullDef = {
	id: string,
	displayName: string,
	pullType: PullType,
	sellsTo: "Kaleb" | "TradeExchange", -- GDD.md §3: junk/treasure are a
	-- research-informed addition (Fields of Mistria / Stardew players
	-- both cite this as a favorite fishing beat); junk sells only to
	-- Kaleb specifically per LORE_BIBLE.md §5, keeping his black market
	-- distinct from the legitimate Trade Exchange.
	value: number,
	description: string, -- shown in the Compendium (GDD.md §12)
}

local FishingConfig = {}

-- Rolled independently of the fish table on every cast — see
-- FishingService.rollPull. Kept small and separate from FishingConfig.Fish
-- so "did I catch a fish" and "did I also get a junk/treasure pull" stay
-- two independent, easy-to-balance rolls.
FishingConfig.PullChance = 0.08 -- 8% of casts also yield a junk/treasure pull
FishingConfig.TreasureShare = 0.25 -- of pulls that happen, 25% are treasure not junk (doubled by the TreasureHunter perk)

-- Fishing skill XP awarded per catch (GDD.md §12) — rarer fish level you
-- up faster, on top of just being worth more to sell.
FishingConfig.RarityXp: { [Rarity]: number } = {
	Common = 10,
	Uncommon = 15,
	Rare = 25,
	Epic = 40,
	Legendary = 100,
}

FishingConfig.Pulls: { PullDef } = {
	{
		id = "Driftwood",
		displayName = "Driftwood",
		pullType = "Junk",
		sellsTo = "Kaleb",
		value = 1,
		description = "Waterlogged and split down the middle. Kaleb takes it anyway.",
	},
	{
		id = "OldBoot",
		displayName = "Old Boot",
		pullType = "Junk",
		sellsTo = "Kaleb",
		value = 1,
		description = "Nobody in Orange Ville claims to be missing a boot.",
	},
	{
		id = "TarnishedLocket",
		displayName = "Tarnished Locket",
		pullType = "Treasure",
		sellsTo = "Kaleb",
		value = 25,
		description = "Empty inside. Whoever it belonged to isn't saying.",
	},
	{
		id = "SunkenCoinPouch",
		displayName = "Sunken Coin Pouch",
		pullType = "Treasure",
		sellsTo = "Kaleb",
		value = 40,
		description = "Old coinage, older than the Trade Exchange. Kaleb's eyes light up at these.",
	},
}

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
		description = "Small, quick, everywhere. Every angler in Orange Ville started here.",
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
		description = "Its scales catch the light like they're storing it up for later.",
	},
	{
		-- Ren Amakusa's "one that got away" (LORE_BIBLE.md §5) — the fish
		-- his postgame redemption questline centers on. Deliberately
		-- catchable in the Shallows (no need to unlock deeper zones for
		-- the story payoff to land) but only at night, so it stays a real
		-- event rather than something players stumble into casually.
		id = "MoonlitSerpent",
		displayName = "Moonlit Serpent",
		rarity = "Legendary",
		zones = { "Shallows" },
		baseWeight = NumberRange.new(8, 15),
		bitePatience = NumberRange.new(4, 8),
		struggleDifficulty = 9,
		sellPrice = 500,
		nightOnly = true,
		spectacle = true,
		description = "Ren swears he saw it once. Now you have too.",
	},
	-- Add more species here as the world/lore expands (region-locked fish, event fish, etc.)
}

return FishingConfig
