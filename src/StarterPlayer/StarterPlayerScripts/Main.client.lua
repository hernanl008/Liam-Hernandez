--!strict
-- Client bootstrap. Add new controllers by requiring their init module here.

print("[AnimeFarmLife] Client starting...")

local Controllers = script.Parent:WaitForChild("Controllers")

local CameraController = require(Controllers:WaitForChild("CameraController"))
local FarmingController = require(Controllers:WaitForChild("FarmingController"))
local FishingController = require(Controllers:WaitForChild("FishingController"))
local CookingController = require(Controllers:WaitForChild("CookingController"))
local DialogueController = require(Controllers:WaitForChild("DialogueController"))
local CompendiumController = require(Controllers:WaitForChild("CompendiumController"))
local SkillTreeController = require(Controllers:WaitForChild("SkillTreeController"))
local HudController = require(Controllers:WaitForChild("HudController"))
local AmbienceController = require(Controllers:WaitForChild("AmbienceController"))
local ShopController = require(Controllers:WaitForChild("ShopController"))

CameraController.init()
FarmingController.init()
FishingController.init()
CookingController.init()
DialogueController.init()
CompendiumController.init()
SkillTreeController.init()
HudController.init()
AmbienceController.init()
-- Must init after DialogueController: it adds its own ProximityPrompt to
-- Kaleb's part and depends on DialogueController having already claimed/
-- created the "Talk" one first (see ShopController.lua's header comment).
ShopController.init()

print("[AnimeFarmLife] Client ready.")
