--!strict
-- Persistent HUD: season/day, clock and purse. Always visible, no
-- toggle.
--
-- Styled after the farm-sim convention Liam referenced: LIGHT parchment
-- panels with a thick brown frame and dark ink text. The previous pass
-- had this inverted — dark wood plaques with light text — which is
-- heavier on the eye and fights a bright outdoor scene instead of
-- sitting on top of it. Light panels with a dark rim also hold their
-- shape against any background, which matters when the ground behind
-- them changes colour by season.
--
-- Laid out as corner clusters, not the full-width bar this started as: a
-- strip across the top of the screen is the shape of a web toolbar and
-- eats play area at every resolution. Calendar, clock and purse all live
-- top right; the rest of the screen stays the world's.
--
-- Skill levels used to sit as three chips in the top-left corner. They
-- are gone: a level that changes a few times an hour does not earn
-- permanent screen space, they collided with Roblox's own chat window,
-- and the numbers are already on the skill tree screen where someone
-- actually deciding something would look for them. Level-ups still
-- announce themselves when they happen (ProgressFeedback).
--
-- The one deliberate departure from the reference: its money row is a
-- set of decorative digit boxes. Ours is a real meter — a thin line
-- under the amount fills with progress toward the next 1,000g — so the
-- space carries information instead of just texture.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local HudUI = {}

local goldLabel: TextLabel
local dayLabel: TextLabel
local clockLabel: TextLabel
local goldFill: Frame
local built = false

-- Parchment panel with a thick dark rim and a cream inner bevel. The
-- bevel is what makes it read as a carved plaque rather than a
-- rectangle with an outline — dark outside, light just inside, the same
-- trick Theme.applyRetroPanel uses on the big panels.
local function makePanel(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local panel = Instance.new("Frame")
	panel.Size = size
	panel.Position = position
	panel.AnchorPoint = anchor
	-- White, so the gradient below shows its true colours: UIGradient
	-- multiplies against BackgroundColor3 rather than replacing it.
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BorderSizePixel = 0
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Theme.RetroColors.Parchment, Theme.RetroColors.ParchmentShadow)
	gradient.Rotation = 90
	gradient.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.RetroColors.WoodDark
	-- 2px, not 3. On panels this small a heavier rim eats the parchment
	-- and the cluster reads as chunky rather than crisp.
	stroke.Thickness = 2
	stroke.Parent = panel

	local bevel = Instance.new("Frame")
	bevel.Name = "Bevel"
	bevel.BackgroundTransparency = 1
	bevel.Position = UDim2.fromOffset(2, 2)
	bevel.Size = UDim2.new(1, -4, 1, -4)
	bevel.Parent = panel
	local bevelCorner = Instance.new("UICorner")
	bevelCorner.CornerRadius = UDim.new(0, 4)
	bevelCorner.Parent = bevel
	local bevelStroke = Instance.new("UIStroke")
	bevelStroke.Color = Theme.RetroColors.WoodLight
	bevelStroke.Thickness = 2
	bevelStroke.Transparency = 0.35
	bevelStroke.Parent = bevel

	return panel
end

local function makeLabel(
	parent: Frame,
	color: Color3,
	alignment: Enum.TextXAlignment,
	textSize: number,
	inset: number?
): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -(inset or 16), 1, -10)
	label.BackgroundTransparency = 1
	label.TextXAlignment = alignment
	-- FIXED integer size, never TextScaled. TextScaled picks whatever
	-- fractional size fits, and PressStart2P at a fractional size renders
	-- its glyph grid across half-pixels and mushes. A
	-- UITextSizeConstraint only caps the maximum -- it does not stop the
	-- chosen size being fractional -- so capping never fixed it. Long
	-- strings get truncated instead of shrunk.
	label.TextSize = textSize
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.FontFace = Theme.RetroFontFace
	label.TextColor3 = color
	label.Text = ""
	label.ZIndex = 2
	label.Parent = parent

	return label
end

local function buildGoldRow(gui: ScreenGui, topOffset: number)
	-- Compact purse: coin, amount, and a thin fill line along the bottom
	-- for progress toward the next 1,000g.
	--
	-- This started as eight discrete pip boxes echoing the reference's
	-- money row. It read as broken: at 100g none of them are lit, so the
	-- HUD showed a row of eight empty slots, which looks like content
	-- that failed to load rather than a meter that is nearly empty. A
	-- continuous line has no such state — an almost-empty bar still
	-- clearly reads as a bar. It is also a third of the width, which is
	-- what actually buys the top-right corner some room.
	local row = makePanel(gui, UDim2.fromOffset(168, 36), UDim2.new(1, -10, 0, topOffset), Vector2.new(1, 0))

	local coin = Instance.new("Frame")
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 10, 0.5, -2)
	coin.Size = UDim2.fromOffset(20, 20)
	coin.BackgroundColor3 = Theme.RetroColors.Bronze
	coin.BorderSizePixel = 0
	coin.ZIndex = 2
	coin.Parent = row
	local coinCorner = Instance.new("UICorner")
	coinCorner.CornerRadius = UDim.new(1, 0)
	coinCorner.Parent = coin
	local coinStroke = Instance.new("UIStroke")
	coinStroke.Color = Theme.RetroColors.WoodDark
	coinStroke.Thickness = 2
	coinStroke.Parent = coin

	local coinLabel = Instance.new("TextLabel")
	coinLabel.Size = UDim2.fromScale(1, 1)
	coinLabel.BackgroundTransparency = 1
	coinLabel.FontFace = Theme.RetroFontFace
	coinLabel.TextColor3 = Theme.RetroColors.WoodDark
	coinLabel.TextSize = 10
	coinLabel.Text = "G"
	coinLabel.ZIndex = 3
	coinLabel.Parent = coin

	goldLabel = Instance.new("TextLabel")
	goldLabel.AnchorPoint = Vector2.new(1, 0.5)
	goldLabel.Position = UDim2.new(1, -12, 0.5, -2)
	goldLabel.Size = UDim2.fromOffset(110, 20)
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextXAlignment = Enum.TextXAlignment.Right
	goldLabel.TextSize = 16
	goldLabel.FontFace = Theme.RetroFontFace
	-- Rust rather than ink: the reference picks the money out in red, and
	-- it is the one number on screen worth finding at a glance.
	goldLabel.TextColor3 = Theme.RetroColors.Rust
	goldLabel.Text = "0"
	goldLabel.ZIndex = 2
	goldLabel.Parent = row

	-- Progress track, inset from both ends so it reads as part of the
	-- panel rather than an edge.
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -6)
	track.Size = UDim2.new(1, -22, 0, 3)
	track.BackgroundColor3 = Theme.RetroColors.ParchmentShadow
	track.BorderSizePixel = 0
	track.ZIndex = 2
	track.Parent = row
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	goldFill = Instance.new("Frame")
	goldFill.Size = UDim2.fromScale(0, 1)
	goldFill.BackgroundColor3 = Theme.RetroColors.Bronze
	goldFill.BorderSizePixel = 0
	goldFill.ZIndex = 3
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

	-- Top right, calendar then clock, side by side as in the reference.
	-- 10px between panels, and the calendar sized to its longest real
	-- string ("AUTUMN 28 RAIN") rather than padded out to a round number.
	local dayPanel = makePanel(gui, UDim2.fromOffset(200, 36), UDim2.new(1, -140, 0, top), Vector2.new(1, 0))
	dayLabel = makeLabel(dayPanel, Theme.RetroColors.Ink, Enum.TextXAlignment.Center, 14)
	dayLabel.Text = "DAY 1"

	local clockPanel = makePanel(gui, UDim2.fromOffset(130, 36), UDim2.new(1, -10, 0, top), Vector2.new(1, 0))
	clockLabel = makeLabel(clockPanel, Theme.RetroColors.Ink, Enum.TextXAlignment.Center, 14)
	clockLabel.Text = "6:00 AM"

	buildGoldRow(gui, top + 46)
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
	local seasonPrefix = season and `{string.upper(season)} ` or ""
	local weatherSuffix = (weather and weather ~= "Clear") and ` {string.upper(weather)}` or ""
	dayLabel.Text = `{seasonPrefix}{day}{weatherSuffix}`
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
