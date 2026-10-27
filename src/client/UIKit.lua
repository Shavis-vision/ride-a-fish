-- UIKit (ModuleScript)
-- Fica em: StarterPlayerScripts > Client > UIKit
--
-- O visual das telas, no estilo das referências: letras grossas com contorno preto,
-- botões com gradiente colorido, janelas escuras com barra de título azul e X vermelho.
-- Todas as telas são montadas com estas peças, para ficarem iguais.
--
--   UIKit.Button(parent, { Text, Color = "Green", Size, Position, OnClick, Icon })
--   UIKit.Window("Shop", { Title = "Loja", Size = Vector2.new(900, 600), Header = "Blue" })
--   UIKit.Viewport(parent, entry) -- peixe 3D dentro de um quadradinho
--   UIKit.Confirm("Vender tudo?", "Vender", function() ... end)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishModel = require(Shared:WaitForChild("FishModel"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne
UIKit.Dark = Color3.fromRGB(14, 14, 20)
UIKit.Panel = Color3.fromRGB(34, 34, 42)
UIKit.Card = Color3.fromRGB(50, 50, 62)
UIKit.CardLight = Color3.fromRGB(64, 64, 78)
UIKit.White = Color3.fromRGB(255, 255, 255)
UIKit.MoneyGreen = Color3.fromRGB(90, 255, 90)
UIKit.StaminaYellow = Color3.fromRGB(255, 220, 50)

-- cor de cima, cor de baixo
UIKit.Colors = {
	Red = { Color3.fromRGB(255, 105, 115), Color3.fromRGB(215, 35, 55) },
	Blue = { Color3.fromRGB(120, 190, 255), Color3.fromRGB(45, 105, 235) },
	Green = { Color3.fromRGB(140, 245, 90), Color3.fromRGB(40, 175, 45) },
	Orange = { Color3.fromRGB(255, 190, 90), Color3.fromRGB(240, 110, 30) },
	Purple = { Color3.fromRGB(215, 140, 255), Color3.fromRGB(135, 60, 230) },
	Gray = { Color3.fromRGB(150, 150, 160), Color3.fromRGB(95, 95, 108) },
	Gold = { Color3.fromRGB(255, 230, 100), Color3.fromRGB(240, 160, 20) },
	Teal = { Color3.fromRGB(110, 240, 230), Color3.fromRGB(20, 160, 170) },
}

function UIKit.Tween(object, time, props, style, direction)
	local tween = TweenService:Create(
		object,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

function UIKit.Stroke(object, thickness, color, mode)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 3
	stroke.Color = color or UIKit.Dark
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	if mode then
		stroke.ApplyStrokeMode = mode
	end
	stroke.Parent = object
	return stroke
end

function UIKit.Corner(object, pixels)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, pixels or 10)
	corner.Parent = object
	return corner
end

function UIKit.Gradient(object, top, bottom, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = rotation or 90
	gradient.Parent = object
	return gradient
end

function UIKit.Padding(object, pixels)
	local padding = Instance.new("UIPadding")
	local p = UDim.new(0, pixels)
	padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight = p, p, p, p
	padding.Parent = object
	return padding
end

-- Texto com contorno. props: Text, Size, Position, AnchorPoint, Color, Align, Max (tamanho máx), Stroke
function UIKit.Text(parent, props)
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Text"
	label.BackgroundTransparency = 1
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.Position = props.Position or UDim2.new()
	label.AnchorPoint = props.AnchorPoint or Vector2.new()
	label.Font = UIKit.Font
	label.Text = props.Text or ""
	label.TextColor3 = props.Color or UIKit.White
	label.TextScaled = true
	label.TextXAlignment = props.Align or Enum.TextXAlignment.Center
	label.TextYAlignment = props.AlignY or Enum.TextYAlignment.Center
	label.RichText = props.Rich == true
	label.ZIndex = props.ZIndex or 1
	label.LayoutOrder = props.LayoutOrder or 0
	if props.Max then
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = props.Max
		limit.Parent = label
	end
	if props.Stroke ~= false then
		UIKit.Stroke(label, props.Stroke or 2.5, UIKit.Dark)
	end
	label.Parent = parent
	return label
end

function UIKit.Frame(parent, props)
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Frame"
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.new()
	frame.BackgroundColor3 = props.Color or UIKit.Card
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.LayoutOrder = props.LayoutOrder or 0
	frame.ZIndex = props.ZIndex or 1
	if props.Corner ~= false then
		UIKit.Corner(frame, props.Corner or 10)
	end
	if props.Stroke then
		UIKit.Stroke(frame, props.Stroke, props.StrokeColor or UIKit.Dark, Enum.ApplyStrokeMode.Border)
	end
	frame.Parent = parent
	return frame
end

local function pressFeedback(button)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.Tween(scale, 0.08, { Scale = 0.93 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	return scale
end

function UIKit.SetButtonColor(button, colorKey)
	local colors = UIKit.Colors[colorKey] or UIKit.Colors.Blue
	local gradient = button:FindFirstChild("Fill")
	if gradient then
		gradient.Color = ColorSequence.new(colors[1], colors[2])
	end
end

-- Botão colorido. props: Text, Color ("Green"...), Size, Position, AnchorPoint, Icon, OnClick, Max, Corner
function UIKit.Button(parent, props)
	local button = Instance.new("TextButton")
	button.Name = props.Name or "Button"
	button.AutoButtonColor = false
	button.Text = ""
	button.Size = props.Size or UDim2.fromOffset(160, 56)
	button.Position = props.Position or UDim2.new()
	button.AnchorPoint = props.AnchorPoint or Vector2.new()
	button.BackgroundColor3 = UIKit.White
	button.BorderSizePixel = 0
	button.LayoutOrder = props.LayoutOrder or 0
	button.ZIndex = props.ZIndex or 1
	UIKit.Corner(button, props.Corner or 10)
	UIKit.Stroke(button, props.StrokeThickness or 3, UIKit.Dark, Enum.ApplyStrokeMode.Border)
	local colors = UIKit.Colors[props.Color or "Blue"] or UIKit.Colors.Blue
	local fill = UIKit.Gradient(button, colors[1], colors[2], 90)
	fill.Name = "Fill"

	-- brilho na metade de cima
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = UIKit.White
	shine.BackgroundTransparency = 0.82
	shine.BorderSizePixel = 0
	shine.Size = UDim2.new(1, -8, 0.42, 0)
	shine.Position = UDim2.fromOffset(4, 3)
	shine.ZIndex = button.ZIndex
	UIKit.Corner(shine, math.max(2, (props.Corner or 10) - 3))
	shine.Parent = button

	local textLeft = 0
	if props.Icon then
		local icon = UIKit.Text(button, {
			Name = "Icon",
			Text = props.Icon,
			Size = UDim2.new(0, 0, 0.8, 0),
			Position = UDim2.new(0, 8, 0.1, 0),
			ZIndex = button.ZIndex + 1,
			Stroke = 1.5,
		})
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1
		ratio.DominantAxis = Enum.DominantAxis.Height
		ratio.Parent = icon
		icon.Size = UDim2.fromScale(1, 0.8)
		textLeft = props.IconWidth or 0.32
	end

	local label = UIKit.Text(button, {
		Name = "Label",
		Text = props.Text or "",
		Size = UDim2.new(1 - textLeft, -12, 0.78, 0),
		Position = UDim2.new(textLeft, 6, 0.11, 0),
		Max = props.Max or 42,
		ZIndex = button.ZIndex + 1,
		Stroke = props.TextStroke or 2.5,
	})

	pressFeedback(button)
	if props.OnClick then
		button.Activated:Connect(props.OnClick)
	end
	button.Parent = parent
	return button, label
end

-- Escala automática conforme o tamanho da tela (celular fica menor, PC normal).
function UIKit.AutoScale(object, baseSize)
	local scale = Instance.new("UIScale")
	scale.Name = "AutoScale"
	scale.Parent = object
	local function update()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1366, 768)
		local s = math.clamp(math.min(viewport.X / 1366, viewport.Y / 768), 0.5, 1.15)
		if baseSize then
			s = math.min(s, viewport.X * 0.96 / baseSize.X, viewport.Y * 0.9 / baseSize.Y)
		end
		scale.Scale = s
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return scale
end

function UIKit.Gui(name, displayOrder)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 1
	gui.Parent = playerGui
	return gui
end

-- Janelas -----------------------------------------------------------------------------------

UIKit.Windows = {}

function UIKit.CloseAll(except)
	for name, window in pairs(UIKit.Windows) do
		if name ~= except and window.IsOpen then
			window.Close()
		end
	end
end

function UIKit.OpenWindow(name, ...)
	local window = UIKit.Windows[name]
	if window then
		window.Open(...)
	end
end

function UIKit.IsOpen(name)
	local window = UIKit.Windows[name]
	return window ~= nil and window.IsOpen
end

-- props: Title, Size = Vector2 (pixels na tela 1366x768), Header = cor, HeaderRight = largura extra
function UIKit.Window(name, props)
	local size = props.Size or Vector2.new(900, 600)
	local gui = UIKit.Gui(name .. "Window", 10)
	gui.Enabled = true

	local root = UIKit.Frame(gui, {
		Name = "Window",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = UIKit.Panel,
		Corner = 16,
		Stroke = 5,
	})
	root.Visible = false
	root.Active = true
	local autoScale = UIKit.AutoScale(root, size)
	local animScale = Instance.new("UIScale")
	animScale.Name = "AnimScale"
	-- duas escalas não somam: a animação mexe num quadro interno
	local inner = UIKit.Frame(root, { Name = "Inner", Transparency = 1, Corner = false })
	animScale.Parent = inner

	local headerColors = UIKit.Colors[props.Header or "Blue"]
	local header = UIKit.Frame(inner, {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 74),
		Color = UIKit.White,
		Corner = 16,
	})
	UIKit.Gradient(header, headerColors[1], headerColors[2], 90)
	-- tira o arredondado de baixo do cabeçalho
	local headerFix = UIKit.Frame(header, { Name = "Fix", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16), Color = UIKit.White, Corner = false })
	UIKit.Gradient(headerFix, headerColors[2]:Lerp(headerColors[1], 0.15), headerColors[2], 90)
	-- listras diagonais claras (como nas referências)
	for i = 0, 5 do
		local stripe = UIKit.Frame(header, {
			Name = "Stripe",
			Size = UDim2.new(0, 46, 1.6, 0),
			Position = UDim2.new(0.45 + i * 0.09, 0, -0.3, 0),
			Color = UIKit.White,
			Transparency = 0.9,
			Corner = false,
		})
		stripe.Rotation = 25
	end
	header.ClipsDescendants = true

	local title = UIKit.Text(header, {
		Name = "Title",
		Text = props.Title or name,
		Size = UDim2.new(0.6, 0, 0, 58),
		Position = UDim2.new(0, 20, 0, 8),
		Align = Enum.TextXAlignment.Left,
		Stroke = 4,
		Max = 54,
	})

	local body = UIKit.Frame(inner, {
		Name = "Body",
		Size = UDim2.new(1, -28, 1, -100),
		Position = UDim2.fromOffset(14, 88),
		Transparency = 1,
		Corner = false,
	})

	local window = { Gui = gui, Root = root, Inner = inner, Header = header, Body = body, Title = title, IsOpen = false }
	window.Opened = Instance.new("BindableEvent")
	window.Closed = Instance.new("BindableEvent")

	local close = UIKit.Button(root, {
		Name = "Close",
		Text = "X",
		Color = "Red",
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(1, -8, 0, 7),
		AnchorPoint = Vector2.new(1, 0),
		Max = 44,
		ZIndex = 5,
	})

	function window.Open(...)
		UIKit.CloseAll(name)
		window.IsOpen = true
		root.Visible = true
		animScale.Scale = 0.85
		UIKit.Tween(animScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
		window.Opened:Fire(...)
	end

	function window.Close()
		if not window.IsOpen then
			return
		end
		window.IsOpen = false
		root.Visible = false
		window.Closed:Fire()
	end

	function window.Toggle()
		if window.IsOpen then
			window.Close()
		else
			window.Open()
		end
	end

	close.Activated:Connect(window.Close)
	UIKit.Windows[name] = window
	window.AutoScale = autoScale
	return window
end

-- Lista com rolagem (as linhas entram em ordem de LayoutOrder)
function UIKit.Scroll(parent, props)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = props.Name or "Scroll"
	scroll.Size = props.Size or UDim2.fromScale(1, 1)
	scroll.Position = props.Position or UDim2.new()
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 140)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = parent
	if props.Grid then
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = props.Grid
		grid.CellPadding = props.GridPadding or UDim2.fromOffset(10, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = scroll
	else
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, props.Padding or 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Parent = scroll
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = scroll
	return scroll
end

function UIKit.Clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Peixe 3D num quadrinho. entry = { S, M, Z }. props: Size, Position, Silhouette, Rotation
function UIKit.Viewport(parent, entry, props)
	props = props or {}
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.BackgroundTransparency = 1
	viewport.Size = props.Size or UDim2.fromScale(1, 1)
	viewport.Position = props.Position or UDim2.new()
	viewport.AnchorPoint = props.AnchorPoint or Vector2.new()
	viewport.Ambient = Color3.fromRGB(170, 170, 180)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
	viewport.ZIndex = props.ZIndex or 1
	viewport.LayoutOrder = props.LayoutOrder or 0

	local model = FishModel.Build(entry.S, entry.M or "Normal", entry.Z or "Normal", { Saddle = false, Scale = 1 })
	model:PivotTo(CFrame.Angles(0, math.rad(props.Rotation or 75), 0))
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = 28
	local length = model:GetAttribute("Length") or 10
	camera.CFrame = CFrame.lookAt(Vector3.new(0, length * 0.35, length * 1.9 + 2), Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	if props.Silhouette then
		viewport.ImageColor3 = Color3.fromRGB(10, 10, 16)
		viewport.Ambient = Color3.new(0, 0, 0)
		viewport.LightColor = Color3.new(0, 0, 0)
	end
	viewport.Parent = parent
	return viewport
end

-- Caixa de confirmação
local confirmGui
function UIKit.Confirm(text, yesText, onYes, color)
	if confirmGui then
		confirmGui:Destroy()
	end
	confirmGui = UIKit.Gui("Confirm", 30)
	local shade = UIKit.Frame(confirmGui, { Color = Color3.new(0, 0, 0), Transparency = 0.5, Corner = false })
	shade.Active = true
	local box = UIKit.Frame(confirmGui, {
		Size = UDim2.fromOffset(520, 260),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = UIKit.Panel,
		Corner = 16,
		Stroke = 5,
	})
	UIKit.AutoScale(box, Vector2.new(520, 260))
	UIKit.Text(box, { Text = text, Size = UDim2.new(1, -40, 0, 130), Position = UDim2.fromOffset(20, 20), Max = 34 })
	local gui = confirmGui
	UIKit.Button(box, {
		Text = "Cancelar",
		Color = "Gray",
		Size = UDim2.fromOffset(200, 64),
		Position = UDim2.new(0.5, -10, 1, -24),
		AnchorPoint = Vector2.new(1, 1),
		OnClick = function()
			gui:Destroy()
		end,
	})
	UIKit.Button(box, {
		Text = yesText or "Sim",
		Color = color or "Green",
		Size = UDim2.fromOffset(200, 64),
		Position = UDim2.new(0.5, 10, 1, -24),
		AnchorPoint = Vector2.new(0, 1),
		OnClick = function()
			gui:Destroy()
			onYes()
		end,
	})
end

return UIKit
