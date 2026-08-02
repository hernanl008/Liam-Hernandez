--!strict
-- Data-driven config for crops. Growth is stage-based so it can drive both
-- server-side timers and client-side model swaps (seedling -> mid -> ripe).
-- No stamina system (GDD.md §5, research-informed decision) — growth only
-- requires watering once per day (FarmingService.lua), pacing comes from
-- the day cycle, not an energy bar.

export type GrowthStage = {
	stageIndex: number,
	durationSeconds: number,
	modelName: string, -- name of the model/mesh variant in ReplicatedStorage.Assets
}

export type CropDef = {
	id: string,
	displayName: string,
	season: "Spring" | "Summer" | "Fall" | "Winter" | "AllSeason",
	stages: { GrowthStage },
	regrowable: boolean, -- true = keeps producing after first harvest (e.g. berry bushes)
	sellPrice: number,
	usedInRecipes: { string }, -- RecipeChart ids from RhythmGameConfig
	description: string, -- shown in the Compendium (GDD.md §12)
}

local FarmingConfig = {}

FarmingConfig.Crops: { CropDef } = {
	{
		id = "MoonriceStalk",
		displayName = "Moonrice Stalk",
		season = "Summer",
		stages = {
			{ stageIndex = 1, durationSeconds = 60 * 10, modelName = "MoonriceSeedling" },
			{ stageIndex = 2, durationSeconds = 60 * 15, modelName = "MoonriceMidGrowth" },
			{ stageIndex = 3, durationSeconds = 60 * 10, modelName = "MoonriceRipe" },
		},
		regrowable = false,
		sellPrice = 8,
		usedInRecipes = {},
		description = "Orange Ville's staple grain. Glows faintly silver under a full moon — nobody's sure why.",
	},
	{
		-- Regrowable bush crop -- quick first grow, then a short regrow
		-- window each subsequent harvest (see FarmingService's regrowable
		-- handling). Feeds SunpetalJamTart in RhythmGameConfig.lua.
		id = "SunpetalBerries",
		displayName = "Sunpetal Berries",
		season = "AllSeason",
		stages = {
			{ stageIndex = 1, durationSeconds = 60 * 6, modelName = "SunpetalSprout" },
			{ stageIndex = 2, durationSeconds = 60 * 8, modelName = "SunpetalBush" },
			{ stageIndex = 3, durationSeconds = 60 * 4, modelName = "SunpetalRipe" },
		},
		regrowable = true,
		sellPrice = 4,
		usedInRecipes = { "SunpetalJamTart" },
		description = "Sweet enough to eat off the bush. Most don't make it to the kitchen.",
	},
	-- Add more crops as the world/regions are designed.
}

return FarmingConfig
