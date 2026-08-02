--!strict
-- Sets the game's visual mood via Lighting post-effects — zero art
-- assets needed, just PostEffect/Atmosphere instances (GDD.md §14 "make
-- it more anime" pass). Lighting is a replicated service, so setting
-- this once on the server is enough for everyone; DayCycleService.lua
-- still owns the moment-to-moment ClockTime, this only owns the static
-- mood layered on top of it.

local Lighting = game:GetService("Lighting")

local AtmosphereService = {}

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

function AtmosphereService.init()
	-- Warm, slightly glowing highlights — the soft-focus look anime
	-- backgrounds tend to have on bright surfaces (water, gold accents).
	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.4

	-- Slightly boosted saturation + warm tint instead of Roblox's default
	-- neutral grade — reads far more "stylized" than "realistic" for free.
	local colorCorrection = ensure("ColorCorrectionEffect", "ColorGrade") :: ColorCorrectionEffect
	colorCorrection.TintColor = Color3.fromRGB(255, 241, 235)
	colorCorrection.Saturation = 0.15
	colorCorrection.Contrast = 0.05
	colorCorrection.Brightness = 0.02

	-- Subtle god-rays for a dreamy, storybook feel rather than flat light.
	local sunRays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	sunRays.Intensity = 0.15
	sunRays.Spread = 0.5

	-- A faint lavender haze in the distance — softens the flat tile
	-- horizon (GDD.md §13) into something that reads as a painted
	-- background rather than an obviously flat plane.
	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(230, 220, 255)
	atmosphere.Decay = Color3.fromRGB(150, 130, 200)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2

	Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 160)
	Lighting.Ambient = Color3.fromRGB(90, 80, 110)
end

return AtmosphereService
