-- ShopUI (LocalScript)
-- Fica em: StarterPlayerScripts > Client > ShopUI
--
-- A LOJA (Robux): gamepasses (Dinheiro x2, Stamina x2) e pacotes de dinheiro.
-- Abre pelo botão Loja e pelos botões verdes "+" da stamina e do dinheiro.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local ROBUX = utf8.char(0xE002) .. " " -- ícone do Robux nas fontes do Roblox

local window = UIKit.Window("Shop", { Title = "Shop", Size = Vector2.new(940, 620), Header = "Blue" })
local scroll = UIKit.Scroll(window.Body, { Padding = 14 })

local PASS_STYLE = {
	MoneyX2 = { Icon = "💰", Color = "Teal", Accent = UIKit.MoneyGreen },
	StaminaX2 = { Icon = "⚡", Color = "Gold", Accent = UIKit.StaminaYellow },
	StaminaX4 = { Icon = "⚡", Color = "Orange", Accent = UIKit.StaminaYellow },
	StaminaX6 = { Icon = "⚡", Color = "Red", Accent = UIKit.StaminaYellow },
	StaminaX8 = { Icon = "⚡", Color = "Purple", Accent = UIKit.StaminaYellow },
}
local Progression = require(Shared:WaitForChild("Progression"))

local sections = {}
local passButtons = {}
local cashLabels = {}

local function sectionTitle(text, order)
	local label = UIKit.Text(scroll, {
		Name = text,
		Text = string.upper(text),
		Size = UDim2.new(1, -20, 0, 46),
		Color = UIKit.MoneyGreen,
		LayoutOrder = order,
		Stroke = 3.5,
		Max = 42,
	})
	sections[text] = label
	return label
end

-- Gamepasses
sectionTitle("Gamepasses", 1)
for i, pass in ipairs(Config.GAMEPASSES) do
	local style = PASS_STYLE[pass.Key] or { Icon = "⭐", Color = "Blue", Accent = UIKit.White }
	local card = UIKit.Frame(scroll, {
		Name = pass.Key,
		Size = UDim2.new(1, -20, 0, 170),
		Color = UIKit.White,
		LayoutOrder = 1 + i,
		Corner = 12,
		Stroke = 4,
	})
	local colors = UIKit.Colors[style.Color]
	UIKit.Gradient(card, colors[1], colors[2], 20)
	UIKit.Text(card, { Text = style.Icon, Size = UDim2.fromOffset(130, 130), Position = UDim2.fromOffset(20, 20), Stroke = 2 })
	UIKit.Text(card, {
		Text = pass.Name,
		Size = UDim2.new(0.5, 0, 0, 62),
		Position = UDim2.fromOffset(170, 18),
		Align = Enum.TextXAlignment.Left,
		Stroke = 4,
		Max = 56,
	})
	UIKit.Text(card, {
		Text = pass.Desc,
		Size = UDim2.new(0.48, 0, 0, 60),
		Position = UDim2.fromOffset(170, 88),
		Align = Enum.TextXAlignment.Left,
		Max = 26,
	})
	local button = UIKit.Button(card, {
		Text = ROBUX .. pass.Price,
		Color = "Green",
		Size = UDim2.fromOffset(200, 72),
		Position = UDim2.new(1, -22, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Max = 40,
		OnClick = function()
			ClientState.Request("BuyPass", pass.Key)
		end,
	})
	passButtons[pass.Key] = { Button = button, Pass = pass }
end

-- Pacotes de dinheiro
sectionTitle("Cash", 10)
local grid = UIKit.Frame(scroll, { Name = "CashGrid", Size = UDim2.new(1, -20, 0, 230), Transparency = 1, LayoutOrder = 11, Corner = false })
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(1 / 3, -10, 1, 0)
gridLayout.CellPadding = UDim2.fromOffset(12, 0)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local cashIcons = { "💵", "💰", "🏦" }
local order = 0
for _, product in ipairs(Config.PRODUCTS) do
	if product.Minutes then
		order += 1
		local card = UIKit.Frame(grid, { Name = product.Key, Color = UIKit.White, LayoutOrder = order, Corner = 12, Stroke = 4 })
		UIKit.Gradient(card, UIKit.Colors.Blue[1], UIKit.Colors.Blue[2], 90)
		UIKit.Text(card, { Text = cashIcons[order] or "💵", Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 10), Stroke = 2 })
		local amount = UIKit.Text(card, {
			Text = "+$0",
			Size = UDim2.new(1, -16, 0, 44),
			Position = UDim2.fromOffset(8, 92),
			Color = UIKit.MoneyGreen,
			Stroke = 3.5,
			Max = 40,
		})
		cashLabels[product.Key] = { Label = amount, Product = product }
		UIKit.Button(card, {
			Text = ROBUX .. product.Price,
			Color = "Green",
			Size = UDim2.new(1, -30, 0, 60),
			Position = UDim2.new(0.5, 0, 1, -14),
			AnchorPoint = Vector2.new(0.5, 1),
			Max = 34,
			OnClick = function()
				ClientState.Request("BuyProduct", product.Key)
			end,
		})
	end
end

UIKit.Text(scroll, {
	Text = "Packs grow with your income.",
	Size = UDim2.new(1, -20, 0, 30),
	LayoutOrder = 20,
	Color = Color3.fromRGB(190, 190, 200),
	Max = 22,
	Stroke = 1.5,
})

local function refresh()
	local data = ClientState.Data
	local passes = data and data.Passes or {}
	for key, info in pairs(passButtons) do
		local label = info.Button:FindFirstChild("Label")
		local previous = Progression.PreviousLadderPass(info.Pass)
		if passes[key] then
			label.Text = "OWNED"
			UIKit.SetButtonColor(info.Button, "Gray")
		elseif previous and not passes[previous.Key] then
			label.Text = "🔒 " .. previous.Name:gsub("Stamina ", "")
			UIKit.SetButtonColor(info.Button, "Gray")
		else
			label.Text = ROBUX .. info.Pass.Price
			UIKit.SetButtonColor(info.Button, "Green")
		end
	end
	local income = ClientState.Stat("Income")
	for _, info in pairs(cashLabels) do
		local p = info.Product
		local amount = math.max(p.Minimum or 0, math.floor(income * 60 * p.Minutes))
		info.Label.Text = "+" .. NumberFormat.Money(amount)
	end
end

ClientState.Changed.Event:Connect(refresh)
window.Opened.Event:Connect(function(section)
	refresh()
	local target = section and sections[section]
	if target then
		task.defer(function()
			scroll.CanvasPosition = Vector2.new(0, math.max(0, target.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 6))
		end)
	else
		scroll.CanvasPosition = Vector2.new()
	end
end)
