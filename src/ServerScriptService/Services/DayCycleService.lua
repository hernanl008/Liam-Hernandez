--!strict
-- Drives the day/night cycle. Day length is one tunable constant per
-- GDD.md §5's "adjustable day length" QoL decision — wiring an actual
-- settings UI to DayCycleService.setDayLengthSeconds is future work, but
-- the service is built so that's a one-line change, not a refactor.
--
-- Deliberately has no direct dependency on FarmingService (or anything
-- else that cares about "a new day started") — callers register via
-- DayCycleService.onNewDay so services stay decoupled. See Main.server.lua
-- for the actual wiring.

local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))

local DayCycleService = {}

export type Season = "Spring" | "Summer" | "Fall" | "Winter"
export type Weather = "Clear" | "Rainy"

local dayLengthSeconds = 20 * 60 -- 20 real-time minutes per in-game day, tune freely
local currentDay = 1
local elapsedThisDay = 0
local currentClockTime = 6 -- 24-hour clock, mirrors Lighting.ClockTime
local newDayListeners: { (number) -> () } = {}

-- GDD.md §3's "broader weather effects on fish spawns" — rolled fresh
-- once per in-game day (not per-second, so it's a stable daily condition
-- players can plan around, same idea as real weather in Stardew-likes).
-- FishingService.lua is the only current consumer; AmbienceController.lua
-- reflects it visually.
local RAIN_CHANCE = 0.3
local currentWeather: Weather = "Clear"

local function rollWeather(): Weather
	return math.random() < RAIN_CHANCE and "Rainy" or "Clear"
end

-- Night-only content (LORE_BIBLE.md §5's Moonlit Serpent) checks this —
-- kept as a named predicate rather than callers comparing ClockTime
-- directly, so the definition of "night" only lives in one place.
local NIGHT_START_CLOCK_TIME = 20 -- 8pm
local NIGHT_END_CLOCK_TIME = 6 -- 6am

-- 7 in-game days per season (a real Stardew-length 28 would make season-
-- locked crops in FarmingConfig.lua nearly untestable within one sitting
-- — this is a vertical-slice pacing choice, tune freely). Cycles forever,
-- doesn't track in-world years.
local SEASON_ORDER: { Season } = { "Spring", "Summer", "Fall", "Winter" }
local DAYS_PER_SEASON = 7

function DayCycleService.setDayLengthSeconds(seconds: number)
	dayLengthSeconds = math.max(seconds, 30) -- floor so it can never become a busy-loop
end

function DayCycleService.getCurrentDay(): number
	return currentDay
end

function DayCycleService.getClockTime(): number
	return currentClockTime
end

function DayCycleService.isNight(): boolean
	return currentClockTime >= NIGHT_START_CLOCK_TIME or currentClockTime < NIGHT_END_CLOCK_TIME
end

function DayCycleService.getCurrentSeason(): Season
	local seasonIndex = math.floor((currentDay - 1) / DAYS_PER_SEASON) % #SEASON_ORDER
	return SEASON_ORDER[seasonIndex + 1]
end

function DayCycleService.getCurrentWeather(): Weather
	return currentWeather
end

function DayCycleService.onNewDay(callback: (number) -> ())
	table.insert(newDayListeners, callback)
end

function DayCycleService.init()
	local RunService = game:GetService("RunService")
	local lastBroadcast = 0
	currentWeather = rollWeather()

	RunService.Heartbeat:Connect(function(dt: number)
		elapsedThisDay += dt

		-- broadcast a lightweight clock update a few times a second, not every frame
		if os.clock() - lastBroadcast > 0.5 then
			lastBroadcast = os.clock()
			local dayProgress = elapsedThisDay / dayLengthSeconds
			currentClockTime = 6 + dayProgress * 18 -- 6am -> midnight across the day
			Lighting.ClockTime = currentClockTime
			Remotes.get("DayCycleUpdate"):FireAllClients({
				day = currentDay,
				dayProgress = dayProgress,
				season = DayCycleService.getCurrentSeason(),
				weather = currentWeather,
			})
		end

		if elapsedThisDay >= dayLengthSeconds then
			elapsedThisDay = 0
			currentDay += 1
			currentWeather = rollWeather()
			for _, listener in newDayListeners do
				listener(currentDay)
			end
		end
	end)
end

return DayCycleService
