--!strict
-- Persistent HUD: gold, the three pillar skill levels, and the current
-- season/day/time. Always visible, no toggle.
--
-- Retro-medieval skin matching the fishing UI and dialogue box: small
-- wood-framed plaques, pixel font, parchment text on dark wood.
--
-- Laid out as corner clusters rather than the single full-width bar this
-- used to be. A bar pinned across the whole top of the screen reads as
-- an application header — it's the shape of a web toolbar, and it ate a
-- strip of the play area at every resolution. Farm sims put this
-- information in the corners for a reason: the middle of the screen
-- belongs to the world.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local SkillTreeConfig = require(Modules:WaitForChild("Shared"):WaitForChild("SkillTreeConfig"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local HudUI = {}

local goldLabel: TextLabel
local dayLabel: TextLabel
local levelsLabel: TextLabel
local built = false

-- Wood plaque with a lighter inner rim — the same carved-label treatment
-- the catch card's name plaque and the dialogue nameplate use, so every
-- piece of chrome in the game reads as cut from the same material.
local function makePlaque(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local plaque = Instance.new("Frame")
	plaque.Size = size
	plaque.Position = position
	plaque.AnchorPoint = anchor
	plaque.BackgroundColor3 = Theme.RetroColors.WoodDark
	plaque.BorderSizePixel = 0
	plaque.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = plaque

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.RetroColors.WoodLight
	stroke.Thickness = 2
	stroke.Parent = plaque

	return plaque
end

local function makeLabel(parent: Frame, color: Color3, alignment: Enum.TextXAlignment, maxSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -14, 1, -8)
	label.BackgroundTransparency = 1
	label.TextXAlignment = alignment
	label.TextScaled = true
	label.FontFace = Theme.RetroFontFace
	label.TextColor3 = color
	label.Text = ""
	label.Parent = parent

	-- Capped, for the same reason every other pixel-font label in this
	-- game is: TextScaled left uncapped lands the face on fractional
	-- glyph pixels and it goes soft.
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.Parent = label

	return label
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

	-- Top left: purse, then the three skill levels beneath it.
	local goldPlaque = makePlaque(gui, UDim2.fromOffset(150, 34), UDim2.fromOffset(10, 10), Vector2.new(0, 0))
	goldLabel = makeLabel(goldPlaque, Theme.RetroColors.Bronze, Enum.TextXAlignment.Left, 16)
	goldLabel.Text = "0G"

	local levelsPlaque = makePlaque(gui, UDim2.fromOffset(280, 28), UDim2.fromOffset(10, 50), Vector2.new(0, 0))
	levelsLabel = makeLabel(levelsPlaque, Theme.RetroColors.Parchment, Enum.TextXAlignment.Left, 12)

	-- Top right: the calendar and clock, away from the purse so a glance
	-- for one never has to read past the other.
	local dayPlaque = makePlaque(gui, UDim2.fromOffset(300, 34), UDim2.new(1, -10, 0, 10), Vector2.new(1, 0))
	dayLabel = makeLabel(dayPlaque, Theme.RetroColors.Parchment, Enum.TextXAlignment.Right, 13)
	dayLabel.Text = "DAY 1"
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
	local seasonPrefix = season and `{season}, ` or ""
	local weatherSuffix = (weather and weather ~= "Clear") and ` ({weather})` or ""
	-- Upper case throughout: PressStart2P has no true lower case worth
	-- reading at 13px, and mixed case in it looks like a rendering fault.
	dayLabel.Text = string.upper(`{seasonPrefix}DAY {day} - {clockTimeToText(dayProgress)}{weatherSuffix}`)
end

function HudUI.refreshInventory()
	ensureBuilt()
	local snapshot = InventoryCache.get()
	goldLabel.Text = `{snapshot.gold}G`

	local parts = {}
	for _, skillId in { "Farming", "Fishing", "Cooking" } do
		local xp = snapshot.skillXp[skillId] or 0
		local level = 1 + math.floor(xp / SkillTreeConfig.xpPerLevel)
		-- Three letters each: the full names at this font size overflowed
		-- the plaque and TextScaled shrank them to unreadable.
		table.insert(parts, `{string.upper(string.sub(skillId, 1, 3))} {level}`)
	end
	levelsLabel.Text = table.concat(parts, "  ")
end

return HudUI
