--!strict
-- Server bootstrap. Add new systems by requiring their init module here.

print("[AnimeFarmLife] Server starting...")

local Services = script.Parent:WaitForChild("Services")

-- PlayerDataService wires its own PlayerAdded/PlayerRemoving connections
-- at require-time — required for that side effect, nothing to call on it.
local _PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local FarmingService = require(Services:WaitForChild("FarmingService"))
local FishingService = require(Services:WaitForChild("FishingService"))
local CookingService = require(Services:WaitForChild("CookingService"))
local DialogueService = require(Services:WaitForChild("DialogueService"))
local DayCycleService = require(Services:WaitForChild("DayCycleService"))
local SkillService = require(Services:WaitForChild("SkillService"))

FarmingService.init()
FishingService.init()
CookingService.init()
DialogueService.init()
DayCycleService.init()
SkillService.init()

-- Keep FarmingService decoupled from DayCycleService (see DayCycleService
-- comments) — wire the one thing they actually share here instead.
DayCycleService.onNewDay(function(_day: number)
	FarmingService.resetDailyWatering()
end)

print("[AnimeFarmLife] Server ready.")
