--!strict
-- Persistent top bar: gold, current day/time, and the three pillar skill
-- levels (GDD.md §13 — closes the "no general inventory/HUD" gap noted
-- in docs/VERTICAL_SLICE_SETUP.md). Always visible, no toggle.

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

local function ensureBuilt()
	if built then
		return
	end
	built = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "HudUI"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -16, 0, 40)
	bar.Position = UDim2.fromOffset(8, 8)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	Theme.applyPanel(bar, { strokeThickness = 2 })

	goldLabel = Instance.new("TextLabel")
	goldLabel.Size = UDim2.fromScale(0.2, 1)
	goldLabel.Position = UDim2.fromScale(0.01, 0)
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextScaled = true
	goldLabel.TextXAlignment = Enum.TextXAlignment.Left
	goldLabel.Text = "0g"
	goldLabel.Parent = bar
	Theme.styleHeader(goldLabel)

	dayLabel = Instance.new("TextLabel")
	dayLabel.Size = UDim2.fromScale(0.3, 1)
	dayLabel.Position = UDim2.fromScale(0.35, 0)
	dayLabel.BackgroundTransparency = 1
	dayLabel.TextScaled = true
	dayLabel.Text = "Day 1"
	dayLabel.Parent = bar
	Theme.styleBody(dayLabel, Theme.Colors.AccentPink)

	levelsLabel = Instance.new("TextLabel")
	levelsLabel.Size = UDim2.fromScale(0.35, 1)
	levelsLabel.Position = UDim2.fromScale(0.63, 0)
	levelsLabel.BackgroundTransparency = 1
	levelsLabel.TextScaled = true
	levelsLabel.TextXAlignment = Enum.TextXAlignment.Right
	levelsLabel.Text = ""
	levelsLabel.Parent = bar
	Theme.styleBody(levelsLabel, Theme.Colors.Success)
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
	dayLabel.Text = `{seasonPrefix}Day {day} — {clockTimeToText(dayProgress)}{weatherSuffix}`
end

function HudUI.refreshInventory()
	ensureBuilt()
	local snapshot = InventoryCache.get()
	goldLabel.Text = `{snapshot.gold}g`

	local parts = {}
	for _, skillId in { "Farming", "Fishing", "Cooking" } do
		local xp = snapshot.skillXp[skillId] or 0
		local level = 1 + math.floor(xp / SkillTreeConfig.xpPerLevel)
		table.insert(parts, `{skillId} {level}`)
	end
	levelsLabel.Text = table.concat(parts, "   ")
end

return HudUI
