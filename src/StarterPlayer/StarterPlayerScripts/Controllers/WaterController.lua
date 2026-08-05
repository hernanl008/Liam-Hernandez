--!strict
-- Animates the cove's water. MapBuilder paints each water tile with a
-- single still pixel-art texture (assets/tiles/water.png) and tags it
-- "WaterTile"; this scrolls that texture's offset every frame so the
-- waves actually drift.
--
-- Why scroll one texture instead of flipping through animation frames:
-- frames would mean N uploaded PNGs and a swap every tick for every
-- tile, whereas the tile art is built to wrap seamlessly in both axes
-- (see tools/make_water_tile.py), so sliding its offset gives
-- continuous motion off a single asset with no visible loop point.
--
-- All tiles share ONE global offset, deliberately: each tile part shows
-- exactly one repeat of the seamless texture (StudsPerTile == tile
-- size), so equal offsets make neighbouring tiles' edges line up into
-- one continuous surface. The first version randomized drift per tile
-- to avoid "lockstep sliding" — which was exactly backwards for a tile
-- GRID: every tile boundary became a visible seam where two unrelated
-- offsets met, and the cove read as a patchwork of out-of-sync squares
-- (caught in a live screenshot). The organic variation now comes from
-- the two LAYERS moving against each other, not from tiles disagreeing
-- with their neighbours.
--
-- Client-side on purpose: it's pure decoration, nothing depends on it,
-- and animating it on the server would replicate a property change per
-- tile per frame to every player for no gameplay reason.

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local WaterController = {}

local WATER_TAG = "WaterTile"
local WATER_TEXTURE_NAME = "WaterTexture"
local WATER_OVERLAY_NAME = "WaterOverlay"

local DRIFT_STUDS_PER_SECOND = 0.35
local SWAY_AMPLITUDE_STUDS = 0.25
local SWAY_SPEED = 0.55
-- The overlay layer (MapBuilder's semi-transparent second Texture) runs
-- faster and against the base layer's direction — the two sliding past
-- each other is what makes the surface shimmer instead of just travel.
local OVERLAY_SPEED_MULTIPLIER = -1.6

-- One fixed drift heading for the whole cove (a lazy diagonal), shared
-- by every tile — see the header for why per-tile variation is exactly
-- what broke it.
local DRIFT_HEADING = math.rad(25)
local DRIFT_X = math.cos(DRIFT_HEADING) * DRIFT_STUDS_PER_SECOND
local DRIFT_Y = math.sin(DRIFT_HEADING) * DRIFT_STUDS_PER_SECOND

type WaterTile = {
	texture: Texture,
	overlay: Texture?,
}

local tiles: { WaterTile } = {}
local tileByTexture: { [Texture]: boolean } = {}

local function track(part: Instance)
	local texture = part:FindFirstChild(WATER_TEXTURE_NAME)
	if not texture or not texture:IsA("Texture") or tileByTexture[texture] then
		return
	end
	tileByTexture[texture] = true

	local overlayInstance = part:FindFirstChild(WATER_OVERLAY_NAME)
	local overlay = if overlayInstance and overlayInstance:IsA("Texture") then overlayInstance else nil

	table.insert(tiles, {
		texture = texture,
		overlay = overlay,
	})

	texture.Destroying:Connect(function()
		tileByTexture[texture] = nil
		for i, tile in tiles do
			if tile.texture == texture then
				table.remove(tiles, i)
				break
			end
		end
	end)
end

-- MapBuilder commits to the textured path as soon as an id is wired,
-- but a wired id can still fail to render (moderation, wrong asset
-- type, bad upload) — and a Texture whose image never loads draws
-- NOTHING, leaving flat blue blocks with no waves at all. Verify the
-- image actually loaded and, if it didn't, strip the textures and fall
-- back to Roblox's built-in animated Water material, which needs no
-- asset. Same "keep the fallback until the replacement is proven"
-- rule as the sprite character and the fish standees.
local function verifyOrFallback()
	local first = tiles[1]
	if not first then
		return
	end
	-- Texture instances expose no IsLoaded, so probe the same image id
	-- through a throwaway ImageLabel, which does.
	local probe = Instance.new("ImageLabel")
	probe.Image = first.texture.Texture
	pcall(function()
		ContentProvider:PreloadAsync({ probe })
	end)
	local loaded = probe.IsLoaded
	probe:Destroy()
	if loaded then
		return
	end

	warn(
		`[WaterController] water texture {first.texture.Texture} never loaded — falling back to Material.Water. `
			.. `Most likely the uploaded asset is still in moderation, is a Decal id, or was the wrong file.`
	)
	for _, tile in tiles do
		local part = tile.texture.Parent
		if part and part:IsA("BasePart") then
			part.Material = Enum.Material.Water
			part.Transparency = 0.15
		end
		tile.texture:Destroy()
		if tile.overlay then
			tile.overlay:Destroy()
		end
	end
	table.clear(tiles)
	table.clear(tileByTexture)
end

function WaterController.init()
	for _, part in CollectionService:GetTagged(WATER_TAG) do
		track(part)
	end
	CollectionService:GetInstanceAddedSignal(WATER_TAG):Connect(track)
	task.spawn(verifyOrFallback)

	RunService.Heartbeat:Connect(function()
		if #tiles == 0 then
			return
		end
		local t = os.clock()
		-- Computed ONCE, applied to every tile identically — equal offsets
		-- are what keep the tiled pattern continuous across part edges.
		local sway = math.sin(t * SWAY_SPEED) * SWAY_AMPLITUDE_STUDS
		local baseU = t * DRIFT_X + sway
		local baseV = t * DRIFT_Y
		local overlayU = t * DRIFT_X * OVERLAY_SPEED_MULTIPLIER - sway * 0.5
		local overlayV = t * DRIFT_Y * OVERLAY_SPEED_MULTIPLIER
		for _, tile in tiles do
			tile.texture.OffsetStudsU = baseU
			tile.texture.OffsetStudsV = baseV
			local overlay = tile.overlay
			if overlay then
				overlay.OffsetStudsU = overlayU
				overlay.OffsetStudsV = overlayV
			end
		end
	end)
end

return WaterController
