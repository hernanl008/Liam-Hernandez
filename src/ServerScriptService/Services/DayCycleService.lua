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

local dayLengthSeconds = 20 * 60 -- 20 real-time minutes per in-game day, tune freely
local currentDay = 1
local elapsedThisDay = 0
local newDayListeners: { (number) -> () } = {}

function DayCycleService.setDayLengthSeconds(seconds: number)
	dayLengthSeconds = math.max(seconds, 30) -- floor so it can never become a busy-loop
end

function DayCycleService.getCurrentDay(): number
	return currentDay
end

function DayCycleService.onNewDay(callback: (number) -> ())
	table.insert(newDayListeners, callback)
end

function DayCycleService.init()
	local RunService = game:GetService("RunService")
	local lastBroadcast = 0

	RunService.Heartbeat:Connect(function(dt: number)
		elapsedThisDay += dt

		-- broadcast a lightweight clock update a few times a second, not every frame
		if os.clock() - lastBroadcast > 0.5 then
			lastBroadcast = os.clock()
			local dayProgress = elapsedThisDay / dayLengthSeconds
			Lighting.ClockTime = 6 + dayProgress * 18 -- 6am -> midnight across the day
			Remotes.get("DayCycleUpdate"):FireAllClients({
				day = currentDay,
				dayProgress = dayProgress,
			})
		end

		if elapsedThisDay >= dayLengthSeconds then
			elapsedThisDay = 0
			currentDay += 1
			for _, listener in newDayListeners do
				listener(currentDay)
			end
		end
	end)
end

return DayCycleService
