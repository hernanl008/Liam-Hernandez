--!strict
-- Reusable rhythm-note UI + input capture, shared by the cooking
-- minigame and the fishing reel-in minigame (GDD.md §10 — deliberately
-- one implementation, not two). Tracks a live combo counter matching the
-- server's authoritative RhythmScoring.evaluate combo bonus (GDD.md §11)
-- so streaks feel rewarding in the moment, not just in the final result.
-- Styled via Theme.lua (GDD.md §14) — still just colored lane cards, not
-- falling-note animation, but themed to match the rest of the UI now.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local RhythmScoring = require(script.Parent.Parent:WaitForChild("Shared"):WaitForChild("RhythmScoring"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local LANE_KEYS = { Enum.KeyCode.D, Enum.KeyCode.F, Enum.KeyCode.J, Enum.KeyCode.K }
local HIT_TOLERANCE = 0.35 -- seconds around a note's time it can still register as *a* hit; RhythmScoring grades accuracy within this
local LOOKAHEAD = 0.6 -- seconds before a note's time its lane starts "cueing"

-- Live combo classification is a client-side *preview* — the server
-- independently recomputes the authoritative quality/combo from the raw
-- hits (FishingService/CookingService), so a mismatched assistMode here
-- only affects how the on-screen counter feels, never the actual reward.
local DEFAULT_WINDOWS: { RhythmScoring.TimingWindow } = {
	{ name = "Perfect", toleranceSeconds = 0.05, qualityScore = 100 },
	{ name = "Good", toleranceSeconds = 0.12, qualityScore = 70 },
	{ name = "Okay", toleranceSeconds = 0.20, qualityScore = 40 },
	{ name = "Miss", toleranceSeconds = math.huge, qualityScore = 0 },
}

local RhythmUI = {}

function RhythmUI.play(
	notes: { RhythmScoring.Note },
	onComplete: ({ RhythmScoring.Hit }) -> (),
	windows: { RhythmScoring.TimingWindow }?
)
	local scoringWindows = windows or DEFAULT_WINDOWS
	local topWindow = scoringWindows[1]
	for _, window in scoringWindows do
		if window.qualityScore > topWindow.qualityScore then
			topWindow = window
		end
	end
	local topWindowName = topWindow.name

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RhythmMinigame"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local comboLabel = Instance.new("TextLabel")
	comboLabel.Size = UDim2.fromScale(0.3, 0.08)
	comboLabel.Position = UDim2.fromScale(0.35, 0.68)
	comboLabel.BackgroundTransparency = 1
	comboLabel.TextScaled = true
	comboLabel.Text = ""
	comboLabel.Parent = screenGui
	Theme.styleImpactText(comboLabel)

	local container = Instance.new("Frame")
	container.Size = UDim2.fromScale(0.5, 0.18)
	container.Position = UDim2.fromScale(0.25, 0.78)
	container.BorderSizePixel = 0
	container.Parent = screenGui
	Theme.applyPanel(container)

	local LANE_IDLE_COLOR = Color3.fromRGB(55, 40, 60)
	local LANE_CUE_COLOR = Theme.Colors.AccentGold
	local LANE_HIT_COLOR = Theme.Colors.Success
	-- Flashed on *any* keypress that doesn't land a note, so a player can
	-- tell their input is registering at all (vs. bad timing) — the two
	-- look identical from "nothing happened" otherwise.
	local LANE_WHIFF_COLOR = Color3.fromRGB(190, 60, 60)

	local laneFrames: { Frame } = {}
	for lane = 1, 4 do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(0.23, 0.8)
		frame.Position = UDim2.fromScale((lane - 1) * 0.25 + 0.01, 0.1)
		frame.BackgroundColor3 = LANE_IDLE_COLOR
		frame.Parent = container
		Theme.applyCard(frame, 8)

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = LANE_KEYS[lane].Name
		label.TextScaled = true
		label.Parent = frame
		Theme.styleHeader(label, Theme.Colors.TextPrimary)

		laneFrames[lane] = frame
	end

	local hits: { RhythmScoring.Hit } = {}
	local hitNotes: { [number]: boolean } = {}
	local startTime = os.clock()
	local finished = false
	local flashUntil: { [number]: number } = {}
	local flashColor: { [number]: Color3 } = {}
	local liveCombo = 0

	local heartbeatConnection: RBXScriptConnection
	local inputConnection: RBXScriptConnection

	local function cleanup()
		if finished then
			return
		end
		finished = true
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
		end
		if inputConnection then
			inputConnection:Disconnect()
		end
		screenGui:Destroy()
		onComplete(hits)
	end

	local function updateCombo(hitTopWindow: boolean)
		if hitTopWindow then
			liveCombo += 1
			comboLabel.Text = liveCombo >= 2 and `{liveCombo}x COMBO!` or ""
			if liveCombo >= 2 and liveCombo % 3 == 0 then
				comboLabel.TextTransparency = 0
				comboLabel.Size = UDim2.fromScale(0.36, 0.1)
				TweenService:Create(comboLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.fromScale(0.3, 0.08),
				}):Play()
			end
		else
			liveCombo = 0
			comboLabel.Text = ""
		end
	end

	inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or finished then
			return
		end
		local laneIndex = table.find(LANE_KEYS, input.KeyCode)
		if not laneIndex then
			return
		end

		local elapsed = os.clock() - startTime
		local bestIndex: number? = nil
		local bestNote: RhythmScoring.Note? = nil
		for i, note in notes do
			if note.lane == laneIndex and not hitNotes[i] and math.abs(elapsed - note.time) <= HIT_TOLERANCE then
				if not bestNote or note.time < (bestNote :: RhythmScoring.Note).time then
					bestIndex, bestNote = i, note
				end
			end
		end

		if bestIndex and bestNote then
			hitNotes[bestIndex] = true
			local offset = elapsed - bestNote.time
			table.insert(hits, { noteIndex = bestIndex, offsetSeconds = offset })
			flashUntil[laneIndex] = os.clock() + 0.15
			flashColor[laneIndex] = LANE_HIT_COLOR

			local window = RhythmScoring.classify(offset, scoringWindows)
			updateCombo(window.name == topWindowName)
		else
			-- No note within HIT_TOLERANCE for this lane right now — still
			-- flash (red) so the press is visibly acknowledged instead of
			-- looking identical to a key that didn't register at all.
			flashUntil[laneIndex] = os.clock() + 0.15
			flashColor[laneIndex] = LANE_WHIFF_COLOR
			updateCombo(false) -- whiffed input on this lane breaks the streak too
		end
	end)

	local endTime = 0
	for _, note in notes do
		endTime = math.max(endTime, note.time)
	end
	endTime += HIT_TOLERANCE + 0.4

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime

		for lane, frame in laneFrames do
			if flashUntil[lane] and os.clock() < flashUntil[lane] then
				frame.BackgroundColor3 = flashColor[lane] or LANE_HIT_COLOR
			else
				local cueing = false
				for i, note in notes do
					if note.lane == lane and not hitNotes[i] and (note.time - elapsed) <= LOOKAHEAD and (note.time - elapsed) >= -HIT_TOLERANCE then
						cueing = true
						break
					end
				end
				frame.BackgroundColor3 = cueing and LANE_CUE_COLOR or LANE_IDLE_COLOR
			end
		end

		if elapsed >= endTime then
			cleanup()
		end
	end)
end

return RhythmUI
