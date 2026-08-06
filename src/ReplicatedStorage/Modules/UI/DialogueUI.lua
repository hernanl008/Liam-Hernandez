--!strict
-- Dialogue box: pixel-art portrait, speaker name, typewriter-revealed
-- text, and up to a few option buttons (or a single continue button when
-- a node has no choices). Content is entirely driven by
-- DialogueController — this module only renders.
--
-- TEXT SIZING, which is the thing this box kept getting wrong: every
-- label uses a FIXED integer TextSize, never TextScaled. TextScaled
-- picks whatever fractional size fits the box, and PressStart2P at a
-- fractional size renders its glyph grid across half-pixels and turns to
-- mush — which is exactly what happened to the option buttons, whose
-- longer strings made TextScaled shrink them furthest of anything on
-- screen. A UITextSizeConstraint only caps the maximum; it does not stop
-- the size from being fractional, so capping was never going to fix it.
-- Fixed sizes, and the layout is built around them instead.
--
-- Portraits come from one shared sheet (PortraitSheet.lua, drawn by
-- tools/make_portrait_sheet.py), scaled by an integer factor for the
-- same reason. If the sheet isn't uploaded the box falls back to the
-- speaker's initial in a tinted box, so dialogue never breaks waiting on
-- art.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local AssetIds = require(Modules:WaitForChild("Shared"):WaitForChild("AssetIds"))
local PortraitSheet = require(Modules:WaitForChild("Shared"):WaitForChild("PortraitSheet"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local DialogueUI = {}

local CHARACTERS_PER_SECOND = 45

-- Integer multiple of PortraitSheet.CELL_SIZE (32 * 2), so the portrait
-- lands on whole source pixels.
local PORTRAIT_SCALE = 2
local PORTRAIT_SIZE = PortraitSheet.CELL_SIZE * PORTRAIT_SCALE

local NAME_TEXT_SIZE = 12
local BODY_TEXT_SIZE = 13
local OPTION_TEXT_SIZE = 12
local OPTION_HEIGHT = 32

local screenGui: ScreenGui? = nil
local portraitImage: ImageLabel
local portraitLetter: TextLabel
local speakerLabel: TextLabel
local textLabel: TextLabel
local optionsFrame: Frame
local continueArrow: TextLabel
local typewriterGeneration = 0
local revealing = false
local fullLine = ""

-- Deterministic per-speaker tint for the fallback letter box, so an
-- undrawn character is at least consistently coloured.
local function colorForSpeaker(speaker: string): Color3
	local hash = 0
	for i = 1, #speaker do
		hash = (hash * 31 + string.byte(speaker, i)) % 359
	end
	return Color3.fromHSV(hash / 359, 0.45, 0.62)
end

-- Parchment surface with a thick dark rim and a cream inner bevel — the
-- same treatment HudUI uses, so the whole interface reads as one set.
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

	-- Smaller than the previous pass, and sized to its contents rather
	-- than to a round number: portrait row + three option rows + padding.
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -20)
	box.Size = UDim2.new(1, -60, 0, 196)
	box.Parent = gui
	applyParchment(box, 8, 3)

	local boxSize = Instance.new("UISizeConstraint")
	boxSize.MaxSize = Vector2.new(620, 196)
	boxSize.MinSize = Vector2.new(300, 196)
	boxSize.Parent = box

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = box

	-- Portrait column, fixed width, so the text column's wrapping never
	-- depends on the speaker or the panel's proportions.
	local portraitFrame = Instance.new("Frame")
	portraitFrame.Name = "Portrait"
	portraitFrame.Size = UDim2.fromOffset(PORTRAIT_SIZE + 8, PORTRAIT_SIZE + 8)
	portraitFrame.Position = UDim2.fromOffset(0, 0)
	portraitFrame.ZIndex = 2
	portraitFrame.Parent = box
	applyParchment(portraitFrame, 5, 2)

	portraitImage = Instance.new("ImageLabel")
	portraitImage.AnchorPoint = Vector2.new(0.5, 0.5)
	portraitImage.Position = UDim2.fromScale(0.5, 0.5)
	portraitImage.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portraitImage.BackgroundTransparency = 1
	portraitImage.ScaleType = Enum.ScaleType.Stretch
	portraitImage.ResampleMode = Enum.ResamplerMode.Pixelated
	portraitImage.ImageRectSize = Vector2.new(PortraitSheet.CELL_SIZE, PortraitSheet.CELL_SIZE)
	portraitImage.Visible = false
	portraitImage.ZIndex = 3
	portraitImage.Parent = portraitFrame

	portraitLetter = Instance.new("TextLabel")
	portraitLetter.AnchorPoint = Vector2.new(0.5, 0.5)
	portraitLetter.Position = UDim2.fromScale(0.5, 0.5)
	portraitLetter.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portraitLetter.BorderSizePixel = 0
	portraitLetter.FontFace = Theme.RetroFontFace
	portraitLetter.TextSize = 28
	portraitLetter.TextColor3 = Theme.RetroColors.Parchment
	portraitLetter.TextStrokeColor3 = Theme.RetroColors.WoodDark
	portraitLetter.TextStrokeTransparency = 0
	portraitLetter.Text = "?"
	portraitLetter.Visible = false
	portraitLetter.ZIndex = 3
	portraitLetter.Parent = portraitFrame
	local letterCorner = Instance.new("UICorner")
	letterCorner.CornerRadius = UDim.new(0, 4)
	letterCorner.Parent = portraitLetter

	-- Text column beside the portrait.
	local columnX = PORTRAIT_SIZE + 20
	local textColumn = Instance.new("Frame")
	textColumn.Name = "TextColumn"
	textColumn.Position = UDim2.fromOffset(columnX, 0)
	textColumn.Size = UDim2.new(1, -columnX, 0, PORTRAIT_SIZE + 8)
	textColumn.BackgroundTransparency = 1
	textColumn.ZIndex = 2
	textColumn.Parent = box

	speakerLabel = Instance.new("TextLabel")
	speakerLabel.Size = UDim2.new(1, 0, 0, 14)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	speakerLabel.FontFace = Theme.RetroFontFace
	speakerLabel.TextSize = NAME_TEXT_SIZE
	-- Rust picks the name out from the body ink without needing a second
	-- panel behind it — one less box on a screen already full of them.
	speakerLabel.TextColor3 = Theme.RetroColors.Rust
	speakerLabel.ZIndex = 3
	speakerLabel.Parent = textColumn

	local rule = Instance.new("Frame")
	rule.Position = UDim2.fromOffset(0, 20)
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.BackgroundColor3 = Theme.RetroColors.WoodLight
	rule.BackgroundTransparency = 0.4
	rule.BorderSizePixel = 0
	rule.ZIndex = 3
	rule.Parent = textColumn

	textLabel = Instance.new("TextLabel")
	textLabel.Position = UDim2.fromOffset(0, 28)
	textLabel.Size = UDim2.new(1, 0, 1, -28)
	textLabel.BackgroundTransparency = 1
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.FontFace = Theme.RetroFontFace
	textLabel.TextSize = BODY_TEXT_SIZE
	textLabel.LineHeight = 1.35 -- pixel faces sit tight by default and run together when wrapped
	textLabel.TextColor3 = Theme.RetroColors.Ink
	textLabel.ZIndex = 3
	textLabel.Parent = textColumn

	-- Options run the full width under both columns, so long option text
	-- isn't squeezed into the narrower text column.
	optionsFrame = Instance.new("Frame")
	optionsFrame.Name = "Options"
	optionsFrame.Position = UDim2.fromOffset(0, PORTRAIT_SIZE + 18)
	optionsFrame.Size = UDim2.new(1, 0, 1, -(PORTRAIT_SIZE + 18))
	optionsFrame.BackgroundTransparency = 1
	optionsFrame.ZIndex = 2
	optionsFrame.Parent = box

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = optionsFrame

	-- Blinking "ready" arrow, bottom right. Shown only once the
	-- typewriter finishes, so it means exactly one thing.
	continueArrow = Instance.new("TextLabel")
	continueArrow.AnchorPoint = Vector2.new(1, 1)
	continueArrow.Position = UDim2.fromScale(1, 1)
	continueArrow.Size = UDim2.fromOffset(20, 20)
	continueArrow.BackgroundTransparency = 1
	-- Deliberately NOT the pixel font: PressStart2P is an ASCII-only face,
	-- so a triangle glyph in it renders as a missing-character box.
	continueArrow.Font = Enum.Font.GothamBold
	continueArrow.TextSize = 16
	continueArrow.TextColor3 = Theme.RetroColors.Rust
	continueArrow.Text = "\u{25BC}"
	continueArrow.Visible = false
	continueArrow.ZIndex = 4
	continueArrow.Parent = box

	-- Driven from Heartbeat rather than a tween loop: one shared clock,
	-- nothing to cancel when a line changes, and it costs a sine per
	-- frame only while the box is open.
	RunService.Heartbeat:Connect(function()
		if gui.Enabled and continueArrow.Visible then
			continueArrow.TextTransparency = (math.sin(os.clock() * 5) + 1) * 0.25
		end
	end)
end

local function setPortrait(speaker: string)
	local sheetId = AssetIds.sprite("portrait_sheet")
	if sheetId ~= "rbxassetid://0" then
		portraitImage.Image = sheetId
		portraitImage.ImageRectOffset = PortraitSheet.rectOffsetFor(speaker)
		portraitImage.Visible = true
		portraitLetter.Visible = false
		return
	end
	-- Not uploaded yet: the initial in a tinted box. Same "keep the
	-- fallback until the replacement is proven" rule as the sprite
	-- character and the fish standees.
	portraitImage.Visible = false
	portraitLetter.Visible = true
	portraitLetter.Text = string.upper(string.sub(speaker, 1, 1))
	portraitLetter.BackgroundColor3 = colorForSpeaker(speaker)
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
	button.TextSize = OPTION_TEXT_SIZE
	button.TextColor3 = Theme.RetroColors.Ink
	-- Truncate rather than wrap or shrink: a fixed size can't shrink to
	-- fit, and a wrapped two-line option would break the row height the
	-- layout is built on. Options are short by design.
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.ZIndex = 3
	applyParchment(button, 5, 2)

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
	setPortrait(speaker)
	typewriterReveal(text)

	for _, child in optionsFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	if #options == 0 then
		local continueButton = Instance.new("TextButton")
		continueButton.Size = UDim2.new(1, 0, 0, OPTION_HEIGHT)
		continueButton.Text = "CONTINUE"
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
		button.Size = UDim2.new(1, 0, 0, OPTION_HEIGHT)
		button.Text = option.text
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
