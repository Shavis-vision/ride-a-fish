-- PlotService (ModuleScript)
-- Fica em: ServerScriptService > Server > PlotService
--
-- Os lotes dos jogadores: quem é dono de qual, os peixes dentro do aquário, as placas
-- de melhoria (esteira e aquário), o nome e a renda em cima do aquário, e onde o
-- jogador nasce.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))
local FishModel = require(Shared:WaitForChild("FishModel"))
local Layout = require(Shared:WaitForChild("Layout"))
local Track = require(Shared:WaitForChild("Track"))
local Progression = require(Shared:WaitForChild("Progression"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local Net = require(script.Parent:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local MapService = require(script.Parent:WaitForChild("MapService"))
local MonetizationService = require(script.Parent:WaitForChild("MonetizationService"))

local PlotService = {}
PlotService.OnChanged = nil :: ((Player) -> ())? -- o Main liga isto (atualiza dinheiro na tela)

local owners = {} -- [índice do lote] = player
local plotOf = {} -- [player] = índice do lote

local FONT = Enum.Font.FredokaOne

local function label(parent, props)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = FONT
	text.TextScaled = true
	text.TextColor3 = props.Color or Color3.new(1, 1, 1)
	text.Text = props.Text or ""
	text.Size = props.Size
	text.Position = props.Position or UDim2.new()
	text.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.Parent = text
	return text
end

function PlotService.GetIndex(player)
	return plotOf[player]
end

function PlotService.GetOwner(index)
	return owners[index]
end

local function plotModel(player)
	local index = plotOf[player]
	return index and MapService.GetPlotModel(index)
end

function PlotService.TreadmillZone(player)
	local model = plotModel(player)
	local treadmill = model and model:FindFirstChild("Esteira")
	return treadmill and treadmill:FindFirstChild("Zona")
end

-- Aquário ----------------------------------------------------------------------------------

local COLUMNS = 8
local function slotOffset(slot)
	local col = (slot - 1) % COLUMNS
	local row = math.floor((slot - 1) / COLUMNS)
	return Vector3.new(-19.25 + col * 5.5, 6.5 + row * 8, -0.5), row
end

function PlotService.Render(player)
	local data = DataService.Get(player)
	local model = plotModel(player)
	if not data or not model then
		return
	end
	local folder = model.Aquario.Peixes
	folder:ClearAllChildren()
	local origin = folder:GetAttribute("Origin")

	for slot, uid in ipairs(data.Aquarium) do
		local entry = DataService.FindFish(data, uid)
		local species = entry and Fish.Get(entry.S)
		if species then
			local sizeDef = Fish.Sizes[entry.Z] or Fish.Sizes.Normal
			local scale = math.min(0.62, 0.46 * sizeDef.Scale ^ 0.6)
			local fish = FishModel.Build(entry.S, entry.M, entry.Z, { Saddle = false, Scale = scale })
			local offset, row = slotOffset(slot)
			local facing = (row % 2 == 0) and math.pi / 2 or -math.pi / 2
			fish:PivotTo(CFrame.new(origin + offset) * CFrame.Angles(0, facing, 0))
			fish:SetAttribute("Bob", slot * 0.7)
			fish:SetAttribute("BaseY", origin.Y + offset.Y)

			local tag = Instance.new("BillboardGui")
			tag.Name = "Etiqueta"
			tag.Size = UDim2.new(7, 0, 2.4, 0)
			tag.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
			tag.MaxDistance = 70
			tag.LightInfluence = 0
			tag.Parent = fish.PrimaryPart
			local rarity = Fish.Rarities[species.Rarity]
			label(tag, { Text = species.Name, Color = rarity.Color, Size = UDim2.fromScale(1, 0.42) })
			local tags = Fish.Tags(entry)
			if tags ~= "" then
				local mutation = Fish.Mutations[entry.M]
				label(tag, { Text = tags, Color = mutation.Color, Size = UDim2.fromScale(1, 0.26), Position = UDim2.fromScale(0, 0.4) })
			end
			label(tag, {
				Text = "$" .. NumberFormat.Rate(Fish.Income(entry)) .. "/s",
				Color = Color3.fromRGB(90, 255, 90),
				Size = UDim2.fromScale(1, 0.34),
				Position = UDim2.fromScale(0, 0.66),
			})
			fish.Parent = folder
		end
	end
end

-- Placas -----------------------------------------------------------------------------------

local GREEN = ColorSequence.new(Color3.fromRGB(140, 245, 90), Color3.fromRGB(40, 175, 45))
local RED = ColorSequence.new(Color3.fromRGB(255, 105, 115), Color3.fromRGB(215, 35, 55))
local GRAY = ColorSequence.new(Color3.fromRGB(150, 150, 160), Color3.fromRGB(95, 95, 108))

-- canBuy: true (verde), false (vermelho) ou nil (nível máximo, cinza)
local function setSign(sign, title, level, info, price, canBuy)
	local gui = sign and sign:FindFirstChild("Placa") and sign.Placa:FindFirstChild("Gui")
	local frame = gui and gui:FindFirstChild("Board")
	if not frame then
		return
	end
	frame.Title.Text = title
	frame.Level.Text = level
	frame.Info.Text = info
	frame.PriceButton.Label.Text = price
	frame.PriceButton.Fill.Color = (canBuy == nil and GRAY) or (canBuy and GREEN) or RED
	local alert = sign:FindFirstChild("Alerta")
	if alert and alert:FindFirstChild("Gui") then
		alert.Gui.Enabled = canBuy == true
	end
end

function PlotService.RefreshSigns(player)
	local data = DataService.Get(player)
	local model = plotModel(player)
	if not data or not model then
		return
	end
	local hasPass = MonetizationService.HasPass(player, "StaminaX2")
	local mult = Progression.StaminaMultiplier(data.BestAura, hasPass)

	-- esteira
	local level = data.TreadmillLevel
	local cost = Progression.TreadmillCost(level)
	local now = Progression.TreadmillRate(level) * mult
	if cost then
		local nextRate = Progression.TreadmillRate(level + 1) * mult
		setSign(
			model.PlacaEsteira,
			"Melhorar Esteira",
			("Nível %d > Nível %d"):format(level, level + 1),
			("+%s > +%s Stamina/s"):format(NumberFormat.Rate(now), NumberFormat.Rate(nextRate)),
			NumberFormat.Money(cost),
			data.Money >= cost
		)
	else
		setSign(model.PlacaEsteira, "Esteira", ("Nível %d (máximo)"):format(level), ("+%s Stamina/s"):format(NumberFormat.Rate(now)), "MÁXIMO", nil)
	end

	-- painel da própria esteira
	local console = model.Esteira:FindFirstChild("Painel")
	local consoleFrame = console and console:FindFirstChild("Gui") and console.Gui:FindFirstChildOfClass("Frame")
	if consoleFrame then
		consoleFrame.Rate.Text = ("⚡ +%s/s"):format(NumberFormat.Rate(now))
	end

	-- aquário
	local aqLevel = data.AquariumLevel
	local aqCost = Progression.AquariumCost(aqLevel)
	local slots = Progression.AquariumSlots(aqLevel)
	if aqCost then
		setSign(
			model.PlacaAquario,
			"Melhorar Aquário",
			("Nível %d > Nível %d"):format(aqLevel, aqLevel + 1),
			("%d > %d vagas para peixes"):format(slots, Progression.AquariumSlots(aqLevel + 1)),
			NumberFormat.Money(aqCost),
			data.Money >= aqCost
		)
	else
		setSign(model.PlacaAquario, "Aquário", ("Nível %d (máximo)"):format(aqLevel), ("%d vagas para peixes"):format(slots), "MÁXIMO", nil)
	end
end

function PlotService.UpdateIncome(player, income)
	local model = plotModel(player)
	local anchor = model and model.Aquario:FindFirstChild("NomeDono")
	local gui = anchor and anchor:FindFirstChild("Gui")
	if gui then
		gui.Income.Text = "$" .. NumberFormat.Rate(income) .. "/s"
	end
end

-- Melhorias --------------------------------------------------------------------------------

function PlotService.Upgrade(player, kind)
	local data = DataService.Get(player)
	if not data then
		return { ok = false }
	end
	local cost, apply, name
	if kind == "Treadmill" then
		cost = Progression.TreadmillCost(data.TreadmillLevel)
		name = "Esteira"
		apply = function()
			data.TreadmillLevel += 1
		end
	elseif kind == "Aquarium" then
		cost = Progression.AquariumCost(data.AquariumLevel)
		name = "Aquário"
		apply = function()
			data.AquariumLevel += 1
		end
	else
		return { ok = false }
	end
	if not cost then
		Net.Notify(player, name .. " já está no nível máximo", "info")
		return { ok = false }
	end
	if data.Money < cost then
		Net.Notify(player, "Falta " .. NumberFormat.Money(cost - data.Money) .. " para melhorar", "erro")
		return { ok = false }
	end
	data.Money -= cost
	apply()
	Net.Notify(player, name .. " melhorado!", "ok")
	PlotService.RefreshSigns(player)
	Net.Sync(player)
	if PlotService.OnChanged then
		PlotService.OnChanged(player)
	end
	return { ok = true }
end

-- Dono do lote -----------------------------------------------------------------------------

function PlotService.Assign(player)
	for index = 1, #Layout.Plots do
		if not owners[index] then
			owners[index] = player
			plotOf[player] = index
			player:SetAttribute("Plot", index)
			local model = MapService.GetPlotModel(index)
			if model then
				model:SetAttribute("Owner", player.UserId)
				local gui = model.Aquario.NomeDono.Gui
				gui.Owner.Text = player.DisplayName
				gui.Avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(player.UserId)
			end
			PlotService.Render(player)
			PlotService.RefreshSigns(player)
			return index
		end
	end
	return nil
end

function PlotService.Release(player)
	local index = plotOf[player]
	if not index then
		return
	end
	owners[index] = nil
	plotOf[player] = nil
	local model = MapService.GetPlotModel(index)
	if model then
		model:SetAttribute("Owner", nil)
		model.Aquario.Peixes:ClearAllChildren()
		local gui = model.Aquario.NomeDono.Gui
		gui.Owner.Text = "Lote livre"
		gui.Income.Text = ""
		gui.Avatar.Image = ""
	end
end

function PlotService.SpawnCFrame(player)
	local index = plotOf[player]
	local plot = index and Layout.Plots[index]
	if not plot then
		return CFrame.new(Layout.LobbySpawn + Vector3.new(0, 3, 0))
	end
	return CFrame.new(plot.Spawn.X, Track.BEACH_Y + 1 + 3.2, plot.Spawn.Z)
end

function PlotService.SendHome(player)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(PlotService.SpawnCFrame(player))
	end
end

function PlotService.Start()
	for index = 1, #Layout.Plots do
		local model = MapService.GetPlotModel(index)
		if model then
			for kind, signName in pairs({ Treadmill = "PlacaEsteira", Aquarium = "PlacaAquario" }) do
				local prompt = model[signName].Placa:FindFirstChild("Prompt")
				if prompt then
					prompt.Triggered:Connect(function(player)
						if plotOf[player] == index then
							PlotService.Upgrade(player, kind)
						else
							Net.Notify(player, "Este lote não é seu", "erro")
						end
					end)
				end
			end
		end
	end

	Net.On("Upgrade", function(player, kind)
		return PlotService.Upgrade(player, kind)
	end)
end

return PlotService
