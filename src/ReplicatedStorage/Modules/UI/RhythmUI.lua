--!strict
-- Reusable rhythm-note UI + input capture, shared by the cooking
-- minigame and the fishing reel-in minigame (GDD.md §10 — deliberately
-- one implementation, not two). Tracks a live combo counter matching the
-- server's authoritative RhythmScoring.evaluate combo bonus (GDD.md §11)
-- so streaks feel rewarding in the moment, not just in the final result.
--
-- Two looks behind one `options.retro` flag, same pattern as
-- StatusToast/CastMeterUI: cooking calls RhythmUI.play with no options
-- and gets the original bottom-of-screen anime lane strip, untouched.
-- Fishing opts into `retro = true` and gets a screen-centered
-- retro-medieval "gamemode" presentation instead — wood/parchment panel,
-- a title, the combo counter in the cutscene's pixel font, and a
-- right-hand vertical "CATCH" meter that rises on good hits and drains
-- on misses.
--
-- That meter is the win condition, not decoration: FILL it and the fish
-- is landed, EMPTY it and the fish escapes, and either outcome ends the
-- chart on the spot. It used to be a survival check — it only mattered
-- if you let it bottom out, and the fish was landed on a separate
-- quality threshold when the notes ran out, so the bar could finish
-- nearly full and still lose, or nearly empty and still win.
--
-- The bar's model lives in RhythmScoring (shared) rather than here,
-- because the SERVER rules on the catch. Both sides run
-- RhythmScoring.simulateMeter over the same hits, so the verdict the
-- server reaches is always the one the player just watched fill. This
-- file only draws it.
-- The whole retro presentation lives in one CanvasGroup so it can fade
-- in/out as a single unit via GroupTransparency instead of tweening
-- every child individually.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local RhythmScoring = require(script.Parent.Parent:WaitForChild("Shared"):WaitForChild("RhythmScoring"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local PlayerFreeze = require(script.Parent.Parent:WaitForChild("Client"):WaitForChild("PlayerFreeze"))
local SpectacleUI = require(script.Parent:WaitForChild("SpectacleUI"))
local SoundIds = require(script.Parent.Parent:WaitForChild("Shared"):WaitForChild("SoundIds"))
local SoundPlayer = require(script.Parent.Parent:WaitForChild("Client"):WaitForChild("SoundPlayer"))

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

-- Catch-meter tuning (retro mode only). Starting above empty and gaining
-- more from a top-tier hit than a single miss costs means one whiff
-- doesn't doom a run, but a genuinely bad one drains it before the chart
-- would otherwise finish.
-- The numbers live in RhythmScoring.meterFor (shared), not here. Filling
-- the bar IS the catch, so the server has to reach the same verdict from
-- the same hits; a second copy of the tuning in the UI is exactly how
-- the two would drift apart and start disagreeing about whether a fish
-- was landed. This file only draws what that model says.
--
-- Note the absence of a whiff penalty. Pressing a lane with no note
-- there used to drain the bar, but the server never learns about an
-- input that hit nothing, so charging for it would desync the two.
-- Whiffs still break the combo, which shows up in the quality score.

local RhythmUI = {}

export type PlayOptions = {
	title: string?,
	subtitle: string?,
	retro: boolean?,
	-- Retro mode only. Lets a caller tint rivets/meter/lane-cue/combo/
	-- title-stroke to reflect something about *what's* being reeled in —
	-- fishing uses this for a rarity color, so a Legendary fight visibly
	-- reads as a bigger deal than a Common one before a single note is
	-- even hit. Defaults to the standard bronze accent when omitted.
	accentColor: Color3?,
}

-- Small round rivet/stud detail, same "bolted wood plaque" look as
-- CastMeterUI's — duplicated rather than shared since it's ~15 lines and
-- pulling in a whole module for it isn't worth the indirection.
local function addRivet(parent: Instance, anchorX: number, anchorY: number, color: Color3)
	local rivet = Instance.new("Frame")
	rivet.AnchorPoint = Vector2.new(anchorX, anchorY)
	rivet.Position = UDim2.new(anchorX, anchorX == 0 and 5 or -5, anchorY, anchorY == 0 and 5 or -5)
	rivet.Size = UDim2.fromOffset(7, 7)
	rivet.BackgroundColor3 = color
	rivet.BorderSizePixel = 0
	rivet.ZIndex = 3
	rivet.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = rivet
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.RetroColors.WoodDark
	stroke.Thickness = 1
	stroke.Parent = rivet
end

-- A quick expanding-ring pop on a lane that just landed a hit — plain UI
-- (a circular Frame tweened bigger + transparent, then destroyed), same
-- "no art asset needed" approach SpectacleUI's speed lines use.
local function spawnHitBurst(laneFrame: Frame, color: Color3)
	local burst = Instance.new("Frame")
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.5, 0.5)
	burst.Size = UDim2.fromScale(0.35, 0.35)
	burst.BackgroundColor3 = color
	burst.BackgroundTransparency = 0.15
	burst.BorderSizePixel = 0
	burst.ZIndex = 5
	burst.Parent = laneFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = burst
	TweenService:Create(burst, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1.5, 1.5),
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.35, function()
		burst:Destroy()
	end)
end

function RhythmUI.play(
	notes: { RhythmScoring.Note },
	onComplete: ({ RhythmScoring.Hit }) -> (),
	windows: { RhythmScoring.TimingWindow }?,
	options: PlayOptions?
)
	local scoringWindows = windows or DEFAULT_WINDOWS
	local topWindow = scoringWindows[1]
	for _, window in scoringWindows do
		if window.qualityScore > topWindow.qualityScore then
			topWindow = window
		end
	end
	local topWindowName = topWindow.name

	local retro = options ~= nil and options.retro == true
	local title = (options and options.title) or "REEL IT IN!"
	local subtitle = options and options.subtitle
	local accentColor = (options and options.accentColor) or Theme.RetroColors.Bronze

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Same "walk away mid-chart" gap the cast meter had — freezing here
	-- too (PlayerFreeze.lua) rather than duplicating that debugging.
	-- Doesn't consume D/F/J/K (the lane keys below, one of which is also
	-- a movement key) since it's a position-pin, not an input sink.
	PlayerFreeze.start()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RhythmMinigame"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local fadeGroup: CanvasGroup? = nil
	local parent: Instance = screenGui
	if retro then
		local group = Instance.new("CanvasGroup")
		group.Size = UDim2.fromScale(1, 1)
		group.BackgroundTransparency = 1
		group.GroupTransparency = 1
		group.Parent = screenGui
		fadeGroup = group
		parent = group
	end

	local comboBaseSize = retro and UDim2.fromScale(0.3, 0.07) or UDim2.fromScale(0.3, 0.08)
	local comboPulseSize = retro and UDim2.fromScale(0.36, 0.09) or UDim2.fromScale(0.36, 0.1)

	local comboLabel = Instance.new("TextLabel")
	comboLabel.Size = comboBaseSize
	comboLabel.BackgroundTransparency = 1
	comboLabel.TextScaled = true
	comboLabel.Text = ""
	comboLabel.Parent = parent
	if retro then
		comboLabel.Position = UDim2.fromScale(0.29, 0.2)
		Theme.styleRetroImpact(comboLabel, accentColor)
	else
		comboLabel.Position = UDim2.fromScale(0.35, 0.68)
		Theme.styleImpactText(comboLabel)
	end

	local container = Instance.new("Frame")
	container.BorderSizePixel = 0
	container.Parent = parent

	local laneIdleColor: Color3
	local laneCueColor: Color3
	local laneHitColor: Color3
	local laneWhiffColor: Color3

	local meterFill: Frame? = nil
	local meterFrameScale: UIScale? = nil
	local meterStroke: UIStroke? = nil
	local meter = RhythmScoring.meterFor(#notes)
	local meterValue = meter.start
	local warningTween: Tween? = nil
	local laneScales: { [number]: UIScale } = {}

	if retro then
		container.AnchorPoint = Vector2.new(0.5, 0.5)
		container.Size = UDim2.fromScale(0.46, 0.34)
		container.Position = UDim2.fromScale(0.44, 0.52)
		Theme.applyRetroPanel(container, { strokeThickness = 3 })
		addRivet(container, 0, 0, accentColor)
		addRivet(container, 1, 0, accentColor)
		addRivet(container, 0, 1, accentColor)
		addRivet(container, 1, 1, accentColor)

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.fromScale(0.9, subtitle and 0.12 or 0.14)
		titleLabel.Position = UDim2.fromScale(0.05, 0.03)
		titleLabel.BackgroundTransparency = 1
		titleLabel.TextScaled = true
		titleLabel.TextWrapped = true
		titleLabel.Text = title
		titleLabel.Parent = container
		Theme.styleRetroHeader(titleLabel)
		titleLabel.TextStrokeColor3 = accentColor
		titleLabel.TextStrokeTransparency = 0.4

		if subtitle then
			local subtitleLabel = Instance.new("TextLabel")
			subtitleLabel.Size = UDim2.fromScale(0.9, 0.07)
			subtitleLabel.Position = UDim2.fromScale(0.05, 0.15)
			subtitleLabel.BackgroundTransparency = 1
			subtitleLabel.TextScaled = true
			subtitleLabel.TextWrapped = true
			subtitleLabel.Text = subtitle
			subtitleLabel.Parent = container
			Theme.styleRetroBody(subtitleLabel, accentColor)
		end

		laneIdleColor = Theme.RetroColors.WoodMid
		laneCueColor = accentColor
		laneHitColor = Color3.fromRGB(120, 176, 98)
		laneWhiffColor = Theme.RetroColors.Rust

		-- Catch meter: a second wood-framed plaque to the right of the
		-- lane panel, same drop-shadow/rivet treatment, tracking how
		-- close the reel-in is to landing the fish in real time.
		local meterShadow = Instance.new("Frame")
		meterShadow.AnchorPoint = Vector2.new(0.5, 0.5)
		meterShadow.Size = UDim2.fromScale(0.075, 0.4)
		meterShadow.Position = UDim2.fromScale(0.823, 0.523)
		meterShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		meterShadow.BackgroundTransparency = 0.55
		meterShadow.BorderSizePixel = 0
		meterShadow.ZIndex = 0
		meterShadow.Parent = parent
		local meterShadowCorner = Instance.new("UICorner")
		meterShadowCorner.CornerRadius = UDim.new(0, 6)
		meterShadowCorner.Parent = meterShadow

		local meterFrame = Instance.new("Frame")
		meterFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		meterFrame.Size = UDim2.fromScale(0.075, 0.4)
		meterFrame.Position = UDim2.fromScale(0.82, 0.52)
		meterFrame.BorderSizePixel = 0
		meterFrame.Parent = parent
		Theme.applyRetroPanel(meterFrame, { strokeThickness = 3 })
		meterStroke = meterFrame:FindFirstChildOfClass("UIStroke")
		addRivet(meterFrame, 0, 0, accentColor)
		addRivet(meterFrame, 1, 0, accentColor)
		addRivet(meterFrame, 0, 1, accentColor)
		addRivet(meterFrame, 1, 1, accentColor)

		local meterScale = Instance.new("UIScale")
		meterScale.Parent = meterFrame
		meterFrameScale = meterScale

		local meterCaption = Instance.new("TextLabel")
		meterCaption.Size = UDim2.fromScale(0.92, 0.1)
		meterCaption.Position = UDim2.fromScale(0.04, 0.02)
		meterCaption.BackgroundTransparency = 1
		meterCaption.TextScaled = true
		meterCaption.TextWrapped = true
		meterCaption.Text = "CATCH"
		meterCaption.Parent = meterFrame
		Theme.styleRetroHeader(meterCaption)

		local meterTrack = Instance.new("Frame")
		meterTrack.AnchorPoint = Vector2.new(0.5, 1)
		meterTrack.Position = UDim2.fromScale(0.5, 0.94)
		meterTrack.Size = UDim2.fromScale(0.42, 0.76)
		meterTrack.BorderSizePixel = 0
		meterTrack.BackgroundColor3 = Theme.RetroColors.WoodDark
		meterTrack.Parent = meterFrame
		local meterTrackCorner = Instance.new("UICorner")
		meterTrackCorner.CornerRadius = UDim.new(0, 4)
		meterTrackCorner.Parent = meterTrack
		local meterTrackStroke = Instance.new("UIStroke")
		meterTrackStroke.Color = Theme.RetroColors.WoodLight
		meterTrackStroke.Thickness = 2
		meterTrackStroke.Parent = meterTrack

		local fillFrame = Instance.new("Frame")
		fillFrame.AnchorPoint = Vector2.new(0, 1)
		fillFrame.Position = UDim2.fromScale(0, 1)
		fillFrame.Size = UDim2.fromScale(1, meter.start)
		fillFrame.BorderSizePixel = 0
		fillFrame.BackgroundColor3 = accentColor
		fillFrame.Parent = meterTrack
		Theme.applyRetroCard(fillFrame, 3)
		local fillGradient = Instance.new("UIGradient")
		fillGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255):Lerp(accentColor, 0.35)),
			ColorSequenceKeypoint.new(1, accentColor),
		})
		fillGradient.Rotation = 90
		fillGradient.Parent = fillFrame
		meterFill = fillFrame
	else
		container.Size = UDim2.fromScale(0.5, 0.18)
		container.Position = UDim2.fromScale(0.25, 0.78)
		Theme.applyPanel(container)

		laneIdleColor = Color3.fromRGB(55, 40, 60)
		laneCueColor = Theme.Colors.AccentGold
		laneHitColor = Theme.Colors.Success
		laneWhiffColor = Color3.fromRGB(190, 60, 60)
	end

	local laneFrames: { Frame } = {}
	for lane = 1, 4 do
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = laneIdleColor
		frame.Parent = container

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = LANE_KEYS[lane].Name
		label.TextScaled = true
		label.Parent = frame

		if retro then
			frame.Size = UDim2.fromScale(0.22, 0.42)
			frame.Position = UDim2.fromScale((lane - 1) * 0.245 + 0.03, 0.5)
			Theme.applyRetroCard(frame, 6)
			label.FontFace = Theme.RetroFontFace
			label.TextColor3 = Theme.RetroColors.Parchment

			local scale = Instance.new("UIScale")
			scale.Parent = frame
			laneScales[lane] = scale
		else
			frame.Size = UDim2.fromScale(0.23, 0.8)
			frame.Position = UDim2.fromScale((lane - 1) * 0.25 + 0.01, 0.1)
			Theme.applyCard(frame, 8)
			Theme.styleHeader(label, Theme.Colors.TextPrimary)
		end

		laneFrames[lane] = frame
	end

	local hits: { RhythmScoring.Hit } = {}
	local hitNotes: { [number]: boolean } = {}
	local missedNotes: { [number]: boolean } = {}
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
		if warningTween then
			warningTween:Cancel()
			warningTween = nil
		end

		local function finalize()
			PlayerFreeze.stop()
			screenGui:Destroy()
			onComplete(hits)
		end

		if fadeGroup then
			local tween = TweenService:Create(
				fadeGroup,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ GroupTransparency = 1 }
			)
			tween.Completed:Connect(finalize)
			tween:Play()
		else
			finalize()
		end
	end

	-- Retro mode only (meterFill is nil otherwise, so this is a no-op).
	-- Below 30% the fill goes warning-red and the frame's stroke starts a
	-- slow pulse — a losing run should visibly feel like it's slipping
	-- before it actually empties, not just stop dead with no warning.
	-- Emptying the meter ends the chart immediately rather than waiting
	-- for it to run out normally — see this file's header for why that's
	-- safe: the server scores the same fixed note list either way.
	local WARNING_THRESHOLD = 0.3
	local function adjustMeter(delta: number)
		if not meterFill then
			return
		end
		meterValue = math.clamp(meterValue + delta, 0, 1)
		meterFill.Size = UDim2.fromScale(1, meterValue)

		local warning = meterValue <= WARNING_THRESHOLD
		local fillColor = warning and Theme.RetroColors.Rust or accentColor
		meterFill.BackgroundColor3 = fillColor
		local gradient = meterFill:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255):Lerp(fillColor, 0.35)),
				ColorSequenceKeypoint.new(1, fillColor),
			})
		end

		if warning and not warningTween and meterStroke then
			local tween = TweenService:Create(
				meterStroke,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Color = Theme.RetroColors.Rust }
			)
			tween:Play()
			warningTween = tween
		elseif not warning and warningTween then
			warningTween:Cancel()
			warningTween = nil
			if meterStroke then
				meterStroke.Color = Theme.RetroColors.WoodDark
			end
		end

		if delta < 0 and meterFrameScale then
			meterFrameScale.Scale = 0.92
			TweenService:Create(meterFrameScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end

		if meterValue <= 0 then
			-- The dramatic "lost it" beat: a bigger shake than any single
			-- hit/combo gets, right as the fish gets away.
			pcall(SpectacleUI.shake, 0.25, 0.3)
			if retro then
				SoundPlayer.play(SoundIds.ReelMeterEmpty)
			end
			cleanup()
		elseif meterValue >= 1 then
			-- Filling the meter IS the catch. The bar used to be a survival
			-- check -- it only mattered if you let it hit zero, and the fish
			-- was landed when the note chart ran out no matter where the bar
			-- had got to, so it was possible to finish on a nearly-empty bar
			-- and still be told you caught it. Now the bar decides: fill it
			-- and the fish is yours, empty it and it's gone, and the chart
			-- loops (see the Heartbeat below) until one of those happens.
			pcall(SpectacleUI.shake, 0.12, 0.18)
			cleanup()
		end
	end

	-- Retro mode only (laneScales only gets populated then). A quick
	-- squash/pop on the lane card itself — separate from the flash color
	-- and the ring burst below, all three landing in the same instant is
	-- what actually sells a hit as *impactful* rather than just a color
	-- change.
	local function punchLane(laneIndex: number, targetScale: number)
		local scale = laneScales[laneIndex]
		if not scale then
			return
		end
		scale.Scale = targetScale
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end

	local function updateCombo(hitTopWindow: boolean)
		if hitTopWindow then
			liveCombo += 1
			comboLabel.Text = liveCombo >= 2 and `{liveCombo}x COMBO!` or ""
			if liveCombo >= 2 and liveCombo % 3 == 0 then
				comboLabel.TextTransparency = 0
				comboLabel.Size = comboPulseSize
				TweenService:Create(comboLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = comboBaseSize,
				}):Play()
				if retro then
					-- Tied to the milestone pulse (every 3rd top-tier hit in a
					-- row), not every single hit — a shake on every note would
					-- be nauseating; a shake on "you're on a streak" reads as
					-- a payoff instead.
					pcall(SpectacleUI.shake, 0.05, 0.15)
				end
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
			flashColor[laneIndex] = laneHitColor

			local window = RhythmScoring.classify(offset, scoringWindows)
			updateCombo(window.name == topWindowName)
			adjustMeter((window.qualityScore / topWindow.qualityScore) * meter.maxGain)
			if retro then
				punchLane(laneIndex, 1.18)
				spawnHitBurst(laneFrames[laneIndex], laneHitColor)
				SoundPlayer.play(SoundIds.ReelHit)
			end
		else
			-- No note within HIT_TOLERANCE for this lane right now — still
			-- flash (red) so the press is visibly acknowledged instead of
			-- looking identical to a key that didn't register at all.
			flashUntil[laneIndex] = os.clock() + 0.15
			flashColor[laneIndex] = laneWhiffColor
			updateCombo(false) -- whiffed input on this lane breaks the streak too
			if retro then
				punchLane(laneIndex, 0.88)
				SoundPlayer.play(SoundIds.ReelMiss)
			end
		end
	end)

	local endTime = 0
	for _, note in notes do
		endTime = math.max(endTime, note.time)
	end
	endTime += HIT_TOLERANCE + 0.4

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		if finished then
			return
		end
		local elapsed = os.clock() - startTime

		-- A note's window fully passing with no input at all is still a
		-- miss (drains the meter, breaks combo) — otherwise just ignoring
		-- the chart entirely would never cost anything.
		for i, note in notes do
			if not hitNotes[i] and not missedNotes[i] and (elapsed - note.time) > HIT_TOLERANCE then
				missedNotes[i] = true
				updateCombo(false)
				adjustMeter(-meter.missPenalty)
				if retro then
					punchLane(note.lane, 0.85)
					SoundPlayer.play(SoundIds.ReelMiss)
				end
				if finished then
					return
				end
			end
		end

		for lane, frame in laneFrames do
			if flashUntil[lane] and os.clock() < flashUntil[lane] then
				frame.BackgroundColor3 = flashColor[lane] or laneHitColor
			else
				local cueing = false
				for i, note in notes do
					if note.lane == lane and not hitNotes[i] and (note.time - elapsed) <= LOOKAHEAD and (note.time - elapsed) >= -HIT_TOLERANCE then
						cueing = true
						break
					end
				end
				frame.BackgroundColor3 = cueing and laneCueColor or laneIdleColor
			end
		end

		if elapsed >= endTime then
			cleanup()
		end
	end)

	if fadeGroup then
		TweenService:Create(
			fadeGroup,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 0 }
		):Play()
	end
end

return RhythmUI
