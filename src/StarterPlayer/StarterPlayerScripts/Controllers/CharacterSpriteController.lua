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
-- pack — see the ROW_* constants below for the verified row order. Idle
-- has 4 columns (walk 6).
--
-- Known limitation: the side row is used as-is for BOTH left and right,
-- so walking one of those two directions shows the character facing the
-- wrong way. The obvious fix — a negative ImageLabel.Size to mirror it —
-- does not work in Roblox: a negative GuiObject size renders *nothing*
-- rather than flipping (it was written that way first and had to be
-- removed). Proper fix is a pre-mirrored copy of each sheet, which means
-- two more PNGs through the human-only upload step, so it's deferred
-- rather than faked.
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
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("AssetIds"))

local CharacterSpriteController = {}

local FRAME_SIZE = 32
local IDLE_COLUMNS = 4
local WALK_COLUMNS = 6
-- Row order verified by cropping the sheet and looking at it, after the
-- first guess (down / side / up, the more common convention) turned out
-- wrong and made walking sideways show the back pose: row 0 faces the
-- camera (face visible), row 1 faces away (back of head), row 2 is the
-- side profile.
local ROW_DOWN = 0
local ROW_UP = 1
local ROW_SIDE = 2
local IDLE_FPS = 4
local WALK_FPS = 10
local MOVE_THRESHOLD = 0.05 -- Humanoid.MoveDirection magnitude below this counts as "standing still"

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
	if not humanoid or not humanoid:IsA("Humanoid") then
		warn(`[CharacterSpriteController] no Humanoid on {character.Name} after 5s — leaving it 3D.`)
		return
	end
	if not rootPart or not rootPart:IsA("BasePart") then
		warn(`[CharacterSpriteController] no HumanoidRootPart on {character.Name} after 5s — leaving it 3D.`)
		return
	end

	-- Build the sprite and confirm the image ACTUALLY loads before hiding
	-- the 3D rig. Hiding first and trusting the image to show up is how
	-- you get an invisible player when the asset doesn't render (wrong id
	-- type, still in moderation, etc.) — the rig is the fallback, so it
	-- only goes away once there's something real to replace it with.
	local image = buildBillboard(rootPart)
	local idleId = AssetIds.sprite("player_idle")
	image.Image = idleId
	pcall(function()
		ContentProvider:PreloadAsync({ image })
	end)
	if not image.IsLoaded then
		warn(
			`[CharacterSpriteController] image {idleId} never loaded (IsLoaded = false) — keeping the 3D avatar. `
				.. `Most likely the uploaded asset is a Decal id rather than an Image id, or it's still in moderation.`
		)
		local billboard = image.Parent
		if billboard then
			billboard:Destroy()
		end
		return
	end

	hideCharacterParts(character)
	print(`[CharacterSpriteController] sprite applied to {character.Name}; image loaded OK ({idleId})`)

	local lastRow = ROW_DOWN
	local currentSheetIsWalk = false -- the idle sheet is already assigned above
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
		if moving then
			if math.abs(moveDirection.X) > math.abs(moveDirection.Z) then
				row = ROW_SIDE
			else
				row = if moveDirection.Z > 0 then ROW_DOWN else ROW_UP
			end
			lastRow = row
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
	local idleId = AssetIds.sprite("player_idle")
	local walkId = AssetIds.sprite("player_walk")
	print(`[CharacterSpriteController] init — idle = {idleId}, walk = {walkId}`)
	if idleId == "rbxassetid://0" or walkId == "rbxassetid://0" then
		warn("[CharacterSpriteController] player_idle/player_walk sprites not uploaded yet — keeping 3D avatars until they are.")
		return
	end

	-- task.spawn, not a direct call: applySprite yields (WaitForChild with
	-- a 5s timeout), and init() runs near the top of Main.client.lua's
	-- controller list — calling it inline would stall every controller
	-- after it for up to 5 seconds per already-spawned character.
	local function onPlayer(player: Player)
		if player.Character then
			task.spawn(applySprite, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			task.spawn(applySprite, character)
		end)
	end

	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return CharacterSpriteController
