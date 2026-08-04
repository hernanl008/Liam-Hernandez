--!strict
-- ProximityPrompt on the Bed-tagged part (MapBuilder.lua, right outside
-- the starter house) that ends the current day early instead of waiting
-- out the full real-time length. No interior/bed-inside-a-house feature
-- exists yet, so this is a single exterior prompt for the whole game.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))

local SleepController = {}

local BED_TAG = "Bed"

local function setupBed(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.MaxActivationDistance = 8
		prompt.Parent = instance
	end
	prompt.ActionText = "Sleep"
	prompt.Triggered:Connect(function()
		Remotes.get("RequestSleep"):FireServer()
	end)
end

function SleepController.init()
	for _, instance in CollectionService:GetTagged(BED_TAG) do
		setupBed(instance)
	end
	CollectionService:GetInstanceAddedSignal(BED_TAG):Connect(setupBed)
end

return SleepController
