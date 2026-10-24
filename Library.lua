local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local LUCIDE_URL = "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"

local Library = {
	Flags = {},
	Accent = Color3.fromRGB(249, 205, 234),
	Lucide = nil,
	_accentHooks = {},
	_connections = {},
	_popups = {},
	_bindToggles = {},
	_capturing = false,
}

local Theme = {
	Window    = Color3.fromRGB(44, 39, 43),
	Sidebar   = Color3.fromRGB(35, 32, 35),
	Section   = Color3.fromRGB(47, 42, 46),
	Stroke    = Color3.fromRGB(60, 54, 58),
	Line      = Color3.fromRGB(64, 58, 62),
	Box       = Color3.fromRGB(27, 23, 26),
	BoxStroke = Color3.fromRGB(38, 34, 37),
	Text      = Color3.fromRGB(240, 235, 238),
	TextDim   = Color3.fromRGB(128, 120, 126),
	TextHover = Color3.fromRGB(170, 162, 168),
	Selected  = Color3.fromRGB(75, 65, 73),
	SubActive = Color3.fromRGB(74, 66, 73),
}
Library.Theme = Theme

local FONT = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium)
local FONT_BOLD = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
local function create(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(r) return create("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function stroke(c, transp)
	return create("UIStroke", { Color = c, Thickness = 1, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function pad(t, b, l, r)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0),
		PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
	})
end
local function list(padding, dir, halign, valign)
	return create("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = dir or Enum.FillDirection.Vertical,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end
local function tween(obj, t, props)
	local tw = TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function toHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function fromHex(s)
	s = s:gsub("#", "")
	if #s ~= 6 then return nil end
	local r, g, b = tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16)
	if not (r and g and b) then return nil end
	return Color3.fromRGB(r, g, b)
end
local function keyName(key)
	if not key then return "none" end
	local n = typeof(key) == "EnumItem" and key.Name or tostring(key)
	n = n:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")
	return n:lower()
end
local function inside(obj, pos)
	if not obj or not obj.Parent then return false end
	local p, s = obj.AbsolutePosition, obj.AbsoluteSize
	return pos.X >= p.X and pos.Y >= p.Y and pos.X <= p.X + s.X and pos.Y <= p.Y + s.Y
end
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Library._connections, c)
	return c
end
local function richName(name)
	local base, ext = name:match("^(.-)(%..+)$")
	if not base then return name end
	return string.format('%s<font color="%s">%s</font>', base, toHex(Library.Accent), ext)
end

function Library:_bindAccent(fn)
	table.insert(self._accentHooks, fn)
	fn(self.Accent)
end

function Library:SetAccent(color)
	self.Accent = color
	for _, fn in ipairs(self._accentHooks) do task.spawn(fn, color) end
end

------------------------------------------------------------------------
-- icons (Lucide)
------------------------------------------------------------------------
local FALLBACK = {
	["moon-star"] = "☾", moon = "☾", check = "✓", ellipsis = "···", ["more-horizontal"] = "···",
	crosshair = "⌖", eye = "◉", sparkles = "✦", settings = "⚙", keyboard = "⌨",
	files = "❐", ["credit-card"] = "▭", ["chevron-down"] = "⌄", x = "✕",
}
local ALIASES = {
	ellipsis = { "ellipsis", "more-horizontal" },
}

local function httpGet(url)
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok and type(body) == "string" and #body > 0 then return body end
	local req = (type(request) == "function" and request) or (type(http_request) == "function" and http_request)
	if req then
		local ok2, res = pcall(req, { Url = url, Method = "GET" })
		if ok2 and type(res) == "table" and type(res.Body) == "string" then return res.Body end
	end
	return nil
end

function Library:LoadIcons(url)
	if self.Lucide then return self.Lucide end

	local mod = ReplicatedStorage:FindFirstChild("Lucide") or ReplicatedStorage:FindFirstChild("lucide-roblox")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and type(res) == "table" then self.Lucide = res return res end
	end

	local src = httpGet(url or LUCIDE_URL)
	if src and type(loadstring) == "function" then
		local fn = loadstring(src)
		if fn then
			local ok, res = pcall(fn)
			if ok and type(res) == "table" then self.Lucide = res return res end
		end
	end

	warn("[pawclient] Lucide icons unavailable, using fallback glyphs")
	return nil
end

local function getAsset(name)
	local L = Library.Lucide
	if not L or type(L.GetAsset) ~= "function" then return nil end
	for _, n in ipairs(ALIASES[name] or { name }) do
		for _, size in ipairs({ 48, 256 }) do
			local ok, a = pcall(L.GetAsset, n, size)
			if ok and type(a) == "table" and (a.Url or a.Image) then return a end
		end
	end
	return nil
end

local function icon(name, size, color, parent)
	local a = getAsset(name)
	if a then
		return create("ImageLabel", {
			Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
			Image = a.Url or a.Image,
			ImageRectSize = a.ImageRectSize or Vector2.zero,
			ImageRectOffset = a.ImageRectOffset or Vector2.zero,
			ImageColor3 = color, ScaleType = Enum.ScaleType.Fit, Parent = parent,
		})
	end
	return create("TextLabel", {
		Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
		Text = FALLBACK[name] or "•", TextColor3 = color, TextSize = math.floor(size * 0.9),
		FontFace = FONT_BOLD, Parent = parent,
	})
end

local function iconColor(obj, c, t)
	local prop = obj:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
	if t then tween(obj, t, { [prop] = c }) else obj[prop] = c end
end

local function centered(obj)
	obj.AnchorPoint = Vector2.new(0.5, 0.5)
	obj.Position = UDim2.fromScale(0.5, 0.5)
	return obj
end

------------------------------------------------------------------------
-- popups (settings panels, dropdowns, colour pickers) — stackable
------------------------------------------------------------------------
function Library:_closePopupsAbove(n)
	while #self._popups > n do
		local p = table.remove(self._popups)
		p.Frame.Visible = false
		if p.OnClose then p.OnClose() end
	end
end

function Library:_togglePopup(window, frame, anchor, placement, onClose)
	for i, p in ipairs(self._popups) do
		if p.Frame == frame then self:_closePopupsAbove(i - 1) return end
	end
	local level = 0
	for i, p in ipairs(self._popups) do
		if anchor:IsDescendantOf(p.Frame) then level = i end
	end
	self:_closePopupsAbove(level)

	local scale = window.Scale.Scale
	local rel = (anchor.AbsolutePosition - window.Main.AbsolutePosition) / scale
	local size = anchor.AbsoluteSize / scale
	if placement == "right" then
		frame.Position = UDim2.fromOffset(rel.X + size.X + 10, rel.Y - 12)
	else
		frame.Position = UDim2.fromOffset(rel.X, rel.Y + size.Y + 6)
	end
	frame.Visible = true
	table.insert(self._popups, { Frame = frame, Anchor = anchor, OnClose = onClose })
end

connect(UserInputService.InputBegan, function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if #Library._popups == 0 then return end
	local pos = UserInputService:GetMouseLocation()
	for i = #Library._popups, 1, -1 do
		local p = Library._popups[i]
		if inside(p.Frame, pos) or inside(p.Anchor, pos) then
			Library:_closePopupsAbove(i)
			return
		end
	end
	Library:_closePopupsAbove(0)
end)

------------------------------------------------------------------------
-- keybind list support (toggles with a Keybind)
------------------------------------------------------------------------
function Library:_refreshKeybinds()
	if self._keybindListRefresh then self._keybindListRefresh() end
end

connect(UserInputService.InputBegan, function(input, gpe)
	if gpe or Library._capturing then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	for _, t in ipairs(Library._bindToggles) do
		if t.Keybind == input.KeyCode then t:Set(not t.Value) end
	end
end)

------------------------------------------------------------------------
-- Container: shared element builders for sections and settings panels
------------------------------------------------------------------------
local Container = {}
Container.__index = Container

function Container.new(window, items, inset)
	return setmetatable({ Window = window, Items = items, Inset = inset or 17, _order = 0 }, Container)
end

function Container:_row(height)
	self._order += 1
	return create("Frame", {
		Name = "Row", Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1,
		LayoutOrder = self._order, Parent = self.Items,
	})
end

function Container:_panel(width)
	local frame = create("Frame", {
		Name = "Popup", Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Section, Visible = false, ZIndex = 5, Parent = self.Window.Overlay,
	}, { corner(8), stroke(Theme.Stroke) })
	local items = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = frame,
	}, { list(14), pad(14, 14) })
	return Container.new(self.Window, items, 14), frame
end

-- Toggle -------------------------------------------------------------
function Container:Toggle(cfg)
	cfg = cfg or {}
	local container, inset = self, self.Inset
	local toggle = {
		Name = cfg.Name or "toggle", Value = false, Flag = cfg.Flag,
		Callback = cfg.Callback or function() end, Keybind = cfg.Keybind,
	}

	local row = self:_row(26)
	local hit = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = row })
	local box = create("Frame", {
		Position = UDim2.fromOffset(inset, 0), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Theme.Box, Parent = row,
	}, { corner(4), stroke(Theme.BoxStroke) })
	local check = centered(icon("check", 18, Theme.Box, box))
	check.Visible = false
	local label = create("TextLabel", {
		Position = UDim2.fromOffset(inset + 40, 0), Size = UDim2.new(1, -(inset + 90), 1, 0),
		BackgroundTransparency = 1, Text = toggle.Name, TextColor3 = Theme.TextDim, TextSize = 19,
		FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})

	local hovering = false
	local function render(instant)
		local t = instant and 0 or 0.18
		local boxColor = toggle.Value and Library.Accent or Theme.Box
		local textColor = toggle.Value and Theme.Text or (hovering and Theme.TextHover or Theme.TextDim)
		if instant then
			box.BackgroundColor3, label.TextColor3 = boxColor, textColor
		else
			tween(box, t, { BackgroundColor3 = boxColor })
			tween(label, t, { TextColor3 = textColor })
		end
		check.Visible = toggle.Value
	end

	Library:_bindAccent(function(c) if toggle.Value then box.BackgroundColor3 = c end end)

	function toggle:Set(v, silent)
		self.Value = v and true or false
		if self.Flag then Library.Flags[self.Flag] = self.Value end
		render()
		Library:_refreshKeybinds()
		if not silent then task.spawn(self.Callback, self.Value) end
	end
	function toggle:Get() return self.Value end

	function toggle:Settings(width)
		if self._settings then return self._settings end
		local dots = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(inset - 2), 0.5, 0),
			Size = UDim2.fromOffset(30, 26), BackgroundTransparency = 1, Text = "", ZIndex = 2, Parent = row,
		})
		local dIcon = centered(icon("ellipsis", 20, Theme.TextDim, dots))
		dots.MouseEnter:Connect(function() iconColor(dIcon, Theme.Text, 0.15) end)
		dots.MouseLeave:Connect(function() iconColor(dIcon, Theme.TextDim, 0.15) end)
		local panel, frame = container:_panel(width or 280)
		dots.MouseButton1Click:Connect(function()
			Library:_togglePopup(container.Window, frame, dots, "right")
		end)
		self._settings = panel
		return panel
	end

	function toggle:SetKeybind(key)
		self.Keybind = key
		Library:_refreshKeybinds()
	end

	hit.MouseEnter:Connect(function() hovering = true render() end)
	hit.MouseLeave:Connect(function() hovering = false render() end)
	hit.MouseButton1Click:Connect(function() toggle:Set(not toggle.Value) end)

	table.insert(Library._bindToggles, toggle)
	toggle:Set(cfg.Default or false, true)
	render(true)
	if cfg.Default and cfg.CallOnLoad ~= false then task.spawn(toggle.Callback, true) end
	return toggle
end

-- Divider ------------------------------------------------------------
function Container:Divider()
	local row = self:_row(1)
	create("Frame", {
		Position = UDim2.fromOffset(self.Inset, 0), Size = UDim2.new(1, -self.Inset * 2, 0, 1),
		BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Parent = row,
	})
end

-- Label --------------------------------------------------------------
function Container:Label(text)
	local row = self:_row(22)
	local lbl = create("TextLabel", {
		Position = UDim2.fromOffset(self.Inset, 0), Size = UDim2.new(1, -self.Inset * 2, 1, 0),
		BackgroundTransparency = 1, Text = text or "", TextColor3 = Theme.TextDim, TextSize = 18,
		FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = row,
	})
	return { Set = function(_, t) lbl.Text = t end }
end

-- Button -------------------------------------------------------------
function Container:Button(cfg)
	cfg = cfg or {}
	local row = self:_row(32)
	local btn = create("TextButton", {
		Position = UDim2.fromOffset(self.Inset, 0), Size = UDim2.new(1, -self.Inset * 2, 1, 0),
		BackgroundColor3 = Theme.Box, AutoButtonColor = false, Text = cfg.Name or "button",
		TextColor3 = Theme.TextDim, TextSize = 18, FontFace = FONT, Parent = row,
	}, { corner(4) })
	local st = stroke(Theme.BoxStroke)
	st.Parent = btn
	btn.MouseEnter:Connect(function() tween(btn, 0.15, { TextColor3 = Theme.Text }) end)
	btn.MouseLeave:Connect(function() tween(btn, 0.15, { TextColor3 = Theme.TextDim }) end)
	btn.MouseButton1Click:Connect(function()
		st.Color = Library.Accent
		tween(st, 0.4, { Color = Theme.BoxStroke })
		if cfg.Callback then task.spawn(cfg.Callback) end
	end)
end

-- Keybind ------------------------------------------------------------
function Container:Keybind(cfg)
	cfg = cfg or {}
	local kb = { Value = cfg.Default, Flag = cfg.Flag, Callback = cfg.Callback, Changed = cfg.Changed, _listening = false }

	local row = self:_row(30)
	local box = create("TextButton", {
		Position = UDim2.fromOffset(self.Inset, 0), Size = UDim2.fromOffset(125, 30),
		BackgroundColor3 = Theme.Box, AutoButtonColor = false, Text = keyName(kb.Value),
		TextColor3 = Theme.TextDim, TextSize = 18, FontFace = FONT, Parent = row,
	}, { corner(4), stroke(Theme.BoxStroke) })
	create("TextLabel", {
		Position = UDim2.fromOffset(self.Inset + 142, 0), Size = UDim2.new(1, -(self.Inset + 150), 1, 0),
		BackgroundTransparency = 1, Text = cfg.Name or "keybind", TextColor3 = Theme.Text, TextSize = 19,
		FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})

	function kb:Set(key)
		self.Value = key
		box.Text = keyName(key)
		if self.Flag then Library.Flags[self.Flag] = key end
		if self.Changed then task.spawn(self.Changed, key) end
	end

	box.MouseButton1Click:Connect(function()
		kb._listening = true
		Library._capturing = true
		box.Text = "..."
		box.TextColor3 = Library.Accent
	end)

	connect(UserInputService.InputBegan, function(input, gpe)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if kb._listening then
			kb._listening = false
			box.TextColor3 = Theme.TextDim
			if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
				kb:Set(nil)
			else
				kb:Set(input.KeyCode)
			end
			task.defer(function() Library._capturing = false end)
			return
		end
		if not gpe and not Library._capturing and kb.Value and input.KeyCode == kb.Value and kb.Callback then
			task.spawn(kb.Callback, kb.Value)
		end
	end)

	if kb.Flag then Library.Flags[kb.Flag] = kb.Value end
	return kb
end

-- Slider -------------------------------------------------------------
function Container:Slider(cfg)
	cfg = cfg or {}
	local min, max = cfg.Min or 0, cfg.Max or 100
	local inc = cfg.Increment or 1
	local suffix = cfg.Suffix or ""
	local decimals = math.max(0, math.ceil(-math.log10(inc) - 1e-9))
	local slider = { Value = cfg.Default or min, Flag = cfg.Flag, Callback = cfg.Callback or function() end }

	local row = self:_row(42)
	create("TextLabel", {
		Position = UDim2.fromOffset(self.Inset, 0), Size = UDim2.new(1, -self.Inset * 2, 0, 20),
		BackgroundTransparency = 1, Text = cfg.Name or "slider", TextColor3 = Theme.TextDim, TextSize = 18,
		FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	local valueLabel = create("TextLabel", {
		Position = UDim2.fromOffset(self.Inset, 0), Size = UDim2.new(1, -self.Inset * 2, 0, 20),
		BackgroundTransparency = 1, Text = "", TextColor3 = Theme.Text, TextSize = 18,
		FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
	})
	local track = create("TextButton", {
		Position = UDim2.fromOffset(self.Inset, 30), Size = UDim2.new(1, -self.Inset * 2, 0, 8),
		BackgroundColor3 = Theme.Box, AutoButtonColor = false, Text = "", Parent = row,
	}, { corner(4), stroke(Theme.BoxStroke) })
	local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Library.Accent, BorderSizePixel = 0, Parent = track }, { corner(4) })
	Library:_bindAccent(function(c) fill.BackgroundColor3 = c end)

	function slider:Set(v, silent)
		v = math.clamp(math.floor((v - min) / inc + 0.5) * inc + min, min, max)
		self.Value = v
		if self.Flag then Library.Flags[self.Flag] = v end
		valueLabel.Text = string.format("%." .. decimals .. "f", v) .. suffix
		tween(fill, 0.08, { Size = UDim2.fromScale((v - min) / (max - min), 1) })
		if not silent then task.spawn(self.Callback, v) end
	end

	local dragging = false
	local function update()
		local x = UserInputService:GetMouseLocation().X
		local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		slider:Set(min + (max - min) * a)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update()
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update() end
	end)
	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)

	slider:Set(slider.Value, true)
	return slider
end

-- Dropdown -----------------------------------------------------------
function Container:Dropdown(cfg)
	cfg = cfg or {}
	local container = self
	local multi = cfg.Multi or false
	local dd = { Options = cfg.Options or {}, Flag = cfg.Flag, Callback = cfg.Callback or function() end }
	dd.Value = multi and (cfg.Default or {}) or (cfg.Default or dd.Options[1])

	local row = self:_row(60)
	create("TextLabel", {
		Position = UDim2.fromOffset(self.Inset, 0), Size = UDim2.new(1, -self.Inset * 2, 0, 20),
		BackgroundTransparency = 1, Text = cfg.Name or "dropdown", TextColor3 = Theme.TextDim, TextSize = 18,
		FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	local box = create("TextButton", {
		Position = UDim2.fromOffset(self.Inset, 28), Size = UDim2.new(1, -self.Inset * 2, 0, 32),
		BackgroundColor3 = Theme.Box, AutoButtonColor = false, Text = "", Parent = row,
	}, { corner(4), stroke(Theme.BoxStroke), pad(0, 0, 12, 10) })
	local valueText = create("TextLabel", {
		Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, Text = "", TextColor3 = Theme.Text,
		TextSize = 18, FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = box,
	})
	local chev = icon("chevron-down", 18, Theme.TextDim, box)
	chev.AnchorPoint = Vector2.new(1, 0.5)
	chev.Position = UDim2.fromScale(1, 0.5)

	local panel, frame = self:_panel(200)
	panel.Items:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 2)
	panel.Items:FindFirstChildOfClass("UIPadding"):Destroy()
	pad(6, 6, 6, 6).Parent = panel.Items
	local optionButtons = {}

	local function isSelected(opt)
		if multi then return table.find(dd.Value, opt) ~= nil end
		return dd.Value == opt
	end

	local function render()
		if multi then
			valueText.Text = #dd.Value > 0 and table.concat(dd.Value, ", ") or "none"
		else
			valueText.Text = tostring(dd.Value or "none")
		end
		for opt, b in pairs(optionButtons) do
			b.TextColor3 = isSelected(opt) and Library.Accent or Theme.TextDim
		end
	end
	Library:_bindAccent(function() render() end)

	local function build()
		for _, b in pairs(optionButtons) do b:Destroy() end
		table.clear(optionButtons)
		for i, opt in ipairs(dd.Options) do
			local b = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Theme.Box, BackgroundTransparency = 1,
				AutoButtonColor = false, Text = tostring(opt), TextColor3 = Theme.TextDim, TextSize = 18,
				FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = panel.Items,
			}, { corner(4), pad(0, 0, 8, 8) })
			b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundTransparency = 0.4 }) end)
			b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundTransparency = 1 }) end)
			b.MouseButton1Click:Connect(function()
				if multi then
					local idx = table.find(dd.Value, opt)
					if idx then table.remove(dd.Value, idx) else table.insert(dd.Value, opt) end
					dd:Set(dd.Value)
				else
					dd:Set(opt)
					Library:_togglePopup(container.Window, frame, box, "below")
				end
			end)
			optionButtons[opt] = b
		end
		render()
	end

	function dd:Set(v, silent)
		self.Value = v
		if self.Flag then Library.Flags[self.Flag] = v end
		render()
		if not silent then task.spawn(self.Callback, v) end
	end
	function dd:Refresh(options, keep)
		self.Options = options
		if not keep then self.Value = multi and {} or options[1] end
		build()
	end

	box.MouseButton1Click:Connect(function()
		frame.Size = UDim2.fromOffset(box.AbsoluteSize.X / container.Window.Scale.Scale, 0)
		Library:_togglePopup(container.Window, frame, box, "below")
	end)

	build()
	if dd.Flag then Library.Flags[dd.Flag] = dd.Value end
	return dd
end

-- ColorPicker --------------------------------------------------------
function Container:ColorPicker(cfg)
	cfg = cfg or {}
	local container = self
	local cp = { Value = cfg.Default or Color3.new(1, 1, 1), Flag = cfg.Flag, Callback = cfg.Callback or function() end }
	local h, s, v = cp.Value:ToHSV()

	local row = self:_row(30)
	local swatch = create("TextButton", {
		Position = UDim2.fromOffset(self.Inset, 0), Size = UDim2.fromOffset(44, 30),
		BackgroundColor3 = cp.Value, AutoButtonColor = false, Text = "", Parent = row,
	}, { corner(4) })
	create("TextLabel", {
		Position = UDim2.fromOffset(self.Inset + 60, 0), Size = UDim2.new(1, -(self.Inset + 70), 1, 0),
		BackgroundTransparency = 1, Text = cfg.Name or "color", TextColor3 = Theme.Text, TextSize = 19,
		FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})

	-- popup
	local frame = create("Frame", {
		Name = "ColorPopup", Size = UDim2.fromOffset(224, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Section, Visible = false, ZIndex = 5, Parent = self.Window.Overlay,
	}, { corner(8), stroke(Theme.Stroke), pad(12, 12, 12, 12), list(10) })

	local sv = create("TextButton", {
		Size = UDim2.fromOffset(200, 150), BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		AutoButtonColor = false, Text = "", LayoutOrder = 1, Parent = frame,
	}, { corner(4) })
	create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv }, {
		corner(4),
		create("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
	})
	create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv }, {
		corner(4),
		create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }),
	})
	local svCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1, ZIndex = 3, Parent = sv,
	}, { corner(5), create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }) })

	local hue = create("TextButton", {
		Size = UDim2.fromOffset(200, 12), BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false, Text = "", LayoutOrder = 2, Parent = frame,
	}, {
		corner(4),
		create("UIGradient", { Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		}) }),
	})
	local hueCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 16), Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = hue,
	}, { corner(2) })

	local hex = create("TextBox", {
		Size = UDim2.fromOffset(200, 28), BackgroundColor3 = Theme.Box, Text = "", PlaceholderText = "#FFFFFF",
		TextColor3 = Theme.Text, PlaceholderColor3 = Theme.TextDim, TextSize = 17, FontFace = FONT,
		ClearTextOnFocus = false, LayoutOrder = 3, Parent = frame,
	}, { corner(4), stroke(Theme.BoxStroke) })

	local function render(silent)
		cp.Value = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = cp.Value
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(h, 0.5)
		hex.Text = toHex(cp.Value)
		if cp.Flag then Library.Flags[cp.Flag] = cp.Value end
		if not silent then task.spawn(cp.Callback, cp.Value) end
	end

	function cp:Set(c, silent)
		h, s, v = c:ToHSV()
		render(silent)
	end

	local dragging
	local function update()
		local m = UserInputService:GetMouseLocation()
		if dragging == "sv" then
			s = math.clamp((m.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			v = 1 - math.clamp((m.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		elseif dragging == "hue" then
			h = math.clamp((m.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 0.999)
		end
		render()
	end
	local function begin(kind)
		return function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = kind
				update()
			end
		end
	end
	sv.InputBegan:Connect(begin("sv"))
	hue.InputBegan:Connect(begin("hue"))
	connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update() end
	end)
	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = nil end
	end)
	hex.FocusLost:Connect(function()
		local c = fromHex(hex.Text)
		if c then cp:Set(c) else hex.Text = toHex(cp.Value) end
	end)

	swatch.MouseButton1Click:Connect(function()
		Library:_togglePopup(container.Window, frame, swatch, "right")
	end)

	render(true)
	return cp
end

------------------------------------------------------------------------
-- Window / Tab / SubTab / Section
------------------------------------------------------------------------
local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local SubTab = {}
SubTab.__index = SubTab

local function getGuiParent()
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and typeof(hui) == "Instance" then return hui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function makeDraggable(handle, target)
	local dragging, startMouse, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, startMouse, startPos = true, UserInputService:GetMouseLocation(), target.Position
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = UserInputService:GetMouseLocation() - startMouse
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

function Library:CreateWindow(cfg)
	cfg = cfg or {}
	if cfg.Accent then self.Accent = cfg.Accent end
	self:LoadIcons(cfg.IconSource)

	local win = setmetatable({
		Name = cfg.Name or "pawclient.hvh",
		MenuKey = cfg.MenuKey or Enum.KeyCode.Insert,
		Tabs = {},
	}, Window)

	local gui = create("ScreenGui", {
		Name = "pawclient", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
	})
	gui.Parent = getGuiParent()
	win.Gui = gui

	local main = create("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(885, 760), BackgroundColor3 = Theme.Window, BackgroundTransparency = 0.02, Parent = gui,
	}, { corner(10), stroke(Theme.Stroke, 0.3) })
	win.Main = main
	win.Scale = create("UIScale", { Scale = cfg.Scale or 0.8, Parent = main })

	-- sidebar
	local sidebar = create("Frame", { Name = "Sidebar", Size = UDim2.new(0, 88, 1, 0), BackgroundColor3 = Theme.Sidebar, Parent = main }, { corner(10) })
	create("Frame", { Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, Parent = sidebar })
	create("Frame", { Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Parent = sidebar })
	makeDraggable(sidebar, main)

	local logo = icon(cfg.Logo or "moon-star", 38, Theme.Text, sidebar)
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Position = UDim2.new(0.5, 0, 0, 42)
	win.Logo = logo

	create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.fromOffset(40, 1), BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Parent = sidebar })
	win.TopTabs = create("Frame", { Position = UDim2.fromOffset(0, 102), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = sidebar }, { list(12, nil, Enum.HorizontalAlignment.Center) })
	win.BottomDivider = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -160), Size = UDim2.fromOffset(40, 1), BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Visible = false, Parent = sidebar })
	win.BottomTabs = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = sidebar }, { list(14, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom) })

	win.Content = create("Frame", { Name = "Content", Position = UDim2.fromOffset(89, 0), Size = UDim2.new(1, -89, 1, 0), BackgroundTransparency = 1, Parent = main })
	win.Overlay = create("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = main })

	-- menu key
	connect(UserInputService.InputBegan, function(input, gpe)
		if gpe or Library._capturing then return end
		if win.MenuKey and input.KeyCode == win.MenuKey then win:SetVisible(not main.Visible) end
	end)

	win:_buildWatermark()
	win:_buildKeybindList()
	return win
end

function Window:SetVisible(v)
	self.Main.Visible = v
	if not v then Library:_closePopupsAbove(0) end
end

function Window:SetMenuKey(key) self.MenuKey = key end

function Window:Tab(cfg)
	cfg = cfg or {}
	local win = self
	local tab = setmetatable({ Window = win, SubTabs = {} }, Tab)

	local btn = create("TextButton", {
		Size = UDim2.fromOffset(56, 56), BackgroundColor3 = Theme.Selected, BackgroundTransparency = 1,
		AutoButtonColor = false, Text = "", LayoutOrder = #win.Tabs + 1,
		Parent = cfg.Bottom and win.BottomTabs or win.TopTabs,
	}, { corner(10) })
	if cfg.Bottom then win.BottomDivider.Visible = true end
	local ic = centered(icon(cfg.Icon or "settings", 28, Theme.TextDim, btn))
	tab.Button, tab.Icon = btn, ic

	tab.Page = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = win.Content })
	tab.Bar = create("Frame", { Position = UDim2.fromOffset(13, 8), Size = UDim2.new(1, -25, 0, 50), BackgroundTransparency = 1, Parent = tab.Page }, { list(6, Enum.FillDirection.Horizontal) })
	makeDraggable(tab.Bar, win.Main)
	create("Frame", { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Parent = tab.Page })
	tab.Pages = create("Frame", { Position = UDim2.fromOffset(0, 71), Size = UDim2.new(1, 0, 1, -71), BackgroundTransparency = 1, Parent = tab.Page })

	btn.MouseEnter:Connect(function() if win.Selected ~= tab then iconColor(ic, Theme.TextHover, 0.15) end end)
	btn.MouseLeave:Connect(function() if win.Selected ~= tab then iconColor(ic, Theme.TextDim, 0.15) end end)
	btn.MouseButton1Click:Connect(function() tab:Select() end)

	table.insert(win.Tabs, tab)
	if not win.Selected then tab:Select() end
	return tab
end

function Tab:Select()
	local win = self.Window
	Library:_closePopupsAbove(0)
	for _, t in ipairs(win.Tabs) do
		local on = t == self
		t.Page.Visible = on
		tween(t.Button, 0.2, { BackgroundTransparency = on and 0 or 1 })
		iconColor(t.Icon, on and Theme.Text or Theme.TextDim, 0.2)
	end
	win.Selected = self
end

function Tab:SubTab(name)
	local tab = self
	local sub = setmetatable({ Tab = tab, Window = tab.Window, Name = name }, SubTab)

	sub.Button = create("TextButton", {
		BackgroundColor3 = Theme.SubActive, BackgroundTransparency = 1, AutoButtonColor = false,
		Text = name or "page", TextColor3 = Theme.TextDim, TextSize = 21, FontFace = FONT,
		LayoutOrder = #tab.SubTabs + 1, Parent = tab.Bar,
	}, { corner(8) })

	sub.Page = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Line, Visible = false, Parent = tab.Pages,
	}, { pad(15, 15, 18, 18) })
	sub.Left = create("Frame", { Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = sub.Page }, { list(12) })
	sub.Right = create("Frame", { Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = sub.Page }, { list(12) })

	sub.Button.MouseEnter:Connect(function() if tab.Selected ~= sub then tween(sub.Button, 0.15, { TextColor3 = Theme.TextHover }) end end)
	sub.Button.MouseLeave:Connect(function() if tab.Selected ~= sub then tween(sub.Button, 0.15, { TextColor3 = Theme.TextDim }) end end)
	sub.Button.MouseButton1Click:Connect(function() sub:Select() end)

	table.insert(tab.SubTabs, sub)
	local n = #tab.SubTabs
	for _, s in ipairs(tab.SubTabs) do
		s.Button.Size = UDim2.new(1 / n, -(6 * (n - 1)) / n, 1, 0)
	end
	if not tab.Selected then sub:Select() end
	return sub
end

function SubTab:Select()
	local tab = self.Tab
	Library:_closePopupsAbove(0)
	for _, s in ipairs(tab.SubTabs) do
		local on = s == self
		s.Page.Visible = on
		tween(s.Button, 0.2, { BackgroundTransparency = on and 0 or 1, TextColor3 = on and Theme.Text or Theme.TextDim })
	end
	tab.Selected = self
end

function SubTab:Section(cfg)
	if type(cfg) == "string" then cfg = { Name = cfg } end
	cfg = cfg or {}
	local column = (cfg.Side or "left"):lower() == "right" and self.Right or self.Left
	local count = #column:GetChildren()

	local frame = create("Frame", {
		Name = "Section", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Section, LayoutOrder = count, Parent = column,
	}, { corner(8), stroke(Theme.Stroke, 0.2) })

	local bar = create("Frame", { Position = UDim2.fromOffset(12, 15), Size = UDim2.fromOffset(3, 22), BackgroundColor3 = Library.Accent, BorderSizePixel = 0, Parent = frame }, { corner(2) })
	Library:_bindAccent(function(c) bar.BackgroundColor3 = c end)
	create("TextLabel", {
		Position = UDim2.fromOffset(30, 15), Size = UDim2.new(1, -40, 0, 22), BackgroundTransparency = 1,
		Text = cfg.Name or "section", TextColor3 = Theme.TextDim, TextSize = 19, FontFace = FONT,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = frame,
	})
	create("Frame", { Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Parent = frame })

	-- items sit under the header; a spacer keeps AutomaticSize counting the header height
	local items = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Parent = frame,
	}, { list(14), pad(2, 14) })
	create("Frame", { Size = UDim2.fromOffset(0, 51), BackgroundTransparency = 1, LayoutOrder = -1, Parent = items })

	return Container.new(self.Window, items, 17)
end

------------------------------------------------------------------------
-- widgets: watermark + keybind list
------------------------------------------------------------------------
function Window:_buildWatermark()
	local holder = create("Frame", {
		Name = "Watermark", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Window, Parent = self.Gui,
	}, { corner(8), stroke(Theme.Stroke, 0.3), pad(0, 0, 12, 14), list(10, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center) })
	create("UIScale", { Scale = self.Scale.Scale, Parent = holder })

	local logo = icon("moon-star", 18, Library.Accent, holder)
	logo.LayoutOrder = 1
	Library:_bindAccent(function(c) iconColor(logo, c) end)

	local label = create("TextLabel", {
		Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		RichText = true, Text = "", TextColor3 = Theme.Text, TextSize = 18, FontFace = FONT, LayoutOrder = 2, Parent = holder,
	})

	local frames, last, fps = 0, os.clock(), 0
	local function refresh()
		local ping = 0
		pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5) end)
		label.Text = string.format('%s  <font color="%s">|</font>  %d fps  <font color="%s">|</font>  %d ms',
			richName(self.Name), toHex(Theme.TextDim), fps, toHex(Theme.TextDim), ping)
	end
	connect(RunService.RenderStepped, function()
		frames += 1
		local now = os.clock()
		if now - last >= 0.5 then
			fps = math.floor(frames / (now - last) + 0.5)
			frames, last = 0, now
			refresh()
		end
	end)
	Library:_bindAccent(function() refresh() end)

	self.Watermark = {
		Frame = holder,
		SetVisible = function(_, v) holder.Visible = v end,
	}
end

function Window:_buildKeybindList()
	local holder = create("Frame", {
		Name = "KeybindList", Position = UDim2.new(0, 16, 0.5, -60), Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Window, Visible = false, Parent = self.Gui,
	}, { corner(8), stroke(Theme.Stroke, 0.3), pad(0, 10, 0, 0), list(6) })
	create("UIScale", { Scale = self.Scale.Scale, Parent = holder })
	makeDraggable(holder, holder)

	local header = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 0, Parent = holder })
	local bar = create("Frame", { Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(3, 20), BackgroundColor3 = Library.Accent, BorderSizePixel = 0, Parent = header }, { corner(2) })
	Library:_bindAccent(function(c) bar.BackgroundColor3 = c end)
	create("TextLabel", { Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -30, 1, 0), BackgroundTransparency = 1, Text = "keybinds", TextColor3 = Theme.Text, TextSize = 18, FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	create("Frame", { Position = UDim2.new(0, 12, 1, -1), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Parent = header })

	local rows = {}
	Library._keybindListRefresh = function()
		for _, r in ipairs(rows) do r:Destroy() end
		table.clear(rows)
		for i, t in ipairs(Library._bindToggles) do
			if t.Keybind and t.Value then
				local r = create("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = i, Parent = holder }, { pad(0, 0, 14, 14) })
				create("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = t.Name, TextColor3 = Theme.Text, TextSize = 17, FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Left, Parent = r })
				create("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "[" .. keyName(t.Keybind) .. "]", TextColor3 = Theme.TextDim, TextSize = 17, FontFace = FONT, TextXAlignment = Enum.TextXAlignment.Right, Parent = r })
				table.insert(rows, r)
			end
		end
	end

	self.KeybindList = {
		Frame = holder,
		SetVisible = function(_, v) holder.Visible = v Library._keybindListRefresh() end,
	}
end

------------------------------------------------------------------------
function Library:Destroy()
	for _, c in ipairs(self._connections) do c:Disconnect() end
	table.clear(self._connections)
	local parent = getGuiParent()
	local gui = parent:FindFirstChild("pawclient")
	if gui then gui:Destroy() end
end

return Library
