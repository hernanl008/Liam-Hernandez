--!strict
-- Ambient sakura petals drifting through the air — a "cozy anime"
-- atmospheric touch (GDD.md §14), zero gameplay effect. An Attachment
-- above the player's HumanoidRootPart carries the emitter, so it follows
-- automatically without any weld/physics bookkeeping and petals are
-- always near the player without needing a source at every map location.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local AssetIds = require(Modules:WaitForChild("Shared"):WaitForChild("AssetIds"))

local AmbienceController = {}

local function attachEmitter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root or not root:IsA("BasePart") then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "PetalAttachment"
	attachment.Position = Vector3.new(0, 18, 0) -- above the player, petals drift down into view
	attachment.Parent = root

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = AssetIds.sprite("petal")
	emitter.Rate = 4
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Size = NumberSequence.new(0.6)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.85, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Acceleration = Vector3.new(0, -2, 0)
	emitter.Drag = 1
	emitter.LightEmission = 0.1
	emitter.Parent = attachment
end

function AmbienceController.init()
	local player = Players.LocalPlayer
	if player.Character then
		attachEmitter(player.Character)
	end
	player.CharacterAdded:Connect(attachEmitter)
end

return AmbienceController
