-- WorldFx (LocalScript)
-- Fica em: StarterPlayerScripts > Client > WorldFx
--
-- Efeitos que só rodam no seu computador:
--   * debaixo d'água: tela azulada, neblina da área (Recife, Algas, Abismo) e bolhas subindo;
--   * anéis das barracas: pisou, a loja abre; saiu, fecha;
--   * esteira: animação de correr e a esteira andando enquanto você treina;
--   * aquários: os peixes balançam a cauda e boiam;
--   * placas de melhoria dos lotes dos outros ficam sem o botão "E".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Track = require(Shared:WaitForChild("Track"))
local Layout = require(Shared:WaitForChild("Layout"))
local FishModel = require(Shared:WaitForChild("FishModel"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundFx = require(script.Parent:WaitForChild("SoundFx"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local map = Workspace:WaitForChild("Map")
local plots = map:WaitForChild("Lotes")

-- Debaixo d'água -----------------------------------------------------------------------------
local surface = {
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
	FogColor = Lighting.FogColor,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
}
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "Submarino"
tint.Enabled = false
tint.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Name = "SubmarinoBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting

local bubblesGui = UIKit.Gui("Bolhas", 0)
bubblesGui.Enabled = false

local underwater = false
local fogColor = Track.Areas[1].FogColor
local fogEnd = Track.Areas[1].FogEnd

-- Raios de luz (só no seu computador e só com a câmera debaixo d'água): feixes suaves que
-- brilham em cima e somem perto do fundo, no Recife Raso.
local raysFolder = Instance.new("Folder")
raysFolder.Name = "RaiosDeLuz"
do
	local rng = Random.new(9)
	for _ = 1, 26 do
		local dist = rng:NextNumber(70, Track.Areas[1].Finish - 30)
		local x = rng:NextNumber(-45, 45)
		local seabed = Track.SeabedY(dist)
		local anchor = Instance.new("Part")
		anchor.Name = "Raio"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = CFrame.new(x, Track.WATER_Y - 2, Track.ZOf(dist))
		local top = Instance.new("Attachment")
		top.Parent = anchor
		local bottom = Instance.new("Attachment")
		-- inclinado, como a luz entrando de lado
		-- posição relativa ao topo (a peça âncora não é girada)
		bottom.Position = Vector3.new(rng:NextNumber(4, 10), seabed + 2 - (Track.WATER_Y - 2), -rng:NextNumber(2, 8))
		bottom.Parent = anchor
		local beam = Instance.new("Beam")
		beam.Attachment0 = top
		beam.Attachment1 = bottom
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(Color3.fromRGB(230, 250, 255))
		-- forte em cima e some embaixo
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(0.5, 0.9),
			NumberSequenceKeypoint.new(1, 1),
		})
		local width = rng:NextNumber(4, 9)
		beam.Width0 = width
		beam.Width1 = width * 1.6
		beam.Segments = 1
		beam.Parent = anchor
		anchor.Parent = raysFolder
	end
end
local function showRays(visible)
	raysFolder.Parent = visible and Workspace or nil
end

-- "Caixa de neblina": a neblina do Roblox não cobre o céu, então debaixo d'água dava para ver
-- as nuvens e o fim do bloco de água. Seis paredes da cor da neblina seguem a câmera, um
-- pouco antes do fim da neblina: elas somem na neblina e escondem tudo o que está além.
local fogBox = Instance.new("Folder")
fogBox.Name = "NeblinaSubmarina"
local fogWalls = {}
do
	local faces = {
		Vector3.new(1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, -1, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, 0, -1),
	}
	for _, normal in ipairs(faces) do
		local wall = Instance.new("Part")
		wall.Name = "Parede"
		wall.Anchored = true
		wall.CanCollide = false
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
		wall.Material = Enum.Material.SmoothPlastic
		wall.Parent = fogBox
		table.insert(fogWalls, { Part = wall, Normal = normal })
	end
end
local function updateFogBox(position, color, distance)
	local side = math.min(2048, distance * 2 + 20)
	for _, w in ipairs(fogWalls) do
		local n = w.Normal
		w.Part.Size = Vector3.new(n.X ~= 0 and 2 or side, n.Y ~= 0 and 2 or side, n.Z ~= 0 and 2 or side)
		w.Part.Position = position + n * distance
		w.Part.Color = color
	end
end

-- Mar além da pista: o bloco de água acaba em x = ±360 e no fim da pista; daqui de fora
-- dava para ver a borda dele no horizonte. Placas de mar (opacas) continuam a água até longe.
do
	local folder = Instance.new("Folder")
	folder.Name = "MarAoLonge"
	local function sea(x0, x1, z0, z1)
		local tile = 2000
		local x = x0
		while x < x1 do
			local w = math.min(tile, x1 - x)
			local z = z0
			while z < z1 do
				local d = math.min(tile, z1 - z)
				local part = Instance.new("Part")
				part.Name = "Mar"
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.fromRGB(30, 140, 225)
				part.Size = Vector3.new(w, 1, d)
				part.Position = Vector3.new(x + w / 2, Track.WATER_Y - 0.6, z + d / 2)
				part.Parent = folder
				z += d
			end
			x += w
		end
	end
	-- retângulo coberto pela água de verdade (Map > Oceano > Agua). Fica escrito aqui porque,
	-- com o StreamingEnabled, as peças de água longe do jogador nem chegam no seu computador.
	local minX, maxX, minZ, maxZ = -360, 360, -2820, 4
	local far = 4000
	sea(minX - far, minX, minZ - far, maxZ) -- lado esquerdo
	sea(maxX, maxX + far, minZ - far, maxZ) -- lado direito
	sea(minX, maxX, minZ - far, minZ) -- depois do fim da pista
	folder.Parent = Workspace
end

-- modo performance (Configurações): sem raios de luz, sem desfoque e sem bolhas na tela
local function perfMode()
	return player:GetAttribute("PerfMode") == true
end
player:GetAttributeChangedSignal("PerfMode"):Connect(function()
	showRays(underwater and not perfMode())
	blur.Enabled = underwater and not perfMode()
end)

local function setUnderwater(value)
	if value == underwater then
		return
	end
	underwater = value
	SoundFx.SetUnderwater(value)
	showRays(value and not perfMode())
	tint.Enabled = value
	blur.Enabled = value and not perfMode()
	fogBox.Parent = value and Workspace or nil
	bubblesGui.Enabled = value
	if value then
		if atmosphere then
			atmosphere.Parent = nil
		end
		Lighting.FogStart = 6
	else
		if atmosphere then
			atmosphere.Parent = Lighting
		end
		for key, v in pairs(surface) do
			Lighting[key] = v
		end
	end
end


-- Sons de passos: o Roblox toca "Running" pelo HumanoidRootPart. Debaixo d'água (e durante a
-- corrida, quando o personagem é movido pelo jogo) eles ficam mudos.
local stepVolumes = {}
local STEP_SOUNDS = { Running = true, Climbing = true, Landing = true, Jumping = true, FreeFalling = true, GettingUp = true }
local function muteSteps(muted)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, sound in ipairs(root:GetChildren()) do
		if sound:IsA("Sound") and STEP_SOUNDS[sound.Name] then
			if muted then
				if stepVolumes[sound] == nil then
					stepVolumes[sound] = sound.Volume
				end
				sound.Volume = 0
			elseif stepVolumes[sound] ~= nil then
				sound.Volume = stepVolumes[sound]
				stepVolumes[sound] = nil
			end
		end
	end
end
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local muted = player:GetAttribute("Running") == true or root.Position.Y < Track.WATER_Y + 0.5
	muteSteps(muted)
end)

local bubbleClock = 0
local function spawnBubble()
	local size = math.random(8, 22)
	local bubble = UIKit.Frame(bubblesGui, {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.new(math.random(), 0, 1, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Color3.fromRGB(220, 245, 255),
		Transparency = 0.55,
		Corner = 999,
		Stroke = 1.5,
		StrokeColor = Color3.fromRGB(255, 255, 255),
	})
	local duration = math.random(25, 45) / 10
	UIKit.Tween(bubble, duration, {
		Position = UDim2.new(bubble.Position.X.Scale + (math.random() - 0.5) * 0.08, 0, -0.05, 0),
		BackgroundTransparency = 0.9,
	}, Enum.EasingStyle.Sine)
	task.delay(duration, function()
		bubble:Destroy()
	end)
end

RunService.RenderStepped:Connect(function(dt)
	local position = camera.CFrame.Position
	setUnderwater(position.Y < Track.WATER_Y - 0.3)
	if not underwater then
		return
	end
	local dist = Track.DistOf(position.Z)
	local area = Track.AreaAt(math.max(0, dist))
	local k = math.min(1, dt * 1.5)
	fogColor = fogColor:Lerp(area.FogColor, k)
	fogEnd += (area.FogEnd - fogEnd) * k
	Lighting.FogColor = fogColor
	Lighting.FogEnd = fogEnd
	updateFogBox(position, fogColor, fogEnd * 0.94)
	local depth = math.clamp((Track.WATER_Y - position.Y) / 140, 0, 1)
	Lighting.Ambient = fogColor:Lerp(Color3.fromRGB(190, 200, 210), 0.6 - depth * 0.2)
	Lighting.OutdoorAmbient = fogColor:Lerp(Color3.fromRGB(210, 225, 235), 0.6 - depth * 0.2)
	Lighting.Brightness = surface.Brightness * (1 - depth * 0.25)
	tint.TintColor = tint.TintColor:Lerp(area.Tint, k)
	tint.Brightness = area.Brightness
	tint.Contrast = 0.03
	tint.Saturation = 0.15
	blur.Size = 1

	bubbleClock += dt
	if bubbleClock > 0.22 and not perfMode() then
		bubbleClock = 0
		spawnBubble()
	end
end)

-- Anéis das barracas ----------------------------------------------------------------------------
local inside = {}
local ringClock = 0
RunService.Heartbeat:Connect(function(dt)
	ringClock += dt
	if ringClock < 0.15 then
		return
	end
	ringClock = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or player:GetAttribute("Running") then
		return
	end
	for _, ring in ipairs(Layout.ShopRings) do
		local offset = root.Position - ring.Position
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		local isInside = flat < ring.Radius and math.abs(offset.Y) < 8
		if isInside and not inside[ring.Shop] then
			inside[ring.Shop] = true
			UIKit.OpenWindow(ring.Shop)
		elseif not isInside and inside[ring.Shop] then
			inside[ring.Shop] = false
			local window = UIKit.Windows[ring.Shop]
			if window and window.IsOpen then
				window.Close()
			end
		end
	end
end)

-- Placas: só o dono vê o botão de melhorar ------------------------------------------------------
local function updatePrompts(model)
	local mine = model:GetAttribute("Owner") == player.UserId
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("ProximityPrompt") then
			item.Enabled = mine
		elseif item:IsA("ClickDetector") then
			item.MaxActivationDistance = mine and 40 or 0
		end
	end
end
for _, model in ipairs(plots:GetChildren()) do
	updatePrompts(model)
	model:GetAttributeChangedSignal("Owner"):Connect(function()
		updatePrompts(model)
	end)
end

-- Esteira: o jogador fica preso olhando para o aquário, andando. Para sair, pula. -------------
local UserInputService = game:GetService("UserInputService")
local lock = nil -- { Humanoid, Root, Zone, WalkSpeed, JumpPower, Track }
local exitUntilOutside = false

local function myTreadmillZone()
	for _, model in ipairs(plots:GetChildren()) do
		if model:GetAttribute("Owner") == player.UserId then
			local treadmill = model:FindFirstChild("Esteira")
			return treadmill and treadmill:FindFirstChild("Zona")
		end
	end
	return nil
end

local function insideZone(zone, position)
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

local function lockOnTreadmill(humanoid, root, zone)
	-- não ancora: o servidor precisa continuar vendo o jogador em cima da esteira
	lock = { Humanoid = humanoid, Root = root, Zone = zone, AutoRotate = humanoid.AutoRotate, WalkSpeed = humanoid.WalkSpeed }
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0

	-- quanto maior o nível da esteira, mais rápido o personagem corre
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local animate = humanoid.Parent:FindFirstChild("Animate")
	local plot = zone.Parent and zone.Parent.Parent
	local level = plot and plot:GetAttribute("TreadmillLevel") or 1
	local runFolder = animate and animate:FindFirstChild(level <= 2 and "walk" or "run")
	local animation = runFolder and runFolder:FindFirstChildOfClass("Animation")
	if animator and animation then
		lock.Track = animator:LoadAnimation(animation)
		lock.Track.Priority = Enum.AnimationPriority.Action
		lock.Track.Looped = true
		lock.Track:Play(0.2)
		lock.Track:AdjustSpeed(math.clamp(0.85 + (level - 1) * 0.04, 0.85, 1.6)) -- cresce devagar e tem limite (não fica frenético)
	end
end

local function unlockTreadmill()
	if not lock then
		return
	end
	local current = lock
	lock = nil
	if current.Track then
		current.Track:Stop(0.2)
	end
	if current.Root.Parent then
		-- sai pela frente da esteira (o lado de onde se entra), olhando para o mar
		local zone = current.Zone
		local out = zone.CFrame * CFrame.new(0, 0, -(zone.Size.Z / 2 + 3))
		local y = current.Root.Position.Y
		current.Root.CFrame = CFrame.lookAt(Vector3.new(out.X, y, out.Z), Vector3.new(out.X, y, out.Z - 10))
		current.Root.AssemblyLinearVelocity = Vector3.new(0, 25, -12)
	end
	if current.Humanoid.Parent then
		current.Humanoid.AutoRotate = current.AutoRotate
		current.Humanoid.WalkSpeed = current.WalkSpeed
	end
	exitUntilOutside = true
end

UserInputService.JumpRequest:Connect(function()
	if lock then
		unlockTreadmill()
	end
end)

local treadmillClock = 0
RunService.Heartbeat:Connect(function(dt)
	treadmillClock += dt
	if treadmillClock < 0.1 then
		return
	end
	treadmillClock = 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if lock then
		if not root or lock.Root ~= root or player:GetAttribute("Running") then
			lock = nil
		end
		return
	end
	if not humanoid or not root or humanoid.Health <= 0 or player:GetAttribute("Running") then
		return
	end
	local zone = myTreadmillZone()
	if not zone then
		return
	end
	local inside = insideZone(zone, root.Position)
	if exitUntilOutside then
		if not inside then
			exitUntilOutside = false
		end
		return
	end
	if inside then
		lockOnTreadmill(humanoid, root, zone)
	end
end)

player.CharacterAdded:Connect(function()
	lock = nil
	exitUntilOutside = false
end)

-- enquanto preso: no meio da esteira, de frente para o aquário (+Z)
RunService.RenderStepped:Connect(function()
	if not lock or not lock.Root.Parent then
		return
	end
	if lock.Track and lock.Zone.Parent and lock.Zone.Parent.Parent then
		local level = lock.Zone.Parent.Parent:GetAttribute("TreadmillLevel") or 1
		lock.Track:AdjustSpeed(math.clamp(0.85 + (level - 1) * 0.04, 0.85, 1.6)) -- cresce devagar e tem limite (não fica frenético)
	end
	local center = lock.Zone.Position
	local y = lock.Root.Position.Y
	lock.Root.CFrame = CFrame.lookAt(Vector3.new(center.X, y, center.Z), Vector3.new(center.X, y, center.Z + 10))
	local velocity = lock.Root.AssemblyLinearVelocity
	lock.Root.AssemblyLinearVelocity = Vector3.new(0, math.min(velocity.Y, 0), 0)
end)

local stripeBase = {}
local function stripesOf(model)
	local treadmill = model:FindFirstChild("Esteira")
	local folder = treadmill and treadmill:FindFirstChild("Listras")
	local base = treadmill and treadmill:FindFirstChild("Base")
	if not folder or not base then
		return nil
	end
	if not stripeBase[model] then
		local list = {}
		for _, stripe in ipairs(folder:GetChildren()) do
			table.insert(list, { Part = stripe, Offset = base.CFrame:ToObjectSpace(stripe.CFrame) })
		end
		-- Period = distância entre as setas; Span = comprimento total do ciclo (setas × Period)
		stripeBase[model] = {
			Base = base,
			List = list,
			Period = folder:GetAttribute("Period") or 2,
			Span = folder:GetAttribute("Span") or 16,
		}
	end
	return stripeBase[model]
end

local function ownerTraining(model)
	local ownerId = model:GetAttribute("Owner")
	if not ownerId then
		return false
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	return owner ~= nil and owner:GetAttribute("Training") == true
end

local beltShift = {}
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for _, model in ipairs(plots:GetChildren()) do
		-- esteira (anda mais rápido a cada nível)
		if ownerTraining(model) then
			local level = model:GetAttribute("TreadmillLevel") or 1
			local info = stripesOf(model)
			if info then
				beltShift[model] = ((beltShift[model] or 0) + dt * math.clamp(6 + level * 1.2, 6, 30)) % info.Period
				local shift = beltShift[model]
				local half = info.Span / 2
				for _, item in ipairs(info.List) do
					local z = item.Offset.Position.Z - shift
					if z < -half then
						z += info.Span
					end
					local pos = item.Offset.Position
					item.Part.CFrame = info.Base.CFrame * CFrame.new(pos.X, pos.Y, z) * item.Offset.Rotation
				end
			end
		end
		-- peixes do aquário
		local aquarium = model:FindFirstChild("Aquario")
		local folder = aquarium and aquarium:FindFirstChild("Peixes")
		if folder then
			for _, fish in ipairs(folder:GetChildren()) do
				local rootPart = fish.PrimaryPart
				local baseY = fish:GetAttribute("BaseY")
				if rootPart and baseY then
					local phase = fish:GetAttribute("Bob") or 0
					local cf = rootPart.CFrame
					local p = cf.Position
					rootPart.CFrame = CFrame.new(p.X, baseY + math.sin(t * 1.4 + phase) * 0.45, p.Z) * cf.Rotation
					FishModel.Wag(fish, t + phase, 3.2)
				end
			end
		end
	end
end)

-- Vendedores das barracas (bonecos Roblox): ficam parados "respirando" e acenam de vez em
-- quando para quem chega. Animações padrão do Roblox (R15), tocadas só no seu computador.
local IDLE_ANIM = "rbxassetid://507766666"
local WAVE_ANIM = "rbxassetid://507770239"
local function animateVendor(rig)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local idle = Instance.new("Animation")
	idle.AnimationId = IDLE_ANIM
	local wave = Instance.new("Animation")
	wave.AnimationId = WAVE_ANIM
	local ok, idleTrack = pcall(animator.LoadAnimation, animator, idle)
	if not ok then
		return
	end
	idleTrack.Looped = true
	idleTrack:Play(0.3)
	local okWave, waveTrack = pcall(animator.LoadAnimation, animator, wave)
	if not okWave then
		return
	end
	waveTrack.Priority = Enum.AnimationPriority.Action
	task.spawn(function()
		task.wait(math.random() * 4)
		while rig.Parent do
			task.wait(6 + math.random() * 6)
			waveTrack:Play(0.25)
		end
	end)
end
task.spawn(function()
	local plaza = map:WaitForChild("Praca", 30)
	if not plaza then
		return
	end
	for _, item in ipairs(plaza:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("NPC") then
			animateVendor(item)
		end
	end
end)

-- Superfície da água: as texturas marcadas com a tag "AguaMovendo" deslizam devagar, cada
-- camada para um lado (atributos SpeedU/SpeedV em studs por segundo) — dá o brilho da água
-- se mexendo. Só mexe no deslocamento da textura: custo quase zero.
local CollectionService = game:GetService("CollectionService")
local waterTextures = {}
local function trackWater(texture)
	if texture:IsA("Texture") then
		table.insert(waterTextures, texture)
	end
end
for _, texture in ipairs(CollectionService:GetTagged("AguaMovendo")) do
	trackWater(texture)
end
CollectionService:GetInstanceAddedSignal("AguaMovendo"):Connect(trackWater)
RunService.Heartbeat:Connect(function(dt)
	if perfMode() then
		return
	end
	for _, texture in ipairs(waterTextures) do
		local u = texture:GetAttribute("SpeedU") or 1
		local v = texture:GetAttribute("SpeedV") or 1
		texture.OffsetStudsU = (texture.OffsetStudsU + u * dt) % texture.StudsPerTileU
		texture.OffsetStudsV = (texture.OffsetStudsV + v * dt) % texture.StudsPerTileV
	end
end)
