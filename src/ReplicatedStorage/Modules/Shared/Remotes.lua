--!strict
-- Single source of truth for RemoteEvent/RemoteFunction instances shared
-- between server and client. Both sides call Remotes.get(name) — the
-- server creates on first call, the client waits for the server to have
-- created it. Avoids scattering FindFirstChild/WaitForChild everywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENT_NAMES = {
	"TillSoil",
	"PlantSeed",
	"WaterPlot",
	"HarvestCrop",
	"FarmingOutcome",
	"RequestCast",
	"FishBite",
	"HookAttempt",
	"ReelStart",
	"ReelResult",
	"CatchResult",
	"StartCooking",
	"CookingRejected",
	"CookingStart",
	"CookingResult",
	"CookingOutcome",
	"DialogueAction",
	"DialogueRelationshipDelta",
	"DayCycleUpdate",
	"InventoryUpdate",
	"UnlockPerk",
	"UnlockPerkResult",
}

local Remotes = {}

local function getFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if folder then
		return folder :: Folder
	end

	if RunService:IsServer() then
		local newFolder = Instance.new("Folder")
		newFolder.Name = FOLDER_NAME
		newFolder.Parent = ReplicatedStorage
		for _, eventName in EVENT_NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = eventName
			remote.Parent = newFolder
		end
		return newFolder
	end

	return ReplicatedStorage:WaitForChild(FOLDER_NAME, 10) :: Folder
end

function Remotes.get(name: string): RemoteEvent
	local folder = getFolder()
	local remote = folder:WaitForChild(name, 10)
	assert(remote, `Remote "{name}" not found — add it to EVENT_NAMES in Remotes.lua`)
	return remote :: RemoteEvent
end

return Remotes
