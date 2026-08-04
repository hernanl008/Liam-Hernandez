--!strict
-- Shared visual language for every UI module (GDD.md §14 "make it more
-- anime" pass). Before this, each screen (DialogueUI, HudUI, Compendium,
-- SkillTree, Spectacle...) picked its own ad-hoc dark-rectangle colors —
-- this is the one place that defines the palette and the reusable
-- "apply this look" helpers, so every screen reads as one game instead
-- of six different prototypes taped together.
--
-- Look: warm jewel-tone panels (deep plum/aubergine, not flat grey),
-- gold stroke borders (the classic "anime UI" bordered-panel signature),
-- soft top-to-bottom gradients instead of flat fills, rounded corners
-- everywhere. Bangers for punchy/impact text (spectacle banners, combo
-- counters), GothamBlack for headers, Gotham for body text.

local Theme = {}

Theme.Colors = {
	PanelTop = Color3.fromRGB(58, 32, 62),
	PanelBottom = Color3.fromRGB(24, 14, 30),
	PanelStroke = Color3.fromRGB(255, 205, 110), -- gold
	AccentGold = Color3.fromRGB(255, 205, 110),
	AccentPink = Color3.fromRGB(255, 140, 170),
	TextPrimary = Color3.fromRGB(255, 250, 245),
	TextSecondary = Color3.fromRGB(205, 190, 205),
	TextMuted = Color3.fromRGB(130, 120, 135),
	Success = Color3.fromRGB(140, 230, 160),
	ButtonFill = Color3.fromRGB(150, 90, 60),
	ButtonAvailable = Color3.fromRGB(190, 140, 50),
	ButtonLocked = Color3.fromRGB(45, 38, 50),
}

Theme.Fonts = {
	Header = Enum.Font.GothamBlack,
	Body = Enum.Font.Gotham,
	BodyBold = Enum.Font.GothamBold,
	Impact = Enum.Font.Bangers,
}

-- "PressStart2P" is NOT a member of the legacy Enum.Font list (confirmed
-- the hard way: referencing it directly at module load time — as every
-- other entry in Theme.Fonts above does — threw immediately and crashed
-- every UI module that requires Theme, i.e. the entire client). Pixel/
-- retro fonts like it only exist in Roblox's newer Font-catalog system
-- (Font.fromName, assigned via TextLabel.FontFace, not .Font), and that
-- catalog can still fail to resolve an unrecognized name — so this is
-- pcall-wrapped with a guaranteed-valid fallback (Font.fromEnum, built
-- from a legacy Enum.Font member that's been proven safe elsewhere in
-- this very file) rather than trusted blind a second time.
local function safeNamedFont(name: string, fallback: Enum.Font): Font
	local ok, result = pcall(Font.fromName, name)
	if ok and result then
		return result
	end
	return Font.fromEnum(fallback)
end

-- Blocky pixel-style font for the opening cutscene's Weaver line
-- (OpeningCutsceneController.lua, set via TextLabel.FontFace) — a
-- deliberate one-off "this isn't the game world yet" register shift for
-- the pre-rebirth sequence, not meant to replace Gotham/Bangers as the
-- game's everyday voice. Falls back to the monospace legacy Code font
-- (definitely valid, been part of Enum.Font since it existed) if the
-- named font can't be resolved.
Theme.RetroFontFace = safeNamedFont("PressStart2P", Enum.Font.Code)

Theme.CornerRadius = UDim.new(0, 12)

-- Rounded corners + a gold stroke border + a subtle top-to-bottom
-- gradient — the one call that makes any Frame read as "this game's UI"
-- instead of a plain rectangle.
function Theme.applyPanel(frame: Frame | ImageLabel, options: { strokeThickness: number? }?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.PanelStroke
	stroke.Thickness = (options and options.strokeThickness) or 2
	stroke.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Theme.Colors.PanelTop, Theme.Colors.PanelBottom)
	gradient.Rotation = 90
	gradient.Parent = frame
end

-- Smaller rounded corner (no stroke/gradient) for interior cards/rows
-- that sit inside an already-themed panel.
function Theme.applyCard(frame: Frame, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = frame
end

function Theme.styleHeader(label: TextLabel, color: Color3?)
	label.Font = Theme.Fonts.Header
	label.TextColor3 = color or Theme.Colors.AccentGold
end

function Theme.styleBody(label: TextLabel, color: Color3?)
	label.Font = Theme.Fonts.Body
	label.TextColor3 = color or Theme.Colors.TextPrimary
end

-- Bold outlined text for spectacle banners/combo counters — the "shonen
-- impact frame" look (thick stroke behind bright fill).
function Theme.styleImpactText(label: TextLabel, fillColor: Color3?)
	label.Font = Theme.Fonts.Impact
	label.TextColor3 = fillColor or Theme.Colors.AccentGold
	label.TextStrokeColor3 = Color3.fromRGB(40, 20, 10)
	label.TextStrokeTransparency = 0
end

function Theme.styleRetro(label: TextLabel, color: Color3?)
	label.FontFace = Theme.RetroFontFace
	label.TextColor3 = color or Theme.Colors.TextPrimary
end

return Theme
