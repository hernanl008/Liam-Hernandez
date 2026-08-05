--!strict
-- Celebratory feedback for standout moments (legendary catches, high
-- combos, Gold-tier dishes) — the "make it feel more anime" pass, see
-- GDD.md §11/§14. Anime mode: a radiating speed-line burst (the shonen
-- "impact frame" look) pops behind a Bangers-font banner. Retro mode
-- (BannerOptions.retro — fishing's catch banners): a parchment ribbon
-- unrolls open with a shimmer sweep and a gold sparkle-diamond burst
-- instead — the speed-line motif reads as anime regardless of what
-- color it's tinted, so retro gets its own presentation rather than a
-- recolored copy of the same effect. Both share a brief screen-tint
-- flash and an optional camera shake. Everything here is plain UI
-- Frames, no art assets — swap the visuals for real VFX/sound later;
-- the API (SpectacleUI.banner) doesn't need to change when that happens.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local SpectacleUI = {}

local screenGui: ScreenGui? = nil
local bannerLabel: TextLabel
local flashFrame: Frame
local speedLines: CanvasGroup
local speedLinesScale: UIScale
local retroRibbon: Frame
local retroShimmer: Frame
local gemSparkles: { Frame } = {}

local SPEED_LINE_COUNT = 14
local RETRO_RIBBON_CLOSED_SIZE = UDim2.fromScale(0, 0.18)
local RETRO_RIBBON_OPEN_SIZE = UDim2.fromScale(0.82, 0.18)
local GEM_COUNT = 6

-- Small round rivet/stud detail, same "bolted wood plaque" look used by
-- CastMeterUI/RhythmUI — duplicated rather than shared (see those files'
-- comments on why: ~15 lines, not worth a shared module for it).
local function addRivet(parent: Instance, anchorX: number, anchorY: number)
	local rivet = Instance.new("Frame")
	rivet.AnchorPoint = Vector2.new(anchorX, anchorY)
	rivet.Position = UDim2.new(anchorX, anchorX == 0 and 6 or -6, anchorY, anchorY == 0 and 6 or -6)
	rivet.Size = UDim2.fromOffset(7, 7)
	rivet.BackgroundColor3 = Theme.RetroColors.Bronze
	rivet.BorderSizePixel = 0
	rivet.ZIndex = 2
	rivet.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = rivet
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.RetroColors.WoodDark
	stroke.Thickness = 1
	stroke.Parent = rivet
end

local function ensureBuilt()
	if screenGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpectacleUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flashFrame.BackgroundTransparency = 1
	flashFrame.Visible = false
	flashFrame.ZIndex = 1
	flashFrame.Parent = gui

	-- CanvasGroup so every line's fade is one GroupTransparency tween
	-- instead of animating 14 Frames individually. Size is fixed (large
	-- enough to contain every line at any rotation) — CanvasGroup clips
	-- to its own bounds, so only the pop/fade is animated, not the size.
	speedLines = Instance.new("CanvasGroup")
	speedLines.AnchorPoint = Vector2.new(0.5, 0.5)
	speedLines.Position = UDim2.fromScale(0.5, 0.22)
	speedLines.Size = UDim2.fromOffset(600, 600)
	speedLines.BackgroundTransparency = 1
	speedLines.GroupTransparency = 1
	speedLines.Visible = false
	speedLines.ZIndex = 1
	speedLines.Parent = gui

	speedLinesScale = Instance.new("UIScale")
	speedLinesScale.Scale = 0.3
	speedLinesScale.Parent = speedLines

	for i = 1, SPEED_LINE_COUNT do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.fromOffset(520, 3)
		line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		line.BorderSizePixel = 0
		line.Rotation = (360 / SPEED_LINE_COUNT) * i
		line.Parent = speedLines
	end

	-- Retro-mode-only backdrop: a parchment plaque that unrolls open behind
	-- the banner text (Size.X tweened 0 -> full) instead of anime mode's
	-- text-floating-on-a-flash presentation. Built here but left hidden/
	-- zero-width — a banner() call only activates it when retro = true, so
	-- non-retro banners (Gold-tier dishes, level-ups) are completely
	-- unaffected by its existence.
	retroRibbon = Instance.new("Frame")
	retroRibbon.AnchorPoint = Vector2.new(0.5, 0.5)
	retroRibbon.Position = UDim2.fromScale(0.5, 0.22)
	retroRibbon.Size = RETRO_RIBBON_CLOSED_SIZE
	retroRibbon.BorderSizePixel = 0
	retroRibbon.ClipsDescendants = true
	retroRibbon.Visible = false
	retroRibbon.ZIndex = 1
	retroRibbon.Parent = gui
	Theme.applyRetroPanel(retroRibbon, { strokeThickness = 4 })
	addRivet(retroRibbon, 0, 0)
	addRivet(retroRibbon, 1, 0)
	addRivet(retroRibbon, 0, 1)
	addRivet(retroRibbon, 1, 1)

	-- A bright diagonal bar that sweeps once across the parchment as it
	-- opens — the "light catching a treasure" trick, clipped to the
	-- ribbon's own bounds (ClipsDescendants above) so it never spills
	-- outside it.
	local shimmer = Instance.new("Frame")
	shimmer.AnchorPoint = Vector2.new(0.5, 0.5)
	shimmer.Size = UDim2.new(0, 50, 3, 0)
	shimmer.Position = UDim2.fromScale(-0.25, 0.5)
	shimmer.Rotation = 25
	shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shimmer.BackgroundTransparency = 1
	shimmer.BorderSizePixel = 0
	shimmer.ZIndex = 2
	shimmer.Parent = retroRibbon
	retroShimmer = shimmer

	-- Retro-mode-only "treasure sparkle" — small gold diamonds that pop
	-- outward from the ribbon and fade, replacing the anime speed-lines
	-- burst below for retro banners entirely (a shonen "impact frame" is
	-- the wrong visual language for a wood-and-parchment medieval look,
	-- however it's tinted). Built once here, hidden; a banner() call only
	-- animates them when retro = true.
	for i = 1, GEM_COUNT do
		local angle = math.rad((360 / GEM_COUNT) * i + 15)
		local gem = Instance.new("Frame")
		gem.AnchorPoint = Vector2.new(0.5, 0.5)
		gem.Position = UDim2.new(0.5, math.cos(angle) * 240, 0.22, math.sin(angle) * 130)
		gem.Size = UDim2.fromOffset(0, 0)
		gem.Rotation = 45
		gem.BackgroundColor3 = Theme.RetroColors.Bronze
		gem.BorderSizePixel = 0
		gem.ZIndex = 1
		gem.Visible = false
		gem.Parent = gui
		local gemStroke = Instance.new("UIStroke")
		gemStroke.Color = Theme.RetroColors.WoodDark
		gemStroke.Thickness = 1
		gemStroke.Parent = gem
		table.insert(gemSparkles, gem)
	end

	bannerLabel = Instance.new("TextLabel")
	bannerLabel.Size = UDim2.fromScale(0.8, 0.14)
	bannerLabel.Position = UDim2.fromScale(0.1, 0.15)
	bannerLabel.BackgroundTransparency = 1
	bannerLabel.TextScaled = true
	bannerLabel.TextTransparency = 1
	bannerLabel.TextStrokeTransparency = 1
	bannerLabel.ZIndex = 2
	bannerLabel.Parent = gui
	Theme.styleImpactText(bannerLabel)
end

-- Applied *after* Roblox's own camera update each frame (priority = Camera + 1)
-- so it nudges the already-computed camera CFrame instead of fighting it —
-- the standard pattern for additive camera shake in Roblox.
local shakeBindingCounter = 0
local function shakeCamera(intensity: number, duration: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	shakeBindingCounter += 1
	local bindingName = `SpectacleShake_{shakeBindingCounter}`
	local startTime = os.clock()

	RunService:BindToRenderStep(bindingName, Enum.RenderPriority.Camera.Value + 1, function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			RunService:UnbindFromRenderStep(bindingName)
			return
		end
		local falloff = 1 - (elapsed / duration)
		local offset = Vector3.new((math.random() - 0.5) * intensity * falloff, (math.random() - 0.5) * intensity * falloff, 0)
		camera.CFrame *= CFrame.new(offset)
	end)
end

-- Public standalone shake — for callers that want the camera punch
-- without a full banner+speed-lines callout every time (e.g. RhythmUI's
-- per-hit/combo-milestone juice, which fires far more often than a
-- banner-worthy moment would).
function SpectacleUI.shake(intensity: number, duration: number)
	shakeCamera(intensity, duration)
end

-- A lightweight expanding-ring pop at an arbitrary screen position — the
-- same trick RhythmUI's per-hit burst uses, but standalone (not scoped
-- to a lane frame) so any caller can drop one anywhere. Meant for
-- "every single instance of this thing feels a little alive" moments
-- (e.g. every fish catch, not just the rare spectacle ones) that would
-- get old fast as a full banner+speed-lines callout every time.
function SpectacleUI.burst(position: UDim2, color: Color3, sizeOffset: number?)
	ensureBuilt()
	local gui = screenGui
	if not gui then
		return
	end
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = position
	ring.Size = UDim2.fromOffset(0, 0)
	ring.BackgroundColor3 = color
	ring.BackgroundTransparency = 0.1
	ring.BorderSizePixel = 0
	ring.ZIndex = 0
	ring.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local offset = sizeOffset or 90
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(offset, offset),
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.4, function()
		ring:Destroy()
	end)
end

export type BannerOptions = {
	shake: boolean?,
	holdSeconds: number?,
	-- Retro-medieval presentation (pixel font via Theme.styleRetroImpact,
	-- the parchment ribbon backdrop with a shimmer sweep, a warm cream
	-- flash, and a gold sparkle-diamond burst) instead of the default
	-- anime Bangers-font/gold-look/speed-lines. Fishing catches opt into
	-- this; Gold-tier dishes and level-ups stay on the anime presentation
	-- until their own turn (same "mechanic by mechanic" rollout as the
	-- rest of the UI).
	retro: boolean?,
}

-- Bumped on every call; each of a call's own delayed fade-outs checks it's
-- still the most recent call before touching shared state. Without this, a
-- second spectacle firing (e.g. a combo catch immediately followed by a
-- Gold-tier dish) could have an *earlier* call's delayed fade-out undo a
-- *later* call's still-playing burst, or vice versa — leaving the speed
-- lines/banner stuck on whichever transparency last got written instead of
-- reliably ending hidden.
local currentBannerId = 0

function SpectacleUI.banner(text: string, color: Color3?, options: BannerOptions?)
	ensureBuilt()

	local bannerId = currentBannerId + 1
	currentBannerId = bannerId
	local function isCurrent(): boolean
		return currentBannerId == bannerId
	end

	local retro = options ~= nil and options.retro == true
	local resolvedColor = color or (retro and Theme.RetroColors.Bronze or Theme.Colors.AccentGold)

	bannerLabel.Visible = true
	bannerLabel.Text = text
	bannerLabel.TextTransparency = 1
	bannerLabel.TextStrokeTransparency = 1
	bannerLabel.Position = UDim2.fromScale(0.1, 0.12)
	if retro then
		Theme.styleRetroImpact(bannerLabel, resolvedColor)
	else
		Theme.styleImpactText(bannerLabel, resolvedColor)
	end

	-- Reset every call, not just when retro — otherwise a retro banner
	-- immediately followed by an anime one (e.g. a spectacle catch, then
	-- a Gold-tier dish) would leave the ribbon stuck open behind text it
	-- was never meant to frame.
	retroRibbon.Visible = retro
	for _, gem in gemSparkles do
		gem.Visible = false
	end
	if retro then
		retroRibbon.Size = RETRO_RIBBON_CLOSED_SIZE
		retroShimmer.Position = UDim2.fromScale(-0.25, 0.5)
		retroShimmer.BackgroundTransparency = 1
		TweenService:Create(retroRibbon, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = RETRO_RIBBON_OPEN_SIZE,
		}):Play()
		-- Shimmer sweeps once, timed to land right as the ribbon finishes
		-- unrolling — "light catching the treasure" the instant it's fully
		-- revealed, not before.
		task.delay(0.15, function()
			if not isCurrent() then
				return
			end
			retroShimmer.BackgroundTransparency = 0.4
			TweenService:Create(retroShimmer, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(1.25, 0.5),
			}):Play()
			task.delay(0.4, function()
				if isCurrent() then
					retroShimmer.BackgroundTransparency = 1
				end
			end)
		end)
		-- Sparkle diamonds pop outward in a quick stagger, hold briefly,
		-- then fade — the retro-medieval "treasure found" replacement for
		-- the anime speed-lines burst below, which is skipped entirely in
		-- retro mode (see the header comment on gemSparkles).
		for i, gem in gemSparkles do
			gem.Visible = true
			gem.Size = UDim2.fromOffset(0, 0)
			gem.BackgroundColor3 = resolvedColor
			gem.BackgroundTransparency = 0
			local gemDelay = (i - 1) * 0.03
			task.delay(gemDelay, function()
				if isCurrent() then
					TweenService:Create(gem, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Size = UDim2.fromOffset(16, 16),
					}):Play()
				end
			end)
			task.delay(0.4 + gemDelay, function()
				if isCurrent() then
					TweenService:Create(gem, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
				end
			end)
			task.delay(0.75 + gemDelay, function()
				if isCurrent() then
					gem.Visible = false
				end
			end)
		end
	end

	flashFrame.Visible = true
	flashFrame.BackgroundColor3 = retro and Theme.RetroColors.Parchment or Color3.fromRGB(255, 255, 255)
	local flashIn = TweenService:Create(flashFrame, TweenInfo.new(0.05), { BackgroundTransparency = 0.6 })
	flashIn:Play()
	task.delay(0.05, function()
		if isCurrent() then
			TweenService:Create(flashFrame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end
	end)
	-- Hard hide, not just relying on the tween landing on transparency = 1:
	-- GroupTransparency/BackgroundTransparency tweens on these have been
	-- observed staying visually on screen well past when they should have
	-- finished fading, so Visible = false is what actually guarantees these
	-- disappear rather than the tween's end value.
	task.delay(0.4, function()
		if isCurrent() then
			flashFrame.Visible = false
		end
	end)

	-- Anime mode only — the "shonen impact frame" speed-line burst is the
	-- wrong visual language for retro-medieval banners regardless of what
	-- color it's tinted, so retro gets the gem-sparkle burst above instead
	-- and skips this entirely (also fixes it competing/cluttering with
	-- the ribbon+shimmer+sparkles all going off at once).
	if retro then
		speedLines.Visible = false
	else
		for _, line in speedLines:GetChildren() do
			if line:IsA("Frame") then
				line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
		speedLines.Visible = true
		speedLinesScale.Scale = 0.3
		speedLines.GroupTransparency = 0
		TweenService:Create(speedLinesScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(0.1, function()
			if isCurrent() then
				TweenService:Create(speedLines, TweenInfo.new(0.35), { GroupTransparency = 1 }):Play()
			end
		end)
		task.delay(0.5, function()
			if isCurrent() then
				speedLines.Visible = false
			end
		end)
	end

	TweenService:Create(bannerLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextStrokeTransparency = 0,
		Position = UDim2.fromScale(0.1, 0.15),
	}):Play()

	if options and options.shake then
		-- Defensive: a shake failure (e.g. no CurrentCamera) must never skip
		-- scheduling the fade-out below, or the banner/lines would hang forever.
		pcall(shakeCamera, 0.3, 0.3)
	end

	local holdSeconds = (options and options.holdSeconds) or 1.1
	task.delay(holdSeconds, function()
		if isCurrent() then
			TweenService:Create(bannerLabel, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			if retro then
				TweenService:Create(retroRibbon, TweenInfo.new(0.3), { Size = RETRO_RIBBON_CLOSED_SIZE }):Play()
			end
		end
	end)
	task.delay(holdSeconds + 0.35, function()
		if isCurrent() then
			bannerLabel.Visible = false
			retroRibbon.Visible = false
		end
	end)
end

return SpectacleUI
