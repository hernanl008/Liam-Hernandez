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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local SkillTreeConfig = require(Modules:WaitForChild("Shared"):WaitForChild("SkillTreeConfig"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local SkillTreeUI = {}

local SKILL_ORDER: { SkillTreeConfig.SkillId } = { "Farming", "Fishing", "Cooking" }

local NODE_SIZE = 54
local TRUNK_WIDTH = 6
local SPINE_HEIGHT = 6
-- Vertical gap between node centres on a trunk. Not a constant: it is
-- solved from the measured canvas height in rebuild() so a branch always
-- fits, whatever the window size. Hard-coding it meant the top node ran
-- off the canvas on a short window -- three nodes at a fixed 96px need
-- 323px of height, and a small window leaves under 300.
local NODE_SPACING_MIN = 62
local NODE_SPACING_MAX = 104
-- Distance from the spine up to the first node's centre.
local TRUNK_BASE = 66

local COLOR_LOCKED = Color3.fromRGB(96, 74, 56)
local COLOR_TRACK = Color3.fromRGB(112, 88, 62)

local screenGui: ScreenGui? = nil
local backdrop: Frame
local panel: Frame
local panelScale: UIScale
local treeArea: Frame
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

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.82, 0.78)
	panel.ZIndex = 3
	panel.Parent = gui

	local panelSize = Instance.new("UISizeConstraint")
	panelSize.MaxSize = Vector2.new(980, 620)
	panelSize.Parent = panel

	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	Theme.panelShadow(panel, 10)
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

	-- The tree canvas. Nodes are positioned into this in pixels from the
	-- bottom up, so a branch grows the way the eye expects.
	treeArea = Instance.new("Frame")
	treeArea.Position = UDim2.fromOffset(0, 30)
	treeArea.Size = UDim2.new(1, 0, 1, -114)
	treeArea.BackgroundTransparency = 1
	treeArea.ZIndex = 4
	treeArea.Parent = face

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
	nodeSpacing: number
): { Instance }
	local snapshot = InventoryCache.get()
	local tree = SkillTreeConfig.Trees[skillId]
	local xp = snapshot.skillXp[skillId] or 0
	local level = 1 + math.floor(xp / SkillTreeConfig.xpPerLevel)
	local unlockedPerks = snapshot.unlockedPerks[skillId] or {}

	-- Evenly spaced across the canvas, measured in absolute pixels at
	-- build time so connectors and nodes share one coordinate space.
	local width = treeArea.AbsoluteSize.X
	local x = width * ((index - 0.5) / #SKILL_ORDER)

	local animated: { Instance } = {}

	for i, perk in tree.perks do
		local status = perkStatus(perk, level, unlockedPerks)
		local nodeBottom = spineBottom + TRUNK_BASE + (i - 1) * nodeSpacing
		local segmentBottom = if i == 1 then spineBottom else spineBottom + TRUNK_BASE + (i - 2) * nodeSpacing
		local segmentHeight = nodeBottom - segmentBottom

		-- A segment is lit when the perk above it is unlocked: the lit
		-- run up a trunk is then exactly how far the player has climbed.
		local fill = makeConnector(treeArea, x, segmentBottom, segmentHeight, status == "unlocked")
		fill:SetAttribute("FullHeight", segmentHeight)
		table.insert(animated, fill)

		local node = makeNode(treeArea, x, nodeBottom, status, perk, skillId, level)
		table.insert(animated, node)
	end

	-- Branch label under the trunk base.
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0, x, 1, -(spineBottom - 8))
	label.Size = UDim2.fromOffset(160, 16)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.RetroFontFace
	label.TextSize = 11
	label.TextColor3 = Theme.RetroColors.Ink
	label.Text = `{string.upper(tree.displayName)}  {level}`
	label.ZIndex = 6
	label.Parent = treeArea

	return animated
end

local function rebuild()
	buildToken += 1
	local token = buildToken

	for _, child in treeArea:GetChildren() do
		child:Destroy()
	end

	local snapshot = InventoryCache.get()
	local totalPoints = 0
	for _, skillId in SKILL_ORDER do
		totalPoints += snapshot.skillPoints[skillId] or 0
	end
	pointsLabel.Text = string.upper(`{totalPoints} POINT{totalPoints == 1 and "" or "S"} - P TO CLOSE`)

	local spineBottom = 34

	-- Root spine. Drawn from the middle outward so the tree assembles
	-- from its centre rather than sweeping in from one side.
	local spine = Instance.new("Frame")
	spine.AnchorPoint = Vector2.new(0.5, 1)
	spine.Position = UDim2.new(0.5, 0, 1, -spineBottom)
	spine.Size = UDim2.new(0, 0, 0, SPINE_HEIGHT)
	spine.BackgroundColor3 = Theme.RetroColors.Bronze
	spine.BorderSizePixel = 0
	spine.ZIndex = 4
	spine.Parent = treeArea

	local width = treeArea.AbsoluteSize.X
	local spineWidth = width * ((#SKILL_ORDER - 0.5) / #SKILL_ORDER - 0.5 / #SKILL_ORDER)
	TweenService:Create(spine, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(spineWidth, SPINE_HEIGHT),
	}):Play()

	-- Solve the node spacing from the height actually available, so the
	-- tallest branch always lands inside the canvas.
	local longest = 0
	for _, skillId in SKILL_ORDER do
		longest = math.max(longest, #SkillTreeConfig.Trees[skillId].perks)
	end
	local usable = treeArea.AbsoluteSize.Y - spineBottom - TRUNK_BASE - NODE_SIZE
	local nodeSpacing = if longest > 1
		then math.clamp(usable / (longest - 1), NODE_SPACING_MIN, NODE_SPACING_MAX)
		else NODE_SPACING_MAX

	local animated: { Instance } = {}
	for i, skillId in SKILL_ORDER do
		for _, instance in buildBranch(skillId, i, spineBottom, nodeSpacing) do
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
		-- One frame's wait so treeArea.AbsoluteSize is resolved before the
		-- branches are laid out against it — everything here is positioned
		-- in pixels, and on the very first open the canvas has no measured
		-- size yet.
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
