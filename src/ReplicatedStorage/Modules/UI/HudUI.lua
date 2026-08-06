--!strict
-- Persistent HUD: season/day, clock, purse, and the three pillar skill
-- levels. Always visible, no toggle.
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
-- eats play area at every resolution. Calendar and purse go top right,
-- skills top left, and the middle of the screen stays the world's.
--
-- The one deliberate departure from the reference: its money row is a
-- set of decorative digit boxes. Ours is a real meter — the pips fill
-- with progress toward the next 1,000g — so the same amount of screen
-- space carries information instead of just texture.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local SkillTreeConfig = require(Modules:WaitForChild("Shared"):WaitForChild("SkillTreeConfig"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local HudUI = {}

local GOLD_PIP_COUNT = 8
local GOLD_PER_PIP = 125 -- GOLD_PIP_COUNT * this == one full bar per 1,000g

local goldLabel: TextLabel
local dayLabel: TextLabel
local clockLabel: TextLabel
local goldPips: { Frame } = {}
local skillLabels: { [string]: TextLabel } = {}
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
	stroke.Thickness = 3
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
	maxSize: number,
	inset: number?
): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -(inset or 16), 1, -10)
	label.BackgroundTransparency = 1
	label.TextXAlignment = alignment
	label.TextScaled = true
	label.FontFace = Theme.RetroFontFace
	label.TextColor3 = color
	label.Text = ""
	label.ZIndex = 2
	label.Parent = parent

	-- Capped, like every pixel-font label in this game: TextScaled left
	-- uncapped lands the face on fractional glyph pixels and it softens.
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.Parent = label

	return label
end

local function buildGoldRow(gui: ScreenGui)
	local row = makePanel(gui, UDim2.fromOffset(330, 36), UDim2.new(1, -10, 0, 54), Vector2.new(1, 0))

	-- Coin badge, standing in for the reference's gold "G" icon. Drawn
	-- rather than uploaded: one more image asset is one more manual
	-- upload, and a bronze disc with a G reads fine at this size.
	local coin = Instance.new("Frame")
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 8, 0.5, 0)
	coin.Size = UDim2.fromOffset(22, 22)
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
	coinLabel.TextScaled = true
	coinLabel.Text = "G"
	coinLabel.ZIndex = 3
	coinLabel.Parent = coin
	local coinConstraint = Instance.new("UITextSizeConstraint")
	coinConstraint.MaxTextSize = 12
	coinConstraint.Parent = coinLabel

	-- Pip track. Unlike the reference's decorative digit boxes these
	-- carry meaning: each pip is GOLD_PER_PIP, so a full row is the next
	-- thousand banked. Same footprint, actual information.
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 38, 0.5, 0)
	track.Size = UDim2.fromOffset(GOLD_PIP_COUNT * 17, 20)
	track.BackgroundTransparency = 1
	track.ZIndex = 2
	track.Parent = row

	local trackLayout = Instance.new("UIListLayout")
	trackLayout.FillDirection = Enum.FillDirection.Horizontal
	trackLayout.Padding = UDim.new(0, 3)
	trackLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	trackLayout.Parent = track

	for i = 1, GOLD_PIP_COUNT do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(14, 18)
		pip.BackgroundColor3 = Theme.RetroColors.ParchmentShadow
		pip.BorderSizePixel = 0
		pip.LayoutOrder = i
		pip.ZIndex = 2
		pip.Parent = track
		local pipCorner = Instance.new("UICorner")
		pipCorner.CornerRadius = UDim.new(0, 2)
		pipCorner.Parent = pip
		local pipStroke = Instance.new("UIStroke")
		pipStroke.Color = Theme.RetroColors.WoodMid
		pipStroke.Thickness = 1
		pipStroke.Parent = pip
		table.insert(goldPips, pip)
	end

	goldLabel = Instance.new("TextLabel")
	goldLabel.AnchorPoint = Vector2.new(1, 0.5)
	goldLabel.Position = UDim2.new(1, -10, 0.5, 0)
	goldLabel.Size = UDim2.fromOffset(110, 22)
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextXAlignment = Enum.TextXAlignment.Right
	goldLabel.TextScaled = true
	goldLabel.FontFace = Theme.RetroFontFace
	-- Rust rather than ink: the reference picks the money out in red, and
	-- it's the one number on screen worth finding at a glance.
	goldLabel.TextColor3 = Theme.RetroColors.Rust
	goldLabel.Text = "0"
	goldLabel.ZIndex = 2
	goldLabel.Parent = row
	local goldConstraint = Instance.new("UITextSizeConstraint")
	goldConstraint.MaxTextSize = 18
	goldConstraint.Parent = goldLabel
end

local function buildSkillChips(gui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.Position = UDim2.fromOffset(10, 10)
	holder.Size = UDim2.fromOffset(300, 32)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = holder

	for i, skillId in { "Farming", "Fishing", "Cooking" } do
		local chip = makePanel(holder, UDim2.fromOffset(94, 30), UDim2.fromOffset(0, 0), Vector2.new(0, 0))
		chip.LayoutOrder = i
		-- Three letters: the full names overflowed a chip this size and
		-- TextScaled shrank them to unreadable.
		skillLabels[skillId] = makeLabel(chip, Theme.RetroColors.Ink, Enum.TextXAlignment.Center, 11, 10)
		skillLabels[skillId].Text = `{string.upper(string.sub(skillId, 1, 3))} 1`
	end
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

	-- Top right, calendar then clock, side by side as in the reference.
	local dayPanel = makePanel(gui, UDim2.fromOffset(210, 38), UDim2.new(1, -128, 0, 10), Vector2.new(1, 0))
	dayLabel = makeLabel(dayPanel, Theme.RetroColors.Ink, Enum.TextXAlignment.Center, 14)
	dayLabel.Text = "DAY 1"

	local clockPanel = makePanel(gui, UDim2.fromOffset(120, 38), UDim2.new(1, -10, 0, 10), Vector2.new(1, 0))
	clockLabel = makeLabel(clockPanel, Theme.RetroColors.Ink, Enum.TextXAlignment.Center, 14)
	clockLabel.Text = "6:00 AM"

	buildGoldRow(gui)
	buildSkillChips(gui)
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

	-- Pips show progress through the current thousand. A player holding
	-- exactly 1,000g reads as a full bar rather than an empty one, which
	-- is the friendlier of the two rounding choices.
	local intoThousand = snapshot.gold % 1000
	local filled = if snapshot.gold > 0 and intoThousand == 0
		then GOLD_PIP_COUNT
		else math.floor(intoThousand / GOLD_PER_PIP)
	for i, pip in goldPips do
		pip.BackgroundColor3 = if i <= filled then Theme.RetroColors.Bronze else Theme.RetroColors.ParchmentShadow
	end

	for _, skillId in { "Farming", "Fishing", "Cooking" } do
		local xp = snapshot.skillXp[skillId] or 0
		local level = 1 + math.floor(xp / SkillTreeConfig.xpPerLevel)
		local label = skillLabels[skillId]
		if label then
			label.Text = `{string.upper(string.sub(skillId, 1, 3))} {level}`
		end
	end
end

return HudUI
