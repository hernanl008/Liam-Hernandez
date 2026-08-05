--!strict
-- Placeholder 3D fishing performance (GDD.md §3) — a rod + a "fish"
-- block, animated purely with per-frame CFrame math (the same
-- Heartbeat-driven "recompute position every frame" pattern
-- PlayerFreeze.lua uses, not TweenService), since there's no real rig
-- animation asset to play yet. Client-only/local-only: built and
-- destroyed per local player, not replicated to anyone else watching —
-- a multiplayer-visible version is a later step, this is "something is
-- visibly happening" for now.
--
-- Rod: two plain anchored Parts (a wood-colored pole + a dark metal tip
-- ball), held at a fixed offset from the character's HumanoidRootPart
-- rather than an actual hand — R6 vs R15 name their arm parts
-- differently ("Right Arm" vs "RightHand") and this project already hit
-- a rig-assumption surprise once (PlayerFreeze's PlayerModule lookup);
-- anchoring off the root instead sidesteps that class of bug entirely.
-- Fish: a single colored Part, manually Lerp'd from a start position
-- (the water, if a FishingSpot part is known) to the rod tip over the
-- reel's duration, with a sine-wave wiggle added on top so it doesn't
-- travel in a dead-straight line.
--
-- Swap the rod/fish Parts for real meshes whenever real art exists —
-- this module's public API (equipRod/bite/startReel/endReel/unequipRod)
-- doesn't need to change when that happens.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FishingRig = {}

local ROD_LENGTH = 5
-- Relative to HumanoidRootPart: held out to the character's right side,
-- angled forward-down, like casting toward water in front of them.
local ROD_HOLD_OFFSET = CFrame.new(0.9, 0.2, -0.7) * CFrame.Angles(math.rad(-55), math.rad(25), 0)

local rodModel: Model? = nil
local rodPole: BasePart? = nil
local rodTip: BasePart? = nil
local followConn: RBXScriptConnection? = nil

local biting = false
local biteStartTime = 0
local reeling = false

local fishPart: BasePart? = nil
local fishConn: RBXScriptConnection? = nil
local waterAnchor: BasePart? = nil

local function getRootCFrame(): CFrame?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.CFrame
	end
	return nil
end

local function computeHeldCFrame(): CFrame?
	local rootCFrame = getRootCFrame()
	if not rootCFrame then
		return nil
	end
	local held = rootCFrame * ROD_HOLD_OFFSET
	-- A short dip right after a bite (visual "something just tugged the
	-- line" cue) and a steady pull-and-release bob while actively
	-- reeling — both computed as an extra rotation added on top of the
	-- held pose each frame, never a separate tween, so they can't fight
	-- the continuous re-positioning below (the same class of bug
	-- PlayerFreeze's WalkSpeed fix was chasing — a one-off tween gets
	-- silently overwritten the very next frame by whatever's re-driving
	-- CFrame every Heartbeat).
	local wobble = 0
	if biting then
		local elapsed = os.clock() - biteStartTime
		if elapsed < 0.35 then
			wobble = math.sin(elapsed / 0.35 * math.pi) * math.rad(20)
		else
			biting = false
		end
	elseif reeling then
		wobble = math.sin(os.clock() * 7) * math.rad(10)
	end
	return held * CFrame.Angles(wobble, 0, 0)
end

local function buildRod(): (Model, BasePart, BasePart)
	local model = Instance.new("Model")
	model.Name = "FishingRodPlaceholder"

	local pole = Instance.new("Part")
	pole.Name = "Pole"
	pole.Size = Vector3.new(0.15, 0.15, ROD_LENGTH)
	pole.Color = Color3.fromRGB(96, 64, 36)
	pole.Material = Enum.Material.Wood
	pole.CanCollide = false
	pole.CanQuery = false
	pole.Anchored = true
	pole.Parent = model

	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.2, 0.2, 0.2)
	tip.Color = Color3.fromRGB(40, 40, 40)
	tip.Material = Enum.Material.Metal
	tip.CanCollide = false
	tip.CanQuery = false
	tip.Anchored = true
	tip.Parent = model

	model.Parent = Workspace
	return model, pole, tip
end

-- `spotPart`, if given, is the FishingSpot the player cast into — used
-- as the "water" origin the fish swims from once reeling starts.
function FishingRig.equipRod(spotPart: BasePart?)
	if rodModel then
		return
	end
	waterAnchor = spotPart

	local model, pole, tip = buildRod()
	rodModel = model
	rodPole = pole
	rodTip = tip

	followConn = RunService.Heartbeat:Connect(function()
		local held = computeHeldCFrame()
		if not held or not rodPole or not rodTip then
			return
		end
		rodPole.CFrame = held * CFrame.new(0, 0, -ROD_LENGTH / 2)
		rodTip.CFrame = held * CFrame.new(0, 0, -ROD_LENGTH)
	end)
end

function FishingRig.unequipRod()
	FishingRig.endReel(false)
	biting = false
	reeling = false
	if followConn then
		followConn:Disconnect()
		followConn = nil
	end
	if rodModel then
		rodModel:Destroy()
		rodModel = nil
		rodPole = nil
		rodTip = nil
	end
	waterAnchor = nil
end

-- Rod-tip dip timed with FishBite's "something's biting, press E!" toast.
function FishingRig.bite()
	if not rodModel then
		return
	end
	biting = true
	biteStartTime = os.clock()
end

-- Spawns the placeholder fish at the water and starts it swimming toward
-- the rod tip over `durationSeconds` (FishingController passes the same
-- length RhythmUI computes for the reel-in chart, so the fish physically
-- arrives right as the minigame ends). `reeling = true` also drives the
-- rod's pull-and-release bob for the same span via computeHeldCFrame.
function FishingRig.startReel(durationSeconds: number)
	if not rodModel then
		return
	end
	biting = false
	reeling = true

	if fishConn then
		fishConn:Disconnect()
		fishConn = nil
	end
	if fishPart then
		fishPart:Destroy()
		fishPart = nil
	end

	local rootCFrame = getRootCFrame()
	local startCFrame = waterAnchor and (waterAnchor.CFrame + Vector3.new(0, 0.4, 0))
		or (rootCFrame and rootCFrame * CFrame.new(0, -0.5, -10))
	if not startCFrame then
		reeling = false
		return
	end

	local fish = Instance.new("Part")
	fish.Name = "FishingCatchPlaceholder"
	fish.Size = Vector3.new(1, 0.5, 0.5)
	fish.Color = Color3.fromRGB(120, 170, 210)
	fish.Material = Enum.Material.SmoothPlastic
	fish.CanCollide = false
	fish.CanQuery = false
	fish.Anchored = true
	fish.CFrame = startCFrame
	fish.Parent = Workspace
	fishPart = fish

	local startTime = os.clock()
	fishConn = RunService.Heartbeat:Connect(function()
		if not fishPart then
			return
		end
		local heldNow = computeHeldCFrame()
		if not heldNow then
			return
		end
		local targetPosition = (heldNow * CFrame.new(0, 0, -ROD_LENGTH)).Position
		local alpha = math.clamp((os.clock() - startTime) / math.max(durationSeconds, 0.1), 0, 1)
		local basePosition = startCFrame.Position:Lerp(targetPosition, alpha)
		-- Side-to-side thrash, tapering off as it nears the rod tip so it
		-- doesn't look like it's still fighting once it's basically caught.
		local wiggle = math.sin(os.clock() * 10) * 0.6 * (1 - alpha)
		local right = heldNow.RightVector
		fishPart.CFrame = CFrame.new(basePosition + right * wiggle, targetPosition) * CFrame.Angles(0, math.rad(90), 0)
	end)
end

-- `success`: true if the fish was actually landed (it arrives at the rod
-- tip and pops); false for a miss/escape (it darts away and vanishes).
-- Safe to call even if startReel was never called (e.g. unequipRod's own
-- cleanup calling this defensively) — no-ops when there's no fish.
function FishingRig.endReel(success: boolean)
	reeling = false
	if fishConn then
		fishConn:Disconnect()
		fishConn = nil
	end
	local fish = fishPart
	if not fish then
		return
	end
	fishPart = nil

	if success then
		task.delay(0.15, function()
			fish:Destroy()
		end)
	else
		local escapeConn: RBXScriptConnection
		local startTime = os.clock()
		local startPosition = fish.Position
		local awayDirection = (fish.Position - (getRootCFrame() and (getRootCFrame() :: CFrame).Position or fish.Position))
		if awayDirection.Magnitude < 0.01 then
			awayDirection = Vector3.new(0, 0, -1)
		else
			awayDirection = awayDirection.Unit
		end
		escapeConn = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - startTime
			if elapsed >= 0.4 then
				escapeConn:Disconnect()
				fish:Destroy()
				return
			end
			fish.CFrame = CFrame.new(startPosition + awayDirection * (elapsed / 0.4) * 12)
		end)
	end
end

return FishingRig
