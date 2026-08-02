--!strict
-- Celebratory feedback for standout moments (legendary catches, high
-- combos, Gold-tier dishes) — the "make it feel more anime" pass, see
-- GDD.md §11. Deliberately simple: a banner that punches in, a brief
-- screen-tint flash, and an optional camera shake. Swap the visuals for
-- real VFX/sound later; the API (SpectacleUI.banner) doesn't need to
-- change when that happens.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SpectacleUI = {}

local screenGui: ScreenGui? = nil
local bannerLabel: TextLabel
local flashFrame: Frame

local function ensureBuilt()
	if screenGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpectacleUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flashFrame.BackgroundTransparency = 1
	flashFrame.ZIndex = 1
	flashFrame.Parent = gui

	bannerLabel = Instance.new("TextLabel")
	bannerLabel.Size = UDim2.fromScale(0.8, 0.12)
	bannerLabel.Position = UDim2.fromScale(0.1, 0.15)
	bannerLabel.BackgroundTransparency = 1
	bannerLabel.Font = Enum.Font.GothamBlack
	bannerLabel.TextScaled = true
	bannerLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	bannerLabel.TextTransparency = 1
	bannerLabel.TextStrokeTransparency = 0.5
	bannerLabel.ZIndex = 2
	bannerLabel.Parent = gui
end

-- Applied *after* Roblox's own camera update each frame (priority = Camera + 1)
-- so it nudges the already-computed camera CFrame instead of fighting it —
-- the standard pattern for additive camera shake in Roblox.
local shakeBindingCounter = 0
local function shakeCamera(intensity: number, duration: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	shakeBindingCounter += 1
	local bindingName = `SpectacleShake_{shakeBindingCounter}`
	local startTime = os.clock()

	RunService:BindToRenderStep(bindingName, Enum.RenderPriority.Camera.Value + 1, function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			RunService:UnbindFromRenderStep(bindingName)
			return
		end
		local falloff = 1 - (elapsed / duration)
		local offset = Vector3.new((math.random() - 0.5) * intensity * falloff, (math.random() - 0.5) * intensity * falloff, 0)
		camera.CFrame *= CFrame.new(offset)
	end)
end

export type BannerOptions = {
	shake: boolean?,
	holdSeconds: number?,
}

function SpectacleUI.banner(text: string, color: Color3?, options: BannerOptions?)
	ensureBuilt()

	bannerLabel.Text = text
	bannerLabel.TextColor3 = color or Color3.fromRGB(255, 220, 80)
	bannerLabel.TextTransparency = 1
	bannerLabel.Position = UDim2.fromScale(0.1, 0.12)

	local flashIn = TweenService:Create(flashFrame, TweenInfo.new(0.05), { BackgroundTransparency = 0.6 })
	flashIn:Play()
	task.delay(0.05, function()
		TweenService:Create(flashFrame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end)

	TweenService:Create(bannerLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		Position = UDim2.fromScale(0.1, 0.15),
	}):Play()

	if options and options.shake then
		shakeCamera(0.3, 0.3)
	end

	local holdSeconds = (options and options.holdSeconds) or 1.6
	task.delay(holdSeconds, function()
		TweenService:Create(bannerLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
end

return SpectacleUI
