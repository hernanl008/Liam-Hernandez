--!strict
-- Skill tree screen (GDD.md §12): three columns (Farming/Fishing/Cooking),
-- each showing level/XP progress, available skill points, and that
-- tree's perk chain. Clicking an unlockable perk fires Remotes.UnlockPerk;
-- SkillTreeController rebuilds this UI when the result comes back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local SkillTreeConfig = require(Modules:WaitForChild("Shared"):WaitForChild("SkillTreeConfig"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local SkillTreeUI = {}

local screenGui: ScreenGui? = nil
local columnsFrame: Frame
local visible = false

local SKILL_ORDER: { SkillTreeConfig.SkillId } = { "Farming", "Fishing", "Cooking" }

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillTreeUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.6, 0.7)
	frame.Position = UDim2.fromScale(0.2, 0.12)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Theme.applyPanel(frame)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.08)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "Skills — Press P to close"
	title.Parent = frame
	Theme.styleHeader(title, Theme.Colors.AccentPink)

	local columns = Instance.new("Frame")
	columns.Size = UDim2.fromScale(0.98, 0.9)
	columns.Position = UDim2.fromScale(0.01, 0.09)
	columns.BackgroundTransparency = 1
	columns.Parent = frame
	columnsFrame = columns
end

local function perkStatus(skillId: SkillTreeConfig.SkillId, perk: SkillTreeConfig.PerkDef, level: number, unlockedPerks: { [string]: boolean })
	if unlockedPerks[perk.id] then
		return "unlocked"
	end
	if level < perk.requiredLevel then
		return "levelLocked"
	end
	if perk.requires and not unlockedPerks[perk.requires] then
		return "prereqLocked"
	end
	return "available"
end

local function buildColumn(skillId: SkillTreeConfig.SkillId, order: number)
	local snapshot = InventoryCache.get()
	local tree = SkillTreeConfig.Trees[skillId]
	local xp = snapshot.skillXp[skillId] or 0
	local level = 1 + math.floor(xp / SkillTreeConfig.xpPerLevel)
	local xpIntoLevel = xp % SkillTreeConfig.xpPerLevel
	local points = snapshot.skillPoints[skillId] or 0
	local unlockedPerks = snapshot.unlockedPerks[skillId] or {}

	local column = Instance.new("Frame")
	column.Size = UDim2.fromScale(0.32, 1)
	column.Position = UDim2.fromScale((order - 1) * 0.34, 0)
	column.BackgroundColor3 = Color3.fromRGB(38, 24, 42)
	column.Parent = columnsFrame
	Theme.applyCard(column, 10)

	local header = Instance.new("TextLabel")
	header.Size = UDim2.fromScale(1, 0.1)
	header.BackgroundTransparency = 1
	header.TextScaled = true
	header.Text = `{tree.displayName} — Lv {level}`
	header.Parent = column
	Theme.styleHeader(header)

	local xpBar = Instance.new("TextLabel")
	xpBar.Size = UDim2.fromScale(1, 0.06)
	xpBar.Position = UDim2.fromScale(0, 0.1)
	xpBar.BackgroundTransparency = 1
	xpBar.TextScaled = true
	xpBar.Text = `XP {xpIntoLevel}/{SkillTreeConfig.xpPerLevel} — {points} point{points == 1 and "" or "s"} available`
	xpBar.Parent = column
	Theme.styleBody(xpBar, Theme.Colors.TextSecondary)

	local y = 0.18
	for _, perk in tree.perks do
		local status = perkStatus(skillId, perk, level, unlockedPerks)

		local card = Instance.new("Frame")
		card.Size = UDim2.fromScale(0.95, 0.28)
		card.Position = UDim2.fromScale(0.025, y)
		card.BackgroundColor3 = if status == "unlocked"
			then Color3.fromRGB(45, 80, 55)
			elseif status == "available" then Theme.Colors.ButtonAvailable
			else Theme.Colors.ButtonLocked
		card.Parent = column
		Theme.applyCard(card, 8)
		y += 0.31

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.fromScale(1, 0.35)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextScaled = true
		nameLabel.Text = perk.displayName
		nameLabel.Parent = card
		Theme.styleBody(nameLabel)
		nameLabel.Font = Theme.Fonts.BodyBold

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.fromScale(1, 0.4)
		descLabel.Position = UDim2.fromScale(0, 0.35)
		descLabel.BackgroundTransparency = 1
		descLabel.TextScaled = true
		descLabel.TextWrapped = true
		descLabel.Text = perk.description
		descLabel.Parent = card
		Theme.styleBody(descLabel, Theme.Colors.TextSecondary)

		local footer = Instance.new("TextButton")
		footer.Size = UDim2.fromScale(1, 0.25)
		footer.Position = UDim2.fromScale(0, 0.75)
		footer.Font = Theme.Fonts.Body
		footer.TextScaled = true
		footer.AutoButtonColor = status == "available"
		Theme.applyCard(footer, 6)

		if status == "unlocked" then
			footer.Text = "Unlocked"
			footer.BackgroundColor3 = Color3.fromRGB(35, 65, 42)
			footer.TextColor3 = Theme.Colors.Success
		elseif status == "available" then
			footer.Text = `Unlock (Lv {perk.requiredLevel}, {perk.cost} pt)`
			footer.BackgroundColor3 = Color3.fromRGB(110, 75, 30)
			footer.TextColor3 = Theme.Colors.TextPrimary
			footer.Activated:Connect(function()
				Remotes.get("UnlockPerk"):FireServer(skillId, perk.id)
			end)
		elseif status == "prereqLocked" then
			footer.Text = `Requires {perk.requires}`
			footer.BackgroundColor3 = Color3.fromRGB(30, 25, 32)
			footer.TextColor3 = Theme.Colors.TextMuted
		else
			footer.Text = `Requires Lv {perk.requiredLevel}`
			footer.BackgroundColor3 = Color3.fromRGB(30, 25, 32)
			footer.TextColor3 = Theme.Colors.TextMuted
		end
		footer.Parent = card
	end
end

local function rebuild()
	for _, child in columnsFrame:GetChildren() do
		child:Destroy()
	end
	for i, skillId in SKILL_ORDER do
		buildColumn(skillId, i)
	end
end

function SkillTreeUI.toggle()
	ensureBuilt()
	visible = not visible
	if visible then
		rebuild()
	end
	(screenGui :: ScreenGui).Enabled = visible
end

function SkillTreeUI.isVisible(): boolean
	return visible
end

function SkillTreeUI.refreshIfVisible()
	if visible then
		rebuild()
	end
end

return SkillTreeUI
