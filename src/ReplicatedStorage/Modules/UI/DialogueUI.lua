--!strict
-- Dialogue box: framed portrait, speaker name, typewriter-revealed text,
-- and up to a few option buttons (or a single continue affordance when a
-- node has no choices). Content is entirely driven by DialogueController
-- — this module only renders.
--
-- Same skin as the HUD, after the farm-sim reference Liam supplied:
-- LIGHT parchment panel, thick dark rim, cream inner bevel, dark ink
-- text. An earlier pass had it inverted (dark wood, light text), which
-- reads heavy and swallows the bottom of the screen.
--
-- Layout notes, since this box has more moving parts than the HUD:
--
--   * The portrait is framed and vertically centred in its own column,
--     with the text column beside it. Previously the portrait, name and
--     text were all positioned by hand against the panel with scale
--     offsets, so any change to the panel's proportions shifted them
--     against each other. Now the two columns are laid out from the
--     panel's padding and the text column carries its own list layout.
--   * Options sit BELOW the text rather than overlapping the panel's
--     bottom edge, and the panel is tall enough for three of them.
--   * A blinking arrow marks "line finished, press to continue", so the
--     player is never left wondering whether the box is still typing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local DialogueUI = {}

local CHARACTERS_PER_SECOND = 45

local screenGui: ScreenGui? = nil
local portraitLabel: TextLabel
local speakerLabel: TextLabel
local textLabel: TextLabel
local optionsFrame: Frame
local continueArrow: TextLabel
local typewriterGeneration = 0
local revealing = false
local fullLine = ""

-- Deterministic per-speaker portrait tint so the same character always
-- gets the same colour without a hand-authored lookup table. Saturation
-- and value are pulled toward the wood palette so the tints land inside
-- the retro range instead of reading as bright modern pastels.
local function colorForSpeaker(speaker: string): Color3
	local hash = 0
	for i = 1, #speaker do
		hash = (hash * 31 + string.byte(speaker, i)) % 359
	end
	return Color3.fromHSV(hash / 359, 0.45, 0.62)
end

local function capTextSize(label: TextLabel | TextButton, maxSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
end

-- Parchment surface with a thick dark rim and a cream inner bevel —
-- identical treatment to HudUI's panels, so the whole interface reads as
-- one set.
local function applyParchment(frame: GuiObject, cornerRadius: number, strokeThickness: number)
	frame.BackgroundColor3 = Color3.new(1, 1, 1) -- UIGradient multiplies, so white shows true colours
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cornerRadius)
	corner.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Theme.RetroColors.Parchment, Theme.RetroColors.ParchmentShadow)
	gradient.Rotation = 90
	gradient.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.RetroColors.WoodDark
	stroke.Thickness = strokeThickness
	stroke.Parent = frame

	local bevel = Instance.new("Frame")
	bevel.Name = "Bevel"
	bevel.BackgroundTransparency = 1
	bevel.Position = UDim2.fromOffset(2, 2)
	bevel.Size = UDim2.new(1, -4, 1, -4)
	bevel.ZIndex = frame.ZIndex
	bevel.Parent = frame
	local bevelCorner = Instance.new("UICorner")
	bevelCorner.CornerRadius = UDim.new(0, math.max(cornerRadius - 2, 2))
	bevelCorner.Parent = bevel
	local bevelStroke = Instance.new("UIStroke")
	bevelStroke.Color = Theme.RetroColors.WoodLight
	bevelStroke.Thickness = 2
	bevelStroke.Transparency = 0.35
	bevelStroke.Parent = bevel
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
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -24)
	-- Fills the width on a narrow window, caps out on a wide one. A fixed
	-- pixel width would overflow small screens and float lost in the
	-- middle of large ones.
	box.Size = UDim2.new(1, -48, 0, 220)
	box.Parent = gui
	applyParchment(box, 8, 4)

	local boxSize = Instance.new("UISizeConstraint")
	boxSize.MaxSize = Vector2.new(760, 220)
	boxSize.MinSize = Vector2.new(320, 220)
	boxSize.Parent = box

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.Parent = box

	-- Portrait column, fixed width so the text column's wrapping never
	-- depends on the speaker's name or the panel's proportions.
	local portraitFrame = Instance.new("Frame")
	portraitFrame.Name = "Portrait"
	portraitFrame.Size = UDim2.fromOffset(96, 96)
	portraitFrame.Position = UDim2.fromOffset(0, 0)
	portraitFrame.ZIndex = 2
	portraitFrame.Parent = box
	applyParchment(portraitFrame, 6, 3)

	portraitLabel = Instance.new("TextLabel")
	portraitLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	portraitLabel.Position = UDim2.fromScale(0.5, 0.5)
	portraitLabel.Size = UDim2.new(1, -12, 1, -12)
	portraitLabel.BorderSizePixel = 0
	portraitLabel.FontFace = Theme.RetroFontFace
	portraitLabel.TextScaled = true
	portraitLabel.TextColor3 = Theme.RetroColors.Parchment
	portraitLabel.TextStrokeColor3 = Theme.RetroColors.WoodDark
	portraitLabel.TextStrokeTransparency = 0
	portraitLabel.Text = "?"
	portraitLabel.ZIndex = 3
	portraitLabel.Parent = portraitFrame
	local portraitCorner = Instance.new("UICorner")
	portraitCorner.CornerRadius = UDim.new(0, 4)
	portraitCorner.Parent = portraitLabel
	capTextSize(portraitLabel, 44)

	-- Text column: name, a hairline rule, then the line itself.
	local textColumn = Instance.new("Frame")
	textColumn.Name = "TextColumn"
	textColumn.Position = UDim2.fromOffset(112, 0)
	textColumn.Size = UDim2.new(1, -112, 0, 96)
	textColumn.BackgroundTransparency = 1
	textColumn.ZIndex = 2
	textColumn.Parent = box

	speakerLabel = Instance.new("TextLabel")
	speakerLabel.Size = UDim2.new(1, 0, 0, 20)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	speakerLabel.TextScaled = true
	speakerLabel.FontFace = Theme.RetroFontFace
	-- Rust picks the name out from the body ink without needing a second
	-- panel behind it, which is one less box on a screen already full of
	-- them.
	speakerLabel.TextColor3 = Theme.RetroColors.Rust
	speakerLabel.ZIndex = 3
	speakerLabel.Parent = textColumn
	capTextSize(speakerLabel, 15)

	local rule = Instance.new("Frame")
	rule.Position = UDim2.fromOffset(0, 26)
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.BackgroundColor3 = Theme.RetroColors.WoodLight
	rule.BackgroundTransparency = 0.4
	rule.BorderSizePixel = 0
	rule.ZIndex = 3
	rule.Parent = textColumn

	textLabel = Instance.new("TextLabel")
	textLabel.Position = UDim2.fromOffset(0, 36)
	textLabel.Size = UDim2.new(1, 0, 1, -36)
	textLabel.BackgroundTransparency = 1
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.TextScaled = true
	textLabel.FontFace = Theme.RetroFontFace
	textLabel.TextColor3 = Theme.RetroColors.Ink
	textLabel.ZIndex = 3
	textLabel.Parent = textColumn
	capTextSize(textLabel, 14)

	-- Options run the full width under both columns, so long option text
	-- isn't squeezed into the narrower text column.
	optionsFrame = Instance.new("Frame")
	optionsFrame.Name = "Options"
	optionsFrame.Position = UDim2.fromOffset(0, 106)
	optionsFrame.Size = UDim2.new(1, 0, 1, -106)
	optionsFrame.BackgroundTransparency = 1
	optionsFrame.ZIndex = 2
	optionsFrame.Parent = box

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = optionsFrame

	-- Blinking "ready" arrow in the bottom-right corner. Only shown once
	-- the typewriter finishes, so it means exactly one thing.
	continueArrow = Instance.new("TextLabel")
	continueArrow.AnchorPoint = Vector2.new(1, 1)
	continueArrow.Position = UDim2.fromScale(1, 1)
	continueArrow.Size = UDim2.fromOffset(24, 24)
	continueArrow.BackgroundTransparency = 1
	-- Deliberately NOT the pixel font: PressStart2P is an ASCII-only face,
	-- so a triangle glyph in it renders as a missing-character box.
	continueArrow.Font = Enum.Font.GothamBold
	continueArrow.TextColor3 = Theme.RetroColors.Rust
	continueArrow.TextScaled = true
	continueArrow.Text = "\u{25BC}"
	continueArrow.Visible = false
	continueArrow.ZIndex = 4
	continueArrow.Parent = box
	capTextSize(continueArrow, 16)

	-- Driven from Heartbeat rather than a tween loop: one shared clock,
	-- nothing to cancel when a line changes, and it costs a sine per
	-- frame only while the box is open.
	RunService.Heartbeat:Connect(function()
		if gui.Enabled and continueArrow.Visible then
			continueArrow.TextTransparency = (math.sin(os.clock() * 5) + 1) * 0.25
		end
	end)
end

local function typewriterReveal(text: string)
	typewriterGeneration += 1
	local myGeneration = typewriterGeneration
	fullLine = text
	revealing = true
	textLabel.Text = ""
	continueArrow.Visible = false
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
			continueArrow.Visible = true
		end
	end)
end

-- Dumps the rest of the line instantly. Anyone who reads faster than 45
-- characters a second shouldn't have to wait for the animation, and a
-- typewriter with no skip is a well-known way to make dialogue drag.
local function finishReveal(): boolean
	if not revealing then
		return false
	end
	typewriterGeneration += 1
	revealing = false
	textLabel.Text = fullLine
	continueArrow.Visible = true
	return true
end

local function styleOptionButton(button: TextButton)
	button.AutoButtonColor = false
	button.FontFace = Theme.RetroFontFace
	button.TextColor3 = Theme.RetroColors.Ink
	button.ZIndex = 3
	applyParchment(button, 5, 2)
	capTextSize(button, 13)

	-- Explicit hover: AutoButtonColor's default darkening washes out
	-- against parchment, and a button that doesn't visibly respond reads
	-- as disabled.
	local stroke = button:FindFirstChildOfClass("UIStroke")
	button.MouseEnter:Connect(function()
		button.TextColor3 = Theme.RetroColors.Rust
		if stroke then
			stroke.Color = Theme.RetroColors.Rust
		end
	end)
	button.MouseLeave:Connect(function()
		button.TextColor3 = Theme.RetroColors.Ink
		if stroke then
			stroke.Color = Theme.RetroColors.WoodDark
		end
	end)
end

export type OptionDisplay = { text: string }

function DialogueUI.show(speaker: string, text: string, options: { OptionDisplay }, onSelect: (number) -> ())
	ensureBuilt()
	local gui = screenGui :: ScreenGui
	gui.Enabled = true
	speakerLabel.Text = string.upper(speaker)
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
		continueButton.Size = UDim2.new(1, 0, 0, 34)
		continueButton.Text = "CONTINUE"
		continueButton.TextScaled = true
		continueButton.Parent = optionsFrame
		styleOptionButton(continueButton)
		continueButton.Activated:Connect(function()
			-- First press finishes the line, second dismisses — a fast
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
		button.Size = UDim2.new(1, 0, 0, 34)
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
	if continueArrow then
		continueArrow.Visible = false
	end
end

return DialogueUI
