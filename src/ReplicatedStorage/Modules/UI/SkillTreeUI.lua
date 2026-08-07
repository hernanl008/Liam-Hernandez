--!strict
-- Skill tree screen (GDD.md §12): a branching tree on a canvas you drag
-- and zoom around, not a list of cards.
--
-- What the shape is doing, borrowed from Liam's Diablo IV reference and
-- rebuilt in this game's wood-and-parchment palette:
--
--   * A ROOT SPINE along the bottom joining every branch, so the trees
--     read as one system with three limbs rather than three unrelated
--     lists.
--   * TRUNKS rising from the spine with nodes threaded on them, so
--     progression is literally upward movement.
--   * CONNECTORS dark while locked, lit once the path is taken. The lit
--     portion of the tree is a picture of your progress, readable at a
--     glance — and energy visibly FLOWS up the lit runs, so the tree
--     looks alive rather than merely coloured in.
--
-- Each branch owns an accent colour, and that colour carries through its
-- spine stub, trunk, node rims, icon tint and detail plaque. Three
-- branches in one bronze was legible but anonymous; colour is what makes
-- "the fishing line" a thing you can find without reading.
--
-- Nothing here needs an uploaded asset to work. Perk icons come from one
-- optional sheet (tools/make_perk_icon_sheet.py) and fall back to a
-- carved diamond when it isn't uploaded, so the screen is never broken
-- waiting on art.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local SkillTreeConfig = require(Modules:WaitForChild("Shared"):WaitForChild("SkillTreeConfig"))
local AssetIds = require(Modules:WaitForChild("Shared"):WaitForChild("AssetIds"))
local SoundIds = require(Modules:WaitForChild("Shared"):WaitForChild("SoundIds"))
local SoundPlayer = require(Modules:WaitForChild("Client"):WaitForChild("SoundPlayer"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local SkillTreeUI = {}

local SKILL_ORDER: { SkillTreeConfig.SkillId } = { "Farming", "Fishing", "Cooking" }

-- One accent per branch. Deliberately kept inside the game's warm range
-- rather than being three saturated primaries — they have to sit on
-- parchment next to each other without any one of them shouting.
local BRANCH_ACCENT: { [string]: Color3 } = {
	Farming = Color3.fromRGB(112, 152, 74),
	Fishing = Color3.fromRGB(78, 132, 176),
	Cooking = Color3.fromRGB(198, 118, 58),
}

-- Row-major cell index into assets/sprites/perk_icons.png. Keep in sync
-- with the PERKS order in tools/make_perk_icon_sheet.py.
local ICON_CELL = 32
local ICON_COLUMNS = 3
local PERK_ICON_CELLS: { [string]: number } = {
	GreenThumb = 0,
	NoTillNeeded = 1,
	MarketSavvy = 2,
	QuickHands = 3,
	TreasureHunter = 4,
	SteadyHands = 5,
	EfficientCook = 6,
	ShowStopper = 7,
	SignatureDish = 8,
}

local NODE_SIZE = 68
local TRUNK_WIDTH = 8
local SPINE_HEIGHT = 8
local BRANCH_SPACING = 340
local CANVAS_PAD_X = 220
local CANVAS_PAD_TOP = 150
local CANVAS_PAD_BOTTOM = 96
-- The canvas is made larger than the viewport so dragging always has
-- somewhere to go. Sized to the tree alone, three short branches fit
-- inside a desktop window and the drag would be dead on exactly the
-- screens most people play on.
local OVERSCAN = 1.35
local NODE_SPACING = 150
local TRUNK_BASE = 110

local ZOOM_MIN = 0.6
local ZOOM_MAX = 1.5
local ZOOM_STEP = 0.12
-- Pan momentum after a flick. Per-frame decay; 0.9 keeps a throw
-- readable for about half a second without feeling slippery.
local PAN_FRICTION = 0.9
local PAN_STOP_SPEED = 6

local COLOR_LOCKED = Color3.fromRGB(96, 74, 56)
local COLOR_TRACK = Color3.fromRGB(112, 88, 62)

local screenGui: ScreenGui? = nil
local backdrop: Frame
local panel: Frame
local panelScale: UIScale
local viewport: Frame
local canvas: Frame
local canvasScale: UIScale
local canvasExtent = Vector2.new(0, 0)
-- The tree's own bounds inside the canvas, which is bigger than it. Kept
-- so the view can be fitted and centred on the TREE rather than on the
-- padding around it.
local treeSpan = Vector2.new(0, 0)
local treeCenter = Vector2.new(0, 0)
local zoom = 1
local pointsLabel: TextLabel
local detailName: TextLabel
local detailBody: TextLabel
local detailMeta: TextLabel
local detailAccent: Frame
local helpPanel: Frame
local visible = false

-- Bumped on every rebuild; staggered open animations check they still
-- own the screen so a fast close-then-open can't have an old sequence
-- animate widgets belonging to the new one.
local buildToken = 0

type PerkStatus = "unlocked" | "available" | "prereqLocked" | "levelLocked"

local function perkStatus(
	perk: SkillTreeConfig.PerkDef,
	level: number,
	unlockedPerks: { [string]: boolean }
): PerkStatus
	if unlockedPerks[perk.id] then
		return "unlocked"
	end
	if level < perk.requiredLevel then
		return "levelLocked"
	end
	if perk.requires and not unlockedPerks[perk.requires] then
		return "prereqLocked"
	end
	return "available"
end

-- ---------------------------------------------------------------------
-- Panning and zoom

local dragging = false
local dragMoved = false
local dragOrigin = Vector2.new(0, 0)
local canvasOrigin = Vector2.new(0, 0)
local panVelocity = Vector2.new(0, 0)
local lastDragPosition = Vector2.new(0, 0)

local function scaledExtent(): Vector2
	return canvasExtent * zoom
end

local function clampCanvas(x: number, y: number): (number, number)
	local view = viewport.AbsoluteSize
	local extent = scaledExtent()
	local slackX = extent.X - view.X
	local slackY = extent.Y - view.Y
	-- Centre on any axis where the tree is smaller than the window.
	-- Letting it drift there would mean dragging the tree off into empty
	-- parchment, which reads as the screen being broken.
	x = if slackX <= 0 then (view.X - extent.X) / 2 else math.clamp(x, -slackX, 0)
	y = if slackY <= 0 then (view.Y - extent.Y) / 2 else math.clamp(y, -slackY, 0)
	return x, y
end

local function setCanvasPosition(x: number, y: number)
	local cx, cy = clampCanvas(x, y)
	canvas.Position = UDim2.fromOffset(cx, cy)
end

local function applyZoom(delta: number, focus: Vector2)
	local previous = zoom
	zoom = math.clamp(zoom + delta, ZOOM_MIN, ZOOM_MAX)
	if zoom == previous then
		return
	end
	canvasScale.Scale = zoom

	-- Keep the point under the cursor pinned while scaling, which is what
	-- makes zoom feel like moving a camera rather than resizing a picture.
	-- Without this the tree slides away from wherever you were looking.
	local origin = Vector2.new(canvas.Position.X.Offset, canvas.Position.Y.Offset)
	local viewportTopLeft = viewport.AbsolutePosition
	local local_ = focus - viewportTopLeft - origin
	local ratio = zoom / previous
	setCanvasPosition(origin.X - local_.X * (ratio - 1), origin.Y - local_.Y * (ratio - 1))
end

-- Begins a pan. Exposed rather than inlined because it has to be
-- connected to the NODE BUTTONS as well as the viewport.
--
-- This was the "can't click a node" bug: a TextButton sinks the input
-- that starts on it, so viewport.InputBegan never fired for a press on a
-- node, dragMoved was never reset, and after any pan it stayed true
-- forever -- so every subsequent node click hit the "this was a drag,
-- not a click" guard and was silently ignored. Connecting both means the
-- flag is always reset by the press that precedes the click, and you can
-- drag the canvas starting from a node as well.
local function beginDrag(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	dragging = true
	dragMoved = false
	panVelocity = Vector2.new(0, 0)
	dragOrigin = Vector2.new(input.Position.X, input.Position.Y)
	lastDragPosition = dragOrigin
	canvasOrigin = Vector2.new(canvas.Position.X.Offset, canvas.Position.Y.Offset)
end

local function setupPanning()
	viewport.InputBegan:Connect(beginDrag)

	-- Ended is watched on UserInputService rather than the viewport: a
	-- drag finishing with the cursor outside the panel would otherwise
	-- never release, and the canvas would keep following the mouse.
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseWheel and visible then
			-- GetMouseLocation reports below Roblox's topbar, while a
			-- GuiObject's AbsolutePosition is measured from the very top of
			-- the window, so the two need the inset reconciled before they
			-- can be subtracted. Left uncorrected the zoom anchors about a
			-- topbar's height above the cursor.
			local inset = GuiService:GetGuiInset()
			local mouse = UserInputService:GetMouseLocation() + inset
			applyZoom(input.Position.Z * ZOOM_STEP, mouse)
			return
		end
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		local delta = position - dragOrigin
		if delta.Magnitude > 4 then
			dragMoved = true
		end
		panVelocity = position - lastDragPosition
		lastDragPosition = position
		setCanvasPosition(canvasOrigin.X + delta.X, canvasOrigin.Y + delta.Y)
	end)

	-- Momentum. A tree you flick and watch glide to a stop feels like a
	-- map; one that halts dead the instant you let go feels like a
	-- scrollbar.
	RunService.RenderStepped:Connect(function()
		if dragging or not visible then
			return
		end
		if panVelocity.Magnitude < PAN_STOP_SPEED then
			panVelocity = Vector2.new(0, 0)
			return
		end
		local origin = Vector2.new(canvas.Position.X.Offset, canvas.Position.Y.Offset)
		setCanvasPosition(origin.X + panVelocity.X, origin.Y + panVelocity.Y)
		panVelocity *= PAN_FRICTION
	end)
end

-- ---------------------------------------------------------------------
-- Pieces

local function setDetail(name: string, body: string, meta: string, tone: Color3)
	detailName.Text = string.upper(name)
	detailName.TextColor3 = tone
	detailBody.Text = string.upper(body)
	detailMeta.Text = string.upper(meta)
	detailAccent.BackgroundColor3 = tone
end

-- One connector segment. Returns its FILL, which the open sequence grows
-- and which carries the flowing highlight while lit.
local function makeConnector(x: number, bottom: number, height: number, lit: boolean, accent: Color3): Frame
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0, x, 1, -bottom)
	track.Size = UDim2.fromOffset(TRUNK_WIDTH, height)
	track.BackgroundColor3 = COLOR_TRACK
	track.BorderSizePixel = 0
	track.ZIndex = 4
	track.Parent = canvas

	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0.5, 1)
	fill.Position = UDim2.fromScale(0.5, 1)
	-- Starts at zero height; the open sequence tweens it up, which is what
	-- makes the tree draw itself rather than simply appear.
	fill.Size = UDim2.new(1, 0, 0, 0)
	fill.BackgroundColor3 = accent
	fill.BorderSizePixel = 0
	fill.ZIndex = 5
	fill.Parent = track
	fill:SetAttribute("Lit", lit)

	if lit then
		-- Energy flow: a bright band riding up the lit run, made by
		-- sliding a gradient's offset rather than moving a child frame —
		-- one instance, and it can't escape the segment's bounds.
		local flow = Instance.new("UIGradient")
		flow.Rotation = 90
		flow.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent),
			ColorSequenceKeypoint.new(0.45, accent),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1):Lerp(accent, 0.25)),
			ColorSequenceKeypoint.new(0.55, accent),
			ColorSequenceKeypoint.new(1, accent),
		})
		flow.Offset = Vector2.new(0, 1)
		flow.Parent = fill
		TweenService:Create(flow, TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {
			Offset = Vector2.new(0, -1),
		}):Play()
	end

	return fill
end

local function makeNode(
	x: number,
	bottom: number,
	status: PerkStatus,
	perk: SkillTreeConfig.PerkDef,
	skillId: SkillTreeConfig.SkillId,
	level: number,
	accent: Color3
): Frame
	-- Holder stays un-rotated so hover scaling and the pop act on an
	-- upright box; only the plate behind the icon is turned 45 degrees.
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0, x, 1, -bottom)
	holder.Size = UDim2.fromOffset(NODE_SIZE, NODE_SIZE)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 6
	holder.Parent = canvas

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder

	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromScale(0.76, 0.76)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Theme.RetroColors.WoodDark
	diamond.BorderSizePixel = 0
	diamond.ZIndex = 6
	diamond.Parent = holder

	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -7, 1, -7)
	inner.BorderSizePixel = 0
	inner.ZIndex = 7
	inner.Parent = diamond

	local glow = Instance.new("UIStroke")
	glow.Thickness = 2
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glow.Parent = inner

	-- Icon sits on the holder, NOT inside the rotated plate: a child of a
	-- rotated frame inherits the rotation, and a 45-degree pictograph is
	-- not the goal.
	local iconSheet = AssetIds.sprite("perk_icons")
	local iconTint: Color3
	if status == "unlocked" then
		inner.BackgroundColor3 = accent
		glow.Color = Theme.RetroColors.Parchment
		glow.Transparency = 0.25
		iconTint = Theme.RetroColors.Parchment
	elseif status == "available" then
		inner.BackgroundColor3 = Theme.RetroColors.Parchment
		glow.Color = accent
		glow.Transparency = 0
		iconTint = Theme.RetroColors.Ink
		-- Available perks breathe. It is the only moving thing on an
		-- otherwise still branch, so the eye lands on what can be spent.
		TweenService:Create(
			glow,
			TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.6 }
		):Play()
	else
		inner.BackgroundColor3 = COLOR_LOCKED
		glow.Color = Theme.RetroColors.WoodDark
		glow.Transparency = 0.4
		iconTint = Color3.fromRGB(64, 48, 34)
	end

	if iconSheet ~= "rbxassetid://0" and PERK_ICON_CELLS[perk.id] then
		local index = PERK_ICON_CELLS[perk.id]
		local icon = Instance.new("ImageLabel")
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		-- Integer multiple of the 32px cell, so the pixels stay square.
		icon.Size = UDim2.fromOffset(ICON_CELL, ICON_CELL)
		icon.BackgroundTransparency = 1
		icon.Image = iconSheet
		icon.ImageColor3 = iconTint
		icon.ResampleMode = Enum.ResamplerMode.Pixelated
		icon.ImageRectSize = Vector2.new(ICON_CELL, ICON_CELL)
		icon.ImageRectOffset = Vector2.new((index % ICON_COLUMNS) * ICON_CELL, math.floor(index / ICON_COLUMNS) * ICON_CELL)
		icon.ZIndex = 8
		icon.Parent = holder
	else
		-- No sheet uploaded: a carved pip, so the node still reads as a
		-- node rather than an empty plate.
		local pip = Instance.new("Frame")
		pip.AnchorPoint = Vector2.new(0.5, 0.5)
		pip.Position = UDim2.fromScale(0.5, 0.5)
		pip.Size = UDim2.fromOffset(14, 14)
		pip.Rotation = 45
		pip.BackgroundColor3 = iconTint
		pip.BorderSizePixel = 0
		pip.ZIndex = 8
		pip.Parent = holder
	end

	-- Click and hover target, laid over everything un-rotated so the hit
	-- area is the upright square the player perceives.
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.AutoButtonColor = false
	button.ZIndex = 9
	button.Parent = holder

	local meta: string
	local tone = Theme.RetroColors.Ink
	if status == "unlocked" then
		meta = "UNLOCKED"
		tone = accent
	elseif status == "available" then
		meta = `CLICK TO UNLOCK - COSTS {perk.cost} POINT{perk.cost == 1 and "" or "S"}`
		tone = Theme.RetroColors.Rust
	elseif status == "prereqLocked" then
		meta = "LOCKED - TAKE THE PERK BELOW IT FIRST"
	else
		meta = `LOCKED - NEEDS LEVEL {perk.requiredLevel}, YOU ARE {level}`
	end

	button.InputBegan:Connect(beginDrag)

	button.MouseEnter:Connect(function()
		setDetail(perk.displayName, perk.description, meta, tone)
		SoundPlayer.play(SoundIds.SkillHover)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.18,
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)

	if status == "available" then
		button.Activated:Connect(function()
			-- A drag that happens to end over a node must not buy it. The
			-- canvas is dragged with the same button that clicks nodes, so
			-- without this a pan across the tree spends points.
			if dragMoved then
				return
			end
			Remotes.get("UnlockPerk"):FireServer(skillId, perk.id)
			SoundPlayer.play(SoundIds.SkillUnlock)

			-- Local confirmation: a ring bursting out of the node. The
			-- authoritative redraw arrives from the server via
			-- SkillTreeController; this only answers the press immediately.
			local burst = Instance.new("Frame")
			burst.AnchorPoint = Vector2.new(0.5, 0.5)
			burst.Position = UDim2.fromScale(0.5, 0.5)
			burst.Size = UDim2.fromOffset(NODE_SIZE, NODE_SIZE)
			burst.BackgroundTransparency = 1
			burst.Rotation = 45
			burst.ZIndex = 10
			burst.Parent = holder
			local burstStroke = Instance.new("UIStroke")
			burstStroke.Color = accent
			burstStroke.Thickness = 3
			burstStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			burstStroke.Parent = burst
			TweenService:Create(burst, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(NODE_SIZE * 2.4, NODE_SIZE * 2.4),
			}):Play()
			TweenService:Create(burstStroke, TweenInfo.new(0.45), { Transparency = 1 }):Play()
			task.delay(0.5, function()
				burst:Destroy()
			end)
		end)
	end

	return holder
end

local function buildBranch(
	skillId: SkillTreeConfig.SkillId,
	index: number,
	spineBottom: number,
	branchOffsetX: number
): { Instance }
	local snapshot = InventoryCache.get()
	local tree = SkillTreeConfig.Trees[skillId]
	local xp = snapshot.skillXp[skillId] or 0
	local level = 1 + math.floor(xp / SkillTreeConfig.xpPerLevel)
	local xpIntoLevel = xp % SkillTreeConfig.xpPerLevel
	local points = snapshot.skillPoints[skillId] or 0
	local unlockedPerks = snapshot.unlockedPerks[skillId] or {}
	local accent = BRANCH_ACCENT[skillId] or Theme.RetroColors.Bronze

	local x = branchOffsetX + CANVAS_PAD_X + (index - 1) * BRANCH_SPACING
	local animated: { Instance } = {}

	for i, perk in tree.perks do
		local status = perkStatus(perk, level, unlockedPerks)
		local nodeBottom = spineBottom + TRUNK_BASE + (i - 1) * NODE_SPACING
		local segmentBottom = if i == 1 then spineBottom else spineBottom + TRUNK_BASE + (i - 2) * NODE_SPACING
		local segmentHeight = nodeBottom - segmentBottom

		-- A segment is lit when the perk above it is unlocked, so the lit
		-- run up a trunk is exactly how far the player has climbed.
		local fill = makeConnector(x, segmentBottom, segmentHeight, status == "unlocked", accent)
		fill:SetAttribute("FullHeight", segmentHeight)
		table.insert(animated, fill)

		table.insert(animated, makeNode(x, nodeBottom, status, perk, skillId, level, accent))
	end

	-- Base plaque where the trunk meets the spine. The reference hangs an
	-- icon at each branch root; a named plate with the level and an XP bar
	-- does that anchoring job and answers "how close am I to the next
	-- point" without a second screen.
	local plaque = Instance.new("Frame")
	plaque.AnchorPoint = Vector2.new(0.5, 0.5)
	plaque.Position = UDim2.new(0, x, 1, -spineBottom)
	plaque.Size = UDim2.fromOffset(186, 46)
	plaque.ZIndex = 7
	plaque.Parent = canvas
	local plaqueFace = Theme.framedPanel(plaque, 6)

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(0, 6)
	label.Size = UDim2.new(1, 0, 0, 14)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.RetroFontFace
	label.TextSize = 11
	label.TextColor3 = Theme.RetroColors.Ink
	label.Text = `{string.upper(tree.displayName)} {level}`
	label.ZIndex = 8
	label.Parent = plaqueFace

	local xpTrack = Instance.new("Frame")
	xpTrack.AnchorPoint = Vector2.new(0.5, 1)
	xpTrack.Position = UDim2.new(0.5, 0, 1, -8)
	xpTrack.Size = UDim2.new(1, -24, 0, 4)
	xpTrack.BackgroundColor3 = Theme.RetroColors.ParchmentShadow
	xpTrack.BorderSizePixel = 0
	xpTrack.ZIndex = 8
	xpTrack.Parent = plaqueFace
	local xpCorner = Instance.new("UICorner")
	xpCorner.CornerRadius = UDim.new(1, 0)
	xpCorner.Parent = xpTrack

	local xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(xpIntoLevel / SkillTreeConfig.xpPerLevel, 1)
	xpFill.BackgroundColor3 = accent
	xpFill.BorderSizePixel = 0
	xpFill.ZIndex = 9
	xpFill.Parent = xpTrack
	local xpFillCorner = Instance.new("UICorner")
	xpFillCorner.CornerRadius = UDim.new(1, 0)
	xpFillCorner.Parent = xpFill

	-- Unspent points ride on the plaque as a badge, where the branch they
	-- belong to is. A single global total elsewhere would not tell you
	-- WHICH tree can be spent.
	if points > 0 then
		local badge = Instance.new("Frame")
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Position = UDim2.new(1, 10, 0, 0)
		badge.Size = UDim2.fromOffset(26, 26)
		badge.BackgroundColor3 = Theme.RetroColors.Rust
		badge.BorderSizePixel = 0
		badge.ZIndex = 9
		badge.Parent = plaque
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(1, 0)
		badgeCorner.Parent = badge
		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color = Theme.RetroColors.WoodDark
		badgeStroke.Thickness = 2
		badgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		badgeStroke.Parent = badge

		local badgeLabel = Instance.new("TextLabel")
		badgeLabel.Size = UDim2.fromScale(1, 1)
		badgeLabel.BackgroundTransparency = 1
		badgeLabel.FontFace = Theme.RetroFontFace
		badgeLabel.TextSize = 11
		badgeLabel.TextColor3 = Theme.RetroColors.Parchment
		badgeLabel.Text = tostring(points)
		badgeLabel.ZIndex = 10
		badgeLabel.Parent = badge
	end

	return animated
end

-- ---------------------------------------------------------------------
-- Background

-- Extent the lattice was last painted for, so it is only redrawn when
-- the canvas changes size. rebuild() runs on every perk unlock, and
-- repainting a few hundred Frames to recreate a background that never
-- changes would be pure waste.
local latticeExtent = Vector2.new(-1, -1)

local function paintLattice()
	if latticeExtent == canvasExtent then
		return
	end
	for _, child in canvas:GetChildren() do
		if child.Name == "Lattice" then
			child:Destroy()
		end
	end
	latticeExtent = canvasExtent

	local spacing = 96
	for column = 0, math.ceil(canvasExtent.X / spacing) do
		for row = 0, math.ceil(canvasExtent.Y / spacing) do
			local mark = Instance.new("Frame")
			mark.Name = "Lattice"
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.fromOffset(column * spacing, row * spacing)
			mark.Size = UDim2.fromOffset(6, 6)
			mark.Rotation = 45
			mark.BackgroundColor3 = Theme.RetroColors.WoodLight
			-- Alternating weight, so it reads as a woven pattern rather
			-- than graph paper.
			mark.BackgroundTransparency = if (column + row) % 2 == 0 then 0.82 else 0.9
			mark.BorderSizePixel = 0
			mark.ZIndex = 2
			mark.Parent = canvas
		end
	end
end

-- Darkened edges inside the viewport. Roblox has no radial gradient, so
-- this is four one-directional gradients along the borders — enough to
-- stop the tree looking like it was cut off with scissors where the
-- clipping ends.
local function buildVignette()
	local edges = {
		{ size = UDim2.new(1, 0, 0, 70), pos = UDim2.fromScale(0, 0), anchor = Vector2.new(0, 0), rotation = 90 },
		{ size = UDim2.new(1, 0, 0, 70), pos = UDim2.fromScale(0, 1), anchor = Vector2.new(0, 1), rotation = 270 },
		{ size = UDim2.new(0, 70, 1, 0), pos = UDim2.fromScale(0, 0), anchor = Vector2.new(0, 0), rotation = 0 },
		{ size = UDim2.new(0, 70, 1, 0), pos = UDim2.fromScale(1, 0), anchor = Vector2.new(1, 0), rotation = 180 },
	}
	for _, edge in edges do
		local shade = Instance.new("Frame")
		shade.Size = edge.size
		shade.Position = edge.pos
		shade.AnchorPoint = edge.anchor
		shade.BackgroundColor3 = Color3.fromRGB(74, 48, 26)
		shade.BorderSizePixel = 0
		shade.ZIndex = 12
		shade.Parent = viewport
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = shade
	end
end

-- ---------------------------------------------------------------------

-- Small square button in the panel's top-right cluster. Returns the
-- TextButton so the caller can wire it; the frame around it is the same
-- layered treatment every other panel uses, so the controls do not read
-- as a different toolkit bolted on.
local function makeToolButton(parent: Frame, order: number, glyph: string, size: number): TextButton
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -(order - 1) * 34, 0, 0)
	holder.Size = UDim2.fromOffset(30, 30)
	holder.ZIndex = 17
	holder.Parent = parent
	local face = Theme.framedPanel(holder, 5)

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Text = glyph
	-- Gotham, not the pixel face: PressStart2P is ASCII-only and has no
	-- glyph for the symbols these buttons want.
	button.Font = Enum.Font.GothamBold
	button.TextSize = size
	button.TextColor3 = Theme.RetroColors.Ink
	button.ZIndex = 18
	button.Parent = face

	button.MouseEnter:Connect(function()
		button.TextColor3 = Theme.RetroColors.Rust
	end)
	button.MouseLeave:Connect(function()
		button.TextColor3 = Theme.RetroColors.Ink
	end)
	return button
end

-- Overlay explaining the controls. Discoverability is the whole reason
-- it exists: pan and zoom are invisible affordances, and a player who
-- does not know the canvas moves will conclude the top of the tree is
-- simply cut off.
local function buildHelp(parent: Frame)
	helpPanel = Instance.new("Frame")
	helpPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	helpPanel.Position = UDim2.fromScale(0.5, 0.5)
	helpPanel.Size = UDim2.fromOffset(400, 200)
	helpPanel.Visible = false
	helpPanel.ZIndex = 20
	helpPanel.Parent = parent
	local face = Theme.framedPanel(helpPanel, 8)

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 14)
	title.Size = UDim2.new(1, -32, 0, 16)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.FontFace = Theme.RetroFontFace
	title.TextSize = 13
	title.TextColor3 = Theme.RetroColors.Rust
	title.Text = "HOW TO READ THIS"
	title.ZIndex = 21
	title.Parent = face

	local body = Instance.new("TextLabel")
	body.Position = UDim2.fromOffset(16, 42)
	body.Size = UDim2.new(1, -32, 1, -70)
	body.BackgroundTransparency = 1
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.FontFace = Theme.RetroFontFace
	body.TextSize = 10
	body.LineHeight = 1.5
	body.TextColor3 = Theme.RetroColors.Ink
	body.Text = "DRAG ANYWHERE TO MOVE THE TREE.\n"
		.. "SCROLL OR USE + AND - TO ZOOM.\n"
		.. "HOVER A NODE TO READ IT.\n"
		.. "A GLOWING NODE CAN BE BOUGHT - CLICK IT.\n"
		.. "EACH BRANCH HAS ITS OWN COLOUR.\n"
		.. "P CLOSES THIS SCREEN."
	body.ZIndex = 21
	body.Parent = face

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -12)
	close.Size = UDim2.fromOffset(120, 26)
	close.BackgroundTransparency = 1
	close.AutoButtonColor = false
	close.Text = "GOT IT"
	close.FontFace = Theme.RetroFontFace
	close.TextSize = 10
	close.TextColor3 = Theme.RetroColors.Rust
	close.ZIndex = 21
	close.Parent = face
	close.Activated:Connect(function()
		helpPanel.Visible = false
	end)
end

local function ensureBuilt()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillTreeUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 6
	-- Under Roblox's topbar too, so the screen is genuinely full-bleed.
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	-- Dim the world behind. A full-screen menu that doesn't dim reads as
	-- floating debris over the game rather than a screen you're in.
	backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(18, 10, 6)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 1
	backdrop.Parent = gui

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	-- Edge to edge. The 12px margin this used to leave let the dim
	-- backdrop show as a dark band around the whole panel, which read as
	-- a rendering fault rather than as a border.
	panel.Size = UDim2.fromScale(1, 1)
	panel.ZIndex = 3
	panel.Parent = gui

	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local face = Theme.framedPanel(panel, 0)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.Parent = face

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.FontFace = Theme.RetroFontFace
	title.TextSize = 15
	title.TextColor3 = Theme.RetroColors.Ink
	title.Text = "SKILLS"
	title.ZIndex = 4
	title.Parent = face

	pointsLabel = Instance.new("TextLabel")
	-- Stops short of the three tool buttons in the same corner. Full width
	-- ran the text underneath them.
	pointsLabel.Size = UDim2.new(1, -110, 0, 20)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Right
	pointsLabel.FontFace = Theme.RetroFontFace
	pointsLabel.TextSize = 10
	pointsLabel.TextColor3 = Theme.RetroColors.InkMuted
	pointsLabel.Text = ""
	pointsLabel.ZIndex = 4
	pointsLabel.Parent = face

	viewport = Instance.new("Frame")
	viewport.Position = UDim2.fromOffset(0, 30)
	viewport.Size = UDim2.new(1, 0, 1, -114)
	viewport.BackgroundTransparency = 1
	viewport.ClipsDescendants = true
	viewport.ZIndex = 4
	viewport.Parent = face

	canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.ZIndex = 4
	canvas.Parent = viewport

	canvasScale = Instance.new("UIScale")
	canvasScale.Parent = canvas

	buildVignette()
	setupPanning()

	-- Zoom and help controls, top right of the panel. Scroll-to-zoom is an
	-- invisible affordance and it does not exist at all on touch, so the
	-- buttons are the real control and the wheel is the shortcut.
	local zoomIn = makeToolButton(face, 3, "+", 20)
	local zoomOut = makeToolButton(face, 2, "\u{2212}", 20)
	local helpButton = makeToolButton(face, 1, "?", 18)
	zoomIn.Activated:Connect(function()
		local view = viewport.AbsoluteSize
		applyZoom(ZOOM_STEP * 2, viewport.AbsolutePosition + view / 2)
	end)
	zoomOut.Activated:Connect(function()
		local view = viewport.AbsoluteSize
		applyZoom(-ZOOM_STEP * 2, viewport.AbsolutePosition + view / 2)
	end)
	helpButton.Activated:Connect(function()
		helpPanel.Visible = not helpPanel.Visible
	end)

	-- Detail plaque, pinned to the bottom. One description at a time,
	-- filled in on hover — three on screen at once is what made the old
	-- card layout a wall of text.
	local detail = Instance.new("Frame")
	detail.AnchorPoint = Vector2.new(0, 1)
	detail.Position = UDim2.fromScale(0, 1)
	detail.Size = UDim2.new(1, 0, 0, 76)
	detail.ZIndex = 14
	detail.Parent = face
	local detailFace = Theme.framedPanel(detail, 6)

	-- Colour bar keyed to the hovered branch, so the plaque says which
	-- tree it is talking about before you read a word of it.
	--
	-- No UIPadding on this face, and the labels carry their own inset
	-- instead. UIPadding shifts EVERY child, so the stripe was pushed to
	-- the same x as the text and sat on top of it — the first character
	-- of every line was disappearing behind the bar.
	detailAccent = Instance.new("Frame")
	detailAccent.Size = UDim2.new(0, 5, 1, -12)
	detailAccent.Position = UDim2.fromOffset(10, 6)
	detailAccent.BackgroundColor3 = Theme.RetroColors.Bronze
	detailAccent.BorderSizePixel = 0
	detailAccent.ZIndex = 15
	detailAccent.Parent = detailFace

	detailName = Instance.new("TextLabel")
	detailName.Position = UDim2.fromOffset(26, 10)
	detailName.Size = UDim2.new(1, -38, 0, 14)
	detailName.BackgroundTransparency = 1
	detailName.TextXAlignment = Enum.TextXAlignment.Left
	detailName.FontFace = Theme.RetroFontFace
	detailName.TextSize = 12
	detailName.TextColor3 = Theme.RetroColors.Rust
	detailName.Text = ""
	detailName.ZIndex = 16
	detailName.Parent = detailFace

	detailBody = Instance.new("TextLabel")
	detailBody.Position = UDim2.fromOffset(26, 30)
	detailBody.Size = UDim2.new(1, -38, 0, 26)
	detailBody.BackgroundTransparency = 1
	detailBody.TextXAlignment = Enum.TextXAlignment.Left
	detailBody.TextYAlignment = Enum.TextYAlignment.Top
	detailBody.TextWrapped = true
	detailBody.FontFace = Theme.RetroFontFace
	detailBody.TextSize = 10
	detailBody.LineHeight = 1.3
	detailBody.TextColor3 = Theme.RetroColors.Ink
	detailBody.Text = "HOVER A NODE TO INSPECT IT."
	detailBody.ZIndex = 16
	detailBody.Parent = detailFace

	detailMeta = Instance.new("TextLabel")
	detailMeta.AnchorPoint = Vector2.new(0, 1)
	detailMeta.Position = UDim2.new(0, 26, 1, -8)
	detailMeta.Size = UDim2.new(1, -38, 0, 12)
	detailMeta.BackgroundTransparency = 1
	detailMeta.TextXAlignment = Enum.TextXAlignment.Left
	detailMeta.FontFace = Theme.RetroFontFace
	detailMeta.TextSize = 9
	detailMeta.TextColor3 = Theme.RetroColors.InkMuted
	detailMeta.Text = "DRAG TO PAN - SCROLL TO ZOOM - ? FOR HELP - P TO CLOSE"
	detailMeta.ZIndex = 16
	detailMeta.Parent = detailFace

	buildHelp(face)
end


local function spineWidthTargetFor(): number
	return (#SKILL_ORDER - 1) * BRANCH_SPACING
end

local function rebuild()
	buildToken += 1
	local token = buildToken

	-- Everything except the lattice, which outlives a rebuild.
	for _, child in canvas:GetChildren() do
		if child.Name ~= "Lattice" then
			child:Destroy()
		end
	end

	local snapshot = InventoryCache.get()
	local totalPoints = 0
	for _, skillId in SKILL_ORDER do
		totalPoints += snapshot.skillPoints[skillId] or 0
	end
	pointsLabel.Text = string.upper(`{totalPoints} UNSPENT POINT{totalPoints == 1 and "" or "S"}`)

	local longest = 0
	for _, skillId in SKILL_ORDER do
		longest = math.max(longest, #SkillTreeConfig.Trees[skillId].perks)
	end

	local spineBottom = CANVAS_PAD_BOTTOM
	local treeWidth = CANVAS_PAD_X * 2 + (#SKILL_ORDER - 1) * BRANCH_SPACING
	local treeHeight = spineBottom + TRUNK_BASE + (longest - 1) * NODE_SPACING + NODE_SIZE / 2 + CANVAS_PAD_TOP

	local view = viewport.AbsoluteSize
	canvasExtent = Vector2.new(math.max(treeWidth, view.X * OVERSCAN), math.max(treeHeight, view.Y * OVERSCAN))
	canvas.Size = UDim2.fromOffset(canvasExtent.X, canvasExtent.Y)

	-- Centre the tree in whatever surplus width there is, so the branches
	-- stay a group instead of hugging the left edge.
	local branchOffset = (canvasExtent.X - treeWidth) / 2

	-- The tree's real bounds inside the (larger) canvas, so the view can
	-- be fitted to the BRANCHES rather than to the padding around them.
	local topOfTree = canvasExtent.Y - (spineBottom + TRUNK_BASE + (longest - 1) * NODE_SPACING + NODE_SIZE / 2)
	local bottomOfTree = canvasExtent.Y - spineBottom + 40 -- plaques hang below the spine
	treeSpan = Vector2.new(spineWidthTargetFor(), bottomOfTree - topOfTree)
	treeCenter = Vector2.new(
		branchOffset + CANVAS_PAD_X + spineWidthTargetFor() / 2,
		(topOfTree + bottomOfTree) / 2
	)

	paintLattice()

	local spineWidthTarget = spineWidthTargetFor()

	-- Root spine, drawn from the middle outward so the tree assembles from
	-- its centre rather than sweeping in from one side.
	local spine = Instance.new("Frame")
	spine.AnchorPoint = Vector2.new(0.5, 1)
	spine.Position = UDim2.new(0, branchOffset + CANVAS_PAD_X + spineWidthTarget / 2, 1, -spineBottom)
	spine.Size = UDim2.new(0, 0, 0, SPINE_HEIGHT)
	spine.BackgroundColor3 = Theme.RetroColors.Bronze
	spine.BorderSizePixel = 0
	spine.ZIndex = 4
	spine.Parent = canvas
	TweenService:Create(spine, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(spineWidthTarget, SPINE_HEIGHT),
	}):Play()

	local animated: { Instance } = {}
	for i, skillId in SKILL_ORDER do
		for _, instance in buildBranch(skillId, i, spineBottom, branchOffset) do
			table.insert(animated, instance)
		end
	end

	-- Staggered draw: each connector grows, then its node pops. Watching
	-- the tree build itself is the payoff for opening the screen.
	for i, instance in animated do
		task.delay(0.25 + (i - 1) * 0.06, function()
			if buildToken ~= token or not instance.Parent then
				return
			end
			local full = instance:GetAttribute("FullHeight")
			if full ~= nil then
				if instance:GetAttribute("Lit") then
					TweenService:Create(instance, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
						Size = UDim2.new(1, 0, 0, full :: number),
					}):Play()
				end
			else
				local scale = instance:FindFirstChildOfClass("UIScale")
				if scale then
					TweenService:Create(
						scale,
						TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Scale = 1 }
					):Play()
				end
			end
		end)
	end
end

local function open()
	rebuild()

	-- Fit the WHOLE tree in view, then centre on it. Opening scrolled to
	-- the base showed two rows of nodes with the third cut off at the top
	-- edge and the right-hand branch clipped, which reads as a broken
	-- screen rather than as a space you are meant to explore. Zooming out
	-- past 1 is capped so a small tree never blows up to fill the window.
	local view = viewport.AbsoluteSize
	local fit = math.min(view.X / (treeSpan.X + NODE_SIZE * 2 + 80), view.Y / (treeSpan.Y + 80))
	zoom = math.clamp(fit, ZOOM_MIN, 1)
	canvasScale.Scale = zoom
	setCanvasPosition(view.X / 2 - treeCenter.X * zoom, view.Y / 2 - treeCenter.Y * zoom)

	backdrop.BackgroundTransparency = 1
	panelScale.Scale = 0.94
	TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(panelScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	SoundPlayer.play(SoundIds.SkillOpen)
end

function SkillTreeUI.toggle()
	ensureBuilt()
	visible = not visible
	local gui = screenGui :: ScreenGui
	if visible then
		gui.Enabled = true
		-- One frame's wait so viewport.AbsoluteSize is resolved before the
		-- canvas is sized against it. The overscan and the initial scroll
		-- position both read the viewport's real size, and on the very
		-- first open it has not been measured yet.
		task.defer(open)
	else
		gui.Enabled = false
		panVelocity = Vector2.new(0, 0)
	end
end

function SkillTreeUI.isVisible(): boolean
	return visible
end

function SkillTreeUI.refreshIfVisible()
	if visible then
		rebuild()
	end
end

return SkillTreeUI
