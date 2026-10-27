-- AquariumUI (LocalScript)
-- Fica em: StarterPlayerScripts > Client > AquariumUI
--
-- A tela dos seus peixes (botão laranja 🐟): o que está no aquário rendendo dinheiro e o
-- que está guardado. Colocar, tirar e "Colocar melhores" (enche o aquário com os que mais
-- rendem).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local window = UIKit.Window("Aquarium", { Title = "Aquário", Size = Vector2.new(860, 640), Header = "Orange" })
local body = window.Body

local tab = "Aquarium"
local MAX_VIEWPORTS = 40

local tabs = UIKit.Frame(body, { Name = "Tabs", Size = UDim2.new(1, 0, 0, 60), Transparency = 1, Corner = false })
local aquariumTab, aquariumTabLabel = UIKit.Button(tabs, { Text = "No aquário", Color = "Orange", Size = UDim2.new(0.34, -6, 1, 0), Max = 30 })
local storedTab, storedTabLabel = UIKit.Button(tabs, { Text = "Guardados", Color = "Gray", Size = UDim2.new(0.34, -6, 1, 0), Position = UDim2.fromScale(0.34, 0), Max = 30 })
UIKit.Button(tabs, {
	Text = "Colocar melhores",
	Color = "Green",
	Size = UDim2.new(0.32, 0, 1, 0),
	Position = UDim2.fromScale(0.68, 0),
	Max = 28,
	OnClick = function()
		ClientState.Request("EquipBest")
	end,
})

local list = UIKit.Scroll(body, { Size = UDim2.new(1, 0, 1, -76), Position = UDim2.fromOffset(0, 74), Padding = 8 })
local empty = UIKit.Text(body, {
	Text = "",
	Size = UDim2.new(1, -40, 0, 80),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Color = Color3.fromRGB(200, 200, 210),
	Max = 30,
})

local function sortedFish(filter)
	local data = ClientState.Data
	local result = {}
	if not data then
		return result
	end
	for _, entry in ipairs(data.Fish) do
		if filter(entry) then
			table.insert(result, entry)
		end
	end
	table.sort(result, function(a, b)
		local ia, ib = Fish.Income(a), Fish.Income(b)
		if ia == ib then
			return a.Uid < b.Uid
		end
		return ia > ib
	end)
	return result
end

local function row(entry, order, inAquarium, full)
	local species = Fish.Get(entry.S)
	if not species then
		return
	end
	local rarity = Fish.Rarities[species.Rarity]
	local frame = UIKit.Frame(list, {
		Name = "Fish" .. entry.Uid,
		Size = UDim2.new(1, -8, 0, 88),
		Color = UIKit.White,
		LayoutOrder = order,
		Corner = 10,
		Stroke = 3,
	})
	UIKit.Gradient(frame, Color3.fromRGB(52, 52, 64), Color3.fromRGB(32, 32, 40), 90)
	local iconBox = UIKit.Frame(frame, {
		Size = UDim2.fromOffset(78, 78),
		Position = UDim2.fromOffset(5, 5),
		Color = rarity.Color:Lerp(Color3.new(0, 0, 0), 0.45),
		Corner = 8,
		Stroke = 2,
		StrokeColor = rarity.Color,
	})
	if order <= MAX_VIEWPORTS then
		UIKit.Viewport(iconBox, entry, { ZIndex = 2 })
	else
		UIKit.Text(iconBox, { Text = "🐟", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Stroke = 1 })
	end
	UIKit.Text(frame, {
		Text = species.Name,
		Size = UDim2.new(0.5, 0, 0, 34),
		Position = UDim2.fromOffset(96, 6),
		Align = Enum.TextXAlignment.Left,
		Color = UIKit.White,
		Max = 30,
	})
	local tags = Fish.Tags(entry)
	UIKit.Text(frame, {
		Text = tags ~= "" and (rarity.Name .. " • " .. tags) or rarity.Name,
		Size = UDim2.new(0.5, 0, 0, 22),
		Position = UDim2.fromOffset(96, 38),
		Align = Enum.TextXAlignment.Left,
		Color = (entry.M ~= "Normal") and Fish.Mutations[entry.M].Color or rarity.Color,
		Max = 20,
	})
	UIKit.Text(frame, {
		Text = "$" .. NumberFormat.Rate(Fish.Income(entry)) .. "/s",
		Size = UDim2.new(0.4, 0, 0, 28),
		Position = UDim2.fromOffset(96, 58),
		Align = Enum.TextXAlignment.Left,
		Color = UIKit.MoneyGreen,
		Max = 26,
	})
	local text, color = "Colocar", "Green"
	if inAquarium then
		text, color = "Tirar", "Red"
	elseif full then
		text, color = "Cheio", "Gray"
	end
	UIKit.Button(frame, {
		Text = text,
		Color = color,
		Size = UDim2.fromOffset(170, 60),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Max = 32,
		OnClick = function()
			if inAquarium then
				ClientState.Request("Unequip", entry.Uid)
			elseif not full then
				ClientState.Request("Equip", entry.Uid)
			else
				ClientState.Toast("Aquário cheio. Melhore o aquário na placa do seu lote.", "erro")
			end
		end,
	})
end

local function render()
	if not window.IsOpen then
		return
	end
	UIKit.Clear(list)
	local data = ClientState.Data
	if not data then
		empty.Text = "Carregando..."
		return
	end
	local inAquariumCount = #data.Aquarium
	local storedCount = #data.Fish - inAquariumCount
	aquariumTabLabel.Text = ("No aquário %d/%d"):format(inAquariumCount, data.Slots)
	storedTabLabel.Text = ("Guardados %d/%d"):format(storedCount, data.MaxStored)
	UIKit.SetButtonColor(aquariumTab, tab == "Aquarium" and "Orange" or "Gray")
	UIKit.SetButtonColor(storedTab, tab == "Stored" and "Orange" or "Gray")

	local full = inAquariumCount >= data.Slots
	local entries
	if tab == "Aquarium" then
		entries = sortedFish(function(entry)
			return table.find(data.Aquarium, entry.Uid) ~= nil
		end)
		empty.Text = #entries == 0 and "Aquário vazio. Mergulhe no mar e dome peixes!" or ""
	else
		entries = sortedFish(function(entry)
			return table.find(data.Aquarium, entry.Uid) == nil
		end)
		empty.Text = #entries == 0 and "Nenhum peixe guardado." or ""
	end
	for i, entry in ipairs(entries) do
		row(entry, i, tab == "Aquarium", full)
	end
end

aquariumTab.Activated:Connect(function()
	tab = "Aquarium"
	render()
end)
storedTab.Activated:Connect(function()
	tab = "Stored"
	render()
end)
window.Opened.Event:Connect(render)
ClientState.Changed.Event:Connect(render)
