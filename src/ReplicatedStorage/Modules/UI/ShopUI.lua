--!strict
-- Kaleb's sell screen (ShopService.lua does the actual pricing/validation
-- — this only displays it and fires the sell request). Unlike
-- CompendiumUI, this refreshes in place while open (ShopController calls
-- ShopUI.refreshIfVisible on every InventoryUpdate) since selling changes
-- the very inventory being displayed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local FishingConfig = require(Modules:WaitForChild("Fishing"):WaitForChild("FishingConfig"))
local FarmingConfig = require(Modules:WaitForChild("Farming"):WaitForChild("FarmingConfig"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local ShopUI = {}

local screenGui: ScreenGui? = nil
local listFrame: ScrollingFrame
local visible = false

-- Same convenience-rate/tier math as ShopService.lua, duplicated here only
-- for *display* — the server is the one that actually prices a sale, this
-- just needs to show a number that matches what the player will get.
local CONVENIENCE_SELL_RATE = 0.8
local BOOSTED_SELL_RATE = 0.95 -- Market Savvy / Signature Dish (SkillTreeConfig.lua)
local DISH_TIER_MULTIPLIER: { [string]: number } = { Basic = 0.3, Bronze = 0.5, Silver = 0.8, Gold = 1.2 }

local function unitPriceFor(category: string, id: string): number?
	local unlockedPerks = InventoryCache.get().unlockedPerks
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
		local rate = (unlockedPerks.Farming and unlockedPerks.Farming.MarketSavvy) and BOOSTED_SELL_RATE
			or CONVENIENCE_SELL_RATE
		for _, crop in FarmingConfig.Crops do
			if crop.id == id then
				return math.floor(crop.sellPrice * rate)
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
		local rate = (unlockedPerks.Cooking and unlockedPerks.Cooking.SignatureDish) and BOOSTED_SELL_RATE
			or CONVENIENCE_SELL_RATE
		for _, recipe in RhythmGameConfig.Recipes do
			if recipe.id == recipeId then
				return math.floor(recipe.basePrice * multiplier * rate)
			end
		end
	end
	return nil
end

local function displayNameFor(category: string, id: string): string
	if category == "dishes" then
		local recipeId, tier = string.match(id, "^(.+)_(%a+)$")
		if recipeId then
			for _, recipe in RhythmGameConfig.Recipes do
				if recipe.id == recipeId then
					return `{tier} {recipe.displayName}`
				end
			end
		end
		return id
	elseif category == "fish" then
		for _, fish in FishingConfig.Fish do
			if fish.id == id then
				return fish.displayName
			end
		end
	elseif category == "crops" then
		for _, crop in FarmingConfig.Crops do
			if crop.id == id then
				return crop.displayName
			end
		end
	elseif category == "junk" then
		for _, pull in FishingConfig.Pulls do
			if pull.id == id then
				return pull.displayName
			end
		end
	end
	return id
end

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.5, 0.75)
	frame.Position = UDim2.fromScale(0.25, 0.1)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Theme.applyPanel(frame)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.07)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "Kaleb's Counter"
	title.Parent = frame
	Theme.styleHeader(title)

	local closeHint = Instance.new("TextLabel")
	closeHint.Size = UDim2.fromScale(1, 0.04)
	closeHint.Position = UDim2.fromScale(0, 0.07)
	closeHint.BackgroundTransparency = 1
	closeHint.TextScaled = true
	closeHint.Text = "Press N to close"
	closeHint.Parent = frame
	Theme.styleBody(closeHint, Theme.Colors.TextMuted)

	local scroller = Instance.new("ScrollingFrame")
	scroller.Size = UDim2.fromScale(0.96, 0.87)
	scroller.Position = UDim2.fromScale(0.02, 0.12)
	scroller.BackgroundTransparency = 1
	scroller.ScrollBarThickness = 6
	scroller.CanvasSize = UDim2.fromScale(0, 0) -- grown by UIListLayout below
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.Parent = frame
	listFrame = scroller

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = scroller
end

local function addRow(category: string, id: string, count: number, order: number)
	local unitPrice = unitPriceFor(category, id)
	if not unitPrice then
		return
	end

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 44)
	row.LayoutOrder = order
	row.Parent = listFrame
	Theme.applyCard(row, 6)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(0.55, 1)
	nameLabel.Position = UDim2.fromScale(0.02, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = `{displayNameFor(category, id)} x{count} (~{unitPrice}g each)`
	nameLabel.Parent = row
	Theme.styleBody(nameLabel, Theme.Colors.AccentGold)

	local sellButton = Instance.new("TextButton")
	sellButton.Size = UDim2.fromScale(0.3, 0.7)
	sellButton.Position = UDim2.fromScale(0.68, 0.15)
	sellButton.BackgroundColor3 = Theme.Colors.ButtonAvailable
	sellButton.Text = `Sell All (+{unitPrice * count}g)`
	sellButton.TextScaled = true
	sellButton.AutoButtonColor = true
	sellButton.Parent = row
	Theme.applyCard(sellButton, 6)
	Theme.styleBody(sellButton, Theme.Colors.TextPrimary)

	sellButton.Activated:Connect(function()
		Remotes.get("SellItem"):FireServer(category, id, count)
	end)
end

local function rebuild()
	for _, child in listFrame:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local snapshot = InventoryCache.get()
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local hasAnything = false
	for _, category in { "fish", "crops", "dishes", "junk" } do
		local bucket = (snapshot :: any)[category] :: { [string]: number }
		for id, count in bucket do
			if count > 0 then
				addRow(category, id, count, nextOrder())
				hasAnything = true
			end
		end
	end

	if not hasAnything then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 44)
		empty.BackgroundTransparency = 1
		empty.TextScaled = true
		empty.Text = "Nothing to sell right now."
		empty.LayoutOrder = nextOrder()
		empty.Parent = listFrame
		Theme.styleBody(empty, Theme.Colors.TextMuted)
	end
end

function ShopUI.toggle()
	ensureBuilt()
	visible = not visible
	if visible then
		rebuild()
	end
	(screenGui :: ScreenGui).Enabled = visible
end

function ShopUI.isVisible(): boolean
	return visible
end

function ShopUI.refreshIfVisible()
	if visible then
		rebuild()
	end
end

return ShopUI
