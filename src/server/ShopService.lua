-- ShopService (ModuleScript)
-- Fica em: ServerScriptService > Server > ShopService
--
-- Tudo o que o jogador faz com os peixes e o dinheiro fora da corrida:
--   * aquário: colocar, tirar, "colocar os melhores";
--   * barraca de VENDER PEIXES: vender um ou todos (os raros só se o jogador marcar);
--   * barraca das AURAS: comprar a próxima aura (sempre melhor) e equipar qualquer uma
--     já comprada (o bônus é sempre o da melhor);
--   * índex: pegar o prêmio de cada peixe e o de área completa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Fish = require(Shared:WaitForChild("Fish"))
local Progression = require(Shared:WaitForChild("Progression"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local Net = require(script.Parent:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local ShopService = {}
ShopService.OnChanged = nil :: ((Player) -> ())? -- o Main liga isto (atualiza dinheiro na tela)

local function changed(player, aquariumChanged)
	if aquariumChanged then
		PlotService.Render(player)
	end
	PlotService.RefreshSigns(player)
	Net.Sync(player)
	if ShopService.OnChanged then
		ShopService.OnChanged(player)
	end
end

-- Aquário ----------------------------------------------------------------------------------

local function equip(player, uid)
	local data = DataService.Get(player)
	if not data or not DataService.FindFish(data, uid) or DataService.InAquarium(data, uid) then
		return { ok = false }
	end
	if #data.Aquarium >= DataService.AquariumSlots(data) then
		return { ok = false, msg = "Aquário cheio. Melhore o aquário para ter mais vagas." }
	end
	table.insert(data.Aquarium, uid)
	changed(player, true)
	return { ok = true }
end

local function unequip(player, uid)
	local data = DataService.Get(player)
	local index = data and table.find(data.Aquarium, uid)
	if not index then
		return { ok = false }
	end
	if DataService.StoredCount(data) >= Config.MAX_STORED_FISH then
		return { ok = false, msg = "Coleção cheia. Venda peixes antes." }
	end
	table.remove(data.Aquarium, index)
	changed(player, true)
	return { ok = true }
end

local function equipBest(player)
	local data = DataService.Get(player)
	if not data then
		return { ok = false }
	end
	local sorted = table.clone(data.Fish)
	table.sort(sorted, function(a, b)
		return Fish.Income(a) > Fish.Income(b)
	end)
	local slots = DataService.AquariumSlots(data)
	data.Aquarium = {}
	for i = 1, math.min(slots, #sorted) do
		table.insert(data.Aquarium, sorted[i].Uid)
	end
	changed(player, true)
	return { ok = true }
end

-- Venda ------------------------------------------------------------------------------------

local function removeFish(data, uid)
	local _, index = DataService.FindFish(data, uid)
	if index then
		table.remove(data.Fish, index)
	end
end

local function sell(player, uid)
	local data = DataService.Get(player)
	local entry = data and DataService.FindFish(data, uid)
	if not entry then
		return { ok = false }
	end
	if DataService.InAquarium(data, uid) then
		return { ok = false, msg = "Tire o peixe do aquário antes de vender" }
	end
	local value = Fish.SellValue(entry, Config.SELL_SECONDS)
	removeFish(data, uid)
	data.Money += value
	Net.Notify(player, "Vendido por " .. NumberFormat.Money(value), "ok")
	changed(player, false)
	return { ok = true, Value = value }
end

local function sellAll(player, includePrecious)
	local data = DataService.Get(player)
	if not data then
		return { ok = false }
	end
	local total, count = 0, 0
	local keep = {}
	for _, entry in ipairs(data.Fish) do
		local inAquarium = DataService.InAquarium(data, entry.Uid)
		if not inAquarium and (includePrecious == true or not Fish.IsPrecious(entry)) then
			total += Fish.SellValue(entry, Config.SELL_SECONDS)
			count += 1
		else
			table.insert(keep, entry)
		end
	end
	if count == 0 then
		return { ok = false, msg = "Nada para vender" }
	end
	data.Fish = keep
	data.Money += total
	Net.Notify(player, ("%d peixes vendidos por %s"):format(count, NumberFormat.Money(total)), "ok")
	changed(player, false)
	return { ok = true, Value = total, Count = count }
end

-- Vende os peixes escolhidos na tela (lista de Uids). Os do aquário são ignorados.
local function sellMany(player, uids)
	local data = DataService.Get(player)
	if not data or type(uids) ~= "table" then
		return { ok = false }
	end
	local wanted = {}
	for _, uid in ipairs(uids) do
		if type(uid) == "number" then
			wanted[uid] = true
		end
	end
	local total, count = 0, 0
	local keep = {}
	for _, entry in ipairs(data.Fish) do
		if wanted[entry.Uid] and not DataService.InAquarium(data, entry.Uid) then
			total += Fish.SellValue(entry, Config.SELL_SECONDS)
			count += 1
		else
			table.insert(keep, entry)
		end
	end
	if count == 0 then
		return { ok = false, msg = "Nada para vender" }
	end
	data.Fish = keep
	data.Money += total
	Net.Notify(player, ("%d peixe(s) vendido(s) por %s"):format(count, NumberFormat.Money(total)), "ok")
	changed(player, false)
	return { ok = true, Value = total, Count = count }
end

-- Auras ------------------------------------------------------------------------------------

function ShopService.ApplyAura(player)
	local data = DataService.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root then
		return
	end
	local old = root:FindFirstChild("AuraFx")
	if old then
		old:Destroy()
	end
	local aura = Progression.Auras[data.Aura]
	if not aura then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "AuraFx"
	attachment.Position = Vector3.new(0, -1.5, 0)
	attachment.Parent = root

	local ring = Instance.new("ParticleEmitter")
	ring.Name = "Brilho"
	ring.Color = ColorSequence.new(aura.Color, Color3.new(1, 1, 1))
	ring.LightEmission = 0.8
	ring.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	ring.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	ring.Lifetime = NumberRange.new(0.8, 1.4)
	ring.Rate = 18 + data.Aura * 6
	ring.Speed = NumberRange.new(2, 4)
	ring.SpreadAngle = Vector2.new(180, 180)
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Acceleration = Vector3.new(0, 4, 0)
	ring.Parent = attachment

	local light = Instance.new("PointLight")
	light.Color = aura.Color
	light.Range = 8 + data.Aura
	light.Brightness = 1.2
	light.Parent = attachment
end

local function buyAura(player, index)
	local data = DataService.Get(player)
	if not data or type(index) ~= "number" then
		return { ok = false }
	end
	local aura = Progression.Auras[index]
	if not aura or index ~= data.BestAura + 1 then
		return { ok = false, msg = "Compre as auras em ordem" }
	end
	if data.Money < aura.Price then
		return { ok = false, msg = "Falta " .. NumberFormat.Money(aura.Price - data.Money) }
	end
	data.Money -= aura.Price
	data.BestAura = index
	data.Aura = index
	ShopService.ApplyAura(player)
	Net.Notify(player, "Aura " .. aura.Name .. " comprada! Stamina da esteira melhorou.", "raro")
	changed(player, false)
	return { ok = true }
end

local function equipAura(player, index)
	local data = DataService.Get(player)
	if not data or type(index) ~= "number" or index < 0 or index > data.BestAura then
		return { ok = false }
	end
	data.Aura = index
	ShopService.ApplyAura(player)
	changed(player, false)
	return { ok = true }
end

-- Índex ------------------------------------------------------------------------------------

local function claimSpecies(player, data, speciesId)
	local rec = data.Index[speciesId]
	if not rec or not rec.F or rec.C then
		return false, 0, 0
	end
	local money, stamina = Progression.IndexReward(speciesId)
	rec.C = true
	data.Money += money
	data.Stamina += stamina
	return true, money, stamina
end

local function claimIndex(player, speciesId)
	local data = DataService.Get(player)
	if not data or type(speciesId) ~= "string" then
		return { ok = false }
	end
	local ok, money, stamina = claimSpecies(player, data, speciesId)
	if not ok then
		return { ok = false, msg = "Prêmio indisponível" }
	end
	Net.Notify(player, ("+%s e +⚡%s"):format(NumberFormat.Money(money), NumberFormat.Abbreviate(stamina)), "ok")
	changed(player, false)
	return { ok = true }
end

local function claimAllIndex(player)
	local data = DataService.Get(player)
	if not data then
		return { ok = false }
	end
	local totalMoney, totalStamina, count = 0, 0, 0
	for speciesId in pairs(data.Index) do
		local ok, money, stamina = claimSpecies(player, data, speciesId)
		if ok then
			totalMoney += money
			totalStamina += stamina
			count += 1
		end
	end
	if count == 0 then
		return { ok = false, msg = "Nenhum prêmio para pegar" }
	end
	Net.Notify(player, ("%d prêmios: +%s e +⚡%s"):format(count, NumberFormat.Money(totalMoney), NumberFormat.Abbreviate(totalStamina)), "ok")
	changed(player, false)
	return { ok = true }
end

local function claimArea(player, area)
	local data = DataService.Get(player)
	if not data or type(area) ~= "number" or not Fish.ByArea[area] then
		return { ok = false }
	end
	if data.Areas[tostring(area)] then
		return { ok = false, msg = "Prêmio já pego" }
	end
	for _, species in ipairs(Fish.ByArea[area]) do
		local rec = data.Index[species.Id]
		if not rec or not rec.F then
			return { ok = false, msg = "Dome a versão normal de todos os peixes da área" }
		end
	end
	local money, stamina = Progression.AreaReward(area)
	data.Areas[tostring(area)] = true
	data.Money += money
	data.Stamina += stamina
	Net.Notify(player, ("Área completa! +%s e +⚡%s"):format(NumberFormat.Money(money), NumberFormat.Abbreviate(stamina)), "raro")
	changed(player, false)
	return { ok = true }
end

-- Usado pela mochila: clicar segurando o peixe coloca no aquário.
function ShopService.Equip(player, uid)
	local result = equip(player, uid)
	if result.msg then
		Net.Notify(player, result.msg, "erro")
	elseif result.ok then
		Net.Notify(player, "Peixe colocado no aquário!", "ok")
	end
	return result
end

function ShopService.Start()
	Net.On("Equip", equip)
	Net.On("Unequip", unequip)
	Net.On("EquipBest", equipBest)
	Net.On("Sell", sell)
	Net.On("SellAll", sellAll)
	Net.On("SellMany", sellMany)
	Net.On("BuyAura", buyAura)
	Net.On("EquipAura", equipAura)
	Net.On("ClaimIndex", claimIndex)
	Net.On("ClaimAllIndex", claimAllIndex)
	Net.On("ClaimArea", claimArea)
end

return ShopService
