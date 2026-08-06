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

local NAME_TEXT_SIZE = 11
local BODY_TEXT_SIZE = 12
local OPTION_TEXT_SIZE = 11
local OPTION_HEIGHT = 28
local OPTION_GAP = 6

-- Every measurement the box's height is built from, in one place, so
-- heightFor() below and the layout can't drift apart.
local PAD = 14
local PORTRAIT_PAD = 6 -- frame inset around the portrait image
local PORTRAIT_BLOCK = PortraitSheet.CELL_SIZE * 2 + 6 -- portrait image plus its frame inset
local COLUMN_GAP = 16

-- Height of the portrait/text row. Taller than the portrait itself, and
-- the number is measured rather than guessed: the longest line in
-- DialogueData is 106 characters, PressStart2P is monospace at roughly
-- TextSize per character, and the text column is about 430px wide at the
-- box's capped width — so a worst-case line wraps to four rows. Four
-- rows at BODY_TEXT_SIZE * 1.3 leading is 64px, plus 28px for the name
-- and its rule. Sizing this to the portrait instead left 42px of text
-- area and silently clipped the longest third of the script.
local TOP_ROW = 92

local screenGui: ScreenGui? = nil
local boxFrame: Frame
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

-- Layered frame: shadow, dark rim, bright ring, parchment face. Same
-- construction as HudUI's panels, so the whole interface reads as one
-- set of objects rather than a pile of bordered rectangles. A single
-- rectangle with a UIStroke -- which is what this was -- is flat no
-- matter what colour the stroke is, because a stroke can only sit
-- outside the shape and never gives you the bright band BETWEEN the
-- dark edge and the face.
--
-- Returns the FACE to parent content to, and keeps working on a
-- TextButton (the option rows) as well as a Frame.
local function applyFramed(target: GuiObject, radius: number): Frame
	target.BackgroundColor3 = Theme.RetroColors.WoodDark
	target.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = target

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, -5, 1, -5)
	ring.BackgroundColor3 = Theme.RetroColors.WoodLight
	ring.BorderSizePixel = 0
	ring.ZIndex = target.ZIndex
	ring.Parent = target
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0, math.max(radius - 2, 2))
	ringCorner.Parent = ring

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.new(1, -5, 1, -5)
	-- White, so the gradient shows its true colours: UIGradient multiplies
	-- against BackgroundColor3 rather than replacing it.
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = target.ZIndex
	face.Parent = ring
	local faceCorner = Instance.new("UICorner")
	faceCorner.CornerRadius = UDim.new(0, math.max(radius - 4, 2))
	faceCorner.Parent = face
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Theme.RetroColors.Parchment, Theme.RetroColors.ParchmentShadow)
	gradient.Rotation = 90
	gradient.Parent = face

	return face
end

-- Drop shadow behind `target`, sized and positioned to match it. Sibling
-- rather than child so it can sit UNDER the panel it belongs to.
local function addShadow(target: GuiObject, radius: number)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = target.AnchorPoint
	shadow.Position = target.Position + UDim2.fromOffset(0, 3)
	shadow.Size = target.Size
	shadow.BackgroundColor3 = Color3.fromRGB(38, 22, 12)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.ZIndex = target.ZIndex - 1
	shadow.Parent = target.Parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = shadow

	-- The box resizes per node (heightFor), so the shadow has to follow.
	target:GetPropertyChangedSignal("Size"):Connect(function()
		shadow.Size = target.Size
	end)
end

-- Total box height for `optionCount` rows: padding, the portrait/text
-- row, then one row per option. Every term is a named constant so the
-- box can never end up a few pixels off from what it actually contains.
local function heightFor(optionCount: number): number
	local optionsHeight = 0
	if optionCount > 0 then
		optionsHeight = optionCount * OPTION_HEIGHT + (optionCount - 1) * OPTION_GAP + PAD
	end
	return PAD * 2 + TOP_ROW + optionsHeight
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

	-- Height is set per line by show(), from heightFor() below. A fixed
	-- height meant a node with one CONTINUE button reserved room for
	-- three options and left a slab of empty parchment under the text —
	-- the single biggest reason the box looked oversized. Width is capped
	-- narrower than before too: long measures are harder to read, and the
	-- box has no business spanning the screen.
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -22)
	box.Size = UDim2.new(1, -80, 0, 150)
	box.ZIndex = 2
	box.Parent = gui
	addShadow(box, 8)
	local boxFace = applyFramed(box, 8)

	local boxSize = Instance.new("UISizeConstraint")
	boxSize.MaxSize = Vector2.new(540, 400)
	boxSize.MinSize = Vector2.new(300, 100)
	boxSize.Parent = box

	-- Padding goes on the FACE, since that is what content is parented to.
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, PAD)
	padding.PaddingRight = UDim.new(0, PAD)
	padding.PaddingTop = UDim.new(0, PAD)
	padding.PaddingBottom = UDim.new(0, PAD)
	padding.Parent = boxFace
	boxFrame = box

	-- Portrait column, fixed width, so the text column's wrapping never
	-- depends on the speaker or the panel's proportions.
	local portraitFrame = Instance.new("Frame")
	portraitFrame.Name = "Portrait"
	portraitFrame.Size = UDim2.fromOffset(PORTRAIT_BLOCK, PORTRAIT_BLOCK)
	-- Centred in the row, which is taller than the portrait.
	portraitFrame.AnchorPoint = Vector2.new(0, 0.5)
	portraitFrame.Position = UDim2.fromOffset(0, TOP_ROW // 2)
	portraitFrame.ZIndex = 3
	portraitFrame.Parent = boxFace
	local portraitFace = applyFramed(portraitFrame, 5)

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
	portraitImage.Parent = portraitFace

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
	portraitLetter.Parent = portraitFace
	local letterCorner = Instance.new("UICorner")
	letterCorner.CornerRadius = UDim.new(0, 4)
	letterCorner.Parent = portraitLetter

	-- Text column beside the portrait.
	local columnX = PORTRAIT_BLOCK + COLUMN_GAP
	local textColumn = Instance.new("Frame")
	textColumn.Name = "TextColumn"
	textColumn.Position = UDim2.fromOffset(columnX, 0)
	textColumn.Size = UDim2.new(1, -columnX, 0, TOP_ROW)
	textColumn.BackgroundTransparency = 1
	textColumn.ZIndex = 2
	textColumn.Parent = boxFace

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
	textLabel.LineHeight = 1.3 -- pixel faces sit tight by default and run together when wrapped
	textLabel.TextColor3 = Theme.RetroColors.Ink
	textLabel.ZIndex = 3
	textLabel.Parent = textColumn

	-- Options run the full width under both columns, so long option text
	-- isn't squeezed into the narrower text column.
	optionsFrame = Instance.new("Frame")
	optionsFrame.Name = "Options"
	-- Anchored to the BOTTOM of the padded area rather than offset from
	-- the top, so it stays put as the box height changes per node.
	optionsFrame.AnchorPoint = Vector2.new(0, 1)
	optionsFrame.Position = UDim2.fromScale(0, 1)
	optionsFrame.Size = UDim2.new(1, 0, 0, 0) -- height set in show()
	optionsFrame.BackgroundTransparency = 1
	optionsFrame.ZIndex = 2
	optionsFrame.Parent = boxFace

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, OPTION_GAP)
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
	continueArrow.Parent = boxFace

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

-- Builds one framed option row and returns the TextButton to connect.
--
-- A row is a framed Frame with a TRANSPARENT TextButton laid over its
-- face, rather than a TextButton styled directly. The frame helper
-- nests a face inside its target, and a face parented to a TextButton
-- would cover that button's own text -- Roblox draws a widget's text at
-- the widget's ZIndex, so a child frame at the same depth wins. Putting
-- the button on top instead keeps the layers in the right order and
-- leaves the button's whole area clickable.
local function makeOptionRow(text: string, layoutOrder: number): TextButton
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, OPTION_HEIGHT)
	row.LayoutOrder = layoutOrder
	row.ZIndex = 4
	row.Parent = optionsFrame
	local face = applyFramed(row, 5)

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Text = text
	button.FontFace = Theme.RetroFontFace
	button.TextSize = OPTION_TEXT_SIZE
	button.TextColor3 = Theme.RetroColors.Ink
	-- Truncate rather than wrap or shrink: a fixed size can't shrink to
	-- fit, and a wrapped two-line option would break the row height the
	-- layout is built on. Options are short by design.
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.ZIndex = 6
	button.Parent = face

	-- Explicit hover: AutoButtonColor's default darkening washes out
	-- against parchment, and a button that doesn't visibly respond reads
	-- as disabled. Lighting the ring is what makes the whole row feel
	-- picked up rather than just the words changing colour.
	local ring = row:FindFirstChild("Ring")
	button.MouseEnter:Connect(function()
		button.TextColor3 = Theme.RetroColors.Rust
		if ring and ring:IsA("Frame") then
			ring.BackgroundColor3 = Theme.RetroColors.Bronze
		end
	end)
	button.MouseLeave:Connect(function()
		button.TextColor3 = Theme.RetroColors.Ink
		if ring and ring:IsA("Frame") then
			ring.BackgroundColor3 = Theme.RetroColors.WoodLight
		end
	end)

	return button
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
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- One CONTINUE button when a node offers no choices, so the box is
	-- never taller than what it holds.
	local rowCount = if #options == 0 then 1 else #options
	boxFrame.Size = UDim2.new(1, -80, 0, heightFor(rowCount))
	optionsFrame.Size = UDim2.new(1, 0, 0, rowCount * OPTION_HEIGHT + (rowCount - 1) * OPTION_GAP)

	if #options == 0 then
		local continueButton = makeOptionRow("CONTINUE", 1)
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
		local button = makeOptionRow(option.text, i)
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
