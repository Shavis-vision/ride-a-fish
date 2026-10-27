-- HUD (LocalScript)
-- Fica em: StarterPlayerScripts > Client > HUD
--
-- A tela fixa do jogo, no estilo das referências:
--   * à esquerda, os botões grandes LOJA (rosa) e ÍNDEX (azul). Na esteira, o ÍNDEX vira a
--     oferta do multiplicador de stamina por Robux (Config.TREADMILL_OFFER);
--   * embaixo à esquerda, a stamina (⚡) e o dinheiro (💵), cada um com o botão verde "+";
--   * à direita, o botão laranja do AQUÁRIO (seus peixes);
--   * em cima, os avisos que o servidor manda.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer
local gui = UIKit.Gui("HUD", 2)

-- Botões da esquerda ---------------------------------------------------------------------
local Config = require(Shared:WaitForChild("Config"))
local ROBUX = utf8.char(0xE002)

local left = UIKit.Frame(gui, {
	Name = "Left",
	Size = UDim2.fromOffset(280, 196),
	Position = UDim2.new(0, 22, 0.5, -20),
	AnchorPoint = Vector2.new(0, 0.5),
	Transparency = 1,
	Corner = false,
})
UIKit.AutoScale(left)
UIKit.Button(left, {
	Name = "Shop",
	Text = "Loja",
	Icon = "🎁",
	Color = "Pink",
	Style = "Hud",
	Size = UDim2.fromOffset(270, 88),
	Studs = true,
	Max = 50,
	IconWidth = 0.3,
	OnClick = function()
		if UIKit.IsOpen("Shop") then
			UIKit.Windows.Shop.Close()
		else
			UIKit.OpenWindow("Shop")
		end
	end,
})
local indexButton = UIKit.Button(left, {
	Name = "Index",
	Text = "Índex",
	Icon = "📘",
	Color = "Blue",
	Style = "Hud",
	Size = UDim2.fromOffset(270, 88),
	Studs = true,
	Position = UDim2.fromOffset(0, 104),
	Max = 50,
	IconWidth = 0.3,
	OnClick = function()
		if UIKit.IsOpen("Index") then
			UIKit.Windows.Index.Close()
		else
			UIKit.OpenWindow("Index")
		end
	end,
})

-- Oferta da esteira: enquanto você treina, o botão do Índex vira o atalho para comprar o
-- multiplicador de stamina por Robux (como na referência "x8 Stamina ONLY 24").
-- Qual passe aparece está em Config.TREADMILL_OFFER.
local offerPass
for _, pass in ipairs(Config.GAMEPASSES) do
	if pass.Key == Config.TREADMILL_OFFER then
		offerPass = pass
	end
end
local offerButton = UIKit.Button(left, {
	Name = "OfertaEsteira",
	Text = "",
	Icon = "⚡",
	Color = "Cyan",
	Style = "Hud",
	Size = UDim2.fromOffset(270, 88),
	Studs = true,
	Position = UDim2.fromOffset(0, 104),
	IconWidth = 0.3,
	OnClick = function()
		if offerPass then
			ClientState.Request("BuyPass", offerPass.Key)
		end
	end,
})
offerButton.Visible = false
local offerLabel = offerButton:FindFirstChild("Label")
offerLabel.Size = UDim2.new(0.7, -10, 0.5, 0)
offerLabel.Position = UDim2.new(0.3, 4, 0.06, 0)
offerLabel.Text = offerPass and offerPass.Name:gsub("Stamina x(%d+)", "x%1 Stamina") or ""
local offerPrice = UIKit.Text(offerButton, {
	Name = "Preco",
	Text = offerPass and ("SÓ " .. ROBUX .. " " .. offerPass.Price) or "",
	Size = UDim2.new(0.7, -10, 0.4, 0),
	Position = UDim2.new(0.3, 4, 0.54, 0),
	Color = UIKit.MoneyGreen,
	Max = 40,
	Stroke = 3.5,
	ZIndex = offerButton.ZIndex + 1,
})
offerPrice:FindFirstChildOfClass("UIStroke").Color = Color3.new(0, 0, 0)

local function updateOffer()
	local training = player:GetAttribute("Training") == true
	local data = ClientState.Data
	local owned = offerPass == nil or (data and data.Passes and data.Passes[offerPass.Key]) == true
	local show = training and not owned
	offerButton.Visible = show
	indexButton.Visible = not show
end
ClientState.Changed.Event:Connect(updateOffer)
updateOffer()

-- Botão do aquário (direita) -------------------------------------------------------------
local right = UIKit.Frame(gui, {
	Name = "Right",
	Size = UDim2.fromOffset(100, 110),
	Position = UDim2.new(1, -22, 0.5, -20),
	AnchorPoint = Vector2.new(1, 0.5),
	Transparency = 1,
	Corner = false,
})
UIKit.AutoScale(right)
local aquariumButton = UIKit.Button(right, {
	Name = "Aquarium",
	Text = "",
	Color = "Orange",
	Style = "Hud",
	Size = UDim2.fromOffset(96, 106),
	Studs = true,
	OnClick = function()
		if UIKit.IsOpen("Aquarium") then
			UIKit.Windows.Aquarium.Close()
		else
			UIKit.OpenWindow("Aquarium")
		end
	end,
})
UIKit.Text(aquariumButton, { Text = "🐟", Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Stroke = 3 })
local badge = UIKit.Frame(aquariumButton, {
	Name = "Badge",
	Size = UDim2.fromOffset(34, 34),
	Position = UDim2.new(1, 8, 0, -8),
	AnchorPoint = Vector2.new(1, 0),
	Color = Color3.fromRGB(230, 40, 50),
	Corner = 17,
	Stroke = 2.5,
	StrokeColor = Color3.new(0, 0, 0),
	ZIndex = 4,
})
local badgeText = UIKit.Text(badge, { Text = "!", ZIndex = 5, Stroke = 1.5 })
badge.Visible = false

-- Stamina e dinheiro (embaixo à esquerda) ---------------------------------------------------
local stats = UIKit.Frame(gui, {
	Name = "Stats",
	Size = UDim2.fromOffset(310, 160),
	Position = UDim2.new(0, 22, 1, -18),
	AnchorPoint = Vector2.new(0, 1),
	Transparency = 1,
	Corner = false,
})
UIKit.AutoScale(stats)

-- barra cinza com ícone grande à esquerda e o "+" verde ao lado (igual à referência)
local function statBar(y, icon, color, onPlus)
	local bar = UIKit.Frame(stats, {
		Size = UDim2.fromOffset(234, 66),
		Position = UDim2.fromOffset(0, y),
		Color = Color3.new(1, 1, 1),
		Transparency = 0.12,
		Corner = 4,
		Stroke = 4,
		StrokeColor = Color3.new(0, 0, 0),
	})
	UIKit.Gradient(bar, Color3.fromRGB(120, 120, 124), Color3.fromRGB(72, 72, 78), 90)
	UIKit.Studs(bar, Vector2.new(234, 66), { Spacing = 22, Transparency = 0.9, EdgeTransparency = 0.85 })
	local iconLabel = UIKit.Text(bar, { Text = icon, Size = UDim2.fromOffset(62, 62), Position = UDim2.new(0, -10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Stroke = 3, ZIndex = 2 })
	iconLabel:FindFirstChildOfClass("UIStroke").Color = Color3.new(0, 0, 0)
	local value = UIKit.Text(bar, {
		Name = "Value",
		Text = "0",
		Size = UDim2.new(1, -66, 0, 52),
		Position = UDim2.fromOffset(58, 7),
		Align = Enum.TextXAlignment.Left,
		Color = color,
		Stroke = 3.5,
		Max = 46,
		ZIndex = 2,
	})
	value:FindFirstChildOfClass("UIStroke").Color = Color3.new(0, 0, 0)
	UIKit.Button(stats, {
		Text = "+",
		Color = "Lime",
		Style = "Hud",
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(248, y + 5),
		Max = 50,
		OnClick = onPlus,
	})
	return bar, value
end

local staminaBar, staminaText = statBar(0, "⚡", UIKit.White, function()
	UIKit.OpenWindow("Shop", "Gamepasses")
end)
local _, moneyText = statBar(82, "💵", UIKit.MoneyGreen, function()
	UIKit.OpenWindow("Shop", "Dinheiro")
end)
local rateText = UIKit.Text(staminaBar, {
	Name = "Rate",
	Text = "",
	Size = UDim2.new(1, 0, 0, 24),
	Position = UDim2.new(0, 0, 0, -28),
	Align = Enum.TextXAlignment.Left,
	Color = UIKit.StaminaYellow,
	Max = 22,
})

-- números sobem suavemente até o valor real
local shownMoney, shownStamina = 0, 0
RunService.RenderStepped:Connect(function(dt)
	local money = ClientState.Stat("Money")
	local stamina = ClientState.Stat("Stamina")
	local k = 1 - math.exp(-dt * 10)
	shownMoney += (money - shownMoney) * k
	shownStamina += (stamina - shownStamina) * k
	if math.abs(money - shownMoney) < 1 then
		shownMoney = money
	end
	if math.abs(stamina - shownStamina) < 1 then
		shownStamina = stamina
	end
	moneyText.Text = NumberFormat.Money(shownMoney)
	staminaText.Text = NumberFormat.Abbreviate(shownStamina)
end)

-- treinando na esteira: "+X/s" e números subindo
local popupClock = 0
RunService.Heartbeat:Connect(function(dt)
	local training = player:GetAttribute("Training") == true
	updateOffer()
	rateText.Text = training and ("Treinando: +" .. NumberFormat.Rate(ClientState.Stat("StaminaRate")) .. "/s") or ""
	if training then
		popupClock += dt
		if popupClock >= 0.5 then
			popupClock = 0
			local popup = UIKit.Text(stats, {
				Text = "+" .. NumberFormat.Rate(ClientState.Stat("StaminaRate") * 0.5) .. " ⚡",
				Size = UDim2.fromOffset(140, 34),
				Position = UDim2.fromOffset(150 + math.random(-30, 30), -30),
				Color = UIKit.StaminaYellow,
				Max = 30,
			})
			UIKit.Tween(popup, 0.9, { Position = popup.Position - UDim2.fromOffset(0, 60), TextTransparency = 1 })
			local stroke = popup:FindFirstChildOfClass("UIStroke")
			if stroke then
				UIKit.Tween(stroke, 0.9, { Transparency = 1 })
			end
			task.delay(0.95, function()
				popup:Destroy()
			end)
		end
	end
end)

-- esconde os botões durante a corrida
local function updateRunning()
	local running = player:GetAttribute("Running") == true
	left.Visible = not running
	right.Visible = not running
	if running then
		UIKit.CloseAll()
	end
end
player:GetAttributeChangedSignal("Running"):Connect(updateRunning)
updateRunning()

-- bolinha vermelha no aquário (vaga livre e peixe guardado) e no índex (prêmio para pegar)
local indexBadge = badge:Clone()
indexBadge.Position = UDim2.new(1, 8, 0, -8)
indexBadge.Parent = indexButton
local Fish = require(Shared:WaitForChild("Fish"))
ClientState.Changed.Event:Connect(function(data)
	local free = data.Slots - #data.Aquarium
	local stored = #data.Fish - #data.Aquarium
	badge.Visible = free > 0 and stored > 0
	badgeText.Text = tostring(math.min(free, stored))

	local claimable = 0
	for _, rec in pairs(data.Index) do
		if rec.F and not rec.C then
			claimable += 1
		end
	end
	for area, list in pairs(Fish.ByArea) do
		if not data.Areas[tostring(area)] then
			local complete = true
			for _, species in ipairs(list) do
				local rec = data.Index[species.Id]
				if not rec or not rec.F then
					complete = false
					break
				end
			end
			if complete then
				claimable += 1
			end
		end
	end
	indexBadge.Visible = claimable > 0
	indexBadge.Text.Text = tostring(claimable)
end)

-- Avisos ------------------------------------------------------------------------------------
local toasts = UIKit.Frame(gui, {
	Name = "Toasts",
	Size = UDim2.fromOffset(640, 300),
	Position = UDim2.new(0.5, 0, 0, 70),
	AnchorPoint = Vector2.new(0.5, 0),
	Transparency = 1,
	Corner = false,
})
UIKit.AutoScale(toasts)
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = toasts

local TOAST_COLORS = {
	info = Color3.fromRGB(255, 255, 255),
	ok = Color3.fromRGB(110, 255, 110),
	erro = Color3.fromRGB(255, 100, 90),
	raro = Color3.fromRGB(255, 215, 70),
}
local order = 0
ClientState.ToastEvent.Event:Connect(function(text, kind)
	order += 1
	local label = UIKit.Text(toasts, {
		Text = text,
		Size = UDim2.fromOffset(640, kind == "raro" and 46 or 38),
		Color = TOAST_COLORS[kind] or TOAST_COLORS.info,
		LayoutOrder = order,
		Stroke = 3,
		Max = kind == "raro" and 40 or 32,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = label
	UIKit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	local children = toasts:GetChildren()
	local count = 0
	for _, child in ipairs(children) do
		if child:IsA("TextLabel") then
			count += 1
		end
	end
	if count > 5 then
		for _, child in ipairs(children) do
			if child:IsA("TextLabel") and child.LayoutOrder <= order - 5 then
				child:Destroy()
			end
		end
	end
	task.delay(3.2, function()
		if label.Parent then
			UIKit.Tween(label, 0.4, { TextTransparency = 1 })
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				UIKit.Tween(stroke, 0.4, { Transparency = 1 })
			end
			task.delay(0.45, function()
				label:Destroy()
			end)
		end
	end)
end)
