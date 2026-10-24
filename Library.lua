--[[
	Moonlight.luau — a modern dark UI library for Roblox
	ModuleScript · put it in ReplicatedStorage and require it from a LocalScript.

	Icons are Lucide (https://lucide.dev, ISC licence), fetched at runtime through
	the Iconify API and loaded with getcustomasset (executor only). Any element that
	takes `Icon` also accepts a raw "rbxassetid://123" string or a number.

	Quick start:
		local Moonlight = require(game.ReplicatedStorage.Moonlight)
		local Window = Moonlight:CreateWindow({ Title = "Moonlight", Version = "v1.0.0" })
		local Combat = Window:AddTab({ Name = "Combat", Icon = "crosshair" })
		local Aim = Combat:AddSection({ Name = "Aim", Icon = "crosshair", Side = "Left" })
		Aim:AddToggle({ Name = "Enabled", Flag = "AimEnabled", Callback = print })
		Window:BuildSettings() -- the Settings tab from the reference design
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Moonlight = {}
Moonlight.Version = "1.0.0"
Moonlight.Flags = {} -- [flag] = current value
Moonlight.Options = {} -- [flag] = element object (has :Set / :Get)

--------------------------------------------------------------------------
-- Icons (Lucide, loaded dynamically via Iconify + getcustomasset)
--------------------------------------------------------------------------
Moonlight.IconNames = {
	"moon-star", "crosshair", "monitor", "folder-open", "settings",
	"search", "palette", "contrast", "scan", "app-window",
	"chevron-down", "check", "eye", "layout-dashboard", "history",
	"keyboard", "bell", "x", "user", "sparkles",
}

-- Filled by Moonlight:LoadIcons(); values become "rbxasset://" paths
Moonlight.Icons = {}

local ICON_SIZE = 64
local ICON_FOLDER = "MoonlightIcons"

local function HasExecutorAssetAPI()
	return type(getcustomasset) == "function"
		and type(writefile) == "function"
		and type(isfile) == "function"
		and type(makefolder) == "function"
end

function Moonlight:LoadIcons()
	if self._iconsLoaded then
		return true
	end
	if not HasExecutorAssetAPI() then
		warn("[Moonlight] getcustomasset/writefile not found; Lucide icons will not load.")
		return false
	end

	pcall(makefolder, ICON_FOLDER)

	for _, name in ipairs(self.IconNames) do
		local path = ICON_FOLDER .. "/" .. name .. ".png"

		if not isfile(path) then
			-- Iconify returns a white PNG on a transparent background.
			local url = string.format(
				"https://api.iconify.design/lucide/%s.png?width=%d&height=%d&color=white",
				name, ICON_SIZE, ICON_SIZE
			)
			local ok, data = pcall(function()
				return game:HttpGet(url)
			end)
			if ok and type(data) == "string" and #data > 0 then
				pcall(writefile, path, data)
			else
				warn("[Moonlight] failed to fetch icon: " .. name)
			end
		end

		if isfile(path) then
			local ok, asset = pcall(getcustomasset, path)
			if ok then
				self.Icons[name] = asset
			end
		end
	end

	self._iconsLoaded = true
	return true
end

--------------------------------------------------------------------------
-- Fonts & themes
--------------------------------------------------------------------------
local FONT_FAMILY = "rbxasset://fonts/families/BuilderSans.json"
local Fonts = {
	Regular = Font.new(FONT_FAMILY, Enum.FontWeight.Regular),
	Medium = Font.new(FONT_FAMILY, Enum.FontWeight.Medium),
	SemiBold = Font.new(FONT_FAMILY, Enum.FontWeight.SemiBold),
	Bold = Font.new(FONT_FAMILY, Enum.FontWeight.Bold),
}
Moonlight.Fonts = Fonts

local rgb = Color3.fromRGB
Moonlight.Themes = {
	Midnight = {
		Background = rgb(19, 21, 24),
		BackgroundEnd = rgb(25, 27, 31),
		Stroke = rgb(37, 40, 45),
		TabActive = rgb(34, 37, 42),
		Section = rgb(24, 26, 30),
		Element = rgb(31, 34, 38),
		ElementHover = rgb(38, 41, 46),
		Divider = rgb(34, 37, 41),
		Text = rgb(230, 232, 236),
		TextDim = rgb(128, 133, 142),
		TextMuted = rgb(84, 89, 98),
		Track = rgb(38, 41, 46),
		Knob = rgb(112, 117, 126),
		SubTabActive = rgb(43, 48, 57),
		SubTabIdle = rgb(28, 31, 35),
		Accent = rgb(138, 148, 166),
	},
	Obsidian = {
		Background = rgb(11, 11, 13),
		BackgroundEnd = rgb(16, 16, 19),
		Stroke = rgb(30, 30, 35),
		TabActive = rgb(27, 27, 32),
		Section = rgb(17, 17, 20),
		Element = rgb(24, 24, 28),
		ElementHover = rgb(31, 31, 36),
		Divider = rgb(27, 27, 31),
		Text = rgb(236, 236, 240),
		TextDim = rgb(122, 122, 132),
		TextMuted = rgb(78, 78, 88),
		Track = rgb(31, 31, 36),
		Knob = rgb(105, 105, 115),
		SubTabActive = rgb(38, 38, 45),
		SubTabIdle = rgb(22, 22, 26),
		Accent = rgb(160, 160, 175),
	},
	Moonlit = {
		Background = rgb(14, 18, 28),
		BackgroundEnd = rgb(19, 24, 36),
		Stroke = rgb(32, 40, 58),
		TabActive = rgb(30, 37, 54),
		Section = rgb(19, 24, 36),
		Element = rgb(26, 32, 47),
		ElementHover = rgb(33, 40, 57),
		Divider = rgb(29, 36, 52),
		Text = rgb(226, 232, 245),
		TextDim = rgb(120, 133, 160),
		TextMuted = rgb(78, 90, 115),
		Track = rgb(33, 40, 57),
		Knob = rgb(108, 121, 148),
		SubTabActive = rgb(39, 49, 72),
		SubTabIdle = rgb(23, 29, 43),
		Accent = rgb(122, 162, 247),
	},
	Dusk = {
		Background = rgb(20, 17, 26),
		BackgroundEnd = rgb(27, 22, 34),
		Stroke = rgb(42, 35, 54),
		TabActive = rgb(38, 31, 48),
		Section = rgb(26, 21, 33),
		Element = rgb(34, 28, 43),
		ElementHover = rgb(42, 35, 52),
		Divider = rgb(37, 31, 47),
		Text = rgb(236, 230, 244),
		TextDim = rgb(138, 126, 156),
		TextMuted = rgb(92, 82, 108),
		Track = rgb(42, 35, 52),
		Knob = rgb(122, 110, 140),
		SubTabActive = rgb(52, 42, 66),
		SubTabIdle = rgb(31, 25, 39),
		Accent = rgb(180, 142, 240),
	},
}
Moonlight.ThemeOrder = { "Midnight", "Obsidian", "Moonlit", "Dusk" }

--------------------------------------------------------------------------
-- Internal state
--------------------------------------------------------------------------
local Theme = table.clone(Moonlight.Themes.Midnight)
Moonlight.Theme = Theme
Moonlight.ThemeName = "Midnight"
Moonlight.FontScale = 1

local Themed = {} -- { inst, prop, key }
local ThemeHooks = {} -- functions re-run when theme/accent changes
local Texts = {} -- [TextObject] = base text size
local Connections = {}

local function Track(conn)
	table.insert(Connections, conn)
	return conn
end

local function Tween(obj, time, props, style)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function New(className, props, children)
	local inst = Instance.new(className)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		elseif k == "Theme" then
			for prop, key in pairs(v) do
				table.insert(Themed, { inst, prop, key })
				inst[prop] = Theme[key]
			end
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		Texts[inst] = inst.TextSize
		inst.TextSize = math.floor(inst.TextSize * Moonlight.FontScale + 0.5)
		inst.Destroying:Connect(function()
			Texts[inst] = nil
		end)
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function Corner(r)
	return New("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function Pad(l, r, t, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingRight = UDim.new(0, r or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingBottom = UDim.new(0, b or 0),
	})
end

local function List(dir, padding, halign, valign)
	return New("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
	})
end

local function ResolveIcon(icon)
	if icon == nil or icon == false then
		return nil
	end
	if typeof(icon) == "number" then
		return "rbxassetid://" .. icon
	end
	if typeof(icon) == "string" then
		if icon:find("^rbxasset") or icon:find("^http") then
			return icon
		end
		local id = Moonlight.Icons[icon]
		if id and id ~= "" and id ~= "rbxassetid://0" then
			return id
		end
	end
	return nil
end

local function Icon(icon, size, themeKey, props)
	local img = ResolveIcon(icon)
	local p = {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Image = img or "",
		Visible = img ~= nil,
		ScaleType = Enum.ScaleType.Fit,
		Theme = { ImageColor3 = themeKey or "Text" },
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return New("ImageLabel", p)
end

local function IsClick(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- Calls onMove(position) while the hitbox is being dragged.
local function Draggable(hitbox, onMove, onEnd)
	local dragging = false
	hitbox.InputBegan:Connect(function(input)
		if IsClick(input) then
			dragging = true
			onMove(input.Position)
		end
	end)
	Track(UserInputService.InputChanged:Connect(function(input)
		if dragging and IsMove(input) then
			onMove(input.Position)
		end
	end))
	Track(UserInputService.InputEnded:Connect(function(input)
		if dragging and IsClick(input) then
			dragging = false
			if onEnd then
				onEnd()
			end
		end
	end))
end

local function HoverTween(button, target, prop, idleKey, hoverKey)
	button.MouseEnter:Connect(function()
		Tween(target, 0.15, { [prop] = Theme[hoverKey] })
	end)
	button.MouseLeave:Connect(function()
		Tween(target, 0.15, { [prop] = Theme[idleKey] })
	end)
end

local function Round(n, step)
	step = step or 1
	return math.floor(n / step + 0.5) * step
end

local function SetFlag(flag, value, element)
	if flag then
		Moonlight.Flags[flag] = value
		Moonlight.Options[flag] = element
	end
end

local function SafeCall(fn, ...)
	if fn then
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Moonlight] callback error: " .. tostring(err))
		end
	end
end

--------------------------------------------------------------------------
-- Global setters
--------------------------------------------------------------------------
local function ApplyTheme(animated)
	for i = #Themed, 1, -1 do
		local entry = Themed[i]
		local inst, prop, key = entry[1], entry[2], entry[3]
		if animated and typeof(Theme[key]) == "Color3" and prop ~= "Color" then
			Tween(inst, 0.25, { [prop] = Theme[key] })
		else
			inst[prop] = Theme[key]
		end
	end
	for _, hook in ipairs(ThemeHooks) do
		SafeCall(hook, animated)
	end
end

function Moonlight:SetTheme(name)
	local preset = self.Themes[name]
	if not preset then
		return warn("[Moonlight] unknown theme: " .. tostring(name))
	end
	local accent = Theme.Accent
	local keepAccent = self._customAccent
	for k, v in pairs(preset) do
		Theme[k] = v
	end
	if keepAccent then
		Theme.Accent = accent
	end
	self.ThemeName = name
	ApplyTheme(true)
end

function Moonlight:SetAccent(color)
	Theme.Accent = color
	self._customAccent = true
	ApplyTheme(true)
end

function Moonlight:SetFontScale(scale)
	self.FontScale = scale
	for obj, base in pairs(Texts) do
		obj.TextSize = math.floor(base * scale + 0.5)
	end
end

function Moonlight:AddTheme(name, palette)
	self.Themes[name] = palette
	table.insert(self.ThemeOrder, name)
end

--------------------------------------------------------------------------
-- Config helpers (serialise flags → JSON-safe table; store with DataStore etc.)
--------------------------------------------------------------------------
function Moonlight:GetConfig()
	local out = {}
	for flag, value in pairs(self.Flags) do
		if typeof(value) == "Color3" then
			out[flag] = { __type = "Color3", hex = value:ToHex() }
		elseif typeof(value) == "EnumItem" then
			out[flag] = { __type = "KeyCode", name = value.Name }
		else
			out[flag] = value
		end
	end
	return out
end

function Moonlight:LoadConfig(config)
	for flag, value in pairs(config or {}) do
		local element = self.Options[flag]
		if element then
			if type(value) == "table" and value.__type == "Color3" then
				value = Color3.fromHex(value.hex)
			elseif type(value) == "table" and value.__type == "KeyCode" then
				value = Enum.KeyCode[value.name]
			end
			element:Set(value)
		end
	end
end

function Moonlight:EncodeConfig()
	return HttpService:JSONEncode(self:GetConfig())
end

function Moonlight:DecodeConfig(json)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	if ok then
		self:LoadConfig(data)
	end
	return ok
end

--------------------------------------------------------------------------
-- Section / elements
--------------------------------------------------------------------------
local Section = {}
Section.__index = Section

function Section:_row(height)
	self._order += 1
	local row = New("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 0),
		AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		LayoutOrder = self._order,
		Parent = self.Card,
	})
	local divider = New("Frame", {
		Name = "Divider",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 2,
		Theme = { BackgroundColor3 = "Divider" },
		Parent = row,
	})
	table.insert(self._rows, { Row = row, Divider = divider })
	self:_refreshDividers()
	return row
end

function Section:_refreshDividers()
	local first = true
	for _, r in ipairs(self._rows) do
		if r.Row.Visible then
			r.Divider.Visible = not first
			first = false
		end
	end
end

function Section:_register(element, name)
	element.Name = name
	table.insert(self.Elements, element)
	return element
end

local function RowLabel(parent, text, themeKey, props)
	local p = {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -90, 1, 0),
		FontFace = Fonts.Medium,
		Text = text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = themeKey or "TextDim" },
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return New("TextLabel", p)
end

-- Toggle ----------------------------------------------------------------
function Section:AddToggle(opts)
	opts = opts or {}
	local element = { Value = opts.Default == true, Type = "Toggle" }
	local row = self:_row(42)

	RowLabel(row, opts.Name or "Toggle", opts.LabelColor or "TextDim")

	local track = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(34, 20),
		Parent = row,
	}, { Corner(10) })
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		Parent = track,
	}, { Corner(5) })

	local button = New("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Parent = row,
	})

	local function render(animated)
		local t = animated and 0.2 or 0
		local on = element.Value
		Tween(track, t, { BackgroundColor3 = on and Theme.Accent or Theme.Track })
		Tween(knob, t, {
			Position = on and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 5, 0.5, 0),
			BackgroundColor3 = on and Theme.Text or Theme.Knob,
		})
	end
	table.insert(ThemeHooks, render)

	function element:Set(value, silent)
		element.Value = value == true
		SetFlag(opts.Flag, element.Value, element)
		render(true)
		if not silent then
			SafeCall(opts.Callback, element.Value)
		end
	end
	function element:Get()
		return element.Value
	end

	button.MouseButton1Click:Connect(function()
		element:Set(not element.Value)
	end)

	SetFlag(opts.Flag, element.Value, element)
	render(false)
	element.Row = row
	return self:_register(element, opts.Name)
end

-- Slider ----------------------------------------------------------------
function Section:AddSlider(opts)
	opts = opts or {}
	local min, max = opts.Min or 0, opts.Max or 100
	local step = opts.Increment or 1
	local suffix = opts.Suffix or ""
	local element = { Value = math.clamp(opts.Default or min, min, max), Type = "Slider" }
	local row = self:_row(40)

	RowLabel(row, opts.Name or "Slider", "TextDim", { Size = UDim2.new(1, -150, 1, 0) })

	local valueLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(44, 20),
		FontFace = Fonts.Medium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Theme = { TextColor3 = "Text" },
		Parent = row,
	})

	local track = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -56, 0.5, 0),
		Size = UDim2.fromOffset(72, 7),
		Theme = { BackgroundColor3 = "Track" },
		Parent = row,
	}, { Corner(3) })
	local fill = New("Frame", {
		Size = UDim2.fromScale(0, 1),
		Theme = { BackgroundColor3 = "Accent" },
		Parent = track,
	}, { Corner(3) })
	local hitbox = New("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 12, 0, 22),
		Text = "",
		Parent = track,
	})

	local function format(v)
		if opts.Format then
			return opts.Format(v)
		end
		local decimals = step < 1 and math.max(0, math.ceil(-math.log10(step))) or 0
		return string.format("%." .. decimals .. "f", v) .. suffix
	end

	local function render(animated)
		local alpha = (max == min) and 0 or (element.Value - min) / (max - min)
		Tween(fill, animated and 0.12 or 0, { Size = UDim2.fromScale(alpha, 1) })
		valueLabel.Text = format(element.Value)
	end

	function element:Set(value, silent)
		value = math.clamp(Round(tonumber(value) or min, step), min, max)
		local changed = value ~= element.Value
		element.Value = value
		SetFlag(opts.Flag, value, element)
		render(true)
		if changed and not silent then
			SafeCall(opts.Callback, value)
		end
	end
	function element:Get()
		return element.Value
	end

	Draggable(hitbox, function(pos)
		local alpha = math.clamp((pos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		element:Set(min + (max - min) * alpha)
	end)

	SetFlag(opts.Flag, element.Value, element)
	render(false)
	element.Row = row
	return self:_register(element, opts.Name)
end

-- Dropdown --------------------------------------------------------------
function Section:AddDropdown(opts)
	opts = opts or {}
	local multi = opts.Multi == true
	local element = { Options = opts.Options or {}, Type = "Dropdown", Open = false }
	if multi then
		element.Value = {}
		for _, v in ipairs(opts.Default or {}) do
			element.Value[v] = true
		end
	else
		element.Value = opts.Default or element.Options[1]
	end

	local row = self:_row(nil)
	local content = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = row,
	}, { List(nil, 6), Pad(0, 0, 10, 10) })

	New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		FontFace = Fonts.Medium,
		Text = opts.Name or "Dropdown",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Theme = { TextColor3 = "TextDim" },
		Parent = content,
	})

	local box = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = 2,
		Theme = { BackgroundColor3 = "Element" },
		Parent = content,
	}, { Corner(6) })
	HoverTween(box, box, "BackgroundColor3", "Element", "ElementHover")

	local valueLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -44, 1, 0),
		FontFace = Fonts.Medium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "Text" },
		Parent = box,
	})

	local chevronImg = ResolveIcon("chevron-down")
	local chevron
	if chevronImg then
		chevron = Icon("chevron-down", 16, "Text", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Parent = box,
		})
	else
		chevron = New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			FontFace = Fonts.Bold,
			Text = "⌄",
			TextSize = 16,
			Theme = { TextColor3 = "Text" },
			Parent = box,
		})
	end

	local listHolder = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Visible = false,
		LayoutOrder = 3,
		Theme = { BackgroundColor3 = "Element" },
		Parent = content,
	}, { Corner(6) })
	local scroller = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Theme = { ScrollBarImageColor3 = "TextMuted" },
		Parent = listHolder,
	}, { List(nil, 2), Pad(4, 4, 4, 4) })

	local optionButtons = {}

	local function isSelected(option)
		if multi then
			return element.Value[option] == true
		end
		return element.Value == option
	end

	local function displayText()
		if multi then
			local picked = {}
			for _, o in ipairs(element.Options) do
				if element.Value[o] then
					table.insert(picked, tostring(o))
				end
			end
			return #picked > 0 and table.concat(picked, ", ") or (opts.Placeholder or "None")
		end
		return element.Value ~= nil and tostring(element.Value) or (opts.Placeholder or "Select...")
	end

	local function renderOptions()
		valueLabel.Text = displayText()
		for option, btn in pairs(optionButtons) do
			local sel = isSelected(option)
			btn.TextColor3 = sel and Theme.Text or Theme.TextDim
			btn.BackgroundTransparency = sel and 0 or 1
			btn.BackgroundColor3 = Theme.ElementHover
		end
	end
	table.insert(ThemeHooks, renderOptions)

	local function listHeight()
		local count = math.min(#element.Options, opts.MaxVisible or 6)
		return count * 26 + (count - 1) * 2 + 8
	end

	local function setOpen(open)
		element.Open = open
		local rotation = open and 180 or 0
		Tween(chevron, 0.2, { Rotation = rotation })
		if open then
			listHolder.Visible = true
			listHolder.Size = UDim2.new(1, 0, 0, 0)
			Tween(listHolder, 0.22, { Size = UDim2.new(1, 0, 0, listHeight()) })
		else
			local t = Tween(listHolder, 0.18, { Size = UDim2.new(1, 0, 0, 0) })
			t.Completed:Connect(function()
				if not element.Open then
					listHolder.Visible = false
				end
			end)
		end
	end

	local function buildOptions()
		for _, btn in pairs(optionButtons) do
			btn:Destroy()
		end
		optionButtons = {}
		for i, option in ipairs(element.Options) do
			local btn = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 26),
				FontFace = Fonts.Medium,
				Text = tostring(option),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				LayoutOrder = i,
				Parent = scroller,
			}, { Corner(5), Pad(8, 8, 0, 0) })
			optionButtons[option] = btn
			btn.MouseButton1Click:Connect(function()
				if multi then
					element.Value[option] = not element.Value[option] or nil
					element:Set(element.Value)
				else
					element:Set(option)
					setOpen(false)
				end
			end)
		end
		renderOptions()
		if element.Open then
			listHolder.Size = UDim2.new(1, 0, 0, listHeight())
		end
	end

	function element:Set(value, silent)
		if multi then
			if type(value) == "table" then
				-- accept both {"A","B"} and {A=true}
				local set = {}
				for k, v in pairs(value) do
					if type(k) == "number" then
						set[v] = true
					elseif v then
						set[k] = true
					end
				end
				element.Value = set
			end
		else
			element.Value = value
		end
		SetFlag(opts.Flag, element.Value, element)
		renderOptions()
		if not silent then
			SafeCall(opts.Callback, element.Value)
		end
	end
	function element:Get()
		return element.Value
	end
	function element:SetOptions(list)
		element.Options = list
		buildOptions()
	end

	box.MouseButton1Click:Connect(function()
		setOpen(not element.Open)
	end)

	buildOptions()
	SetFlag(opts.Flag, element.Value, element)
	element.Row = row
	return self:_register(element, opts.Name)
end

-- Color picker ----------------------------------------------------------
function Section:AddColorPicker(opts)
	opts = opts or {}
	local element = { Value = opts.Default or Theme.Accent, Type = "ColorPicker", Open = false }
	local h, s, v = element.Value:ToHSV()

	local row = self:_row(nil)
	local content = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = row,
	}, { List(nil, 0), Pad(0, 0, 0, 0) })

	local head = New("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 42),
		Text = "",
		LayoutOrder = 1,
		Parent = content,
	})
	RowLabel(head, opts.Name or "Color", "Text")

	local swatch = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(18, 11),
		BackgroundColor3 = element.Value,
		Parent = head,
	}, { Corner(4) })
	New("UIStroke", {
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Theme = { Color = "Accent" },
		Parent = swatch,
	})

	local panel = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Visible = false,
		LayoutOrder = 2,
		Parent = content,
	})

	local sv = New("TextButton", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -26, 0, 110),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		Parent = panel,
	}, { Corner(6) })
	New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = sv,
	}, {
		Corner(6),
		New("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
	})
	New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Parent = sv,
	}, {
		Corner(6),
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }),
	})
	local svCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sv,
	}, { Corner(5), New("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }) })

	local hueKeys = {}
	for i = 0, 6 do
		table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1)))
	end
	local hue = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 14, 0, 110),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = panel,
	}, { Corner(5), New("UIGradient", { Rotation = 90, Color = ColorSequence.new(hueKeys) }) })
	local hueCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 4, 0, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = hue,
	}, { Corner(2) })

	local hexBox = New("TextBox", {
		Position = UDim2.fromOffset(0, 118),
		Size = UDim2.new(1, 0, 0, 28),
		FontFace = Fonts.Medium,
		TextSize = 12,
		ClearTextOnFocus = false,
		Text = "",
		Theme = { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "TextMuted" },
		Parent = panel,
	}, { Corner(6) })

	local function render()
		swatch.BackgroundColor3 = element.Value
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(0.5, h)
		hexBox.Text = "#" .. element.Value:ToHex():upper()
	end

	local function commit(silent)
		element.Value = Color3.fromHSV(h, s, v)
		SetFlag(opts.Flag, element.Value, element)
		render()
		if not silent then
			SafeCall(opts.Callback, element.Value)
		end
	end

	function element:Set(color, silent)
		if typeof(color) == "string" then
			local ok, c = pcall(Color3.fromHex, color)
			color = ok and c or element.Value
		end
		h, s, v = color:ToHSV()
		commit(silent)
	end
	function element:Get()
		return element.Value
	end

	Draggable(sv, function(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		commit()
	end)
	Draggable(hue, function(pos)
		h = math.clamp((pos.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 0.999)
		commit()
	end)
	hexBox.FocusLost:Connect(function()
		element:Set(hexBox.Text)
	end)

	head.MouseButton1Click:Connect(function()
		element.Open = not element.Open
		if element.Open then
			panel.Visible = true
			Tween(panel, 0.22, { Size = UDim2.new(1, 0, 0, 156) })
		else
			local t = Tween(panel, 0.18, { Size = UDim2.new(1, 0, 0, 0) })
			t.Completed:Connect(function()
				if not element.Open then
					panel.Visible = false
				end
			end)
		end
	end)

	SetFlag(opts.Flag, element.Value, element)
	render()
	element.Row = row
	return self:_register(element, opts.Name)
end

-- Button ----------------------------------------------------------------
function Section:AddButton(opts)
	opts = opts or {}
	local element = { Type = "Button" }
	local row = self:_row(48)
	local btn = New("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 32),
		FontFace = Fonts.Medium,
		Text = opts.Name or "Button",
		TextSize = 13,
		AutoButtonColor = false,
		Theme = { BackgroundColor3 = "Element", TextColor3 = "Text" },
		Parent = row,
	}, { Corner(6) })
	HoverTween(btn, btn, "BackgroundColor3", "Element", "ElementHover")
	btn.MouseButton1Down:Connect(function()
		Tween(btn, 0.1, { BackgroundColor3 = Theme.SubTabActive })
	end)
	btn.MouseButton1Up:Connect(function()
		Tween(btn, 0.15, { BackgroundColor3 = Theme.ElementHover })
	end)
	btn.MouseButton1Click:Connect(function()
		SafeCall(opts.Callback)
	end)
	function element:SetText(text)
		btn.Text = text
	end
	element.Row = row
	return self:_register(element, opts.Name)
end

-- Textbox ---------------------------------------------------------------
function Section:AddTextbox(opts)
	opts = opts or {}
	local element = { Value = opts.Default or "", Type = "Textbox" }
	local row = self:_row(44)
	RowLabel(row, opts.Name or "Textbox", "TextDim", { Size = UDim2.new(1, -160, 1, 0) })
	local box = New("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(150, 28),
		FontFace = Fonts.Medium,
		TextSize = 12,
		Text = element.Value,
		PlaceholderText = opts.Placeholder or "Type here...",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "TextMuted" },
		Parent = row,
	}, { Corner(6), Pad(10, 10, 0, 0) })

	function element:Set(value, silent)
		element.Value = tostring(value)
		box.Text = element.Value
		SetFlag(opts.Flag, element.Value, element)
		if not silent then
			SafeCall(opts.Callback, element.Value)
		end
	end
	function element:Get()
		return element.Value
	end
	box.FocusLost:Connect(function(enter)
		if opts.Numeric then
			box.Text = tostring(tonumber(box.Text) or element.Value)
		end
		element:Set(box.Text)
		if opts.ClearOnSubmit and enter then
			box.Text = ""
		end
	end)
	SetFlag(opts.Flag, element.Value, element)
	element.Row = row
	return self:_register(element, opts.Name)
end

-- Keybind ---------------------------------------------------------------
function Section:AddKeybind(opts)
	opts = opts or {}
	local element = { Value = opts.Default or Enum.KeyCode.Unknown, Type = "Keybind", Listening = false }
	local row = self:_row(42)
	RowLabel(row, opts.Name or "Keybind", "TextDim")

	local pill = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Fonts.Medium,
		TextSize = 12,
		AutoButtonColor = false,
		Theme = { BackgroundColor3 = "Element", TextColor3 = "TextDim" },
		Parent = row,
	}, { Corner(5), Pad(9, 9, 0, 0) })

	local function render()
		if element.Listening then
			pill.Text = "..."
		else
			pill.Text = element.Value == Enum.KeyCode.Unknown and "None" or element.Value.Name
		end
	end

	function element:Set(key, silent)
		element.Value = key or Enum.KeyCode.Unknown
		element.Listening = false
		SetFlag(opts.Flag, element.Value, element)
		render()
		if not silent then
			SafeCall(opts.Changed, element.Value)
		end
	end
	function element:Get()
		return element.Value
	end

	pill.MouseButton1Click:Connect(function()
		element.Listening = true
		Moonlight._listening = true
		render()
	end)

	Track(UserInputService.InputBegan:Connect(function(input, processed)
		if element.Listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local key = input.KeyCode
				if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace then
					key = Enum.KeyCode.Unknown
				end
				element:Set(key)
				task.defer(function()
					Moonlight._listening = false
				end)
			end
			return
		end
		if not processed and element.Value ~= Enum.KeyCode.Unknown and input.KeyCode == element.Value then
			SafeCall(opts.Callback, element.Value)
		end
	end))

	SetFlag(opts.Flag, element.Value, element)
	render()
	element.Row = row
	return self:_register(element, opts.Name)
end

-- Label / Paragraph -----------------------------------------------------
function Section:AddLabel(text)
	local element = { Type = "Label" }
	local row = self:_row(nil)
	local lbl = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Fonts.Medium,
		Text = text or "",
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Theme = { TextColor3 = "TextDim" },
		Parent = row,
	}, { Pad(0, 0, 12, 12) })
	function element:Set(t)
		lbl.Text = t
	end
	element.Row = row
	return self:_register(element, text)
end

function Section:AddParagraph(opts)
	opts = opts or {}
	local element = { Type = "Paragraph" }
	local row = self:_row(nil)
	local holder = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = row,
	}, { List(nil, 4), Pad(0, 0, 12, 12) })
	local title = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Fonts.SemiBold,
		Text = opts.Title or "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Theme = { TextColor3 = "Text" },
		Parent = holder,
	})
	local body = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Fonts.Regular,
		Text = opts.Content or "",
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Theme = { TextColor3 = "TextDim" },
		Parent = holder,
	})
	function element:Set(newTitle, newContent)
		title.Text = newTitle or title.Text
		body.Text = newContent or body.Text
	end
	element.Row = row
	return self:_register(element, opts.Title)
end

--------------------------------------------------------------------------
-- SubTab (pill row under the main tabs)
--------------------------------------------------------------------------
local SubTab = {}
SubTab.__index = SubTab

function SubTab:AddSection(opts)
	opts = opts or {}
	local side = (opts.Side == "Right" or opts.Side == 2) and self.Right or self.Left
	local column = side

	column._order = (column._order or 0) + 1
	local holder = New("Frame", {
		Name = opts.Name or "Section",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = column._order,
		Parent = column,
	}, { List(nil, 10) })

	local header = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = holder,
	})
	local headerIcon = Icon(opts.Icon, 14, "Text", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Parent = header,
	})
	New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(headerIcon.Visible and 28 or 6, 0),
		Size = UDim2.new(1, -28, 1, 0),
		FontFace = Fonts.Bold,
		Text = opts.Name or "Section",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Theme = { TextColor3 = "Text" },
		Parent = header,
	})

	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Theme = { BackgroundColor3 = "Section" },
		Parent = holder,
	}, { Corner(8), Pad(12, 12, 2, 2), List(nil, 0) })

	local section = setmetatable({
		Name = opts.Name,
		Holder = holder,
		Card = card,
		HeaderIcon = headerIcon,
		Elements = {},
		_rows = {},
		_order = 0,
	}, Section)
	table.insert(self.Sections, section)
	table.insert(self.Window._sectionIcons, headerIcon)
	return section
end

--------------------------------------------------------------------------
-- Tab
--------------------------------------------------------------------------
local Tab = {}
Tab.__index = Tab

local function MakeSubPage(tab, name)
	local page = New("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Theme = { ScrollBarImageColor3 = "TextMuted" },
		Parent = tab.SubPages,
	}, { Pad(27, 27, 2, 24) })
	local left = New("Frame", {
		Name = "Left",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, { List(nil, 16) })
	local right = New("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 6, 0, 0),
		Size = UDim2.new(0.5, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, { List(nil, 16) })
	return page, left, right
end

function Tab:AddSubTab(name)
	if self._implicit then
		error("[Moonlight] call AddSubTab before adding sections directly to the tab", 2)
	end
	self.SubTabBar.Visible = true
	self.SubPages.Position = UDim2.fromOffset(0, 50)
	self.SubPages.Size = UDim2.new(1, 0, 1, -50)

	local page, left, right = MakeSubPage(self, name)
	local button = New("TextButton", {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Fonts.Medium,
		Text = name,
		TextSize = 13,
		AutoButtonColor = false,
		LayoutOrder = #self.SubTabs + 1,
		Theme = { BackgroundColor3 = "SubTabIdle", TextColor3 = "TextDim" },
		Parent = self.SubTabBar,
	}, { Corner(6), Pad(13, 13, 0, 0) })

	local sub = setmetatable({
		Name = name,
		Tab = self,
		Window = self.Window,
		Page = page,
		Left = left,
		Right = right,
		Button = button,
		Sections = {},
	}, SubTab)
	table.insert(self.SubTabs, sub)

	button.MouseButton1Click:Connect(function()
		self:SelectSubTab(sub)
	end)
	if #self.SubTabs == 1 then
		self:SelectSubTab(sub)
	end
	return sub
end

function Tab:SelectSubTab(sub)
	if type(sub) == "string" then
		for _, s in ipairs(self.SubTabs) do
			if s.Name == sub then
				sub = s
				break
			end
		end
	end
	for _, s in ipairs(self.SubTabs) do
		local active = s == sub
		s.Page.Visible = active
		Tween(s.Button, 0.18, {
			BackgroundColor3 = active and Theme.SubTabActive or Theme.SubTabIdle,
			TextColor3 = active and Theme.Text or Theme.TextDim,
		})
	end
	self.ActiveSubTab = sub
	self.Window:_applySearch()
end

function Tab:AddSection(opts)
	if #self.SubTabs == 0 then
		self._implicit = true
		local page, left, right = MakeSubPage(self, "Main")
		local sub = setmetatable({
			Name = "Main",
			Tab = self,
			Window = self.Window,
			Page = page,
			Left = left,
			Right = right,
			Sections = {},
		}, SubTab)
		page.Visible = true
		table.insert(self.SubTabs, sub)
		self.ActiveSubTab = sub
	end
	if not self._implicit then
		return self.ActiveSubTab:AddSection(opts)
	end
	return self.SubTabs[1]:AddSection(opts)
end

--------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------
local Window = {}
Window.__index = Window

function Moonlight:CreateWindow(opts)
	opts = opts or {}
	if opts.Theme then
		self:SetTheme(opts.Theme)
	end

	local player = Players.LocalPlayer
	local gui = New("ScreenGui", {
		Name = "Moonlight",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		DisplayOrder = 10,
		Parent = opts.Parent or player:WaitForChild("PlayerGui"),
	})

	local size = opts.Size or UDim2.fromOffset(804, 581)
	local main = New("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = gui,
	}, { Corner(12) })
	local gradient = New("UIGradient", { Rotation = 115, Parent = main })
	New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Theme = { Color = "Stroke" }, Parent = main })
	local scale = New("UIScale", { Scale = 1, Parent = main })

	local function paintGradient()
		gradient.Color = ColorSequence.new(Theme.Background, Theme.BackgroundEnd)
	end
	paintGradient()
	table.insert(ThemeHooks, paintGradient)

	-- Top bar ---------------------------------------------------------
	local topbar = New("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 90),
		Parent = main,
	})

	-- Logo: Lucide "moon-star". Falls back to a drawn crescent until the id is set.
	local logo = Icon(opts.Logo or "moon-star", 26, "Text", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(45, 55),
		Parent = topbar,
	})
	if not logo.Visible then
		local moon = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(45, 55),
			Size = UDim2.fromOffset(22, 22),
			Theme = { BackgroundColor3 = "Text" },
			Parent = topbar,
		}, { Corner(11) })
		New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 6, 0.5, -5),
			Size = UDim2.fromOffset(18, 18),
			Theme = { BackgroundColor3 = "Background" },
			Parent = moon,
		}, { Corner(9) })
	end

	local tabBar = New("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(100, 39),
		Size = UDim2.new(0, 420, 0, 32),
		Parent = topbar,
	}, { List(Enum.FillDirection.Horizontal, 4, nil, Enum.VerticalAlignment.Center) })

	-- Search
	local search = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(540, 40),
		Size = UDim2.fromOffset(170, 30),
		Parent = topbar,
	})
	local searchIcon = Icon("search", 15, "Text", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
		Parent = search,
	})
	if not searchIcon.Visible then
		New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			FontFace = Fonts.Bold,
			Text = "⌕",
			TextSize = 18,
			Theme = { TextColor3 = "Text" },
			Parent = search,
		})
	end
	New("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 32, 0.5, 0),
		Size = UDim2.fromOffset(1, 11),
		Theme = { BackgroundColor3 = "TextMuted" },
		Parent = search,
	})
	local searchBox = New("TextBox", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(43, 0),
		Size = UDim2.new(1, -43, 1, 0),
		FontFace = Fonts.Medium,
		PlaceholderText = "Search",
		Text = "",
		TextSize = 12,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "TextMuted" },
		Parent = search,
	})

	New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -32, 0, 55),
		Size = UDim2.fromOffset(80, 16),
		FontFace = Fonts.Medium,
		Text = opts.Version or ("v" .. Moonlight.Version),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Theme = { TextColor3 = "TextMuted" },
		Parent = topbar,
	})

	local pages = New("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 1, -90),
		Parent = main,
	})

	-- Notifications + watermark live outside Main so they show while hidden
	local notifyHolder = New("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 280, 1, -32),
		Parent = gui,
	}, { List(nil, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom) })

	local self = setmetatable({
		Gui = gui,
		Main = main,
		Scale = scale,
		Pages = pages,
		TabBar = tabBar,
		SearchBox = searchBox,
		Tabs = {},
		Visible = true,
		ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift,
		Opacity = 1,
		UserScale = 1,
		_tabIcons = {},
		_sectionIcons = {},
		_notifyHolder = notifyHolder,
		_opts = opts,
	}, Window)

	-- Dragging --------------------------------------------------------
	do
		local dragging, dragStart, startPos = false, nil, nil
		topbar.InputBegan:Connect(function(input)
			if IsClick(input) then
				dragging = true
				dragStart = input.Position
				startPos = main.Position
			end
		end)
		Track(UserInputService.InputChanged:Connect(function(input)
			if dragging and IsMove(input) then
				local delta = input.Position - dragStart
				main.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end))
		Track(UserInputService.InputEnded:Connect(function(input)
			if IsClick(input) then
				dragging = false
			end
		end))
	end

	-- keep active tab / sub-tab highlights correct after a theme change
	table.insert(ThemeHooks, function()
		self:_paintTabs(false)
		for _, t in ipairs(self.Tabs) do
			if t.ActiveSubTab and t.SubTabBar.Visible then
				t:SelectSubTab(t.ActiveSubTab)
			end
		end
	end)

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self:_applySearch()
	end)

	Track(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or Moonlight._listening then
			return
		end
		if input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end))

	if opts.MobileButton ~= false and UserInputService.TouchEnabled then
		self:_makeMobileButton()
	end

	return self
end

function Window:_makeMobileButton()
	local btn = New("TextButton", {
		Name = "MobileToggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		Text = "",
		AutoButtonColor = false,
		Theme = { BackgroundColor3 = "Section" },
		Parent = self.Gui,
	}, { Corner(22) })
	New("UIStroke", { Theme = { Color = "Stroke" }, Parent = btn })
	local img = Icon("moon-star", 22, "Text", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = btn,
	})
	if not img.Visible then
		New("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			FontFace = Fonts.Bold,
			Text = "☾",
			TextSize = 22,
			Theme = { TextColor3 = "Text" },
			Parent = btn,
		})
	end
	btn.MouseButton1Click:Connect(function()
		self:Toggle()
	end)
end

function Window:AddTab(opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	local button = New("TextButton", {
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		LayoutOrder = #self.Tabs + 1,
		Theme = { BackgroundColor3 = "TabActive" },
		Parent = self.TabBar,
	}, {
		Corner(8),
		Pad(15, 15, 0, 0),
		List(Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Center),
	})
	local icon = Icon(opts.Icon, 16, "TextDim", { LayoutOrder = 1, Parent = button })
	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Fonts.Medium,
		Text = opts.Name or "Tab",
		TextSize = 14,
		LayoutOrder = 2,
		Theme = { TextColor3 = "TextDim" },
		Parent = button,
	})
	table.insert(self._tabIcons, icon)

	local page = New("Frame", {
		Name = opts.Name or "Tab",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = self.Pages,
	})
	local subBar = New("Frame", {
		Name = "SubTabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(27, 13),
		Size = UDim2.new(1, -54, 0, 24),
		Visible = false,
		Parent = page,
	}, { List(Enum.FillDirection.Horizontal, 6) })
	local subPages = New("Frame", {
		Name = "SubPages",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 1, -10),
		Parent = page,
	})

	local tab = setmetatable({
		Name = opts.Name,
		Window = self,
		Button = button,
		Icon = icon,
		Label = label,
		Page = page,
		SubTabBar = subBar,
		SubPages = subPages,
		SubTabs = {},
	}, Tab)
	table.insert(self.Tabs, tab)

	button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)
	button.MouseEnter:Connect(function()
		if self.ActiveTab ~= tab then
			Tween(label, 0.15, { TextColor3 = Theme.Text })
		end
	end)
	button.MouseLeave:Connect(function()
		if self.ActiveTab ~= tab then
			Tween(label, 0.15, { TextColor3 = Theme.TextDim })
		end
	end)

	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	if type(tab) == "string" then
		for _, t in ipairs(self.Tabs) do
			if t.Name == tab then
				tab = t
				break
			end
		end
	end
	self.ActiveTab = tab
	self:_paintTabs(true)
	self:_applySearch()
end

function Window:_paintTabs(animated)
	local t = animated and 0.18 or 0
	for _, tb in ipairs(self.Tabs) do
		local active = tb == self.ActiveTab
		tb.Page.Visible = active
		Tween(tb.Button, t, { BackgroundTransparency = active and 0 or 1 })
		Tween(tb.Label, t, { TextColor3 = active and Theme.Text or Theme.TextDim })
		Tween(tb.Icon, t, { ImageColor3 = active and Theme.Text or Theme.TextDim })
	end
end

function Window:_applySearch()
	if not self.SearchBox then
		return
	end
	local query = self.SearchBox.Text:lower()
	local tab = self.ActiveTab
	if not tab then
		return
	end
	for _, sub in ipairs(tab.SubTabs) do
		for _, section in ipairs(sub.Sections) do
			local sectionMatch = query == "" or (section.Name or ""):lower():find(query, 1, true) ~= nil
			local any = false
			for _, el in ipairs(section.Elements) do
				local match = sectionMatch or (el.Name or ""):lower():find(query, 1, true) ~= nil
				el.Row.Visible = match
				any = any or match
			end
			section.Holder.Visible = any or sectionMatch or #section.Elements == 0 and query == ""
			section:_refreshDividers()
		end
	end
end

function Window:Toggle(state)
	if state == nil then
		state = not self.Visible
	end
	self.Visible = state
	if state then
		self.Main.Visible = true
		self.Scale.Scale = self.UserScale * 0.96
		Tween(self.Scale, 0.25, { Scale = self.UserScale }, Enum.EasingStyle.Back)
	else
		local t = Tween(self.Scale, 0.15, { Scale = self.UserScale * 0.96 })
		t.Completed:Connect(function()
			if not self.Visible then
				self.Main.Visible = false
			end
		end)
	end
end

function Window:SetScale(scale)
	self.UserScale = scale
	self.Scale.Scale = scale
end

-- 1 = solid background, 0 = see-through background (elements stay opaque)
function Window:SetOpacity(alpha)
	self.Opacity = alpha
	self.Main.BackgroundTransparency = (1 - alpha) * 0.6
end

function Window:SetIconsVisible(visible)
	for _, icon in ipairs(self._tabIcons) do
		icon.Visible = visible and icon.Image ~= ""
	end
	for _, icon in ipairs(self._sectionIcons) do
		icon.Visible = visible and icon.Image ~= ""
	end
end

local Anchors = {
	["Top left"] = { Vector2.new(0, 0), UDim2.new(0, 24, 0, 24) },
	["Top right"] = { Vector2.new(1, 0), UDim2.new(1, -24, 0, 24) },
	["Bottom left"] = { Vector2.new(0, 1), UDim2.new(0, 24, 1, -24) },
	["Bottom right"] = { Vector2.new(1, 1), UDim2.new(1, -24, 1, -24) },
	["Center"] = { Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5) },
}
function Window:SetPosition(name)
	local a = Anchors[name]
	if a then
		self.Main.AnchorPoint = a[1]
		Tween(self.Main, 0.3, { Position = a[2] })
	end
end

function Window:SetAlwaysOnTop(on)
	self.Gui.DisplayOrder = on and 999 or 10
end

function Window:Notify(opts)
	if type(opts) == "string" then
		opts = { Content = opts }
	end
	local duration = opts.Duration or 4
	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self._notifyHolder,
	})
	local inner = New("Frame", {
		Position = UDim2.fromOffset(300, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Theme = { BackgroundColor3 = "Section" },
		Parent = card,
	}, { Corner(8), Pad(14, 14, 12, 14), List(nil, 4) })
	New("UIStroke", { Theme = { Color = "Stroke" }, Parent = inner })
	New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Fonts.Bold,
		Text = opts.Title or "Moonlight",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Theme = { TextColor3 = "Text" },
		Parent = inner,
	})
	New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Fonts.Medium,
		Text = opts.Content or "",
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Theme = { TextColor3 = "TextDim" },
		Parent = inner,
	})
	local bar = New("Frame", {
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2),
		LayoutOrder = 3,
		Theme = { BackgroundColor3 = "Accent" },
		Parent = inner,
	}, { Corner(1) })

	Tween(inner, 0.35, { Position = UDim2.fromOffset(0, 0) })
	Tween(bar, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
	task.delay(duration, function()
		local t = Tween(inner, 0.3, { Position = UDim2.fromOffset(300, 0) })
		t.Completed:Wait()
		card:Destroy()
	end)
end

function Window:SetWatermark(enabled, text)
	if not self._watermark then
		local wm = New("Frame", {
			Name = "Watermark",
			Position = UDim2.fromOffset(16, 16),
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			Theme = { BackgroundColor3 = "Section" },
			Parent = self.Gui,
		}, { Corner(7), Pad(12, 12, 0, 0) })
		New("UIStroke", { Theme = { Color = "Stroke" }, Parent = wm })
		local label = New("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			FontFace = Fonts.Medium,
			RichText = true,
			TextSize = 13,
			Theme = { TextColor3 = "TextDim" },
			Parent = wm,
		})
		local frames, elapsed, fps = 0, 0, 60
		Track(RunService.RenderStepped:Connect(function(dt)
			frames += 1
			elapsed += dt
			if elapsed >= 0.5 then
				fps = math.floor(frames / elapsed + 0.5)
				frames, elapsed = 0, 0
				local accent = Theme.Text:ToHex()
				label.Text = string.format(
					'<font color="#%s">%s</font>  |  %d fps  |  %s',
					accent,
					self._watermarkText or "moonlight",
					fps,
					os.date("%H:%M")
				)
			end
		end))
		self._watermark = wm
	end
	if text then
		self._watermarkText = text
	end
	self._watermark.Visible = enabled
end

--------------------------------------------------------------------------
-- The Settings tab from the reference design
--------------------------------------------------------------------------
function Window:BuildSettings(opts)
	opts = opts or {}
	local tab = self:AddTab({ Name = "Settings", Icon = "settings" })
	local appearance = tab:AddSubTab("Appearance")
	local hud = tab:AddSubTab("HUD")
	local changelog = tab:AddSubTab("Changelog")

	-- Appearance · left
	local visual = appearance:AddSection({ Name = "Visual settings", Icon = "palette", Side = "Left" })
	visual:AddDropdown({
		Name = "Theme",
		Options = Moonlight.ThemeOrder,
		Default = Moonlight.ThemeName,
		Flag = "Moonlight_Theme",
		Callback = function(name)
			Moonlight:SetTheme(name)
		end,
	})
	visual:AddColorPicker({
		Name = "Accent color",
		Default = Theme.Accent,
		Flag = "Moonlight_Accent",
		Callback = function(c)
			Moonlight:SetAccent(c)
		end,
	})

	local custom = appearance:AddSection({ Name = "Customization", Icon = "contrast", Side = "Left" })
	custom:AddDropdown({
		Name = "Sidebar position",
		Options = { "Top left", "Top right", "Bottom left", "Bottom right", "Center" },
		Default = opts.Position or "Center",
		Flag = "Moonlight_Position",
		Callback = function(p)
			self:SetPosition(p)
		end,
	})
	custom:AddToggle({
		Name = "Show / Hide icons",
		Default = false,
		Flag = "Moonlight_HideIcons",
		Callback = function(hide)
			self:SetIconsVisible(not hide)
		end,
	})

	-- Appearance · right
	local uiScale = appearance:AddSection({ Name = "UI Scale", Icon = "scan", Side = "Right" })
	uiScale:AddSlider({
		Name = "Interface size",
		Min = 100,
		Max = 150,
		Default = 100,
		Suffix = "%",
		Flag = "Moonlight_Scale",
		Callback = function(v)
			self:SetScale(v / 100)
		end,
	})
	uiScale:AddSlider({
		Name = "Interface opacity",
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = "%",
		Flag = "Moonlight_Opacity",
		Callback = function(v)
			self:SetOpacity(0.5 + v / 200) -- 0% → half see-through, 100% → solid
		end,
	})
	uiScale:AddSlider({
		Name = "Font size adjustment",
		Min = 100,
		Max = 150,
		Default = 100,
		Suffix = "%",
		Flag = "Moonlight_FontScale",
		Callback = function(v)
			Moonlight:SetFontScale(v / 100)
		end,
	})
	self:SetOpacity(0.75)

	local windowSec = appearance:AddSection({ Name = "Window settings", Icon = "app-window", Side = "Right" })
	windowSec:AddToggle({
		Name = "Always on top",
		Flag = "Moonlight_OnTop",
		Callback = function(on)
			self:SetAlwaysOnTop(on)
		end,
	})
	windowSec:AddToggle({
		Name = "Run on startup",
		Flag = "Moonlight_OpenOnStart", -- read this flag when you create the window next session
	})

	-- HUD
	local hudSec = hud:AddSection({ Name = "Overlay", Icon = "layout-dashboard", Side = "Left" })
	hudSec:AddToggle({
		Name = "Watermark",
		Flag = "Moonlight_Watermark",
		Callback = function(on)
			self:SetWatermark(on)
		end,
	})
	hudSec:AddTextbox({
		Name = "Watermark text",
		Default = "moonlight",
		Flag = "Moonlight_WatermarkText",
		Callback = function(text)
			self._watermarkText = text
		end,
	})
	local keys = hud:AddSection({ Name = "Keybinds", Icon = "keyboard", Side = "Right" })
	keys:AddKeybind({
		Name = "Menu toggle",
		Default = self.ToggleKey,
		Flag = "Moonlight_MenuKey",
		Changed = function(key)
			self.ToggleKey = key
		end,
	})

	-- Changelog
	local log = changelog:AddSection({ Name = "Changelog", Icon = "history", Side = "Left" })
	for _, entry in ipairs(opts.Changelog or {
		{ Title = "v1.0.0", Content = "Initial release of Moonlight." },
	}) do
		log:AddParagraph(entry)
	end

	return tab
end

function Window:Destroy()
	for _, c in ipairs(Connections) do
		c:Disconnect()
	end
	table.clear(Connections)
	table.clear(Themed)
	table.clear(ThemeHooks)
	table.clear(Texts)
	self.Gui:Destroy()
end

--------------------------------------------------------------------------
-- Load Lucide icons eagerly (executors only; no-op otherwise)
--------------------------------------------------------------------------
task.spawn(function()
	pcall(function()
		Moonlight:LoadIcons()
	end)
end)

return Moonlight
