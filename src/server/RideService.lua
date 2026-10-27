-- RideService (ModuleScript)
-- Fica em: ServerScriptService > Server > RideService
--
-- A corrida, do lado do servidor. O cliente faz o movimento (é ele quem desenha os peixes
-- nadando e o jogador pulando), mas o servidor decide o que vale:
--   1. StartRun: o jogador está na zona de mergulho? Então o servidor sorteia um seed.
--      Servidor e cliente geram a mesma lista de peixes com esse seed (Track.GenerateRun).
--   2. Mount: o cliente avisa em qual peixe montou (o relógio da doma começa aqui).
--   3. Tame: o cliente diz que terminou de domar. O servidor confere se o peixe existe,
--      se ninguém já o domou nesta corrida, se passou o tempo de doma e se a stamina do
--      jogador é suficiente. Só então o peixe entra na coleção e no índex.
--   4. EndRun: caiu ou apertou Voltar. O jogador volta para o lote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Fish = require(Shared:WaitForChild("Fish"))
local Track = require(Shared:WaitForChild("Track"))
local Layout = require(Shared:WaitForChild("Layout"))

local Net = require(script.Parent:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local RideService = {}

local runs = {} -- [player] = { Seed, Started, Fish, Tamed, Mount, MountAt, ReviveReady }
local rng = Random.new()

function RideService.IsRunning(player)
	return runs[player] ~= nil
end

local function endRun(player, reason)
	if not runs[player] then
		return
	end
	runs[player] = nil
	player:SetAttribute("Running", false)
	if reason ~= "saiu" then
		PlotService.SendHome(player)
	end
end

local function startRun(player)
	if runs[player] then
		return { ok = false, msg = "Você já está correndo" }
	end
	local data = DataService.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root then
		return { ok = false }
	end
	local offset = root.Position - Layout.StartZone
	local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if flat > Track.START_RADIUS + 8 or root.Position.Y > Track.WATER_Y + 2 then
		return { ok = false, msg = "Entre na zona de mergulho" }
	end
	local seed = rng:NextInteger(1, 2 ^ 30)
	runs[player] = {
		Seed = seed,
		Started = os.clock(),
		Fish = Track.GenerateRun(seed),
		Tamed = {},
		Mount = nil,
		MountAt = 0,
	}
	player:SetAttribute("Running", true)
	return { ok = true, Seed = seed }
end

local function mount(player, index)
	local run = runs[player]
	if not run or type(index) ~= "number" then
		return { ok = false }
	end
	local fish = run.Fish[index]
	if not fish then
		return { ok = false }
	end
	run.Mount = index
	run.MountAt = os.clock()
	return { ok = true }
end

local function tame(player, index)
	local run = runs[player]
	local data = DataService.Get(player)
	if not run or not data or type(index) ~= "number" then
		return { ok = false }
	end
	local fish = run.Fish[index]
	if not fish or run.Tamed[index] then
		return { ok = false }
	end
	local species = Fish.Get(fish.S)
	if not species then
		return { ok = false }
	end

	-- montou mesmo neste peixe e ficou o tempo da doma?
	local now = os.clock()
	if run.Mount ~= index or now - run.MountAt < species.TameTime * Config.RIDE.TAME_TOLERANCE then
		return { ok = false, msg = "Doma inválida" }
	end
	-- deu tempo de chegar até ele?
	local minTime = math.max(0, (fish.Dist - Track.START_DIST - 40)) / Track.MAX_SPEED
	if now - run.Started < minTime then
		return { ok = false, msg = "Doma inválida" }
	end
	-- stamina suficiente?
	local required = Fish.RequiredStamina(fish.S, fish.Z)
	if data.Stamina < required then
		return { ok = false, msg = "Stamina insuficiente" }
	end

	run.Tamed[index] = true
	data.Tamed += 1
	local isNew = DataService.RegisterIndex(data, fish.S, fish.M, fish.Z)

	local stored = DataService.StoredCount(data) < Config.MAX_STORED_FISH
	local entry = nil
	if stored then
		entry = { Uid = data.NextUid, S = fish.S, M = fish.M, Z = fish.Z }
		data.NextUid += 1
		table.insert(data.Fish, entry)
	else
		Net.Notify(player, "Coleção cheia! Venda peixes na barraca para guardar mais.", "erro")
	end
	if isNew then
		Net.Notify(player, "Novo no índex: " .. species.Name .. "! Pegue o prêmio no Índex.", "raro")
	end
	Net.Sync(player)
	return { ok = true, New = isNew, Stored = stored, Entry = entry }
end

-- Chamado quando a compra do "Reviver" é confirmada.
function RideService.Revive(player)
	if not runs[player] then
		return false
	end
	Net.RideEvent:FireClient(player, "Revived")
	return true
end

function RideService.Start()
	Net.On("StartRun", startRun)
	Net.On("Mount", mount)
	Net.On("Tame", tame)
	Net.On("EndRun", function(player, reason)
		endRun(player, type(reason) == "string" and reason or "voltou")
		return { ok = true }
	end)

	Players.PlayerRemoving:Connect(function(player)
		endRun(player, "saiu")
	end)
end

-- O personagem morreu ou nasceu de novo: a corrida acaba.
function RideService.CharacterAdded(player)
	if runs[player] then
		runs[player] = nil
		player:SetAttribute("Running", false)
	end
end

return RideService
