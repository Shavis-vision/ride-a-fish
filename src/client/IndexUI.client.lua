-- IndexUI (LocalScript)
-- Fica em: StarterPlayerScripts > Client > IndexUI
--
-- O ÍNDEX de peixes (como o "Dino Index" das referências):
--   * à esquerda, as 3 áreas, com o progresso e o prêmio de área completa;
--   * no meio, os 8 peixes da área (sombra preta = nunca domado);
--   * à direita, o peixe escolhido: renda, stamina, variações e o prêmio.
-- Só a versão NORMAL (sem mutação) libera o prêmio de cada peixe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))
local Track = require(Shared:WaitForChild("Track"))
local Progression = require(Shared:WaitForChild("Progression"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local window = UIKit.Window("Index", { Title = "Índex de Peixes", Size = Vector2.new(1060, 660), Header = "Blue" })

UIKit.Button(window.Inner, {
	Name = "ClaimAll",
	Text = "PEGAR TUDO",
	Color = "Green",
	Size = UDim2.fromOffset(230, 58),
	Position = UDim2.new(1, -84, 0, 8),
	AnchorPoint = Vector2.new(1, 0),
	Max = 34,
	ZIndex = 5,
	OnClick = function()
		ClientState.Request("ClaimAllIndex")
	end,
})

local body = window.Body
local selectedArea = 1
local selectedSpecies = "palhaco"

local areaColumn = UIKit.Frame(body, { Name = "Areas", Size = UDim2.new(0, 232, 1, -64), Transparency = 1, Corner = false })
local areaList = Instance.new("UIListLayout")
areaList.Padding = UDim.new(0, 10)
areaList.SortOrder = Enum.SortOrder.LayoutOrder
areaList.Parent = areaColumn

local center = UIKit.Frame(body, {
	Name = "Center",
	Size = UDim2.new(0, 470, 1, -64),
	Position = UDim2.fromOffset(246, 0),
	Color = Color3.fromRGB(26, 26, 32),
	Corner = 12,
})
UIKit.Padding(center, 10)
local grid = UIKit.Frame(center, { Name = "Grid", Size = UDim2.new(1, 0, 1, -64), Transparency = 1, Corner = false })
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.25, -8, 0.5, -8)
gridLayout.CellPadding = UDim2.fromOffset(10, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local areaBar = UIKit.Frame(center, {
	Name = "AreaBar",
	Size = UDim2.new(1, 0, 0, 52),
	Position = UDim2.new(0, 0, 1, -52),
	Color = Color3.fromRGB(20, 20, 24),
	Corner = 10,
	Stroke = 3,
})
local areaFill = UIKit.Frame(areaBar, { Name = "Fill", Size = UDim2.fromScale(0, 1), Color = UIKit.White, Corner = 10 })
UIKit.Gradient(areaFill, UIKit.Colors.Green[1], UIKit.Colors.Green[2], 90)
local areaText = UIKit.Text(areaBar, { Text = "", Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), ZIndex = 3, Stroke = 3, Max = 34 })

local detail = UIKit.Frame(body, {
	Name = "Detail",
	Size = UDim2.new(1, -730, 1, -64),
	Position = UDim2.fromOffset(730, 0),
	Color = Color3.fromRGB(60, 62, 72),
	Corner = 12,
	Stroke = 3,
})

local totalBar = UIKit.Frame(body, {
	Name = "Total",
	Size = UDim2.new(1, 0, 0, 50),
	Position = UDim2.new(0, 0, 1, -50),
	Color = Color3.fromRGB(20, 20, 24),
	Corner = 10,
	Stroke = 3,
})
local totalFill = UIKit.Frame(totalBar, { Name = "Fill", Size = UDim2.fromScale(0, 1), Color = UIKit.White, Corner = 10 })
UIKit.Gradient(totalFill, UIKit.Colors.Blue[1], UIKit.Colors.Blue[2], 90)
local totalText = UIKit.Text(totalBar, { Text = "", Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), ZIndex = 3, Stroke = 3, Max = 34 })
UIKit.Text(totalBar, { Text = "📘", Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(6, -3), ZIndex = 4, Stroke = 1 })

local function record(speciesId)
	local data = ClientState.Data
	return data and data.Index[speciesId]
end

local function variantCount(rec)
	local count = 0
	if rec then
		for _ in pairs(rec.V) do
			count += 1
		end
	end
	return count
end

local function areaComplete(area)
	for _, species in ipairs(Fish.ByArea[area]) do
		local rec = record(species.Id)
		if not rec or not rec.F then
			return false
		end
	end
	return true
end

local function foundCount(area)
	local count = 0
	for _, species in ipairs(Fish.ByArea[area]) do
		local rec = record(species.Id)
		if rec and rec.F then
			count += 1
		end
	end
	return count
end

local render

local function renderAreas()
	UIKit.Clear(areaColumn)
	local data = ClientState.Data
	for _, area in ipairs(Track.Areas) do
		local selected = area.Index == selectedArea
		local card = Instance.new("TextButton")
		card.Name = "Area" .. area.Index
		card.Text = ""
		card.AutoButtonColor = false
		card.Size = UDim2.new(1, -4, 0, 158)
		card.LayoutOrder = area.Index
		card.BackgroundColor3 = UIKit.White
		UIKit.Corner(card, 12)
		UIKit.Stroke(card, selected and 4 or 3, selected and UIKit.White or UIKit.Dark, Enum.ApplyStrokeMode.Border)
		UIKit.Gradient(card, area.FogColor:Lerp(Color3.new(1, 1, 1), 0.25), area.FogColor:Lerp(Color3.new(0, 0, 0), 0.25), 90)
		card.Parent = areaColumn
		UIKit.Text(card, { Text = area.Name, Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 8), Stroke = 3, Max = 32 })
		UIKit.Text(card, {
			Text = ("%d/8 peixes"):format(foundCount(area.Index)),
			Size = UDim2.new(1, -16, 0, 26),
			Position = UDim2.fromOffset(8, 50),
			Color = Color3.fromRGB(230, 240, 255),
			Max = 24,
		})
		local money, stamina = Progression.AreaReward(area.Index)
		local box = UIKit.Frame(card, {
			Size = UDim2.new(1, -16, 0, 68),
			Position = UDim2.fromOffset(8, 82),
			Color = Color3.fromRGB(20, 40, 30),
			Transparency = 0.2,
			Corner = 8,
			Stroke = 2,
			StrokeColor = UIKit.MoneyGreen,
		})
		local claimed = data and data.Areas[tostring(area.Index)]
		if areaComplete(area.Index) and not claimed then
			UIKit.Button(box, {
				Text = "PEGAR PRÊMIO",
				Color = "Green",
				Size = UDim2.new(1, -12, 1, -12),
				Position = UDim2.fromOffset(6, 6),
				Max = 28,
				OnClick = function()
					ClientState.Request("ClaimArea", area.Index)
				end,
			})
		else
			UIKit.Text(box, {
				Text = claimed and "COMPLETO ✓" or "COMPLETAR:",
				Size = UDim2.new(1, -8, 0, 24),
				Position = UDim2.fromOffset(4, 4),
				Color = UIKit.MoneyGreen,
				Max = 22,
			})
			UIKit.Text(box, {
				Text = ("💵 %s   ⚡ +%s"):format(NumberFormat.Money(money), NumberFormat.Abbreviate(stamina)),
				Size = UDim2.new(1, -8, 0, 32),
				Position = UDim2.fromOffset(4, 30),
				Max = 26,
			})
		end
		card.Activated:Connect(function()
			selectedArea = area.Index
			selectedSpecies = Fish.ByArea[area.Index][1].Id
			render()
		end)
	end
end

local function renderGrid()
	UIKit.Clear(grid)
	for i, species in ipairs(Fish.ByArea[selectedArea]) do
		local rec = record(species.Id)
		local seen = rec ~= nil
		local rarity = Fish.Rarities[species.Rarity]
		local selected = species.Id == selectedSpecies
		local card = Instance.new("TextButton")
		card.Name = species.Id
		card.Text = ""
		card.AutoButtonColor = false
		card.LayoutOrder = i
		card.BackgroundColor3 = UIKit.White
		UIKit.Corner(card, 10)
		UIKit.Stroke(card, selected and 4 or 3, selected and UIKit.White or UIKit.Dark, Enum.ApplyStrokeMode.Border)
		local top = seen and rarity.Color:Lerp(Color3.new(1, 1, 1), 0.2) or Color3.fromRGB(110, 110, 120)
		UIKit.Gradient(card, top, top:Lerp(Color3.new(0, 0, 0), 0.4), 90)
		card.Parent = grid
		UIKit.Text(card, {
			Text = seen and species.Name or "???",
			Size = UDim2.new(1, -8, 0, 26),
			Position = UDim2.fromOffset(4, 4),
			Max = 20,
			ZIndex = 3,
		})
		UIKit.Viewport(card, { S = species.Id, M = "Normal", Z = "Normal" }, {
			Size = UDim2.new(1, -8, 1, -36),
			Position = UDim2.fromOffset(4, 30),
			Silhouette = not seen,
			ZIndex = 2,
		})
		if rec and rec.F and not rec.C then
			local dot = UIKit.Frame(card, {
				Size = UDim2.fromOffset(28, 28),
				Position = UDim2.new(1, 6, 0, -6),
				AnchorPoint = Vector2.new(1, 0),
				Color = Color3.fromRGB(230, 40, 50),
				Corner = 14,
				Stroke = 2,
				ZIndex = 6,
			})
			UIKit.Text(dot, { Text = "!", ZIndex = 7, Stroke = 1.5 })
		end
		card.Activated:Connect(function()
			selectedSpecies = species.Id
			render()
		end)
	end

	local found = foundCount(selectedArea)
	areaFill.Size = UDim2.fromScale(math.max(0.04, found / 8), 1)
	areaText.Text = found >= 8 and "COMPLETO! 8/8" or ("Normais domados: %d/8"):format(found)
end

local function infoLine(parent, y, text, color)
	return UIKit.Text(parent, {
		Text = text,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, y),
		Align = Enum.TextXAlignment.Left,
		Color = color,
		Max = 26,
	})
end

local function renderDetail()
	UIKit.Clear(detail)
	local species = Fish.Get(selectedSpecies)
	if not species then
		return
	end
	local rec = record(species.Id)
	local seen = rec ~= nil
	local rarity = Fish.Rarities[species.Rarity]

	local stage = UIKit.Frame(detail, {
		Size = UDim2.new(1, -20, 0, 150),
		Position = UDim2.fromOffset(10, 10),
		Color = Color3.fromRGB(150, 155, 170),
		Corner = 10,
		Stroke = 2,
	})
	UIKit.Gradient(stage, Color3.fromRGB(190, 200, 215), Color3.fromRGB(120, 125, 140), 90)
	UIKit.Viewport(stage, { S = species.Id, M = "Normal", Z = "Normal" }, { Silhouette = not seen, ZIndex = 2 })

	UIKit.Text(detail, { Text = seen and species.Name or "???", Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 166), Stroke = 3.5, Max = 36 })
	UIKit.Text(detail, { Text = rarity.Name, Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 204), Color = rarity.Color, Max = 26 })
	infoLine(detail, 238, "💵 $" .. NumberFormat.Rate(species.Income) .. "/s no aquário", UIKit.MoneyGreen)
	infoLine(detail, 268, "⚡ Precisa de " .. NumberFormat.Abbreviate(species.Stamina) .. " de stamina", UIKit.StaminaYellow)
	infoLine(detail, 298, ("✨ Variações: %d/%d"):format(variantCount(rec), Fish.VariantCount), Color3.fromRGB(210, 170, 255))
	if species.Ability then
		infoLine(detail, 328, "🌀 " .. species.Ability .. ": " .. Fish.Abilities[species.Ability], Color3.fromRGB(120, 230, 255))
	end

	local rewards = UIKit.Frame(detail, {
		Size = UDim2.new(1, -20, 0, 120),
		Position = UDim2.new(0, 10, 1, -130),
		Color = Color3.fromRGB(20, 40, 28),
		Corner = 10,
		Stroke = 3,
		StrokeColor = UIKit.MoneyGreen,
	})
	local money, stamina = Progression.IndexReward(species.Id)
	UIKit.Text(rewards, { Text = "Prêmio:", Size = UDim2.new(0.4, 0, 0, 28), Position = UDim2.fromOffset(10, 6), Align = Enum.TextXAlignment.Left, Max = 24 })
	UIKit.Text(rewards, {
		Text = ("💵 %s  ⚡ +%s"):format(NumberFormat.Money(money), NumberFormat.Abbreviate(stamina)),
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.fromOffset(10, 34),
		Align = Enum.TextXAlignment.Left,
		Max = 24,
	})
	local text, color, canClaim
	if rec and rec.C then
		text, color = "PEGO!", "Gray"
	elseif rec and rec.F then
		text, color, canClaim = "PEGAR", "Green", true
	else
		text, color = "Dome a versão normal", "Gray"
	end
	UIKit.Button(rewards, {
		Text = text,
		Color = color,
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.new(0, 10, 1, -8),
		AnchorPoint = Vector2.new(0, 1),
		Max = 28,
		OnClick = function()
			if canClaim then
				ClientState.Request("ClaimIndex", species.Id)
			end
		end,
	})
end

render = function()
	if not window.IsOpen then
		return
	end
	renderAreas()
	renderGrid()
	renderDetail()
	local total = 0
	for area in pairs(Fish.ByArea) do
		total += foundCount(area)
	end
	totalFill.Size = UDim2.fromScale(math.max(0.03, total / #Fish.Species), 1)
	totalText.Text = ("Desbloqueados: %d/%d"):format(total, #Fish.Species)
end

window.Opened.Event:Connect(render)
ClientState.Changed.Event:Connect(render)
