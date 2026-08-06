--!strict
-- Dialogue box: portrait tile, speaker nameplate, typewriter-revealed
-- text, and up to a few option buttons (or a single continue button when
-- a node has no choices). Content is entirely driven by
-- DialogueController — this module only renders.
--
-- Retro-medieval skin (GDD.md §14), matching the fishing UI: a parchment
-- page in a thick wood frame, pixel font, dark ink on light ground.
--
-- Two things the pixel font forces that the old anime skin didn't need:
--
--   * TextScaled is capped by a UITextSizeConstraint everywhere. A
--     blocky pixel face scaled to arbitrary sizes lands on fractional
--     glyph pixels and goes soft — the same failure the catch showcase
--     had. Capped, it scales DOWN on small screens but never blows up
--     past its clean size.
--   * Ink on parchment, not light text on a dark panel. The anime theme's
--     convention doesn't survive a heavy pixel face; it smears.

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
local revealing = false
local fullLine = ""

-- Deterministic per-speaker portrait tint so the same character always
-- gets the same color without needing a hand-authored lookup table.
-- Saturation and value are pulled toward the wood palette so the tints
-- sit inside the retro range instead of reading as bright anime pastels.
local function colorForSpeaker(speaker: string): Color3
	local hash = 0
	for i = 1, #speaker do
		hash = (hash * 31 + string.byte(speaker, i)) % 359
	end
	return Color3.fromHSV(hash / 359, 0.42, 0.68)
end

local function capTextSize(label: TextLabel, maxSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
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
	box.Name = "Box"
	box.Size = UDim2.fromScale(0.62, 0.3)
	box.Position = UDim2.fromScale(0.19, 0.65)
	box.BorderSizePixel = 0
	box.Parent = gui
	Theme.applyRetroPanel(box)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = box

	-- Square portrait tile, not the old circle: a round frame reads as
	-- modern UI chrome and fights everything else on screen here.
	local portraitHolder = Instance.new("Frame")
	portraitHolder.Name = "Portrait"
	portraitHolder.Size = UDim2.fromScale(0.13, 0.46)
	portraitHolder.Position = UDim2.fromScale(0, 0.04)
	portraitHolder.BackgroundColor3 = Theme.RetroColors.WoodDark
	portraitHolder.BorderSizePixel = 0
	portraitHolder.Parent = box
	local holderCorner = Instance.new("UICorner")
	holderCorner.CornerRadius = UDim.new(0, 4)
	holderCorner.Parent = portraitHolder

	portraitLabel = Instance.new("TextLabel")
	portraitLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	portraitLabel.Position = UDim2.fromScale(0.5, 0.5)
	portraitLabel.Size = UDim2.new(1, -6, 1, -6)
	portraitLabel.BorderSizePixel = 0
	portraitLabel.FontFace = Theme.RetroFontFace
	portraitLabel.TextScaled = true
	portraitLabel.TextColor3 = Theme.RetroColors.Parchment
	portraitLabel.TextStrokeColor3 = Theme.RetroColors.WoodDark
	portraitLabel.TextStrokeTransparency = 0
	portraitLabel.Text = "?"
	portraitLabel.Parent = portraitHolder
	local portraitCorner = Instance.new("UICorner")
	portraitCorner.CornerRadius = UDim.new(0, 3)
	portraitCorner.Parent = portraitLabel
	capTextSize(portraitLabel, 40)

	-- Nameplate: a small wood strip the name sits on, rather than bare
	-- text floating on the parchment. Gives the speaker the same "carved
	-- label" treatment the catch card's plaque uses.
	local namePlate = Instance.new("Frame")
	namePlate.Name = "NamePlate"
	namePlate.Size = UDim2.fromScale(0.5, 0.17)
	namePlate.Position = UDim2.fromScale(0.16, 0.02)
	namePlate.BackgroundColor3 = Theme.RetroColors.WoodDark
	namePlate.BorderSizePixel = 0
	namePlate.Parent = box
	local plateCorner = Instance.new("UICorner")
	plateCorner.CornerRadius = UDim.new(0, 4)
	plateCorner.Parent = namePlate
	local plateStroke = Instance.new("UIStroke")
	plateStroke.Color = Theme.RetroColors.WoodLight
	plateStroke.Thickness = 2
	plateStroke.Parent = namePlate

	speakerLabel = Instance.new("TextLabel")
	speakerLabel.AnchorPoint = Vector2.new(0, 0.5)
	speakerLabel.Position = UDim2.new(0, 8, 0.5, 0)
	speakerLabel.Size = UDim2.new(1, -16, 1, -8)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	speakerLabel.TextScaled = true
	speakerLabel.Parent = namePlate
	Theme.styleRetroHeader(speakerLabel, Theme.RetroColors.Parchment)
	capTextSize(speakerLabel, 15)

	textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(0.82, 0.4)
	textLabel.Position = UDim2.fromScale(0.16, 0.22)
	textLabel.BackgroundTransparency = 1
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.TextScaled = true
	textLabel.Parent = box
	Theme.styleRetroBody(textLabel, Theme.RetroColors.Ink)
	capTextSize(textLabel, 15)

	optionsFrame = Instance.new("Frame")
	optionsFrame.Size = UDim2.fromScale(1, 0.32)
	optionsFrame.Position = UDim2.fromScale(0, 0.66)
	optionsFrame.BackgroundTransparency = 1
	optionsFrame.Parent = box

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = optionsFrame
end

local function typewriterReveal(text: string)
	typewriterGeneration += 1
	local myGeneration = typewriterGeneration
	fullLine = text
	revealing = true
	textLabel.Text = ""
	task.spawn(function()
		for i = 1, #text do
			if myGeneration ~= typewriterGeneration then
				return -- a newer line started, abandon this one
			end
			textLabel.Text = string.sub(text, 1, i)
			task.wait(1 / CHARACTERS_PER_SECOND)
		end
		if myGeneration == typewriterGeneration then
			revealing = false
		end
	end)
end

-- Dumps the rest of the line instantly. Anyone who reads faster than 45
-- characters a second shouldn't have to wait for the animation, and a
-- typewriter with no skip is a well-known way to make dialogue feel slow.
local function finishReveal(): boolean
	if not revealing then
		return false
	end
	typewriterGeneration += 1
	revealing = false
	textLabel.Text = fullLine
	return true
end

local function styleOptionButton(button: TextButton)
	button.BackgroundColor3 = Theme.RetroColors.WoodMid
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.FontFace = Theme.RetroFontFace
	button.TextColor3 = Theme.RetroColors.Parchment
	Theme.applyRetroCard(button, 4)
	capTextSize(button, 14)

	-- Hover lightens the wood and the border. AutoButtonColor is off
	-- because its default darkening washes out against this palette.
	local stroke = button:FindFirstChildOfClass("UIStroke")
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Theme.RetroColors.WoodLight
		if stroke then
			stroke.Color = Theme.RetroColors.Bronze
		end
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Theme.RetroColors.WoodMid
		if stroke then
			stroke.Color = Theme.RetroColors.WoodMid
		end
	end)
end

export type OptionDisplay = { text: string }

function DialogueUI.show(speaker: string, text: string, options: { OptionDisplay }, onSelect: (number) -> ())
	ensureBuilt()
	local gui = screenGui :: ScreenGui
	gui.Enabled = true
	speakerLabel.Text = speaker
	portraitLabel.Text = string.upper(string.sub(speaker, 1, 1))
	portraitLabel.BackgroundColor3 = colorForSpeaker(speaker)
	typewriterReveal(text)

	for _, child in optionsFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	if #options == 0 then
		local continueButton = Instance.new("TextButton")
		continueButton.Size = UDim2.fromScale(1, 0.32)
		continueButton.Text = "CONTINUE"
		continueButton.TextScaled = true
		continueButton.Parent = optionsFrame
		styleOptionButton(continueButton)
		continueButton.Activated:Connect(function()
			-- First press finishes the line, second dismisses — so a fast
			-- reader never loses text by pressing ahead.
			if finishReveal() then
				return
			end
			DialogueUI.hide()
		end)
		return
	end

	for i, option in options do
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(1, 0.32)
		button.Text = option.text
		button.TextScaled = true
		button.LayoutOrder = i
		button.Parent = optionsFrame
		styleOptionButton(button)
		button.Activated:Connect(function()
			if finishReveal() then
				return
			end
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
