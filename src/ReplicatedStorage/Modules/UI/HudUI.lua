--!strict
-- Persistent HUD: season/day, clock and purse. Always visible, no
-- toggle.
--
-- LAYERED FRAMES, which is the whole point of this file's look. Earlier
-- passes drew each panel as one rectangle with a UIStroke and a faint
-- inner line, and it read as flat and generic no matter how the contents
-- were arranged — rearranging them (side-by-side, then a tall stacked
-- sign) changed nothing, because the layout was never the problem. What
-- makes the farm-sim frames Liam referenced look carved is that they are
-- several nested shapes: a dark outer rim, a bright metal ring inside
-- it, then the parchment face, with a shadow underneath lifting the
-- whole thing off the world. Four cheap Frames per panel, and it is the
-- difference between "a box with a border" and "an object".
--
-- Corner clusters, not a full-width bar: a strip across the top of the
-- screen is the shape of a web toolbar and eats play area at every
-- resolution. Everything lives top right; the rest of the screen stays
-- the world's.
--
-- Skill levels used to sit as chips in the top-left corner. They are
-- gone: a level that changes a few times an hour does not earn permanent
-- screen space, they collided with Roblox's chat window, and the numbers
-- are already on the skill tree screen. Level-ups still announce
-- themselves when they happen (ProgressFeedback).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local HudUI = {}

local DATE_WIDTH = 200
local CLOCK_WIDTH = 132
local PANEL_HEIGHT = 40
local PANEL_GAP = 8
local MARGIN = 12

local goldLabel: TextLabel
local dayLabel: TextLabel
local clockLabel: TextLabel
local goldFill: Frame
local built = false

-- Builds one framed panel and returns its FACE — the parchment surface
-- callers parent content to. The rim and ring are decoration; nothing
-- outside needs a handle on them.
local function makePanel(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	-- Shadow. Not a stroke or a gradient: a second rounded rectangle
	-- offset downward, dark and mostly transparent. Cheap, and it is what
	-- stops a light panel lying flat against a bright field.
	local shadow = Instance.new("Frame")
	shadow.Size = size
	shadow.Position = position + UDim2.fromOffset(0, 3)
	shadow.AnchorPoint = anchor
	shadow.BackgroundColor3 = Color3.fromRGB(38, 22, 12)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = parent
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 9)
	shadowCorner.Parent = shadow

	-- Outer rim: the dark carved edge.
	local rim = Instance.new("Frame")
	rim.Size = size
	rim.Position = position
	rim.AnchorPoint = anchor
	rim.BackgroundColor3 = Theme.RetroColors.WoodDark
	rim.BorderSizePixel = 0
	rim.ZIndex = 2
	rim.Parent = parent
	local rimCorner = Instance.new("UICorner")
	rimCorner.CornerRadius = UDim.new(0, 9)
	rimCorner.Parent = rim

	-- Metal ring: the bright band between rim and face. This is the layer
	-- that reads as gilded, and it is the one a UIStroke can never give
	-- you, because a stroke only ever sits outside the shape.
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, -6, 1, -6)
	ring.BackgroundColor3 = Theme.RetroColors.WoodLight
	ring.BorderSizePixel = 0
	ring.ZIndex = 3
	ring.Parent = rim
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0, 7)
	ringCorner.Parent = ring

	-- Parchment face, where content goes.
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.new(1, -6, 1, -6)
	-- White, so the gradient shows its true colours: UIGradient multiplies
	-- against BackgroundColor3 rather than replacing it.
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = 4
	face.Parent = ring
	local faceCorner = Instance.new("UICorner")
	faceCorner.CornerRadius = UDim.new(0, 5)
	faceCorner.Parent = face
	local faceGradient = Instance.new("UIGradient")
	faceGradient.Color = ColorSequence.new(Theme.RetroColors.Parchment, Theme.RetroColors.ParchmentShadow)
	faceGradient.Rotation = 90
	faceGradient.Parent = face

	return face
end

local function makeLabel(parent: Frame, color: Color3, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -14, 1, -8)
	label.BackgroundTransparency = 1
	-- FIXED integer size, never TextScaled: TextScaled picks whatever
	-- fractional size fits, and PressStart2P at a fractional size renders
	-- its glyph grid across half-pixels and mushes.
	label.TextSize = textSize
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.FontFace = Theme.RetroFontFace
	label.TextColor3 = color
	label.Text = ""
	label.ZIndex = 5
	label.Parent = parent
	return label
end

local function buildPurse(gui: ScreenGui, top: number)
	local width = DATE_WIDTH + PANEL_GAP + CLOCK_WIDTH
	local face = makePanel(gui, UDim2.fromOffset(width, 38), UDim2.new(1, -MARGIN, 0, top), Vector2.new(1, 0))

	local coin = Instance.new("Frame")
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 10, 0.5, -2)
	coin.Size = UDim2.fromOffset(20, 20)
	coin.BackgroundColor3 = Theme.RetroColors.Bronze
	coin.BorderSizePixel = 0
	coin.ZIndex = 5
	coin.Parent = face
	local coinCorner = Instance.new("UICorner")
	coinCorner.CornerRadius = UDim.new(1, 0)
	coinCorner.Parent = coin
	local coinStroke = Instance.new("UIStroke")
	coinStroke.Color = Theme.RetroColors.WoodDark
	coinStroke.Thickness = 2
	coinStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	coinStroke.Parent = coin

	local coinLabel = Instance.new("TextLabel")
	coinLabel.Size = UDim2.fromScale(1, 1)
	coinLabel.BackgroundTransparency = 1
	coinLabel.FontFace = Theme.RetroFontFace
	coinLabel.TextColor3 = Theme.RetroColors.WoodDark
	coinLabel.TextSize = 10
	coinLabel.Text = "G"
	coinLabel.ZIndex = 6
	coinLabel.Parent = coin

	goldLabel = Instance.new("TextLabel")
	goldLabel.AnchorPoint = Vector2.new(1, 0.5)
	goldLabel.Position = UDim2.new(1, -12, 0.5, -2)
	goldLabel.Size = UDim2.fromOffset(140, 20)
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextXAlignment = Enum.TextXAlignment.Right
	goldLabel.TextSize = 17
	goldLabel.FontFace = Theme.RetroFontFace
	-- Rust rather than ink: the reference picks the money out in red, and
	-- it is the one number on screen worth finding at a glance.
	goldLabel.TextColor3 = Theme.RetroColors.Rust
	goldLabel.Text = "0"
	goldLabel.ZIndex = 5
	goldLabel.Parent = face

	-- Progress toward the next 1,000g, as a thin line rather than the row
	-- of discrete pips this started as. At 100g none of those pips lit, so
	-- the HUD showed eight empty boxes — which reads as content that
	-- failed to load, not as a meter that is nearly empty. A partly-filled
	-- line still obviously reads as a line.
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -5)
	track.Size = UDim2.new(1, -24, 0, 3)
	track.BackgroundColor3 = Theme.RetroColors.ParchmentShadow
	track.BorderSizePixel = 0
	track.ZIndex = 5
	track.Parent = face
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	goldFill = Instance.new("Frame")
	goldFill.Size = UDim2.fromScale(0, 1)
	goldFill.BackgroundColor3 = Theme.RetroColors.Bronze
	goldFill.BorderSizePixel = 0
	goldFill.ZIndex = 6
	goldFill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = goldFill
end

-- How far down the HUD has to start to clear Roblox's own topbar (the
-- chat, player-list and menu buttons). A hard-coded margin doesn't work:
-- the inset differs between desktop, mobile and consoles, and again on
-- devices with a notch. GuiService.TopbarInset reports the real reserved
-- rectangle, so ask for it — with a fallback for any client where the
-- property doesn't exist.
local function topbarOffset(): number
	local ok, inset = pcall(function()
		return GuiService.TopbarInset
	end)
	if ok and inset then
		return inset.Height + 8
	end
	return 44
end

local function ensureBuilt()
	if built then
		return
	end
	built = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "HudUI"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local top = topbarOffset()

	-- Date and clock side by side, purse spanning both underneath. Two
	-- readable panels beat the tall stacked sign this briefly became: that
	-- put three centred rows of the same monospace face in a column, which
	-- reads as a form, and its translucent middle band muddied against the
	-- parchment instead of dividing it.
	local dateFace = makePanel(
		gui,
		UDim2.fromOffset(DATE_WIDTH, PANEL_HEIGHT),
		UDim2.new(1, -(MARGIN + CLOCK_WIDTH + PANEL_GAP), 0, top),
		Vector2.new(1, 0)
	)
	dayLabel = makeLabel(dateFace, Theme.RetroColors.Ink, 14)
	dayLabel.Text = "SPRING 1"

	local clockFace = makePanel(
		gui,
		UDim2.fromOffset(CLOCK_WIDTH, PANEL_HEIGHT),
		UDim2.new(1, -MARGIN, 0, top),
		Vector2.new(1, 0)
	)
	clockLabel = makeLabel(clockFace, Theme.RetroColors.Ink, 14)
	clockLabel.Text = "6:00 AM"

	buildPurse(gui, top + PANEL_HEIGHT + PANEL_GAP)
end

local function clockTimeToText(dayProgress: number): string
	-- Mirrors DayCycleService's own ClockTime formula (6am -> midnight
	-- across the day) — see its comments for why 6..24 specifically.
	local clockTime = 6 + dayProgress * 18
	local hour24 = math.floor(clockTime) % 24
	local minute = math.floor((clockTime % 1) * 60)
	local suffix = hour24 >= 12 and "PM" or "AM"
	local hour12 = hour24 % 12
	if hour12 == 0 then
		hour12 = 12
	end
	return string.format("%d:%02d %s", hour12, minute, suffix)
end

function HudUI.setDay(day: number, dayProgress: number, season: string?, weather: string?)
	ensureBuilt()
	-- Upper case throughout: PressStart2P has no lower case worth reading
	-- at this size, and mixed case in it looks like a rendering fault.
	local base = season and `{season} {day}` or `DAY {day}`
	-- Weather rides on the date line rather than getting its own row.
	-- Clear weather says nothing at all — a permanent "CLEAR" is a label
	-- that is only ever news when it changes.
	local suffix = (weather and weather ~= "Clear") and ` {weather}` or ""
	dayLabel.Text = string.upper(base .. suffix)
	clockLabel.Text = clockTimeToText(dayProgress)
end

function HudUI.refreshInventory()
	ensureBuilt()
	local snapshot = InventoryCache.get()
	goldLabel.Text = tostring(snapshot.gold)

	-- Fill shows progress through the current thousand. Someone holding
	-- exactly 1,000g gets a full bar rather than an empty one, which is
	-- the friendlier of the two rounding choices.
	local intoThousand = snapshot.gold % 1000
	local progress = if snapshot.gold > 0 and intoThousand == 0 then 1 else intoThousand / 1000
	goldFill.Size = UDim2.fromScale(progress, 1)
end

return HudUI
