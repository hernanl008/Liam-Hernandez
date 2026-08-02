--!strict
-- Reusable rhythm-note UI + input capture, shared by the cooking
-- minigame and the fishing reel-in minigame (GDD.md §10 — deliberately
-- one implementation, not two). Visual is intentionally plain (labeled
-- lane boxes that cue then flash on hit) — a first pass to prove the
-- mechanic out; visual polish is a Studio/art pass, not a logic change.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local RhythmScoring = require(script.Parent.Parent:WaitForChild("Shared"):WaitForChild("RhythmScoring"))

local LANE_KEYS = { Enum.KeyCode.D, Enum.KeyCode.F, Enum.KeyCode.J, Enum.KeyCode.K }
local HIT_TOLERANCE = 0.35 -- seconds around a note's time it can still register as *a* hit; RhythmScoring grades accuracy within this
local LOOKAHEAD = 0.6 -- seconds before a note's time its lane starts "cueing"

local RhythmUI = {}

function RhythmUI.play(notes: { RhythmScoring.Note }, onComplete: ({ RhythmScoring.Hit }) -> ())
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RhythmMinigame"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Size = UDim2.fromScale(0.5, 0.18)
	container.Position = UDim2.fromScale(0.25, 0.78)
	container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	container.BackgroundTransparency = 0.2
	container.Parent = screenGui

	local laneFrames: { Frame } = {}
	for lane = 1, 4 do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(0.23, 0.8)
		frame.Position = UDim2.fromScale((lane - 1) * 0.25 + 0.01, 0.1)
		frame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		frame.Parent = container

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = LANE_KEYS[lane].Name
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Parent = frame

		laneFrames[lane] = frame
	end

	local hits: { RhythmScoring.Hit } = {}
	local hitNotes: { [number]: boolean } = {}
	local startTime = os.clock()
	local finished = false
	local flashUntil: { [number]: number } = {}

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
			table.insert(hits, { noteIndex = bestIndex, offsetSeconds = elapsed - bestNote.time })
			flashUntil[laneIndex] = os.clock() + 0.15
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
				frame.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
			else
				local cueing = false
				for i, note in notes do
					if note.lane == lane and not hitNotes[i] and (note.time - elapsed) <= LOOKAHEAD and (note.time - elapsed) >= -HIT_TOLERANCE then
						cueing = true
						break
					end
				end
				frame.BackgroundColor3 = cueing and Color3.fromRGB(210, 190, 90) or Color3.fromRGB(60, 60, 60)
			end
		end

		if elapsed >= endTime then
			cleanup()
		end
	end)
end

return RhythmUI
