--!strict
-- Cast-power meter (GDD.md §3), previously punted on — see the removed
-- header comment in FishingController.lua explaining it needed a server-
-- side consumer first (FishingService.RequestCast now takes a castPower
-- argument). A vertical fill bar ping-pongs 0->1->0; pressing Space locks
-- in whatever power it's at, same skill-based "stop the moving bar" beat
-- as the reel-in minigame but simpler (one axis, no scoring window).
--
-- While the meter is up, the player is meant to be planted in place —
-- three earlier attempts at blocking movement/jump piecemeal
-- (SetStateEnabled(Jumping, false), WalkSpeed = 0, sinking individual
-- keys through ContextActionService) each fixed one symptom without
-- fully working, most likely because Roblox's default WASD movement
-- polls key state directly each frame rather than reacting to bound
-- actions the way jump does — sinking specific keys never touched it,
-- and the sinking itself turned out to suppress the plain
-- UserInputService listener this module used to detect the Space lock,
-- breaking that instead. The actual fix is PlayerModule's Controls
-- object (GetControls():Disable()/:Enable()) — Roblox's own documented
-- "turn off all default character input at once" API — which sidesteps
-- both problems: it's the real mechanism games use for this, and it
-- doesn't interfere with this module's own plain UserInputService
-- listener for Space/Escape (a separate, independent system).

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

-- Resolved once, lazily, the first time it's needed rather than at
-- module load — PlayerScripts/PlayerModule should already exist by then
-- (this module is only ever required from a Controller that's already
-- running under StarterPlayerScripts), but there's no reason to risk a
-- module-load-time failure over it given this session's history with
-- exactly that failure mode. nil if PlayerModule can't be found/required
-- (e.g. this project's source tree doesn't track it under
-- StarterPlayerScripts, so it depends on whatever Rojo's sync leaves in
-- place) — setPlayerFrozen falls back to the Humanoid-level attempts
-- below in that case, better than nothing even if not fully reliable.
local controlsResolved = false
local controls: any = nil

local function getControls(): any
	if controlsResolved then
		return controls
	end
	controlsResolved = true
	local ok, result = pcall(function()
		local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts", 5)
		local playerModuleScript = playerScripts and playerScripts:FindFirstChild("PlayerModule")
		if not playerModuleScript then
			return nil
		end
		local playerModule = require(playerModuleScript :: ModuleScript) :: any
		return playerModule:GetControls()
	end)
	if ok then
		controls = result
	end
	return controls
end

local savedWalkSpeed: number? = nil

local function setPlayerFrozen(frozen: boolean)
	local resolvedControls = getControls()
	if resolvedControls then
		if frozen then
			resolvedControls:Disable()
		else
			resolvedControls:Enable()
		end
	end

	-- Backup layer in case Controls couldn't be resolved — not fully
	-- reliable on its own (see the header comment) but better than
	-- nothing.
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not frozen)
		if frozen then
			savedWalkSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = 0
		elseif savedWalkSpeed then
			humanoid.WalkSpeed = savedWalkSpeed
			savedWalkSpeed = nil
		end
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
	end)

	-- Plain input listener — Controls:Disable() above handles keeping
	-- Roblox's own jump/movement from firing, so there's nothing this
	-- needs to Sink or race against anymore.
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
