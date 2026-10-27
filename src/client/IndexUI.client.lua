-- IndexUI (LocalScript)
-- Fica em: StarterPlayerScripts > Client > IndexUI
--
-- O ÍNDEX de peixes. É uma lista só, com rolagem: cada bioma (área) é um bloco com
--   * à esquerda, o "quadro" do bioma (nome, cor da água e stamina recomendada);
--   * à direita, os 8 peixes (sombra preta = nunca domado). Cada peixe mostra o próprio
--     prêmio e um botão PEGAR quando a versão NORMAL já foi domada;
--   * embaixo, a barra "Normais domados x/8" com o prêmio de completar o bioma.
-- Role para baixo para ver os outros biomas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))
local Track = require(Shared:WaitForChild("Track"))
local Progression = require(Shared:WaitForChild("Progression"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local window = UIKit.Window("Index", { Title = "Índex de Peixes", Icon = "📘", Size = Vector2.new(1100, 680), Header = "Blue" })

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
local SECTION_HEIGHT = 396

local scroll = UIKit.Scroll(body, { Size = UDim2.new(1, 0, 1, -62), Padding = 14 })

local totalBar = UIKit.Frame(body, {
	Name = "Total",
	Size = UDim2.new(1, 0, 0, 50),
	Position = UDim2.new(0, 0, 1, -50),
	Color = Color3.fromRGB(20, 20, 24),
	Transparency = 0.2,
	Corner = 10,
	Stroke = 3,
})
local totalFill = UIKit.Frame(totalBar, { Name = "Fill", Size = UDim2.fromScale(0, 1), Color = UIKit.White, Corner = 10 })
UIKit.Gradient(totalFill, UIKit.Colors.Blue[1], UIKit.Colors.Blue[2], 90)
local totalText = UIKit.Text(totalBar, { Text = "", Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), ZIndex = 3, Stroke = 3, Max = 34 })
UIKit.Text(totalBar, { Text = "📘", Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(6, -3), ZIndex = 4, Stroke = 1 })

local BIOME_ART = { "🐠", "🌿", "🦑" }

local function record(speciesId)
	local data = ClientState.Data
	return data and data.Index[speciesId]
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

local function fishCard(parent, species, order)
	local rec = record(species.Id)
	local seen = rec ~= nil
	local rarity = Fish.Rarities[species.Rarity]
	local card = UIKit.Frame(parent, { Name = species.Id, Color = UIKit.White, LayoutOrder = order, Corner = 10, Stroke = 3 })
	local top = seen and rarity.Color:Lerp(Color3.new(1, 1, 1), 0.2) or Color3.fromRGB(110, 110, 120)
	UIKit.Gradient(card, top, top:Lerp(Color3.new(0, 0, 0), 0.45), 90)

	UIKit.Text(card, { Text = seen and species.Name or "???", Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 4), Max = 20, ZIndex = 3 })
	UIKit.Viewport(card, { S = species.Id, M = "Normal", Z = "Normal" }, {
		Size = UDim2.new(1, -8, 1, -66),
		Position = UDim2.fromOffset(4, 28),
		Silhouette = not seen,
		ZIndex = 2,
	})

	local money, stamina = Progression.IndexReward(species.Id)
	local footer = UIKit.Frame(card, {
		Size = UDim2.new(1, -10, 0, 34),
		Position = UDim2.new(0, 5, 1, -38),
		Color = Color3.fromRGB(14, 14, 18),
		Transparency = 0.25,
		Corner = 6,
		ZIndex = 3,
	})
	if rec and rec.F and not rec.C then
		UIKit.Button(footer, {
			Text = "PEGAR",
			Color = "Green",
			Size = UDim2.fromScale(1, 1),
			Max = 24,
			ZIndex = 4,
			OnClick = function()
				ClientState.Request("ClaimIndex", species.Id)
			end,
		})
	else
		local text
		if rec and rec.C then
			text = "✓ Prêmio pego"
		elseif rec then
			text = "Dome o normal"
		else
			text = ("💵%s ⚡%s"):format(NumberFormat.Abbreviate(money), NumberFormat.Abbreviate(stamina))
		end
		UIKit.Text(footer, {
			Text = text,
			Size = UDim2.new(1, -8, 1, -6),
			Position = UDim2.fromOffset(4, 3),
			Color = (rec and rec.C) and UIKit.MoneyGreen or Color3.fromRGB(220, 220, 230),
			Max = 20,
			Stroke = 2,
			ZIndex = 4,
		})
	end
end

local function biomeSection(area)
	local data = ClientState.Data
	local section = UIKit.Frame(scroll, {
		Name = "Bioma" .. area.Index,
		Size = UDim2.new(1, -12, 0, SECTION_HEIGHT),
		Color = Color3.fromRGB(18, 18, 24),
		Transparency = 0.35,
		LayoutOrder = area.Index,
		Corner = 12,
		Stroke = 3,
	})

	-- quadro do bioma (lado esquerdo)
	local art = UIKit.Frame(section, {
		Name = "Quadro",
		Size = UDim2.fromOffset(232, 290),
		Position = UDim2.fromOffset(10, 10),
		Color = UIKit.White,
		Corner = 10,
		Stroke = 3,
	})
	UIKit.Gradient(art, area.FogColor:Lerp(Color3.new(1, 1, 1), 0.35), area.FogColor:Lerp(Color3.new(0, 0, 0), 0.35), 90)
	UIKit.Studs(art, Vector2.new(232, 290), { Spacing = 29, Transparency = 0.86, EdgeTransparency = 0.8 })
	UIKit.Text(art, { Text = ("ÁREA %d"):format(area.Index), Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 10), Color = Color3.fromRGB(230, 240, 255), Max = 24, ZIndex = 2 })
	UIKit.Text(art, { Text = area.Name, Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 38), Max = 36, Stroke = 3.5, ZIndex = 2 })
	UIKit.Text(art, { Text = BIOME_ART[area.Index] or "🐟", Size = UDim2.fromOffset(130, 130), Position = UDim2.new(0.5, 0, 0, 92), AnchorPoint = Vector2.new(0.5, 0), Stroke = 2, ZIndex = 2 })
	UIKit.Text(art, {
		Text = "⚡ " .. NumberFormat.Abbreviate(area.Recommended) .. " recomendado",
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.new(0, 8, 1, -40),
		Color = UIKit.StaminaYellow,
		Max = 22,
		ZIndex = 2,
	})

	-- peixes (lado direito)
	local grid = UIKit.Frame(section, {
		Name = "Peixes",
		Size = UDim2.new(1, -266, 0, 290),
		Position = UDim2.fromOffset(256, 10),
		Transparency = 1,
		Corner = false,
	})
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.25, -9, 0.5, -6)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	for i, species in ipairs(Fish.ByArea[area.Index]) do
		fishCard(grid, species, i)
	end

	-- barra de baixo: normais domados + prêmio de completar o bioma
	local found = foundCount(area.Index)
	local bar = UIKit.Frame(section, {
		Name = "Completar",
		Size = UDim2.new(1, -20, 0, 74),
		Position = UDim2.new(0, 10, 1, -84),
		Color = Color3.fromRGB(14, 14, 18),
		Transparency = 0.15,
		Corner = 10,
		Stroke = 3,
	})
	local progress = UIKit.Frame(bar, {
		Size = UDim2.new(0.46, 0, 0, 50),
		Position = UDim2.fromOffset(12, 12),
		Color = Color3.fromRGB(30, 30, 36),
		Corner = 8,
		Stroke = 2,
	})
	local fill = UIKit.Frame(progress, { Size = UDim2.fromScale(math.max(0.05, found / 8), 1), Color = UIKit.White, Corner = 8 })
	UIKit.Gradient(fill, UIKit.Colors.Green[1], UIKit.Colors.Green[2], 90)
	UIKit.Text(progress, {
		Text = found >= 8 and "COMPLETO! 8/8" or ("Normais domados: %d/8"):format(found),
		Size = UDim2.new(1, -12, 0.8, 0),
		Position = UDim2.new(0, 6, 0.1, 0),
		Max = 30,
		Stroke = 3,
		ZIndex = 3,
	})

	local money, stamina = Progression.AreaReward(area.Index)
	UIKit.Text(bar, {
		Text = ("Completar: 💵 %s  ⚡ +%s"):format(NumberFormat.Money(money), NumberFormat.Abbreviate(stamina)),
		Size = UDim2.new(0.32, 0, 0, 40),
		Position = UDim2.new(0.49, 0, 0, 17),
		Align = Enum.TextXAlignment.Left,
		Color = UIKit.MoneyGreen,
		Max = 28,
		Stroke = 2.5,
	})
	local claimed = data and data.Areas[tostring(area.Index)]
	local text, color, canClaim
	if claimed then
		text, color = "PEGO ✓", "Gray"
	elseif found >= 8 then
		text, color, canClaim = "PEGAR", "Green", true
	else
		text, color = "🔒", "Gray"
	end
	UIKit.Button(bar, {
		Text = text,
		Color = color,
		Size = UDim2.new(0.17, 0, 0, 54),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Max = 30,
		OnClick = function()
			if canClaim then
				ClientState.Request("ClaimArea", area.Index)
			else
				ClientState.Toast("Dome a versão normal dos 8 peixes do bioma", "info")
			end
		end,
	})
end

local function render()
	if not window.IsOpen then
		return
	end
	local position = scroll.CanvasPosition
	UIKit.Clear(scroll)
	for _, area in ipairs(Track.Areas) do
		biomeSection(area)
	end
	scroll.CanvasPosition = position
	local total = 0
	for area in pairs(Fish.ByArea) do
		total += foundCount(area)
	end
	totalFill.Size = UDim2.fromScale(math.max(0.03, total / #Fish.Species), 1)
	totalText.Text = ("Desbloqueados: %d/%d"):format(total, #Fish.Species)
end

window.Opened.Event:Connect(render)
ClientState.Changed.Event:Connect(render)
