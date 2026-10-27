-- SellUI (LocalScript)
-- Fica em: StarterPlayerScripts > Client > SellUI
--
-- Barraca VENDER PEIXES (abre ao pisar no anel vermelho). Lista os peixes guardados
-- (os do aquário não aparecem). "Vender tudo" pede confirmação e, por padrão, NÃO vende
-- os preciosos (mutados, Enorme/Gigante, Épico e Lendário); para incluir, marque a caixa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Fish = require(Shared:WaitForChild("Fish"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local window = UIKit.Window("Sell", { Title = "Vender Peixes", Size = Vector2.new(860, 640), Header = "Red" })
local body = window.Body
local includePrecious = false
local MAX_VIEWPORTS = 30

local list = UIKit.Scroll(body, { Size = UDim2.new(1, 0, 1, -86), Padding = 8 })
local empty = UIKit.Text(body, {
	Text = "",
	Size = UDim2.new(1, -40, 0, 80),
	Position = UDim2.new(0.5, 0, 0.42, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Color = Color3.fromRGB(200, 200, 210),
	Max = 30,
})

local footer = UIKit.Frame(body, { Name = "Footer", Size = UDim2.new(1, 0, 0, 72), Position = UDim2.new(0, 0, 1, -72), Transparency = 1, Corner = false })
local toggle, toggleLabel = UIKit.Button(footer, {
	Text = "☐ Incluir raros",
	Color = "Gray",
	Size = UDim2.new(0.4, -8, 1, 0),
	Max = 28,
})
local sellAll, sellAllLabel = UIKit.Button(footer, {
	Text = "VENDER TUDO",
	Color = "Red",
	Size = UDim2.new(0.6, 0, 1, 0),
	Position = UDim2.fromScale(0.4, 0),
	Max = 32,
})

local function sellable()
	local data = ClientState.Data
	local result = {}
	if not data then
		return result
	end
	for _, entry in ipairs(data.Fish) do
		if not table.find(data.Aquarium, entry.Uid) then
			table.insert(result, entry)
		end
	end
	table.sort(result, function(a, b)
		local va, vb = Fish.Income(a), Fish.Income(b)
		if va == vb then
			return a.Uid < b.Uid
		end
		return va < vb
	end)
	return result
end

local function totalFor(entries)
	local total, count = 0, 0
	for _, entry in ipairs(entries) do
		if includePrecious or not Fish.IsPrecious(entry) then
			total += Fish.SellValue(entry, Config.SELL_SECONDS)
			count += 1
		end
	end
	return total, count
end

local function render()
	if not window.IsOpen then
		return
	end
	UIKit.Clear(list)
	local entries = sellable()
	empty.Text = #entries == 0 and "Nada para vender. Os peixes do aquário não aparecem aqui." or ""
	for i, entry in ipairs(entries) do
		local species = Fish.Get(entry.S)
		local rarity = Fish.Rarities[species.Rarity]
		local precious = Fish.IsPrecious(entry)
		local frame = UIKit.Frame(list, { Size = UDim2.new(1, -8, 0, 80), Color = UIKit.White, LayoutOrder = i, Corner = 10, Stroke = 3 })
		UIKit.Gradient(frame, Color3.fromRGB(52, 52, 64), Color3.fromRGB(32, 32, 40), 90)
		local iconBox = UIKit.Frame(frame, {
			Size = UDim2.fromOffset(70, 70),
			Position = UDim2.fromOffset(5, 5),
			Color = rarity.Color:Lerp(Color3.new(0, 0, 0), 0.45),
			Corner = 8,
			Stroke = 2,
			StrokeColor = rarity.Color,
		})
		if i <= MAX_VIEWPORTS then
			UIKit.Viewport(iconBox, entry, { ZIndex = 2 })
		else
			UIKit.Text(iconBox, { Text = "🐟", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Stroke = 1 })
		end
		local tags = Fish.Tags(entry)
		UIKit.Text(frame, {
			Text = species.Name .. (precious and "  💎" or ""),
			Size = UDim2.new(0.5, 0, 0, 32),
			Position = UDim2.fromOffset(88, 6),
			Align = Enum.TextXAlignment.Left,
			Max = 28,
		})
		UIKit.Text(frame, {
			Text = tags ~= "" and (rarity.Name .. " • " .. tags) or rarity.Name,
			Size = UDim2.new(0.5, 0, 0, 24),
			Position = UDim2.fromOffset(88, 44),
			Align = Enum.TextXAlignment.Left,
			Color = (entry.M ~= "Normal") and Fish.Mutations[entry.M].Color or rarity.Color,
			Max = 22,
		})
		local value = Fish.SellValue(entry, Config.SELL_SECONDS)
		UIKit.Button(frame, {
			Text = "Vender " .. NumberFormat.Money(value),
			Color = "Green",
			Size = UDim2.fromOffset(230, 58),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Max = 28,
			OnClick = function()
				if precious then
					UIKit.Confirm("Vender " .. species.Name .. " (" .. (tags ~= "" and tags or rarity.Name) .. ")?", "Vender", function()
						ClientState.Request("Sell", entry.Uid)
					end, "Red")
				else
					ClientState.Request("Sell", entry.Uid)
				end
			end,
		})
	end
	local total, count = totalFor(entries)
	sellAllLabel.Text = count > 0 and ("VENDER %d • %s"):format(count, NumberFormat.Money(total)) or "VENDER TUDO"
	toggleLabel.Text = (includePrecious and "☑" or "☐") .. " Incluir raros"
	UIKit.SetButtonColor(toggle, includePrecious and "Orange" or "Gray")
end

toggle.Activated:Connect(function()
	includePrecious = not includePrecious
	render()
end)

sellAll.Activated:Connect(function()
	local total, count = totalFor(sellable())
	if count == 0 then
		ClientState.Toast("Nada para vender", "info")
		return
	end
	local text = ("Vender %d peixes por %s?"):format(count, NumberFormat.Money(total))
	if includePrecious then
		text = text .. "\nInclui peixes RAROS e mutados!"
	end
	UIKit.Confirm(text, "Vender tudo", function()
		ClientState.Request("SellAll", includePrecious)
	end, "Red")
end)

window.Opened.Event:Connect(render)
ClientState.Changed.Event:Connect(render)
