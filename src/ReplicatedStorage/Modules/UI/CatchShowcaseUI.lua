--!strict
-- The catch close-up: when a fish is landed, its sprite zooms up big in
-- the middle of the screen — the same cell of the fish sheet the 3D
-- standee uses, blown up with pixel-crisp scaling — popping in with the
-- rest of the celebration and shrinking away as the held fish pops.
-- This is the "you caught THIS" beat games like Stardew sell with the
-- held-overhead item; at this game's far-away fixed camera the 3D
-- standee alone is too small to star in that moment, so the UI close-up
-- carries it.
--
-- Everything here is built around ONE rule: keep it crisp. Pixel art
-- blown up goes mushy the moment any dimension stops being an integer
-- multiple of the source, so the image size is derived from PIXEL_SCALE
-- and every other measurement is derived from the image. The first pass
-- solved for the largest image that fit the diamond and landed on
-- 5.56x, which drew some source pixels 5 screen-px wide and their
-- neighbours 6 — visible as uneven, soft-looking edges even with
-- Pixelated resampling.
--
-- Skips silently (returns false) when the fish sheet isn't uploaded —
-- the banner/toast still carry the celebration.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("AssetIds"))
local FishSpriteSheet = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("FishSpriteSheet"))
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local CatchShowcaseUI = {}

-- Integer, and the only tuning knob that matters: every size below is a
-- multiple of it, so the art can never land on a fractional pixel.
local PIXEL_SCALE = 6
local IMAGE_WIDTH = FishSpriteSheet.CELL_WIDTH * PIXEL_SCALE -- 192
local IMAGE_HEIGHT = FishSpriteSheet.CELL_HEIGHT * PIXEL_SCALE -- 96

-- A w x h box fits inside a square rotated 45 degrees when
-- (w + h) / 2 <= halfDiagonal, and halfDiagonal = side * sqrt(2) / 2.
-- Solved for side, then rounded up to clear the image with a margin.
local DIAMOND_SIZE = math.ceil((IMAGE_WIDTH + IMAGE_HEIGHT) / math.sqrt(2)) + 12
local DIAMOND_SPAN = math.ceil(DIAMOND_SIZE * math.sqrt(2)) -- corner-to-corner
local FRAME_SIZE = DIAMOND_SPAN + 160 -- headroom for the sunburst

local RAY_COUNT = 12

local screenGui: ScreenGui? = nil
local frame: Frame
local rays: Frame
local diamondOuter: Frame
local diamondInner: Frame
local image: ImageLabel
local plaque: Frame
local plaqueLabel: TextLabel
local callout: Frame
local calloutLabel: TextLabel
local calloutStroke: UIStroke
local calloutScale: UIScale
local newTag: Frame
local newTagScale: UIScale
local scale: UIScale
local pulseTween: Tween? = nil

-- Bumped per show(); delayed hide steps check they still own the
-- showcase so back-to-back catches can't have an old hide clobber a new
-- show (same token pattern SpectacleUI.banner uses).
local showToken = 0

local function ensureBuilt()
	if screenGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CatchShowcaseUI"
	gui.ResetOnSpawn = false
	-- Just under SpectacleUI's 10: the transient ring burst / speed lines
	-- draw over the showcase as a halo, the banner lives at the top of
	-- the screen and never overlaps it.
	gui.DisplayOrder = 9
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	-- Square positioning anchor, dead centre. Every child centres in it,
	-- which is what keeps the sprite, the diamond and the rays concentric
	-- no matter how the sizes are tuned.
	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(FRAME_SIZE, FRAME_SIZE)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui

	scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = frame

	-- Sunburst behind everything. Spokes rather than a soft glow: a
	-- radial gradient would fight the pixel art, hard-edged rays read as
	-- the same era as the sprite.
	rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1, 1)
	rays.BackgroundTransparency = 1
	rays.ZIndex = 1
	rays.Parent = frame
	for i = 1, RAY_COUNT do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(18, FRAME_SIZE)
		-- Half a turn spread over all the rays: each is double-ended, so
		-- 180 degrees of spokes covers the full circle.
		ray.Rotation = (i - 1) * (180 / RAY_COUNT)
		ray.BackgroundColor3 = Theme.RetroColors.Bronze
		ray.BackgroundTransparency = 0.86
		ray.BorderSizePixel = 0
		ray.ZIndex = 1
		ray.Parent = rays
	end

	-- Two nested diamonds instead of one translucent one. The old single
	-- diamond sat at 0.3 transparency, so the world showed through and
	-- muddied the sprite's edges; a solid fill inside a dark keyline is
	-- both crisper and more in keeping with the retro panels elsewhere.
	diamondOuter = Instance.new("Frame")
	diamondOuter.AnchorPoint = Vector2.new(0.5, 0.5)
	diamondOuter.Position = UDim2.fromScale(0.5, 0.5)
	diamondOuter.Size = UDim2.fromOffset(DIAMOND_SIZE, DIAMOND_SIZE)
	diamondOuter.Rotation = 45
	diamondOuter.BackgroundColor3 = Theme.RetroColors.WoodDark
	diamondOuter.BorderSizePixel = 0
	diamondOuter.ZIndex = 2
	diamondOuter.Parent = frame

	diamondInner = Instance.new("Frame")
	diamondInner.AnchorPoint = Vector2.new(0.5, 0.5)
	diamondInner.Position = UDim2.fromScale(0.5, 0.5)
	diamondInner.Size = UDim2.new(1, -10, 1, -10)
	diamondInner.BackgroundColor3 = Theme.RetroColors.Bronze
	diamondInner.BorderSizePixel = 0
	diamondInner.ZIndex = 3
	diamondInner.Parent = diamondOuter
	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = Theme.RetroColors.Parchment
	innerStroke.Thickness = 2
	innerStroke.Transparency = 0.5
	innerStroke.Parent = diamondInner

	-- Exact integer multiple of the sheet cell. Parented to the frame,
	-- not to the diamond: a child of a rotated frame inherits the
	-- rotation, and a 45-degree fish is not the goal.
	image = Instance.new("ImageLabel")
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromOffset(IMAGE_WIDTH, IMAGE_HEIGHT)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Stretch
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	image.ImageRectSize = Vector2.new(FishSpriteSheet.CELL_WIDTH, FishSpriteSheet.CELL_HEIGHT)
	image.ZIndex = 5
	image.Parent = frame

	-- Name plaque under the diamond, so the close-up is a labelled card
	-- rather than a floating sprite the player has to read the toast to
	-- identify.
	plaque = Instance.new("Frame")
	plaque.AnchorPoint = Vector2.new(0.5, 0)
	plaque.Position = UDim2.new(0.5, 0, 0.5, DIAMOND_SPAN // 2 - 6)
	plaque.Size = UDim2.fromOffset(DIAMOND_SPAN, 34)
	plaque.BackgroundColor3 = Theme.RetroColors.WoodDark
	plaque.BorderSizePixel = 0
	plaque.ZIndex = 6
	plaque.Parent = frame
	local plaqueCorner = Instance.new("UICorner")
	plaqueCorner.CornerRadius = UDim.new(0, 4)
	plaqueCorner.Parent = plaque
	local plaqueStroke = Instance.new("UIStroke")
	plaqueStroke.Color = Theme.RetroColors.WoodLight
	plaqueStroke.Thickness = 2
	plaqueStroke.Parent = plaque

	plaqueLabel = Instance.new("TextLabel")
	plaqueLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	plaqueLabel.Position = UDim2.fromScale(0.5, 0.5)
	plaqueLabel.Size = UDim2.new(1, -12, 1, -8)
	plaqueLabel.BackgroundTransparency = 1
	plaqueLabel.FontFace = Theme.RetroFontFace
	plaqueLabel.TextColor3 = Theme.RetroColors.Parchment
	plaqueLabel.TextScaled = true
	plaqueLabel.ZIndex = 7
	plaqueLabel.Parent = plaque
	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MaxTextSize = 16
	sizeConstraint.Parent = plaqueLabel

	-- Quality callout, mirroring the plaque above the diamond. This used
	-- to be SpectacleUI's full-width banner at the top of the screen,
	-- which put the celebration in three separate places at once — banner
	-- at the top, card in the middle, toast at the bottom. Folding it
	-- into the card makes the whole catch one object the eye can rest on.
	callout = Instance.new("Frame")
	callout.AnchorPoint = Vector2.new(0.5, 1)
	callout.Position = UDim2.new(0.5, 0, 0.5, -(DIAMOND_SPAN // 2) + 6)
	callout.Size = UDim2.fromOffset(DIAMOND_SPAN, 32)
	callout.BackgroundColor3 = Theme.RetroColors.WoodDark
	callout.BorderSizePixel = 0
	callout.Visible = false
	callout.ZIndex = 6
	callout.Parent = frame
	local calloutCorner = Instance.new("UICorner")
	calloutCorner.CornerRadius = UDim.new(0, 4)
	calloutCorner.Parent = callout
	calloutStroke = Instance.new("UIStroke")
	calloutStroke.Color = Theme.RetroColors.Bronze
	calloutStroke.Thickness = 2
	calloutStroke.Parent = callout

	calloutScale = Instance.new("UIScale")
	calloutScale.Parent = callout

	-- "NEW" corner tag for a first-time catch. This used to be a separate
	-- full-screen NEW DISCOVERY banner fired 2.3s after the card had
	-- gone, which turned one event into two interruptions and made a
	-- routine first catch feel like a bigger deal than a legendary one.
	-- As a tag it's on the same object as the fish it describes, and it
	-- costs the player no extra time.
	newTag = Instance.new("Frame")
	newTag.AnchorPoint = Vector2.new(0.5, 0.5)
	newTag.Position = UDim2.new(0.5, DIAMOND_SPAN // 2 - 18, 0.5, -(DIAMOND_SPAN // 2) + 18)
	newTag.Size = UDim2.fromOffset(58, 26)
	newTag.BackgroundColor3 = Theme.RetroColors.Rust
	newTag.BorderSizePixel = 0
	newTag.Rotation = -12
	newTag.Visible = false
	newTag.ZIndex = 8
	newTag.Parent = frame
	local newCorner = Instance.new("UICorner")
	newCorner.CornerRadius = UDim.new(0, 4)
	newCorner.Parent = newTag
	local newStroke = Instance.new("UIStroke")
	newStroke.Color = Theme.RetroColors.WoodDark
	newStroke.Thickness = 2
	newStroke.Parent = newTag

	local newLabel = Instance.new("TextLabel")
	newLabel.Size = UDim2.fromScale(1, 1)
	newLabel.BackgroundTransparency = 1
	newLabel.FontFace = Theme.RetroFontFace
	newLabel.TextSize = 11
	newLabel.TextColor3 = Theme.RetroColors.Parchment
	newLabel.Text = "NEW"
	newLabel.ZIndex = 9
	newLabel.Parent = newTag

	newTagScale = Instance.new("UIScale")
	newTagScale.Parent = newTag

	calloutLabel = Instance.new("TextLabel")
	calloutLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	calloutLabel.Position = UDim2.fromScale(0.5, 0.5)
	calloutLabel.Size = UDim2.new(1, -12, 1, -8)
	calloutLabel.BackgroundTransparency = 1
	calloutLabel.FontFace = Theme.RetroFontFace
	calloutLabel.TextScaled = true
	calloutLabel.ZIndex = 7
	calloutLabel.Parent = callout
	local calloutConstraint = Instance.new("UITextSizeConstraint")
	calloutConstraint.MaxTextSize = 15
	calloutConstraint.Parent = calloutLabel
end

export type ShowOptions = {
	accentColor: Color3, -- the fish's rarity colour, tints the diamond and rays
	seconds: number, -- how long the card holds before shrinking away
	displayName: string?, -- labels the plaque below; omitted hides it
	callout: string?, -- e.g. "LEGENDARY CATCH!", ribbon above; omitted hides it
	isNew: boolean?, -- first time catching this species
}

-- Zooms `spriteId`'s sheet cell up center-screen as a labelled card.
--
-- Options table rather than positional arguments: this grew to five
-- trailing parameters, the last two of which were a string and a boolean
-- that no call site could keep straight at a glance.
function CatchShowcaseUI.show(spriteId: string, options: ShowOptions): boolean
	local accentColor = options.accentColor
	local seconds = options.seconds
	local displayName = options.displayName
	local calloutText = options.callout
	local sheetId = AssetIds.sprite("fish_sheet")
	if sheetId == "rbxassetid://0" then
		return false
	end
	ensureBuilt()

	showToken += 1
	local token = showToken
	if pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
	end

	image.Image = sheetId
	image.ImageRectOffset = FishSpriteSheet.rectOffsetFor(spriteId)
	diamondInner.BackgroundColor3 = accentColor
	for _, ray in rays:GetChildren() do
		if ray:IsA("Frame") then
			ray.BackgroundColor3 = accentColor
			ray.BackgroundTransparency = 0.72
		end
	end
	plaque.Visible = displayName ~= nil
	plaqueLabel.Text = string.upper(displayName or "")
	callout.Visible = false
	calloutLabel.Text = string.upper(calloutText or "")
	calloutLabel.TextColor3 = accentColor
	calloutStroke.Color = accentColor
	newTag.Visible = false
	frame.Visible = true

	-- Pop in with overshoot, then breathe gently while held. Both are
	-- deliberately unhurried — the first pass snapped in at 0.28s and
	-- pulsed twice a second, which on top of the banner, sparkles and
	-- toast landing in the same moment read as frantic.
	scale.Scale = 0
	TweenService:Create(scale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	-- The sunburst is an IMPACT, not a fixture: it flashes with the pop
	-- and is gone in a third of a second, leaving a calm card behind.
	-- Spinning it for the whole hold (the previous version) meant
	-- something was always moving under the sprite, which is what made a
	-- crisp card still feel busy.
	rays.Rotation = 0
	TweenService:Create(rays, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = 10,
	}):Play()
	for _, ray in rays:GetChildren() do
		if ray:IsA("Frame") then
			TweenService:Create(ray, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end

	-- The NEW tag stamps on just after the card settles, slightly ahead
	-- of the callout so the two don't pop together.
	if options.isNew then
		task.delay(0.3, function()
			if showToken ~= token then
				return
			end
			newTag.Visible = true
			newTagScale.Scale = 0
			TweenService:Create(newTagScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end)
	end

	-- The callout lands a beat after the card, so the two read as
	-- cause and effect rather than arriving in a heap.
	if calloutText then
		task.delay(0.4, function()
			if showToken ~= token then
				return
			end
			callout.Visible = true
			calloutScale.Scale = 0
			TweenService:Create(calloutScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end)
	end

	task.delay(0.42, function()
		if showToken == token then
			local pulse = TweenService:Create(
				scale,
				TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.03 }
			)
			pulse:Play()
			pulseTween = pulse
		end
	end)

	task.delay(seconds, function()
		if showToken ~= token then
			return
		end
		if pulseTween then
			pulseTween:Cancel()
			pulseTween = nil
		end
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Scale = 0,
		}):Play()
		task.delay(0.22, function()
			if showToken == token then
				frame.Visible = false
				callout.Visible = false
				newTag.Visible = false
			end
		end)
	end)
	return true
end

return CatchShowcaseUI
