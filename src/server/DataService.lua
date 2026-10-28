-- DataService (ModuleScript)
-- Fica em: ServerScriptService > Server > DataService
--
-- Dados de cada jogador. Só o servidor mexe aqui: o cliente nunca muda dinheiro,
-- stamina ou peixes diretamente.
--
-- Salvamento (mesmo esquema do Exploradores de Animais): lê do DataStore ao entrar,
-- grava a cada Config.AUTOSAVE_INTERVAL segundos, ao sair e ao desligar o servidor,
-- com trava de sessão (o mesmo jogador em dois servidores não estraga os dados).
-- No Studio sem acesso ao DataStore, o jogo funciona com dados novos e NÃO salva.
--
-- Formato dos dados:
-- {
--     Version = 1,
--     Money = 0, Stamina = 12, TotalEarned = 0,
--     TreadmillLevel = 1, AquariumLevel = 1,
--     Fish = { { Uid = 1, S = "palhaco", M = "Normal", Z = "Normal" } }, -- todos os peixes
--     NextUid = 2,
--     Aquarium = { 1 }, -- Uids dos peixes que estão no aquário (rendem dinheiro)
--     Index = { palhaco = { F = true, C = false, V = { ["Normal|Normal"] = true } } },
--         -- F = já domou a versão normal (libera o prêmio), C = prêmio já pego,
--         -- V = variações (mutação|tamanho) já domadas
--     Areas = { ["1"] = true }, -- prêmios de área completa já pegos
--     BestAura = 0, Aura = 0, -- melhor aura comprada e aura equipada (0 = nenhuma)
--     Tamed = 0, -- total de peixes domados
--     Purchases = { "id-do-recibo" }, -- últimas compras com Robux (evita dar duas vezes)
--     LastSave = 1760000000,
-- }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Fish = require(Shared:WaitForChild("Fish"))
local Progression = require(Shared:WaitForChild("Progression"))

local DataService = {}

local DATA_VERSION = 1
local MAX_FISH_TOTAL = Config.MAX_STORED_FISH + Config.AQUARIUM.MAX_SLOTS

local profiles = {}
local unsaved = {}
local saving = {}
local store = nil

local function newData()
	return {
		Version = DATA_VERSION,
		Money = Config.STARTING_MONEY,
		Stamina = Config.STARTING_STAMINA,
		TotalEarned = 0,
		TreadmillLevel = 1,
		AquariumLevel = 1,
		Fish = {},
		NextUid = 1,
		Aquarium = {},
		Index = {},
		Areas = {},
		BestAura = 0,
		Aura = 0,
		Tamed = 0,
		Purchases = {},
	}
end

local function keyFor(player)
	return "Jogador_" .. tostring(player.UserId)
end

local function getStore()
	if not store then
		store = DataStoreService:GetDataStore(Config.DATA_STORE_NAME)
	end
	return store
end

local serverId = (game.JobId ~= nil and game.JobId ~= "") and game.JobId or "studio"

local function lockedByOther(lock)
	return type(lock) == "table" and lock.Id ~= serverId and type(lock.At) == "number" and os.time() - lock.At < Config.SESSION_LOCK_TIMEOUT
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function withRetries(action)
	local ok, result
	for attempt = 1, Config.DATA_RETRIES do
		ok, result = pcall(action)
		if ok then
			return true, result
		end
		warn(("[DataService] tentativa %d/%d falhou: %s"):format(attempt, Config.DATA_RETRIES, tostring(result)))
		if attempt < Config.DATA_RETRIES then
			task.wait(Config.DATA_RETRY_DELAY)
		end
	end
	return false, result
end

local function isNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isWhole(value)
	return isNumber(value) and value == math.floor(value)
end

-- Confere e conserta os dados salvos antes de usar.
local function sanitize(raw)
	if type(raw) ~= "table" then
		return nil, "dados_invalidos"
	end
	if isNumber(raw.Version) and raw.Version > DATA_VERSION then
		return nil, "versao_nova"
	end

	local data = newData()
	data.Money = isNumber(raw.Money) and math.clamp(raw.Money, 0, 1e30) or data.Money
	data.Stamina = isNumber(raw.Stamina) and math.clamp(raw.Stamina, 0, 1e30) or data.Stamina
	data.TotalEarned = isNumber(raw.TotalEarned) and math.clamp(raw.TotalEarned, 0, 1e30) or 0
	data.TreadmillLevel = isWhole(raw.TreadmillLevel) and math.clamp(raw.TreadmillLevel, 1, Config.TREADMILL.MAX_LEVEL) or 1
	data.AquariumLevel = isWhole(raw.AquariumLevel) and math.clamp(raw.AquariumLevel, 1, Progression.AquariumMaxLevel()) or 1
	data.BestAura = isWhole(raw.BestAura) and math.clamp(raw.BestAura, 0, #Progression.Auras) or 0
	data.Aura = isWhole(raw.Aura) and math.clamp(raw.Aura, 0, data.BestAura) or data.BestAura
	data.Tamed = isWhole(raw.Tamed) and math.max(0, raw.Tamed) or 0

	-- peixes
	local used = {}
	local nextUid = isWhole(raw.NextUid) and raw.NextUid or 1
	if type(raw.Fish) == "table" then
		for _, entry in ipairs(raw.Fish) do
			if #data.Fish >= MAX_FISH_TOTAL then
				break
			end
			if
				type(entry) == "table"
				and isWhole(entry.Uid)
				and entry.Uid >= 1
				and not used[entry.Uid]
				and Fish.Get(entry.S)
			then
				used[entry.Uid] = true
				table.insert(data.Fish, {
					Uid = entry.Uid,
					S = entry.S,
					M = Fish.Mutations[entry.M] and entry.M or "Normal",
					Z = Fish.Sizes[entry.Z] and entry.Z or "Normal",
				})
				nextUid = math.max(nextUid, entry.Uid + 1)
			end
		end
	end
	data.NextUid = nextUid

	-- aquário: só Uids que existem, sem repetir, até o número de vagas
	local slots = Progression.AquariumSlots(data.AquariumLevel)
	if type(raw.Aquarium) == "table" then
		local seen = {}
		for _, uid in ipairs(raw.Aquarium) do
			if #data.Aquarium >= slots then
				break
			end
			if isWhole(uid) and used[uid] and not seen[uid] then
				seen[uid] = true
				table.insert(data.Aquarium, uid)
			end
		end
	end

	-- índex
	if type(raw.Index) == "table" then
		for speciesId, rec in pairs(raw.Index) do
			if Fish.Get(speciesId) and type(rec) == "table" then
				local clean = { F = rec.F == true, C = rec.C == true, V = {} }
				if type(rec.V) == "table" then
					for key, value in pairs(rec.V) do
						if value == true and type(key) == "string" then
							local mutation, size = string.match(key, "^(%w+)|(%w+)$")
							if mutation and Fish.Mutations[mutation] and Fish.Sizes[size] then
								clean.V[key] = true
							end
						end
					end
				end
				clean.C = clean.C and clean.F
				data.Index[speciesId] = clean
			end
		end
	end

	if type(raw.Areas) == "table" then
		for key, value in pairs(raw.Areas) do
			if value == true and tonumber(key) and Fish.ByArea[tonumber(key)] then
				data.Areas[tostring(tonumber(key))] = true
			end
		end
	end

	if type(raw.Purchases) == "table" then
		for _, id in ipairs(raw.Purchases) do
			if type(id) == "string" and #data.Purchases < 50 then
				table.insert(data.Purchases, id)
			end
		end
	end

	if isNumber(raw.LastSave) then
		data.LastSave = raw.LastSave
	end
	return data
end

DataService.SanitizeForTest = sanitize

function DataService.Load(player)
	local key = keyFor(player)
	while saving[key] do
		task.wait(0.1)
	end

	local ok, raw
	local waited = 0
	while true do
		local blocked, record = false, nil
		ok, raw = withRetries(function()
			blocked, record = false, nil
			getStore():UpdateAsync(key, function(old)
				if old ~= nil and type(old) ~= "table" then
					return nil
				end
				if old ~= nil and lockedByOther(old.Lock) then
					blocked = true
					return nil
				end
				record = deepCopy(old)
				old = old or {}
				old.Lock = { Id = serverId, At = os.time() }
				return old
			end)
		end)
		if ok then
			raw = record
		end
		if not ok or not blocked then
			break
		end
		if waited >= Config.SESSION_LOCK_WAIT then
			return nil, "sessao_em_uso"
		end
		task.wait(Config.SESSION_LOCK_POLL)
		waited += Config.SESSION_LOCK_POLL
		if player.Parent ~= Players then
			return nil, "saiu"
		end
	end

	if player.Parent ~= Players then
		return nil, "saiu"
	end

	local data
	if ok then
		if raw == nil or raw.Version == nil then
			data = newData()
		else
			local reason
			data, reason = sanitize(raw)
			if not data then
				warn(("[DataService] dados de %s recusados: %s"):format(player.Name, tostring(reason)))
				return nil, reason
			end
		end
	elseif RunService:IsStudio() then
		warn(
			"[DataService] DataStore indisponível ("
				.. tostring(raw)
				.. "). Jogando com dados NOVOS e SEM salvar. Para testar o salvamento: publique o jogo e ligue "
				.. "'Enable Studio Access to API Services' em Game Settings > Security."
		)
		data = newData()
		unsaved[player] = true
	else
		return nil, "falha_dataStore"
	end

	profiles[player] = data
	return data
end

function DataService.Get(player)
	return profiles[player]
end

local function saveData(player, data, release)
	if unsaved[player] then
		return false
	end
	local key = keyFor(player)
	while saving[key] do
		task.wait(0.1)
	end
	saving[key] = true

	data.LastSave = os.time()
	local snapshot = deepCopy(data)

	local lost = false
	local ok, err = withRetries(function()
		lost = false
		getStore():UpdateAsync(key, function(old)
			if type(old) == "table" and lockedByOther(old.Lock) then
				lost = true
				return nil
			end
			snapshot.Lock = (not release) and { Id = serverId, At = os.time() } or nil
			return snapshot
		end)
	end)
	saving[key] = nil

	if ok and lost then
		warn(("[DataService] %s: os dados passaram para outro servidor; gravação cancelada"):format(player.Name))
		unsaved[player] = true
		if player.Parent == Players then
			player:Kick("Your account was opened on another server. Please rejoin.")
		end
		return false
	end
	if not ok then
		warn(("[DataService] NÃO consegui salvar %s: %s"):format(player.Name, tostring(err)))
	end
	return ok
end

function DataService.Save(player)
	local data = profiles[player]
	if not data then
		return false
	end
	return saveData(player, data)
end

function DataService.Release(player)
	local data = profiles[player]
	profiles[player] = nil
	if data then
		saveData(player, data, true)
	end
	unsaved[player] = nil
end

function DataService.Discard(player)
	profiles[player] = nil
	unsaved[player] = nil
end

function DataService.Start()
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player, data in pairs(profiles) do
				task.spawn(saveData, player, data)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, data in pairs(profiles) do
			pending += 1
			task.spawn(function()
				saveData(player, data, true)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait(0.1)
		end
	end)
end

-- Utilidades dos dados --------------------------------------------------------------------

function DataService.FindFish(data, uid)
	for index, entry in ipairs(data.Fish) do
		if entry.Uid == uid then
			return entry, index
		end
	end
	return nil, nil
end

function DataService.InAquarium(data, uid)
	return table.find(data.Aquarium, uid) ~= nil
end

-- Peixes guardados (fora do aquário)
function DataService.StoredCount(data)
	return #data.Fish - #data.Aquarium
end

function DataService.AquariumSlots(data)
	return Progression.AquariumSlots(data.AquariumLevel)
end

-- Registra uma doma no índex. Devolve true se a espécie acabou de ser descoberta (versão normal).
function DataService.RegisterIndex(data, speciesId, mutation, size)
	local rec = data.Index[speciesId]
	if not rec then
		rec = { F = false, C = false, V = {} }
		data.Index[speciesId] = rec
	end
	rec.V[Fish.VariantKey(mutation, size)] = true
	if mutation == "Normal" and not rec.F then
		rec.F = true
		return true
	end
	return false
end

return DataService
