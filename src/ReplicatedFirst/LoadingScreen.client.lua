--!strict
-- Standard Roblox loading-screen pattern: runs from ReplicatedFirst
-- (before any other client script), shows a full-screen splash while the
-- game/character load, then fades out. Deliberately doesn't play the
-- opening cutscene (docs/OPENING_CUTSCENE.md) itself — wiring that
-- cinematic sequence in is separate narrative-content work for a later
-- session; this only owns "don't show a blank screen while loading."

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
background.BorderSizePixel = 0
background.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(0.6, 0.12)
title.Position = UDim2.fromScale(0.2, 0.4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 220, 150)
title.Text = "Anime Farm Life"
title.Parent = background

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.fromScale(0.6, 0.06)
statusLabel.Position = UDim2.fromScale(0.2, 0.54)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextScaled = true
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Text = "Waking up..."
statusLabel.Parent = background

-- Simple pulsing dots instead of a real progress bar — there's no
-- reliable single "percent loaded" number to drive one honestly (asset
-- counts vary run to run).
task.spawn(function()
	local dotCounts = { "", ".", "..", "..." }
	local i = 0
	while screenGui.Parent do
		i = (i % #dotCounts) + 1
		statusLabel.Text = `Waking up{dotCounts[i]}`
		task.wait(0.4)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

if not player.Character then
	player.CharacterAdded:Wait()
end

statusLabel.Text = "Ready."
task.wait(0.3)

local fade = TweenService:Create(background, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
local titleFade = TweenService:Create(title, TweenInfo.new(0.6), { TextTransparency = 1 })
local statusFade = TweenService:Create(statusLabel, TweenInfo.new(0.6), { TextTransparency = 1 })
fade:Play()
titleFade:Play()
statusFade:Play()
fade.Completed:Wait()
screenGui:Destroy()
