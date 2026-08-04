--!strict
-- Data-driven config for the cooking rhythm minigame. Each recipe defines a
-- note chart; timing accuracy on each note determines dish quality.

-- Note types carry diegetic meaning rather than being abstract lanes
-- (GDD.md §10, research-informed): Tap = crack/chop/plate, Hold =
-- stir/simmer (hold duration mirrors the action's real duration), Slide =
-- flip/toss. Client-side scoring (RhythmScoring.lua) only reads time/lane
-- today — noteType currently drives animation/VFX choices, not scoring.
export type NoteType = "Tap" | "Hold" | "Slide"

export type Note = {
	time: number, -- seconds from chart start
	lane: number, -- 1-4
	noteType: NoteType,
	holdDuration: number?, -- only for Hold notes
}

export type TimingWindow = {
	name: "Perfect" | "Good" | "Okay" | "Miss",
	toleranceSeconds: number,
	qualityScore: number, -- contributes to final dish quality (0-100)
}

export type RecipeChart = {
	id: string,
	displayName: string,
	ingredients: { string }, -- FishDef ids / crop ids consumed
	bpm: number,
	notes: { Note },
	basePrice: number, -- sell price at 100% quality
	description: string, -- shown in the Compendium (GDD.md §12)
}

local RhythmGameConfig = {}

-- `Table.Field: Type = value` is NOT valid Luau outside `local`
-- declarations (the parser reads the colon as the start of a method
-- definition) — declare typed locals first, then assign, everywhere in
-- this file and its sibling config modules.
local TimingWindows: { TimingWindow } = {
	{ name = "Perfect", toleranceSeconds = 0.05, qualityScore = 100 },
	{ name = "Good", toleranceSeconds = 0.12, qualityScore = 70 },
	{ name = "Okay", toleranceSeconds = 0.20, qualityScore = 40 },
	{ name = "Miss", toleranceSeconds = math.huge, qualityScore = 0 },
}
RhythmGameConfig.TimingWindows = TimingWindows

local Recipes: { RecipeChart } = {
	{
		id = "GrilledMinnowSkewer",
		displayName = "Grilled Minnow Skewer",
		ingredients = { "SilverMinnow" },
		bpm = 100,
		notes = {
			{ time = 0.6, lane = 1, noteType = "Tap" },
			{ time = 1.2, lane = 2, noteType = "Tap" },
			{ time = 1.8, lane = 3, noteType = "Hold", holdDuration = 0.6 },
		},
		basePrice = 15,
		description = "Hinano's first lesson: plain, quick, forgiving. Everyone starts here.",
	},
	{
		-- Longer/harder chart than the tutorial recipe — deliberately
		-- gives the combo bonus (RhythmScoring.lua, GDD.md §11) room to
		-- matter, since a 3-note chart can't build much of a streak.
		id = "SunpetalJamTart",
		displayName = "Sunpetal Jam Tart",
		ingredients = { "SunpetalBerries" },
		bpm = 130,
		notes = {
			{ time = 0.5, lane = 1, noteType = "Tap" },
			{ time = 0.9, lane = 2, noteType = "Tap" },
			{ time = 1.3, lane = 3, noteType = "Tap" },
			{ time = 1.7, lane = 1, noteType = "Hold", holdDuration = 0.4 },
			{ time = 2.3, lane = 4, noteType = "Tap" },
			{ time = 2.7, lane = 2, noteType = "Slide" },
			{ time = 3.1, lane = 3, noteType = "Tap" },
			{ time = 3.5, lane = 4, noteType = "Hold", holdDuration = 0.5 },
		},
		basePrice = 35,
		description = "A festival-circuit staple. Vane calls it simple; Hinano calls it honest.",
	},
	{
		id = "SpringrootMisoSoup",
		displayName = "Springroot Miso Soup",
		ingredients = { "SpringrootOnion" },
		bpm = 90,
		notes = {
			{ time = 0.6, lane = 1, noteType = "Tap" },
			{ time = 1.2, lane = 2, noteType = "Tap" },
			{ time = 1.8, lane = 1, noteType = "Hold", holdDuration = 0.5 },
			{ time = 2.5, lane = 3, noteType = "Tap" },
		},
		basePrice = 12,
		description = "Orange Ville's first-of-the-season dish — Hinano makes a batch the day "
			.. "the Springroot comes up, no exceptions.",
	},
	{
		-- Deliberately the first recipe to consume two different
		-- ingredients (one crop, one fish) — CookingService.lua's
		-- ingredient loop already supported this from the start, nothing
		-- else in the recipe roster had exercised it yet.
		id = "EmberGlazedTrenchEel",
		displayName = "Ember-Glazed Trench Eel",
		ingredients = { "EmberleafSquash", "TrenchEel" },
		bpm = 110,
		notes = {
			{ time = 0.5, lane = 1, noteType = "Tap" },
			{ time = 1.0, lane = 2, noteType = "Tap" },
			{ time = 1.5, lane = 3, noteType = "Slide" },
			{ time = 2.0, lane = 1, noteType = "Hold", holdDuration = 0.5 },
			{ time = 2.7, lane = 4, noteType = "Tap" },
			{ time = 3.2, lane = 2, noteType = "Tap" },
			{ time = 3.7, lane = 3, noteType = "Hold", holdDuration = 0.6 },
		},
		basePrice = 55,
		description = "Half farm, half catch — squash from the Fields, eel from the Trench. "
			.. "A dish that could only come from Orange Ville doing both at once.",
	},
	{
		id = "FrostberryTart",
		displayName = "Frostberry Tart",
		ingredients = { "Frostberry" },
		bpm = 100,
		notes = {
			{ time = 0.5, lane = 2, noteType = "Tap" },
			{ time = 1.0, lane = 3, noteType = "Tap" },
			{ time = 1.5, lane = 1, noteType = "Slide" },
			{ time = 2.1, lane = 4, noteType = "Hold", holdDuration = 0.5 },
			{ time = 2.8, lane = 2, noteType = "Tap" },
		},
		basePrice = 22,
		description = "Best served the same day as a hard frost — Hinano insists the timing "
			.. "actually matters, Vane insists she's being superstitious.",
	},
	{
		-- MoonriceStalk has existed since the earliest content this game
		-- had (FarmingConfig.lua's original Summer crop) but never had a
		-- recipe of its own — every other crop got one as the roster grew,
		-- this one was just missed. Named/paced as a second tutorial-tier
		-- dish, one step past GrilledMinnowSkewer.
		id = "MoonriceOnigiri",
		displayName = "Moonrice Onigiri",
		ingredients = { "MoonriceStalk" },
		bpm = 95,
		notes = {
			{ time = 0.5, lane = 1, noteType = "Tap" },
			{ time = 1.0, lane = 3, noteType = "Tap" },
			{ time = 1.5, lane = 2, noteType = "Hold", holdDuration = 0.5 },
			{ time = 2.2, lane = 4, noteType = "Tap" },
			{ time = 2.7, lane = 1, noteType = "Tap" },
		},
		basePrice = 20,
		description = "Hinano won't say why she only serves this after dark — just that Moonrice "
			.. "tastes different by moonlight, and refuses to explain further.",
	},
	-- Add more recipes as the food/lore list grows (regional dishes, festival specials, etc.)
}
RhythmGameConfig.Recipes = Recipes

return RhythmGameConfig
