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
-- Rod: a flat sprite standee (assets/sprites/fishing_rod.png, drawn by
-- tools/make_fishing_rod_sprite.py since the asset pack has no rod),
-- falling back to two plain anchored Parts (wood-colored pole + gold tip
-- ball) for as long as that sprite hasn't been uploaded. Either way it's
-- held at a fixed offset from the character's HumanoidRootPart rather
-- than an actual hand — R6 vs R15 name their arm parts differently
-- ("Right Arm" vs "RightHand") and this project already hit a
-- rig-assumption surprise once (PlayerFreeze's PlayerModule lookup);
-- anchoring off the root instead sidesteps that class of bug entirely.
-- Fish: a flat, thin, unrotated Part with a Decal on its Back face — the
-- exact same "camera-facing sprite standee" convention MapBuilder.lua's
-- placeProps already uses for every tree/house/animal in the game
-- (CameraController's camera is fixed and never rotates, so an unrotated
-- part's Back face is reliably always what's on screen; no per-frame
-- "face the camera" math needed). AssetIds.sprite("fish_generic") has no
-- uploaded art yet so the Decal is currently blank — the Part's own
-- bright color is what's actually visible right now; the Decal slot is
-- just sitting there ready to pick up real fish art later with no code
-- changes, same as every other sprite in this game. Manually Lerp'd from
-- a start position (the water, if a FishingSpot part is known) to the
-- rod tip over the reel's duration, with a sine-wave wiggle added on top
-- so it doesn't travel in a dead-straight line.
--
-- Deliberately NOT Enum.Material.Neon despite wanting these to pop:
-- Neon renders overbright specifically to trigger bloom (AtmosphereService
-- .lua's BloomEffect, Threshold = 1.4), and a large bright Neon surface
-- held right above the character for the "holding it up" beat plausibly
-- blooms out that whole region of the screen — which reads as "my
-- character turned invisible," not as "cool glow." Saturated
-- SmoothPlastic gets the contrast without the HDR overexposure risk.
--
-- Swap the rod/fish Parts for real meshes whenever real art exists —
-- this module's public API (equipRod/bite/startReel/endReel/unequipRod)
-- doesn't need to change when that happens.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("AssetIds"))

local FishingRig = {}

-- Sized/angled for THIS game's actual camera (CameraController.lua: a
-- fixed 3/4 top-down view ~44 studs away — sqrt(38^2 + 22^2) — at a
-- steep ~60 degree downward pitch), not a third-person/close-up camera.
-- The first pass used realistic proportions (a 0.15-stud-thick pole
-- angled -55 degrees, almost straight down) that were essentially
-- invisible at this distance/angle — a thin near-vertical line
-- foreshortens to almost nothing viewed from steeply above. Both the
-- rod and the fish below are deliberately oversized and high-contrast
-- instead: a shallow hold angle so the rod's length actually reads as a
-- line across the screen, and saturated, high-contrast colors on the
-- tip/fish so they stay clearly visible without relying on Neon/bloom
-- (see the header comment above for why that backfired).
local ROD_LENGTH = 7
local ROD_HOLD_OFFSET = CFrame.new(0.9, 0.6, -0.8) * CFrame.Angles(math.rad(-20), math.rad(20), 0)

local rodModel: Model? = nil
local rodPole: BasePart? = nil
local rodTip: BasePart? = nil
local rodIsSprite = false
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

-- Shared by startReel/snagPull/splash — wherever something is meant to
-- rise from or appear at "the water": the FishingSpot part if one was
-- passed to equipRod, else a fallback point in front of the character.
local function getWaterOrigin(): CFrame?
	if waterAnchor then
		return waterAnchor.CFrame + Vector3.new(0, 0.4, 0)
	end
	local rootCFrame = getRootCFrame()
	return rootCFrame and rootCFrame * CFrame.new(0, -0.5, -10)
end

-- The rod's current animation angle, in radians: a short dip right after
-- a bite (visual "something just tugged the line" cue), or a steady
-- pull-and-release bob while actively reeling. Recomputed from the clock
-- every frame rather than driven by a tween — a one-off tween would get
-- silently overwritten the very next frame by whatever's re-driving the
-- rod's CFrame on Heartbeat (the same class of bug PlayerFreeze's
-- WalkSpeed fix was chasing). Shared by both rod looks: the 3D pole
-- applies it as a pitch, the sprite as an in-plane roll.
local function currentWobble(): number
	if biting then
		local elapsed = os.clock() - biteStartTime
		if elapsed < 0.35 then
			return math.sin(elapsed / 0.35 * math.pi) * math.rad(20)
		end
		biting = false
		return 0
	elseif reeling then
		return math.sin(os.clock() * 7) * math.rad(10)
	end
	return 0
end

local function computeHeldCFrame(): CFrame?
	local rootCFrame = getRootCFrame()
	if not rootCFrame then
		return nil
	end
	return rootCFrame * ROD_HOLD_OFFSET * CFrame.Angles(currentWobble(), 0, 0)
end

-- Two rod looks. Preferred: a single flat sprite standee (assets/sprites/
-- fishing_rod.png), matching the now-2D-sprite player character and the
-- Decal-standee convention MapBuilder.placeProps uses for every prop.
-- Fallback: the original 3D pole + tip ball, kept for exactly as long as
-- the rod sprite hasn't been uploaded — a Decal pointed at an
-- unuploaded asset renders nothing, and an invisible rod is strictly
-- worse than a blocky one (same "don't remove the fallback until the
-- replacement is confirmed" rule CharacterSpriteController learned the
-- hard way).
local function buildRod(): (Model, BasePart, BasePart?)
	local model = Instance.new("Model")
	model.Name = "FishingRodPlaceholder"

	local spriteId = AssetIds.sprite("fishing_rod")
	if spriteId ~= "rbxassetid://0" then
		rodIsSprite = true
		local sprite = Instance.new("Part")
		sprite.Name = "RodSprite"
		sprite.Size = Vector3.new(ROD_LENGTH * 0.8, ROD_LENGTH * 0.8, 0.15)
		sprite.Transparency = 0.999 -- see placeProps: 1.0 from birth suppresses the Decal too
		sprite.CanCollide = false
		sprite.CanQuery = false
		sprite.Anchored = true
		sprite.Parent = model

		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Back
		decal.Texture = spriteId
		decal.Parent = sprite

		model.Parent = Workspace
		return model, sprite, nil
	end

	rodIsSprite = false
	local pole = Instance.new("Part")
	pole.Name = "Pole"
	pole.Size = Vector3.new(0.4, 0.4, ROD_LENGTH)
	pole.Color = Color3.fromRGB(150, 100, 55)
	pole.Material = Enum.Material.Wood
	pole.CanCollide = false
	pole.CanQuery = false
	pole.Anchored = true
	pole.Parent = model

	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.7, 0.7, 0.7)
	tip.Color = Color3.fromRGB(255, 210, 70)
	tip.Material = Enum.Material.SmoothPlastic
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
		if not held or not rodPole then
			return
		end
		if rodIsSprite then
			-- Position only, plus a roll about the part's OWN Z axis. Z is
			-- the axis the Decal's Back face points along, so rolling around
			-- it tilts the rod image in-plane without ever turning the face
			-- away from the fixed camera — the wobble still reads, and the
			-- sprite never foreshortens into a sliver.
			local midpoint = (held * CFrame.new(0, 0, -ROD_LENGTH / 2)).Position
			rodPole.CFrame = CFrame.new(midpoint) * CFrame.Angles(0, 0, currentWobble())
		else
			rodPole.CFrame = held * CFrame.new(0, 0, -ROD_LENGTH / 2)
			if rodTip then
				rodTip.CFrame = held * CFrame.new(0, 0, -ROD_LENGTH)
			end
		end
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
	FishingRig.splash()
end

-- A flat expanding, fading disc at the water surface — the "something
-- broke the surface" cue for a bite, plain geometry (a Cylinder Part
-- laid flat) rather than a ParticleEmitter, so it doesn't depend on
-- Roblox's default particle texture looking right at this scale/camera.
function FishingRig.splash()
	local origin = getWaterOrigin()
	if not origin then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "FishingSplashPlaceholder"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 0.6, 0.6)
	ring.CFrame = origin * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(235, 245, 255)
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.35
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Anchored = true
	ring.Parent = Workspace

	local startTime = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= 0.5 then
			conn:Disconnect()
			ring:Destroy()
			return
		end
		local alpha = elapsed / 0.5
		ring.Size = Vector3.new(0.15, 0.6 + alpha * 5, 0.6 + alpha * 5)
		ring.Transparency = 0.35 + alpha * 0.65
	end)
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

	local startCFrame = getWaterOrigin()
	if not startCFrame then
		reeling = false
		return
	end

	local fish = Instance.new("Part")
	fish.Name = "FishingCatchPlaceholder"
	fish.Size = Vector3.new(2.4, 1.1, 0.15)
	fish.Color = Color3.fromRGB(70, 180, 245)
	fish.Material = Enum.Material.SmoothPlastic
	fish.CanCollide = false
	fish.CanQuery = false
	fish.Anchored = true
	-- Position only, no rotation applied (or ever set again below) — a
	-- fixed orientation is exactly what keeps the Decal's Back face
	-- reliably camera-facing under this game's locked camera angle.
	fish.CFrame = CFrame.new(startCFrame.Position)
	fish.Parent = Workspace
	fishPart = fish

	local fishDecal = Instance.new("Decal")
	fishDecal.Face = Enum.NormalId.Back
	fishDecal.Texture = AssetIds.sprite("fish_generic")
	fishDecal.Parent = fish

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
		-- Side-to-side thrash (perpendicular to the straight-line path to
		-- the rod tip), tapering off as it nears the tip so it doesn't
		-- look like it's still fighting once it's basically caught.
		local travel = targetPosition - startCFrame.Position
		local perpendicular = if travel.Magnitude > 0.01
			then Vector3.new(-travel.Unit.Z, 0, travel.Unit.X)
			else Vector3.new(1, 0, 0)
		local wiggle = math.sin(os.clock() * 10) * 0.6 * (1 - alpha)
		fishPart.CFrame = CFrame.new(basePosition + perpendicular * wiggle)
	end)
end

-- Above and just in front of the character's head — "holding the catch
-- up," the beat between "reeled it in" and the celebration effects. Live
-- root-relative rather than a position captured once, so it keeps
-- tracking correctly even if the player moves during the hold (they're
-- not frozen for this — PlayerFreeze already released them the moment
-- the 2D minigame ended, well before this 3D beat even starts).
local HELD_OFFSET = CFrame.new(0, 3.4, -0.6)
local HELD_RISE_SECONDS = 0.35
local HELD_HOLD_SECONDS = 1.0

-- `success`: true if the fish was actually landed — it rises to a held-
-- up pose in front of the character, pauses there, then pops; false for
-- a miss/escape — it darts away and vanishes instead. `onComplete` (if
-- given) fires once that beat is fully finished, so a caller can time
-- celebration effects to land *after* the physical catch instead of
-- racing it — including the "no fish existed at all" cases (a Pull or a
-- ZoneLocked rejection never called startReel), where it just fires
-- immediately since there's nothing to animate.
-- Safe to call even if startReel was never called (e.g. unequipRod's own
-- cleanup calling this defensively) — no-ops (past firing onComplete)
-- when there's no fish.
function FishingRig.endReel(success: boolean, onComplete: (() -> ())?)
	reeling = false
	if fishConn then
		fishConn:Disconnect()
		fishConn = nil
	end
	local fish = fishPart
	if not fish then
		if onComplete then
			onComplete()
		end
		return
	end
	fishPart = nil

	if success then
		local startTime = os.clock()
		local risePosition = fish.Position
		local holdConn: RBXScriptConnection
		holdConn = RunService.Heartbeat:Connect(function()
			local rootCFrame = getRootCFrame()
			if not rootCFrame then
				return
			end
			local heldTarget = (rootCFrame * HELD_OFFSET).Position
			local elapsed = os.clock() - startTime
			if elapsed < HELD_RISE_SECONDS then
				local alpha = elapsed / HELD_RISE_SECONDS
				fish.CFrame = CFrame.new(risePosition:Lerp(heldTarget, alpha))
			elseif elapsed < HELD_RISE_SECONDS + HELD_HOLD_SECONDS then
				-- A small triumphant bob while held up, instead of sitting
				-- dead still.
				local bob = math.sin((elapsed - HELD_RISE_SECONDS) * 4) * 0.1
				fish.CFrame = CFrame.new(heldTarget + Vector3.new(0, bob, 0))
			else
				holdConn:Disconnect()
				fish:Destroy()
				if onComplete then
					onComplete()
				end
			end
		end)
	else
		local escapeConn: RBXScriptConnection
		local startTime = os.clock()
		local startPosition = fish.Position
		local rootCFrame = getRootCFrame()
		local awayDirection = fish.Position - (rootCFrame and rootCFrame.Position or fish.Position)
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
				if onComplete then
					onComplete()
				end
				return
			end
			fish.CFrame = CFrame.new(startPosition + awayDirection * (elapsed / 0.4) * 12)
		end)
	end
end

local SNAG_SECONDS = 0.5

-- A junk/treasure "Pull" never calls startReel — the server resolves it
-- immediately, no reel-in chart — so it previously had zero animation at
-- all, unlike every other outcome. This gives it its own quick beat: the
-- rod dips hard (reusing the same `biting` wobble bite() uses) while a
-- small snag prop rises straight to the rod tip and spins once, then
-- pops. `isTreasure` just picks the color (gold vs. driftwood-brown) —
-- no separate geometry, still a placeholder either way.
function FishingRig.snagPull(onComplete: (() -> ())?, isTreasure: boolean?)
	if not rodModel then
		if onComplete then
			onComplete()
		end
		return
	end
	biting = true
	biteStartTime = os.clock()

	local startCFrame = getWaterOrigin()
	if not startCFrame then
		if onComplete then
			onComplete()
		end
		return
	end

	local snag = Instance.new("Part")
	snag.Name = "FishingPullPlaceholder"
	snag.Size = Vector3.new(0.9, 0.9, 0.9)
	snag.Color = isTreasure and Color3.fromRGB(255, 215, 80) or Color3.fromRGB(120, 100, 80)
	snag.Material = Enum.Material.SmoothPlastic
	snag.CanCollide = false
	snag.CanQuery = false
	snag.Anchored = true
	snag.CFrame = startCFrame
	snag.Parent = Workspace

	local startTime = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local heldNow = computeHeldCFrame()
		if not heldNow then
			return
		end
		local elapsed = os.clock() - startTime
		if elapsed >= SNAG_SECONDS then
			conn:Disconnect()
			snag:Destroy()
			if onComplete then
				onComplete()
			end
			return
		end
		local alpha = elapsed / SNAG_SECONDS
		local targetPosition = (heldNow * CFrame.new(0, 0, -ROD_LENGTH)).Position
		local position = startCFrame.Position:Lerp(targetPosition, alpha)
		snag.CFrame = CFrame.new(position) * CFrame.Angles(0, alpha * math.rad(360), 0)
	end)
end

return FishingRig
