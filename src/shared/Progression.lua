-- Progression (ModuleScript)
-- Fica em: ReplicatedStorage > Shared > Progression
--
-- As contas de progresso, iguais no servidor (que decide) e no cliente (que mostra):
-- esteira, aquário, auras, bônus e prêmios do índex.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Fish = require(Shared:WaitForChild("Fish"))

local Progression = {}

-- Auras (barraca das auras) ----------------------------------------------------------------
-- Cada aura nova é sempre melhor que a anterior: +0.5 no multiplicador da esteira.
-- Só se compra com dinheiro do jogo. As antigas podem ser equipadas só pelo visual:
-- o bônus é sempre o da MELHOR aura comprada.
Progression.Auras = {
	{ Name = "Bolhas", Mult = 1.5, Price = 5000, Color = Color3.fromRGB(160, 230, 255) },
	{ Name = "Coral", Mult = 2, Price = 60000, Color = Color3.fromRGB(255, 120, 140) },
	{ Name = "Maré", Mult = 2.5, Price = 700000, Color = Color3.fromRGB(40, 170, 255) },
	{ Name = "Água-viva", Mult = 3, Price = 8000000, Color = Color3.fromRGB(230, 120, 255) },
	{ Name = "Tempestade", Mult = 3.5, Price = 90000000, Color = Color3.fromRGB(255, 240, 90) },
	{ Name = "Abissal", Mult = 4, Price = 1000000000, Color = Color3.fromRGB(120, 60, 255) },
	{ Name = "Kraken", Mult = 4.5, Price = 12000000000, Color = Color3.fromRGB(255, 70, 70) },
	{ Name = "Netuno", Mult = 5, Price = 150000000000, Color = Color3.fromRGB(80, 255, 200) },
}

-- Esteira ----------------------------------------------------------------------------------
function Progression.TreadmillRate(level)
	local t = Config.TREADMILL
	return math.floor(t.BASE_RATE * t.RATE_GROWTH ^ (level - 1) + 0.5)
end

-- Preço para subir do nível atual para o próximo (nil = nível máximo).
function Progression.TreadmillCost(level)
	local t = Config.TREADMILL
	if level >= t.MAX_LEVEL then
		return nil
	end
	return math.floor(t.BASE_COST * t.COST_GROWTH ^ (level - 1))
end

-- Aquário ----------------------------------------------------------------------------------
function Progression.AquariumSlots(level)
	local a = Config.AQUARIUM
	return math.min(a.MAX_SLOTS, a.START_SLOTS + level - 1)
end

function Progression.AquariumMaxLevel()
	local a = Config.AQUARIUM
	return a.MAX_SLOTS - a.START_SLOTS + 1
end

function Progression.AquariumCost(level)
	local a = Config.AQUARIUM
	if level >= Progression.AquariumMaxLevel() then
		return nil
	end
	return math.floor(a.BASE_COST * a.COST_GROWTH ^ (level - 1))
end

-- Bônus ------------------------------------------------------------------------------------
-- Multiplicador da stamina da esteira: aura + gamepass, SOMADOS (veja Config.BONUS_MODE).
function Progression.StaminaMultiplier(bestAura, hasStaminaPass)
	local auraMult = 1
	local aura = Progression.Auras[bestAura or 0]
	if aura then
		auraMult = aura.Mult
	end
	local passMult = hasStaminaPass and 2 or 1
	if Config.BONUS_MODE == "multiplica" then
		return auraMult * passMult
	end
	return 1 + (auraMult - 1) + (passMult - 1)
end

function Progression.MoneyMultiplier(hasMoneyPass)
	return hasMoneyPass and 2 or 1
end

-- Stamina por segundo na esteira, com todos os bônus.
function Progression.StaminaPerSecond(treadmillLevel, bestAura, hasStaminaPass)
	return Progression.TreadmillRate(treadmillLevel) * Progression.StaminaMultiplier(bestAura, hasStaminaPass)
end

-- Índex ------------------------------------------------------------------------------------
function Progression.IndexReward(speciesId)
	local species = Fish.Get(speciesId)
	if not species then
		return 0, 0
	end
	local money = math.floor(species.Income * Config.INDEX_REWARD.MONEY_SECONDS)
	local stamina = math.max(1, math.floor(species.Stamina * Config.INDEX_REWARD.STAMINA_FRACTION))
	return money, stamina
end

function Progression.AreaReward(area)
	local income, stamina = 0, 0
	for _, species in ipairs(Fish.ByArea[area] or {}) do
		income += species.Income
		stamina += species.Stamina
	end
	return math.floor(income * Config.AREA_REWARD.MONEY_SECONDS), math.floor(stamina * Config.AREA_REWARD.STAMINA_FRACTION)
end

-- Cor da stamina necessária: "Green", "Yellow" ou "Red".
function Progression.StaminaState(playerStamina, required)
	if playerStamina >= required then
		return "Green"
	elseif playerStamina >= required * Config.STAMINA_YELLOW_AT then
		return "Yellow"
	end
	return "Red"
end

Progression.StateColors = {
	Green = Color3.fromRGB(80, 255, 90),
	Yellow = Color3.fromRGB(255, 225, 50),
	Red = Color3.fromRGB(255, 70, 60),
}
Progression.StateIcons = { Green = "✓", Yellow = "!", Red = "✗" }

return Progression
