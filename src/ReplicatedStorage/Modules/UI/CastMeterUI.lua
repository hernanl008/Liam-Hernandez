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
local ContextActionService = game:GetService("ContextActionService")
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

-- Space is Roblox's default jump key. Two earlier attempts at fixing
-- this didn't work out: SetStateEnabled(Jumping, false) alone still let
-- the character jump, and adding a *separate* ContextActionService
-- binding purely to Sink the key (alongside the plain
-- UserInputService.InputBegan listener that was actually detecting the
-- lock) stopped that listener from firing at all — apparently a Sunk
-- ContextAction input doesn't reach UserInputService.InputBegan the same
-- way a plain keypress does. Fix: one single ContextActionService-bound
-- handler does both jobs — detect the press to lock the meter, AND
-- return Sink so Roblox's own jump control (bound at a lower priority)
-- never sees it — instead of two separate systems racing each other.
local SPACE_ACTION = "CastMeterLockSpace"

local function setJumpEnabled(enabled: boolean)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	end
end

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
	setJumpEnabled(false)

	local function finish(power: number?)
		if not active then
			return
		end
		active = false
		(screenGui :: ScreenGui).Enabled = false
		setJumpEnabled(true)
		ContextActionService:UnbindAction(SPACE_ACTION)
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

	-- Single handler for both jobs: locks the meter on press AND sinks
	-- the input so Roblox's own jump control never sees it — see the
	-- comment above SPACE_ACTION for why this used to be two separate,
	-- conflicting mechanisms.
	local function handleSpace(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			local t = (elapsed * CYCLES_PER_SECOND) % 2
			local power = t <= 1 and t or (2 - t)
			finish(power)
		end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindActionAtPriority(
		SPACE_ACTION,
		handleSpace,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space
	)

	-- Escape isn't bound to any default Roblox control, so a plain
	-- UserInputService listener is fine for it — no race to avoid here.
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
