--!strict
-- Data-driven config for crops. Growth is stage-based so it can drive both
-- server-side timers and client-side model swaps (seedling -> mid -> ripe).

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
	},
	-- Add more crops as the world/regions are designed.
}

return FarmingConfig
