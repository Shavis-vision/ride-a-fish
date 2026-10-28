-- EconomyService (ModuleScript)
-- Fica em: ServerScriptService > Server > EconomyService
--
-- O dinheiro do aquário entrando a cada segundo, o treino na esteira (stamina por
-- segundo enquanto o jogador está em cima dela) e os números que o cliente lê
-- (atributos Money, Stamina, Income, StaminaRate, Training e o leaderstats).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Fish = require(Shared:WaitForChild("Fish"))
local Progression = require(Shared:WaitForChild("Progression"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local MonetizationService = require(script.Parent:WaitForChild("MonetizationService"))

local EconomyService = {}

-- Renda por segundo do aquário, com o gamepass.
function EconomyService.Income(player, data)
	local total = 0
	for _, uid in ipairs(data.Aquarium) do
		local entry = DataService.FindFish(data, uid)
		if entry then
			total += Fish.Income(entry)
		end
	end
	return total * Progression.MoneyMultiplier(MonetizationService.HasPass(player, "MoneyX2"))
end

function EconomyService.StaminaRate(player, data)
	return Progression.StaminaPerSecond(data.TreadmillLevel, data.BestAura, MonetizationService.StaminaMult(player))
end

-- Atualiza os atributos e o placar do jogador agora.
function EconomyService.Publish(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local income = EconomyService.Income(player, data)
	player:SetAttribute("Money", data.Money)
	player:SetAttribute("Stamina", data.Stamina)
	player:SetAttribute("Income", income)
	player:SetAttribute("StaminaRate", EconomyService.StaminaRate(player, data))

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Income.Value = "$" .. NumberFormat.Rate(income) .. "/s"
		stats.Stamina.Value = "⚡" .. NumberFormat.Abbreviate(data.Stamina)
	end
	PlotService.UpdateIncome(player, income)
end

function EconomyService.PlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local renda = Instance.new("StringValue")
	renda.Name = "Income"
	renda.Parent = stats
	local stamina = Instance.new("StringValue")
	stamina.Name = "Stamina"
	stamina.Parent = stats
	stats.Parent = player
	EconomyService.Publish(player)
end

local function insideZone(zone, position)
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

function EconomyService.Start()
	-- renda do aquário
	task.spawn(function()
		while true do
			task.wait(Config.INCOME_TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.Get(player)
				if data then
					local income = EconomyService.Income(player, data) * Config.INCOME_TICK
					data.Money += income
					data.TotalEarned += income
					EconomyService.Publish(player)
					PlotService.RefreshSigns(player)
				end
			end
		end
	end)

	-- treino na esteira
	task.spawn(function()
		local tick = Config.TREADMILL.TICK
		while true do
			task.wait(tick)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.Get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local training = false
				if data and root and not player:GetAttribute("Running") then
					local zone = PlotService.TreadmillZone(player)
					if zone and insideZone(zone, root.Position) then
						training = true
						data.Stamina += EconomyService.StaminaRate(player, data) * tick
						player:SetAttribute("Stamina", data.Stamina)
					end
				end
				if player:GetAttribute("Training") ~= training then
					player:SetAttribute("Training", training)
				end
			end
		end
	end)
end

return EconomyService
