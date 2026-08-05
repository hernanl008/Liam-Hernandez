--!strict
-- One shared bottom-of-screen status line ("Casting...", "Caught a
-- Silver Minnow!", "Bronze Grilled Minnow Skewer (~8g)") used by the
-- Farming/Fishing/Cooking controllers instead of each keeping its own
-- copy of the same tiny GUI. Styled via Theme.lua (GDD.md §14).
--
-- One GUI, but two looks, restyled on the fly per-call rather than a
-- second GUI: pass `retro = true` and it repaints itself as a parchment
-- plaque with the cutscene's pixel font (matching CastMeterUI, fishing
-- being the mechanic currently getting the retro-medieval pass) instead
-- of the default anime jewel-tone panel every other mechanic still uses.
-- Style only actually gets rebuilt when it changes, not on every call.
--
-- Background (panel) and text (label) are separate instances, padded,
-- with an optional drop-shadow + corner rivets behind the panel in retro
-- mode — the first retro pass just called Theme.applyRetroPanel directly
-- on the text label with no padding/shadow/rivets, which read as a flat
-- plain box next to CastMeterUI's much more detailed plaque. This
-- matches that same level of polish instead of a cheaper version of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local StatusToast = {}

local screenGui: ScreenGui? = nil
local shadow: Frame
local panel: Frame
local label: TextLabel
local currentlyRetro = false

-- Retro mode sits lower than the anime default — closer to the bottom
-- edge, out from under the cast meter/reel-in panel/rod-and-fish 3D
-- performance that all live in the vertical middle of the screen while
-- fishing, instead of competing with them for the same space.
local ANIME_POSITION = UDim2.fromScale(0.5, 0.6)
local ANIME_SHADOW_POSITION = UDim2.fromScale(0.508, 0.615)
local RETRO_POSITION = UDim2.fromScale(0.5, 0.88)
local RETRO_SHADOW_POSITION = UDim2.fromScale(0.508, 0.895)

local function addRivet(anchorX: number, anchorY: number)
	local rivet = Instance.new("Frame")
	rivet.Name = "Rivet"
	rivet.AnchorPoint = Vector2.new(anchorX, anchorY)
	rivet.Position = UDim2.new(anchorX, anchorX == 0 and 6 or -6, anchorY, anchorY == 0 and 6 or -6)
	rivet.Size = UDim2.fromOffset(6, 6)
	rivet.BackgroundColor3 = Theme.RetroColors.Bronze
	rivet.BorderSizePixel = 0
	rivet.ZIndex = 3
	rivet.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = rivet
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.RetroColors.WoodDark
	stroke.Thickness = 1
	stroke.Parent = rivet
end

local function applyStyle(retro: boolean)
	for _, child in panel:GetChildren() do
		if child:IsA("UICorner") or child:IsA("UIStroke") or child:IsA("UIGradient") or child.Name == "Rivet" then
			child:Destroy()
		end
	end
	shadow.Visible = retro
	if retro then
		Theme.applyRetroPanel(panel, { strokeThickness = 3 })
		Theme.styleRetroBody(label, Theme.RetroColors.Ink)
		addRivet(0, 0)
		addRivet(1, 0)
		addRivet(0, 1)
		addRivet(1, 1)
		panel.Position = RETRO_POSITION
		shadow.Position = RETRO_SHADOW_POSITION
	else
		Theme.applyPanel(panel, { strokeThickness = 1 })
		Theme.styleBody(label)
		panel.Position = ANIME_POSITION
		shadow.Position = ANIME_SHADOW_POSITION
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

	shadow = Instance.new("Frame")
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Size = UDim2.fromScale(0.42, 0.075)
	shadow.Position = ANIME_SHADOW_POSITION
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Visible = false
	shadow.Parent = gui
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 6)
	shadowCorner.Parent = shadow

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.4, 0.07)
	panel.Position = ANIME_POSITION
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui

	label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = ""
	label.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label

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
		panel.Visible = true
		shadow.Visible = wantRetro
	else
		panel.Visible = false
		shadow.Visible = false
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
