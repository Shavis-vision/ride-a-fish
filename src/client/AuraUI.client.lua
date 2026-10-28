-- AuraUI (LocalScript)
-- Fica em: StarterPlayerScripts > Client > AuraUI
--
-- Barraca das AURAS (abre ao pisar no anel roxo na frente do balcão), no estilo da
-- referência: cartões coloridos lado a lado, cada um com o boneco da aura, o multiplicador
-- de stamina e o botão. Cada aura nova é melhor que a anterior (+0.5) e só se compra com
-- dinheiro do jogo, em ordem. As antigas podem ser equipadas só pelo visual: o bônus é
-- sempre o da MELHOR aura comprada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared:WaitForChild("Progression"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local window = UIKit.Window("Aura", { Title = "AURAS", Icon = "⚡", Center = true, Size = Vector2.new(1100, 660), Header = "Lavender" })
local body = window.Body

local CARD = Vector2.new(240, 410)

local strip = Instance.new("ScrollingFrame")
strip.Name = "Cards"
strip.Size = UDim2.new(1, 0, 0, CARD.Y + 22)
strip.BackgroundTransparency = 1
strip.BorderSizePixel = 0
strip.ScrollBarThickness = 8
strip.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 190)
strip.ScrollingDirection = Enum.ScrollingDirection.X
strip.AutomaticCanvasSize = Enum.AutomaticSize.X
strip.CanvasSize = UDim2.new()
strip.Parent = body
local stripLayout = Instance.new("UIListLayout")
stripLayout.FillDirection = Enum.FillDirection.Horizontal
stripLayout.Padding = UDim.new(0, 14)
stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
stripLayout.Parent = strip
local stripPad = Instance.new("UIPadding")
stripPad.PaddingLeft = UDim.new(0, 6)
stripPad.PaddingTop = UDim.new(0, 4)
stripPad.Parent = strip

-- parte de baixo: tirar a aura (só visual) e o aviso do bônus
local bottom = UIKit.Frame(body, { Name = "Bottom", Size = UDim2.new(1, 0, 0, 118), Position = UDim2.new(0, 0, 1, -118), Transparency = 1, Corner = false })
UIKit.Text(bottom, { Text = "EQUIPPED AURA • THE LOOK IS COSMETIC ONLY", Size = UDim2.new(1, 0, 0, 36), Max = 32, Stroke = 3 })
local noneButton, noneLabel = UIKit.Button(bottom, {
	Text = "No aura",
	Color = "Green",
	Size = UDim2.fromOffset(250, 62),
	Position = UDim2.fromOffset(20, 48),
	Max = 32,
	OnClick = function()
		ClientState.Request("EquipAura", 0)
	end,
})
UIKit.Text(bottom, {
	Text = "The treadmill bonus always comes from the best aura you bought.",
	Size = UDim2.new(1, -300, 0, 50),
	Position = UDim2.fromOffset(290, 54),
	Align = Enum.TextXAlignment.Left,
	Max = 28,
	Stroke = 2.5,
})

-- boneco de blocos com a aura (dentro de um ViewportFrame)
local function auraFigure(parent, color, locked)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(190, 190, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.7)
	viewport.ZIndex = 3
	viewport.Parent = parent
	local model = Instance.new("Model")
	local bodyColor = color:Lerp(Color3.new(1, 1, 1), 0.15)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.25)
	local function block(size, position, partColor, transparency)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = size
		part.CFrame = CFrame.new(position)
		part.Color = partColor
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.Parent = model
		return part
	end
	block(Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), bodyColor)
	block(Vector3.new(1.25, 1.25, 1.25), Vector3.new(0, 1.65, 0), bodyColor)
	block(Vector3.new(1, 2, 1), Vector3.new(-1.55, 0.1, 0.1), dark)
	block(Vector3.new(1, 2, 1), Vector3.new(1.55, -0.1, -0.1), dark)
	block(Vector3.new(0.95, 2, 1), Vector3.new(-0.5, -2, 0.15), dark)
	block(Vector3.new(0.95, 2, 1), Vector3.new(0.5, -2, -0.15), dark)
	-- "chamas" da aura em volta
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		local radius = 2.2 + (i % 3) * 0.25
		local flame = block(Vector3.new(0.45, 1.4 + (i % 4) * 0.5, 0.45), Vector3.new(math.cos(angle) * radius, -0.6 + (i % 5) * 0.7, math.sin(angle) * radius * 0.5), color, 0.25)
		flame.CFrame *= CFrame.Angles(0, 0, math.cos(angle) * 0.4)
	end
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(3.2, 1.2, 9), Vector3.new(0, -0.3, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	if locked then
		viewport.ImageColor3 = Color3.fromRGB(70, 70, 80)
	end
	return viewport
end

local function render()
	if not window.IsOpen then
		return
	end
	UIKit.Clear(strip)
	local data = ClientState.Data
	if not data then
		return
	end
	local money = ClientState.Stat("Money")
	noneLabel.Text = data.Aura == 0 and "✓ No aura" or "No aura"
	UIKit.SetButtonColor(noneButton, data.Aura == 0 and "Gray" or "Green")

	for i, aura in ipairs(Progression.Auras) do
		local owned = i <= data.BestAura
		local isNext = i == data.BestAura + 1
		local locked = not owned and not isNext

		local card = UIKit.Frame(strip, {
			Name = "Aura" .. i,
			Size = UDim2.fromOffset(CARD.X, CARD.Y),
			Color = UIKit.White,
			LayoutOrder = i,
			Corner = 8,
			Stroke = data.Aura == i and 5 or 4,
			StrokeColor = data.Aura == i and UIKit.White or UIKit.Dark,
		})
		local top = locked and Color3.fromRGB(110, 110, 120) or aura.Color:Lerp(Color3.new(1, 1, 1), 0.3)
		local bottomColor = locked and Color3.fromRGB(60, 60, 70) or aura.Color:Lerp(Color3.new(0, 0, 0), 0.15)
		UIKit.Gradient(card, top, bottomColor, 90)
		UIKit.Studs(card, CARD, { Spacing = 30, Transparency = 0.85, EdgeTransparency = 0.8 })

		UIKit.Text(card, { Text = aura.Name, Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 8), Max = 28, Stroke = 3, ZIndex = 2 })
		local status, statusColor
		if data.Aura == i then
			status, statusColor = "Equipped", UIKit.MoneyGreen
		elseif owned then
			status, statusColor = "Owned", UIKit.MoneyGreen
		elseif isNext then
			status, statusColor = "Next", UIKit.StaminaYellow
		else
			status, statusColor = "Locked", Color3.fromRGB(200, 200, 210)
		end
		UIKit.Text(card, {
			Text = ('Nv %d <font color="#%s">%s</font>'):format(i, statusColor:ToHex(), status),
			Rich = true,
			Size = UDim2.new(1, -16, 0, 28),
			Position = UDim2.fromOffset(8, 40),
			Max = 26,
			Stroke = 2.5,
			ZIndex = 2,
		})

		local picture = UIKit.Frame(card, {
			Size = UDim2.new(1, -24, 0, 196),
			Position = UDim2.fromOffset(12, 74),
			Color = Color3.fromRGB(246, 236, 212),
			Corner = 6,
			Stroke = 3,
			ZIndex = 2,
		})
		auraFigure(picture, aura.Color, locked)
		if locked then
			UIKit.Text(picture, { Text = "🔒", Size = UDim2.fromOffset(70, 70), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 1.5, ZIndex = 5 })
		end

		local multBar = UIKit.Frame(card, {
			Size = UDim2.new(1, -24, 0, 46),
			Position = UDim2.fromOffset(12, 280),
			Color = Color3.fromRGB(20, 20, 26),
			Transparency = 0.45,
			Corner = 6,
			ZIndex = 2,
		})
		UIKit.Text(multBar, {
			Text = ('<font color="#5AFF5A">x%s</font> Stamina'):format(tostring(aura.Mult)),
			Rich = true,
			Size = UDim2.new(1, -10, 1, -6),
			Position = UDim2.fromOffset(5, 3),
			Max = 36,
			Stroke = 3,
			ZIndex = 3,
		})

		local text, color, action
		if data.Aura == i then
			text, color = "Equipped", "Gray"
		elseif owned then
			text, color, action = "Equip", "Green", "EquipAura"
		elseif isNext then
			text = NumberFormat.Money(aura.Price)
			color = money >= aura.Price and "Green" or "Red"
			action = "BuyAura"
		else
			text, color = NumberFormat.Money(aura.Price), "Gray"
		end
		UIKit.Button(card, {
			Text = text,
			Color = color,
			Size = UDim2.new(1, -24, 0, 58),
			Position = UDim2.fromOffset(12, 340),
			Max = 34,
			ZIndex = 3,
			OnClick = function()
				if action then
					ClientState.Request(action, i)
				elseif locked then
					ClientState.Toast("Buy the previous aura first", "info")
				end
			end,
		})
	end
end

window.Opened.Event:Connect(render)
ClientState.Changed.Event:Connect(render)
