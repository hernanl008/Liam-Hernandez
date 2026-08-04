--!strict
-- Kaleb's black-market sell counter (LORE_BIBLE.md §5) — currently the
-- *only* way to convert fish/crops/dishes/junk into gold. Distinct from
-- the Trade Exchange (GDD.md §7, Kotobuki Port, player-to-player listings,
-- run by Mira Kessler) which doesn't exist yet: Kaleb is the "no
-- paperwork, pays less, always available" option, not a replacement for
-- it — see CONVENIENCE_SELL_RATE below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local FishingConfig = require(Modules:WaitForChild("Fishing"):WaitForChild("FishingConfig"))
local FarmingConfig = require(Modules:WaitForChild("Farming"):WaitForChild("FarmingConfig"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local ShopService = {}

-- Kaleb takes a cut on everything except his actual specialty — junk and
-- treasure pulls sell at full listed value (LORE_BIBLE.md §5: "junk sells
-- only to Kaleb specifically", keeping his black market distinct from the
-- legitimate Trade Exchange).
local CONVENIENCE_SELL_RATE = 0.8

-- Dishes are inventoried as "{recipeId}_{tier}" (CookingService.lua) with
-- only a count kept per stack, not the exact quality a given batch was
-- cooked at — so selling approximates value from tier alone rather than
-- the precise quality-based price CookingService showed at cook time.
local DISH_TIER_MULTIPLIER: { [string]: number } = {
	Basic = 0.3,
	Bronze = 0.5,
	Silver = 0.8,
	Gold = 1.2,
}

type SellableCategory = "fish" | "crops" | "dishes" | "junk"

-- Per-unit sell price, or nil if `id` isn't a recognized item in that
-- category (or, for dishes, doesn't parse as "{recipeId}_{tier}").
local function priceFor(category: SellableCategory, id: string): number?
	if category == "junk" then
		for _, pull in FishingConfig.Pulls do
			if pull.id == id then
				return pull.value
			end
		end
	elseif category == "fish" then
		for _, fish in FishingConfig.Fish do
			if fish.id == id then
				return math.floor(fish.sellPrice * CONVENIENCE_SELL_RATE)
			end
		end
	elseif category == "crops" then
		for _, crop in FarmingConfig.Crops do
			if crop.id == id then
				return math.floor(crop.sellPrice * CONVENIENCE_SELL_RATE)
			end
		end
	elseif category == "dishes" then
		local recipeId, tier = string.match(id, "^(.+)_(%a+)$")
		if not recipeId then
			return nil
		end
		local multiplier = DISH_TIER_MULTIPLIER[tier]
		if not multiplier then
			return nil
		end
		for _, recipe in RhythmGameConfig.Recipes do
			if recipe.id == recipeId then
				return math.floor(recipe.basePrice * multiplier * CONVENIENCE_SELL_RATE)
			end
		end
	end
	return nil
end

local VALID_CATEGORIES: { [string]: boolean } = { fish = true, crops = true, dishes = true, junk = true }

function ShopService.init()
	Remotes.get("SellItem").OnServerEvent:Connect(function(player: Player, category: string, id: string, amount: number)
		if typeof(category) ~= "string" or typeof(id) ~= "string" or typeof(amount) ~= "number" then
			return
		end
		if not VALID_CATEGORIES[category] then
			return
		end
		amount = math.floor(amount)
		if amount < 1 then
			return
		end

		if not PlayerDataService.hasFlag(player, "UnlockKalebShop") then
			Remotes.get("SellItemRejected"):FireClient(player, "You haven't met Kaleb yet.")
			return
		end

		local unitPrice = priceFor(category :: SellableCategory, id)
		if not unitPrice then
			return -- unrecognized item, not a legitimate sell request
		end

		if not PlayerDataService.hasItem(player, category :: SellableCategory, id, amount) then
			Remotes.get("SellItemRejected"):FireClient(player, "You don't have that many to sell.")
			return
		end

		PlayerDataService.removeItem(player, category :: SellableCategory, id, amount)
		PlayerDataService.addGold(player, unitPrice * amount)
	end)
end

return ShopService
