-- Main (Script)
-- Fica em: ServerScriptService > Server > Main
--
-- O "maestro" do servidor: constrói o mapa, liga os serviços e cuida de quem entra e sai.
-- A lógica de verdade fica nos módulos ao lado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Net = require(script.Parent:WaitForChild("Net"))
local MapService = require(script.Parent:WaitForChild("MapService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local MonetizationService = require(script.Parent:WaitForChild("MonetizationService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local RideService = require(script.Parent:WaitForChild("RideService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local BackpackService = require(script.Parent:WaitForChild("BackpackService"))

Net.Start()
MapService.Build()
DataService.Start()
MonetizationService.Start()
PlotService.Start()
EconomyService.Start()
RideService.Start()
ShopService.Start()
LeaderboardService.Start()

-- A "foto" dos dados que o cliente recebe (o cliente só lê; quem decide é o servidor).
Net.SetSnapshotBuilder(function(player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	BackpackService.Refresh(player) -- os peixes guardados ficam na mochila do Roblox
	return {
		Fish = data.Fish,
		Aquarium = data.Aquarium,
		Index = data.Index,
		Areas = data.Areas,
		BestAura = data.BestAura,
		Aura = data.Aura,
		TreadmillLevel = data.TreadmillLevel,
		AquariumLevel = data.AquariumLevel,
		Slots = DataService.AquariumSlots(data),
		Passes = MonetizationService.GetPasses(player),
		MaxStored = Config.MAX_STORED_FISH,
		Tamed = data.Tamed,
		BestDist = data.BestDist,
		Tut = data.Tut,
		Set = data.Set,
		Plot = PlotService.GetIndex(player),
	}
end)

local function onChanged(player)
	EconomyService.Publish(player)
	PlotService.RefreshSigns(player)
	Net.Sync(player)
end

MonetizationService.SetHooks({ Revive = RideService.Revive, Changed = onChanged })
ShopService.OnChanged = EconomyService.Publish
BackpackService.PlaceInAquarium = ShopService.Equip
PlotService.OnChanged = EconomyService.Publish

-- Tutorial: o cliente avisa que o jogador terminou um passo (só aumenta).
-- Configurações (volume e modo performance): o cliente já aplicou; aqui só guarda.
Net.On("Settings", function(player, settings)
	local data = DataService.Get(player)
	if data then
		data.Set = DataService.CleanSettings(settings)
	end
	return { ok = true }
end)

Net.On("Tutorial", function(player, step)
	local data = DataService.Get(player)
	if data and type(step) == "number" and step == math.floor(step) then
		data.Tut = math.max(data.Tut, math.clamp(step, 0, 99))
	end
	return { ok = true }
end)

-- Rever o tutorial (para testar): digite /tutorial no chat. Só funciona no Studio ou
-- para o dono do jogo, para jogador comum não ficar reiniciando sem querer.
local RunServiceMain = game:GetService("RunService")
local function canReplayTutorial(player)
	return RunServiceMain:IsStudio() or player.UserId == game.CreatorId
end
local function replayTutorial(player)
	if not player or not canReplayTutorial(player) then
		return
	end
	local data = DataService.Get(player)
	if data then
		data.Tut = 0
		Net.Sync(player)
		Net.Notify(player, "Tutorial restarted!", "ok")
	end
end
-- chat novo (TextChatService): comando de verdade, não aparece como mensagem
pcall(function()
	local TextChatService = game:GetService("TextChatService")
	local command = Instance.new("TextChatCommand")
	command.Name = "TutorialCommand"
	command.PrimaryAlias = "/tutorial"
	command.Parent = TextChatService
	command.Triggered:Connect(function(source)
		replayTutorial(Players:GetPlayerByUserId(source.UserId))
	end)
end)
-- chat antigo
local function hookTutorialCommand(player)
	pcall(function()
		player.Chatted:Connect(function(message)
			if string.lower(message) == "/tutorial" then
				replayTutorial(player)
			end
		end)
	end)
end
Players.PlayerAdded:Connect(hookTutorialCommand)
for _, existing in ipairs(Players:GetPlayers()) do
	hookTutorialCommand(existing)
end

Net.On("GetData", function(player)
	Net.Sync(player)
	return { ok = true }
end)

local function onPlayerAdded(player)
	task.spawn(MonetizationService.PlayerAdded, player)

	local data, reason = DataService.Load(player)
	if not data then
		if reason == "sessao_em_uso" then
			player:Kick("Your account is still open on another server. Wait a few seconds and rejoin.")
		elseif reason ~= "saiu" then
			player:Kick("Could not load your data. Please try rejoining.")
		end
		return
	end

	local plot = PlotService.Assign(player)
	if not plot then
		DataService.Discard(player)
		player:Kick("Server is full. Try another server.")
		return
	end

	EconomyService.PlayerAdded(player)
	Net.Sync(player)

	local function onCharacter(character)
		RideService.CharacterAdded(player)
		task.spawn(function()
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if not root then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = Config.WALK_SPEED
			end
			task.wait(0.1)
			PlotService.SendHome(player)
			ShopService.ApplyAura(player)
			BackpackService.Refresh(player) -- a mochila é nova a cada vez que o personagem nasce
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	PlotService.Release(player)
	MonetizationService.PlayerRemoving(player)
	DataService.Release(player)
end)
