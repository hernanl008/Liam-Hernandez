--!strict
-- Plain dialogue box: speaker name, text, up to a few option buttons (or
-- a single "..." continue button when a node has no choices). Content is
-- entirely driven by DialogueController — this module only renders.

local Players = game:GetService("Players")

local DialogueUI = {}

local screenGui: ScreenGui? = nil
local speakerLabel: TextLabel
local textLabel: TextLabel
local optionsFrame: Frame

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DialogueUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	local box = Instance.new("Frame")
	box.Size = UDim2.fromScale(0.6, 0.3)
	box.Position = UDim2.fromScale(0.2, 0.66)
	box.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
	box.BackgroundTransparency = 0.1
	box.Parent = gui

	speakerLabel = Instance.new("TextLabel")
	speakerLabel.Size = UDim2.fromScale(0.95, 0.18)
	speakerLabel.Position = UDim2.fromScale(0.025, 0.02)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	speakerLabel.Font = Enum.Font.GothamBold
	speakerLabel.TextScaled = true
	speakerLabel.TextColor3 = Color3.fromRGB(255, 220, 150)
	speakerLabel.Parent = box

	textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(0.95, 0.4)
	textLabel.Position = UDim2.fromScale(0.025, 0.2)
	textLabel.BackgroundTransparency = 1
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.Parent = box

	optionsFrame = Instance.new("Frame")
	optionsFrame.Size = UDim2.fromScale(0.95, 0.35)
	optionsFrame.Position = UDim2.fromScale(0.025, 0.62)
	optionsFrame.BackgroundTransparency = 1
	optionsFrame.Parent = box

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = optionsFrame
end

export type OptionDisplay = { text: string }

function DialogueUI.show(speaker: string, text: string, options: { OptionDisplay }, onSelect: (number) -> ())
	ensureBuilt()
	local gui = screenGui :: ScreenGui
	gui.Enabled = true
	speakerLabel.Text = speaker
	textLabel.Text = text

	for _, child in optionsFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	if #options == 0 then
		local continueButton = Instance.new("TextButton")
		continueButton.Size = UDim2.fromScale(1, 0.3)
		continueButton.Text = "..."
		continueButton.TextScaled = true
		continueButton.Parent = optionsFrame
		continueButton.Activated:Connect(function()
			DialogueUI.hide()
		end)
		return
	end

	for i, option in options do
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(1, 0.3)
		button.Text = option.text
		button.TextScaled = true
		button.LayoutOrder = i
		button.Parent = optionsFrame
		button.Activated:Connect(function()
			onSelect(i)
		end)
	end
end

function DialogueUI.hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return DialogueUI
