--!strict
-- Locks the camera to a fixed top-down angle that follows the player and
-- never rotates — GDD.md §6's "locked top-down 2D presentation"
-- decision (this is how Stardew Valley itself actually reads: fixed
-- angle, no free camera). Because the camera's yaw never changes, WASD
-- consistently maps to fixed screen/world directions like a real
-- top-down game, instead of Roblox's default camera-relative movement.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraController = {}

-- Tuned for a "3/4 top-down" Stardew-ish angle rather than a pure
-- straight-down view, which reads as flatter and is harder to parse at
-- a glance. Adjust to taste once there's an actual playtest to look at.
local HEIGHT = 38
local BACK_OFFSET = 22
local FOLLOW_LERP = 0.15 -- 0-1 per frame; higher = camera catches up to the player faster

function CameraController.init()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera :: Camera
	camera.CameraType = Enum.CameraType.Scriptable

	local currentFocus = Vector3.zero
	local hasFocus = false

	player.CharacterAdded:Connect(function()
		hasFocus = false -- snap to the new spawn point instead of lerping across the map
	end)

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		local targetPosition = (root :: BasePart).Position
		if not hasFocus then
			currentFocus = targetPosition
			hasFocus = true
		else
			currentFocus = currentFocus:Lerp(targetPosition, FOLLOW_LERP)
		end

		local cameraPosition = currentFocus + Vector3.new(0, HEIGHT, BACK_OFFSET)
		camera.CFrame = CFrame.lookAt(cameraPosition, currentFocus)
	end)
end

return CameraController
