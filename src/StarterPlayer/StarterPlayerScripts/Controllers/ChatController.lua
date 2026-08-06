--!strict
-- Moves and reskins Roblox's built-in chat so it stops sitting on top of
-- this game's HUD.
--
-- The problem: the default chat window anchors to the TOP LEFT, which is
-- exactly where the HUD's skill chips live, and it opens over them
-- whenever anyone types. The default styling is also plain white
-- sans-serif on dark grey, which reads as "Roblox UI bolted onto the
-- game" next to the parchment-and-wood panels everything else uses.
--
-- The fix is configuration, not replacement. TextChatService exposes
-- ChatWindowConfiguration and ChatInputBarConfiguration for precisely
-- this, and driving those keeps every piece of chat behaviour Roblox
-- gives us for free — moderation, filtering, /commands, mobile input,
-- the whole lot. Building a custom chat window would mean owning all of
-- that, which is a bad trade for a cosmetic problem.
--
-- Chat moves to the BOTTOM LEFT: out of the HUD's corners, and clear of
-- the dialogue box, which is centred and capped at 760px wide.
--
-- Every property assignment is individually pcall-guarded. These
-- configuration objects have gained properties over several Roblox
-- releases, and a client on an older build would otherwise throw on the
-- first unknown property and skip every setting after it — turning a
-- cosmetic miss into "chat is unstyled AND still covering the HUD".

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Theme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local ChatController = {}

-- Sets `property` on `instance`, ignoring it if this client's Roblox
-- build doesn't have it. Returns whether it took, so callers can log.
local function trySet(instance: Instance, property: string, value: any): boolean
	local ok = pcall(function()
		(instance :: any)[property] = value
	end)
	return ok
end

function ChatController.init()
	-- LegacyChatService places have no configuration objects at all; the
	-- old chat is driven by scripts copied into the place instead. Nothing
	-- to do there, and reading the children would just yield forever.
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		warn("[ChatController] place is on LegacyChatService — leaving chat alone. Switch to TextChatService to restyle it.")
		return
	end

	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	local inputBar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")

	if window then
		-- Bottom left. The HUD owns both top corners (skill chips left,
		-- calendar/clock/purse right) and the dialogue box owns the bottom
		-- centre, so this is the one corner nothing else wants.
		trySet(window, "HorizontalAlignment", Enum.HorizontalAlignment.Left)
		trySet(window, "VerticalAlignment", Enum.VerticalAlignment.Bottom)
		-- Smaller than default in both axes: chat is ambient here, not the
		-- main event, and a shorter window means fewer lines drawn over
		-- the world.
		trySet(window, "WidthScale", 0.7)
		trySet(window, "HeightScale", 0.6)

		-- Wood panel to match everything else, but more transparent than
		-- the HUD's: chat is always on screen and always changing, so a
		-- solid panel there would be a permanent hole in the view.
		trySet(window, "BackgroundColor3", Theme.RetroColors.WoodDark)
		trySet(window, "BackgroundTransparency", 0.35)
		trySet(window, "TextColor3", Theme.RetroColors.Parchment)
		-- Chat is the one surface that deliberately does NOT use the pixel
		-- font. PressStart2P is ASCII-only, so it renders anything a
		-- player types outside that set as missing-character boxes, and
		-- it's near-illegible at the small sizes chat runs at.
		trySet(window, "FontFace", Font.fromEnum(Enum.Font.GothamMedium))
		trySet(window, "TextSize", 14)
		-- A dark outline keeps chat readable over bright grass and water,
		-- which is most of this map.
		trySet(window, "TextStrokeColor3", Color3.fromRGB(20, 12, 8))
		trySet(window, "TextStrokeTransparency", 0.4)
	else
		warn("[ChatController] no ChatWindowConfiguration found — chat keeps its default position and style.")
	end

	if inputBar then
		trySet(inputBar, "BackgroundColor3", Theme.RetroColors.WoodDark)
		trySet(inputBar, "BackgroundTransparency", 0.25)
		trySet(inputBar, "TextColor3", Theme.RetroColors.Parchment)
		trySet(inputBar, "PlaceholderColor3", Theme.RetroColors.WoodLight)
		trySet(inputBar, "FontFace", Font.fromEnum(Enum.Font.GothamMedium))
		trySet(inputBar, "TextSize", 14)
	end

	-- The player list is the other core panel that overlaps this game's
	-- HUD — it drops down the right-hand side, straight through the
	-- calendar, clock and purse. It stays enabled, since it's how you see
	-- who else is on the server; the HUD moves out of its way instead by
	-- offsetting itself below the topbar (see HudUI).
end

return ChatController
