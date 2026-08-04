--!strict
-- Plants the local player in place for the duration of a minigame
-- (cast-power meter, fishing reel-in, cooking rhythm chart) — shared so
-- the debugging that went into getting this right happens once, not
-- once per minigame.
--
-- Two things turned out to both be necessary, found the hard way via
-- live debug logging on an actual Studio session:
--   1. Re-pinning the HumanoidRootPart's CFrame every Heartbeat frame
--      (not SetStateEnabled/WalkSpeed alone — this project's character
--      movement didn't respond reliably to either) undoes any actual
--      net displacement, confirmed via logging that the frozen position
--      never drifted across an entire multi-second test.
--   2. WalkSpeed still has to be zeroed too, even though the position
--      pin alone stops net movement — otherwise the Humanoid still
--      *tries* to walk and plays its running animation in place every
--      frame (a few hundredths of a stud of movement per frame, caught
--      and undone before it can accumulate, but visible as constant
--      jitter/an animated "walking in place" look), which reads as "I
--      can still move" even though the character never actually goes
--      anywhere.
-- Position-pinning (not sinking input via ContextActionService, tried
-- and abandoned earlier) deliberately doesn't consume any key presses —
-- callers with their own input needs during the freeze (e.g. RhythmUI's
-- D/F/J/K lane keys, where D is also a movement key) keep working
-- unaffected.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerFreeze = {}

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

function PlayerFreeze.start()
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
