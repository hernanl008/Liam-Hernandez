--!strict
-- One shared bottom-of-screen status line ("Casting...", "Caught a
-- Silver Minnow!", "Bronze Grilled Minnow Skewer (~8g)") used by the
-- Farming/Fishing/Cooking controllers instead of each keeping its own
-- copy of the same tiny GUI. Styled via Theme.lua (GDD.md §14).
--
-- One label, but two looks, restyled on the fly per-call rather than a
-- second GUI: pass `retro = true` and it repaints itself as a parchment
-- plaque with the cutscene's pixel font (matching CastMeterUI, fishing
-- being the mechanic currently getting the retro-medieval pass) instead
-- of the default anime jewel-tone panel every other mechanic still uses.
-- Style only actually gets rebuilt when it changes, not on every call.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local StatusToast = {}

local screenGui: ScreenGui? = nil
local label: TextLabel
local currentlyRetro = false

local function applyStyle(retro: boolean)
	for _, child in label:GetChildren() do
		if child:IsA("UICorner") or child:IsA("UIStroke") or child:IsA("UIGradient") then
			child:Destroy()
		end
	end
	if retro then
		Theme.applyRetroPanel(label, { strokeThickness = 3 })
		Theme.styleRetroBody(label)
	else
		Theme.applyPanel(label, { strokeThickness = 1 })
		Theme.styleBody(label)
	end
	currentlyRetro = retro
end

local function ensureBuilt()
	if screenGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "StatusToast"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.4, 0.06)
	label.Position = UDim2.fromScale(0.3, 0.6)
	label.TextScaled = true
	label.Text = ""
	label.Visible = false
	label.Parent = gui
	applyStyle(false)
end

function StatusToast.set(text: string?, retro: boolean?)
	ensureBuilt()
	if text then
		local wantRetro = retro == true
		if wantRetro ~= currentlyRetro then
			applyStyle(wantRetro)
		end
		label.Text = text
		label.Visible = true
	else
		label.Visible = false
	end
end

-- Convenience: show `text`, then clear it after `seconds` (unless
-- something else has already changed it in the meantime).
function StatusToast.setTemporary(text: string, seconds: number, retro: boolean?)
	StatusToast.set(text, retro)
	task.delay(seconds, function()
		if screenGui and label.Text == text then
			StatusToast.set(nil)
		end
	end)
end

return StatusToast
