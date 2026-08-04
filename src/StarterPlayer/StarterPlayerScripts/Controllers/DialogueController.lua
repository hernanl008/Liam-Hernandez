--!strict
-- Walks DialogueData trees (docs/DIALOGUE_ACT1.md is the human-readable
-- source of truth for the actual lines) and drives DialogueUI. NPCs are
-- expected to be Parts/Models tagged "NPC" with a ProximityPrompt and a
-- string attribute "NpcId" matching a key in DialogueData (e.g. "Kaya").

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local DialogueData = require(Modules:WaitForChild("Shared"):WaitForChild("DialogueData"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local DialogueUI = require(Modules:WaitForChild("UI"):WaitForChild("DialogueUI"))

local DialogueController = {}

local NPC_TAG = "NPC"

local AUTO_ROUTE_CHECKS: { [string]: () -> boolean } = {
	HasAnyIngredient = InventoryCache.hasAnyIngredient,
	-- One per NPC rather than a single parameterized check: autoRoute.check
	-- is just a no-arg lookup key today (matches HasAnyIngredient above),
	-- and five explicit entries is simpler than reworking that for one caller.
	HasMetKaya = function() return InventoryCache.hasFlag("Met_Kaya") end,
	HasMetElderSouta = function() return InventoryCache.hasFlag("Met_ElderSouta") end,
	HasMetRen = function() return InventoryCache.hasFlag("Met_Ren") end,
	HasMetHinano = function() return InventoryCache.hasFlag("Met_Hinano") end,
	HasMetKaleb = function() return InventoryCache.hasFlag("Met_Kaleb") end,
}

local function runConversation(npcId: string)
	local trees = DialogueData[npcId]
	local rootId = DialogueData.Roots[npcId]
	if not trees or not rootId then
		warn(`No dialogue configured for NpcId "{npcId}"`)
		return
	end

	-- Fired every conversation (server no-ops repeats, DialogueService.lua)
	-- rather than checked-then-fired here, since the check that matters —
	-- whether THIS conversation should show the return greeting — already
	-- reads the cache as of *before* this line runs.
	Remotes.get("DialogueAction"):FireServer(`Met_{npcId}`)

	local function showNode(nodeId: string?)
		if not nodeId then
			DialogueUI.hide()
			return
		end

		local node = trees[nodeId]
		if not node then
			warn(`Dialogue node "{nodeId}" missing for NpcId "{npcId}"`)
			DialogueUI.hide()
			return
		end

		if node.autoRoute then
			local function resolveRoute(_index: number?)
				local check = AUTO_ROUTE_CHECKS[node.autoRoute.check]
				local result = check ~= nil and check() or false
				showNode(result and node.autoRoute.ifTrue or node.autoRoute.ifFalse)
			end
			if node.text == "" then
				-- Silent router (e.g. the *_root nodes): nothing to show,
				-- resolve immediately — same behavior as before this fix.
				resolveRoute()
			else
				-- Has an actual line to speak (e.g. Hinano's greeting)
				-- before the routing decision — show it first instead of
				-- silently skipping straight to whichever branch it picks.
				DialogueUI.show(node.speaker, node.text, { { text = "Continue" } }, resolveRoute)
			end
			return
		end

		local options = node.options or {}
		local optionTexts = {}
		for _, option in options do
			table.insert(optionTexts, { text = option.text })
		end

		DialogueUI.show(node.speaker, node.text, optionTexts, function(index: number)
			local chosen = options[index]
			if not chosen then
				DialogueUI.hide()
				return
			end
			if chosen.relationshipDelta then
				Remotes.get("DialogueRelationshipDelta"):FireServer(npcId, chosen.relationshipDelta)
			end
			if chosen.action then
				Remotes.get("DialogueAction"):FireServer(chosen.action)
			end
			showNode(chosen.next)
		end)
	end

	showNode(rootId)
end

local function connectNpc(instance: Instance)
	local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		if not instance:IsA("BasePart") then
			return -- Models need their own hand-placed ProximityPrompt (on a specific part), can't guess which
		end
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.MaxActivationDistance = 8
		prompt.Parent = instance
	end
	prompt.Triggered:Connect(function()
		local npcId = instance:GetAttribute("NpcId")
		if typeof(npcId) == "string" then
			runConversation(npcId)
		else
			warn(`NPC "{instance:GetFullName()}" is tagged "{NPC_TAG}" but has no NpcId attribute`)
		end
	end)
end

function DialogueController.init()
	for _, instance in CollectionService:GetTagged(NPC_TAG) do
		connectNpc(instance)
	end
	CollectionService:GetInstanceAddedSignal(NPC_TAG):Connect(connectNpc)
end

return DialogueController
