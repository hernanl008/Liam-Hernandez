--!strict
-- One shared bottom-of-screen status line ("Casting...", "Caught a
-- Silver Minnow!", "Bronze Grilled Minnow Skewer (~8g)") used by the
-- Farming/Fishing/Cooking controllers instead of each keeping its own
-- copy of the same tiny GUI.

local Players = game:GetService("Players")

local StatusToast = {}

local screenGui: ScreenGui? = nil
local label: TextLabel

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
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Text = ""
	label.Visible = false
	label.Parent = gui
end

function StatusToast.set(text: string?)
	ensureBuilt()
	if text then
		label.Text = text
		label.Visible = true
	else
		label.Visible = false
	end
end

-- Convenience: show `text`, then clear it after `seconds` (unless
-- something else has already changed it in the meantime).
function StatusToast.setTemporary(text: string, seconds: number)
	StatusToast.set(text)
	task.delay(seconds, function()
		if screenGui and label.Text == text then
			StatusToast.set(nil)
		end
	end)
end

return StatusToast
