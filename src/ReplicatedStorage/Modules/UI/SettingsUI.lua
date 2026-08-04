--!strict
-- Settings screen (press O). Currently just Assist Mode (GDD.md §10) —
-- the only settings-shaped toggle the game has — but it's its own screen
-- rather than bolted onto the HUD so a real options menu has somewhere to
-- grow later without another redesign.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local SettingsUI = {}

local screenGui: ScreenGui? = nil
local assistToggleButton: TextButton
local visible = false

local function refreshAssistToggle()
	local enabled = InventoryCache.get().assistMode
	assistToggleButton.Text = enabled and "Assist Mode: ON" or "Assist Mode: OFF"
	assistToggleButton.BackgroundColor3 = enabled and Theme.Colors.ButtonAvailable or Theme.Colors.ButtonLocked
end

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SettingsUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.4, 0.32)
	frame.Position = UDim2.fromScale(0.3, 0.34)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Theme.applyPanel(frame)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.18)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "Settings"
	title.Parent = frame
	Theme.styleHeader(title)

	local closeHint = Instance.new("TextLabel")
	closeHint.Size = UDim2.fromScale(1, 0.1)
	closeHint.Position = UDim2.fromScale(0, 0.18)
	closeHint.BackgroundTransparency = 1
	closeHint.TextScaled = true
	closeHint.Text = "Press O to close"
	closeHint.Parent = frame
	Theme.styleBody(closeHint, Theme.Colors.TextMuted)

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.fromScale(0.7, 0.22)
	toggle.Position = UDim2.fromScale(0.15, 0.32)
	toggle.AutoButtonColor = true
	toggle.Parent = frame
	Theme.applyCard(toggle, 8)
	Theme.styleBody(toggle, Theme.Colors.TextPrimary)
	assistToggleButton = toggle

	toggle.Activated:Connect(function()
		-- No optimistic local flip — SettingsController.lua refreshes this
		-- screen off the server's own InventoryUpdate echo instead, same
		-- round-trip ShopUI/other screens already rely on for live state.
		Remotes.get("SetAssistMode"):FireServer(not InventoryCache.get().assistMode)
	end)

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.fromScale(0.9, 0.32)
	desc.Position = UDim2.fromScale(0.05, 0.58)
	desc.BackgroundTransparency = 1
	desc.TextScaled = true
	desc.TextWrapped = true
	desc.Text = "Widens the timing windows on fishing/cooking rhythm minigames — a "
		.. "gentler difficulty, not a shortcut. On by default."
	desc.Parent = frame
	Theme.styleBody(desc, Theme.Colors.TextSecondary)
end

function SettingsUI.toggle()
	ensureBuilt()
	visible = not visible
	if visible then
		refreshAssistToggle()
	end
	(screenGui :: ScreenGui).Enabled = visible
end

function SettingsUI.isVisible(): boolean
	return visible
end

function SettingsUI.refreshIfVisible()
	if visible then
		refreshAssistToggle()
	end
end

return SettingsUI
