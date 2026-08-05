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

-- Retro-medieval wood/parchment look — the game's new target visual
-- direction, being rolled out one mechanic at a time (fishing first)
-- rather than all at once, so the rest of the UI (dialogue, shop,
-- compendium, etc.) intentionally stays on the anime jewel-tone palette
-- above until its own turn comes. Flat colors + a UIStroke border for
-- now, same "no texture assets yet" approach the anime pass started
-- with — real wood-grain/parchment textures can replace these once art
-- exists, without callers needing to change.
Theme.RetroColors = {
	WoodDark = Color3.fromRGB(64, 38, 24), -- outer frame/border
	WoodMid = Color3.fromRGB(120, 76, 42), -- wood panel fill
	WoodLight = Color3.fromRGB(168, 118, 66), -- wood highlight/accent border
	Parchment = Color3.fromRGB(230, 200, 148), -- page background (top of gradient)
	ParchmentShadow = Color3.fromRGB(202, 168, 112), -- page background (bottom of gradient)
	Ink = Color3.fromRGB(58, 36, 22), -- primary text — dark ink on parchment
	InkMuted = Color3.fromRGB(112, 84, 56), -- secondary/hint text
	Bronze = Color3.fromRGB(198, 150, 78), -- gold/bronze accent (fills, highlights)
	Rust = Color3.fromRGB(140, 58, 40), -- warnings/cancel accents
}

-- A parchment page inset into a thick wood frame — the retro-medieval
-- equivalent of applyPanel above.
function Theme.applyRetroPanel(frame: Frame | ImageLabel, options: { strokeThickness: number? }?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6) -- boxier than the anime theme's rounder corners, reads more "carved wood"
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.RetroColors.WoodDark
	stroke.Thickness = (options and options.strokeThickness) or 4
	stroke.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Theme.RetroColors.Parchment, Theme.RetroColors.ParchmentShadow)
	gradient.Rotation = 90
	gradient.Parent = frame

	-- Cream highlight line just inside the wood rim — the Stardew-panel
	-- signature (dark outer border, light inner edge) that makes the frame
	-- read as a carved surface with actual depth instead of a flat
	-- rectangle wearing an outline. A nested transparent frame carrying
	-- its own UIStroke, since UIStroke itself can only trace the outer
	-- boundary. Named so restyle-on-the-fly code (StatusToast.applyStyle)
	-- can find and clear it along with the other style instances.
	local inner = Instance.new("Frame")
	inner.Name = "InnerHighlight"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(2, 2)
	inner.Size = UDim2.new(1, -4, 1, -4)
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0, 4)
	innerCorner.Parent = inner
	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = Color3.fromRGB(250, 232, 190)
	innerStroke.Thickness = 2
	innerStroke.Transparency = 0.45
	innerStroke.Parent = inner
	inner.Parent = frame
end

-- Smaller wood-trimmed card (interior rows/slots) — the retro-medieval
-- equivalent of applyCard above.
function Theme.applyRetroCard(frame: Frame, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 4)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.RetroColors.WoodMid
	stroke.Thickness = 2
	stroke.Parent = frame
end

-- Retro pixel font (Theme.RetroFontFace) + ink color — dark text on the
-- light parchment background reads far better than the anime theme's
-- light-text-on-dark convention would with a blocky pixel font.
function Theme.styleRetroHeader(label: TextLabel, color: Color3?)
	label.FontFace = Theme.RetroFontFace
	label.TextColor3 = color or Theme.RetroColors.Ink
end

function Theme.styleRetroBody(label: TextLabel, color: Color3?)
	label.FontFace = Theme.RetroFontFace
	label.TextColor3 = color or Theme.RetroColors.InkMuted
end

-- Retro-medieval equivalent of styleImpactText — same "thick dark stroke
-- behind a bright fill" punch, pixel font + wood-toned stroke instead of
-- Bangers + a plain dark stroke, for combo counters on retro-skinned
-- minigames (the fishing reel-in chart).
function Theme.styleRetroImpact(label: TextLabel, fillColor: Color3?)
	label.FontFace = Theme.RetroFontFace
	label.TextColor3 = fillColor or Color3.fromRGB(255, 221, 143)
	label.TextStrokeColor3 = Theme.RetroColors.WoodDark
	label.TextStrokeTransparency = 0
end

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
