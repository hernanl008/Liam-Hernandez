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
--
-- Note: `Table.Field: Type = value` is NOT valid Luau outside `local`
-- declarations (the parser reads the colon as the start of a method
-- definition) — every field below is a typed local assigned to
-- FishingConfig afterward, not typed inline.
local RarityXp: { [Rarity]: number } = {
	Common = 10,
	Uncommon = 15,
	Rare = 25,
	Epic = 40,
	Legendary = 100,
}
FishingConfig.RarityXp = RarityXp

-- Cast-power meter (GDD.md §3, FishingController.lua's CastMeterUI): base
-- odds a candidate fish is picked from its zone, before the cast-power
-- bonus below is applied. A weaker cast still has some chance at anything
-- in the zone (rarer fish are just uncommon), it just isn't biased toward
-- them.
local RarityWeight: { [Rarity]: number } = {
	Common = 50,
	Uncommon = 25,
	Rare = 12,
	Epic = 5,
	Legendary = 1,
}
FishingConfig.RarityWeight = RarityWeight

-- At castPower = 1 (a perfectly-timed cast), a rarity's weight is
-- multiplied by (1 + bonus) — Legendary quintuples, Common is cut by
-- more than half. At castPower = 0 the table has no effect at all
-- (weights are exactly RarityWeight above). Interpolated linearly by
-- castPower in between, see FishingService.weightedFishPick.
local RarityPowerBonus: { [Rarity]: number } = {
	Common = -0.65,
	Uncommon = 0,
	Rare = 1,
	Epic = 2.5,
	Legendary = 4,
}
FishingConfig.RarityPowerBonus = RarityPowerBonus

local Pulls: { PullDef } = {
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
FishingConfig.Pulls = Pulls

local DepthZones: { DepthZone } = {
	{ id = "Shallows", displayName = "Shallows", minDepth = 0, maxDepth = 15, unlockLevel = 1 },
	{ id = "MidReef", displayName = "Mid Reef", minDepth = 15, maxDepth = 40, unlockLevel = 5 },
	{ id = "DeepTrench", displayName = "Deep Trench", minDepth = 40, maxDepth = 90, unlockLevel = 12 },
	{ id = "AbyssalRift", displayName = "Abyssal Rift", minDepth = 90, maxDepth = 200, unlockLevel = 20 },
}
FishingConfig.DepthZones = DepthZones

local Fish: { FishDef } = {
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
	{
		id = "TrenchEel",
		displayName = "Trench Eel",
		rarity = "Uncommon",
		zones = { "DeepTrench" },
		baseWeight = NumberRange.new(2, 6),
		bitePatience = NumberRange.new(3, 7),
		struggleDifficulty = 6,
		sellPrice = 45,
		description = "Longer than it has any business being, and it knows it — half the "
			.. "fight is just keeping the line straight.",
	},
	{
		-- LORE_BIBLE.md §6/§8: the valley's magic has been declining for
		-- three generations and Blightspawn creep in from its fringes —
		-- this is what that decline looks like underwater. Deliberately
		-- *not* explained by any NPC (the founding myth is secondhand
		-- legend to everyone but Kaleb per §8's consistency rule); it's
		-- just a wrong-looking fish the player can notice on their own.
		id = "BlightscaleCarp",
		displayName = "Blightscale Carp",
		rarity = "Epic",
		zones = { "DeepTrench" },
		baseWeight = NumberRange.new(3, 8),
		bitePatience = NumberRange.new(4, 8),
		struggleDifficulty = 7,
		sellPrice = 90,
		description = "Its scales have a faint, sickly shimmer that has nothing to do with "
			.. "the light. Something out here isn't right.",
	},
	{
		id = "AbyssalAnglerfish",
		displayName = "Abyssal Anglerfish",
		rarity = "Rare",
		zones = { "AbyssalRift" },
		baseWeight = NumberRange.new(4, 10),
		bitePatience = NumberRange.new(5, 9),
		struggleDifficulty = 8,
		sellPrice = 120,
		description = "Its lure was still glowing when you pulled it up. Something else was watching it.",
	},
	{
		-- LORE_BIBLE.md §5 (Mossom): a small spirit-animal companion
		-- "revealed to be a fragment of the original guardian spirit."
		-- This is the deepest, rarest catch in the game — a wondrous,
		-- unexplained echo of that same presence, found where nothing
		-- should still be thriving. No NPC comments on it (§8's rule
		-- that nobody alive remembers the founding myth firsthand); the
		-- moment is meant to land on its own, foreshadowing without
		-- spoiling Act 2.
		id = "GuardiansEcho",
		displayName = "Guardian's Echo",
		rarity = "Legendary",
		zones = { "AbyssalRift" },
		baseWeight = NumberRange.new(10, 20),
		bitePatience = NumberRange.new(6, 10),
		struggleDifficulty = 10,
		sellPrice = 800,
		spectacle = true,
		description = "It shouldn't be alive down here. It shouldn't be alive at all, if half "
			.. "of what Elder Souta says about this valley is true. And yet.",
	},
	-- Add more species here as the world/lore expands (region-locked fish, event fish, etc.)
}
FishingConfig.Fish = Fish

return FishingConfig
