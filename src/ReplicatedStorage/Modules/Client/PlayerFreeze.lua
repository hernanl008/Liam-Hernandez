--!strict
-- Plants the local player in place for the duration of a minigame
-- (cast-power meter, fishing reel-in, cooking rhythm chart) — shared so
-- the debugging that went into getting this right happens once, not
-- once per minigame.
--
-- Three things turned out to be necessary, found the hard way via live
-- debug logging on an actual Studio session:
--   1. Re-pinning the HumanoidRootPart's CFrame every Heartbeat frame
--      undoes any actual net displacement — confirmed via logging that
--      the frozen position never drifted across an entire multi-second
--      test, regardless of what tried to move it.
--   2. WalkSpeed still has to be zeroed too, even with the position pin
--      in place — otherwise the Humanoid still *tries* to walk and
--      plays its running animation in place every frame (a few
--      hundredths of a stud of movement per frame, caught and undone
--      before it can accumulate, but visible as constant jitter/an
--      animated "walking in place" look), which reads as "I can still
--      move" even though the character never actually goes anywhere.
--   3. Space (jump) specifically needs its *input* blocked, not just
--      Humanoid:SetStateEnabled(Jumping, false) — that alone was proven
--      insufficient earlier (this project's jump doesn't respond
--      reliably to the state disable on its own, for reasons never
--      fully identified). Sunk via ContextActionService at a higher
--      priority than Roblox's own jump control. The position pin also
--      catches any residual upward displacement as a backstop, but
--      sinking the input outright avoids the visible "hop" a jump's
--      initial velocity would otherwise cause for one frame before the
--      pin corrects it.
--
-- Sinking Space here (not sinking WASD — tried and abandoned earlier;
-- see git history) is safe for every current caller: RhythmUI's lane
-- keys are D/F/J/K, never Space, so there's nothing to conflict with
-- there. CastMeterUI *does* need to know when Space is pressed (to lock
-- its meter) — pass a callback to `start()` and it fires from inside
-- this same sunk handler, instead of keeping a second, separate
-- UserInputService listener for the same key (confirmed earlier that a
-- sunk ContextAction input doesn't reliably reach a parallel
-- UserInputService.InputBegan listener, which broke the lock outright
-- when tried that way).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local PlayerFreeze = {}

local SPACE_ACTION = "PlayerFreezeBlockJump"

local frozenCFrame: CFrame? = nil
local savedWalkSpeed: number? = nil
local heartbeatConn: RBXScriptConnection? = nil

local function getRootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- `onSpacePressed` (optional) fires when Space is pressed while frozen —
-- CastMeterUI uses this to lock its meter; callers with no use for Space
-- (RhythmUI) can omit it and Space is simply blocked with no other effect.
function PlayerFreeze.start(onSpacePressed: (() -> ())?)
	if heartbeatConn then
		return -- already frozen (nested start() calls collapse into one)
	end

	local root = getRootPart()
	frozenCFrame = root and root.CFrame

	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		savedWalkSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
	end

	ContextActionService:BindActionAtPriority(
		SPACE_ACTION,
		function(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin and onSpacePressed then
				onSpacePressed()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space
	)

	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not frozenCFrame then
			return
		end
		local currentRoot = getRootPart()
		if currentRoot then
			currentRoot.CFrame = frozenCFrame
			currentRoot.AssemblyLinearVelocity = Vector3.zero
			currentRoot.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

function PlayerFreeze.stop()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	frozenCFrame = nil
	ContextActionService:UnbindAction(SPACE_ACTION)

	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		if savedWalkSpeed then
			humanoid.WalkSpeed = savedWalkSpeed
		end
	end
	savedWalkSpeed = nil
end

-- Whether the player is currently frozen for a minigame (cast meter or
-- reel-in/cooking chart) — the single source of truth other UI
-- (Compendium/Shop/Inventory/Settings/SkillTree controllers) checks
-- before opening a full-screen panel on top of one.
function PlayerFreeze.isActive(): boolean
	return heartbeatConn ~= nil
end

return PlayerFreeze
