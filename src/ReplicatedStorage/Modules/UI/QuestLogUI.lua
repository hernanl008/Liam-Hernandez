--!strict
-- The quest log (J): every quest, open and finished, with its giver,
-- objectives and reward.
--
-- The on-screen tracker deliberately shows only ONE quest — the nearest
-- to completion — because a permanent list of six is a wall players stop
-- reading. This is where the rest lives: opened on demand, so it can
-- afford to be complete.
--
-- Completed quests stay listed rather than disappearing. A log that only
-- shows outstanding work throws away the record of what you've done,
-- which in a game with no other progress summary is most of the reason
-- to open it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local QuestConfig = require(Modules:WaitForChild("Shared"):WaitForChild("QuestConfig"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local QuestLogUI = {}

local screenGui: ScreenGui? = nil
local backdrop: Frame
local panel: Frame
local panelScale: UIScale
local listFrame: ScrollingFrame
local emptyLabel: TextLabel
local visible = false

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestLogUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 6
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(18, 10, 6)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 1
	backdrop.Parent = gui

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -120, 1, -120)
	panel.ZIndex = 3
	panel.Parent = gui

	local sizeCap = Instance.new("UISizeConstraint")
	sizeCap.MaxSize = Vector2.new(720, 640)
	sizeCap.Parent = panel

	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local face = Theme.framedPanel(panel, 10)

	-- Content clears Roblox's own topbar, measured rather than assumed:
	-- that strip is a different height on mobile and console.
	local topbar = 36
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and inset then
		topbar = math.max(inset.Y, 8)
	end

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.Parent = face

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 18)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.FontFace = Theme.RetroFontFace
	title.TextSize = 14
	title.TextColor3 = Theme.RetroColors.Ink
	title.Text = "JOURNAL"
	title.ZIndex = 4
	title.Parent = face

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0, 18)
	hint.BackgroundTransparency = 1
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.FontFace = Theme.RetroFontFace
	hint.TextSize = 9
	hint.TextColor3 = Theme.RetroColors.InkMuted
	hint.Text = "J TO CLOSE"
	hint.ZIndex = 4
	hint.Parent = face

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.fromOffset(0, 30)
	listFrame.Size = UDim2.new(1, 0, 1, -30)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.ScrollBarImageColor3 = Theme.RetroColors.WoodMid
	listFrame.CanvasSize = UDim2.new()
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.ZIndex = 4
	listFrame.Parent = face

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = listFrame

	emptyLabel = Instance.new("TextLabel")
	emptyLabel.Size = UDim2.new(1, 0, 0, 40)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
	emptyLabel.FontFace = Theme.RetroFontFace
	emptyLabel.TextSize = 10
	emptyLabel.TextColor3 = Theme.RetroColors.InkMuted
	emptyLabel.Text = "NOTHING RECORDED YET."
	emptyLabel.Visible = false
	emptyLabel.ZIndex = 5
	emptyLabel.Parent = face
end

local function describeReward(reward: QuestConfig.Reward): string
	local parts = {}
	if reward.gold then
		table.insert(parts, `{reward.gold}G`)
	end
	if reward.seeds then
		table.insert(parts, `{reward.seeds.count}x {reward.seeds.id}`)
	end
	if reward.skill then
		table.insert(parts, `{reward.skill.xp} {reward.skill.id} XP`)
	end
	return #parts > 0 and table.concat(parts, "  ") or "-"
end

local function addEntry(quest: QuestConfig.QuestDef, counters: { number }?, done: boolean, order: number)
	local rows = #quest.objectives
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -10, 0, 62 + rows * 16)
	card.LayoutOrder = order
	card.ZIndex = 5
	card.Parent = listFrame
	local face = Theme.framedPanel(card, 6)

	local heading = Instance.new("TextLabel")
	heading.Position = UDim2.fromOffset(12, 8)
	heading.Size = UDim2.new(1, -24, 0, 14)
	heading.BackgroundTransparency = 1
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.FontFace = Theme.RetroFontFace
	heading.TextSize = 11
	heading.TextColor3 = if done then Theme.RetroColors.InkMuted else Theme.RetroColors.Rust
	heading.TextTruncate = Enum.TextTruncate.AtEnd
	heading.Text = string.upper(`{done and "[DONE] " or ""}{quest.title}  -  {quest.giver}`)
	heading.ZIndex = 6
	heading.Parent = face

	local summary = Instance.new("TextLabel")
	summary.Position = UDim2.fromOffset(12, 26)
	summary.Size = UDim2.new(1, -24, 0, 16)
	summary.BackgroundTransparency = 1
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.TextYAlignment = Enum.TextYAlignment.Top
	summary.TextWrapped = true
	summary.FontFace = Theme.RetroFontFace
	summary.TextSize = 9
	summary.LineHeight = 1.3
	summary.TextColor3 = Theme.RetroColors.Ink
	summary.Text = string.upper(quest.summary)
	summary.ZIndex = 6
	summary.Parent = face

	for index, objective in quest.objectives do
		local have = if done then objective.count else math.min((counters and counters[index]) or 0, objective.count)
		local ticked = have >= objective.count

		local row = Instance.new("TextLabel")
		row.Position = UDim2.fromOffset(12, 44 + (index - 1) * 16)
		row.Size = UDim2.new(1, -24, 0, 14)
		row.BackgroundTransparency = 1
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.FontFace = Theme.RetroFontFace
		row.TextSize = 9
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.TextColor3 = if ticked then Theme.RetroColors.InkMuted else Theme.RetroColors.Ink
		row.Text = string.upper(`{ticked and "[X]" or "[ ]"} {objective.description}  {have}/{objective.count}`)
		row.ZIndex = 6
		row.Parent = face
	end

	local reward = Instance.new("TextLabel")
	reward.AnchorPoint = Vector2.new(0, 1)
	reward.Position = UDim2.new(0, 12, 1, -8)
	reward.Size = UDim2.new(1, -24, 0, 12)
	reward.BackgroundTransparency = 1
	reward.TextXAlignment = Enum.TextXAlignment.Left
	reward.FontFace = Theme.RetroFontFace
	reward.TextSize = 8
	reward.TextColor3 = Theme.RetroColors.InkMuted
	reward.Text = string.upper(`REWARD: {describeReward(quest.reward)}`)
	reward.ZIndex = 6
	reward.Parent = face
end

local function rebuild()
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local snapshot = InventoryCache.get()
	local order = 0
	local shown = 0

	-- Open quests first, then finished ones. Sorting by state rather than
	-- by definition order keeps the thing you can act on at the top, which
	-- is the reason the log gets opened in the first place.
	for _, quest in QuestConfig.Quests do
		local counters = snapshot.questProgress[quest.id]
		if counters and not snapshot.questsCompleted[quest.id] then
			order += 1
			shown += 1
			addEntry(quest, counters, false, order)
		end
	end
	for _, quest in QuestConfig.Quests do
		if snapshot.questsCompleted[quest.id] then
			order += 1
			shown += 1
			addEntry(quest, nil, true, order)
		end
	end

	emptyLabel.Visible = shown == 0
end

function QuestLogUI.toggle()
	ensureBuilt()
	visible = not visible
	local gui = screenGui :: ScreenGui
	if visible then
		rebuild()
		gui.Enabled = true
		backdrop.BackgroundTransparency = 1
		panelScale.Scale = 0.95
		TweenService:Create(backdrop, TweenInfo.new(0.18), { BackgroundTransparency = 0.5 }):Play()
		TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	else
		gui.Enabled = false
	end
end

function QuestLogUI.isVisible(): boolean
	return visible
end

function QuestLogUI.refreshIfVisible()
	if visible then
		ensureBuilt()
		rebuild()
	end
end

return QuestLogUI
