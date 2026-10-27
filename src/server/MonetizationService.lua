-- MonetizationService (ModuleScript)
-- Fica em: ServerScriptService > Server > MonetizationService
--
-- Gamepasses (Dinheiro x2, Stamina x2) e produtos (Reviver, pacotes de dinheiro).
-- Os números (Id) ficam em Config.GAMEPASSES e Config.PRODUCTS. Com Id = 0:
--   * no jogo publicado, o botão aparece como "Em breve" e nada acontece;
--   * no Studio, o botão dá o item DE GRAÇA, só para você testar.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Progression = require(Shared:WaitForChild("Progression"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local Net = require(script.Parent:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local MonetizationService = {}

local passes = {} -- [player] = { MoneyX2 = true, ... }
local hooks: { [string]: any } = {} -- funções chamadas quando algo é comprado: hooks.Revive(player), hooks.Changed(player)

local function passByKey(key)
	for _, pass in ipairs(Config.GAMEPASSES) do
		if pass.Key == key then
			return pass
		end
	end
	return nil
end

local function productByKey(key)
	for _, product in ipairs(Config.PRODUCTS) do
		if product.Key == key then
			return product
		end
	end
	return nil
end

local function productById(id)
	for _, product in ipairs(Config.PRODUCTS) do
		if product.Id ~= 0 and product.Id == id then
			return product
		end
	end
	return nil
end

function MonetizationService.SetHooks(newHooks)
	hooks = newHooks
end

function MonetizationService.HasPass(player, key)
	return passes[player] ~= nil and passes[player][key] == true
end

-- Multiplicador do passe de stamina (o maior degrau comprado: 1, 2, 4, 6 ou 8)
function MonetizationService.StaminaMult(player)
	return Progression.LadderMult("Stamina", passes[player])
end

function MonetizationService.GetPasses(player)
	return passes[player] or {}
end

-- Quanto dá um pacote de dinheiro agora (cresce com a renda do jogador).
function MonetizationService.CashAmount(product, income)
	return math.max(product.Minimum or 0, math.floor((income or 0) * 60 * (product.Minutes or 10)))
end

local function grantProduct(player, product)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	if product.Key == "Revive" then
		if hooks.Revive then
			return hooks.Revive(player)
		end
		return false
	end
	local income = player:GetAttribute("Income") or 0
	local amount = MonetizationService.CashAmount(product, income)
	data.Money += amount
	Net.Notify(player, "+" .. NumberFormat.Money(amount) .. " de dinheiro!", "ok")
	if hooks.Changed then
		hooks.Changed(player)
	end
	return true
end

function MonetizationService.PlayerAdded(player)
	passes[player] = {}
	for _, pass in ipairs(Config.GAMEPASSES) do
		if pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				passes[player][pass.Key] = true
			end
		end
	end
end

function MonetizationService.PlayerRemoving(player)
	passes[player] = nil
end

function MonetizationService.Start()
	Net.On("BuyPass", function(player, key)
		local pass = passByKey(key)
		if not pass then
			return { ok = false }
		end
		if MonetizationService.HasPass(player, key) then
			return { ok = false, msg = "Você já tem este gamepass" }
		end
		local previous = Progression.PreviousLadderPass(pass)
		if previous and not MonetizationService.HasPass(player, previous.Key) then
			return { ok = false, msg = "Compre o " .. previous.Name .. " antes" }
		end
		if pass.Id == 0 then
			if RunService:IsStudio() then
				passes[player][key] = true
				Net.Notify(player, pass.Name .. " liberado (teste no Studio)", "ok")
				if hooks.Changed then
					hooks.Changed(player)
				end
				return { ok = true }
			end
			return { ok = false, msg = "Em breve!" }
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		return { ok = true }
	end)

	Net.On("BuyProduct", function(player, key)
		local product = productByKey(key)
		if not product then
			return { ok = false }
		end
		if product.Id == 0 then
			if RunService:IsStudio() then
				local granted = grantProduct(player, product)
				return { ok = granted, msg = if granted then nil else "Não deu para usar agora" }
			end
			return { ok = false, msg = "Em breve!" }
		end
		MarketplaceService:PromptProductPurchase(player, product.Id)
		return { ok = true }
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in ipairs(Config.GAMEPASSES) do
			if pass.Id == passId and passes[player] then
				passes[player][pass.Key] = true
				Net.Notify(player, pass.Name .. " ativado. Obrigado!", "raro")
				if hooks.Changed then
					hooks.Changed(player)
				end
			end
		end
	end)

	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local data = player and DataService.Get(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if table.find(data.Purchases, info.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local product = productById(info.ProductId)
		if not product then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not grantProduct(player, product) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(data.Purchases, info.PurchaseId)
		while #data.Purchases > 50 do
			table.remove(data.Purchases, 1)
		end
		task.spawn(DataService.Save, player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return MonetizationService
