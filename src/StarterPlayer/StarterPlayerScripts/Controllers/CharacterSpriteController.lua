--!strict
-- Swaps every character (local player AND everyone else on the server —
-- this runs per-character on the client, not just for LocalPlayer, so a
-- multiplayer server reads as sprites for everyone, not "I see myself as
-- 3D but others as 2D" or vice versa) from a normal Roblox 3D avatar to
-- a 2D pixel-art billboard sprite. GDD.md §15: Liam supplied real
-- Idle.png/Walk.png character sheets early on, but wiring them in was
-- explicitly deferred as "the bigger, separately-tracked fallback" from
-- the original "keep the avatar 3D for now" decision (§6/§14). This is
-- that fallback, now built.
--
-- Sheets (assets/sprites/player_idle.png, player_walk.png — visually
-- inspected, not just inferred from frame geometry): both are 32x32-px
-- cells, 3 rows, in the standard convention for this style of asset
-- pack — row 1 faces the camera (down), row 2 is a side profile, row 3
-- faces away (up). Idle has 4 columns (walk 6). The side row's default
-- facing (left vs right) was eyeballed from a small thumbnail, not
-- confirmed pixel-by-pixel — if characters look like they're moonwalking
-- sideways in Studio, flip SIDE_ROW_FACES_LEFT below; that's the only
-- thing that'd need to change.
--
-- Technique: every BasePart/Accessory on the character goes fully
-- transparent (the Humanoid/HumanoidRootPart stay — still needed for
-- movement, collision, and everything else in this game that reads
-- HumanoidRootPart.CFrame, e.g. CameraController.lua and
-- PlayerFreeze.lua, neither of which needed to change for this), and a
-- BillboardGui with an ImageLabel takes over as the actual visual.
-- BillboardGui.Size's Scale component is interpreted in *studs* (a real
-- Roblox quirk, not a typo) rather than the 0-1 fraction every other
-- GuiObject uses, which is what makes the sprite correctly shrink/grow
-- with camera distance like a real 3D object instead of staying a fixed
-- screen size. A BillboardGui always renders flat-on to the camera
-- regardless of camera angle — under this game's fixed, never-rotating
-- top-down camera (CameraController.lua) that reads as a classic
-- "upright 2D sprite standee," the same convention Stardew Valley itself
-- uses, without needing any manual camera-facing math.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("AssetIds"))

local CharacterSpriteController = {}

local FRAME_SIZE = 32
local IDLE_COLUMNS = 4
local WALK_COLUMNS = 6
local ROW_DOWN = 0
local ROW_SIDE = 1
local ROW_UP = 2
local IDLE_FPS = 4
local WALK_FPS = 10
local MOVE_THRESHOLD = 0.05 -- Humanoid.MoveDirection magnitude below this counts as "standing still"

-- Eyeballed from the sheet thumbnail, not pixel-confirmed — flip if the
-- side-facing walk looks mirrored in Studio.
local SIDE_ROW_FACES_LEFT = true

-- Character height convention this game's already settled on
-- (MapConfig.lua's PropSpot comment: props were sized "next to an
-- ~5-stud-tall player") — the billboard is sized to roughly match, not
-- derived from the actual (now-hidden) rig's real height.
local SPRITE_HEIGHT_STUDS = 4.5
local SPRITE_WIDTH_STUDS = 4.5
local GROUND_OFFSET_STUDS = -1.4 -- nudges the billboard down so its feet roughly meet the ground instead of floating at root height

local function hideCharacterParts(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		end
	end
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		end
	end)
end

local function buildBillboard(rootPart: BasePart): ImageLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CharacterSprite"
	billboard.Size = UDim2.fromScale(SPRITE_WIDTH_STUDS, SPRITE_HEIGHT_STUDS)
	billboard.StudsOffset = Vector3.new(0, GROUND_OFFSET_STUDS, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Parent = rootPart

	local image = Instance.new("ImageLabel")
	image.Name = "Sprite"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	-- Stretch (the default), not Crop: with ImageRectSize set, Stretch
	-- maps exactly the selected 32x32 sheet cell onto the label. The
	-- label is square and the cell is square, so nothing distorts.
	image.ScaleType = Enum.ScaleType.Stretch
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	image.ImageRectSize = Vector2.new(FRAME_SIZE, FRAME_SIZE)
	image.Parent = billboard
	return image
end

local function applySprite(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not rootPart or not humanoid:IsA("Humanoid") or not rootPart:IsA("BasePart") then
		return
	end

	hideCharacterParts(character)
	local image = buildBillboard(rootPart)

	local lastRow = ROW_DOWN
	local lastFlip = false
	local currentSheetIsWalk: boolean? = nil -- forces the first frame's Image assignment
	local frameTimer = 0

	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if not character.Parent or not rootPart.Parent then
			conn:Disconnect()
			return
		end

		local moveDirection = humanoid.MoveDirection
		local moving = moveDirection.Magnitude > MOVE_THRESHOLD

		local row = lastRow
		local flip = lastFlip
		if moving then
			if math.abs(moveDirection.X) > math.abs(moveDirection.Z) then
				row = ROW_SIDE
				local facingRight = moveDirection.X > 0
				flip = if SIDE_ROW_FACES_LEFT then facingRight else not facingRight
			else
				row = if moveDirection.Z > 0 then ROW_DOWN else ROW_UP
				flip = false
			end
			lastRow = row
			lastFlip = flip
		end

		local columns = if moving then WALK_COLUMNS else IDLE_COLUMNS
		local fps = if moving then WALK_FPS else IDLE_FPS
		frameTimer += dt
		local column = math.floor(frameTimer * fps) % columns

		if currentSheetIsWalk ~= moving then
			image.Image = AssetIds.sprite(if moving then "player_walk" else "player_idle")
			currentSheetIsWalk = moving
		end
		image.ImageRectOffset = Vector2.new(column * FRAME_SIZE, row * FRAME_SIZE)
		image.Size = UDim2.fromScale(flip and -1 or 1, 1)
	end)
end

function CharacterSpriteController.init()
	-- Hard gate: if the sheets haven't been uploaded yet (AssetIds falls
	-- back to rbxassetid://0 — tarmac sync / manual upload is a Liam-only
	-- step, see tarmac.toml), do NOTHING. Hiding the 3D character while
	-- the sprite renders as a blank image would make every character
	-- literally invisible — the exact class of bug this session already
	-- chased once with the Neon/bloom washout. 3D avatars stay until the
	-- art actually exists; upload player_idle.png/player_walk.png, sync,
	-- and this activates on its own with no code change.
	if AssetIds.sprite("player_idle") == "rbxassetid://0" or AssetIds.sprite("player_walk") == "rbxassetid://0" then
		warn("[CharacterSpriteController] player_idle/player_walk sprites not uploaded yet — keeping 3D avatars until they are.")
		return
	end

	local function onPlayer(player: Player)
		if player.Character then
			applySprite(player.Character)
		end
		player.CharacterAdded:Connect(applySprite)
	end

	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return CharacterSpriteController
