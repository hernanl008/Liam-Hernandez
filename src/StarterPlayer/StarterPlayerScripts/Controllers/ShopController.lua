--!strict
-- Kaleb's sell counter (ShopService.lua/ShopUI.lua). Adds a second
-- ProximityPrompt to Kaleb's NPC part specifically — his "Talk" prompt is
-- set up separately by DialogueController, this must run after that so it
-- creates its own prompt instead of DialogueController reusing it (see
-- DialogueController.connectNpc: it reuses *any* existing prompt on the
-- part rather than making its own, if one's already there). Also opens
-- with the N key, same pattern as Compendium (B) and skill tree (P).

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local ShopUI = require(Modules:WaitForChild("UI"):WaitForChild("ShopUI"))
local StatusToast = require(Modules:WaitForChild("UI"):WaitForChild("StatusToast"))

local ShopController = {}

local NPC_TAG = "NPC"
local SHOP_NPC_ID = "Kaleb"
local TOGGLE_KEY = Enum.KeyCode.N

local function setupShopPrompt(instance: Instance)
	if instance:GetAttribute("NpcId") ~= SHOP_NPC_ID or not instance:IsA("BasePart") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sell"
	prompt.ObjectText = "Kaleb"
	prompt.MaxActivationDistance = 8
	prompt.Parent = instance
	prompt.Triggered:Connect(function()
		ShopUI.toggle()
	end)
end

function ShopController.init()
	for _, instance in CollectionService:GetTagged(NPC_TAG) do
		setupShopPrompt(instance)
	end
	CollectionService:GetInstanceAddedSignal(NPC_TAG):Connect(setupShopPrompt)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			ShopUI.toggle()
		end
	end)

	Remotes.get("SellItemRejected").OnClientEvent:Connect(function(reason: string)
		StatusToast.setTemporary(reason, 2.5)
	end)

	-- Selling changes the very inventory the shop screen is showing —
	-- keep it live while open instead of only refreshing on next open.
	Remotes.get("InventoryUpdate").OnClientEvent:Connect(function()
		ShopUI.refreshIfVisible()
	end)
end

return ShopController
