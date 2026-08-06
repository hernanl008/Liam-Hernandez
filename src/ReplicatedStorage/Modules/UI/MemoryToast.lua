--!strict
-- The "KAYA WILL REMEMBER THAT" card: a small notice that slides into
-- the bottom-right corner when a dialogue choice moves a relationship,
-- holds, and slides away.
--
-- Replaces a plain status-line message ("Kaya +1 relationship") that
-- shared the same strip as every other transient line in the game, read
-- as a stat readout, and said nothing about what actually happened. The
-- Walking Dead framing Liam asked for works because it reports a
-- CONSEQUENCE rather than a number — the player learns their choice
-- landed without being handed a score to optimise.
--
-- Own corner, deliberately. The HUD holds the top two, the dialogue box
-- holds the bottom centre, and chat sits bottom left, so bottom right is
-- the one place a notice can appear during a conversation without
-- covering anything the player is reading.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local AssetIds = require(Modules:WaitForChild("Shared"):WaitForChild("AssetIds"))
local PortraitSheet = require(Modules:WaitForChild("Shared"):WaitForChild("PortraitSheet"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local MemoryToast = {}

local CARD_WIDTH = 300
local CARD_HEIGHT = 60
local PORTRAIT_SCALE = 1 -- 32px, an integer multiple of the sheet cell
local PORTRAIT_SIZE = PortraitSheet.CELL_SIZE * PORTRAIT_SCALE
local HOLD_SECONDS = 2.6
local BOTTOM_MARGIN = 18

local screenGui: ScreenGui? = nil
local card: Frame
local portraitImage: ImageLabel
local titleLabel: TextLabel
local bodyLabel: TextLabel

-- Bumped per show(); the delayed hide checks it still owns the card, so
-- two relationship changes in quick succession can't have the first
-- one's hide cut the second one short.
local showToken = 0

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "MemoryToast"
	gui.ResetOnSpawn = false
	-- Above the HUD, below the catch showcase: it should never be hidden,
	-- but it also shouldn't sit over a celebration.
	gui.DisplayOrder = 8
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(1, 1)
	-- Parked just off the bottom edge; show() slides it up.
	card.Position = UDim2.new(1, -18, 1, CARD_HEIGHT + BOTTOM_MARGIN)
	card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	card.BackgroundColor3 = Theme.RetroColors.WoodDark
	card.BorderSizePixel = 0
	card.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.RetroColors.Bronze
	stroke.Thickness = 2
	stroke.Parent = card

	-- Dark card, not parchment. Every other panel is a light page; this
	-- one is a beat of narration, and the inversion is what makes it
	-- register as different in kind rather than just another readout.
	local portraitHolder = Instance.new("Frame")
	portraitHolder.AnchorPoint = Vector2.new(0, 0.5)
	portraitHolder.Position = UDim2.new(0, 9, 0.5, 0)
	portraitHolder.Size = UDim2.fromOffset(PORTRAIT_SIZE + 6, PORTRAIT_SIZE + 6)
	portraitHolder.BackgroundColor3 = Theme.RetroColors.WoodMid
	portraitHolder.BorderSizePixel = 0
	portraitHolder.Parent = card
	local holderCorner = Instance.new("UICorner")
	holderCorner.CornerRadius = UDim.new(0, 4)
	holderCorner.Parent = portraitHolder

	portraitImage = Instance.new("ImageLabel")
	portraitImage.AnchorPoint = Vector2.new(0.5, 0.5)
	portraitImage.Position = UDim2.fromScale(0.5, 0.5)
	portraitImage.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portraitImage.BackgroundTransparency = 1
	portraitImage.ScaleType = Enum.ScaleType.Stretch
	portraitImage.ResampleMode = Enum.ResamplerMode.Pixelated
	portraitImage.ImageRectSize = Vector2.new(PortraitSheet.CELL_SIZE, PortraitSheet.CELL_SIZE)
	portraitImage.Parent = portraitHolder

	local textX = PORTRAIT_SIZE + 24

	titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.fromOffset(textX, 12)
	titleLabel.Size = UDim2.new(1, -(textX + 12), 0, 12)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.FontFace = Theme.RetroFontFace
	-- Fixed integer sizes, like every pixel-font label in this game:
	-- TextScaled lands the face on fractional glyph pixels and it mushes.
	titleLabel.TextSize = 11
	titleLabel.TextColor3 = Theme.RetroColors.Bronze
	titleLabel.Parent = card

	bodyLabel = Instance.new("TextLabel")
	bodyLabel.Position = UDim2.fromOffset(textX, 30)
	bodyLabel.Size = UDim2.new(1, -(textX + 12), 0, 14)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.FontFace = Theme.RetroFontFace
	bodyLabel.TextSize = 10
	bodyLabel.TextColor3 = Theme.RetroColors.Parchment
	bodyLabel.TextTruncate = Enum.TextTruncate.AtEnd
	bodyLabel.Parent = card
end

-- Shows "<speaker> will remember that" for a relationship change.
-- `delta` only decides the tone of the second line — the number itself
-- is never shown, on purpose.
function MemoryToast.show(speaker: string, delta: number)
	if speaker == "" or delta == 0 then
		return
	end
	ensureBuilt()

	showToken += 1
	local token = showToken

	titleLabel.Text = string.upper(speaker)
	bodyLabel.Text = if delta > 0 then "WILL REMEMBER THAT." else "WILL NOT FORGET THAT."
	-- Warm for a bond gained, rust for one strained. Two words and a
	-- colour carry it; a number would invite optimising instead of
	-- choosing.
	bodyLabel.TextColor3 = if delta > 0 then Theme.RetroColors.Parchment else Theme.RetroColors.Rust

	local sheetId = AssetIds.sprite("portrait_sheet")
	local hasPortrait = sheetId ~= "rbxassetid://0" and PortraitSheet.has(speaker)
	portraitImage.Visible = hasPortrait
	if hasPortrait then
		portraitImage.Image = sheetId
		portraitImage.ImageRectOffset = PortraitSheet.rectOffsetFor(speaker)
	end

	local shown = UDim2.new(1, -18, 1, -BOTTOM_MARGIN)
	local hidden = UDim2.new(1, -18, 1, CARD_HEIGHT + BOTTOM_MARGIN)

	card.Position = hidden
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = shown,
	}):Play()

	task.delay(HOLD_SECONDS, function()
		if showToken ~= token then
			return
		end
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = hidden,
		}):Play()
	end)
end

return MemoryToast
