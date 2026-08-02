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
}

local RhythmGameConfig = {}

RhythmGameConfig.TimingWindows: { TimingWindow } = {
	{ name = "Perfect", toleranceSeconds = 0.05, qualityScore = 100 },
	{ name = "Good", toleranceSeconds = 0.12, qualityScore = 70 },
	{ name = "Okay", toleranceSeconds = 0.20, qualityScore = 40 },
	{ name = "Miss", toleranceSeconds = math.huge, qualityScore = 0 },
}

RhythmGameConfig.Recipes: { RecipeChart } = {
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
	},
	-- Add more recipes as the food/lore list grows (regional dishes, festival specials, etc.)
}

return RhythmGameConfig
