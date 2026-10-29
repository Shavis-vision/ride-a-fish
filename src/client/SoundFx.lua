-- SoundFx (ModuleScript)
-- Fica em: StarterPlayerScripts > Client > SoundFx
--
-- Sons do jogo (só no seu computador). Os IDs ficam em Config.SOUNDS — são áudios prontos
-- do Creator Store (efeitos da Pro Sound Effects e músicas licenciadas da DistroKid, que o
-- Roblox libera para qualquer jogo). Para trocar um som, troque o número lá.
--
--   SoundFx.Play("Splash")          -- efeito curto
--   SoundFx.SetUnderwater(true)     -- a música fica abafada, como ouvida debaixo d'água
--   SoundFx.SetVolumes(music, fx)   -- 0 a 1 (configurações do jogador)

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SoundFx = {}

local SOUNDS = Config.SOUNDS or {}

local effectsGroup = Instance.new("SoundGroup")
effectsGroup.Name = "Efeitos"
effectsGroup.Volume = SOUNDS.EffectsVolume or 0.6
effectsGroup.Parent = SoundService

local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Musica"
musicGroup.Volume = SOUNDS.MusicVolume or 0.35
musicGroup.Parent = SoundService

-- "abafado" debaixo d'água: corta os agudos e dá um eco
local muffle = Instance.new("EqualizerSoundEffect")
muffle.HighGain = -40
muffle.MidGain = -12
muffle.LowGain = 4
muffle.Enabled = false
muffle.Parent = musicGroup
local echo = Instance.new("ReverbSoundEffect")
echo.DecayTime = 2.2
echo.WetLevel = -6
echo.Enabled = false
echo.Parent = musicGroup

local cache = {}
local function soundFor(key)
	if cache[key] then
		return cache[key]
	end
	local entry = SOUNDS.Effects and SOUNDS.Effects[key]
	if not entry or entry.Id == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = "rbxassetid://" .. entry.Id
	sound.Volume = entry.Volume or 0.6
	sound.PlaybackSpeed = entry.Speed or 1
	sound.SoundGroup = effectsGroup
	sound.Parent = SoundService
	cache[key] = sound
	return sound
end

local lastPlayed = {}
function SoundFx.Play(key)
	local sound = soundFor(key)
	if not sound then
		return
	end
	local now = os.clock()
	if lastPlayed[key] and now - lastPlayed[key] < 0.06 then
		return -- evita o mesmo som várias vezes no mesmo instante
	end
	lastPlayed[key] = now
	-- cópia para poder tocar o mesmo som por cima de outro
	local copy = sound:Clone()
	copy.PlaybackSpeed = sound.PlaybackSpeed * (0.95 + math.random() * 0.1)
	copy.Parent = SoundService
	if not pcall(function()
		copy:Play()
	end) then
		copy:Destroy()
		return
	end
	task.delay(math.max(2, sound.TimeLength / copy.PlaybackSpeed + 0.5), function()
		if copy.Parent then
			copy:Destroy()
		end
	end)
end

-- volume escolhido pelo jogador (0 a 1), multiplicado pelo volume base do Config
function SoundFx.SetVolumes(music, effects)
	musicGroup.Volume = (SOUNDS.MusicVolume or 0.35) * math.clamp(music or 1, 0, 1)
	effectsGroup.Volume = (SOUNDS.EffectsVolume or 0.6) * math.clamp(effects or 1, 0, 1)
end

function SoundFx.SetUnderwater(value)
	muffle.Enabled = value
	echo.Enabled = value
end

-- Música: toca a lista em sequência, sem parar
task.spawn(function()
	local list = SOUNDS.Music or {}
	if #list == 0 then
		return
	end
	local index = math.random(1, #list)
	while true do
		local id = list[index]
		if id and id ~= 0 then
			local track = Instance.new("Sound")
			track.Name = "Musica"
			track.SoundId = "rbxassetid://" .. id
			track.Volume = 1
			track.SoundGroup = musicGroup
			track.Parent = SoundService
			if not pcall(function()
				track:Play()
			end) then
				track:Destroy()
				return
			end
			local started = os.clock()
			track.Ended:Wait()
			track:Destroy()
			if os.clock() - started < 2 then
				task.wait(5) -- áudio que não carregou: não fica tentando sem parar
			end
		end
		index = index % #list + 1
	end
end)

return SoundFx
