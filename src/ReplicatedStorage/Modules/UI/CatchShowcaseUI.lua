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

	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.4)
	frame.Size = UDim2.fromOffset(288, 144)
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
	diamond.Size = UDim2.fromOffset(150, 150)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Theme.RetroColors.Bronze
	diamond.BackgroundTransparency = 0.3
	diamond.Parent = frame
	local diamondStroke = Instance.new("UIStroke")
	diamondStroke.Color = Theme.RetroColors.WoodDark
	diamondStroke.Thickness = 3
	diamondStroke.Parent = diamond

	image = Instance.new("ImageLabel")
	image.Size = UDim2.fromScale(1, 1)
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

	-- Pop in with overshoot, then breathe gently while held.
	scale.Scale = 0
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	task.delay(0.28, function()
		if showToken == token then
			local pulse = TweenService:Create(
				scale,
				TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.05 }
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
