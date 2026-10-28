-- AquariumUI (LocalScript)
-- Fica em: StarterPlayerScripts > Client > AquariumUI
--
-- Painel lateral do AQUÁRIO (botão laranja 🐟), no estilo da referência: aparece do lado
-- direito e mostra SÓ os peixes que estão no aquário rendendo dinheiro, com o botão "Remove".
-- Os peixes guardados ficam na mochila do Roblox (barra de baixo): segure um e clique para
-- colocar no aquário. "Place best" enche o aquário com os que mais rendem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local SIZE = Vector2.new(470, 520)
local gui = UIKit.Gui("AquariumPanel", 6)

local holder = UIKit.Frame(gui, {
	Name = "Holder",
	Size = UDim2.fromOffset(SIZE.X + 60, SIZE.Y + 110),
	Position = UDim2.new(1, -130, 0.5, -10),
	AnchorPoint = Vector2.new(1, 0.5),
	Transparency = 1,
	Corner = false,
})
UIKit.AutoScale(holder)
holder.Visible = false

local panel = UIKit.Frame(holder, {
	Name = "Panel",
	Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
	Position = UDim2.fromOffset(60, 0),
	Color = Color3.fromRGB(26, 26, 32),
	Transparency = UIKit.PanelTransparency,
	Corner = 12,
	Stroke = 5,
})
UIKit.Studs(panel, SIZE, { Spacing = 30, Transparency = 0.93 })

local countLabel = UIKit.Text(panel, { Text = "0/4 in aquarium", Size = UDim2.new(0.62, 0, 0, 50), Position = UDim2.fromOffset(16, 10), Align = Enum.TextXAlignment.Left, Max = 44, Stroke = 3.5, ZIndex = 2 })
local storedLabel = UIKit.Text(panel, {
	Text = "0 in backpack",
	Size = UDim2.new(0.34, 0, 0, 30),
	Position = UDim2.new(1, -14, 0, 20),
	AnchorPoint = Vector2.new(1, 0),
	Align = Enum.TextXAlignment.Right,
	Max = 26,
	ZIndex = 2,
})

local list = UIKit.Scroll(panel, { Size = UDim2.new(1, -20, 1, -76), Position = UDim2.fromOffset(10, 68), Padding = 6 })
local empty = UIKit.Text(panel, {
	Text = "",
	Size = UDim2.new(1, -40, 0, 110),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Color = Color3.fromRGB(205, 205, 215),
	Max = 26,
	ZIndex = 2,
})

-- seta para fechar (à esquerda do painel, como na referência)
UIKit.Button(holder, {
	Text = ">",
	Color = "Red",
	Size = UDim2.fromOffset(48, 64),
	Position = UDim2.fromOffset(4, SIZE.Y / 2 - 32),
	Max = 40,
	OnClick = function()
		holder.Visible = false
	end,
})

UIKit.Button(holder, {
	Text = "Place best",
	Color = "Green",
	Size = UDim2.fromOffset(300, 62),
	Position = UDim2.new(0, 60 + SIZE.X, 0, SIZE.Y + 8),
	AnchorPoint = Vector2.new(1, 0),
	Max = 34,
	Studs = true,
	OnClick = function()
		ClientState.Request("EquipBest")
	end,
})
UIKit.Text(holder, {
	Text = "Hold a fish from your backpack and click to place it",
	Size = UDim2.fromOffset(SIZE.X, 30),
	Position = UDim2.fromOffset(60, SIZE.Y + 74),
	Max = 22,
	Stroke = 2,
})

local function row(entry, order)
	local species = Fish.Get(entry.S)
	if not species then
		return
	end
	local rarity = Fish.Rarities[species.Rarity]
	local frame = UIKit.Frame(list, {
		Name = "Fish" .. entry.Uid,
		Size = UDim2.new(1, -8, 0, 80),
		Color = Color3.fromRGB(14, 14, 18),
		Transparency = 0.2,
		LayoutOrder = order,
		Corner = 6,
		Stroke = 2,
		StrokeColor = Color3.fromRGB(60, 60, 72),
	})
	-- faixa colorida embaixo (cor da mutação ou da raridade), como nas referências
	local stripe = UIKit.Frame(frame, {
		Size = UDim2.new(1, -8, 0, 4),
		Position = UDim2.new(0, 4, 1, -6),
		Color = entry.M ~= "Normal" and Fish.Mutations[entry.M].Color or rarity.Color,
		Corner = 2,
	})
	stripe.ZIndex = 2
	UIKit.Viewport(frame, entry, { Size = UDim2.fromOffset(78, 72), Position = UDim2.fromOffset(4, 2), ZIndex = 2 })
	UIKit.Text(frame, {
		Text = species.Name,
		Size = UDim2.new(0.5, 0, 0, 26),
		Position = UDim2.fromOffset(90, 4),
		Align = Enum.TextXAlignment.Left,
		Max = 24,
		Stroke = 2,
		ZIndex = 2,
	})
	local tags = Fish.Tags(entry)
	UIKit.Text(frame, {
		Text = string.upper(tags ~= "" and tags or rarity.Name),
		Size = UDim2.new(0.5, 0, 0, 18),
		Position = UDim2.fromOffset(90, 30),
		Align = Enum.TextXAlignment.Left,
		Color = entry.M ~= "Normal" and Fish.Mutations[entry.M].Color or rarity.Color,
		Max = 18,
		Stroke = 1.5,
		ZIndex = 2,
	})
	UIKit.Text(frame, {
		Text = "$" .. NumberFormat.Rate(Fish.Income(entry)) .. "/s",
		Size = UDim2.new(0.5, 0, 0, 28),
		Position = UDim2.fromOffset(90, 48),
		Align = Enum.TextXAlignment.Left,
		Color = UIKit.MoneyGreen,
		Max = 28,
		Stroke = 2.5,
		ZIndex = 2,
	})
	UIKit.Button(frame, {
		Text = "Remove",
		Color = "Red",
		Size = UDim2.fromOffset(126, 54),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Max = 32,
		ZIndex = 2,
		OnClick = function()
			ClientState.Request("Unequip", entry.Uid)
		end,
	})
end

local function render()
	if not holder.Visible then
		return
	end
	UIKit.Clear(list)
	local data = ClientState.Data
	if not data then
		empty.Text = "Loading..."
		return
	end
	local entries = {}
	for _, entry in ipairs(data.Fish) do
		if table.find(data.Aquarium, entry.Uid) then
			table.insert(entries, entry)
		end
	end
	table.sort(entries, function(a, b)
		return Fish.Income(a) > Fish.Income(b)
	end)
	countLabel.Text = ("%d/%d in aquarium"):format(#entries, data.Slots)
	storedLabel.Text = ("%d in backpack"):format(#data.Fish - #data.Aquarium)
	empty.Text = #entries == 0 and "Aquarium is empty. Hold a fish from your backpack and click, or use Place best." or ""
	for i, entry in ipairs(entries) do
		row(entry, i)
	end
end

-- O HUD abre/fecha pelo mesmo nome "Aquarium" (como as outras janelas)
local window = { IsOpen = false }
window.Opened = Instance.new("BindableEvent")
window.Closed = Instance.new("BindableEvent")
function window.Open()
	holder.Visible = true
	window.IsOpen = true
	render()
end
function window.Close()
	holder.Visible = false
	window.IsOpen = false
end
holder:GetPropertyChangedSignal("Visible"):Connect(function()
	window.IsOpen = holder.Visible
end)
UIKit.Windows.Aquarium = window

ClientState.Changed.Event:Connect(render)
