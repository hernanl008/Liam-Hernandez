--!strict
-- Cast-power meter (GDD.md §3), previously punted on — see the removed
-- header comment in FishingController.lua explaining it needed a server-
-- side consumer first (FishingService.RequestCast now takes a castPower
-- argument). A vertical fill bar ping-pongs 0->1->0; pressing Space locks
-- in whatever power it's at, same skill-based "stop the moving bar" beat
-- as the reel-in minigame but simpler (one axis, no scoring window).
--
-- Freezes the player for the duration via PlayerFreeze.lua (Client
-- module) — see that file's header for why this needed real debugging
-- to get right (position-pinning alone wasn't enough; WalkSpeed had to
-- be zeroed too, or the character visibly "walks in place").
--
-- Retro-medieval styling (Theme.applyRetroPanel/styleRetroHeader, GDD's
-- new target look, fishing being the first mechanic reskinned) — dark
-- ink text on parchment instead of the anime theme's light-on-dark,
-- since a blocky pixel font reads far better with strong light/dark
-- contrast than it did tinted TextMuted-gray on a dark purple panel.
-- The old "SPACE" hint rotated 90° along the bar is gone too — sideways
-- pixel-font text was genuinely harder to read, not just off-theme.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))
local PlayerFreeze = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("PlayerFreeze"))
local StatusToast = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("StatusToast"))

local CastMeterUI = {}

-- Full 0->1->0 sweep takes 1/CYCLES_PER_SECOND seconds either direction.
local CYCLES_PER_SECOND = 1.1

-- Q, not Escape: Escape/the menu key turned out to be un-sinkable from a
-- LocalScript — Roblox's own core menu claims it below the level any
-- client script (ContextActionService included, even at Max priority)
-- can intercept, confirmed after the ContextAction-Sink fix that worked
-- for Space did nothing here. Q was free (WASD movement, E hook, Space
-- lock, N/B/P/O menus, D/F/J/K rhythm lanes all already taken).
local CANCEL_ACTION = "CastMeterCancel"
local CANCEL_KEY = Enum.KeyCode.Q

-- Without this, walking away (or just not reacting) left the meter open
-- — and the player frozen (PlayerFreeze.lua) — indefinitely. ~7 full
-- sweeps at the cycle speed above; long enough not to feel rushed, short
-- enough that abandoning a cast doesn't strand the player.
local TIMEOUT_SECONDS = 8

local screenGui: ScreenGui? = nil
local fill: Frame

local active = false
local heartbeatConn: RBXScriptConnection? = nil
local elapsed = 0
local finishActive: ((number?) -> ())? = nil

-- Small round rivet/stud, the corner-screw detail medieval wood-UI kits
-- use to sell "this is bolted together," not just a flat rounded corner.
local function addRivet(parent: Instance, anchorX: number, anchorY: number)
	local rivet = Instance.new("Frame")
	rivet.AnchorPoint = Vector2.new(anchorX, anchorY)
	rivet.Position = UDim2.new(anchorX, anchorX == 0 and 5 or -5, anchorY, anchorY == 0 and 5 or -5)
	rivet.Size = UDim2.fromOffset(7, 7)
	rivet.BackgroundColor3 = Theme.RetroColors.Bronze
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

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CastMeterUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	-- Slimmer than the first pass, and a drop shadow (an offset, darker
	-- duplicate sitting behind everything) so the whole thing reads as a
	-- plaque mounted proud of the screen instead of a flat rectangle.
	local shadow = Instance.new("Frame")
	shadow.Size = UDim2.fromScale(0.1, 0.4)
	shadow.Position = UDim2.fromScale(0.033, 0.308)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = gui
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 6)
	shadowCorner.Parent = shadow

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.1, 0.4)
	frame.Position = UDim2.fromScale(0.03, 0.3)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Theme.applyRetroPanel(frame, { strokeThickness = 3 })
	addRivet(frame, 0, 0)
	addRivet(frame, 1, 0)
	addRivet(frame, 0, 1)
	addRivet(frame, 1, 1)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.92, 0.12)
	title.Position = UDim2.fromScale(0.04, 0.03)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.TextWrapped = true
	title.Text = "CAST"
	title.Parent = frame
	Theme.styleRetroHeader(title)

	-- Thin bronze rule under the title separating it from the gauge —
	-- an inlay-trim detail rather than a plain gap.
	local divider = Instance.new("Frame")
	divider.Size = UDim2.fromScale(0.8, 0)
	divider.Position = UDim2.fromScale(0.1, 0.16)
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = Theme.RetroColors.Bronze
	divider.Parent = frame
	local dividerStroke = Instance.new("UIStroke")
	dividerStroke.Thickness = 1
	dividerStroke.Color = Theme.RetroColors.WoodDark
	dividerStroke.Parent = divider

	-- A "slot carved into wood" look for the bar itself — dark recess,
	-- lighter wood rim — distinct from the parchment page it sits on.
	-- Narrower than the first pass so the whole plaque reads slimmer.
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.fromScale(0.5, 0.22)
	track.Size = UDim2.fromScale(0.26, 0.5)
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Theme.RetroColors.WoodDark
	track.Parent = frame
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = Theme.RetroColors.WoodLight
	trackStroke.Thickness = 2
	trackStroke.Parent = track

	local fillFrame = Instance.new("Frame")
	fillFrame.AnchorPoint = Vector2.new(0, 1)
	fillFrame.Position = UDim2.fromScale(0, 1)
	fillFrame.Size = UDim2.fromScale(1, 0)
	fillFrame.BorderSizePixel = 0
	fillFrame.BackgroundColor3 = Theme.RetroColors.Bronze
	fillFrame.Parent = track
	Theme.applyRetroCard(fillFrame, 3)
	-- Gold-to-bronze gradient (not a flat fill) so the gauge reads like a
	-- polished gem/molten-metal charge level rather than a plain bar.
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 221, 143)),
		ColorSequenceKeypoint.new(1, Theme.RetroColors.Bronze),
	})
	fillGradient.Rotation = 90
	fillGradient.Parent = fillFrame
	fill = fillFrame

	local spaceHint = Instance.new("TextLabel")
	spaceHint.Size = UDim2.fromScale(0.92, 0.11)
	spaceHint.Position = UDim2.fromScale(0.04, 0.76)
	spaceHint.BackgroundTransparency = 1
	spaceHint.TextScaled = true
	spaceHint.TextWrapped = true
	spaceHint.Text = "SPACE"
	spaceHint.Parent = frame
	Theme.styleRetroHeader(spaceHint, Theme.RetroColors.Ink)

	local cancelHint = Instance.new("TextLabel")
	cancelHint.Size = UDim2.fromScale(0.92, 0.09)
	cancelHint.Position = UDim2.fromScale(0.04, 0.89)
	cancelHint.BackgroundTransparency = 1
	cancelHint.TextScaled = true
	cancelHint.TextWrapped = true
	cancelHint.Text = "Q"
	cancelHint.Parent = frame
	Theme.styleRetroBody(cancelHint, Theme.RetroColors.InkMuted)
end

-- Fires `onLocked(power)` (0-1) once the player presses Space, or
-- `onLocked(nil)` if `cancel()` is called first (e.g. player walks away).
function CastMeterUI.start(onLocked: (power: number?) -> ())
	ensureBuilt()
	if active then
		return
	end
	active = true
	elapsed = 0
	(screenGui :: ScreenGui).Enabled = true

	local function finish(power: number?)
		if not active then
			return
		end
		active = false
		(screenGui :: ScreenGui).Enabled = false
		PlayerFreeze.stop()
		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
		ContextActionService:UnbindAction(CANCEL_ACTION)
		finishActive = nil
		onLocked(power)
	end
	finishActive = finish

	-- Space is sunk by PlayerFreeze (to block jump), so the lock has to
	-- happen from inside that same handler rather than a separate
	-- UserInputService listener for Space — see PlayerFreeze.lua's header
	-- comment for why a parallel listener doesn't reliably see it.
	PlayerFreeze.start(function()
		local t = (elapsed * CYCLES_PER_SECOND) % 2
		local power = t <= 1 and t or (2 - t)
		finish(power)
	end)

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= TIMEOUT_SECONDS then
			StatusToast.setTemporary("You hesitated too long — the line snaps back empty.", 2.5, true)
			finish(nil)
			return
		end
		local t = (elapsed * CYCLES_PER_SECOND) % 2
		local power = t <= 1 and t or (2 - t)
		fill.Size = UDim2.fromScale(1, power)
	end)

	ContextActionService:BindActionAtPriority(
		CANCEL_ACTION,
		function(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then
				finish(nil)
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		CANCEL_KEY
	)
end

function CastMeterUI.cancel()
	if not active or not finishActive then
		return
	end
	finishActive(nil)
end

function CastMeterUI.isActive(): boolean
	return active
end

return CastMeterUI
