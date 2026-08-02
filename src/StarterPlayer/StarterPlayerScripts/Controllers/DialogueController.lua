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
}

local function runConversation(npcId: string)
	local trees = DialogueData[npcId]
	local rootId = DialogueData.Roots[npcId]
	if not trees or not rootId then
		warn(`No dialogue configured for NpcId "{npcId}"`)
		return
	end

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
			local check = AUTO_ROUTE_CHECKS[node.autoRoute.check]
			local result = check ~= nil and check() or false
			showNode(result and node.autoRoute.ifTrue or node.autoRoute.ifFalse)
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
				-- No persisted relationship stat yet (docs/ROADMAP.md
				-- Phase 3) — logged so the hook exists once that lands.
				print(`[Dialogue] {npcId} relationship {chosen.relationshipDelta > 0 and "+" or ""}{chosen.relationshipDelta}`)
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
