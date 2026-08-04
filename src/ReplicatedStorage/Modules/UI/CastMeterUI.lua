--!strict
-- Cast-power meter (GDD.md §3), previously punted on — see the removed
-- header comment in FishingController.lua explaining it needed a server-
-- side consumer first (FishingService.RequestCast now takes a castPower
-- argument). A vertical fill bar ping-pongs 0->1->0; pressing Space locks
-- in whatever power it's at, same skill-based "stop the moving bar" beat
-- as the reel-in minigame but simpler (one axis, no scoring window).
--
-- While the meter is up, the player is meant to be planted in place.
-- Four earlier attempts at this (SetStateEnabled(Jumping, false),
-- WalkSpeed = 0, sinking individual keys through ContextActionService,
-- PlayerModule.Controls:Disable()) each failed for a different reason —
-- confirmed via debug logging that this project's StarterPlayerScripts
-- doesn't actually have a PlayerModule after Rojo syncs it (so Controls
-- was never reachable), and separately that WalkSpeed = 0 visibly wasn't
-- stopping movement either, meaning whatever drives it here isn't the
-- normal Humanoid pipeline those techniques assume. Instead of chasing
-- the exact mechanism further, this brute-forces it: every single frame
-- the meter is active, the HumanoidRootPart gets snapped back to exactly
-- where it was when the meter opened and its velocity zeroed — it
-- doesn't matter what tried to move it, the position is just overwritten
-- after everything else already had its chance to.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local CastMeterUI = {}

-- SYNC-VERIFICATION CANARY (temporary): prints once, the moment this
-- module is first required (client startup, well before any fishing
-- happens) — six fixes in a row not taking effect points at least as
-- much at "is Studio actually running the code being pushed" as at the
-- code itself. If this exact line ("CANARY-BRUTEFORCE-v1") isn't the
-- very first CastMeterUI-related thing in Output right after pressing
-- Play, the sync isn't picking up the latest push and nothing below
-- this point matters yet.
print("[CastMeterUI] loaded — CANARY-BRUTEFORCE-v1")

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

-- Set only while frozen; the Heartbeat loop re-pins the root part to
-- this every frame. nil means "not currently freezing position."
local frozenCFrame: CFrame? = nil

local function getRootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function setPlayerFrozen(frozen: boolean)
	if frozen then
		local root = getRootPart()
		frozenCFrame = root and root.CFrame
	else
		frozenCFrame = nil
	end

	-- Kept as an extra layer alongside the position-pin above — doesn't
	-- hurt, and stops jump's animation/sound from playing even though
	-- the pin would undo the actual displacement regardless.
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not frozen)
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
	setPlayerFrozen(true)

	local function finish(power: number?)
		if not active then
			return
		end
		active = false
		(screenGui :: ScreenGui).Enabled = false
		setPlayerFrozen(false)
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

		if frozenCFrame then
			local root = getRootPart()
			if root then
				root.CFrame = frozenCFrame
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end
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
