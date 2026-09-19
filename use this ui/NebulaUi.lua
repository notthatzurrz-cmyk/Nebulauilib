--[==[

	NebulaUI v1.32.0 — a compact, panel-based UI library for Roblox (Luau)
	======================================================================

	Original implementation. No external dependencies, no image assets, no HTTP
	requests, no filesystem access and no executor-only globals. Only normal
	client UI APIs: Instance.new, TweenService, UserInputService, RunService,
	Players.LocalPlayer.PlayerGui.

	LOADING
	----------------------------------------------------------------------
	Host this file anywhere raw text is served, then:

		local library = loadstring(game:HttpGet("YOUR_RAW_LIBRARY_URL"))()
		local window = library:CreateWindow({
			Title = "Nebula",
			Subtitle = "Settings",
			Theme = "Phantom",                   -- applied on creation, see THEMES
			Accent = Color3.fromRGB(214, 214, 255), -- overrides the theme accent
			StartPosition = UDim2.fromOffset(24, 24),
			ToggleKey = Enum.KeyCode.RightShift, -- hide/show the interface
			ModuleList = true,                   -- HUD arraylist, top-right
			ModuleListBar = true,                -- thin theme-gradient separator
			ModuleListGlow = true,               -- theme-coloured text/bar bloom
			ModuleListBlur = true,               -- contained frosted fallback layer
			HudFont = "GothamMedium",            -- geometric semi-bold arraylist face
		})

	FEATURE ROWS
	----------------------------------------------------------------------
	A panel is a list of features. Left click switches a feature on — its label
	lifts grey -> white, the row takes a faint accent tint, the header counter
	goes up and it appears in the module list. The chevron, or a right click,
	opens its settings block:

		local legit = window:CreatePanel({ Title = "Legit" })
		local mlg = legit:Feature("Auto MLG", false, function(on) print(on) end)
		local settings = mlg:Submenu()
		settings:Slider("Min Fall Distance", 0, 20, 3, 1, nil, { Suffix = " blocks" })
		settings:Dropdown("Clutch Item", { "Water Bucket", "Powder Snow Bucket" }, "Water Bucket")

	EVERY ELEMENT
	----------------------------------------------------------------------
	Label(text) · Warning(text) · Divider()
	Button(text, callback) · Buttons({ { label, callback }, ... })
	Row(text, callback) · Feature(text, default, callback)
	Toggle(text, default, callback)
	Dropdown(text, options, default, callback)
	MultiDropdown(text, options, defaults, callback, { Max, Placeholder })
	Slider(text, min, max, default, step, callback, { Suffix, Decimals })
	Keybind(text, defaultKey, changedCallback, pressedCallback)
	Textbox(text, default, placeholder, callback)
	Color(text, defaultColor, defaultAlpha, callback, { FollowAccent = true })

	Every element supports:
		Get() · Set(value, silent) · SetVisible(bool) · IsVisible()
		Tooltip("description") · Tooltip(title, description, hint) · Destroy()
	Extras:
		Color:    GetAlpha() · GetHex()
		Dropdown: SetOptions(options, keepCurrentValue) · Open() · Close() · IsOpen()
		MultiDropdown: Get()/Set({ values }) · Select(value) · Deselect(value)
		               Toggle(value) · Clear() · SetOptions(options, keepSelections)
		Slider:   SetRange(min, max)
		Keybind:  IsListening() · StartListening() · (Escape clears the bind)
		Feature:  SetText(text) · SetBadge("100 ms") · BindBadge(slider, "%s ms")
		Rows with Submenu(): SetSubmenuOpen(bool) · ToggleSubmenu() · HasSubmenu()

	WINDOW
	----------------------------------------------------------------------
	SetAccent(color) / GetAccent()
	SetTheme(name) / GetTheme()              -- repaints the whole UI live
	Notify({ Title, Content, Duration })     -- themed card, bottom-right, expire bar
	SetModuleListVisible(bool) / IsModuleListVisible()
	SetModuleListBarVisible(bool) / IsModuleListBarVisible()
	SetModuleListGlowEnabled(bool) / IsModuleListGlowEnabled()
	SetModuleListBlurEnabled(bool) / IsModuleListBlurEnabled()
	-- The HUD arraylist and the notifications live in their own ScreenGui: they
	-- ignore the topbar inset, so they sit at the true screen edge, and they
	-- stay on screen while the menu itself is hidden.
	SetVisible(bool) / ToggleVisible() / IsVisible()
	SetToggleKey(Enum.KeyCode or nil)        -- rebindable with a Keybind element too
	ClosePopups() · Destroy()                -- Destroy removes every connection

	THEMES
	----------------------------------------------------------------------
    Phantom · Casual · Midnight · Crimson · Kyoto · Emerald · Violet · Ocean
    Amber · Mono
    Every theme drives the HUD arraylist spectrum from its own Accent. Mono is
    the only theme with a deliberate black/white arraylist.
		window:SetTheme("Crimson")
	Register your own before use:
		library.Themes.Sakura = {
			Accent = Color3.fromRGB(255, 170, 200),
			Panel  = Color3.fromRGB(15, 11, 13),
			Header = Color3.fromRGB(20, 14, 17),
			Layers = { Color3.fromRGB(20, 14, 17), Color3.fromRGB(25, 18, 22) },
			Popup  = Color3.fromRGB(29, 21, 26),
		}

	CLEANUP & ENVIRONMENT
	----------------------------------------------------------------------
	window:Destroy() removes the ScreenGui and disconnects every listener,
	follow loop and timer — nothing global is left behind. Client only:
	LocalScript, ModuleScript required from one, or an executor with
	loadstring + game:HttpGet. ResetOnSpawn = false keeps the UI alive
	through respawns. This file contains no loadstring, HttpGet, writefile
	or asset ids of its own.

]==]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local NebulaUI = {}
NebulaUI.Version = "1.32.0"
NebulaUI.GuiName = "NebulaUI"

-- =====================================================================
-- palette / metrics
-- =====================================================================

local PALETTE = {
	Panel = Color3.fromRGB(11, 11, 14),
	Header = Color3.fromRGB(15, 15, 19),
	Row = Color3.fromRGB(15, 15, 19),
	RowHover = Color3.fromRGB(24, 24, 30),
	RowActive = Color3.fromRGB(30, 30, 37),
	Border = Color3.fromRGB(38, 38, 46),
	BorderSoft = Color3.fromRGB(28, 28, 34),
	Track = Color3.fromRGB(34, 34, 41),
	Knob = Color3.fromRGB(150, 150, 164),
	Text = Color3.fromRGB(238, 238, 244),
	SubText = Color3.fromRGB(150, 150, 162),
	Muted = Color3.fromRGB(112, 112, 126),
	Warning = Color3.fromRGB(224, 96, 96),
	Popup = Color3.fromRGB(22, 22, 27),
	Tooltip = Color3.fromRGB(9, 9, 12),
}

-- Roblox added the fuller, rounder Builder Sans family well after Gotham, so
-- resolve it by name and fall back cleanly on older clients rather than
-- indexing an enum item that may not exist.
local function pickFont(...)
	for _, name in ipairs({ ... }) do
		local ok, font = pcall(function()
			return Enum.Font[name]
		end)
		if ok and font then
			return font
		end
	end
	return Enum.Font.Gotham
end

-- Accepts an Enum.Font, a font name, or nil to keep the supplied default.
-- The HUD prefers Montserrat when available, then Gotham Medium: both are
-- compact geometric semi-bold faces that remain smooth at small UI sizes.
local function resolveFontOption(value, default)
	if typeof(value) == "EnumItem" then
		return value
	end
	if type(value) == "string" then
		local ok, font = pcall(function()
			return Enum.Font[value]
		end)
		if ok and font then
			return font
		end
	end
	return default
end

local METRICS = {
	PanelWidth = 296,
	MinPanelWidth = 220,
	HeaderHeight = 42,
	RowHeight = 40,
	FieldHeight = 38,
	ButtonHeight = 38,
	Corner = 4,
	SmallCorner = 5,
	Gap = 10,
	Margin = 16,
	-- rows run edge to edge like the reference list: no panel inset, no gap
	PanelPad = 0,
	RowGap = 0,
	-- anything that is not a plain row keeps a small side inset
	InsetPad = 12,
	LabelHeight = 24,
	-- Builder Sans has fuller, rounder strokes than Gotham, which reads much
	-- cleaner than thin hairlines at UI sizes
	Font = pickFont("BuilderSansMedium", "GothamMedium", "Gotham"),
	FontMedium = pickFont("BuilderSansBold", "GothamBold", "Gotham"),
	-- Montserrat/Poppins-style geometric medium face for the PvP HUD.
	FontHud = pickFont("Montserrat", "GothamMedium", "BuilderSansMedium", "Gotham"),
	TextSize = 17,
	SmallTextSize = 15,
}

-- Compact Minecraft PvP arraylist. The theme's existing Accent is the single
-- colour source for the UI, text field, glow, separator and frosted tint.
local HUD = {
	TopMargin = 7,
	RightMargin = 7,
	PadX = 6,
	PadY = 4,
	SegmentCorner = 5,
	FrostBleed = 1,
	LineHeight = 22,
	LineGap = 0,
	BadgeGap = 4,
	TextSize = 17,
	BadgeSize = 17,
	BadgeColor = Color3.fromRGB(168, 168, 178),
	BadgeTransparency = 0.04,
	BackgroundTransparency = 0.38,
	FrostTransparency = 0.82,
	GlowTransparency = 0.82,
	TextShadowNear = 0.34,
	TextShadowFar = 0.76,
	BarWidth = 5,
	BarGap = 0,
	ChromaStops = 9,
	ChromaSpeed = 0.68,
	ChromaAmplitude = 54,
	ChromaXFrequency = 0.0028,
	ChromaYFrequency = 0.0062,
	WaveFrequency = 0.038,
	WaveDistortion = 0.068,
	UpdateRate = 1 / 60,
	EnterSlide = 20,
	ExitSlide = 30,
}

local HUD_GLOW_OFFSETS = {
	Vector2.new(1, 0), Vector2.new(-1, 0),
	Vector2.new(0, 1), Vector2.new(0, -1),
	Vector2.new(1, 1), Vector2.new(-1, 1),
	Vector2.new(1, -1), Vector2.new(-1, -1),
}

-- No second theme table: every theme derives its arraylist spectrum from the
-- shared Accent. Mono is the only theme that deliberately animates a
-- black/white spectrum, because its accent is literally colourless.
local function buildHudPalette(accent, themeName)
	local key = string.lower(tostring(themeName or ""))
	if key == "mono" then
		return {
			Color3.fromRGB(8, 8, 10),
			Color3.fromRGB(62, 62, 68),
			Color3.fromRGB(178, 178, 188),
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(132, 132, 142),
			Color3.fromRGB(38, 38, 44),
			Color3.fromRGB(5, 5, 7),
		}
	end

	local hue, saturation, value = accent:ToHSV()

	-- A genuinely colourless accent has no hue to rotate or deepen, so keep the
	-- neutral ramp for it rather than inventing a red from hue 0.
	if saturation < 0.02 then
		return {
			accent:Lerp(Color3.new(0, 0, 0), 0.62),
			accent:Lerp(Color3.new(0, 0, 0), 0.28),
			accent,
			Color3.new(1, 1, 1),
			accent,
			accent:Lerp(Color3.new(0, 0, 0), 0.28),
			accent:Lerp(Color3.new(0, 0, 0), 0.62),
		}
	end

	-- Pale accents (Phantom's lavender, Casual's soft slate) carry too little
	-- saturation for hue shifting to read as colour at all — rotating a 0.16
	-- saturation hue just produces more grey, which is why the HUD used to look
	-- black/white while the menu looked purple. Animate accent -> white with a
	-- deepened, saturation-boosted low end instead, so the arraylist keeps the
	-- menu's tint.
	if saturation < 0.34 then
		local deep = Color3.fromHSV(
			hue,
			math.clamp(saturation * 2.8, 0, 1),
			math.clamp(value * 0.70, 0, 1)
		)
		local mid = Color3.fromHSV(
			hue,
			math.clamp(saturation * 1.7, 0, 1),
			math.clamp(value * 0.94, 0, 1)
		)
		return {
			deep,
			mid,
			accent,
			accent:Lerp(Color3.new(1, 1, 1), 0.55),
			Color3.new(1, 1, 1),
			accent,
			mid,
			deep,
		}
	end

	local palette = {}
	local definitions = {
		{ Shift = 0, Saturation = 1.00, Value = 0.88 },
		{ Shift = -0.015, Saturation = 0.98, Value = 1.00 },
		{ Shift = -0.035, Saturation = 0.88, Value = 1.00 },
		{ Shift = -0.060, Saturation = 0.78, Value = 1.00 },
		{ Shift = -0.038, Saturation = 0.92, Value = 0.96 },
		{ Shift = -0.014, Saturation = 0.86, Value = 1.00 },
		{ Shift = 0, Saturation = 1.00, Value = 0.92 },
	}
	for _, definition in ipairs(definitions) do
		table.insert(palette, Color3.fromHSV(
			(hue + definition.Shift) % 1,
			math.clamp(saturation * definition.Saturation, 0, 1),
			math.clamp(value * definition.Value, 0, 1)
		))
	end
	return palette
end

local function sampleHudChroma(position, palette)
	local count = #palette
	local wrapped = position % 1
	local scaled = wrapped * count
	local base = math.floor(scaled)
	local index = base % count + 1
	local nextIndex = index % count + 1
	local alpha = scaled - base
	alpha = alpha * alpha * (3 - 2 * alpha)
	return palette[index]:Lerp(palette[nextIndex], alpha)
end

local function hudChromaAt(screenX, screenY, now, palette)
	local verticalShift = math.sin(now * HUD.ChromaSpeed) * HUD.ChromaAmplitude
	local shiftedY = screenY + verticalShift
	local phase = screenX * HUD.ChromaXFrequency
		+ shiftedY * HUD.ChromaYFrequency
	local distortion = math.sin(
		shiftedY * HUD.WaveFrequency + screenX * 0.011
	) * HUD.WaveDistortion
	distortion += math.sin(
		screenX * 0.004 - shiftedY * 0.019
	) * HUD.WaveDistortion * 0.45
	return sampleHudChroma(phase + distortion, palette)
end

local function buildHudChromaSequence(guiObject, now, palette, vertical)
	local position = guiObject and guiObject.AbsolutePosition or Vector2.zero
	local size = guiObject and guiObject.AbsoluteSize or Vector2.new(1, HUD.LineHeight)
	local width = math.max(size.X, 1)
	local height = math.max(size.Y, 1)
	local points = {}
	for stop = 0, HUD.ChromaStops - 1 do
		local ratio = stop / (HUD.ChromaStops - 1)
		local screenX = vertical and (position.X + width * 0.5)
			or (position.X + width * ratio)
		local screenY = vertical and (position.Y + height * ratio)
			or (position.Y + height * 0.5)
		table.insert(points, ColorSequenceKeypoint.new(
			ratio,
			hudChromaAt(screenX, screenY, now, palette)
		))
	end
	return ColorSequence.new(points)
end

local ANIM = {
	Fast = 0.14,
	-- short enough that a dragged knob stays under the pointer, long enough
	-- that it glides instead of stepping
	Drag = 0.08,
	Normal = 0.2,
	Submenu = 0.22,
	Toggle = 0.18,
	-- quart out carries the soft, weighted glide the reference menu has
	Style = Enum.EasingStyle.Quart,
	Direction = Enum.EasingDirection.Out,
}

-- Nesting shades. Rows on one layer are near-black, the block that opens out of
-- them is a step lighter, the block inside that one flips back to near-black,
-- and so on, so "a menu inside a menu" always separates from its parent.
local LAYERS = {
	Color3.fromRGB(15, 15, 19),
	Color3.fromRGB(19, 19, 24),
}

-- The opened config box: how far it sits in from the panel edge, the gap above
-- and below it, and its inner padding.
local SUBMENU_INSET = 7
local SUBMENU_MARGIN = 4
local SUBMENU_PAD = 5

local function shade(color, amount)
	if amount >= 0 then
		return color:Lerp(Color3.fromRGB(255, 255, 255), amount)
	end
	return color:Lerp(Color3.fromRGB(0, 0, 0), -amount)
end

local function layerColor(depth)
	return LAYERS[(depth % #LAYERS) + 1]
end

-- =====================================================================
-- themes (accent + surface tints; applied live by Window:SetTheme)
-- =====================================================================

local THEMES = {
	Phantom = {
		Accent = Color3.fromRGB(214, 214, 255),
		Panel = Color3.fromRGB(11, 11, 14),
		Header = Color3.fromRGB(15, 15, 19),
		Layers = { Color3.fromRGB(15, 15, 19), Color3.fromRGB(19, 19, 24) },
		Popup = Color3.fromRGB(22, 22, 27),
	},
	-- Casual: the relaxed, low-contrast counterpart to Phantom. Slightly lifted
	-- surfaces and a soft periwinkle-slate accent, so nothing shouts. Its low
	-- saturation routes the arraylist through the accent -> white ramp.
	Casual = {
		Accent = Color3.fromRGB(188, 204, 230),
		Panel = Color3.fromRGB(17, 18, 22),
		Header = Color3.fromRGB(22, 24, 29),
		Layers = { Color3.fromRGB(22, 24, 29), Color3.fromRGB(27, 29, 35) },
		Popup = Color3.fromRGB(31, 33, 40),
	},
	Midnight = {
		Accent = Color3.fromRGB(124, 160, 255),
		Panel = Color3.fromRGB(10, 12, 20),
		Header = Color3.fromRGB(14, 17, 27),
		Layers = { Color3.fromRGB(14, 17, 27), Color3.fromRGB(18, 22, 34) },
		Popup = Color3.fromRGB(20, 24, 38),
	},
	Crimson = {
		Accent = Color3.fromRGB(237, 66, 96),
		Panel = Color3.fromRGB(18, 10, 12),
		Header = Color3.fromRGB(24, 13, 16),
		Layers = { Color3.fromRGB(24, 13, 16), Color3.fromRGB(30, 16, 20) },
		Popup = Color3.fromRGB(33, 18, 23),
	},
	Kyoto = {
		Accent = Color3.fromRGB(255, 158, 205),
		Panel = Color3.fromRGB(16, 11, 16),
		Header = Color3.fromRGB(22, 14, 21),
		Layers = { Color3.fromRGB(22, 14, 21), Color3.fromRGB(27, 17, 26) },
		Popup = Color3.fromRGB(31, 19, 30),
	},
	Emerald = {
		Accent = Color3.fromRGB(72, 209, 157),
		Panel = Color3.fromRGB(9, 15, 13),
		Header = Color3.fromRGB(12, 20, 17),
		Layers = { Color3.fromRGB(12, 20, 17), Color3.fromRGB(15, 25, 21) },
		Popup = Color3.fromRGB(17, 28, 24),
	},
	Violet = {
		Accent = Color3.fromRGB(178, 132, 255),
		Panel = Color3.fromRGB(13, 11, 18),
		Header = Color3.fromRGB(17, 14, 24),
		Layers = { Color3.fromRGB(17, 14, 24), Color3.fromRGB(21, 17, 29) },
		Popup = Color3.fromRGB(25, 20, 33),
	},
	Ocean = {
		Accent = Color3.fromRGB(84, 190, 235),
		Panel = Color3.fromRGB(9, 13, 17),
		Header = Color3.fromRGB(12, 17, 22),
		Layers = { Color3.fromRGB(12, 17, 22), Color3.fromRGB(15, 21, 27) },
		Popup = Color3.fromRGB(18, 25, 32),
	},
	Amber = {
		Accent = Color3.fromRGB(235, 178, 84),
		Panel = Color3.fromRGB(16, 12, 9),
		Header = Color3.fromRGB(21, 16, 12),
		Layers = { Color3.fromRGB(21, 16, 12), Color3.fromRGB(26, 20, 15) },
		Popup = Color3.fromRGB(30, 23, 18),
	},
	Mono = {
		Accent = Color3.fromRGB(228, 228, 232),
		Panel = Color3.fromRGB(12, 12, 13),
		Header = Color3.fromRGB(16, 16, 17),
		Layers = { Color3.fromRGB(16, 16, 17), Color3.fromRGB(20, 20, 21) },
		Popup = Color3.fromRGB(23, 23, 24),
	},
}

-- =====================================================================
-- instance helpers
-- =====================================================================

local function new(className, props, children)
	local instance = Instance.new(className)
	local parent = nil

	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end

	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end

	instance.Parent = parent
	return instance
end

local function corner(parent, radius)
	return new("UICorner", {
		CornerRadius = UDim.new(0, radius or METRICS.Corner),
		Parent = parent,
	})
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or PALETTE.Border,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		Parent = parent,
	})
end

-- Soft drop shadow. Roblox has no blur and this library ships no image assets,
-- so the falloff is built from progressively larger, fainter, more rounded
-- plates stacked behind the target. The shadow is a sibling rather than a child
-- because panels clip their own contents.
local function attachShadow(target, registry, options)
	options = options or {}
	local plates = options.Layers or 4
	local step = options.Step or 2
	local strength = options.Strength or 0.9
	local radius = options.Corner or METRICS.Corner

	local shadow = new("Frame", {
		Name = target.Name .. "Shadow",
		BackgroundTransparency = 1,
		Position = target.Position,
		Size = target.Size,
		Visible = target.Visible,
		ZIndex = math.max(0, (target.ZIndex or 1) - 1),
		Parent = target.Parent,
	})

	for index = 1, plates do
		local spread = index * step
		local plate = new("Frame", {
			Name = "Plate" .. index,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = math.clamp(strength + (index - 1) * 0.022, 0, 1),
			BorderSizePixel = 0,
			-- nudged down so the light reads as coming from above
			Position = UDim2.fromOffset(-spread, -spread + 1),
			Size = UDim2.new(1, spread * 2, 1, spread * 2),
			ZIndex = plates - index + 1,
			Parent = shadow,
		})
		corner(plate, radius + spread)
	end

	local function sync()
		shadow.Position = target.Position
		-- AbsoluteSize always reflects the rendered size, including the growth
		-- AutomaticSize applies after the Size property was first read
		local pixels = target.AbsoluteSize
		shadow.Size = UDim2.fromOffset(pixels.X, pixels.Y)
		shadow.Visible = target.Visible
	end

	registry:Add(shadow)
	registry:Add(target:GetPropertyChangedSignal("Position"):Connect(sync))
	registry:Add(target:GetPropertyChangedSignal("Size"):Connect(sync))
	registry:Add(target:GetPropertyChangedSignal("Visible"):Connect(sync))
	-- AutomaticSize targets grow after creation; AbsoluteSize catches that
	registry:Add(target:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync))
	sync()

	return shadow
end

local function pad(parent, top, right, bottom, left)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		PaddingLeft = UDim.new(0, left or 0),
		Parent = parent,
	})
end

local function vlist(parent, gap)
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap or 0),
		Parent = parent,
	})
end

local function hlist(parent, gap)
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap or 0),
		Parent = parent,
	})
end

local TEXT_DEFAULTS = {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Font = METRICS.Font,
	TextSize = METRICS.TextSize,
	TextColor3 = PALETTE.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextTruncate = Enum.TextTruncate.AtEnd,
}

local BUTTON_DEFAULTS = {
	AutoButtonColor = false,
	BackgroundColor3 = PALETTE.Row,
	BorderSizePixel = 0,
	Font = METRICS.Font,
	Text = "",
	TextColor3 = PALETTE.Text,
	TextSize = METRICS.TextSize,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}

local BOX_DEFAULTS = {
	BackgroundColor3 = PALETTE.Row,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = METRICS.Font,
	PlaceholderColor3 = PALETTE.Muted,
	Text = "",
	TextColor3 = PALETTE.Text,
	TextSize = METRICS.TextSize,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}

local function merged(defaults, props)
	local result = {}
	for key, value in pairs(defaults) do
		result[key] = value
	end
	if props then
		for key, value in pairs(props) do
			result[key] = value
		end
	end
	return result
end

local function makeText(props)
	return new("TextLabel", merged(TEXT_DEFAULTS, props))
end

local function makeButton(props)
	return new("TextButton", merged(BUTTON_DEFAULTS, props))
end

local function makeBox(props)
	return new("TextBox", merged(BOX_DEFAULTS, props))
end

local function tween(instance, duration, goal, style, direction)
	local info = TweenInfo.new(
		duration,
		style or ANIM.Style,
		direction or ANIM.Direction
	)
	local animation = TweenService:Create(instance, info, goal)
	animation:Play()
	return animation
end

-- =====================================================================
-- connection / cleanup registry
-- =====================================================================

local Registry = {}
Registry.__index = Registry

function Registry.new()
	return setmetatable({ _items = {}, _closed = false }, Registry)
end

local function disposeItem(item)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		if item.Connected then
			item:Disconnect()
		end
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		local ok, err = pcall(item)
		if not ok then
			warn("[NebulaUI] cleanup error: " .. tostring(err))
		end
	end
end

-- Accepts connections, instances and teardown functions.
function Registry:Add(item)
	if item == nil then
		return nil
	end
	if self._closed then
		disposeItem(item)
		return item
	end
	table.insert(self._items, item)
	return item
end

function Registry:Remove(item)
	local index = table.find(self._items, item)
	if index then
		table.remove(self._items, index)
	end
end

function Registry:Clean()
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		disposeItem(items[index])
	end
end

function Registry:Destroy()
	self:Clean()
	self._closed = true
end

-- =====================================================================
-- listener lists (one UserInputService connection per window)
-- =====================================================================

local function listen(list, handler)
	table.insert(list, handler)
	return function()
		local index = table.find(list, handler)
		if index then
			table.remove(list, index)
		end
	end
end

local function fire(list, ...)
	for _, handler in ipairs(table.clone(list)) do
		local ok, err = pcall(handler, ...)
		if not ok then
			warn("[NebulaUI] listener error: " .. tostring(err))
		end
	end
end

-- Callbacks are always optional and never block the input thread.
local function invoke(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(callback, table.unpack(args, 1, args.n))
		if not ok then
			warn("[NebulaUI] callback error: " .. tostring(err))
		end
	end)
end

-- =====================================================================
-- number / colour utilities
-- =====================================================================

local function snap(value, step)
	if not step or step <= 0 then
		return value
	end
	return math.floor(value / step + 0.5) * step
end

local function decimalsOf(step)
	if not step or step <= 0 then
		return 2
	end
	if step % 1 == 0 then
		return 0
	end
	local text = string.format("%.6f", step)
	text = string.gsub(text, "0+$", "")
	local dot = string.find(text, "%.")
	if not dot then
		return 0
	end
	return math.min(#text - dot, 4)
end

local function formatNumber(value, decimals)
	if decimals <= 0 then
		local rounded = value >= 0 and math.floor(value + 0.5) or -math.floor(-value + 0.5)
		return string.format("%d", rounded)
	end
	return string.format("%." .. decimals .. "f", value)
end

local function byteToHex(value)
	return string.format("%02X", math.clamp(math.floor(value * 255 + 0.5), 0, 255))
end

local function colorToHex(color, alpha)
	local hex = "#" .. byteToHex(color.R) .. byteToHex(color.G) .. byteToHex(color.B)
	if alpha ~= nil then
		hex = hex .. byteToHex(alpha)
	end
	return hex
end

-- Accepts #RGB, #RRGGBB and #RRGGBBAA (with or without the leading hash).
local function parseHex(text)
	if type(text) ~= "string" then
		return nil
	end
	local body = string.gsub(text, "%s", "")
	body = string.gsub(body, "^#", "")
	body = string.upper(body)
	if not string.match(body, "^%x+$") then
		return nil
	end

	local red, green, blue, alpha
	if #body == 3 then
		red = tonumber(string.rep(string.sub(body, 1, 1), 2), 16)
		green = tonumber(string.rep(string.sub(body, 2, 2), 2), 16)
		blue = tonumber(string.rep(string.sub(body, 3, 3), 2), 16)
	elseif #body == 6 or #body == 8 then
		red = tonumber(string.sub(body, 1, 2), 16)
		green = tonumber(string.sub(body, 3, 4), 16)
		blue = tonumber(string.sub(body, 5, 6), 16)
		if #body == 8 then
			alpha = tonumber(string.sub(body, 7, 8), 16) / 255
		end
	else
		return nil
	end

	if not (red and green and blue) then
		return nil
	end
	return Color3.fromRGB(red, green, blue), alpha
end

-- Keeps swatch text legible on bright colours.
local function readableOn(color)
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	if luminance > 0.62 then
		return Color3.fromRGB(16, 16, 20)
	end
	return Color3.fromRGB(244, 244, 250)
end

local function isInside(guiObject, position)
	if not guiObject or not guiObject.Visible then
		return false
	end
	local origin = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return position.X >= origin.X
		and position.X <= origin.X + size.X
		and position.Y >= origin.Y
		and position.Y <= origin.Y + size.Y
end

-- =====================================================================
-- key labels
-- =====================================================================

local MOUSE_LABELS = {
	[Enum.UserInputType.MouseButton1] = "MB1",
	[Enum.UserInputType.MouseButton2] = "MB2",
	[Enum.UserInputType.MouseButton3] = "MB3",
}

local KEY_LABELS = {
	[Enum.KeyCode.LeftShift] = "Shift",
	[Enum.KeyCode.RightShift] = "RShift",
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.RightControl] = "RCtrl",
	[Enum.KeyCode.LeftAlt] = "Alt",
	[Enum.KeyCode.RightAlt] = "RAlt",
	[Enum.KeyCode.LeftSuper] = "Super",
	[Enum.KeyCode.RightSuper] = "RSuper",
	[Enum.KeyCode.Escape] = "Esc",
	[Enum.KeyCode.Return] = "Enter",
	[Enum.KeyCode.KeypadEnter] = "NumEnter",
	[Enum.KeyCode.Backspace] = "Bksp",
	[Enum.KeyCode.Space] = "Space",
	[Enum.KeyCode.Tab] = "Tab",
	[Enum.KeyCode.CapsLock] = "Caps",
	[Enum.KeyCode.Delete] = "Del",
	[Enum.KeyCode.Insert] = "Ins",
	[Enum.KeyCode.PageUp] = "PgUp",
	[Enum.KeyCode.PageDown] = "PgDn",
	[Enum.KeyCode.Home] = "Home",
	[Enum.KeyCode.End] = "End",
	[Enum.KeyCode.Up] = "Up",
	[Enum.KeyCode.Down] = "Down",
	[Enum.KeyCode.Left] = "Left",
	[Enum.KeyCode.Right] = "Right",
	[Enum.KeyCode.Minus] = "-",
	[Enum.KeyCode.Equals] = "=",
	[Enum.KeyCode.LeftBracket] = "[",
	[Enum.KeyCode.RightBracket] = "]",
	[Enum.KeyCode.Semicolon] = ";",
	[Enum.KeyCode.Quote] = "'",
	[Enum.KeyCode.Comma] = ",",
	[Enum.KeyCode.Period] = ".",
	[Enum.KeyCode.Slash] = "/",
	[Enum.KeyCode.BackSlash] = "\\",
	[Enum.KeyCode.Backquote] = "`",
	[Enum.KeyCode.Zero] = "0",
	[Enum.KeyCode.One] = "1",
	[Enum.KeyCode.Two] = "2",
	[Enum.KeyCode.Three] = "3",
	[Enum.KeyCode.Four] = "4",
	[Enum.KeyCode.Five] = "5",
	[Enum.KeyCode.Six] = "6",
	[Enum.KeyCode.Seven] = "7",
	[Enum.KeyCode.Eight] = "8",
	[Enum.KeyCode.Nine] = "9",
	[Enum.KeyCode.Unknown] = "None",
}

local function keyLabel(key)
	if key == nil or typeof(key) ~= "EnumItem" then
		return "None"
	end
	if MOUSE_LABELS[key] then
		return MOUSE_LABELS[key]
	end
	if KEY_LABELS[key] then
		return KEY_LABELS[key]
	end
	if key.EnumType == Enum.KeyCode then
		local name = key.Name
		if string.match(name, "^Keypad") then
			return "Num" .. string.sub(name, 7)
		end
		return name
	end
	return "None"
end

local function keyMatchesInput(key, input)
	if key == nil or typeof(key) ~= "EnumItem" then
		return false
	end
	if key.EnumType == Enum.KeyCode then
		return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key
	end
	return input.UserInputType == key
end

local function keyFromInput(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode
	end
	if MOUSE_LABELS[input.UserInputType] then
		return input.UserInputType
	end
	return nil
end

-- =====================================================================
-- chevron built from two hairline bars (no image assets)
-- =====================================================================

local CHEVRON_TAG = "NebulaChevron"
local CHEVRON_SHOWN = "NebulaChevronShown"
local CHEVRON_HIDDEN = "NebulaChevronHidden"
local COLLAPSED_TAG = "NebulaCollapsed"

-- True when a container between `instance` and `stopAt` is itself collapsed.
-- Nesting needs this: expanding a block must not reveal the chevrons that
-- belong to the still-closed blocks inside it.
local function insideCollapsed(instance, stopAt)
	local node = instance.Parent
	while node and node ~= stopAt do
		if node:GetAttribute(COLLAPSED_TAG) then
			return true
		end
		node = node.Parent
	end
	return false
end

-- Roblox does not clip rotated GuiObjects, and chevrons are built from rotated
-- bars. A container that collapses therefore has to hide them outright instead
-- of trusting ClipsDescendants, otherwise they float loose over the screen.
local function suppressChevrons(root, suppressed)
	if not root then
		return
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:GetAttribute(CHEVRON_TAG) then
			local hidden = suppressed or insideCollapsed(descendant, root)
			descendant:SetAttribute(CHEVRON_HIDDEN, hidden or nil)
			descendant.Visible = descendant:GetAttribute(CHEVRON_SHOWN) ~= false
				and not hidden
		end
	end
end

local function makeChevron(parent, size, closedRotation, openRotation)
	size = size or 9

	-- The glyph is a single text character, so there is no pair of rotated
	-- bars that can render out of sync on the first frame. The ">" glyph
	-- points right at rotation 0, so every rotation the library asks for is
	-- shifted by +90 to keep the old call sites pointing the same way.
	local holder = new("Frame", {
		Name = "Chevron",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -10, 0.5, 0),
		Rotation = (closedRotation or -90) + 90,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	holder:SetAttribute(CHEVRON_TAG, true)
	holder:SetAttribute(CHEVRON_SHOWN, true)

	local glyph = makeText({
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Font = METRICS.FontMedium,
		Text = "\u{203A}",
		TextColor3 = PALETTE.Muted,
		TextSize = size + 5,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = holder,
	})

	-- re-apply the resting rotation one frame later: on a fresh load Roblox
	-- occasionally skips the very first Rotation render, which is exactly the
	-- "broken until you touch the module" behaviour this replaces
	task.defer(function()
		if holder.Parent then
			holder.Rotation = (closedRotation or -90) + 90
		end
	end)

	local chevron = {
		Instance = holder,
		Glyph = glyph,
		ClosedRotation = closedRotation or -90,
		OpenRotation = openRotation or 0,
	}

	function chevron:SetColor(color)
		glyph.TextColor3 = color
	end

	function chevron:SetVisible(visible)
		local shown = visible and true or false
		holder:SetAttribute(CHEVRON_SHOWN, shown)
		holder.Visible = shown and not holder:GetAttribute(CHEVRON_HIDDEN)
	end

	function chevron:SetOpen(open, animate)
		local goal = (open and self.OpenRotation or self.ClosedRotation) + 90
		if animate == false then
			holder.Rotation = goal
		else
			tween(holder, ANIM.Normal, { Rotation = goal })
		end
	end

	return chevron
end

local BASE_COLOR = "NebulaBaseColor"

local function bindHover(target, registry, normal, hover)
	target:SetAttribute(BASE_COLOR, normal)
	target.BackgroundColor3 = normal
	registry:Add(target.MouseEnter:Connect(function()
		local base = target:GetAttribute(BASE_COLOR) or normal
		tween(target, ANIM.Fast, { BackgroundColor3 = shade(base, 0.08) })
	end))
	registry:Add(target.MouseLeave:Connect(function()
		local base = target:GetAttribute(BASE_COLOR) or normal
		tween(target, ANIM.Fast, { BackgroundColor3 = base })
	end))
end

-- Right click helper: GuiButtons expose no MouseButton2Click signal.
local function onRightClick(target, registry, handler)
	registry:Add(target.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			handler(input)
		end
	end))
end

local function getPlayerGui()
	local player = Players.LocalPlayer
	if not player then
		local elapsed = 0
		while not Players.LocalPlayer and elapsed < 5 do
			elapsed = elapsed + task.wait(0.05)
		end
		player = Players.LocalPlayer
	end
	if not player then
		return nil, "Players.LocalPlayer is unavailable (NebulaUI is client only)"
	end

	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		playerGui = player:WaitForChild("PlayerGui", 5)
	end
	if not playerGui then
		return nil, "PlayerGui is unavailable"
	end
	return playerGui
end

local function resolveOffsets(position, area, fallbackX, fallbackY)
	if typeof(position) ~= "UDim2" then
		return fallbackX, fallbackY
	end
	local x = position.X.Offset + position.X.Scale * area.X
	local y = position.Y.Offset + position.Y.Scale * area.Y
	return math.floor(x + 0.5), math.floor(y + 0.5)
end

-- =====================================================================
-- forward declared classes
-- =====================================================================

local Window = {}
Window.__index = Window

local Container = {}
Container.__index = Container

local Panel = setmetatable({}, { __index = Container })
Panel.__index = Panel

local Submenu = setmetatable({}, { __index = Container })
Submenu.__index = Submenu

local createSubmenu

-- =====================================================================
-- window
-- =====================================================================

function NebulaUI:CreateWindow(options)
	options = type(options) == "table" and options or {}

	local playerGui, problem = getPlayerGui()
	if not playerGui then
		error("[NebulaUI] " .. tostring(problem), 2)
	end

	local guiName = type(options.Name) == "string" and options.Name or NebulaUI.GuiName

	-- Reuse one ScreenGui name safely.
	local existing = playerGui:FindFirstChild(guiName)
	if existing then
		existing:Destroy()
	end

	local window = setmetatable({
		Title = tostring(options.Title or "Nebula"),
		Subtitle = tostring(options.Subtitle or ""),
		Accent = typeof(options.Accent) == "Color3" and options.Accent or Color3.fromRGB(214, 214, 255),
		_theme = type(options.Theme) == "string" and options.Theme or "Phantom",
		Panels = {},
		_registry = Registry.new(),
		_accentBindings = {},
		_inputBegan = {},
		_inputChanged = {},
		_inputEnded = {},
		_visible = true,
		_destroyed = false,
		_toggleKey = typeof(options.ToggleKey) == "EnumItem" and options.ToggleKey or nil,
	}, Window)

	local gui = new("ScreenGui", {
		Name = guiName,
		AutoLocalize = false,
		DisplayOrder = tonumber(options.DisplayOrder) or 100,
		IgnoreGuiInset = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	window.Gui = gui
	window._registry:Add(gui)

	-- The HUD (arraylist + notifications) lives in its own ScreenGui. It ignores
	-- the topbar inset, so the list sits at the true top edge of the screen, and
	-- it is never disabled with the menu, so active modules stay on screen while
	-- the interface is hidden.
	local hudName = guiName .. "Hud"
	local existingHud = playerGui:FindFirstChild(hudName)
	if existingHud then
		existingHud:Destroy()
	end

	local hud = new("ScreenGui", {
		Name = hudName,
		AutoLocalize = false,
		DisplayOrder = (tonumber(options.DisplayOrder) or 100) + 1,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	window.Hud = hud
	window._hudFont = resolveFontOption(options.HudFont, METRICS.FontHud)
	window._flowExtras = {}
	window._registry:Add(hud)

	local function layer(name, zIndex)
		return new("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = zIndex,
			Parent = gui,
		})
	end

	-- Separate sibling layers guarantee popups and tooltips draw above panels.
	window._layers = {
		panels = layer("Panels", 1),
		popups = layer("Popups", 5),
		overlays = layer("Overlays", 7),
		tooltips = layer("Tooltips", 9),
	}

	-- Transparent parent: each line supplies one exact-width dark segment. The
	-- segments touch vertically without overlap, forming a single stepped shape
	-- that follows the text instead of a rectangular panel.
	local moduleList = new("Frame", {
		Name = "ModuleList",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Position = UDim2.new(1, -HUD.RightMargin, 0, HUD.TopMargin),
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		ZIndex = 2,
		Parent = hud,
	})
	window._moduleListEnabled = options.ModuleList ~= false
	window._moduleBarEnabled = options.ModuleListBar ~= false
	window._moduleGlowEnabled = options.ModuleListGlow ~= false
	window._moduleBlurEnabled = options.ModuleListBlur ~= false
	window._moduleEntries = {}
	window._moduleOrder = {}
	window._hudChromaPalette = buildHudPalette(window.Accent, window._theme)

	local barGlowRecords = {}
	for index, definition in ipairs({
		{ Width = 7, Transparency = 0.84 },
		{ Width = 11, Transparency = 0.94 },
	}) do
		local glow = new("Frame", {
			Name = "SeparatorGlow" .. index,
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = definition.Transparency,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -HUD.BarWidth * 0.5, 0, 0),
			Size = UDim2.new(0, definition.Width, 1, 0),
			Visible = window._moduleBarEnabled and window._moduleGlowEnabled,
			ZIndex = 8,
			Parent = moduleList,
		})
		corner(glow, definition.Width * 0.5)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(window.Accent)
		gradient.Parent = glow
		table.insert(barGlowRecords, { Frame = glow, Gradient = gradient })
	end

	local separatorBar = new("Frame", {
		Name = "SeparatorBar",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.new(1, -HUD.BarWidth * 0.5, 0, 0),
		Size = UDim2.new(0, HUD.BarWidth, 1, 0),
		Visible = window._moduleBarEnabled,
		ZIndex = 9,
		Parent = moduleList,
	})
	corner(separatorBar, HUD.BarWidth * 0.5)
	local separatorGradient = Instance.new("UIGradient")
	separatorGradient.Rotation = 90
	separatorGradient.Color = ColorSequence.new(window.Accent)
	separatorGradient.Parent = separatorBar

	window._moduleBar = separatorBar
	window._moduleBarGradient = separatorGradient
	window._moduleBarGlows = barGlowRecords

	local lastHudUpdate = 0
	window._registry:Add(RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now - lastHudUpdate < HUD.UpdateRate then
			return
		end
		lastHudUpdate = now
		local palette = window._hudChromaPalette or buildHudPalette(window.Accent, window._theme)

		if moduleList.Visible then
			for _, record in ipairs(window._moduleOrder) do
				if record.NameLabel and record.NameLabel.Parent then
					local sequence = buildHudChromaSequence(
						record.NameLabel, now, palette, false
					)
					record.NameGradient.Color = sequence
					for _, glow in ipairs(record.Glows) do
						glow.Gradient.Color = sequence
					end
				end
			end
			if separatorBar.Visible then
				local barSequence = buildHudChromaSequence(
					separatorBar, now, palette, true
				)
				separatorGradient.Color = barSequence
				for _, glow in ipairs(barGlowRecords) do
					glow.Gradient.Color = barSequence
				end
			end
		end

		for _, gradient in ipairs(window._flowExtras) do
			if gradient.Parent then
				gradient.Color = buildHudChromaSequence(
					gradient.Parent, now, palette, false
				)
			end
		end
	end))

	local notices = new("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -METRICS.Margin, 1, -METRICS.Margin),
		Size = UDim2.new(0, 320, 0, 0),
		ZIndex = 1,
		Parent = hud,
	})
	local noticeLayout = vlist(notices, 10)
	noticeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	noticeLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	window._moduleList = moduleList
	window._notices = notices
	window._noticeOrder = 0

	local area = window._layers.panels.AbsoluteSize
	local startX, startY = resolveOffsets(
		options.StartPosition,
		area,
		METRICS.Margin,
		METRICS.Margin
	)
	window._flow = { x = startX, y = startY, originX = startX, rowHeight = 0, rowIndex = 1 }
	window._gap = tonumber(options.Gap) or METRICS.Gap

	-- One connection per input signal for the whole window.
	window._registry:Add(UserInputService.InputBegan:Connect(function(input, processed)
		fire(window._inputBegan, input, processed)
	end))
	window._registry:Add(UserInputService.InputChanged:Connect(function(input, processed)
		fire(window._inputChanged, input, processed)
	end))
	window._registry:Add(UserInputService.InputEnded:Connect(function(input, processed)
		fire(window._inputEnded, input, processed)
	end))

	-- Escape closes any open popup; optional key toggles the whole interface.
	window._registry:Add(listen(window._inputBegan, function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape then
			window:ClosePopups()
			return
		end
		-- the menu key is checked before "processed" so it still works when the
		-- game itself consumes the key (shift-lock, sprint scripts, etc.)
		if window._toggleKey and keyMatchesInput(window._toggleKey, input) then
			window:ToggleVisible()
			return
		end
		if processed then
			return
		end
	end))

	-- refresh HUD contents after accent/theme changes; text, glow, separator
	-- and frosted tint all derive from the same live Accent as the main UI
	window:BindAccent(window._registry, function()
		window:_refreshModuleGradient()
		window:_refreshModules()
	end)

	-- A Theme passed straight to CreateWindow used to be recorded without ever
	-- being painted, so the panels kept the default surfaces. Apply it here, and
	-- let an explicitly supplied Accent still win over the theme's own accent.
	if type(options.Theme) == "string" then
		window:SetTheme(options.Theme)
		if typeof(options.Accent) == "Color3" then
			window:SetAccent(options.Accent)
		end
	end

	return window
end

function Window:OnInputBegan(handler)
	return listen(self._inputBegan, handler)
end

function Window:OnInputChanged(handler)
	return listen(self._inputChanged, handler)
end

function Window:OnInputEnded(handler)
	return listen(self._inputEnded, handler)
end

function Window:BindAccent(registry, apply)
	table.insert(self._accentBindings, apply)
	apply(self.Accent)
	if registry then
		registry:Add(function()
			local index = table.find(self._accentBindings, apply)
			if index then
				table.remove(self._accentBindings, index)
			end
		end)
	end
	return apply
end

function Window:GetAccent()
	return self.Accent
end

function Window:SetAccent(color)
	if typeof(color) ~= "Color3" then
		return self
	end
	self.Accent = color
	for _, apply in ipairs(table.clone(self._accentBindings)) do
		local ok, err = pcall(apply, color)
		if not ok then
			warn("[NebulaUI] accent error: " .. tostring(err))
		end
	end
	return self
end

function Window:SetVisible(visible)
	self._visible = visible and true or false
	if not self._visible then
		self:ClosePopups()
	end
	if self.Gui then
		self.Gui.Enabled = self._visible
	end
	-- the HUD ScreenGui is deliberately left alone: the arraylist and any
	-- notifications stay on screen while the menu itself is hidden
	return self._visible
end

function Window:ToggleVisible()
	return self:SetVisible(not self._visible)
end

function Window:IsVisible()
	return self._visible
end

function Window:SetToggleKey(key)
	self._toggleKey = typeof(key) == "EnumItem" and key or nil
	return self._toggleKey
end

-- Only one dropdown may be open at a time.
function Window:RegisterPopup(popup)
	if self._activePopup and self._activePopup ~= popup then
		self._activePopup:Close()
	end
	self._activePopup = popup
end

function Window:ClearPopup(popup)
	if self._activePopup == popup then
		self._activePopup = nil
	end
end

function Window:GetTheme()
	return self._theme
end

-- Repaints every structural surface from the theme table, then fires the
-- accent bindings so toggles, sliders, underlines and keybind chips follow.
function Window:SetTheme(name)
	local theme = nil
	for key, value in pairs(THEMES) do
		if string.lower(key) == string.lower(tostring(name)) then
			theme = value
			name = key
			break
		end
	end
	if not theme then
		warn("[NebulaUI] unknown theme: " .. tostring(name))
		return self
	end
	self._theme = name

	if theme.Panel then PALETTE.Panel = theme.Panel end
	if theme.Header then PALETTE.Header = theme.Header end
	if theme.Popup then PALETTE.Popup = theme.Popup end
	if theme.Layers then
		LAYERS[1], LAYERS[2] = theme.Layers[1], theme.Layers[2]
	end

	if self.Gui then
		for _, node in ipairs(self.Gui:GetDescendants()) do
			local role = node:GetAttribute("NebulaRole")
			if role == "Panel" then
				node.BackgroundColor3 = PALETTE.Panel
			elseif role == "Header" then
				node.BackgroundColor3 = PALETTE.Header
			elseif role == "Popup" then
				node.BackgroundColor3 = PALETTE.Popup
			elseif role == "Box" then
				node.BackgroundColor3 = layerColor(node:GetAttribute("NebulaDepth") or 1)
			elseif role == "Row" then
				local base = layerColor(node:GetAttribute("NebulaDepth") or 0)
				if node:GetAttribute("NebulaBand") then
					base = shade(base, 0.03)
				end
				node:SetAttribute(BASE_COLOR, base)
				node.BackgroundColor3 = base
			elseif role == "Field" then
				-- buttons, dropdown fields, chips and text boxes sit one step above
				-- their layer, so they follow the theme like everything else
				local base = shade(layerColor(node:GetAttribute("NebulaDepth") or 0), 0.03)
				node:SetAttribute(BASE_COLOR, base)
				node.BackgroundColor3 = base
			end
		end
	end

	if theme.Accent then
		self:SetAccent(theme.Accent)
	end
	return self
end

function Window:SetModuleListVisible(visible)
	self._moduleListEnabled = visible and true or false
	self:_refreshModules()
	return self
end

function Window:IsModuleListVisible()
	return self._moduleListEnabled and true or false
end

function Window:SetModuleListBarVisible(visible)
	self._moduleBarEnabled = visible and true or false
	if self._moduleBar then
		self._moduleBar.Visible = self._moduleBarEnabled
	end
	for _, glow in ipairs(self._moduleBarGlows or {}) do
		glow.Frame.Visible = self._moduleBarEnabled and self._moduleGlowEnabled
	end
	self:_refreshModules()
	return self
end

function Window:IsModuleListBarVisible()
	return self._moduleBarEnabled and true or false
end

function Window:SetModuleListGlowEnabled(visible)
	self._moduleGlowEnabled = visible and true or false
	for _, record in pairs(self._moduleEntries or {}) do
		for _, glow in ipairs(record.Glows or {}) do
			glow.Label.Visible = self._moduleGlowEnabled
		end
	end
	for _, glow in ipairs(self._moduleBarGlows or {}) do
		glow.Frame.Visible = self._moduleBarEnabled and self._moduleGlowEnabled
	end
	return self
end

function Window:IsModuleListGlowEnabled()
	return self._moduleGlowEnabled and true or false
end

function Window:SetModuleListBlurEnabled(visible)
	self._moduleBlurEnabled = visible and true or false
	for _, record in pairs(self._moduleEntries or {}) do
		if record.Frost then
			record.Frost.Visible = self._moduleBlurEnabled
		end
	end
	return self
end

function Window:IsModuleListBlurEnabled()
	return self._moduleBlurEnabled and true or false
end

local function measureLineWidth(text, size, font)
	return TextService:GetTextSize(
		tostring(text),
		size,
		font or METRICS.FontMedium,
		Vector2.new(1e6, 1e6)
	).X
end

-- Rebuilds the shared theme palette for module names, their glow, the bar,
-- notifications and the subtle tint in each fitted backdrop segment.
function Window:_refreshModuleGradient()
	local now = os.clock()
	local palette = buildHudPalette(self.Accent, self._theme)
	self._hudChromaPalette = palette
	self._moduleGradientMain = buildHudChromaSequence(
		self._moduleList, now, palette, false
	)

	for _, record in pairs(self._moduleEntries or {}) do
		if record.Backdrop then
			local backdropColor = Color3.fromRGB(0, 0, 0)
				:Lerp(self.Accent, 0.025)
			record.BackdropRounded.BackgroundColor3 = backdropColor
			record.BackdropSquare.BackgroundColor3 = backdropColor
		end
		if record.Frost then
			local frostColor = Color3.fromRGB(20, 20, 24)
				:Lerp(self.Accent, 0.045)
			record.FrostRounded.BackgroundColor3 = frostColor
			record.FrostSquare.BackgroundColor3 = frostColor
		end
		local sequence = buildHudChromaSequence(
			record.NameLabel, now, palette, false
		)
		record.NameGradient.Color = sequence
		for _, glow in ipairs(record.Glows or {}) do
			glow.Gradient.Color = sequence
		end
	end

	if self._moduleBar and self._moduleBarGradient then
		local barSequence = buildHudChromaSequence(
			self._moduleBar, now, palette, true
		)
		self._moduleBarGradient.Color = barSequence
		for _, glow in ipairs(self._moduleBarGlows or {}) do
			glow.Gradient.Color = barSequence
		end
	end
	for _, gradient in ipairs(self._flowExtras or {}) do
		if gradient.Parent then
			gradient.Color = buildHudChromaSequence(
				gradient.Parent, now, palette, false
			)
		end
	end
end

-- One module line. Its dark segment matches this exact line width; adjacent
-- segments touch vertically and visually merge into a single stepped surface.
function Window:_buildModuleLine(feature)
	local lineHolder = new("Frame", {
		Name = "Module",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 4,
		Parent = self._moduleList,
	})

	local surfaceColor = Color3.fromRGB(0, 0, 0):Lerp(self.Accent, 0.025)
	local frostColor = Color3.fromRGB(20, 20, 24):Lerp(self.Accent, 0.045)
	local function buildLeftRoundedSurface(name, color, radius, zIndex)
		-- CanvasGroup applies translucency once after combining the rounded plate
		-- and square right fill, preventing a dark overlap seam.
		local group = new("CanvasGroup", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			ZIndex = zIndex,
			Parent = lineHolder,
		})
		local rounded = new("Frame", {
			Name = "LeftRoundedPlate",
			BackgroundColor3 = color,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = zIndex,
			Parent = group,
		})
		corner(rounded, radius)
		local rightSquare = new("Frame", {
			Name = "RightSquareFill",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = color,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, radius, 1, 0),
			ZIndex = zIndex,
			Parent = group,
		})
		return group, rounded, rightSquare
	end

	local frost, frostRounded, frostSquare = buildLeftRoundedSurface(
		"FrostSegment", frostColor,
		HUD.SegmentCorner + HUD.FrostBleed, 2
	)
	frost.Visible = self._moduleBlurEnabled
	local backdrop, backdropRounded, backdropSquare = buildLeftRoundedSurface(
		"BackdropSegment", surfaceColor, HUD.SegmentCorner, 3
	)

	local hudFont = self._hudFont or METRICS.FontHud
	local shadows = {}
	for index, definition in ipairs({
		{ Offset = Vector2.new(1, 1), Rest = HUD.TextShadowNear },
		{ Offset = Vector2.new(2, 2), Rest = HUD.TextShadowFar },
	}) do
		local shadowLabel = makeText({
			Name = "LetterShadow" .. index,
			AnchorPoint = Vector2.new(1, 0),
			Font = hudFont,
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextColor3 = Color3.new(0, 0, 0),
			TextSize = HUD.TextSize,
			TextTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 5,
			Parent = lineHolder,
		})
		table.insert(shadows, {
			Label = shadowLabel,
			Offset = definition.Offset,
			Rest = definition.Rest,
		})
	end

	local white = ColorSequence.new(Color3.new(1, 1, 1))
	local glows = {}
	for _, offset in ipairs(HUD_GLOW_OFFSETS) do
		local ghost = makeText({
			Name = "LetterGlow",
			AnchorPoint = Vector2.new(1, 0),
			Font = hudFont,
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = HUD.TextSize,
			TextTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Right,
			Visible = self._moduleGlowEnabled,
			ZIndex = 6,
			Parent = lineHolder,
		})
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 0
		gradient.Color = self._moduleGradientMain or white
		gradient.Parent = ghost
		table.insert(glows, {
			Label = ghost,
			Gradient = gradient,
			Offset = offset,
			Rest = HUD.GlowTransparency,
		})
	end

	local nameLabel = makeText({
		Name = "Name",
		AnchorPoint = Vector2.new(1, 0),
		Font = hudFont,
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = HUD.TextSize,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 7,
		Parent = lineHolder,
	})
	local nameGradient = Instance.new("UIGradient")
	nameGradient.Rotation = 0
	nameGradient.Color = self._moduleGradientMain or white
	nameGradient.Parent = nameLabel

	return {
		Holder = lineHolder,
		Backdrop = backdrop,
		BackdropRounded = backdropRounded,
		BackdropSquare = backdropSquare,
		Frost = frost,
		FrostRounded = frostRounded,
		FrostSquare = frostSquare,
		NameLabel = nameLabel,
		NameGradient = nameGradient,
		Glows = glows,
		Shadows = shadows,
		Width = 0,
	}
end

-- Value text uses the same font, size and baseline as the name, but stays a
-- fixed neutral gray and never receives the themed gradient/glow.
function Window:_syncModuleLine(record, feature)
	local name = feature.Label.Text
	local badge = feature._badge
	local hudFont = self._hudFont or METRICS.FontHud

	record.NameLabel.Text = name
	for _, shadow in ipairs(record.Shadows) do
		shadow.Label.Text = name
	end

	if badge ~= nil then
		if not record.BadgeLabel then
			local badgeShadows = {}
			for index, definition in ipairs({
				{ Offset = Vector2.new(1, 1), Rest = HUD.TextShadowNear },
				{ Offset = Vector2.new(2, 2), Rest = HUD.TextShadowFar },
			}) do
				local shadow = makeText({
					Name = "BadgeShadow" .. index,
					AnchorPoint = Vector2.new(1, 0),
					Font = hudFont,
					Size = UDim2.new(1, 0, 1, 0),
					TextColor3 = Color3.new(0, 0, 0),
					TextSize = HUD.TextSize,
					TextTransparency = definition.Rest,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 5,
					Parent = record.Holder,
				})
				table.insert(badgeShadows, {
					Label = shadow,
					Offset = definition.Offset,
					Rest = definition.Rest,
				})
			end

			local badgeLabel = makeText({
				Name = "Badge",
				AnchorPoint = Vector2.new(1, 0),
				Font = hudFont,
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				TextColor3 = HUD.BadgeColor,
				TextSize = HUD.TextSize,
				TextTransparency = HUD.BadgeTransparency,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 7,
				Parent = record.Holder,
			})
			record.BadgeLabel = badgeLabel
			record.BadgeShadows = badgeShadows
		end
		record.BadgeLabel.Text = badge
		for _, shadow in ipairs(record.BadgeShadows) do
			shadow.Label.Text = badge
		end
	elseif record.BadgeLabel then
		record.BadgeLabel:Destroy()
		for _, shadow in ipairs(record.BadgeShadows or {}) do
			shadow.Label:Destroy()
		end
		record.BadgeLabel = nil
		record.BadgeShadows = nil
	end

	local nameWidth = measureLineWidth(name, HUD.TextSize, hudFont)
	local badgeWidth = badge ~= nil and measureLineWidth(badge, HUD.TextSize, hudFont) or 0
	local gap = badge ~= nil and HUD.BadgeGap or 0
	record.Width = math.ceil(nameWidth + badgeWidth + gap)

	record.NameLabel.Size = UDim2.new(1, -(badgeWidth + gap), 1, 0)
	record.NameLabel.Position = UDim2.new(1, -(badgeWidth + gap), 0, 0)
	for _, shadow in ipairs(record.Shadows) do
		shadow.Label.Size = record.NameLabel.Size
		shadow.Label.Position = record.NameLabel.Position
			+ UDim2.fromOffset(shadow.Offset.X, shadow.Offset.Y)
	end
	for _, glow in ipairs(record.Glows) do
		glow.Label.Text = name
		glow.Label.Size = record.NameLabel.Size
		glow.Label.Position = record.NameLabel.Position
			+ UDim2.fromOffset(glow.Offset.X, glow.Offset.Y)
	end

	if record.BadgeLabel then
		record.BadgeLabel.Size = UDim2.new(0, badgeWidth, 1, 0)
		record.BadgeLabel.Position = UDim2.new(1, 0, 0, 0)
		for _, shadow in ipairs(record.BadgeShadows) do
			shadow.Label.Size = record.BadgeLabel.Size
			shadow.Label.Position = record.BadgeLabel.Position
				+ UDim2.fromOffset(shadow.Offset.X, shadow.Offset.Y)
		end
	end
end

-- Reconciles active features and builds the staircase silhouette from exact
-- text widths. Segments abut at integer row boundaries and never overlap.
function Window:_refreshModules()
	local holder = self._moduleList
	if not holder then
		return
	end
	local entries = self._moduleEntries

	local active = {}
	for _, panel in ipairs(self.Panels) do
		for _, feature in ipairs(panel._features or {}) do
			if feature:Get() and feature.Label then
				active[feature] = true
			end
		end
	end

	for feature, record in pairs(entries) do
		if not active[feature] then
			entries[feature] = nil
			tween(record.NameLabel, ANIM.Normal, { TextTransparency = 1 })
			for _, group in ipairs({
				record.Glows, record.Shadows, record.BadgeShadows or {},
			}) do
				for _, item in ipairs(group) do
					tween(item.Label, ANIM.Normal, { TextTransparency = 1 })
				end
			end
			if record.BadgeLabel then
				tween(record.BadgeLabel, ANIM.Normal, { TextTransparency = 1 })
			end
			tween(record.Backdrop, ANIM.Normal, { GroupTransparency = 1 })
			tween(record.Frost, ANIM.Normal, { GroupTransparency = 1 })
			local lineHolder = record.Holder
			tween(lineHolder, ANIM.Submenu, {
				Position = lineHolder.Position - UDim2.fromOffset(HUD.ExitSlide, 0),
			})
			task.delay(ANIM.Submenu + 0.04, function()
				if lineHolder.Parent then
					lineHolder:Destroy()
				end
			end)
		end
	end

	for feature in pairs(active) do
		local record = entries[feature]
		if not record then
			record = self:_buildModuleLine(feature)
			record.IsNew = true
			entries[feature] = record
		end
		self:_syncModuleLine(record, feature)
	end

	local order = {}
	for _, record in pairs(entries) do
		table.insert(order, record)
	end
	table.sort(order, function(a, b)
		return a.Width > b.Width
	end)
	self._moduleOrder = order

	local count = #order
	local barRegion = self._moduleBarEnabled and (HUD.BarGap + HUD.BarWidth) or 0
	local maxWidth = 0
	for index, record in ipairs(order) do
		maxWidth = math.max(maxWidth, record.Width)
		local target = UDim2.new(
			1,
			-(barRegion + HUD.PadX),
			0,
			HUD.PadY + (index - 1) * (HUD.LineHeight + HUD.LineGap)
		)
		local size = UDim2.fromOffset(record.Width, HUD.LineHeight)
		local topExtra = index == 1 and HUD.PadY or 0
		local bottomExtra = index == count and HUD.PadY or 0
		local segmentPosition = UDim2.new(0, -HUD.PadX, 0, -topExtra)
		local segmentSize = UDim2.new(
			1, HUD.PadX * 2,
			1, topExtra + bottomExtra
		)
		record.Backdrop.Position = segmentPosition
		record.Backdrop.Size = segmentSize
		-- the frost halo bleeds one pixel beyond every rounded edge
		local bleed = HUD.FrostBleed
		record.Frost.Position = UDim2.new(
			0, -HUD.PadX - bleed,
			0, -topExtra - bleed
		)
		record.Frost.Size = UDim2.new(
			1, HUD.PadX * 2 + bleed * 2,
			1, topExtra + bottomExtra + bleed * 2
		)
		record.Frost.Visible = self._moduleBlurEnabled

		if record.IsNew then
			record.IsNew = nil
			record.Holder.Position = target + UDim2.fromOffset(HUD.EnterSlide, 0)
			record.Holder.Size = size
			record.NameLabel.TextTransparency = 1
			record.Backdrop.GroupTransparency = 1
			record.Frost.GroupTransparency = 1
			for _, group in ipairs({
				record.Glows, record.Shadows, record.BadgeShadows or {},
			}) do
				for _, item in ipairs(group) do
					item.Label.TextTransparency = 1
				end
			end
			if record.BadgeLabel then
				record.BadgeLabel.TextTransparency = 1
			end

			tween(record.NameLabel, ANIM.Normal, { TextTransparency = 0 })
			for _, glow in ipairs(record.Glows) do
				tween(glow.Label, ANIM.Normal, { TextTransparency = glow.Rest })
			end
			for _, shadow in ipairs(record.Shadows) do
				tween(shadow.Label, ANIM.Normal, { TextTransparency = shadow.Rest })
			end
			if record.BadgeLabel then
				tween(record.BadgeLabel, ANIM.Normal, {
					TextTransparency = HUD.BadgeTransparency,
				})
				for _, shadow in ipairs(record.BadgeShadows or {}) do
					tween(shadow.Label, ANIM.Normal, { TextTransparency = shadow.Rest })
				end
			end
			tween(record.Backdrop, ANIM.Normal, {
				GroupTransparency = HUD.BackgroundTransparency,
			})
			if self._moduleBlurEnabled then
				tween(record.Frost, ANIM.Normal, {
					GroupTransparency = HUD.FrostTransparency,
				})
			end
		end
		tween(record.Holder, ANIM.Normal, { Position = target, Size = size })
	end

	local contentWidth = count > 0 and math.ceil(maxWidth + HUD.PadX * 2) or 0
	local targetWidth = contentWidth + barRegion
	local targetHeight = count > 0
		and math.ceil(HUD.PadY * 2 + count * HUD.LineHeight
			+ math.max(count - 1, 0) * HUD.LineGap)
		or 0
	self._moduleBar.Visible = self._moduleBarEnabled
	for _, glow in ipairs(self._moduleBarGlows or {}) do
		glow.Frame.Visible = self._moduleBarEnabled and self._moduleGlowEnabled
	end
	tween(holder, ANIM.Normal, {
		Size = UDim2.fromOffset(targetWidth, targetHeight),
	})

	if not self._moduleListEnabled then
		holder.Visible = false
	elseif count > 0 then
		self._moduleHideToken = nil
		holder.Visible = true
	else
		local token = {}
		self._moduleHideToken = token
		task.delay(ANIM.Submenu + 0.05, function()
			if self._moduleHideToken == token and #self._moduleOrder == 0 then
				holder.Visible = false
			end
		end)
	end
end

-- A themed notification card with a tweening expire bar, stacked bottom-right.
function Window:Notify(options)
	options = type(options) == "table" and options or {}
	local holder = self._notices
	if not holder then
		return self
	end

	local registry = Registry.new()
	self._registry:Add(function()
		registry:Destroy()
	end)

	local duration = math.clamp(tonumber(options.Duration) or 4, 0.5, 30)
	self._noticeOrder = (self._noticeOrder or 0) + 1

	-- The shell carries the drop shadow: a CanvasGroup renders its children
	-- into its own bounds, so the falloff has to live outside the card.
	local shell = new("Frame", {
		Name = "Notice",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = self._noticeOrder,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = holder,
	})
	registry:Add(shell)

	-- One tight plate gives the card depth without the oversized black halo the
	-- old two-layer, eight-pixel spread created.
	local shadowPlates = {}
	local plate = new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(-2, 1),
		Size = UDim2.new(1, 4, 1, 4),
		ZIndex = 4,
		Parent = shell,
	})
	corner(plate, METRICS.SmallCorner + 2)
	table.insert(shadowPlates, { Plate = plate, Rest = 0.9 })

	-- a CanvasGroup lets the whole card fade in and out as one unit
	local card = new("CanvasGroup", {
		Name = "Card",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PALETTE.Popup,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 6,
		Parent = shell,
	})
	corner(card, METRICS.SmallCorner)
	local cardStroke = stroke(card, PALETTE.Border)
	card:SetAttribute("NebulaRole", "Popup")
	registry:Add(card)
	registry:Add(cardStroke)

	pad(card, 12, 14, 11, 14)
	vlist(card, 8)

	-- the title rides the same accent/white flow as the arraylist
	local titleLabel = makeText({
		Name = "Title",
		Font = self._hudFont or METRICS.FontHud,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, METRICS.LabelHeight),
		Text = tostring(options.Title or "Notice"),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = METRICS.TextSize + 1,
		Parent = card,
	})

	local titleGradient = Instance.new("UIGradient")
	titleGradient.Rotation = 0
	titleGradient.Color = self._moduleGradientMain or ColorSequence.new(self.Accent)
	titleGradient.Parent = titleLabel

	self._flowExtras = self._flowExtras or {}
	table.insert(self._flowExtras, titleGradient)
	registry:Add(function()
		local extras = self._flowExtras or {}
		for index = #extras, 1, -1 do
			if extras[index] == titleGradient then
				table.remove(extras, index)
			end
		end
	end)

	if options.Content ~= nil then
		makeText({
			Name = "Content",
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			Text = tostring(options.Content),
			TextColor3 = PALETTE.SubText,
			TextSize = METRICS.TextSize,
			TextTruncate = Enum.TextTruncate.None,
			TextWrapped = true,
			LineHeight = 1.15,
			Parent = card,
		})
	end

	-- the expire bar drains over the duration, then the card fades out
	local barTrack = new("Frame", {
		Name = "ExpireTrack",
		BackgroundColor3 = PALETTE.BorderSoft,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 3),
		Parent = card,
	})
	corner(barTrack, 2)

	local barFill = new("Frame", {
		Name = "Fill",
		BackgroundColor3 = self.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = barTrack,
	})
	corner(barFill, 2)

	-- themed live: the bar follows the accent, the card follows Popup, and the
	-- title picks up the rebuilt accent/white flow
	self:BindAccent(registry, function(accent)
		barFill.BackgroundColor3 = accent
		titleGradient.Color = self._moduleGradientMain or ColorSequence.new(accent)
	end)

	local dismissed = false
	local function dismiss()
		if dismissed or not card.Parent then
			return
		end
		dismissed = true
		tween(card, ANIM.Normal, { GroupTransparency = 1 })
		for _, plate in ipairs(shadowPlates) do
			tween(plate.Plate, ANIM.Normal, { BackgroundTransparency = 1 })
		end
		task.delay(ANIM.Normal + 0.05, function()
			registry:Destroy()
		end)
	end

	tween(card, ANIM.Normal, { GroupTransparency = 0 })
	for _, plate in ipairs(shadowPlates) do
		tween(plate.Plate, ANIM.Normal, { BackgroundTransparency = plate.Rest })
	end
	local drain = TweenService:Create(
		barFill,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0, 1) }
	)
	registry:Add(drain.Completed:Connect(dismiss))
	drain:Play()

	return self
end

function Window:ClosePopups()
	local popup = self._activePopup
	if popup then
		self._activePopup = nil
		popup:Close()
	end
end

function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	self:ClosePopups()

	for _, panel in ipairs(table.clone(self.Panels)) do
		panel:Destroy()
	end
	table.clear(self.Panels)
	table.clear(self._accentBindings)
	table.clear(self._inputBegan)
	table.clear(self._inputChanged)
	table.clear(self._inputEnded)

	self._registry:Destroy()
	self.Gui = nil
	self.Hud = nil
	self._layers = nil
	self._moduleEntries = {}
	self._moduleOrder = {}
	self._flowExtras = {}
end

-- =====================================================================
-- tooltips (single reusable card in the tooltip layer)
-- =====================================================================

function Window:_ensureTooltip()
	if self._tooltip then
		return self._tooltip
	end

	-- a CanvasGroup fades the whole card (background + text) with one property
	local frame = new("CanvasGroup", {
		Name = "Tooltip",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PALETTE.Tooltip,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Size = UDim2.fromOffset(303, 0),
		Visible = false,
		Parent = self._layers.tooltips,
	})
	corner(frame, METRICS.Corner)
	local outline = stroke(frame, PALETTE.Border)
	outline.Transparency = 0
	pad(frame, 7, 9, 8, 9)
	vlist(frame, 3)
	-- compact tooltip-only shadow: a 6px maximum spread, not a large halo
	local shadow = attachShadow(frame, self._registry, {
		Layers = 3,
		Step = 2,
		Strength = 0.86,
		Corner = METRICS.Corner,
	})
	local shadowPlates = {}
	for _, plate in ipairs(shadow:GetChildren()) do
		if plate:IsA("GuiObject") then
			plate:SetAttribute("RestTransparency", plate.BackgroundTransparency)
			plate.BackgroundTransparency = 1
			table.insert(shadowPlates, plate)
		end
	end

	-- every line sizes itself: a fixed slot would clip the row-sized title
	local function line(order, color, size, wrapped)
		return makeText({
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 0),
			TextColor3 = color,
			TextSize = size,
			TextTruncate = Enum.TextTruncate.None,
			TextWrapped = wrapped or false,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = frame,
		})
	end

	-- the title mirrors the hovered module exactly: same family, same size
	local title = line(1, PALETTE.Text, METRICS.TextSize, false)
	title.Font = METRICS.Font
	local description = line(2, PALETTE.SubText, METRICS.SmallTextSize, true)
	local hint = line(3, PALETTE.Muted, METRICS.SmallTextSize, true)

	-- Tooltip surfaces follow SetTheme/SetAccent immediately. The background is
	-- the active theme's popup/panel mix; the 1px outline is a muted accent; the
	-- shadow carries a very subtle tint from that same theme.
	self:BindAccent(self._registry, function(accent)
		local theme = THEMES[self._theme] or THEMES.Phantom
		local panelColor = theme.Panel or PALETTE.Panel
		local popupColor = theme.Popup or PALETTE.Popup
		frame.BackgroundColor3 = popupColor:Lerp(panelColor, 0.28)
		outline.Color = PALETTE.Border:Lerp(accent, 0.32)
		title.TextColor3 = PALETTE.Text:Lerp(accent, 0.06)
		description.TextColor3 = PALETTE.SubText
		hint.TextColor3 = PALETTE.Muted
		local shadowColor = panelColor:Lerp(Color3.new(0, 0, 0), 0.58)
		for _, plate in ipairs(shadowPlates) do
			plate.BackgroundColor3 = shadowColor
		end
	end)

	self._tooltip = { Instance = frame, Title = title, Description = description, Hint = hint, Stroke = outline, ShadowPlates = shadowPlates, TextLabels = { title, description, hint } }
	return self._tooltip
end

local TOOLTIP_HANDOFF = 0.045
local TOOLTIP_TEXT_FADE = 0.06
local TOOLTIP_CARD_FADE = 0.10

function Window:ShowTooltip(target, title, description, hint)
	if self._destroyed or not self._layers or not target then
		return
	end
	if type(hint) == "function" then
		hint = hint()
	end

	local tip = self:_ensureTooltip()
	local previousTarget = self._tooltipTarget
	local switching = tip.Instance.Visible
		and previousTarget ~= nil
		and previousTarget ~= target

	-- Every enter cancels the previous row's delayed leave. This handoff is what
	-- keeps a sweep A -> B on the text-crossfade path instead of starting a full
	-- card fade-out and fade-in against one another.
	tip._hoverToken = (tip._hoverToken or 0) + 1
	tip._fadeToken = (tip._fadeToken or 0) + 1
	self._tooltipTarget = target

	local function applyText()
		tip.Title.Text = tostring(title or "")
		tip.Title.Visible = tip.Title.Text ~= ""
		tip.Description.Text = tostring(description or "")
		tip.Description.Visible = tip.Description.Text ~= ""
		tip.Hint.Text = tostring(hint or "")
		tip.Hint.Visible = tip.Hint.Text ~= ""
	end

	local function place()
		if self._destroyed or self._tooltipTarget ~= target or not target.Parent then
			return
		end
		local layerFrame = self._layers.tooltips
		local mouse = Players.LocalPlayer:GetMouse()
		local origin = Vector2.new(mouse.X, mouse.Y)
		local size = tip.Instance.AbsoluteSize
		local x = origin.X + 12
		local y = origin.Y + 10
		if x + size.X > layerFrame.AbsoluteSize.X - 4 then
			x = origin.X - size.X - 4
		end
		if y + size.Y > layerFrame.AbsoluteSize.Y - 4 then
			y = origin.Y - size.Y - 4
		end
		x = math.max(4, x)
		y = math.max(4, y)
		tip.Instance.Position = UDim2.fromOffset(
			math.floor(x + 0.5), math.floor(y + 0.5)
		)
	end

	if switching then
		-- Short, tokenized text crossfade. Rapid A -> B -> C sweeps can only
		-- commit C; stale delayed swaps return before touching the labels.
		tip._textToken = (tip._textToken or 0) + 1
		local textToken = tip._textToken
		for _, label in ipairs(tip.TextLabels) do
			tween(label, TOOLTIP_TEXT_FADE, { TextTransparency = 1 })
		end
		task.delay(TOOLTIP_TEXT_FADE, function()
			if self._destroyed
				or tip._textToken ~= textToken
				or self._tooltipTarget ~= target then
				return
			end
			applyText()
			place()
			for _, label in ipairs(tip.TextLabels) do
				label.TextTransparency = 1
				tween(label, TOOLTIP_TEXT_FADE, { TextTransparency = 0 })
			end
			task.defer(place)
		end)
		return
	end

	applyText()
	if not (tip.Title.Visible or tip.Description.Visible or tip.Hint.Visible) then
		tip.Instance.Visible = false
		return
	end
	for _, label in ipairs(tip.TextLabels) do
		label.TextTransparency = 0
	end

	tip.Instance.Visible = true
	place()
	tween(tip.Instance, TOOLTIP_CARD_FADE, { GroupTransparency = 0 })
	for _, plate in ipairs(tip.ShadowPlates) do
		tween(plate, TOOLTIP_CARD_FADE, {
			BackgroundTransparency = plate:GetAttribute("RestTransparency") or 0.9,
		})
	end
	task.defer(place)
end

function Window:HideTooltip(target)
	if target and self._tooltipTarget ~= target then
		return
	end
	local tip = self._tooltip
	if not tip or self._destroyed then
		return
	end

	-- Keep the old target for a few milliseconds. If a neighbouring module is
	-- entered, ShowTooltip increments _hoverToken and cancels this hide, letting
	-- the text crossfade cleanly while the card stays visible.
	local hoverToken = (tip._hoverToken or 0) + 1
	tip._hoverToken = hoverToken
	local leavingTarget = target or self._tooltipTarget
	task.delay(target and TOOLTIP_HANDOFF or 0, function()
		if self._destroyed or tip._hoverToken ~= hoverToken then
			return
		end
		if leavingTarget and self._tooltipTarget ~= leavingTarget then
			return
		end

		self._tooltipTarget = nil
		tip._textToken = (tip._textToken or 0) + 1
		local fadeToken = (tip._fadeToken or 0) + 1
		tip._fadeToken = fadeToken
		tween(tip.Instance, TOOLTIP_CARD_FADE, { GroupTransparency = 1 })
		for _, plate in ipairs(tip.ShadowPlates) do
			tween(plate, TOOLTIP_CARD_FADE, { BackgroundTransparency = 1 })
		end
		task.delay(TOOLTIP_CARD_FADE + 0.02, function()
			if tip._fadeToken == fadeToken and self._tooltipTarget == nil then
				tip.Instance.Visible = false
			end
		end)
	end)
end

function Window:AttachTooltip(target, registry, title, description, hint)
	registry:Add(target.MouseEnter:Connect(function()
		self:ShowTooltip(target, title, description, hint)
	end))
	registry:Add(target.MouseLeave:Connect(function()
		self:HideTooltip(target)
	end))
	registry:Add(function()
		self:HideTooltip(target)
	end)
end

-- =====================================================================
-- panel flow layout
-- =====================================================================

function Window:_nextFlowPosition(width)
	local flow = self._flow
	local area = self._layers.panels.AbsoluteSize
	local limit = (area.X > 0 and area.X or 1280) - METRICS.Margin

	if flow.x > flow.originX and flow.x + width > limit then
		flow.x = flow.originX
		flow.y = flow.y + flow.rowHeight + self._gap
		flow.rowHeight = 0
		flow.rowIndex = flow.rowIndex + 1
	end

	local position = UDim2.fromOffset(flow.x, flow.y)
	flow.x = flow.x + width + self._gap
	return position, flow.rowIndex
end

-- =====================================================================
-- panels
-- =====================================================================

function Window:CreatePanel(options)
	options = type(options) == "table" and options or {}

	local width = math.floor(math.max(METRICS.MinPanelWidth, tonumber(options.Width) or METRICS.PanelWidth))
	local position, flowRow
	if typeof(options.Position) == "UDim2" then
		local x, y = resolveOffsets(options.Position, self._layers.panels.AbsoluteSize, 0, 0)
		position = UDim2.fromOffset(x, y)
	else
		position, flowRow = self:_nextFlowPosition(width)
	end

	local panel = setmetatable({
		Window = self,
		Width = width,
		Title = tostring(options.Title or "Panel"),
		Depth = 0,
		elements = {},
		_registry = Registry.new(),
		_orderCounter = 0,
		_collapsed = options.Collapsed == true,
		_flowRow = flowRow,
		_destroyed = false,
		-- feature rows tracked for the small "how many are on" header counter
		_features = {},
		_counter = options.Counter ~= false,
		_subtitle = tostring(options.Subtitle or ""),
	}, Panel)
	panel.panel = panel
	panel.window = self

	local frame = new("Frame", {
		Name = "Panel",
		BackgroundColor3 = PALETTE.Panel,
		BorderSizePixel = 0,
		-- flush rows have to be trimmed by the rounded panel edge
		ClipsDescendants = true,
		Position = position,
		Size = UDim2.fromOffset(width, METRICS.HeaderHeight),
		Parent = self._layers.panels,
	})
	corner(frame, METRICS.Corner)
	stroke(frame, PALETTE.Border)
	frame:SetAttribute("NebulaRole", "Panel")
	panel.Instance = frame

	-- every panel casts a soft shadow so it lifts off whatever is behind it
	attachShadow(frame, panel._registry, {
		Layers = 4,
		Step = 2,
		Strength = 0.9,
		Corner = METRICS.Corner,
	})

	local header = makeButton({
		Name = "Header",
		BackgroundColor3 = PALETTE.Header,
		Size = UDim2.new(1, 0, 0, METRICS.HeaderHeight),
		Parent = frame,
	})
	corner(header, METRICS.Corner)
	header:SetAttribute("NebulaRole", "Header")
	panel.Header = header

	-- squares off the two bottom corners of the rounded header
	local cornerFill = new("Frame", {
		Name = "CornerFill",
		BackgroundColor3 = PALETTE.Header,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -METRICS.Corner),
		Size = UDim2.new(1, 0, 0, METRICS.Corner),
		ZIndex = 1,
		Parent = header,
	})
	cornerFill:SetAttribute("NebulaRole", "Header")

	local titleLabel = makeText({
		Name = "Title",
		Font = METRICS.FontMedium,
		Position = UDim2.fromOffset(9, 0),
		Size = UDim2.new(1, -48, 1, 0),
		Text = panel.Title,
		ZIndex = 2,
		Parent = header,
	})
	panel.TitleLabel = titleLabel

	local subtitleLabel = makeText({
		Name = "Subtitle",
		Position = UDim2.new(1, -36, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0.5, -24, 1, 0),
		Text = tostring(options.Subtitle or ""),
		TextColor3 = PALETTE.Muted,
		TextSize = METRICS.SmallTextSize,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = header,
	})
	panel.SubtitleLabel = subtitleLabel

	local chevron = makeChevron(header, 12, 0, 180)
	chevron.Instance.ZIndex = 2
	chevron:SetColor(PALETTE.SubText)
	chevron:SetOpen(not panel._collapsed, false)
	panel.Chevron = chevron

	if options.Underline ~= false then
		local underline = new("Frame", {
			Name = "Underline",
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 3,
			Parent = header,
		})
		self:BindAccent(panel._registry, function(accent)
			underline.BackgroundColor3 = accent
		end)
		panel.Underline = underline
	else
		new("Frame", {
			Name = "Underline",
			BackgroundColor3 = PALETTE.BorderSoft,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 3,
			Parent = header,
		})
	end

	-- The body is a real scroller. Short panels behave exactly like the old
	-- frame, while long submenus cap at the viewport and remain reachable.
	local body = new("ScrollingFrame", {
		Name = "Body",
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, METRICS.HeaderHeight),
		ScrollBarImageColor3 = PALETTE.Knob,
		ScrollBarImageTransparency = 0.2,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = frame,
	})
	panel.Body = body

	local content = new("Frame", {
		Name = "Content",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = body,
	})
	pad(content, METRICS.PanelPad, METRICS.PanelPad, METRICS.PanelPad, METRICS.PanelPad)
	panel.content = content
	panel.Content = content
	panel.Layout = vlist(content, METRICS.RowGap)

	panel._registry:Add(panel.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if not panel._destroyed and not panel._collapsed and not panel._animating then
			panel:_apply(false)
		end
	end))

	-- Recompute the cap and clamp the panel whenever the viewport changes.
	panel._registry:Add(self._layers.panels:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if not panel._destroyed then
			panel:_apply(false)
		end
	end))

	-- header drag + click to collapse
	local dragging = false
	local dragStart = Vector3.zero
	local startPosition = frame.Position
	local travelled = 0

	panel._registry:Add(header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			travelled = 0
			dragStart = input.Position
			startPosition = frame.Position
			self:ClosePopups()
		end
	end))

	panel._registry:Add(self:OnInputChanged(function(input)
		if not dragging or panel._destroyed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		travelled = math.max(travelled, math.abs(delta.X) + math.abs(delta.Y))
		panel:_moveTo(startPosition.X.Offset + delta.X, startPosition.Y.Offset + delta.Y)
	end))

	panel._registry:Add(self:OnInputEnded(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			if travelled < 5 and not panel._destroyed then
				panel:ToggleCollapsed()
			end
		end
	end))

	bindHover(header, panel._registry, PALETTE.Header, PALETTE.RowActive)

	panel:_apply(false)
	table.insert(self.Panels, panel)
	return panel
end

function Panel:_measure()
	return self.Layout.AbsoluteContentSize.Y + METRICS.PanelPad * 2
end

function Panel:_updateFlowHeight(height)
	local flow = self.Window and self.Window._flow
	if flow and self._flowRow and self._flowRow == flow.rowIndex then
		flow.rowHeight = math.max(flow.rowHeight, height)
	end
end

function Panel:_apply(animate)
	if self._destroyed then
		return
	end

	local measured = self:_measure()
	local layer = self.Window and self.Window._layers and self.Window._layers.panels
	local viewportHeight = layer and layer.AbsoluteSize.Y or (METRICS.HeaderHeight + measured)
	local maxBodyHeight = math.max(0, viewportHeight - METRICS.HeaderHeight - 12)
	local bodyHeight = self._collapsed and 0 or math.min(measured, maxBodyHeight)
	local total = METRICS.HeaderHeight + bodyHeight
	self.Body.ScrollingEnabled = not self._collapsed and measured > bodyHeight + 1
	self.Body.ScrollBarImageTransparency = self.Body.ScrollingEnabled and 0.2 or 1

	-- rotated chevrons escape the body clip, so hide them while collapsed
	self.Body:SetAttribute(COLLAPSED_TAG, self._collapsed or nil)
	suppressChevrons(self.Body, self._collapsed)

	if animate then
		self.Body.Visible = true
		self._animating = true
		tween(self.Body, ANIM.Normal, { Size = UDim2.new(1, 0, 0, bodyHeight) })
		tween(self.Instance, ANIM.Normal, { Size = UDim2.fromOffset(self.Width, total) })
		task.delay(ANIM.Normal + 0.02, function()
			if self._destroyed then
				return
			end
			self._animating = false
			self:_apply(false)
		end)
	else
		self.Body.Size = UDim2.new(1, 0, 0, bodyHeight)
		self.Instance.Size = UDim2.fromOffset(self.Width, total)
		self.Body.Visible = not self._collapsed
	end

	self:_updateFlowHeight(total)

	-- Expanding near the bottom used to grow through the screen. Move only as
	-- far as needed to keep the complete header and scrollable body visible.
	local position = self.Instance.Position
	self:_moveTo(position.X.Offset, position.Y.Offset)
end

function Panel:_moveTo(x, y)
	local layerFrame = self.Window and self.Window._layers and self.Window._layers.panels
	if not layerFrame then
		return
	end
	local available = layerFrame.AbsoluteSize
	local size = self.Instance.AbsoluteSize
	local maxX = math.max(0, available.X - size.X)
	local maxY = math.max(0, available.Y - size.Y)
	self.Instance.Position = UDim2.fromOffset(
		math.clamp(math.floor(x + 0.5), 0, maxX),
		math.clamp(math.floor(y + 0.5), 0, maxY)
	)
end

function Panel:SetPosition(position)
	if typeof(position) ~= "UDim2" then
		return self
	end
	local x, y = resolveOffsets(position, self.Window._layers.panels.AbsoluteSize, 0, 0)
	self:_moveTo(x, y)
	return self
end

function Panel:SetTitle(text)
	self.Title = tostring(text or "")
	self.TitleLabel.Text = self.Title
	return self
end

function Panel:SetSubtitle(text)
	self._subtitle = tostring(text or "")
	self:_refreshCounter()
	return self
end

-- The header shows a small count of how many feature rows are switched on,
-- falling back to the subtitle when the panel has no feature rows.
function Panel:_trackFeature(element)
	table.insert(self._features, element)
	self:_refreshCounter()
end

function Panel:_untrackFeature(element)
	local index = table.find(self._features, element)
	if index then
		table.remove(self._features, index)
	end
	self:_refreshCounter()
end

function Panel:GetActiveCount()
	local active = 0
	for _, element in ipairs(self._features) do
		if element:Get() then
			active = active + 1
		end
	end
	return active
end

function Panel:_refreshCounter()
	if not self.SubtitleLabel then
		return
	end
	if not self._counter or #self._features == 0 then
		self.SubtitleLabel.Text = self._subtitle or ""
		return
	end
	local active = self:GetActiveCount()
	self.SubtitleLabel.Text = tostring(active)
	self.SubtitleLabel.TextColor3 = active > 0 and PALETTE.SubText or PALETTE.Muted
end

function Panel:SetCollapsed(collapsed, animate)
	collapsed = collapsed and true or false
	if self._collapsed == collapsed then
		return self._collapsed
	end
	self._collapsed = collapsed
	self.Chevron:SetOpen(not collapsed, animate ~= false)
	if collapsed then
		self.Window:ClosePopups()
	end
	self:_apply(animate ~= false)
	return self._collapsed
end

function Panel:ToggleCollapsed()
	return self:SetCollapsed(not self._collapsed)
end

function Panel:IsCollapsed()
	return self._collapsed
end

function Panel:SetVisible(visible)
	self.Instance.Visible = visible ~= false
	if not self.Instance.Visible then
		self.Window:ClosePopups()
	end
	return self
end

function Panel:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	for _, element in ipairs(table.clone(self.elements)) do
		element:Destroy()
	end
	table.clear(self.elements)

	self._registry:Destroy()

	if self.Window then
		local index = table.find(self.Window.Panels, self)
		if index then
			table.remove(self.Window.Panels, index)
		end
	end

	if self.Instance then
		self.Instance:Destroy()
		self.Instance = nil
	end
end

-- =====================================================================
-- element scaffolding
-- =====================================================================

function Container:_nextOrder()
	self._orderCounter = (self._orderCounter or 0) + 1
	return self._orderCounter
end

function Container:GetElements()
	return table.clone(self.elements)
end

local function baseElement(container, kind)
	local window = container.window
	local registry = Registry.new()

	local holder = new("Frame", {
		Name = kind,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = container:_nextOrder(),
		Size = UDim2.new(1, 0, 0, 0),
		Parent = container.content,
	})
	vlist(holder, 0)

	-- rows sit flush with the panel edge, every other control keeps an inset
	if kind ~= "Row" and kind ~= "Feature" and kind ~= "Toggle" and kind ~= "Keybind" then
		pad(holder, 5, METRICS.InsetPad, 5, METRICS.InsetPad)
	end

	local element = {
		Kind = kind,
		Window = window,
		Panel = container.panel,
		Parent = container,
		Instance = holder,
		Holder = holder,
		_registry = registry,
		_destroyed = false,
	}

	function element:SetVisible(visible)
		holder.Visible = visible ~= false
		if not holder.Visible and window then
			window:ClosePopups()
		end
		return self
	end

	function element:IsVisible()
		return holder.Visible
	end

	-- Tooltip("explanation") titles the box with the element's own label, so
	-- a module is documented in one call. Tooltip(title, description, hint)
	-- remains for full control.
	function element:Tooltip(title, description, hint)
		if description == nil and hint == nil and type(title) == "string" then
			description = title
			title = nil
		end
		if (title == nil or title == "") and self.Label and self.Label.Text ~= "" then
			title = self.Label.Text
		end
		if hint == nil and (kind == "Feature" or kind == "Toggle" or kind == "Row") then
			hint = function()
				local hasMenu = self.HasSubmenu and self:HasSubmenu()
				if kind == "Row" then
					return hasMenu and "Left-click opens settings" or nil
				end
				return hasMenu
					and "Left-click toggles  |  Right-click opens settings"
					or "Left-click toggles"
			end
		end
		local target = self._tooltipTarget or holder
		if window then
			window:AttachTooltip(target, registry, title, description, hint)
		end
		return self
	end

	function element:Get()
		return nil
	end

	function element:Set()
		return self
	end

	function element:Destroy()
		if self._destroyed then
			return
		end
		self._destroyed = true

		if self._submenu then
			self._submenu:Destroy()
			self._submenu = nil
		end

		registry:Destroy()

		local index = table.find(container.elements, self)
		if index then
			table.remove(container.elements, index)
		end

		if holder then
			holder:Destroy()
		end
	end

	table.insert(container.elements, element)
	return element, holder, registry
end

-- =====================================================================
-- submenus (inline, expand below their owning row)
-- =====================================================================

createSubmenu = function(owner, container)
	local window = container.window
	-- one nesting step deeper than the block that owns this row
	local depth = (container.Depth or 0) + 1

	local wrapper = new("Frame", {
		Name = "Submenu",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		Visible = false,
		Parent = owner.Holder,
	})
	wrapper:SetAttribute(COLLAPSED_TAG, true)

	-- The opened config sits inside its own inset box, the way the reference
	-- menu frames a feature's settings, instead of bleeding into the row list.
	local box = new("Frame", {
		Name = "Box",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = layerColor(depth),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(SUBMENU_INSET, SUBMENU_MARGIN),
		Size = UDim2.new(1, -SUBMENU_INSET * 2, 0, 0),
		Parent = wrapper,
	})
	corner(box, METRICS.SmallCorner)
	stroke(box, PALETTE.BorderSoft)
	box:SetAttribute("NebulaRole", "Box")
	box:SetAttribute("NebulaDepth", depth)

	local inner = new("Frame", {
		Name = "Inner",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = box,
	})
	pad(inner, SUBMENU_PAD, 0, SUBMENU_PAD, 0)
	local layout = vlist(inner, METRICS.RowGap)

	local submenu = setmetatable({
		Window = window,
		Panel = container.panel,
		Owner = owner,
		Parent = container,
		Depth = depth,
		Instance = wrapper,
		Content = inner,
		Layout = layout,
		window = window,
		panel = container.panel,
		content = inner,
		elements = {},
		_orderCounter = 0,
		_open = false,
		_animating = false,
		_destroyed = false,
		_registry = Registry.new(),
	}, Submenu)

	submenu._registry:Add(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if submenu._open and not submenu._animating and not submenu._destroyed then
			wrapper.Size = UDim2.new(1, 0, 0, submenu:_measure())
		end
	end))

	return submenu
end

function Submenu:_measure()
	local content = self.Layout.AbsoluteContentSize.Y
	if content <= 0 then
		return 0
	end
	-- the content, its box padding, and the margin above and below the box
	return content + SUBMENU_PAD * 2 + SUBMENU_MARGIN * 2
end

function Submenu:_setOpen(open, animate)
	open = open and true or false
	self._open = open

	if open then
		self.Instance.Visible = true
		self.Instance:SetAttribute(COLLAPSED_TAG, nil)
		suppressChevrons(self.Instance, false)
		local target = self:_measure()
		if animate == false then
			self.Instance.Size = UDim2.new(1, 0, 0, target)
			return
		end
		self._animating = true
		tween(self.Instance, ANIM.Submenu, { Size = UDim2.new(1, 0, 0, target) })
		task.delay(ANIM.Submenu + 0.02, function()
			if self._destroyed then
				return
			end
			self._animating = false
			if self._open then
				self.Instance.Size = UDim2.new(1, 0, 0, self:_measure())
			end
		end)
	else
		if self.window then
			self.window:ClosePopups()
		end
		self.Instance:SetAttribute(COLLAPSED_TAG, true)
		suppressChevrons(self.Instance, true)
		if animate == false then
			self.Instance.Size = UDim2.new(1, 0, 0, 0)
			self.Instance.Visible = false
			return
		end
		self._animating = true
		tween(self.Instance, ANIM.Submenu, { Size = UDim2.new(1, 0, 0, 0) })
		task.delay(ANIM.Submenu + 0.02, function()
			if self._destroyed then
				return
			end
			self._animating = false
			if not self._open then
				self.Instance.Visible = false
			end
		end)
	end
end

function Submenu:IsOpen()
	return self._open
end

function Submenu:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	for _, element in ipairs(table.clone(self.elements)) do
		element:Destroy()
	end
	table.clear(self.elements)

	self._registry:Destroy()

	if self.Instance then
		self.Instance:Destroy()
		self.Instance = nil
	end
end

-- Adds Submenu()/SetSubmenuOpen()/ToggleSubmenu() to a row-like element.
local function attachSubmenu(element, container, chevron, onChange)
	function element:Submenu()
		if not self._submenu then
			self._submenu = createSubmenu(self, container)
			if chevron then
				chevron:SetVisible(true)
				chevron:SetOpen(false, false)
			end
		end
		return self._submenu
	end

	function element:HasSubmenu()
		return self._submenu ~= nil
	end

	function element:IsSubmenuOpen()
		return self._submenu ~= nil and self._submenu._open
	end

	function element:SetSubmenuOpen(open, silent)
		local submenu = self._submenu
		if not submenu then
			return false
		end
		open = open and true or false
		if submenu._open ~= open then
			submenu:_setOpen(open, true)
			if chevron then
				chevron:SetOpen(open, true)
			end
			if not silent and onChange then
				onChange(open)
			end
		end
		return open
	end

	function element:ToggleSubmenu(silent)
		if not self._submenu then
			return false
		end
		return self:SetSubmenuOpen(not self._submenu._open, silent)
	end
end

-- Depth-aware colours: every container knows which nesting layer it draws on.
function Container:_depth()
	return self.Depth or 0
end

function Container:_rowColor(index)
	local base = layerColor(self:_depth())
	-- every other band lifts a hair, the way the reference list reads
	if index and index % 2 == 0 then
		return shade(base, 0.03)
	end
	return base
end

function Container:_rowHover(index)
	return shade(self:_rowColor(index), 0.08)
end

function Container:_rowActive(index)
	return shade(self:_rowColor(index), 0.15)
end

-- Fields (dropdown boxes, keybind chips, text boxes) sit a step above whatever
-- surface they are drawn on, so they still read as controls inside the darker
-- config box.
function Container:_fieldColor()
	return shade(self:_rowColor(), 0.03)
end

function Container:_fieldHover()
	return shade(self:_rowColor(), 0.08)
end

-- Shared interactive row shell, shaded for the layer it lives on.
local function rowShell(container, holder, height)
	local color = container:_rowColor(container._orderCounter)
	local row = makeButton({
		Name = "Row",
		BackgroundColor3 = color,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, height or METRICS.RowHeight),
		Parent = holder,
	})
	row:SetAttribute("NebulaRole", "Row")
	row:SetAttribute("NebulaDepth", container:_depth())
	row:SetAttribute("NebulaBand", container._orderCounter % 2 == 0)
	row:SetAttribute(BASE_COLOR, color)
	pad(row, 0, 13, 0, 13)
	return row
end

local function captionLine(holder, text, order)
	return makeText({
		Name = "Caption",
		LayoutOrder = order or 1,
		Size = UDim2.new(1, 0, 0, METRICS.LabelHeight),
		Text = tostring(text or ""),
		TextColor3 = PALETTE.SubText,
		TextSize = METRICS.SmallTextSize,
		Parent = holder,
	})
end

-- =====================================================================
-- static elements
-- =====================================================================

function Container:Label(text)
	local element, holder = baseElement(self, "Label")

	local body = makeText({
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Text = tostring(text or ""),
		TextColor3 = PALETTE.SubText,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = holder,
	})
	pad(body, 2, 2, 2, 2)

	element._tooltipTarget = body
	element.TextLabel = body

	function element:Get()
		return body.Text
	end

	function element:Set(value)
		body.Text = tostring(value or "")
		return self
	end

	return element
end

function Container:Warning(text)
	local element = self:Label(text)
	element.Kind = "Warning"
	element.TextLabel.TextColor3 = PALETTE.Warning
	element.TextLabel.Font = METRICS.FontMedium
	return element
end

function Container:Divider()
	local element, holder = baseElement(self, "Divider")

	local wrapper = new("Frame", {
		Name = "Wrapper",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 7),
		Parent = holder,
	})

	new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = PALETTE.BorderSoft,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = wrapper,
	})

	element._tooltipTarget = wrapper
	return element
end

-- =====================================================================
-- rows and toggles
-- =====================================================================

function Container:Row(text, callback)
	local element, holder, registry = baseElement(self, "Row")

	local row = rowShell(self, holder)
	local label = makeText({
		Name = "Label",
		Size = UDim2.new(1, -14, 1, 0),
		Text = tostring(text or ""),
		Parent = row,
	})

	local chevron = makeChevron(row, 12, -90, 0)
	chevron.Instance.Position = UDim2.new(1, -7, 0.5, 0)
	chevron:SetColor(PALETTE.Muted)
	chevron:SetVisible(false)

	bindHover(row, registry, row.BackgroundColor3, shade(row.BackgroundColor3, 0.08))

	attachSubmenu(element, self, chevron, function(open)
		invoke(callback, open)
	end)

	registry:Add(row.MouseButton1Click:Connect(function()
		if element._submenu then
			element:ToggleSubmenu()
		else
			invoke(callback, false)
		end
	end))

	onRightClick(row, registry, function()
		if element._submenu then
			element:ToggleSubmenu()
		end
	end)

	element._tooltipTarget = row
	element.Row = row
	element.Label = label

	function element:Get()
		return label.Text
	end

	function element:Set(value)
		label.Text = tostring(value or "")
		return self
	end

	return element
end

-- A feature row. Clicking the row itself switches the feature on, and its
-- label lights from grey to white; the chevron on the right (or a right click)
-- opens the settings block underneath. Every feature row counts towards the
-- small number in its panel header.
function Container:Feature(text, default, callback)
	local element, holder, registry = baseElement(self, "Feature")
	local panel = self.panel
	local window = self.window
	local value = default == true
	local hovered = false

	local row = rowShell(self, holder)
	local label = makeText({
		Name = "Label",
		Size = UDim2.new(1, -20, 1, 0),
		Text = tostring(text or ""),
		TextColor3 = PALETTE.SubText,
		Parent = row,
	})

	local chevron = makeChevron(row, 12, -90, 0)
	chevron.Instance.Position = UDim2.new(1, -7, 0.5, 0)
	chevron:SetColor(PALETTE.Muted)
	chevron:SetVisible(false)

	-- separate hit area over the chevron, so opening the block and switching the
	-- feature on never fight over the same click
	local expand = makeButton({
		Name = "Expand",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 8, 0.5, 0),
		Size = UDim2.new(0, 28, 1, 0),
		Text = "",
		Visible = false,
		ZIndex = 3,
		Parent = row,
	})

	local function labelColor()
		if value then
			return PALETTE.Text
		elseif hovered then
			return shade(PALETTE.SubText, 0.34)
		end
		return PALETTE.SubText
	end

	local baseColor = row.BackgroundColor3
	row:SetAttribute(BASE_COLOR, baseColor)

	-- active modules carry a faint wash of the theme accent; the resting base
	-- attribute stays untouched so theme repaints and hover math keep working
	local function restColor()
		local base = row:GetAttribute(BASE_COLOR) or baseColor
		if value then
			return base:Lerp(window.Accent, 0.14)
		end
		return base
	end

	local function applyVisual(animate)
		local target = hovered and shade(restColor(), 0.08) or restColor()
		if animate == false then
			label.TextColor3 = labelColor()
			row.BackgroundColor3 = target
		else
			tween(label, ANIM.Normal, { TextColor3 = labelColor() })
			tween(row, ANIM.Normal, { BackgroundColor3 = target })
		end
		chevron:SetColor(value and PALETTE.SubText or PALETTE.Muted)
	end

	window:BindAccent(registry, function()
		applyVisual(false)
	end)

	registry:Add(row.MouseEnter:Connect(function()
		hovered = true
		tween(row, ANIM.Fast, { BackgroundColor3 = shade(restColor(), 0.08) })
		applyVisual(true)
	end))

	registry:Add(row.MouseLeave:Connect(function()
		hovered = false
		tween(row, ANIM.Fast, { BackgroundColor3 = restColor() })
		applyVisual(true)
	end))

	local function setValue(newValue, silent, animate)
		value = newValue and true or false
		applyVisual(animate)
		if panel and panel._refreshCounter then
			panel:_refreshCounter()
		end
		if window and window._refreshModules then
			window:_refreshModules()
		end
		if not silent then
			invoke(callback, value)
		end
		return value
	end

	attachSubmenu(element, self, chevron, nil)

	local createSubmenuFor = element.Submenu
	function element:Submenu()
		local submenu = createSubmenuFor(self)
		expand.Visible = true
		return submenu
	end

	registry:Add(row.MouseButton1Click:Connect(function()
		setValue(not value, false, true)
	end))

	registry:Add(expand.MouseButton1Click:Connect(function()
		if element._submenu then
			element:ToggleSubmenu()
		end
	end))

	-- right click only reveals the settings block, it never flips the feature
	onRightClick(row, registry, function()
		if element._submenu then
			element:ToggleSubmenu()
		end
	end)

	element._tooltipTarget = row
	element.Row = row
	element.Label = label

	function element:Get()
		return value
	end

	function element:Set(newValue, silent)
		return setValue(newValue, silent, true)
	end

	function element:SetText(newText)
		label.Text = tostring(newText or "")
		if window and window._refreshModules then
			window:_refreshModules()
		end
		return self
	end

	-- a grey suffix shown after the name in the module list, e.g. "100 ms"
	function element:SetBadge(badge)
		element._badge = badge ~= nil and tostring(badge) or nil
		if window and window._refreshModules then
			window:_refreshModules()
		end
		return self
	end

	-- pins the badge to another element's value, so the list always mirrors it:
	-- BindBadge(slider, "%s ms") shows the slider live, e.g. "360 ms"
	function element:BindBadge(source, format)
		local function read()
			local ok, value = pcall(function()
				return source:Get()
			end)
			if not ok or value == nil then
				return nil
			end
			if type(format) == "function" then
				local okText, text = pcall(format, value)
				if okText then
					return tostring(text)
				end
				return tostring(value)
			end
			if type(format) == "string" then
				local okText, text = pcall(string.format, format, value)
				if okText then
					return text
				end
			end
			return tostring(value)
		end

		element:SetBadge(read())

		local stopped = false
		registry:Add(function()
			stopped = true
		end)
		task.spawn(function()
			while not stopped do
				local text = read()
				if text ~= element._badge then
					element:SetBadge(text)
				end
				task.wait(0.1)
			end
		end)
		return self
	end

	applyVisual(false)

	if panel and panel._trackFeature then
		panel:_trackFeature(element)
		registry:Add(function()
			panel:_untrackFeature(element)
			if window and window._refreshModules then
				window:_refreshModules()
			end
		end)
	end

	if window and window._refreshModules then
		window:_refreshModules()
	end

	return element
end

function Container:Toggle(text, default, callback)
	local element, holder, registry = baseElement(self, "Toggle")
	local window = self.window
	local value = default == true

	local row = rowShell(self, holder)
	local label = makeText({
		Name = "Label",
		Size = UDim2.new(1, -54, 1, 0),
		Text = tostring(text or ""),
		Parent = row,
	})

	local track = new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = PALETTE.Track,
		BorderSizePixel = 0,
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(40, 21),
		Parent = row,
	})
	corner(track, 11)
	stroke(track, PALETTE.Border)

	local knob = new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = PALETTE.Knob,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(17, 17),
		Parent = track,
	})
	corner(knob, 9)

	local chevron = makeChevron(row, 12, -90, 0)
	chevron.Instance.Position = UDim2.new(1, -51, 0.5, 0)
	chevron:SetColor(PALETTE.Muted)
	chevron:SetVisible(false)

	local function applyVisual(animate)
		local accent = window.Accent
		local trackColor = value and accent or self:_fieldColor()
		local knobColor = value and shade(accent, 0.78) or PALETTE.Knob
		local knobOffset = value and 21 or 2
		if animate == false then
			track.BackgroundColor3 = trackColor
			knob.BackgroundColor3 = knobColor
			knob.Position = UDim2.new(0, knobOffset, 0.5, 0)
		else
			tween(track, ANIM.Toggle, { BackgroundColor3 = trackColor })
			tween(knob, ANIM.Toggle, {
				BackgroundColor3 = knobColor,
				Position = UDim2.new(0, knobOffset, 0.5, 0),
			})
		end
	end

	window:BindAccent(registry, function()
		applyVisual(false)
	end)

	local function setValue(newValue, silent, animate)
		value = newValue and true or false
		applyVisual(animate)
		if not silent then
			invoke(callback, value)
		end
		return value
	end

	bindHover(row, registry, row.BackgroundColor3, shade(row.BackgroundColor3, 0.08))
	attachSubmenu(element, self, chevron, nil)

	registry:Add(row.MouseButton1Click:Connect(function()
		setValue(not value, false, true)
	end))

	-- right click never changes the value, it only reveals the submenu
	onRightClick(row, registry, function()
		if element._submenu then
			element:ToggleSubmenu()
		end
	end)

	element._tooltipTarget = row
	element.Row = row
	element.Label = label

	function element:Get()
		return value
	end

	function element:Set(newValue, silent)
		return setValue(newValue, silent, true)
	end

	function element:SetText(newText)
		label.Text = tostring(newText or "")
		return self
	end

	return element
end

-- =====================================================================
-- buttons
-- =====================================================================

local function pressFeedback(button)
	local base = button:GetAttribute(BASE_COLOR) or PALETTE.Row
	button.BackgroundColor3 = shade(base, 0.16)
	tween(button, ANIM.Normal, { BackgroundColor3 = base })
end

function Container:Button(text, callback)
	local element, holder, registry = baseElement(self, "Button")

	local button = makeButton({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, METRICS.ButtonHeight),
		Text = tostring(text or "Button"),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = holder,
	})
	corner(button, METRICS.SmallCorner)
	stroke(button, PALETTE.BorderSoft)
	button:SetAttribute("NebulaRole", "Field")
	button:SetAttribute("NebulaDepth", self:_depth())
	bindHover(button, registry, self:_fieldColor(), self:_fieldHover())

	registry:Add(button.MouseButton1Click:Connect(function()
		pressFeedback(button)
		invoke(callback)
	end))

	element._tooltipTarget = button
	element.Button = button

	function element:Get()
		return button.Text
	end

	function element:Set(value)
		button.Text = tostring(value or "")
		return self
	end

	return element
end

function Container:Buttons(entries)
	local element, holder, registry = baseElement(self, "Buttons")
	entries = type(entries) == "table" and entries or {}

	local count = math.max(1, #entries)
	local gap = 4

	local strip = new("Frame", {
		Name = "Strip",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, METRICS.ButtonHeight),
		Parent = holder,
	})
	hlist(strip, gap)

	element.Buttons = {}

	for index, entry in ipairs(entries) do
		local text, action
		if type(entry) == "table" then
			text = entry[1] or entry.Title or entry.Text or ("Button " .. index)
			action = entry[2] or entry.Callback or entry.callback
		else
			text = tostring(entry)
		end

		local button = makeButton({
			LayoutOrder = index,
			Size = UDim2.new(1 / count, -(gap * (count - 1)) / count, 1, 0),
			Text = tostring(text),
			TextSize = METRICS.SmallTextSize,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = strip,
		})
		corner(button, METRICS.SmallCorner)
		stroke(button, PALETTE.BorderSoft)
		button:SetAttribute("NebulaRole", "Field")
		button:SetAttribute("NebulaDepth", self:_depth())
		bindHover(button, registry, self:_fieldColor(), self:_fieldHover())

		registry:Add(button.MouseButton1Click:Connect(function()
			pressFeedback(button)
			invoke(action)
		end))

		table.insert(element.Buttons, button)
	end

	element._tooltipTarget = strip

	function element:Get()
		local labels = {}
		for index, button in ipairs(self.Buttons) do
			labels[index] = button.Text
		end
		return labels
	end

	function element:Set(labels)
		if type(labels) ~= "table" then
			return self
		end
		for index, button in ipairs(self.Buttons) do
			if labels[index] ~= nil then
				button.Text = tostring(labels[index])
			end
		end
		return self
	end

	return element
end

-- =====================================================================
-- dropdown (option list lives in the popup layer, never clipped)
-- =====================================================================

function Container:Dropdown(text, options, default, callback)
	local element, holder, registry = baseElement(self, "Dropdown")
	local window = self.window

	captionLine(holder, text, 1)

	local field = makeButton({
		Name = "Field",
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, METRICS.FieldHeight),
		Parent = holder,
	})
	corner(field, METRICS.SmallCorner)
	stroke(field, PALETTE.Border)
	pad(field, 0, 6, 0, 7)

	local valueLabel = makeText({
		Name = "Value",
		Size = UDim2.new(1, -14, 1, 0),
		Text = "",
		Parent = field,
	})

	local chevron = makeChevron(field, 8, 0, 180)
	chevron.Instance.Position = UDim2.new(1, -7, 0.5, 0)
	chevron:SetColor(PALETTE.Muted)

	-- full screen catcher: any click outside the list closes it
	local blocker = makeButton({
		Name = "DropdownBlocker",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 0,
		Parent = window._layers.popups,
	})
	registry:Add(blocker)

	local list = new("Frame", {
		Name = "DropdownList",
		BackgroundColor3 = PALETTE.Popup,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(120, 0),
		Visible = false,
		ZIndex = 2,
		Parent = window._layers.popups,
	})
	list:SetAttribute("NebulaRole", "Popup")
	corner(list, METRICS.SmallCorner)
	stroke(list, PALETTE.Border)
	registry:Add(list)

	-- the pop-up box carries its own shadow, so it clearly floats over the panel
	attachShadow(list, registry, {
		Layers = 4,
		Step = 2,
		Strength = 0.88,
		Corner = METRICS.SmallCorner,
	})

	local scroller = new("ScrollingFrame", {
		Name = "Options",
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = PALETTE.Knob,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
		Parent = list,
	})
	pad(scroller, 3, 3, 3, 3)
	vlist(scroller, 2)

	local entries = {}
	local values = {}
	local value = nil
	local open = false
	local follow = nil

	local function applySelectionVisual()
		for _, entry in ipairs(entries) do
			local selected = entry.Value == value
			-- the picked option reads plain white, the rest stay grey until hovered
			entry.Button.TextColor3 = selected and PALETTE.Text or PALETTE.SubText
			-- no band behind the selected option: the text alone carries the state
			entry.Button.BackgroundTransparency = 1
		end
	end

	window:BindAccent(registry, function()
		applySelectionVisual()
	end)

	local function setValue(newValue, silent)
		value = newValue ~= nil and tostring(newValue) or nil
		valueLabel.Text = value or ""
		valueLabel.TextColor3 = value and PALETTE.Text or PALETTE.Muted
		applySelectionVisual()
		if not silent then
			invoke(callback, value)
		end
		return value
	end

	local function listHeight()
		local count = #entries
		if count == 0 then
			return 0
		end
		return math.min(count * 34 + (count - 1) * 2 + 6, 264)
	end

	-- The options are a compact floating box rather than a full width list bolted
	-- under the field: it is only as wide as its longest option and it hangs off
	-- the field the way the reference menu does.
	local function listWidth()
		local widest = 0
		for _, entry in ipairs(entries) do
			widest = math.max(widest, #entry.Value)
		end
		local estimate = widest * METRICS.SmallTextSize * 0.68 + 48
		return math.floor(math.clamp(estimate, 150, 320) + 0.5)
	end

	local function targetPosition()
		local layers = window._layers
		if not layers or not field.Parent then
			return nil, nil
		end
		local layerFrame = layers.popups
		local origin = field.AbsolutePosition - layerFrame.AbsolutePosition
		local width, height = listWidth(), listHeight()

		-- the box hangs over the field itself rather than sitting under it, which
		-- is how the reference popup reads
		local x = origin.X + math.floor(field.AbsoluteSize.X * 0.42)
		local y = origin.Y + math.floor(field.AbsoluteSize.Y * 0.5)

		if x + width > layerFrame.AbsoluteSize.X - 6 then
			x = layerFrame.AbsoluteSize.X - width - 6
		end
		if y + height > layerFrame.AbsoluteSize.Y - 6 and origin.Y - height + 4 >= 6 then
			y = origin.Y - height + 4
		end

		return math.floor(math.max(6, x) + 0.5), math.floor(math.max(6, y) + 0.5)
	end

	local function updatePosition()
		local x, y = targetPosition()
		if x then
			list.Position = UDim2.fromOffset(x, y)
		end
	end

	local function stopFollow()
		if follow then
			follow:Disconnect()
			registry:Remove(follow)
			follow = nil
		end
	end

	local function closeList()
		blocker.Visible = false
		if not open then
			return
		end
		open = false
		stopFollow()
		chevron:SetOpen(false, true)
		tween(list, ANIM.Fast, {
			Size = UDim2.fromOffset(math.floor(listWidth() * 0.86), 0),
			BackgroundTransparency = 0.35,
		})
		task.delay(ANIM.Fast + 0.02, function()
			if not open and list and list.Parent then
				list.Visible = false
			end
		end)
		window:ClearPopup(element)
	end

	local function openList()
		if open or #entries == 0 then
			return
		end
		open = true
		window:RegisterPopup(element)

		local width, height = listWidth(), listHeight()
		local x, y = targetPosition()
		if not x then
			x, y = 0, 0
		end

		list.Visible = true
		blocker.Visible = true
		-- the box pops: it starts small, slightly high and faded, then settles
		list.Size = UDim2.fromOffset(math.floor(width * 0.86), math.floor(height * 0.5))
		list.BackgroundTransparency = 0.35
		list.Position = UDim2.fromOffset(x, y - 8)
		tween(list, ANIM.Submenu, {
			Size = UDim2.fromOffset(width, height),
			Position = UDim2.fromOffset(x, y),
			BackgroundTransparency = 0,
		})
		chevron:SetOpen(true, true)

		-- the follow loop only takes over once the pop has settled, so it never
		-- fights the opening tween
		task.delay(ANIM.Submenu + 0.02, function()
			if open and not follow and list and list.Parent then
				follow = registry:Add(RunService.RenderStepped:Connect(updatePosition))
			end
		end)
	end

	local function clearEntries()
		for _, entry in ipairs(entries) do
			entry.Button:Destroy()
		end
		table.clear(entries)
		table.clear(values)
	end

	local function rebuild(newOptions)
		clearEntries()
		for index, option in ipairs(newOptions) do
			local optionText = tostring(option)
			values[index] = optionText

			local button = makeButton({
				Name = "Option",
				BackgroundColor3 = PALETTE.Row,
				BackgroundTransparency = 0.4,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 34),
				Text = optionText,
				TextColor3 = PALETTE.SubText,
				TextSize = METRICS.SmallTextSize,
				Parent = scroller,
			})
			corner(button, METRICS.SmallCorner)
			pad(button, 0, 6, 0, 7)

			button.MouseButton1Click:Connect(function()
				setValue(optionText, false)
				closeList()
			end)
			button.MouseEnter:Connect(function()
				-- no box: only the text lights up as the pointer crosses the option
				tween(button, ANIM.Fast, { TextColor3 = PALETTE.Text })
			end)
			button.MouseLeave:Connect(function()
				if optionText == value then
					return
				end
				tween(button, ANIM.Fast, { TextColor3 = PALETTE.SubText })
			end)

			table.insert(entries, { Button = button, Value = optionText })
		end
		applySelectionVisual()
	end

	field:SetAttribute("NebulaRole", "Field")
	field:SetAttribute("NebulaDepth", self:_depth())
	bindHover(field, registry, self:_fieldColor(), self:_fieldHover())

	registry:Add(field.MouseButton1Click:Connect(function()
		if open then
			closeList()
		else
			openList()
		end
	end))
	onRightClick(field, registry, function()
		if open then
			closeList()
		else
			openList()
		end
	end)

	registry:Add(blocker.MouseButton1Click:Connect(closeList))
	onRightClick(blocker, registry, closeList)

	registry:Add(function()
		open = false
		stopFollow()
		window:ClearPopup(element)
	end)

	rebuild(type(options) == "table" and options or {})
	if default ~= nil then
		setValue(default, true)
	else
		setValue(values[1], true)
	end

	element._tooltipTarget = field
	element.Field = field
	element.List = list

	function element:Get()
		return value
	end

	function element:Set(newValue, silent)
		return setValue(newValue, silent)
	end

	function element:GetOptions()
		return table.clone(values)
	end

	function element:SetOptions(newOptions, keepCurrentValue)
		local previous = value
		rebuild(type(newOptions) == "table" and newOptions or {})
		if keepCurrentValue then
			setValue(previous, true)
		else
			setValue(values[1], true)
		end
		if open then
			if #entries == 0 then
				closeList()
			else
				updatePosition()
				tween(list, ANIM.Fast, {
					Size = UDim2.fromOffset(listWidth(), listHeight()),
				})
			end
		end
		return self
	end

	function element:Open()
		openList()
		return self
	end

	function element:Close()
		closeList()
		return self
	end

	function element:IsOpen()
		return open
	end

	return element
end

-- =====================================================================
-- multi dropdown
-- Keeps the popup open while options are toggled and returns a stable array.
-- Signature: MultiDropdown(text, options, defaults, callback, config)
-- config: { Max = number?, Placeholder = string? }
-- =====================================================================

function Container:MultiDropdown(text, options, defaults, callback, config)
	config = type(config) == "table" and config or {}
	local element, holder, registry = baseElement(self, "MultiDropdown")
	local window = self.window
	local maxSelected = tonumber(config.Max)
	local placeholder = tostring(config.Placeholder or "Select options")

	captionLine(holder, text, 1)

	local field = makeButton({
		Name = "Field",
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, METRICS.FieldHeight),
		Parent = holder,
	})
	corner(field, METRICS.SmallCorner)
	stroke(field, PALETTE.Border)
	pad(field, 0, 6, 0, 7)

	local valueLabel = makeText({
		Name = "Value",
		Size = UDim2.new(1, -14, 1, 0),
		Text = placeholder,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = field,
	})
	local chevron = makeChevron(field, 8, 0, 180)
	chevron.Instance.Position = UDim2.new(1, -7, 0.5, 0)
	chevron:SetColor(PALETTE.Muted)

	local blocker = makeButton({
		Name = "MultiDropdownBlocker",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 0,
		Parent = window._layers.popups,
	})
	registry:Add(blocker)

	local list = new("Frame", {
		Name = "MultiDropdownList",
		BackgroundColor3 = PALETTE.Popup,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(180, 0),
		Visible = false,
		ZIndex = 2,
		Parent = window._layers.popups,
	})
	list:SetAttribute("NebulaRole", "Popup")
	corner(list, METRICS.SmallCorner)
	stroke(list, PALETTE.Border)
	registry:Add(list)
	attachShadow(list, registry, {
		Layers = 4,
		Step = 2,
		Strength = 0.88,
		Corner = METRICS.SmallCorner,
	})

	local scroller = new("ScrollingFrame", {
		Name = "Options",
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = PALETTE.Knob,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
		Parent = list,
	})
	pad(scroller, 3, 3, 3, 3)
	vlist(scroller, 2)

	local values, entries, selected, order = {}, {}, {}, {}
	local open, follow = false, nil

	local function snapshot()
		return table.clone(order)
	end

	local function refreshSummary()
		if #order == 0 then
			valueLabel.Text = placeholder
			valueLabel.TextColor3 = PALETTE.Muted
		elseif #order <= 2 then
			valueLabel.Text = table.concat(order, ", ")
			valueLabel.TextColor3 = PALETTE.Text
		else
			valueLabel.Text = string.format("%d selected", #order)
			valueLabel.TextColor3 = PALETTE.Text
		end
		for _, entry in ipairs(entries) do
			local active = selected[entry.Value] == true
			-- Match Dropdown exactly: selected options are conveyed by brighter text
			-- only. No checkmark, accent, fill or changed row background.
			entry.Button.TextColor3 = active and PALETTE.Text or PALETTE.SubText
			entry.Button.BackgroundTransparency = 1
		end
	end

	window:BindAccent(registry, refreshSummary)

	local function emit(silent)
		refreshSummary()
		if not silent then
			invoke(callback, snapshot())
		end
		return snapshot()
	end

	local function setValues(newValues, silent)
		table.clear(selected)
		table.clear(order)
		if type(newValues) == "table" then
			for _, item in ipairs(newValues) do
				local value = tostring(item)
				if table.find(values, value) and not selected[value]
					and (not maxSelected or #order < maxSelected) then
					selected[value] = true
					table.insert(order, value)
				end
			end
		end
		return emit(silent)
	end

	local function toggleValue(value, silent)
		if selected[value] then
			selected[value] = nil
			local index = table.find(order, value)
			if index then table.remove(order, index) end
		elseif not maxSelected or #order < maxSelected then
			selected[value] = true
			table.insert(order, value)
		else
			return snapshot()
		end
		return emit(silent)
	end

	local function listHeight()
		return math.min(#entries * 34 + math.max(#entries - 1, 0) * 2 + 6, 264)
	end

	local function listWidth()
		local widest = 0
		for _, value in ipairs(values) do widest = math.max(widest, #value) end
		return math.floor(math.clamp(widest * METRICS.SmallTextSize * 0.68 + 48, 150, 320) + 0.5)
	end

	local function targetPosition()
		local layer = window._layers and window._layers.popups
		if not layer or not field.Parent then return nil, nil end
		local origin = field.AbsolutePosition - layer.AbsolutePosition
		local width, height = listWidth(), listHeight()
		local x = origin.X + math.floor(field.AbsoluteSize.X * 0.42)
		local y = origin.Y + math.floor(field.AbsoluteSize.Y * 0.5)
		if x + width > layer.AbsoluteSize.X - 6 then x = layer.AbsoluteSize.X - width - 6 end
		if y + height > layer.AbsoluteSize.Y - 6 and origin.Y - height + 4 >= 6 then
			y = origin.Y - height + 4
		end
		return math.floor(math.max(6, x) + 0.5), math.floor(math.max(6, y) + 0.5)
	end

	local function updatePosition()
		local x, y = targetPosition()
		if x then list.Position = UDim2.fromOffset(x, y) end
	end

	local function stopFollow()
		if follow then
			follow:Disconnect()
			registry:Remove(follow)
			follow = nil
		end
	end

	local function closeList()
		blocker.Visible = false
		if not open then return end
		open = false
		stopFollow()
		chevron:SetOpen(false, true)
		tween(list, ANIM.Fast, { Size = UDim2.fromOffset(math.floor(listWidth() * 0.9), 0), BackgroundTransparency = 0.3 })
		task.delay(ANIM.Fast + 0.02, function()
			if not open and list.Parent then list.Visible = false end
		end)
		window:ClearPopup(element)
	end

	local function openList()
		if open or #entries == 0 then return end
		open = true
		window:RegisterPopup(element)
		local width, height = listWidth(), listHeight()
		local x, y = targetPosition()
		x, y = x or 0, y or 0
		list.Visible, blocker.Visible = true, true
		list.Size = UDim2.fromOffset(math.floor(width * 0.9), math.floor(height * 0.5))
		list.Position = UDim2.fromOffset(x, y - 6)
		list.BackgroundTransparency = 0.3
		tween(list, ANIM.Submenu, { Size = UDim2.fromOffset(width, height), Position = UDim2.fromOffset(x, y), BackgroundTransparency = 0 })
		chevron:SetOpen(true, true)
		task.delay(ANIM.Submenu + 0.02, function()
			if open and not follow and list.Parent then
				follow = registry:Add(RunService.RenderStepped:Connect(updatePosition))
			end
		end)
	end

	local function rebuild(newOptions)
		for _, entry in ipairs(entries) do entry.Button:Destroy() end
		table.clear(entries)
		table.clear(values)
		for index, option in ipairs(newOptions) do
			local optionText = tostring(option)
			values[index] = optionText
			local button = makeButton({
				Name = "Option", BackgroundColor3 = PALETTE.Row,
				BackgroundTransparency = 1, LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 34), Text = optionText,
				TextColor3 = PALETTE.SubText, TextSize = METRICS.SmallTextSize,
				Parent = scroller,
			})
			corner(button, METRICS.SmallCorner)
			pad(button, 0, 6, 0, 7)
			registry:Add(button.MouseButton1Click:Connect(function()
				toggleValue(optionText, false) -- deliberately stays open
			end))
			registry:Add(button.MouseEnter:Connect(function()
				tween(button, ANIM.Fast, { TextColor3 = PALETTE.Text })
			end))
			registry:Add(button.MouseLeave:Connect(function()
				if not selected[optionText] then tween(button, ANIM.Fast, { TextColor3 = PALETTE.SubText }) end
			end))
			table.insert(entries, { Button = button, Value = optionText })
		end
		-- Drop selections that no longer exist.
		for index = #order, 1, -1 do
			if not table.find(values, order[index]) then
				selected[order[index]] = nil
				table.remove(order, index)
			end
		end
		refreshSummary()
	end

	field:SetAttribute("NebulaRole", "Field")
	field:SetAttribute("NebulaDepth", self:_depth())
	bindHover(field, registry, self:_fieldColor(), self:_fieldHover())
	registry:Add(field.MouseButton1Click:Connect(function()
		if open then closeList() else openList() end
	end))
	onRightClick(field, registry, function()
		if open then closeList() else openList() end
	end)
	registry:Add(blocker.MouseButton1Click:Connect(closeList))
	onRightClick(blocker, registry, closeList)
	registry:Add(function()
		open = false
		stopFollow()
		window:ClearPopup(element)
	end)

	rebuild(type(options) == "table" and options or {})
	setValues(type(defaults) == "table" and defaults or {}, true)

	element._tooltipTarget, element.Field, element.List = field, field, list
	function element:Get() return snapshot() end
	function element:Set(newValues, silent) return setValues(newValues, silent) end
	function element:Select(value, silent)
		value = tostring(value)
		if not selected[value] and table.find(values, value) then return toggleValue(value, silent) end
		return snapshot()
	end
	function element:Deselect(value, silent)
		value = tostring(value)
		if selected[value] then return toggleValue(value, silent) end
		return snapshot()
	end
	function element:Toggle(value, silent)
		value = tostring(value)
		if table.find(values, value) then return toggleValue(value, silent) end
		return snapshot()
	end
	function element:Clear(silent) return setValues({}, silent) end
	function element:GetOptions() return table.clone(values) end
	function element:SetOptions(newOptions, keepSelections)
		local previous = keepSelections and snapshot() or {}
		rebuild(type(newOptions) == "table" and newOptions or {})
		setValues(previous, true)
		if open then
			if #entries == 0 then
				closeList()
			else
				updatePosition()
				list.Size = UDim2.fromOffset(listWidth(), listHeight())
			end
		end
		return self
	end
	function element:Open()
		openList()
		return self
	end
	function element:Close()
		closeList()
		return self
	end
	function element:IsOpen()
		return open
	end

	return element
end

-- =====================================================================
-- slider
-- =====================================================================

function Container:Slider(text, minimum, maximum, default, step, callback, options)
	local element, holder, registry = baseElement(self, "Slider")
	local window = self.window
	options = type(options) == "table" and options or {}

	minimum = tonumber(minimum) or 0
	maximum = tonumber(maximum) or 100
	if maximum < minimum then
		minimum, maximum = maximum, minimum
	end
	step = math.abs(tonumber(step) or 1)

	local span = maximum - minimum
	local decimals = tonumber(options.Decimals) or decimalsOf(step)
	local suffix = tostring(options.Suffix or "")
	local value = math.clamp(tonumber(default) or minimum, minimum, maximum)

	local head = new("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, METRICS.LabelHeight),
		Parent = holder,
	})

	makeText({
		Name = "Caption",
		Size = UDim2.new(1, -62, 1, 0),
		Text = tostring(text or ""),
		TextColor3 = PALETTE.SubText,
		TextSize = METRICS.SmallTextSize,
		Parent = head,
	})

	local readout = makeText({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(60, METRICS.LabelHeight),
		Text = "",
		TextSize = METRICS.SmallTextSize,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = head,
	})

	-- The hit area stays invisible: it only exists to make the thin bar easy to
	-- grab. There is no highlight box — the slider is simply always visible.
	local track = makeButton({
		Name = "Track",
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = holder,
	})
	corner(track, METRICS.SmallCorner)

	-- the bar itself is invisible: only the accent fill, the knob and their
	-- shadows are drawn, which keeps the slider floating and clean
	local bar = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 6),
		Parent = track,
	})

	local fill = new("Frame", {
		Name = "Fill",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	})
	corner(fill, 3)

	-- the fill casts its own soft shadow, so the accent strip floats too
	local fillShadow = new("Frame", {
		Name = "FillShadow",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromScale(0, 1),
		ZIndex = 0,
		Parent = bar,
	})
	corner(fillShadow, 3)

	local knob = new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PALETTE.Text,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		ZIndex = 2,
		Parent = bar,
	})
	corner(knob, 7)

	-- a soft dark disc just under the knob lifts it off the bar; it travels
	-- with the knob exactly the way the glow stack does
	local knobShadow = new("Frame", {
		Name = "KnobShadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0.5, 2),
		Size = UDim2.fromOffset(18, 18),
		ZIndex = 1,
		Parent = bar,
	})
	corner(knobShadow, 8)

	-- Real glow, not one washed out ring: five progressively larger and fainter
	-- circles stacked behind the knob give a soft radial falloff, and the whole
	-- stack travels with the knob.
	local glow = new("Frame", {
		Name = "KnobGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		ZIndex = 1,
		Parent = bar,
	})

	local glowRings = {}
	for index = 1, 5 do
		local ringScale = (32 - (index - 1) * 4) / 32
		local ring = new("Frame", {
			Name = "Ring" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = PALETTE.Text,
			BackgroundTransparency = 0.94 - (index - 1) * 0.07,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			-- scaled, so the whole halo can swell with a single tween while held
			Size = UDim2.fromScale(ringScale, ringScale),
			ZIndex = index,
			Parent = glow,
		})
		corner(ring, 40)
		glowRings[index] = ring
	end

	window:BindAccent(registry, function(accent)
		fill.BackgroundColor3 = accent
		knob.BackgroundColor3 = accent
		for _, ring in ipairs(glowRings) do
			ring.BackgroundColor3 = accent
		end
	end)

	local function alphaOf(input)
		if span <= 0 then
			return 0
		end
		return math.clamp((input - minimum) / span, 0, 1)
	end

	local dragging = false

	local function applyVisual(smooth)
		local alpha = alphaOf(value)
		local knobPosition = UDim2.new(alpha, 0, 0.5, 0)
		local shadowPosition = UDim2.new(alpha, 0, 0.5, 2)
		-- a very short tween while dragging keeps the knob glued to the pointer
		-- but still glides instead of stepping frame to frame
		local duration = dragging and ANIM.Drag or ANIM.Fast
		readout.Text = formatNumber(value, decimals) .. suffix
		if smooth then
			tween(fill, duration, { Size = UDim2.fromScale(alpha, 1) })
			tween(fillShadow, duration, { Size = UDim2.fromScale(alpha, 1) })
			tween(knob, duration, { Position = knobPosition })
			tween(glow, duration, { Position = knobPosition })
			tween(knobShadow, duration, { Position = shadowPosition })
		else
			fill.Size = UDim2.fromScale(alpha, 1)
			fillShadow.Size = UDim2.fromScale(alpha, 1)
			knob.Position = knobPosition
			glow.Position = knobPosition
			knobShadow.Position = shadowPosition
		end
	end

	local function setValue(newValue, silent, smooth, onlyWhenChanged)
		local numeric = tonumber(newValue)
		if numeric == nil then
			return value
		end
		numeric = math.clamp(numeric, minimum, maximum)
		if step > 0 then
			numeric = math.clamp(minimum + snap(numeric - minimum, step), minimum, maximum)
		end
		if decimals > 0 then
			local scale = 10 ^ decimals
			numeric = math.floor(numeric * scale + 0.5) / scale
		end

		local changed = numeric ~= value
		value = numeric
		applyVisual(smooth)

		if not silent and (changed or not onlyWhenChanged) then
			invoke(callback, value)
		end
		return value
	end

	local function valueFromX(x)
		local width = track.AbsoluteSize.X
		if width <= 0 or span <= 0 then
			return value
		end
		return minimum + span * math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
	end

	local removeMove, removeEnd

	-- No highlight box and nothing hides: holding the knob only grows it a
	-- little and swells its halo, like the reference drag frame.
	local function applyHighlight()
		local knobSize = dragging and 16 or 14
		tween(knob, ANIM.Fast, { Size = UDim2.fromOffset(knobSize, knobSize) })
		local glowSize = dragging and 44 or 32
		tween(glow, ANIM.Fast, { Size = UDim2.fromOffset(glowSize, glowSize) })
	end

	local function stopDrag()
		dragging = false
		applyHighlight()
		if removeMove then
			removeMove()
			registry:Remove(removeMove)
			removeMove = nil
		end
		if removeEnd then
			removeEnd()
			registry:Remove(removeEnd)
			removeEnd = nil
		end
	end

	registry:Add(track.InputBegan:Connect(function(input)
		if dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		dragging = true
		applyHighlight()
		setValue(valueFromX(input.Position.X), false, true, true)

		removeMove = registry:Add(window:OnInputChanged(function(moveInput)
			if not dragging then
				return
			end
			if moveInput.UserInputType == Enum.UserInputType.MouseMovement
				or moveInput.UserInputType == Enum.UserInputType.Touch then
				setValue(valueFromX(moveInput.Position.X), false, true, true)
			end
		end))

		removeEnd = registry:Add(window:OnInputEnded(function(endInput)
			if endInput.UserInputType == Enum.UserInputType.MouseButton1
				or endInput.UserInputType == Enum.UserInputType.Touch then
				stopDrag()
			end
		end))
	end))

	registry:Add(stopDrag)
	applyVisual(false)

	element._tooltipTarget = track
	element.Track = track

	function element:Get()
		return value
	end

	function element:Set(newValue, silent)
		return setValue(newValue, silent, true, false)
	end

	function element:SetRange(newMinimum, newMaximum)
		minimum = tonumber(newMinimum) or minimum
		maximum = tonumber(newMaximum) or maximum
		if maximum < minimum then
			minimum, maximum = maximum, minimum
		end
		span = maximum - minimum
		setValue(value, true, false, false)
		return self
	end

	return element
end

-- =====================================================================
-- keybind
-- =====================================================================

function Container:Keybind(text, defaultKey, changedCallback, pressedCallback)
	local element, holder, registry = baseElement(self, "Keybind")
	local window = self.window

	local key = typeof(defaultKey) == "EnumItem" and defaultKey or nil
	local listening = false
	local swallowClick = false

	local row = rowShell(self, holder)
	bindHover(row, registry, row.BackgroundColor3, shade(row.BackgroundColor3, 0.08))

	makeText({
		Name = "Caption",
		Size = UDim2.new(1, -84, 1, 0),
		Text = tostring(text or ""),
		Parent = row,
	})

	local display = makeButton({
		Name = "Key",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = self:_fieldColor(),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(72, 24),
		Text = keyLabel(key),
		TextColor3 = PALETTE.SubText,
		TextSize = METRICS.SmallTextSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = row,
	})
	corner(display, METRICS.SmallCorner)
	stroke(display, PALETTE.BorderSoft)
	display:SetAttribute("NebulaRole", "Field")
	display:SetAttribute("NebulaDepth", self:_depth())

	local function refresh()
		display.Text = listening and "..." or keyLabel(key)
		display.TextColor3 = listening and window.Accent or PALETTE.SubText
		display.BackgroundColor3 = listening and self:_rowActive() or self:_fieldColor()
	end

	window:BindAccent(registry, function()
		refresh()
	end)

	local function setKey(newKey, silent)
		key = typeof(newKey) == "EnumItem" and newKey or nil
		refresh()
		if not silent then
			invoke(changedCallback, key)
		end
		return key
	end

	registry:Add(display.MouseButton1Click:Connect(function()
		if swallowClick then
			swallowClick = false
			return
		end
		listening = not listening
		refresh()
	end))

	registry:Add(window:OnInputBegan(function(input, processed)
		if listening then
			if input.KeyCode == Enum.KeyCode.Escape then
				listening = false
				setKey(nil, false)
				return
			end

			local candidate = keyFromInput(input)
			if candidate then
				listening = false
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					-- the release of this same click would otherwise re-arm listening
					swallowClick = true
				end
				setKey(candidate, false)
			end
			return
		end

		-- never fire the action for inputs the engine already consumed
		if processed or not key then
			return
		end
		if keyMatchesInput(key, input) then
			invoke(pressedCallback, key)
		end
	end))

	refresh()

	element._tooltipTarget = row
	element.Row = row
	element.Display = display

	function element:Get()
		return key
	end

	function element:Set(newKey, silent)
		listening = false
		return setKey(newKey, silent)
	end

	function element:IsListening()
		return listening
	end

	function element:StartListening()
		listening = true
		refresh()
		return self
	end

	return element
end

-- =====================================================================
-- textbox
-- =====================================================================

function Container:Textbox(text, default, placeholder, callback)
	local element, holder, registry = baseElement(self, "Textbox")
	local window = self.window

	captionLine(holder, text, 1)

	local box = makeBox({
		Name = "Field",
		LayoutOrder = 2,
		PlaceholderText = tostring(placeholder or ""),
		Size = UDim2.new(1, 0, 0, METRICS.FieldHeight),
		Text = tostring(default or ""),
		Parent = holder,
	})
	corner(box, METRICS.SmallCorner)
	local outline = stroke(box, PALETTE.Border)
	pad(box, 0, 6, 0, 7)
	box.BackgroundColor3 = self:_fieldColor()
	box:SetAttribute("NebulaRole", "Field")
	box:SetAttribute("NebulaDepth", self:_depth())

	local value = box.Text

	registry:Add(box.Focused:Connect(function()
		outline.Color = window.Accent
	end))

	-- callbacks fire on focus lost, never on every keystroke
	registry:Add(box.FocusLost:Connect(function(enterPressed)
		outline.Color = PALETTE.Border
		value = box.Text
		invoke(callback, value, enterPressed == true)
	end))

	element._tooltipTarget = box
	element.Field = box

	function element:Get()
		return value
	end

	function element:Set(newValue, silent)
		value = tostring(newValue or "")
		box.Text = value
		if not silent then
			invoke(callback, value, false)
		end
		return value
	end

	function element:SetPlaceholder(newPlaceholder)
		box.PlaceholderText = tostring(newPlaceholder or "")
		return self
	end

	return element
end

-- =====================================================================
-- colour field (hex text + live swatch)
-- =====================================================================

function Container:Color(text, defaultColor, defaultAlpha, callback, options)
	local element, holder, registry = baseElement(self, "Color")
	options = type(options) == "table" and options or {}

	local color = typeof(defaultColor) == "Color3" and defaultColor or Color3.fromRGB(255, 255, 255)
	local alpha = math.clamp(tonumber(defaultAlpha) or 1, 0, 1)

	captionLine(holder, text, 1)

	local swatch = makeBox({
		Name = "Swatch",
		BackgroundColor3 = color,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, METRICS.FieldHeight),
		Text = colorToHex(color, alpha),
		TextSize = METRICS.SmallTextSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = holder,
	})
	corner(swatch, METRICS.SmallCorner)
	stroke(swatch, PALETTE.Border)

	local function applyVisual()
		local ink = readableOn(color)
		swatch.BackgroundColor3 = color
		-- hint at alpha without hurting legibility
		swatch.BackgroundTransparency = (1 - alpha) * 0.55
		swatch.Text = colorToHex(color, alpha)
		swatch.TextColor3 = ink
		swatch.PlaceholderColor3 = ink
	end

	local function setColor(newColor, newAlpha, silent)
		if typeof(newColor) == "Color3" then
			color = newColor
		end
		local numeric = tonumber(newAlpha)
		if numeric then
			alpha = math.clamp(numeric, 0, 1)
		end
		applyVisual()
		if not silent then
			invoke(callback, color, alpha)
		end
		return color, alpha
	end

	registry:Add(swatch.FocusLost:Connect(function()
		local parsed, parsedAlpha = parseHex(swatch.Text)
		if parsed then
			setColor(parsed, parsedAlpha, false)
		else
			-- invalid text reverts to the last valid value
			applyVisual()
		end
	end))

	applyVisual()

	-- FollowAccent pins the field to the window accent, so it visibly tracks
	-- the active theme (it stays silent, so no callback loops back)
	if options.FollowAccent then
		self.window:BindAccent(registry, function(accent)
			setColor(accent, nil, true)
		end)
	end

	element._tooltipTarget = swatch
	element.Field = swatch

	function element:Get()
		return color
	end

	function element:GetAlpha()
		return alpha
	end

	function element:GetHex()
		return colorToHex(color, alpha)
	end

	function element:Set(newColor, newAlpha, silent)
		return setColor(newColor, newAlpha, silent)
	end

	return element
end

-- =====================================================================
-- optional demo: six compact settings panels in the reference layout
-- =====================================================================

function NebulaUI:Demo()
	local window = self:CreateWindow({
		Title = "Nebula",
		Subtitle = "Settings",
		Accent = Color3.fromRGB(214, 214, 255),
		StartPosition = UDim2.fromOffset(26, 40),
		ToggleKey = Enum.KeyCode.RightShift,
	})

	-- A panel is a list of features. A feature is a chevron row that opens its
	-- own settings block, and any row inside that block can open another block,
	-- which is why `feature` works on panels and submenus alike.
	local function feature(container, name, build)
		-- a plain left click switches the feature on: its label lights from grey
		-- to white and the panel header counts it. The chevron opens the block.
		local row = container:Feature(name, false, function(on)
			window:Notify({
				Title = name,
				Content = on and "Enabled" or "Disabled",
				Duration = 2.5,
			})
		end)
		local menu = row:Submenu()
		if build then
			build(menu)
		end
		return row, menu
	end

	local general = window:CreatePanel({ Title = "General" })
	feature(general, "Auto Save", function(menu)
		menu:Dropdown("Trigger", { "On change", "Timer", "Manual" }, "Timer")
		menu:Slider("Interval", 5, 300, 60, 5, nil, { Suffix = " s" })
		-- a block inside a block: flips back to the near-black layer
		feature(menu, "Backups", function(nested)
			nested:Toggle("Keep backups", true)
			nested:Slider("Keep count", 1, 20, 5, 1)
			nested:Dropdown("On failure", { "Retry", "Skip", "Notify" }, "Retry")
		end)
	end)
	feature(general, "Startup", function(menu)
		menu:Toggle("Restore last session", true)
		menu:Dropdown("Open on launch", { "Home", "Last page", "Blank" }, "Home")
		menu:Keybind("Quick open", Enum.KeyCode.F1)
	end)
	feature(general, "Language", function(menu)
		menu:Dropdown("Display", { "English", "Deutsch", "Espanol", "Francais" }, "English")
		menu:Toggle("Use system locale", true)
	end)
	feature(general, "Updates", function(menu)
		menu:Toggle("Check automatically", true)
		menu:Dropdown("Channel", { "Stable", "Beta" }, "Stable")
		menu:Button("Check now", function()
			print("[Nebula] Checking for updates")
		end)
	end)
	feature(general, "Session", function(menu)
		menu:Label("Everything here stays local to this session.")
		menu:Toggle("Remember panel layout", true)
	end)

	local interface = window:CreatePanel({ Title = "Interface", Subtitle = "Layout" })
	feature(interface, "Panels", function(menu)
		menu:Slider("Width", 170, 320, 218, 2, nil, { Suffix = " px" })
		menu:Slider("Gap", 4, 24, 10, 1, nil, { Suffix = " px" })
		menu:Toggle("Snap to edges", true)
	end)
	feature(interface, "Rows", function(menu)
		menu:Slider("Height", 24, 40, 32, 1, nil, { Suffix = " px" })
		menu:Dropdown("Text size", { "Small", "Medium", "Large" }, "Medium")
		feature(menu, "Density", function(nested)
			nested:Toggle("Tight spacing", false)
			nested:Slider("Row gap", 0, 10, 4, 1, nil, { Suffix = " px" })
		end)
	end)
	feature(interface, "Tooltips", function(menu)
		menu:Toggle("Show tooltips", true)
		menu:Slider("Delay", 0, 1000, 250, 50, nil, { Suffix = " ms" })
	end)
	feature(interface, "Animations", function(menu)
		menu:Toggle("Enabled", true)
		menu:Slider("Speed", 0.5, 2, 1, 0.1, nil, { Suffix = "x" })
	end)
	interface:Divider()
	interface:Keybind("Open UI", Enum.KeyCode.RightShift, function(newKey)
		window:SetToggleKey(newKey)
	end)

	local visuals = window:CreatePanel({ Title = "Visuals", Subtitle = "Style" })
	local highlights = visuals:Toggle("Highlights", true)
	local highlightMenu = highlights:Submenu()
	highlightMenu:Slider("Opacity", 0, 100, 60, 5, nil, { Suffix = "%" })
	highlightMenu:Color("Tint", Color3.fromRGB(214, 214, 255), 0.8)
	feature(highlightMenu, "Edges", function(nested)
		nested:Toggle("Soft edges", true)
		nested:Slider("Thickness", 1, 6, 2, 1, nil, { Suffix = " px" })
	end)
	feature(visuals, "Overlay", function(menu)
		menu:Dropdown("Corner", { "Top left", "Top right", "Bottom left", "Bottom right" }, "Top left")
		menu:Toggle("Show clock", false)
		menu:Toggle("Show frame rate", true)
	end)
	feature(visuals, "Grid", function(menu)
		menu:Toggle("Visible", false)
		menu:Slider("Cell size", 4, 64, 16, 4, nil, { Suffix = " px" })
	end)
	feature(visuals, "Preview", function(menu)
		menu:Label("Preview uses the current theme only.")
		menu:Button("Refresh preview", function()
			print("[Nebula] Preview refreshed")
		end)
	end)

	-- dense feature list, closest to the reference "Misc" panel
	local misc = window:CreatePanel({ Title = "Misc", Subtitle = "Everything else" })
	feature(misc, "Audio", function(menu)
		menu:Toggle("Enabled", true)
		menu:Slider("Volume", 0, 100, 70, 5, nil, { Suffix = "%" })
	end)
	feature(misc, "Camera", function(menu)
		menu:Slider("Field of view", 60, 120, 90, 1)
		menu:Toggle("Smooth follow", true)
	end)
	feature(misc, "Clipboard", function(menu)
		menu:Toggle("Track history", false)
		menu:Slider("History size", 1, 50, 10, 1, nil, { Suffix = " items" })
	end)
	feature(misc, "Downloads", function(menu)
		menu:Textbox("Folder", "Downloads", "Folder name")
		menu:Toggle("Ask every time", false)
	end)
	feature(misc, "Hotkeys", function(menu)
		menu:Keybind("Toggle overlay", Enum.KeyCode.F2)
		menu:Keybind("Reload", Enum.KeyCode.F5)
		feature(menu, "Advanced", function(nested)
			nested:Toggle("Allow mouse buttons", true)
			nested:Dropdown("Conflict", { "Warn", "Replace", "Ignore" }, "Warn")
		end)
	end)
	feature(misc, "Notifications", function(menu)
		menu:Toggle("Enabled", true)
		menu:Dropdown("Position", { "Top right", "Bottom right", "Bottom left" }, "Top right")
		menu:Slider("Duration", 1, 10, 4, 1, nil, { Suffix = " s" })
	end)
	feature(misc, "Privacy", function(menu)
		menu:Toggle("Hide names", false)
		menu:Toggle("Blur previews", false)
	end)
	feature(misc, "Search", function(menu)
		menu:Toggle("Fuzzy matching", true)
		menu:Slider("Results", 5, 50, 20, 5)
	end)
	feature(misc, "Sync", function(menu)
		menu:Toggle("Enabled", false)
		menu:Dropdown("Frequency", { "Live", "Hourly", "Daily" }, "Hourly")
	end)

	local menuPanel = window:CreatePanel({ Title = "Menu", Subtitle = "Appearance" })
	local accentLabel = menuPanel:Label("This label and the accent field follow the theme")
	local demoTheme = menuPanel:Dropdown("Theme", {
		"Phantom", "Casual", "Midnight", "Crimson", "Kyoto",
		"Emerald", "Violet", "Ocean", "Amber", "Mono",
	}, "Phantom", function(themeName)
		window:SetTheme(themeName)
		print("[Nebula] Theme:", themeName)
	end)
	local demoArrayList = menuPanel:Toggle("Array List", true, function(on)
		window:SetModuleListVisible(on)
	end)
	local demoArrayListMenu = demoArrayList:Submenu()
	local demoArrayListBar = demoArrayListMenu:Toggle("Array List Bar", true, function(on)
		window:SetModuleListBarVisible(on)
	end)
	local demoArrayListGlow = demoArrayListMenu:Toggle("Glow", true, function(on)
		window:SetModuleListGlowEnabled(on)
	end)
	local demoArrayListBlur = demoArrayListMenu:Toggle("Background Blur", true, function(on)
		window:SetModuleListBlurEnabled(on)
	end)
	menuPanel:Color("Main accent", Color3.fromRGB(214, 214, 255), 1, function(color)
		window:SetAccent(color)
	end, { FollowAccent = true })
	menuPanel:Color("Scroll accent", Color3.fromRGB(224, 224, 235), 1)

	-- the accent label tracks the active theme
	window:BindAccent(nil, function(accent)
		accentLabel.TextLabel.TextColor3 = accent
	end)

	menuPanel:Button("Test notification", function()
		window:Notify({
			Title = "Nebula",
			Content = "Notifications are themed and expire on their own.",
			Duration = 4,
		})
	end)
	menuPanel:Keybind("Menu key", Enum.KeyCode.LeftShift, function(newKey)
		window:SetToggleKey(newKey)
	end)
	menuPanel:Toggle("Compact rows", false)
	menuPanel:Warning("Layout changes apply to this session only!")
	menuPanel:Button("Hide interface", function()
		window:ToggleVisible()
	end)

	local configs = window:CreatePanel({ Title = "Configs", Subtitle = "Profiles" })
	local demoProfiles = {}
	configs:Button("Refresh list", function()
		print("[Nebula] Config list refreshed")
	end)
	local profile = configs:Dropdown("Profile", { "default", "compact", "verbose" }, "default")
	configs:Textbox("Name", "default", "Enter a name", function(text)
		print("[Nebula] Config name:", text)
	end)
	configs:Buttons({
		{ "Load", function()
			local name = profile:Get()
			local saved = demoProfiles[name]
			if not saved then
				warn("[Nebula] No saved profile:", name)
				return
			end
			demoTheme:Set(saved.Theme)
			demoArrayList:Set(saved.ArrayList)
			demoArrayListBar:Set(saved.ArrayListBar)
			demoArrayListGlow:Set(saved.ArrayListGlow)
			demoArrayListBlur:Set(saved.ArrayListBlur)
			print("[Nebula] Loaded", name)
		end },
		{ "Save", function()
			local name = profile:Get()
			demoProfiles[name] = {
				Theme = demoTheme:Get(),
				ArrayList = demoArrayList:Get(),
				ArrayListBar = demoArrayListBar:Get(),
				ArrayListGlow = demoArrayListGlow:Get(),
				ArrayListBlur = demoArrayListBlur:Get(),
			}
			print("[Nebula] Saved", name)
		end },
		{ "Delete", function()
			local name = profile:Get()
			demoProfiles[name] = nil
			print("[Nebula] Deleted", name)
		end },
	})
	configs:Divider()
	configs:Toggle("Autosave on exit", true)
	configs:Button("Unload", function()
		window:Destroy()
	end)

	return window
end

NebulaUI.Themes = THEMES

return NebulaUI
