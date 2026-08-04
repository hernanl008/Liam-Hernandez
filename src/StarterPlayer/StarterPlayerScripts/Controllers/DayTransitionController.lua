--!strict
-- Full-screen black fade on every day change (DayCycleService.lua's
-- DayChanged event — fired once per actual rollover, whether triggered
-- by sleeping or the day just running out) — "and then it's the next
-- day" instead of the world silently relabeling itself mid-frame.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))

local DayTransitionController = {}

local FADE_IN_SECONDS = 0.5
local HOLD_SECONDS = 0.5
local FADE_OUT_SECONDS = 0.7

local screenGui: ScreenGui? = nil
local background: Frame
local fading = false

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DayTransitionUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 80 -- above the HUD/world, below the opening cutscene (90) if that ever overlaps
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	background = frame
end

local function playFade()
	if fading then
		-- Sleeping is throttled server-side (DayCycleService.lua) so this
		-- shouldn't be reachable in practice, but guard anyway rather than
		-- risk two tweens fighting over the same Frame's transparency.
		return
	end
	fading = true
	ensureBuilt()

	local fadeIn = TweenService:Create(background, TweenInfo.new(FADE_IN_SECONDS), { BackgroundTransparency = 0 })
	fadeIn:Play()
	fadeIn.Completed:Wait()

	task.wait(HOLD_SECONDS)

	local fadeOut = TweenService:Create(background, TweenInfo.new(FADE_OUT_SECONDS), { BackgroundTransparency = 1 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	fading = false
end

function DayTransitionController.init()
	Remotes.get("DayChanged").OnClientEvent:Connect(function(_day: number)
		task.spawn(playFade)
	end)
end

return DayTransitionController
