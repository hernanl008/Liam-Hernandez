--!strict
-- Cooking rhythm minigame (GDD.md §4). Always produces a dish — never a
-- wasted-ingredients wipe — per the research-informed "always produces
-- something, quality varies" decision; quality is instead encoded as a
-- tier suffix on the dish item id, since inventory here is count-based
-- (see PlayerDataService) rather than per-item unique instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local RhythmScoring = require(Modules:WaitForChild("Shared"):WaitForChild("RhythmScoring"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local CookingService = {}

type PendingCook = {
	recipe: RhythmGameConfig.RecipeChart,
}

local pendingCooks: { [Player]: PendingCook } = {}

local function getRecipe(recipeId: string): RhythmGameConfig.RecipeChart?
	for _, recipe in RhythmGameConfig.Recipes do
		if recipe.id == recipeId then
			return recipe
		end
	end
	return nil
end

local function qualityTier(quality: number): string
	if quality >= 85 then
		return "Gold"
	elseif quality >= 60 then
		return "Silver"
	elseif quality >= 30 then
		return "Bronze"
	end
	return "Basic"
end

function CookingService.init()
	Remotes.get("StartCooking").OnServerEvent:Connect(function(player: Player, recipeId: string)
		local recipe = getRecipe(recipeId)
		if not recipe then
			return
		end

		for _, ingredientId in recipe.ingredients do
			local hasCrop = PlayerDataService.hasItem(player, "crops", ingredientId, 1)
			local hasFish = PlayerDataService.hasItem(player, "fish", ingredientId, 1)
			if not hasCrop and not hasFish then
				return -- missing an ingredient, silently reject (client should have checked first)
			end
		end

		for _, ingredientId in recipe.ingredients do
			if not PlayerDataService.removeItem(player, "crops", ingredientId, 1) then
				PlayerDataService.removeItem(player, "fish", ingredientId, 1)
			end
		end

		pendingCooks[player] = { recipe = recipe }
		Remotes.get("CookingStart"):FireClient(player, { recipeId = recipe.id, notes = recipe.notes })
	end)

	Remotes.get("CookingResult").OnServerEvent:Connect(function(player: Player, hits: { RhythmScoring.Hit })
		local pending = pendingCooks[player]
		if not pending then
			return
		end
		pendingCooks[player] = nil

		local data = PlayerDataService.get(player)
		local assistMode = data ~= nil and data.assistMode or false
		local result = RhythmScoring.evaluate(pending.recipe.notes, hits, RhythmGameConfig.TimingWindows, assistMode)
		local tier = qualityTier(result.quality)
		local dishId = `{pending.recipe.id}_{tier}`

		PlayerDataService.addItem(player, "dishes", dishId, 1)

		Remotes.get("CookingOutcome"):FireClient(player, {
			recipeId = pending.recipe.id,
			displayName = pending.recipe.displayName,
			quality = result.quality,
			maxCombo = result.maxCombo,
			tier = tier,
			estimatedValue = math.floor(pending.recipe.basePrice * math.max(result.quality, 10) / 100),
			-- GDD.md §11: Gold tier or a big combo triggers CookingController's celebratory banner.
			spectacle = tier == "Gold" or result.maxCombo >= 5,
		})
	end)
end

return CookingService
