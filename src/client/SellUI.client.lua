-- SellUI (LocalScript)
-- Fica em: StarterPlayerScripts > Client > SellUI
--
-- Barraca VENDER PEIXES (abre ao pisar no anel vermelho na frente do balcão), no estilo da
-- referência "Sell Dinos":
--   * à esquerda: ordenar por Valor ou Raridade e "Selecionar todos";
--   * no meio: os peixes guardados em cartões (toque para marcar/desmarcar);
--   * embaixo: o valor total dos marcados e o botão "Vender (n)", que sempre pede confirmação
--     (e avisa quando há peixes raros ou mutados no meio).
-- Os peixes que estão no aquário não aparecem aqui.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Fish = require(Shared:WaitForChild("Fish"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local window = UIKit.Window("Sell", { Title = "Vender Peixes", Icon = "🐟", Size = Vector2.new(1040, 660), Header = "Lime" })
local body = window.Body

local sortBy = "Value"
local selected = {}
local MAX_VIEWPORTS = 45

local MUTATION_BORDER = {
	Normal = Color3.fromRGB(70, 70, 82),
	Prata = Color3.fromRGB(225, 230, 240),
	Dourado = Color3.fromRGB(255, 200, 60),
	Diamante = Color3.fromRGB(120, 230, 255),
	ArcoIris = Color3.fromRGB(255, 120, 220),
}

-- Coluna da esquerda ------------------------------------------------------------------------
local left = UIKit.Frame(body, { Name = "Left", Size = UDim2.new(0, 240, 1, -96), Transparency = 1, Corner = false })
UIKit.Text(left, { Text = "Ordenar por:", Size = UDim2.new(1, 0, 0, 38), Max = 32 })
local valueButton = UIKit.Button(left, { Text = "Valor", Icon = "⬇️", Color = "Green", Size = UDim2.new(1, -10, 0, 62), Position = UDim2.fromOffset(5, 46), Max = 32 })
local rarityButton = UIKit.Button(left, { Text = "Raridade", Icon = "⬇️", Color = "Gray", Size = UDim2.new(1, -10, 0, 62), Position = UDim2.fromOffset(5, 118), Max = 32 })
UIKit.Frame(left, { Size = UDim2.new(1, -20, 0, 4), Position = UDim2.fromOffset(10, 196), Color = Color3.fromRGB(70, 70, 82), Corner = 2 })
local selectAll, selectAllLabel = UIKit.Button(left, {
	Text = "Selecionar todos",
	Color = "Green",
	Size = UDim2.new(1, -10, 0, 62),
	Position = UDim2.fromOffset(5, 214),
	Max = 26,
	IconWidth = 0.22,
	Icon = " ",
})
local dot = UIKit.Frame(selectAll, {
	Name = "Dot",
	Size = UDim2.fromOffset(40, 40),
	Position = UDim2.fromOffset(10, 11),
	Color = Color3.fromRGB(20, 20, 26),
	Corner = 20,
	Stroke = 2,
	ZIndex = 4,
})
local dotFill = UIKit.Frame(dot, {
	Size = UDim2.fromOffset(24, 24),
	Position = UDim2.fromOffset(8, 8),
	Color = UIKit.White,
	Corner = 12,
	ZIndex = 5,
})
UIKit.Text(left, {
	Text = "Os peixes que estão no aquário não podem ser vendidos.",
	Size = UDim2.new(1, -10, 0, 84),
	Position = UDim2.fromOffset(5, 296),
	Color = Color3.fromRGB(200, 200, 212),
	Align = Enum.TextXAlignment.Left,
	Max = 24,
	Stroke = 1.5,
})

-- Grade de peixes ---------------------------------------------------------------------------
local gridArea = UIKit.Frame(body, {
	Name = "GridArea",
	Size = UDim2.new(1, -256, 1, -96),
	Position = UDim2.fromOffset(256, 0),
	Color = Color3.fromRGB(16, 16, 20),
	Transparency = 0.45,
	Corner = 10,
	Stroke = 3,
})
local grid = UIKit.Scroll(gridArea, {
	Size = UDim2.new(1, -12, 1, -12),
	Position = UDim2.fromOffset(6, 6),
	Grid = UDim2.fromOffset(234, 252),
	GridPadding = UDim2.fromOffset(10, 10),
})
local empty = UIKit.Text(gridArea, {
	Text = "",
	Size = UDim2.new(1, -40, 0, 80),
	Position = UDim2.fromScale(0.5, 0.45),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Color = Color3.fromRGB(200, 200, 210),
	Max = 30,
})

-- Barra de baixo ------------------------------------------------------------------------------
local footer = UIKit.Frame(body, {
	Name = "Footer",
	Size = UDim2.new(1, 0, 0, 84),
	Position = UDim2.new(0, 0, 1, -84),
	Color = Color3.fromRGB(16, 16, 20),
	Transparency = 0.3,
	Corner = 10,
	Stroke = 3,
})
UIKit.Text(footer, { Text = "Valor total:", Size = UDim2.fromOffset(240, 50), Position = UDim2.fromOffset(24, 17), Align = Enum.TextXAlignment.Left, Max = 40, Stroke = 3 })
UIKit.Text(footer, { Text = "💵", Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(262, 14), Stroke = 1.5 })
local totalLabel = UIKit.Text(footer, { Text = "$0", Size = UDim2.fromOffset(320, 50), Position = UDim2.fromOffset(326, 17), Align = Enum.TextXAlignment.Left, Max = 44, Stroke = 3 })
local sellButton, sellLabel = UIKit.Button(footer, {
	Text = "Vender (0)",
	Color = "Gray",
	Size = UDim2.fromOffset(320, 64),
	Position = UDim2.new(1, -12, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	Max = 40,
})

-- Lógica ------------------------------------------------------------------------------------
local function storedFish()
	local data = ClientState.Data
	local result = {}
	if not data then
		return result
	end
	for _, entry in ipairs(data.Fish) do
		if not table.find(data.Aquarium, entry.Uid) and Fish.Get(entry.S) then
			table.insert(result, entry)
		end
	end
	table.sort(result, function(a, b)
		local va, vb = Fish.SellValue(a, Config.SELL_SECONDS), Fish.SellValue(b, Config.SELL_SECONDS)
		if sortBy == "Rarity" then
			local ra = Fish.Rarities[Fish.Get(a.S).Rarity].Order
			local rb = Fish.Rarities[Fish.Get(b.S).Rarity].Order
			if ra ~= rb then
				return ra > rb
			end
		end
		if va == vb then
			return a.Uid < b.Uid
		end
		return va > vb
	end)
	return result
end

local function selection(entries)
	local total, count, precious = 0, 0, 0
	local uids = {}
	for _, entry in ipairs(entries) do
		if selected[entry.Uid] then
			total += Fish.SellValue(entry, Config.SELL_SECONDS)
			count += 1
			table.insert(uids, entry.Uid)
			if Fish.IsPrecious(entry) then
				precious += 1
			end
		end
	end
	return total, count, precious, uids
end

local render

local function card(entry, order)
	local species = Fish.Get(entry.S)
	local rarity = Fish.Rarities[species.Rarity]
	local isSelected = selected[entry.Uid] == true
	local button = Instance.new("TextButton")
	button.Name = "Fish" .. entry.Uid
	button.Text = ""
	button.AutoButtonColor = false
	button.LayoutOrder = order
	button.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
	button.BackgroundTransparency = isSelected and 0.05 or 0.3
	UIKit.Corner(button, 8)
	UIKit.Stroke(button, isSelected and 5 or 3, isSelected and UIKit.White or (MUTATION_BORDER[entry.M] or MUTATION_BORDER.Normal), Enum.ApplyStrokeMode.Border)
	button.Parent = grid

	UIKit.Text(button, {
		Text = species.Name,
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 6),
		Align = Enum.TextXAlignment.Left,
		Color = rarity.Color,
		Max = 26,
		ZIndex = 2,
	})
	local tags = {}
	if entry.M ~= "Normal" then
		table.insert(tags, string.upper(Fish.Mutations[entry.M].Name))
	end
	if entry.Z ~= "Normal" then
		table.insert(tags, string.upper(Fish.Sizes[entry.Z].Name))
	end
	if #tags > 0 then
		UIKit.Text(button, {
			Text = table.concat(tags, "   "),
			Size = UDim2.new(1, -16, 0, 20),
			Position = UDim2.fromOffset(8, 36),
			Color = entry.M ~= "Normal" and Fish.Mutations[entry.M].Color or Color3.fromRGB(255, 190, 120),
			Max = 18,
			Stroke = 1.5,
			ZIndex = 2,
		})
	end
	if order <= MAX_VIEWPORTS then
		UIKit.Viewport(button, entry, { Size = UDim2.new(1, -20, 0, 110), Position = UDim2.fromOffset(10, 56), ZIndex = 2 })
	else
		UIKit.Text(button, { Text = "🐟", Size = UDim2.new(1, -20, 0, 100), Position = UDim2.fromOffset(10, 60), Stroke = 1, ZIndex = 2 })
	end
	UIKit.Text(button, {
		Text = "$" .. NumberFormat.Rate(Fish.Income(entry)) .. "/s",
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.fromOffset(8, 166),
		Color = UIKit.MoneyGreen,
		Max = 30,
		Stroke = 3,
		ZIndex = 2,
	})
	local valueBar = UIKit.Frame(button, {
		Size = UDim2.new(1, -16, 0, 42),
		Position = UDim2.fromOffset(8, 202),
		Color = Color3.fromRGB(12, 12, 16),
		Transparency = 0.15,
		Corner = 6,
		Stroke = 2,
		StrokeColor = Color3.fromRGB(60, 60, 70),
		ZIndex = 2,
	})
	UIKit.Text(valueBar, { Text = "💵", Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(6, 3), Stroke = 1, ZIndex = 3 })
	UIKit.Text(valueBar, {
		Text = NumberFormat.Money(Fish.SellValue(entry, Config.SELL_SECONDS)),
		Size = UDim2.new(1, -52, 1, -8),
		Position = UDim2.fromOffset(48, 4),
		Align = Enum.TextXAlignment.Left,
		Max = 28,
		Stroke = 2.5,
		ZIndex = 3,
	})
	if isSelected then
		local check = UIKit.Frame(button, {
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.new(1, -6, 0, 6),
			AnchorPoint = Vector2.new(1, 0),
			Color = Color3.fromRGB(60, 200, 60),
			Corner = 17,
			Stroke = 2,
			ZIndex = 4,
		})
		UIKit.Text(check, { Text = "✓", ZIndex = 5, Stroke = 1.5 })
	end
	button.Activated:Connect(function()
		selected[entry.Uid] = not selected[entry.Uid] or nil
		render()
	end)
end

render = function()
	if not window.IsOpen then
		return
	end
	UIKit.Clear(grid)
	local entries = storedFish()
	-- tira da seleção o que não existe mais
	local present = {}
	for _, entry in ipairs(entries) do
		present[entry.Uid] = true
	end
	for uid in pairs(selected) do
		if not present[uid] then
			selected[uid] = nil
		end
	end
	for i, entry in ipairs(entries) do
		card(entry, i)
	end
	empty.Text = #entries == 0 and "Nada para vender. Dome peixes no mar!" or ""

	local total, count = selection(entries)
	totalLabel.Text = NumberFormat.Money(total)
	sellLabel.Text = ("Vender (%d)"):format(count)
	UIKit.SetButtonColor(sellButton, count > 0 and "Green" or "Gray")
	UIKit.SetButtonColor(valueButton, sortBy == "Value" and "Green" or "Gray")
	UIKit.SetButtonColor(rarityButton, sortBy == "Rarity" and "Green" or "Gray")
	local allSelected = #entries > 0 and count == #entries
	dotFill.Visible = allSelected
	selectAllLabel.Text = allSelected and "Desmarcar todos" or "Selecionar todos"
end

valueButton.Activated:Connect(function()
	sortBy = "Value"
	render()
end)
rarityButton.Activated:Connect(function()
	sortBy = "Rarity"
	render()
end)
selectAll.Activated:Connect(function()
	local entries = storedFish()
	local _, count = selection(entries)
	local selectEverything = count < #entries
	selected = {}
	if selectEverything then
		for _, entry in ipairs(entries) do
			selected[entry.Uid] = true
		end
	end
	render()
end)

sellButton.Activated:Connect(function()
	local total, count, precious, uids = selection(storedFish())
	if count == 0 then
		ClientState.Toast("Toque nos peixes para escolher o que vender", "info")
		return
	end
	local text = ("Vender %d peixe(s) por %s?"):format(count, NumberFormat.Money(total))
	if precious > 0 then
		text ..= ("\n%d deles são raros ou mutados!"):format(precious)
	end
	UIKit.Confirm(text, "Vender", function()
		local result = ClientState.Request("SellMany", uids)
		if result.ok then
			selected = {}
		end
	end, "Red")
end)

window.Opened.Event:Connect(function()
	selected = {}
	render()
end)
ClientState.Changed.Event:Connect(render)
