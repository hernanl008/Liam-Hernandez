--!strict
-- Client bootstrap. Add new controllers by requiring their init module here.

print("[AnimeFarmLife] Client starting...")

local Controllers = script.Parent:WaitForChild("Controllers")

local FarmingController = require(Controllers:WaitForChild("FarmingController"))
local FishingController = require(Controllers:WaitForChild("FishingController"))
local CookingController = require(Controllers:WaitForChild("CookingController"))
local DialogueController = require(Controllers:WaitForChild("DialogueController"))
local CompendiumController = require(Controllers:WaitForChild("CompendiumController"))
local SkillTreeController = require(Controllers:WaitForChild("SkillTreeController"))

FarmingController.init()
FishingController.init()
CookingController.init()
DialogueController.init()
CompendiumController.init()
SkillTreeController.init()

print("[AnimeFarmLife] Client ready.")
