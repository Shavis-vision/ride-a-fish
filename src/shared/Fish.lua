-- Fish (ModuleScript)
-- Fica em: ReplicatedStorage > Shared > Fish
--
-- Catálogo dos peixes: 3 áreas x 8 peixes. Nomes, números e cores são PROVISÓRIOS,
-- para testar. Todos usam o mesmo modelo (FishModel.lua) com cores e proporções diferentes.
--
-- Cada peixe tem:
--   Stamina  = stamina que você precisa ter para domar (tamanho Normal)
--   Income   = dinheiro por segundo no aquário (mutação Normal, tamanho Normal)
--   Speed    = velocidade quando você está montado (studs por segundo)
--   TameTime = segundos em cima dele para domar
--   Ability  = habilidade especial (opcional): "Salto", "Turbo" ou "Casco"
--   Shape    = proporções do modelo: Length (comprimento), Height (altura), Spikes (espinhos)

local Fish = {}

-- Raridades ------------------------------------------------------------------------------
Fish.RarityOrder = { "Comum", "Incomum", "Raro", "Epico", "Lendario" }
Fish.Rarities = {
	Comum = { Name = "Comum", Order = 1, Weight = 22, Color = Color3.fromRGB(200, 200, 200) },
	Incomum = { Name = "Incomum", Order = 2, Weight = 12, Color = Color3.fromRGB(90, 220, 90) },
	Raro = { Name = "Raro", Order = 3, Weight = 6, Color = Color3.fromRGB(70, 160, 255) },
	Epico = { Name = "Épico", Order = 4, Weight = 3, Color = Color3.fromRGB(190, 90, 255) },
	Lendario = { Name = "Lendário", Order = 5, Weight = 1, Color = Color3.fromRGB(255, 190, 40) },
}

-- Mutações (multiplicam a renda) -----------------------------------------------------------
Fish.MutationOrder = { "Normal", "Prata", "Dourado", "Diamante", "ArcoIris" }
Fish.Mutations = {
	Normal = { Name = "Normal", Mult = 1, Chance = 0.86, Color = Color3.fromRGB(255, 255, 255) },
	Prata = { Name = "Prata", Mult = 2, Chance = 0.08, Color = Color3.fromRGB(205, 215, 230) },
	Dourado = { Name = "Dourado", Mult = 4, Chance = 0.04, Color = Color3.fromRGB(255, 200, 40) },
	Diamante = { Name = "Diamante", Mult = 8, Chance = 0.015, Color = Color3.fromRGB(120, 235, 255) },
	ArcoIris = { Name = "Arco-íris", Mult = 15, Chance = 0.005, Color = Color3.fromRGB(255, 120, 220) },
}

-- Tamanhos (mudam renda, stamina necessária, velocidade e o tamanho do modelo) ---------------
Fish.SizeOrder = { "Mini", "Normal", "Grande", "Enorme", "Gigante" }
Fish.Sizes = {
	Mini = { Name = "Mini", Scale = 0.65, Income = 0.5, Stamina = 0.6, Speed = 1.1, Chance = 0.12 },
	Normal = { Name = "Normal", Scale = 1, Income = 1, Stamina = 1, Speed = 1, Chance = 0.6 },
	Grande = { Name = "Grande", Scale = 1.3, Income = 1.6, Stamina = 1.4, Speed = 0.95, Chance = 0.18 },
	Enorme = { Name = "Enorme", Scale = 1.65, Income = 2.5, Stamina = 2, Speed = 0.9, Chance = 0.08 },
	Gigante = { Name = "Gigante", Scale = 2.1, Income = 4, Stamina = 3, Speed = 0.85, Chance = 0.02 },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Espécies ---------------------------------------------------------------------------------
Fish.Species = {
	-- Área 1: Recife Raso
	{ Id = "palhaco", Name = "Peixe-Palhaço", Area = 1, Rarity = "Comum", Stamina = 10, Income = 2, Speed = 30, TameTime = 2,
		Colors = { Body = rgb(255, 120, 30), Belly = rgb(255, 170, 90), Fin = rgb(20, 20, 20), Stripe = rgb(255, 255, 255) },
		Shape = { Length = 0.9, Height = 1.1 } },
	{ Id = "sardinha", Name = "Sardinha", Area = 1, Rarity = "Comum", Stamina = 18, Income = 3, Speed = 34, TameTime = 2.2,
		Colors = { Body = rgb(120, 150, 190), Belly = rgb(220, 230, 240), Fin = rgb(80, 100, 140), Stripe = rgb(90, 120, 170) },
		Shape = { Length = 1.15, Height = 0.8 } },
	{ Id = "cirurgiao", Name = "Peixe-Cirurgião", Area = 1, Rarity = "Incomum", Stamina = 35, Income = 5, Speed = 36, TameTime = 2.5,
		Colors = { Body = rgb(30, 90, 220), Belly = rgb(60, 130, 255), Fin = rgb(255, 220, 30), Stripe = rgb(15, 25, 60) },
		Shape = { Length = 1.0, Height = 1.2 } },
	{ Id = "baiacu", Name = "Baiacu", Area = 1, Rarity = "Incomum", Stamina = 60, Income = 8, Speed = 30, TameTime = 2.8,
		Colors = { Body = rgb(230, 200, 120), Belly = rgb(250, 240, 200), Fin = rgb(180, 140, 70), Stripe = rgb(140, 100, 50) },
		Shape = { Length = 0.8, Height = 1.4, Spikes = true } },
	{ Id = "cavalo", Name = "Cavalo-Marinho", Area = 1, Rarity = "Raro", Stamina = 110, Income = 13, Speed = 38, TameTime = 3,
		Colors = { Body = rgb(255, 210, 60), Belly = rgb(255, 235, 140), Fin = rgb(255, 150, 40), Stripe = rgb(230, 160, 30) },
		Shape = { Length = 0.85, Height = 1.5, Spikes = true } },
	{ Id = "tartaruga", Name = "Tartaruga-Marinha", Area = 1, Rarity = "Raro", Stamina = 200, Income = 22, Speed = 32, TameTime = 3.2,
		Colors = { Body = rgb(70, 150, 80), Belly = rgb(220, 210, 150), Fin = rgb(110, 180, 100), Stripe = rgb(40, 100, 50) },
		Shape = { Length = 1.0, Height = 1.0 } },
	{ Id = "arraia", Name = "Arraia", Area = 1, Rarity = "Epico", Stamina = 380, Income = 40, Speed = 42, TameTime = 3.5,
		Colors = { Body = rgb(90, 80, 110), Belly = rgb(230, 230, 240), Fin = rgb(60, 50, 80), Stripe = rgb(240, 240, 255) },
		Shape = { Length = 1.1, Height = 0.6 } },
	{ Id = "voador", Name = "Peixe-Voador", Area = 1, Rarity = "Lendario", Stamina = 700, Income = 75, Speed = 46, TameTime = 4, Ability = "Salto",
		Colors = { Body = rgb(40, 200, 230), Belly = rgb(200, 250, 255), Fin = rgb(255, 255, 255), Stripe = rgb(20, 120, 200) },
		Shape = { Length = 1.2, Height = 0.9 } },

	-- Área 2: Floresta de Algas
	{ Id = "atum", Name = "Atum", Area = 2, Rarity = "Comum", Stamina = 1500, Income = 150, Speed = 44, TameTime = 2.5,
		Colors = { Body = rgb(40, 60, 110), Belly = rgb(200, 210, 220), Fin = rgb(255, 220, 40), Stripe = rgb(60, 90, 150) },
		Shape = { Length = 1.25, Height = 1.0 } },
	{ Id = "garoupa", Name = "Garoupa", Area = 2, Rarity = "Comum", Stamina = 2500, Income = 240, Speed = 40, TameTime = 2.7,
		Colors = { Body = rgb(150, 90, 60), Belly = rgb(220, 180, 140), Fin = rgb(110, 60, 40), Stripe = rgb(90, 50, 30) },
		Shape = { Length = 1.0, Height = 1.3 } },
	{ Id = "barracuda", Name = "Barracuda", Area = 2, Rarity = "Incomum", Stamina = 4500, Income = 400, Speed = 50, TameTime = 3,
		Colors = { Body = rgb(150, 170, 160), Belly = rgb(230, 240, 235), Fin = rgb(60, 80, 70), Stripe = rgb(40, 60, 50) },
		Shape = { Length = 1.45, Height = 0.75 } },
	{ Id = "peixelua", Name = "Peixe-Lua", Area = 2, Rarity = "Incomum", Stamina = 8000, Income = 650, Speed = 38, TameTime = 3.2,
		Colors = { Body = rgb(170, 180, 200), Belly = rgb(235, 235, 245), Fin = rgb(120, 130, 160), Stripe = rgb(140, 150, 180) },
		Shape = { Length = 0.8, Height = 1.6 } },
	{ Id = "espada", Name = "Peixe-Espada", Area = 2, Rarity = "Raro", Stamina = 14000, Income = 1100, Speed = 56, TameTime = 3.4,
		Colors = { Body = rgb(60, 80, 160), Belly = rgb(190, 200, 230), Fin = rgb(30, 40, 100), Stripe = rgb(110, 130, 200) },
		Shape = { Length = 1.5, Height = 0.9 } },
	{ Id = "martelo", Name = "Tubarão-Martelo", Area = 2, Rarity = "Raro", Stamina = 25000, Income = 1800, Speed = 50, TameTime = 3.6,
		Colors = { Body = rgb(120, 130, 140), Belly = rgb(230, 230, 230), Fin = rgb(90, 100, 110), Stripe = rgb(100, 110, 120) },
		Shape = { Length = 1.35, Height = 1.0 } },
	{ Id = "marlin", Name = "Marlin", Area = 2, Rarity = "Epico", Stamina = 45000, Income = 3000, Speed = 60, TameTime = 3.8,
		Colors = { Body = rgb(30, 40, 120), Belly = rgb(200, 220, 255), Fin = rgb(80, 200, 255), Stripe = rgb(90, 160, 255) },
		Shape = { Length = 1.5, Height = 1.1, Spikes = true } },
	{ Id = "branco", Name = "Tubarão-Branco", Area = 2, Rarity = "Lendario", Stamina = 80000, Income = 5000, Speed = 58, TameTime = 4.2, Ability = "Turbo",
		Colors = { Body = rgb(110, 120, 135), Belly = rgb(245, 245, 245), Fin = rgb(90, 100, 115), Stripe = rgb(200, 30, 30) },
		Shape = { Length = 1.5, Height = 1.2 } },

	-- Área 3: Abismo
	{ Id = "lanterna", Name = "Peixe-Lanterna", Area = 3, Rarity = "Comum", Stamina = 150000, Income = 9000, Speed = 52, TameTime = 2.8,
		Colors = { Body = rgb(40, 30, 70), Belly = rgb(90, 70, 140), Fin = rgb(255, 240, 120), Stripe = rgb(255, 230, 90) },
		Shape = { Length = 0.9, Height = 1.0 } },
	{ Id = "vibora", Name = "Peixe-Víbora", Area = 3, Rarity = "Comum", Stamina = 260000, Income = 15000, Speed = 56, TameTime = 3,
		Colors = { Body = rgb(30, 50, 60), Belly = rgb(70, 110, 120), Fin = rgb(120, 255, 220), Stripe = rgb(80, 220, 200) },
		Shape = { Length = 1.4, Height = 0.8, Spikes = true } },
	{ Id = "pescador", Name = "Peixe-Pescador", Area = 3, Rarity = "Incomum", Stamina = 450000, Income = 25000, Speed = 50, TameTime = 3.2,
		Colors = { Body = rgb(60, 40, 40), Belly = rgb(110, 80, 70), Fin = rgb(255, 255, 160), Stripe = rgb(140, 90, 60) },
		Shape = { Length = 0.9, Height = 1.4, Spikes = true } },
	{ Id = "enguia", Name = "Enguia-Elétrica", Area = 3, Rarity = "Incomum", Stamina = 800000, Income = 40000, Speed = 62, TameTime = 3.4,
		Colors = { Body = rgb(40, 60, 40), Belly = rgb(200, 220, 60), Fin = rgb(255, 255, 80), Stripe = rgb(255, 240, 0) },
		Shape = { Length = 1.6, Height = 0.7 } },
	{ Id = "lula", Name = "Lula-Gigante", Area = 3, Rarity = "Raro", Stamina = 1400000, Income = 65000, Speed = 60, TameTime = 3.6,
		Colors = { Body = rgb(190, 50, 60), Belly = rgb(240, 140, 140), Fin = rgb(140, 30, 40), Stripe = rgb(255, 200, 200) },
		Shape = { Length = 1.4, Height = 1.1 } },
	{ Id = "celacanto", Name = "Celacanto", Area = 3, Rarity = "Raro", Stamina = 2500000, Income = 110000, Speed = 54, TameTime = 3.8, Ability = "Casco",
		Colors = { Body = rgb(40, 70, 120), Belly = rgb(140, 170, 210), Fin = rgb(230, 230, 240), Stripe = rgb(220, 220, 230) },
		Shape = { Length = 1.2, Height = 1.2 } },
	{ Id = "duende", Name = "Tubarão-Duende", Area = 3, Rarity = "Epico", Stamina = 4500000, Income = 180000, Speed = 66, TameTime = 4,
		Colors = { Body = rgb(230, 150, 170), Belly = rgb(255, 210, 220), Fin = rgb(200, 110, 140), Stripe = rgb(180, 90, 120) },
		Shape = { Length = 1.45, Height = 1.0 } },
	{ Id = "leviata", Name = "Leviatã", Area = 3, Rarity = "Lendario", Stamina = 8000000, Income = 300000, Speed = 72, TameTime = 4.5, Ability = "Turbo",
		Colors = { Body = rgb(20, 20, 40), Belly = rgb(80, 40, 140), Fin = rgb(170, 60, 255), Stripe = rgb(0, 255, 200) },
		Shape = { Length = 1.6, Height = 1.3, Spikes = true } },
}

Fish.ById = {}
Fish.ByArea = {}
for order, species in ipairs(Fish.Species) do
	species.Order = order
	Fish.ById[species.Id] = species
	Fish.ByArea[species.Area] = Fish.ByArea[species.Area] or {}
	table.insert(Fish.ByArea[species.Area], species)
end

Fish.Abilities = {
	Salto = "Pula para fora da água de tempos em tempos",
	Turbo = "Fica mais rápido depois de alguns segundos",
	Casco = "Aguenta uma batida sem te derrubar",
}

function Fish.Get(id)
	return Fish.ById[id]
end

-- Stamina necessária para domar este peixe (o tamanho muda o valor).
function Fish.RequiredStamina(speciesId, size)
	local species = Fish.ById[speciesId]
	if not species then
		return math.huge
	end
	local sizeDef = Fish.Sizes[size] or Fish.Sizes.Normal
	return math.floor(species.Stamina * sizeDef.Stamina + 0.5)
end

-- Renda por segundo de um peixe guardado: { S = espécie, M = mutação, Z = tamanho }.
function Fish.Income(entry)
	local species = Fish.ById[entry.S]
	if not species then
		return 0
	end
	local mutation = Fish.Mutations[entry.M] or Fish.Mutations.Normal
	local size = Fish.Sizes[entry.Z] or Fish.Sizes.Normal
	return species.Income * mutation.Mult * size.Income
end

-- Quanto o vendedor paga.
function Fish.SellValue(entry, sellSeconds)
	return math.floor(Fish.Income(entry) * sellSeconds)
end

-- Velocidade montado.
function Fish.Speed(speciesId, size)
	local species = Fish.ById[speciesId]
	local sizeDef = Fish.Sizes[size] or Fish.Sizes.Normal
	return (species and species.Speed or 30) * sizeDef.Speed
end

-- Chave da variação (mutação + tamanho), usada no índex: "Dourado|Gigante".
function Fish.VariantKey(mutation, size)
	return mutation .. "|" .. size
end

Fish.VariantCount = #Fish.MutationOrder * #Fish.SizeOrder

-- É "raro de vender"? (pede confirmação extra na venda)
function Fish.IsPrecious(entry)
	local species = Fish.ById[entry.S]
	if not species then
		return false
	end
	return entry.M ~= "Normal" or entry.Z == "Enorme" or entry.Z == "Gigante" or Fish.Rarities[species.Rarity].Order >= 4
end

-- Texto curto das etiquetas: "Dourado Gigante" (não mostra o que é Normal).
function Fish.Tags(entry)
	local parts = {}
	if entry.M and entry.M ~= "Normal" then
		table.insert(parts, Fish.Mutations[entry.M].Name)
	end
	if entry.Z and entry.Z ~= "Normal" then
		table.insert(parts, Fish.Sizes[entry.Z].Name)
	end
	return table.concat(parts, " ")
end

-- Sorteios (rng = Random): usados na geração da corrida, igual no servidor e no cliente --------
local function pickWeighted(rng, list, weightOf)
	local total = 0
	for _, item in ipairs(list) do
		total += weightOf(item)
	end
	local roll = rng:NextNumber() * total
	for _, item in ipairs(list) do
		roll -= weightOf(item)
		if roll <= 0 then
			return item
		end
	end
	return list[#list]
end

function Fish.RollSpecies(rng, area)
	local list = Fish.ByArea[area] or Fish.ByArea[1]
	return pickWeighted(rng, list, function(species)
		return Fish.Rarities[species.Rarity].Weight
	end)
end

function Fish.RollMutation(rng)
	return pickWeighted(rng, Fish.MutationOrder, function(key)
		return Fish.Mutations[key].Chance
	end)
end

function Fish.RollSize(rng)
	return pickWeighted(rng, Fish.SizeOrder, function(key)
		return Fish.Sizes[key].Chance
	end)
end

return Fish
