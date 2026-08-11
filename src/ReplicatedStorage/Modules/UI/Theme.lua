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
	-- Border, not the Contextual default. Contextual outlines the border
	-- of a Frame but the GLYPHS of a TextLabel/TextButton/TextBox, and
	-- these helpers get applied to buttons (ShopUI's sell buttons, the
	-- dialogue options) as readily as to panels. On a button that default
	-- draws a thick dark outline around every letter, which at pixel-font
	-- sizes smears the text into unreadable blobs. Border is a no-op on
	-- Frames, so it is always the right thing for a shared helper.
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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
	-- Border, not the Contextual default. Contextual outlines the border
	-- of a Frame but the GLYPHS of a TextLabel/TextButton/TextBox, and
	-- these helpers get applied to buttons (ShopUI's sell buttons, the
	-- dialogue options) as readily as to panels. On a button that default
	-- draws a thick dark outline around every letter, which at pixel-font
	-- sizes smears the text into unreadable blobs. Border is a no-op on
	-- Frames, so it is always the right thing for a shared helper.
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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
-- Adds a decorative border BEHIND `frame` as siblings, and turns the
-- frame itself into the parchment face.
--
-- Siblings, not children, and that is the whole trick. The nested
-- version (Theme.framedPanel) has to return a face for callers to parent
-- content to, which means every call site has to be rewritten — and on a
-- TextButton a nested face covers the button's own text outright. Layers
-- placed behind as slightly larger siblings need neither: existing
-- screens keep parenting content straight to the frame they always used,
-- and buttons keep their labels.
--
-- The position maths handles any AnchorPoint. A decoration `pad` larger
-- on every side shares the frame's centre when its Position is offset by
-- ((2*ax - 1) * pad, (2*ay - 1) * pad) — which resolves to -pad at
-- anchor 0, 0 at anchor 0.5 and +pad at anchor 1.
local function addBackingLayer(frame: GuiObject, pad: number, color: Color3, radius: number, depth: number): Frame
	local anchor = frame.AnchorPoint
	local layer = Instance.new("Frame")
	layer.Name = "Backing"
	layer.AnchorPoint = anchor
	layer.Position = frame.Position + UDim2.fromOffset((2 * anchor.X - 1) * pad, (2 * anchor.Y - 1) * pad)
	layer.Size = frame.Size + UDim2.fromOffset(pad * 2, pad * 2)
	layer.BackgroundColor3 = color
	layer.BorderSizePixel = 0
	layer.ZIndex = frame.ZIndex - depth
	layer.Parent = frame.Parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = layer

	-- Follow the frame if it is moved or resized later; several screens
	-- lay out with UIListLayout, which writes Position after the fact.
	local function sync()
		local a = frame.AnchorPoint
		layer.AnchorPoint = a
		layer.Position = frame.Position + UDim2.fromOffset((2 * a.X - 1) * pad, (2 * a.Y - 1) * pad)
		layer.Size = frame.Size + UDim2.fromOffset(pad * 2, pad * 2)
	end
	frame:GetPropertyChangedSignal("Position"):Connect(sync)
	frame:GetPropertyChangedSignal("Size"):Connect(sync)

	return layer
end

-- Parchment gradient for `frame`, TINTED toward whatever colour the
-- caller had already set.
--
-- These helpers now paint the surface themselves, and simply overwriting
-- BackgroundColor3 would throw away meaning: several screens colour a
-- card to say something (ShopUI's sell button uses ButtonAvailable,
-- InventoryUI tiles differ by category). Blending the caller's colour
-- into the parchment keeps that signal while the panel still reads as
-- parchment. A frame left at Roblox's default grey is treated as "no
-- opinion" and gets plain parchment.
local ROBLOX_DEFAULT_BACKGROUND = Color3.fromRGB(163, 162, 165)
local TINT_STRENGTH = 0.4

local function applyParchmentFill(frame: GuiObject)
	local base = frame.BackgroundColor3
	local top = Theme.RetroColors.Parchment
	local bottom = Theme.RetroColors.ParchmentShadow
	if base ~= ROBLOX_DEFAULT_BACKGROUND and base ~= Color3.new(1, 1, 1) then
		top = top:Lerp(base, TINT_STRENGTH)
		bottom = bottom:Lerp(base, TINT_STRENGTH)
	end

	-- White, so the gradient shows its true colours: UIGradient multiplies
	-- against BackgroundColor3 rather than replacing it.
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = frame
end

function Theme.applyPanel(frame: Frame | ImageLabel, options: { strokeThickness: number? }?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	applyParchmentFill(frame)

	-- Bright ring, dark rim, then a shadow under both.
	addBackingLayer(frame, 3, Theme.RetroColors.WoodLight, 10, 1)
	addBackingLayer(frame, 6, Theme.RetroColors.WoodDark, 12, 2)
	local shadow = addBackingLayer(frame, 6, Color3.fromRGB(38, 22, 12), 12, 3)
	shadow.BackgroundTransparency = 0.55
	shadow.Position += UDim2.fromOffset(0, 3)
end

function Theme.applyCard(frame: Frame, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = frame

	applyParchmentFill(frame)

	addBackingLayer(frame, 2, Theme.RetroColors.WoodLight, (radius or 6) + 2, 1)
	addBackingLayer(frame, 4, Theme.RetroColors.WoodDark, (radius or 6) + 4, 2)
end

-- Darkens a colour enough to read as ink on parchment while keeping its
-- hue.
--
-- Needed because applyPanel now paints panels LIGHT, and every existing
-- screen was written for the old dark panels: it passes pale accents
-- (AccentGold, AccentPink, Success) that would be all but invisible on
-- parchment. Ignoring the caller's colour outright would work but throws
-- away real meaning — a green "success" line and a red warning are
-- carrying information. Scaling the value down instead keeps green
-- green and pink pink while guaranteeing contrast.
--
-- 0.28 is not a taste call: the panel gradient runs Parchment down to
-- ParchmentShadow, so text near the bottom of a panel sits on the darker
-- tone, and that is the case the factor has to clear. Checked against
-- every accent the old screens pass, using the WCAG relative-luminance
-- formula on the SHADOW end. 0.42 left the worst of them at 3.2:1 and
-- 0.32 still fell just short; 0.28 puts the worst at 5.1:1, past the 4.5
-- threshold for body text.
local INK_VALUE_FACTOR = 0.28

local function inkify(color: Color3): Color3
	local h, sat, value = color:ToHSV()
	return Color3.fromHSV(h, math.min(sat + 0.15, 1), math.min(value, 1) * INK_VALUE_FACTOR)
end

function Theme.styleHeader(label: TextLabel, color: Color3?)
	label.Font = Theme.Fonts.Header
	label.TextColor3 = if color then inkify(color) else Theme.RetroColors.Ink
end

function Theme.styleBody(label: TextLabel, color: Color3?)
	label.Font = Theme.Fonts.Body
	label.TextColor3 = if color then inkify(color) else Theme.RetroColors.Ink
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

-- ---------------------------------------------------------------------
-- Layered frames
--
-- The look every retro panel in this game is built from: a drop shadow,
-- a dark outer rim, a bright metal ring, and the parchment face. The
-- ring is the part a UIStroke can never provide, because a stroke only
-- ever sits outside the shape and there is no way to get a bright band
-- BETWEEN the dark edge and the face -- which is why earlier panels,
-- built as one rectangle plus a stroke, read as flat no matter how they
-- were coloured or arranged.
--
-- Lives here because it is now used by the HUD, the dialogue box and the
-- skill tree, and three hand-copied versions of a sixty-line builder is
-- exactly the kind of thing that drifts apart one panel at a time.

-- Frames `target` and returns its FACE -- the parchment surface callers
-- parent content to. Works on a TextButton as well as a Frame, though
-- note that a face parented to a button covers that button's own text
-- (Roblox draws a widget's text at the widget's ZIndex), so buttons want
-- a transparent TextButton laid OVER the returned face instead.
function Theme.framedPanel(target: GuiObject, radius: number): Frame
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

-- Drop shadow behind `target`, tracking its size. A sibling rather than
-- a child, since a child always draws above its parent.
--
-- Sized from AbsoluteSize, not by copying Size: a panel whose Size is
-- scale-based and narrowed by a UISizeConstraint resolves much smaller
-- than its Size claims, and copying the UDim2 made the dialogue box's
-- shadow span the screen and stick out both sides as a dark bar.
function Theme.panelShadow(target: GuiObject, radius: number)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = target.AnchorPoint
	shadow.Position = target.Position + UDim2.fromOffset(0, 3)
	shadow.Size = UDim2.fromOffset(target.AbsoluteSize.X, target.AbsoluteSize.Y)
	shadow.BackgroundColor3 = Color3.fromRGB(38, 22, 12)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.ZIndex = target.ZIndex - 1
	shadow.Parent = target.Parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = shadow

	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		shadow.Size = UDim2.fromOffset(target.AbsoluteSize.X, target.AbsoluteSize.Y)
	end)
end


return Theme
