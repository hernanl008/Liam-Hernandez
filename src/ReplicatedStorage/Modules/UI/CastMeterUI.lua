--!strict
-- Cast-power meter (GDD.md §3), previously punted on — see the removed
-- header comment in FishingController.lua explaining it needed a server-
-- side consumer first (FishingService.RequestCast now takes a castPower
-- argument). A vertical fill bar ping-pongs 0->1->0; pressing Space locks
-- in whatever power it's at, same skill-based "stop the moving bar" beat
-- as the reel-in minigame but simpler (one axis, no scoring window).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local CastMeterUI = {}

-- Full 0->1->0 sweep takes 1/CYCLES_PER_SECOND seconds either direction.
local CYCLES_PER_SECOND = 1.1

local screenGui: ScreenGui? = nil
local fill: Frame
local marker: TextLabel

local active = false
local heartbeatConn: RBXScriptConnection? = nil
local inputConn: RBXScriptConnection? = nil
local elapsed = 0
local finishActive: ((number?) -> ())? = nil

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CastMeterUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	local track = Instance.new("Frame")
	track.Size = UDim2.fromScale(0.03, 0.35)
	track.Position = UDim2.fromScale(0.03, 0.35)
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Theme.Colors.PanelBottom
	track.Parent = gui
	Theme.applyPanel(track, { strokeThickness = 2 })

	local fillFrame = Instance.new("Frame")
	fillFrame.AnchorPoint = Vector2.new(0, 1)
	fillFrame.Position = UDim2.fromScale(0, 1)
	fillFrame.Size = UDim2.fromScale(1, 0)
	fillFrame.BorderSizePixel = 0
	fillFrame.BackgroundColor3 = Theme.Colors.AccentGold
	fillFrame.Parent = track
	Theme.applyCard(fillFrame, 6)
	fill = fillFrame

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.fromScale(1, 0.9)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.fromScale(0.06, 0.99)
	hint.BackgroundTransparency = 1
	hint.TextScaled = true
	hint.Text = "SPACE"
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Rotation = -90
	hint.Parent = track
	Theme.styleBody(hint, Theme.Colors.TextMuted)
	marker = hint

	local escHint = Instance.new("TextLabel")
	escHint.Size = UDim2.fromScale(0.3, 0.04)
	escHint.Position = UDim2.fromScale(0, 0.72)
	escHint.BackgroundTransparency = 1
	escHint.TextScaled = true
	escHint.Text = "Esc to cancel"
	escHint.TextXAlignment = Enum.TextXAlignment.Left
	escHint.Parent = gui
	Theme.styleBody(escHint, Theme.Colors.TextMuted)
end

-- Fires `onLocked(power)` (0-1) once the player presses Space, or
-- `onLocked(nil)` if `cancel()` is called first (e.g. player walks away).
function CastMeterUI.start(onLocked: (power: number?) -> ())
	ensureBuilt()
	if active then
		return
	end
	active = true
	elapsed = 0
	(screenGui :: ScreenGui).Enabled = true

	local function finish(power: number?)
		if not active then
			return
		end
		active = false
		(screenGui :: ScreenGui).Enabled = false
		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
		if inputConn then
			inputConn:Disconnect()
			inputConn = nil
		end
		finishActive = nil
		onLocked(power)
	end
	finishActive = finish

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local t = (elapsed * CYCLES_PER_SECOND) % 2
		local power = t <= 1 and t or (2 - t)
		fill.Size = UDim2.fromScale(1, power)
	end)

	inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			local t = (elapsed * CYCLES_PER_SECOND) % 2
			local power = t <= 1 and t or (2 - t)
			finish(power)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			finish(nil)
		end
	end)
end

function CastMeterUI.cancel()
	if not active or not finishActive then
		return
	end
	finishActive(nil)
end

function CastMeterUI.isActive(): boolean
	return active
end

return CastMeterUI
