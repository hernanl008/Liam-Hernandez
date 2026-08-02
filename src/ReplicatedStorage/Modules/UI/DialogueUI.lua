--!strict
-- Dialogue box: portrait circle, speaker name, typewriter-revealed text,
-- and up to a few option buttons (or a single "..." continue button when
-- a node has no choices). Content is entirely driven by DialogueController
-- — this module only renders. Styled via Theme.lua (GDD.md §14).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local DialogueUI = {}

local CHARACTERS_PER_SECOND = 45

local screenGui: ScreenGui? = nil
local portraitLabel: TextLabel
local speakerLabel: TextLabel
local textLabel: TextLabel
local optionsFrame: Frame
local typewriterGeneration = 0

-- Deterministic per-speaker portrait tint so the same character always
-- gets the same color without needing a hand-authored lookup table.
local function colorForSpeaker(speaker: string): Color3
	local hash = 0
	for i = 1, #speaker do
		hash = (hash * 31 + string.byte(speaker, i)) % 359
	end
	return Color3.fromHSV(hash / 359, 0.55, 0.85)
end

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DialogueUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	local box = Instance.new("Frame")
	box.Size = UDim2.fromScale(0.62, 0.3)
	box.Position = UDim2.fromScale(0.19, 0.65)
	box.BorderSizePixel = 0
	box.Parent = gui
	Theme.applyPanel(box)

	portraitLabel = Instance.new("TextLabel")
	portraitLabel.Size = UDim2.fromScale(0.12, 0.5)
	portraitLabel.Position = UDim2.fromScale(0.02, 0.06)
	portraitLabel.Font = Theme.Fonts.Header
	portraitLabel.TextScaled = true
	portraitLabel.TextColor3 = Color3.fromRGB(30, 20, 25)
	portraitLabel.Text = "?"
	portraitLabel.Parent = box
	local portraitCorner = Instance.new("UICorner")
	portraitCorner.CornerRadius = UDim.new(1, 0)
	portraitCorner.Parent = portraitLabel
	local portraitStroke = Instance.new("UIStroke")
	portraitStroke.Color = Theme.Colors.AccentGold
	portraitStroke.Thickness = 2
	portraitStroke.Parent = portraitLabel

	speakerLabel = Instance.new("TextLabel")
	speakerLabel.Size = UDim2.fromScale(0.78, 0.18)
	speakerLabel.Position = UDim2.fromScale(0.18, 0.04)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	speakerLabel.TextScaled = true
	speakerLabel.Parent = box
	Theme.styleHeader(speakerLabel)

	textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(0.78, 0.42)
	textLabel.Position = UDim2.fromScale(0.18, 0.24)
	textLabel.BackgroundTransparency = 1
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.TextScaled = true
	textLabel.Parent = box
	Theme.styleBody(textLabel)

	optionsFrame = Instance.new("Frame")
	optionsFrame.Size = UDim2.fromScale(0.95, 0.32)
	optionsFrame.Position = UDim2.fromScale(0.025, 0.66)
	optionsFrame.BackgroundTransparency = 1
	optionsFrame.Parent = box

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = optionsFrame
end

local function typewriterReveal(fullText: string)
	typewriterGeneration += 1
	local myGeneration = typewriterGeneration
	textLabel.Text = ""
	task.spawn(function()
		for i = 1, #fullText do
			if myGeneration ~= typewriterGeneration then
				return -- a newer line started, abandon this one
			end
			textLabel.Text = string.sub(fullText, 1, i)
			task.wait(1 / CHARACTERS_PER_SECOND)
		end
	end)
end

local function styleOptionButton(button: TextButton)
	button.BackgroundColor3 = Theme.Colors.ButtonFill
	button.TextColor3 = Theme.Colors.TextPrimary
	button.Font = Theme.Fonts.BodyBold
	Theme.applyCard(button, 6)
end

export type OptionDisplay = { text: string }

function DialogueUI.show(speaker: string, text: string, options: { OptionDisplay }, onSelect: (number) -> ())
	ensureBuilt()
	local gui = screenGui :: ScreenGui
	gui.Enabled = true
	speakerLabel.Text = speaker
	portraitLabel.Text = string.sub(speaker, 1, 1)
	portraitLabel.BackgroundColor3 = colorForSpeaker(speaker)
	typewriterReveal(text)

	for _, child in optionsFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	if #options == 0 then
		local continueButton = Instance.new("TextButton")
		continueButton.Size = UDim2.fromScale(1, 0.3)
		continueButton.Text = "..."
		continueButton.TextScaled = true
		continueButton.Parent = optionsFrame
		styleOptionButton(continueButton)
		continueButton.Activated:Connect(function()
			DialogueUI.hide()
		end)
		return
	end

	for i, option in options do
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(1, 0.3)
		button.Text = option.text
		button.TextScaled = true
		button.LayoutOrder = i
		button.Parent = optionsFrame
		styleOptionButton(button)
		button.Activated:Connect(function()
			onSelect(i)
		end)
	end
end

function DialogueUI.hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return DialogueUI
