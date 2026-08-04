--!strict
-- General inventory screen (docs/ROADMAP.md Phase 2 — "data's already
-- replicated client-side via InventoryCache.lua, just needs a screen").
-- Unlike CompendiumUI (an index of every possible item, "???" until
-- discovered) this only shows what the player is actually carrying right
-- now, laid out as a real grid (UIGridLayout) rather than CompendiumUI's/
-- ShopUI's single-column row list, to read as a distinct "inventory" screen
-- rather than a third copy of the same list. Also the only place NPC
-- relationship values (persisted since earlier this session, never shown
-- anywhere) are surfaced — a "Bonds" set of tiles after the item grid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local FishingConfig = require(Modules:WaitForChild("Fishing"):WaitForChild("FishingConfig"))
local FarmingConfig = require(Modules:WaitForChild("Farming"):WaitForChild("FarmingConfig"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local InventoryUI = {}

local screenGui: ScreenGui? = nil
local gridFrame: ScrollingFrame
local goldLabel: TextLabel
local visible = false

-- Relationship values have persisted server-side (PlayerDataService.lua)
-- since earlier this session, but nothing ever showed them to the player
-- — DialogueController.lua's StatusToast on each change is the only other
-- feedback. Ordered list (not DialogueData.Roots directly) so display
-- order is stable regardless of table iteration order.
local BOND_NPCS: { { id: string, displayName: string } } = {
	{ id = "Kaya", displayName = "Kaya" },
	{ id = "ElderSouta", displayName = "Elder Souta" },
	{ id = "Ren", displayName = "Ren Amakusa" },
	{ id = "Hinano", displayName = "Chef Hinano" },
	{ id = "Kaleb", displayName = "Kaleb" },
}

-- Seeds and harvested crops are both keyed by cropId (FarmingConfig.Crops)
-- so they share a display-name lookup; dishes are keyed "{recipeId}_{tier}"
-- (CookingService.lua) same as ShopUI.
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
	elseif category == "seeds" or category == "crops" then
		for _, crop in FarmingConfig.Crops do
			if crop.id == id then
				return category == "seeds" and `{crop.displayName} Seeds` or crop.displayName
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
	gui.Name = "InventoryUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.55, 0.75)
	frame.Position = UDim2.fromScale(0.225, 0.1)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Theme.applyPanel(frame)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.7, 0.07)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "Inventory"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromScale(0.02, 0)
	title.Parent = frame
	Theme.styleHeader(title)

	local gold = Instance.new("TextLabel")
	gold.Size = UDim2.fromScale(0.28, 0.07)
	gold.Position = UDim2.fromScale(0.7, 0)
	gold.BackgroundTransparency = 1
	gold.TextScaled = true
	gold.TextXAlignment = Enum.TextXAlignment.Right
	gold.Text = "0g"
	gold.Parent = frame
	Theme.styleHeader(gold, Theme.Colors.AccentGold)
	goldLabel = gold

	local closeHint = Instance.new("TextLabel")
	closeHint.Size = UDim2.fromScale(1, 0.04)
	closeHint.Position = UDim2.fromScale(0, 0.07)
	closeHint.BackgroundTransparency = 1
	closeHint.TextScaled = true
	closeHint.Text = "Press I to close"
	closeHint.Parent = frame
	Theme.styleBody(closeHint, Theme.Colors.TextMuted)

	local scroller = Instance.new("ScrollingFrame")
	scroller.Size = UDim2.fromScale(0.96, 0.87)
	scroller.Position = UDim2.fromScale(0.02, 0.12)
	scroller.BackgroundTransparency = 1
	scroller.ScrollBarThickness = 6
	scroller.CanvasSize = UDim2.fromScale(0, 0) -- grown by UIGridLayout below
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.Parent = frame
	gridFrame = scroller

	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellSize = UDim2.new(0, 150, 0, 72)
	layout.CellPadding = UDim2.new(0, 8, 0, 8)
	layout.Parent = scroller
end

local function addTile(category: string, id: string, count: number, order: number)
	local tile = Instance.new("Frame")
	tile.LayoutOrder = order
	tile.Parent = gridFrame
	Theme.applyCard(tile, 8)
	tile.BackgroundColor3 = Color3.fromRGB(58, 40, 55)

	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.fromScale(1, 0.35)
	countLabel.Position = UDim2.fromScale(0, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.TextScaled = true
	countLabel.Text = `x{count}`
	countLabel.Parent = tile
	Theme.styleHeader(countLabel, Theme.Colors.AccentGold)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(0.92, 0.55)
	nameLabel.Position = UDim2.fromScale(0.04, 0.4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.Text = displayNameFor(category, id)
	nameLabel.Parent = tile
	Theme.styleBody(nameLabel, Theme.Colors.TextPrimary)
end

local function addBondTile(displayName: string, value: number, order: number)
	local tile = Instance.new("Frame")
	tile.LayoutOrder = order
	tile.Parent = gridFrame
	Theme.applyCard(tile, 8)
	tile.BackgroundColor3 = Color3.fromRGB(60, 32, 45)

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.fromScale(1, 0.35)
	valueLabel.Position = UDim2.fromScale(0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.TextScaled = true
	valueLabel.Text = `\u{2665} {value}`
	valueLabel.Parent = tile
	Theme.styleHeader(valueLabel, Theme.Colors.AccentPink)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(0.92, 0.55)
	nameLabel.Position = UDim2.fromScale(0.04, 0.4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.Text = displayName
	nameLabel.Parent = tile
	Theme.styleBody(nameLabel, Theme.Colors.TextPrimary)
end

local function rebuild()
	for _, child in gridFrame:GetChildren() do
		if not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end

	local snapshot = InventoryCache.get()
	goldLabel.Text = `{snapshot.gold}g`

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local hasAnything = false
	for _, category in { "seeds", "crops", "fish", "dishes", "junk" } do
		local bucket = (snapshot :: any)[category] :: { [string]: number }
		for id, count in bucket do
			if count > 0 then
				addTile(category, id, count, nextOrder())
				hasAnything = true
			end
		end
	end

	if not hasAnything then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 44)
		empty.BackgroundTransparency = 1
		empty.TextScaled = true
		empty.Text = "Your inventory is empty."
		empty.LayoutOrder = nextOrder()
		empty.Parent = gridFrame
		Theme.styleBody(empty, Theme.Colors.TextMuted)
	end

	-- Only NPCs the player has actually met — showing "Elder Souta: 0"
	-- before ever talking to him would spoil the roster/give away nothing
	-- meaningful anyway.
	for _, npc in BOND_NPCS do
		if snapshot.flags[`Met_{npc.id}`] == true then
			addBondTile(npc.displayName, snapshot.relationships[npc.id] or 0, nextOrder())
		end
	end
end

function InventoryUI.toggle()
	ensureBuilt()
	visible = not visible
	if visible then
		rebuild()
	end
	(screenGui :: ScreenGui).Enabled = visible
end

function InventoryUI.isVisible(): boolean
	return visible
end

function InventoryUI.refreshIfVisible()
	if visible then
		rebuild()
	end
end

return InventoryUI
