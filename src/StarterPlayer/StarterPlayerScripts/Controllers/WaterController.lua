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
-- The "randomized" part is per-tile: each tile gets its own phase, drift
-- direction and sway speed, so the cove reads as a body of water with
-- waves moving through it rather than one giant texture sliding in
-- lockstep — which is exactly what a uniform scroll looks like across a
-- grid, and reads as obviously fake.
--
-- Client-side on purpose: it's pure decoration, nothing depends on it,
-- and animating it on the server would replicate a property change per
-- tile per frame to every player for no gameplay reason.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local WaterController = {}

local WATER_TAG = "WaterTile"
local WATER_TEXTURE_NAME = "WaterTexture"

local DRIFT_STUDS_PER_SECOND = 0.35
local SWAY_AMPLITUDE_STUDS = 0.25
local SWAY_SPEED = 0.55

type WaterTile = {
	texture: Texture,
	phase: number,
	driftX: number,
	driftY: number,
	swaySpeed: number,
}

local tiles: { WaterTile } = {}
local tileByTexture: { [Texture]: boolean } = {}

local function track(part: Instance)
	local texture = part:FindFirstChild(WATER_TEXTURE_NAME)
	if not texture or not texture:IsA("Texture") or tileByTexture[texture] then
		return
	end
	tileByTexture[texture] = true

	-- math.random() per tile, not a hash of position: neighbouring tiles
	-- getting unrelated values is the whole point.
	local angle = math.random() * math.pi * 2
	table.insert(tiles, {
		texture = texture,
		phase = math.random() * math.pi * 2,
		driftX = math.cos(angle) * DRIFT_STUDS_PER_SECOND,
		driftY = math.sin(angle) * DRIFT_STUDS_PER_SECOND,
		swaySpeed = SWAY_SPEED * (0.7 + math.random() * 0.6),
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

function WaterController.init()
	for _, part in CollectionService:GetTagged(WATER_TAG) do
		track(part)
	end
	CollectionService:GetInstanceAddedSignal(WATER_TAG):Connect(track)

	RunService.Heartbeat:Connect(function()
		if #tiles == 0 then
			return
		end
		local t = os.clock()
		for _, tile in tiles do
			-- Steady drift plus a slow crosswise sway, so crests wander
			-- instead of tracking a dead-straight line.
			local sway = math.sin(t * tile.swaySpeed + tile.phase) * SWAY_AMPLITUDE_STUDS
			tile.texture.OffsetStudsU = tile.phase + t * tile.driftX + sway
			tile.texture.OffsetStudsV = tile.phase + t * tile.driftY
		end
	end)
end

return WaterController
