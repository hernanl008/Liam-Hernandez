--!strict
-- Server bootstrap. Add new systems by requiring their init module here.

print("[AnimeFarmLife] Server starting...")

local Services = script.Parent:WaitForChild("Services")

local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local FarmingService = require(Services:WaitForChild("FarmingService"))
local FishingService = require(Services:WaitForChild("FishingService"))
local CookingService = require(Services:WaitForChild("CookingService"))
local DialogueService = require(Services:WaitForChild("DialogueService"))
local DayCycleService = require(Services:WaitForChild("DayCycleService"))

-- PlayerDataService wires its own PlayerAdded/PlayerRemoving connections
-- at require-time, nothing else to call.
FarmingService.init()
FishingService.init()
CookingService.init()
DialogueService.init()
DayCycleService.init()

-- Keep FarmingService decoupled from DayCycleService (see DayCycleService
-- comments) — wire the one thing they actually share here instead.
DayCycleService.onNewDay(function(_day: number)
	FarmingService.resetDailyWatering()
end)

print("[AnimeFarmLife] Server ready.")
