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
-- Skips silently (returns false) when the fish sheet isn't uploaded —
-- the banner/toast still carry the celebration.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("AssetIds"))
local FishSpriteSheet = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("FishSpriteSheet"))
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local CatchShowcaseUI = {}

local DIAMOND_SIZE = 190

local screenGui: ScreenGui? = nil
local frame: Frame
local diamond: Frame
local image: ImageLabel
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

	-- Square and big enough that the rotated diamond never reaches the
	-- edges. The frame is just a positioning anchor — both children are
	-- centered in it, which is what keeps them aligned.
	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.4)
	frame.Size = UDim2.fromOffset(DIAMOND_SIZE * 2, DIAMOND_SIZE * 2)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui

	scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = frame

	-- Rotated accent diamond behind the fish — ties the close-up to the
	-- gem-sparkle motif the rest of the retro celebration uses, and gives
	-- the sprite a backdrop so it reads against any world color.
	diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromOffset(DIAMOND_SIZE, DIAMOND_SIZE)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Theme.RetroColors.Bronze
	diamond.BackgroundTransparency = 0.3
	diamond.Parent = frame
	local diamondStroke = Instance.new("UIStroke")
	diamondStroke.Color = Theme.RetroColors.WoodDark
	diamondStroke.Thickness = 3
	diamondStroke.Parent = diamond

	-- Sized to actually FIT INSIDE the rotated diamond, centered on the
	-- same point. The first pass let the image fill the whole frame while
	-- the diamond was much smaller, so the fish overhung it badly on both
	-- sides. For a diamond of side S the inscribed half-diagonal is
	-- S*sqrt(2)/2, and a w x h box fits when w/2 + h/2 <= that; with the
	-- sheet's 2:1 cells that solves to the constants below.
	local halfDiagonal = DIAMOND_SIZE * math.sqrt(2) / 2
	local imageHeight = math.floor(halfDiagonal * 2 / 3)
	image = Instance.new("ImageLabel")
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromOffset(imageHeight * 2, imageHeight)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Stretch
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	image.ImageRectSize = Vector2.new(FishSpriteSheet.CELL_WIDTH, FishSpriteSheet.CELL_HEIGHT)
	image.ZIndex = 2
	image.Parent = frame
end

-- Zooms `spriteId`'s sheet cell up center-screen for `seconds`, tinting
-- the backdrop diamond with `accentColor` (the fish's rarity color).
function CatchShowcaseUI.show(spriteId: string, accentColor: Color3, seconds: number): boolean
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
	diamond.BackgroundColor3 = accentColor
	frame.Visible = true

	-- Pop in with overshoot, then breathe gently while held. Both are
	-- deliberately unhurried — the first pass snapped in at 0.28s and
	-- pulsed twice a second, which on top of the banner, sparkles and
	-- toast landing in the same moment read as frantic.
	scale.Scale = 0
	TweenService:Create(scale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
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
			end
		end)
	end)
	return true
end

return CatchShowcaseUI
