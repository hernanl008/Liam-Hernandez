--!strict
-- The on-screen quest tracker: one quest, its objectives, and how far
-- along each is. Sits under the HUD's purse in the top-right corner.
--
-- ONE quest, not a list. Six can be open at once by the time the chain
-- branches, and a tracker showing all of them is a wall the player
-- learns to ignore — which defeats the point of having it on screen at
-- all. The full set lives in the quest log (J); this shows the one thing
-- to do next.
--
-- Which one that is: the quest closest to completion, ties broken by
-- definition order. Picking by "most progress" means finishing something
-- always moves the tracker onto the next nearest goal rather than
-- stranding it on a long-running quest while three short ones sit
-- invisible.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local GuiService = game:GetService("GuiService")
local QuestConfig = require(Modules:WaitForChild("Shared"):WaitForChild("QuestConfig"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local QuestTrackerUI = {}

local WIDTH = 340
local ROW_HEIGHT = 18

local screenGui: ScreenGui? = nil
local panel: Frame
local titleLabel: TextLabel
local rowsFrame: Frame
local built = false

local function ensureBuilt()
	if built then
		return
	end
	built = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestTrackerUI"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	-- Sits below the HUD's three panels. Measured off the same topbar
	-- inset the HUD uses so the two stacks stay aligned on any device.
	local top = 44
	local ok, inset = pcall(function()
		return GuiService.TopbarInset
	end)
	if ok and inset then
		top = inset.Height + 4
	end

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -6, 0, top + 92)
	panel.Size = UDim2.fromOffset(WIDTH, 90)
	panel.Visible = false
	panel.ZIndex = 2
	panel.Parent = gui
	local face = Theme.framedPanel(panel, 8)

	titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.fromOffset(12, 8)
	titleLabel.Size = UDim2.new(1, -24, 0, 14)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.FontFace = Theme.RetroFontFace
	titleLabel.TextSize = 11
	titleLabel.TextColor3 = Theme.RetroColors.Rust
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.ZIndex = 3
	titleLabel.Parent = face

	rowsFrame = Instance.new("Frame")
	rowsFrame.Position = UDim2.fromOffset(12, 30)
	rowsFrame.Size = UDim2.new(1, -24, 1, -38)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.ZIndex = 3
	rowsFrame.Parent = face

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = rowsFrame
end

-- Fraction of `quest` that is done, 0-1. Averaged across objectives so a
-- two-objective quest with one finished reads as half, not as "not
-- finished".
local function completion(quest: QuestConfig.QuestDef, counters: { number }): number
	local total = 0
	for index, objective in quest.objectives do
		total += math.min((counters[index] or 0) / objective.count, 1)
	end
	return total / math.max(#quest.objectives, 1)
end

local function pickTracked(): (QuestConfig.QuestDef?, { number }?)
	local snapshot = InventoryCache.get()
	local best: QuestConfig.QuestDef? = nil
	local bestCounters: { number }? = nil
	local bestScore = -1

	for _, quest in QuestConfig.Quests do
		if snapshot.questsCompleted[quest.id] then
			continue
		end
		local counters = snapshot.questProgress[quest.id]
		if not counters then
			continue -- not open yet (prerequisite unmet)
		end
		local score = completion(quest, counters)
		-- Strict >, so ties fall to the earlier definition and the tracker
		-- doesn't flicker between two equally-progressed quests.
		if score > bestScore then
			best, bestCounters, bestScore = quest, counters, score
		end
	end
	return best, bestCounters
end

function QuestTrackerUI.refresh()
	ensureBuilt()
	local quest, counters = pickTracked()
	if not quest or not counters then
		panel.Visible = false
		return
	end

	titleLabel.Text = string.upper(quest.title)

	for _, child in rowsFrame:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	for index, objective in quest.objectives do
		local have = math.min(counters[index] or 0, objective.count)
		local done = have >= objective.count

		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.LayoutOrder = index
		row.BackgroundTransparency = 1
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.FontFace = Theme.RetroFontFace
		row.TextSize = 9
		row.TextTruncate = Enum.TextTruncate.AtEnd
		-- A finished objective stays on the list rather than vanishing, so
		-- the player can see what they already did; it just stops competing
		-- for attention.
		row.TextColor3 = if done then Theme.RetroColors.InkMuted else Theme.RetroColors.Ink
		row.Text = string.upper(`{done and "[X]" or "[ ]"} {objective.description}  {have}/{objective.count}`)
		row.ZIndex = 4
		row.Parent = rowsFrame
	end

	panel.Size = UDim2.fromOffset(WIDTH, 38 + #quest.objectives * (ROW_HEIGHT + 3))
	panel.Visible = true
end

-- Slides a completion notice down from the tracker. Deliberately its own
-- moment rather than a line in the status strip: finishing a quest is
-- the payoff for everything the tracker has been nagging about.
function QuestTrackerUI.announce(title: string, rewardText: string)
	ensureBuilt()
	local gui = screenGui :: ScreenGui

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, -0.2)
	card.Size = UDim2.fromOffset(420, 66)
	card.ZIndex = 6
	card.Parent = gui
	local face = Theme.framedPanel(card, 8)

	local heading = Instance.new("TextLabel")
	heading.Position = UDim2.fromOffset(16, 10)
	heading.Size = UDim2.new(1, -32, 0, 14)
	heading.BackgroundTransparency = 1
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.FontFace = Theme.RetroFontFace
	heading.TextSize = 10
	heading.TextColor3 = Theme.RetroColors.InkMuted
	heading.Text = "QUEST COMPLETE"
	heading.ZIndex = 7
	heading.Parent = face

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(16, 28)
	name.Size = UDim2.new(1, -32, 0, 16)
	name.BackgroundTransparency = 1
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.FontFace = Theme.RetroFontFace
	name.TextSize = 12
	name.TextColor3 = Theme.RetroColors.Rust
	name.Text = string.upper(title)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 7
	name.Parent = face

	local reward = Instance.new("TextLabel")
	reward.Position = UDim2.fromOffset(16, 46)
	reward.Size = UDim2.new(1, -32, 0, 12)
	reward.BackgroundTransparency = 1
	reward.TextXAlignment = Enum.TextXAlignment.Left
	reward.FontFace = Theme.RetroFontFace
	reward.TextSize = 9
	reward.TextColor3 = Theme.RetroColors.Ink
	reward.Text = string.upper(rewardText)
	reward.ZIndex = 7
	reward.Parent = face

	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.08),
	}):Play()
	task.delay(3.4, function()
		local away = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, -0.2),
		})
		away.Completed:Connect(function()
			card:Destroy()
		end)
		away:Play()
	end)
end

return QuestTrackerUI
