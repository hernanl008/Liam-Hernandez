--!strict
-- Skill tree screen (GDD.md §12), built as a BRANCHING TREE rather than
-- three columns of cards.
--
-- The old version listed each perk as a card with its description and an
-- Unlock button — readable, but it showed a list, and the thing that
-- makes a skill tree feel like progression is seeing the shape of the
-- path: where you are on it, what lights up next, how far the branch
-- runs. Liam's reference (Diablo IV's tree) gets that from three things,
-- and this borrows all three in the game's own wood-and-parchment
-- palette rather than its grimdark one:
--
--   * A ROOT SPINE along the bottom joining every branch, so the trees
--     read as one system with three limbs instead of three unrelated
--     lists.
--   * TRUNKS rising from the spine with nodes threaded on them, so
--     progression is literally upward movement.
--   * CONNECTORS that are dark while locked and light up as the path is
--     taken. This is the whole trick: the lit portion of the tree is a
--     picture of your progress, readable at a glance from across the
--     room.
--
-- Descriptions moved off the nodes and into one detail plaque at the
-- bottom, which fills in on hover — same idea as the reference's
-- "SKILL ASSIGNMENT" bar. Three descriptions on screen at once is what
-- made the old layout a wall of text.
--
-- Everything animates in on open (spine draws, trunks grow, nodes pop)
-- and on unlock (the connector fills, the node flashes). All of it is
-- TweenService on Frames — no image assets, so nothing here waits on an
-- upload.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local SkillTreeConfig = require(Modules:WaitForChild("Shared"):WaitForChild("SkillTreeConfig"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local SkillTreeUI = {}

local SKILL_ORDER: { SkillTreeConfig.SkillId } = { "Farming", "Fishing", "Cooking" }

local NODE_SIZE = 64
local TRUNK_WIDTH = 7
local SPINE_HEIGHT = 7
-- Horizontal distance between trunks on the canvas.
local BRANCH_SPACING = 340
-- Breathing room around the tree's extent, so a branch never sits flush
-- against the edge you can drag it to.
local CANVAS_PAD_X = 220
local CANVAS_PAD_TOP = 150
local CANVAS_PAD_BOTTOM = 96
-- How much bigger than the viewport the canvas is made, so there is
-- always somewhere to drag to.
local OVERSCAN = 1.35
-- Vertical gap between node centres on a trunk. Not a constant: it is
-- solved from the measured canvas height in rebuild() so a branch always
-- fits, whatever the window size. Hard-coding it meant the top node ran
-- off the canvas on a short window -- three nodes at a fixed 96px need
-- 323px of height, and a small window leaves under 300.
-- Fixed now, not solved from the viewport: the tree lives on its own
-- canvas that the player drags around, so it no longer has to shrink to
-- fit whatever window it opened in. That was the right answer while the
-- tree was locked inside a small panel and the wrong one for a space you
-- can move through.
local NODE_SPACING = 150
-- Distance from the spine up to the first node's centre.
local TRUNK_BASE = 110

local COLOR_LOCKED = Color3.fromRGB(96, 74, 56)
local COLOR_TRACK = Color3.fromRGB(112, 88, 62)

local screenGui: ScreenGui? = nil
local backdrop: Frame
local panel: Frame
local panelScale: UIScale
local viewport: Frame
local canvas: Frame
local canvasExtent = Vector2.new(0, 0)
local pointsLabel: TextLabel
local detailName: TextLabel
local detailBody: TextLabel
local detailMeta: TextLabel
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

-- Drag-to-pan. Clamped so the canvas can never be pulled away from the
-- viewport entirely, and centred on whichever axis the tree is smaller
-- than the window -- panning into empty parchment is worse than not
-- panning, so the space only moves where there is actually more tree.
local dragging = false
local dragOrigin = Vector2.new(0, 0)
local canvasOrigin = Vector2.new(0, 0)

local function clampCanvas(x: number, y: number): (number, number)
	local view = viewport.AbsoluteSize
	local slackX = canvasExtent.X - view.X
	local slackY = canvasExtent.Y - view.Y
	if slackX <= 0 then
		x = (view.X - canvasExtent.X) / 2
	else
		x = math.clamp(x, -slackX, 0)
	end
	if slackY <= 0 then
		y = (view.Y - canvasExtent.Y) / 2
	else
		y = math.clamp(y, -slackY, 0)
	end
	return x, y
end

local function setCanvasPosition(x: number, y: number)
	local cx, cy = clampCanvas(x, y)
	canvas.Position = UDim2.fromOffset(cx, cy)
end

local function setupPanning()
	viewport.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragOrigin = Vector2.new(input.Position.X, input.Position.Y)
			canvasOrigin = Vector2.new(canvas.Position.X.Offset, canvas.Position.Y.Offset)
		end
	end)

	-- Ended is watched on UserInputService rather than the viewport: a
	-- drag that finishes with the cursor outside the panel would otherwise
	-- never release, and the canvas would keep following the mouse.
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - dragOrigin
		setCanvasPosition(canvasOrigin.X + delta.X, canvasOrigin.Y + delta.Y)
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

	-- Full screen. A skill tree is somewhere you go, not a dialog that
	-- floats over the game, and the tree needs the whole viewport now that
	-- it lives on a canvas you drag around.
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -24, 1, -24)
	panel.ZIndex = 3
	panel.Parent = gui

	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local face = Theme.framedPanel(panel, 10)

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
	pointsLabel.Size = UDim2.new(1, 0, 0, 20)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Right
	pointsLabel.FontFace = Theme.RetroFontFace
	pointsLabel.TextSize = 11
	pointsLabel.TextColor3 = Theme.RetroColors.InkMuted
	pointsLabel.Text = "P TO CLOSE"
	pointsLabel.ZIndex = 4
	pointsLabel.Parent = face

	-- Viewport clips; canvas is the world inside it. The tree is laid out
	-- on the canvas at a fixed scale and the canvas is dragged around
	-- beneath the viewport, which is why nothing here shrinks to fit the
	-- window any more.
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

	setupPanning()

	-- Detail plaque, pinned to the bottom. One description at a time,
	-- filled in on hover.
	local detail = Instance.new("Frame")
	detail.AnchorPoint = Vector2.new(0, 1)
	detail.Position = UDim2.fromScale(0, 1)
	detail.Size = UDim2.new(1, 0, 0, 76)
	detail.ZIndex = 5
	detail.Parent = face
	local detailFace = Theme.framedPanel(detail, 6)

	local detailPad = Instance.new("UIPadding")
	detailPad.PaddingLeft = UDim.new(0, 12)
	detailPad.PaddingRight = UDim.new(0, 12)
	detailPad.PaddingTop = UDim.new(0, 8)
	detailPad.Parent = detailFace

	detailName = Instance.new("TextLabel")
	detailName.Size = UDim2.new(1, 0, 0, 14)
	detailName.BackgroundTransparency = 1
	detailName.TextXAlignment = Enum.TextXAlignment.Left
	detailName.FontFace = Theme.RetroFontFace
	detailName.TextSize = 12
	detailName.TextColor3 = Theme.RetroColors.Rust
	detailName.Text = ""
	detailName.ZIndex = 6
	detailName.Parent = detailFace

	detailBody = Instance.new("TextLabel")
	detailBody.Position = UDim2.fromOffset(0, 22)
	detailBody.Size = UDim2.new(1, 0, 0, 28)
	detailBody.BackgroundTransparency = 1
	detailBody.TextXAlignment = Enum.TextXAlignment.Left
	detailBody.TextYAlignment = Enum.TextYAlignment.Top
	detailBody.TextWrapped = true
	detailBody.FontFace = Theme.RetroFontFace
	detailBody.TextSize = 10
	detailBody.LineHeight = 1.3
	detailBody.TextColor3 = Theme.RetroColors.Ink
	detailBody.Text = "HOVER A NODE TO INSPECT IT."
	detailBody.ZIndex = 6
	detailBody.Parent = detailFace

	detailMeta = Instance.new("TextLabel")
	detailMeta.AnchorPoint = Vector2.new(0, 1)
	detailMeta.Position = UDim2.new(0, 0, 1, -8)
	detailMeta.Size = UDim2.new(1, 0, 0, 12)
	detailMeta.BackgroundTransparency = 1
	detailMeta.TextXAlignment = Enum.TextXAlignment.Left
	detailMeta.FontFace = Theme.RetroFontFace
	detailMeta.TextSize = 9
	detailMeta.TextColor3 = Theme.RetroColors.InkMuted
	detailMeta.Text = ""
	detailMeta.ZIndex = 6
	detailMeta.Parent = detailFace
end

local function setDetail(name: string, body: string, meta: string, tone: Color3)
	detailName.Text = string.upper(name)
	detailName.TextColor3 = tone
	detailBody.Text = string.upper(body)
	detailMeta.Text = string.upper(meta)
end

-- One connector segment. Returns its FILL, so unlocking can tween the
-- lit portion upward rather than snapping it on.
local function makeConnector(parent: Frame, x: number, bottom: number, height: number, lit: boolean): Frame
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0, x, 1, -bottom)
	track.Size = UDim2.fromOffset(TRUNK_WIDTH, height)
	track.BackgroundColor3 = COLOR_TRACK
	track.BorderSizePixel = 0
	track.ZIndex = 4
	track.Parent = parent

	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0.5, 1)
	fill.Position = UDim2.fromScale(0.5, 1)
	-- Height starts at zero and is tweened up by the open sequence, which
	-- is what makes the tree draw itself rather than appear.
	fill.Size = UDim2.new(1, 0, 0, 0)
	fill.BackgroundColor3 = Theme.RetroColors.Bronze
	fill.BorderSizePixel = 0
	fill.ZIndex = 5
	fill.Parent = track
	fill:SetAttribute("Lit", lit)

	return fill
end

local function makeNode(
	parent: Frame,
	x: number,
	bottom: number,
	status: PerkStatus,
	perk: SkillTreeConfig.PerkDef,
	skillId: SkillTreeConfig.SkillId,
	level: number
): Frame
	-- Holder is un-rotated so the pop animation and hover scaling act on
	-- an upright box; only the diamond inside is rotated.
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0, x, 1, -bottom)
	holder.Size = UDim2.fromOffset(NODE_SIZE, NODE_SIZE)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 6
	holder.Parent = parent

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder

	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromScale(0.78, 0.78)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Theme.RetroColors.WoodDark
	diamond.BorderSizePixel = 0
	diamond.ZIndex = 6
	diamond.Parent = holder

	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -6, 1, -6)
	inner.BorderSizePixel = 0
	inner.ZIndex = 7
	inner.Parent = diamond

	local glow = Instance.new("UIStroke")
	glow.Thickness = 2
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glow.Parent = inner

	if status == "unlocked" then
		inner.BackgroundColor3 = Theme.RetroColors.Bronze
		glow.Color = Theme.RetroColors.Parchment
		glow.Transparency = 0.3
	elseif status == "available" then
		inner.BackgroundColor3 = Theme.RetroColors.Parchment
		glow.Color = Theme.RetroColors.Rust
		glow.Transparency = 0
		-- Available perks breathe. It is the only moving thing on an
		-- otherwise still tree, so the eye lands on what can be spent.
		TweenService:Create(
			glow,
			TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.65 }
		):Play()
	else
		inner.BackgroundColor3 = COLOR_LOCKED
		glow.Color = Theme.RetroColors.WoodDark
		glow.Transparency = 0.4
	end

	-- Click target and hover surface, laid over the diamond un-rotated so
	-- the cursor hit area is the upright square the player perceives.
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.AutoButtonColor = false
	button.ZIndex = 8
	button.Parent = holder

	local meta: string
	local tone = Theme.RetroColors.Ink
	if status == "unlocked" then
		meta = "UNLOCKED"
		tone = Theme.RetroColors.Bronze
	elseif status == "available" then
		meta = `CLICK TO UNLOCK - COSTS {perk.cost} POINT{perk.cost == 1 and "" or "S"}`
		tone = Theme.RetroColors.Rust
	elseif status == "prereqLocked" then
		meta = `REQUIRES THE PERK BELOW IT`
	else
		meta = `REQUIRES LEVEL {perk.requiredLevel} - YOU ARE {level}`
	end

	button.MouseEnter:Connect(function()
		setDetail(perk.displayName, perk.description, meta, tone)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.18,
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)

	if status == "available" then
		button.Activated:Connect(function()
			Remotes.get("UnlockPerk"):FireServer(skillId, perk.id)
			-- A confirming flash on click. The authoritative redraw comes
			-- from the server via SkillTreeController; this only makes the
			-- press feel answered in the meantime.
			TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1.35,
			}):Play()
		end)
	end

	holder:SetAttribute("Bottom", bottom)
	return holder
end

local function buildBranch(
	skillId: SkillTreeConfig.SkillId,
	index: number,
	spineBottom: number,
	nodeSpacing: number,
	branchOffsetX: number
): { Instance }
	local snapshot = InventoryCache.get()
	local tree = SkillTreeConfig.Trees[skillId]
	local xp = snapshot.skillXp[skillId] or 0
	local level = 1 + math.floor(xp / SkillTreeConfig.xpPerLevel)
	local unlockedPerks = snapshot.unlockedPerks[skillId] or {}

	-- Fixed spacing on the canvas, not a fraction of the window: the
	-- canvas has its own size and the viewport moves over it.
	local x = branchOffsetX + CANVAS_PAD_X + (index - 1) * BRANCH_SPACING

	local animated: { Instance } = {}

	for i, perk in tree.perks do
		local status = perkStatus(perk, level, unlockedPerks)
		local nodeBottom = spineBottom + TRUNK_BASE + (i - 1) * nodeSpacing
		local segmentBottom = if i == 1 then spineBottom else spineBottom + TRUNK_BASE + (i - 2) * nodeSpacing
		local segmentHeight = nodeBottom - segmentBottom

		-- A segment is lit when the perk above it is unlocked: the lit
		-- run up a trunk is then exactly how far the player has climbed.
		local fill = makeConnector(canvas, x, segmentBottom, segmentHeight, status == "unlocked")
		fill:SetAttribute("FullHeight", segmentHeight)
		table.insert(animated, fill)

		local node = makeNode(canvas, x, nodeBottom, status, perk, skillId, level)
		table.insert(animated, node)
	end

	-- Base plaque where the trunk meets the spine — the reference hangs an
	-- icon at each branch's root, and a named plate does the same job of
	-- anchoring the branch and saying what it is.
	local plaque = Instance.new("Frame")
	plaque.AnchorPoint = Vector2.new(0.5, 0.5)
	plaque.Position = UDim2.new(0, x, 1, -spineBottom)
	plaque.Size = UDim2.fromOffset(168, 34)
	plaque.ZIndex = 7
	plaque.Parent = canvas
	local plaqueFace = Theme.framedPanel(plaque, 6)

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -10, 1, -6)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.RetroFontFace
	label.TextSize = 11
	label.TextColor3 = Theme.RetroColors.Ink
	label.Text = `{string.upper(tree.displayName)} {level}`
	label.ZIndex = 8
	label.Parent = plaqueFace

	return animated
end

-- Faint diamond lattice across the whole canvas, drawn behind
-- everything. Its job is to make the space you drag through feel like a
-- surface rather than blank parchment, and to give the drag a visible
-- parallax reference -- without it, panning across empty background
-- looks like nothing is happening.
-- Extent the lattice was last painted for, so it is only redrawn when
-- the canvas actually changes size. rebuild() runs on every perk unlock,
-- and repainting a few hundred Frames each time to redraw a background
-- that never changes would be pure waste.
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
	local columns = math.ceil(canvasExtent.X / spacing)
	local rows = math.ceil(canvasExtent.Y / spacing)
	for column = 0, columns do
		for row = 0, rows do
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
	pointsLabel.Text = string.upper(`{totalPoints} POINT{totalPoints == 1 and "" or "S"} - P TO CLOSE`)

	-- Canvas extent, derived from the tree it has to hold. Sizing the
	-- canvas rather than fitting the tree to the window is what lets the
	-- nodes keep a comfortable size on any display: a small window shows
	-- less of the tree instead of showing all of it smaller.
	local longest = 0
	for _, skillId in SKILL_ORDER do
		longest = math.max(longest, #SkillTreeConfig.Trees[skillId].perks)
	end
	local spineBottom = CANVAS_PAD_BOTTOM
	local treeWidth = CANVAS_PAD_X * 2 + (#SKILL_ORDER - 1) * BRANCH_SPACING
	local treeHeight = spineBottom + TRUNK_BASE + (longest - 1) * NODE_SPACING + NODE_SIZE / 2 + CANVAS_PAD_TOP

	-- At least a bit larger than the window in both axes, so dragging
	-- always does something. Sized to the tree alone, three short branches
	-- fit inside a desktop viewport and the space would be a static
	-- picture — the drag would be dead on exactly the screens most people
	-- play on. The surplus is not blank: the lattice below fills it.
	local view = viewport.AbsoluteSize
	canvasExtent = Vector2.new(
		math.max(treeWidth, view.X * OVERSCAN),
		math.max(treeHeight, view.Y * OVERSCAN)
	)
	canvas.Size = UDim2.fromOffset(canvasExtent.X, canvasExtent.Y)

	-- Centre the tree horizontally within whatever surplus width there is,
	-- so the branches stay a group rather than hugging the left edge.
	local branchOffset = (canvasExtent.X - treeWidth) / 2

	paintLattice()

	local spineWidthTarget = (#SKILL_ORDER - 1) * BRANCH_SPACING

	-- Root spine. Drawn from the middle outward so the tree assembles
	-- from its centre rather than sweeping in from one side.
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
		for _, instance in buildBranch(skillId, i, spineBottom, NODE_SPACING, branchOffset) do
			table.insert(animated, instance)
		end
	end

	-- Staggered draw: each connector grows, then its node pops. Reading
	-- the tree build itself is the payoff for opening the screen.
	for i, instance in animated do
		task.delay(0.25 + (i - 1) * 0.06, function()
			if buildToken ~= token or not instance.Parent then
				return
			end
			if instance:IsA("Frame") and instance:GetAttribute("FullHeight") ~= nil then
				-- Connector: only fill the ones that are actually lit.
				if instance:GetAttribute("Lit") then
					local full = instance:GetAttribute("FullHeight") :: number
					TweenService:Create(instance, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
						Size = UDim2.new(1, 0, 0, full),
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
	-- Start centred horizontally and showing the base of the tree, which
	-- is where the player's attention belongs: the lit part nearest the
	-- root is what they just earned.
	local view = viewport.AbsoluteSize
	setCanvasPosition((view.X - canvasExtent.X) / 2, view.Y - canvasExtent.Y)
	backdrop.BackgroundTransparency = 1
	panelScale.Scale = 0.92
	TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(panelScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

function SkillTreeUI.toggle()
	ensureBuilt()
	visible = not visible
	local gui = screenGui :: ScreenGui
	if visible then
		gui.Enabled = true
		-- One frame's wait so viewport.AbsoluteSize is resolved before the
		-- canvas is sized against it. The overscan and the initial scroll
		-- position are both computed from the viewport's real size, and on
		-- the very first open it has not been measured yet.
		task.defer(open)
	else
		gui.Enabled = false
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
