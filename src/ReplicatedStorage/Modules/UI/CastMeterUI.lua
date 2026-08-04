--!strict
-- Cast-power meter (GDD.md §3), previously punted on — see the removed
-- header comment in FishingController.lua explaining it needed a server-
-- side consumer first (FishingService.RequestCast now takes a castPower
-- argument). A vertical fill bar ping-pongs 0->1->0; pressing Space locks
-- in whatever power it's at, same skill-based "stop the moving bar" beat
-- as the reel-in minigame but simpler (one axis, no scoring window).
--
-- Freezes the player for the duration via PlayerFreeze.lua (Client
-- module) — see that file's header for why this needed real debugging
-- to get right (position-pinning alone wasn't enough; WalkSpeed had to
-- be zeroed too, or the character visibly "walks in place").
--
-- Retro-medieval styling (Theme.applyRetroPanel/styleRetroHeader, GDD's
-- new target look, fishing being the first mechanic reskinned) — dark
-- ink text on parchment instead of the anime theme's light-on-dark,
-- since a blocky pixel font reads far better with strong light/dark
-- contrast than it did tinted TextMuted-gray on a dark purple panel.
-- The old "SPACE" hint rotated 90° along the bar is gone too — sideways
-- pixel-font text was genuinely harder to read, not just off-theme.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))
local PlayerFreeze = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("PlayerFreeze"))

local CastMeterUI = {}

-- Full 0->1->0 sweep takes 1/CYCLES_PER_SECOND seconds either direction.
local CYCLES_PER_SECOND = 1.1

local screenGui: ScreenGui? = nil
local fill: Frame

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

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.15, 0.4)
	frame.Position = UDim2.fromScale(0.03, 0.3)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Theme.applyRetroPanel(frame)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.94, 0.13)
	title.Position = UDim2.fromScale(0.03, 0.02)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.TextWrapped = true
	title.Text = "CAST POWER"
	title.Parent = frame
	Theme.styleRetroHeader(title)

	-- A "slot carved into wood" look for the bar itself — dark recess,
	-- lighter wood rim — distinct from the parchment page it sits on.
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.fromScale(0.5, 0.18)
	track.Size = UDim2.fromScale(0.4, 0.52)
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Theme.RetroColors.WoodDark
	track.Parent = frame
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = Theme.RetroColors.WoodLight
	trackStroke.Thickness = 2
	trackStroke.Parent = track

	local fillFrame = Instance.new("Frame")
	fillFrame.AnchorPoint = Vector2.new(0, 1)
	fillFrame.Position = UDim2.fromScale(0, 1)
	fillFrame.Size = UDim2.fromScale(1, 0)
	fillFrame.BorderSizePixel = 0
	fillFrame.BackgroundColor3 = Theme.RetroColors.Bronze
	fillFrame.Parent = track
	Theme.applyRetroCard(fillFrame, 3)
	fill = fillFrame

	local spaceHint = Instance.new("TextLabel")
	spaceHint.Size = UDim2.fromScale(0.94, 0.13)
	spaceHint.Position = UDim2.fromScale(0.03, 0.74)
	spaceHint.BackgroundTransparency = 1
	spaceHint.TextScaled = true
	spaceHint.TextWrapped = true
	spaceHint.Text = "PRESS SPACE"
	spaceHint.Parent = frame
	Theme.styleRetroHeader(spaceHint, Theme.RetroColors.Ink)

	local escHint = Instance.new("TextLabel")
	escHint.Size = UDim2.fromScale(0.94, 0.1)
	escHint.Position = UDim2.fromScale(0.03, 0.88)
	escHint.BackgroundTransparency = 1
	escHint.TextScaled = true
	escHint.TextWrapped = true
	escHint.Text = "ESC: CANCEL"
	escHint.Parent = frame
	Theme.styleRetroBody(escHint, Theme.RetroColors.InkMuted)
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
		PlayerFreeze.stop()
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

	-- Space is sunk by PlayerFreeze (to block jump), so the lock has to
	-- happen from inside that same handler rather than a separate
	-- UserInputService listener for Space — see PlayerFreeze.lua's header
	-- comment for why a parallel listener doesn't reliably see it.
	PlayerFreeze.start(function()
		local t = (elapsed * CYCLES_PER_SECOND) % 2
		local power = t <= 1 and t or (2 - t)
		finish(power)
	end)

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
		if input.KeyCode == Enum.KeyCode.Escape then
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
