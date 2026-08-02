--!strict
-- The "book" (GDD.md §12): a scrollable index of every fish, dish, crop,
-- and junk/treasure pull in the game, sectioned by category. Undiscovered
-- entries show as "???" — discovery happens the first time
-- PlayerDataService.addItem/discover records that id for this player
-- (FishingService/CookingService/FarmingService).
--
-- Rebuilds its content fresh each time it's opened rather than staying
-- live-updated while open — simpler, and discovery only happens while
-- out fishing/cooking/farming anyway, never while the book is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local FishingConfig = require(Modules:WaitForChild("Fishing"):WaitForChild("FishingConfig"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))
local FarmingConfig = require(Modules:WaitForChild("Farming"):WaitForChild("FarmingConfig"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local CompendiumUI = {}

local screenGui: ScreenGui? = nil
local listFrame: ScrollingFrame
local visible = false

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CompendiumUI"
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
	title.Text = "Compendium"
	title.Parent = frame
	Theme.styleHeader(title)

	local closeHint = Instance.new("TextLabel")
	closeHint.Size = UDim2.fromScale(1, 0.04)
	closeHint.Position = UDim2.fromScale(0, 0.07)
	closeHint.BackgroundTransparency = 1
	closeHint.TextScaled = true
	closeHint.Text = "Press B to close"
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

local function addSectionHeader(text: string, order: number)
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 28)
	header.BackgroundTransparency = 1
	header.TextScaled = true
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = text
	header.LayoutOrder = order
	header.Parent = listFrame
	Theme.styleHeader(header, Theme.Colors.AccentPink)
end

local function addEntry(displayName: string, tag: string, description: string, discovered: boolean, order: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundColor3 = discovered and Color3.fromRGB(58, 40, 55) or Color3.fromRGB(35, 30, 35)
	row.LayoutOrder = order
	row.Parent = listFrame
	Theme.applyCard(row, 6)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(0.4, 1)
	nameLabel.Position = UDim2.fromScale(0.02, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = discovered and `{displayName} ({tag})` or "???"
	nameLabel.Parent = row
	Theme.styleBody(nameLabel, discovered and Theme.Colors.AccentGold or Theme.Colors.TextMuted)
	nameLabel.Font = Theme.Fonts.BodyBold

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.fromScale(0.56, 1)
	descLabel.Position = UDim2.fromScale(0.42, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.TextScaled = true
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Text = discovered and description or "Not yet discovered."
	descLabel.Parent = row
	Theme.styleBody(descLabel, discovered and Theme.Colors.TextSecondary or Theme.Colors.TextMuted)
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

	addSectionHeader("Fish", nextOrder())
	for _, fish in FishingConfig.Fish do
		addEntry(fish.displayName, fish.rarity, fish.description, snapshot.discovered.fish[fish.id] == true, nextOrder())
	end

	addSectionHeader("Dishes", nextOrder())
	for _, recipe in RhythmGameConfig.Recipes do
		addEntry(recipe.displayName, `~{recipe.basePrice}g`, recipe.description, snapshot.discovered.dishes[recipe.id] == true, nextOrder())
	end

	addSectionHeader("Crops", nextOrder())
	for _, crop in FarmingConfig.Crops do
		addEntry(crop.displayName, crop.season, crop.description, snapshot.discovered.crops[crop.id] == true, nextOrder())
	end

	addSectionHeader("Junk & Treasure", nextOrder())
	for _, pull in FishingConfig.Pulls do
		addEntry(pull.displayName, pull.pullType, pull.description, snapshot.discovered.junk[pull.id] == true, nextOrder())
	end
end

function CompendiumUI.toggle()
	ensureBuilt()
	visible = not visible
	if visible then
		rebuild()
	end
	(screenGui :: ScreenGui).Enabled = visible
end

function CompendiumUI.isVisible(): boolean
	return visible
end

return CompendiumUI
