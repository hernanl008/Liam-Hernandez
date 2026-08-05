--!strict
-- Hides the mouse cursor during normal play and brings it back only for
-- the screens you actually click on (dialogue choices, shop, inventory,
-- compendium, skill tree, settings). Everything else in this game is
-- keyboard/ProximityPrompt driven under a fixed camera, so a cursor
-- floating over the world the rest of the time is just noise.
--
-- Works by observing the UIs rather than being told by them: every
-- interactive screen in this project is one ScreenGui in PlayerGui
-- toggled via `.Enabled` (DialogueUI.show/hide, and .toggle() on the
-- rest — all six follow that same pattern), so this watches those
-- ScreenGuis' Enabled property and shows the cursor whenever any of
-- them is on. That means no call site has to remember to ask for the
-- cursor and none can leave it stuck on after closing — the cursor is
-- derived from real UI state instead of being a second thing to keep in
-- sync. Adding a new clickable screen later is one entry in
-- CURSOR_GUI_NAMES below.
--
-- Deliberately NOT listed: HudUI, StatusToast, CastMeterUI, RhythmUI,
-- SpectacleUI, the day-transition fade and the opening cutscene. Those
-- are all either passive readouts or keyboard-only minigames — none of
-- them are clicked, so none of them should summon a cursor.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local MouseCursorController = {}

local CURSOR_GUI_NAMES: { [string]: boolean } = {
	DialogueUI = true,
	ShopUI = true,
	InventoryUI = true,
	CompendiumUI = true,
	SkillTreeUI = true,
	SettingsUI = true,
}

-- Every watched ScreenGui that currently wants the cursor. A set rather
-- than a counter so a gui toggling Enabled repeatedly can't unbalance it.
local wanting: { [Instance]: boolean } = {}

local function refresh()
	local anyWants = next(wanting) ~= nil
	UserInputService.MouseIconEnabled = anyWants
end

local function watch(instance: Instance)
	if not instance:IsA("ScreenGui") or not CURSOR_GUI_NAMES[instance.Name] then
		return
	end

	local function sync()
		if instance.Enabled then
			wanting[instance] = true
		else
			wanting[instance] = nil
		end
		refresh()
	end

	instance:GetPropertyChangedSignal("Enabled"):Connect(sync)
	-- A gui destroyed while still enabled would otherwise pin the cursor
	-- on forever with nothing left to turn it off.
	instance.Destroying:Connect(function()
		wanting[instance] = nil
		refresh()
	end)
	sync()
end

function MouseCursorController.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- These UIs build themselves lazily (first show/toggle call), so most
	-- won't exist yet at init — hence watching ChildAdded, not just what's
	-- already there.
	for _, child in playerGui:GetChildren() do
		watch(child)
	end
	playerGui.ChildAdded:Connect(watch)

	refresh()
end

return MouseCursorController
