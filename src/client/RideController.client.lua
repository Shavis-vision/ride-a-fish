-- RideController (LocalScript)
-- Fica em: StarterPlayerScripts > Client > RideController
--
-- A CORRIDA, do lado do jogador:
--   1. Entre na água e pise no anel da zona de mergulho: o servidor manda um seed e o
--      jogador mergulha para a frente.
--   2. Os peixes da corrida (gerados com o seed, iguais aos do servidor) nadam sempre para
--      a frente e desviam dos obstáculos. Cada um mostra o nome e a stamina que pede, em
--      verde (dá), amarelo (quase, 80%+) ou vermelho (falta).
--   3. ESPAÇO (ou o botão PULAR) salta do peixe: o tempo fica lento e aparece um círculo
--      amarelo embaixo de você (A/D para os lados; a assistência pega peixes um pouco à
--      frente). ESPAÇO de novo lança o arpão no peixe que o círculo pegou.
--   4. Em cima do peixe: com stamina suficiente, ele é domado depois de alguns segundos.
--      Sem stamina suficiente, ele te derruba antes (você perde só esse peixe).
--      Domado, ele aguenta você por um tempo (mais stamina = mais tempo) e depois te derruba.
--   5. Bateu num obstáculo, foi derrubado e não pegou outro peixe a tempo? Caiu no fundo:
--      volta para a praia (ou revive, se o produto estiver configurado).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Fish = require(Shared:WaitForChild("Fish"))
local Track = require(Shared:WaitForChild("Track"))
local Layout = require(Shared:WaitForChild("Layout"))
local FishModel = require(Shared:WaitForChild("FishModel"))
local Progression = require(Shared:WaitForChild("Progression"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local RunPanel = require(script.Parent:WaitForChild("RunPanel"))
local SoundFx = require(script.Parent:WaitForChild("SoundFx"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local RIDE = Config.RIDE
local RIDER_OFFSET = 1.9 -- altura do HumanoidRootPart acima da sela
local SWIM = Track.FISH_SWIM_HEIGHT

local character, humanoid, root, sitTrack
local poseTracks = {} -- animações de pose durante a corrida: sit, run, jump, fall
local controls = nil
task.spawn(function()
	local ok, module = pcall(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 60)
		return module and require(module)
	end)
	if ok and module then
		controls = module:GetControls()
	end
end)

local function moveX()
	if controls then
		local ok, vector = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and vector and vector.X ~= 0 then
			return math.clamp(vector.X, -1, 1)
		end
	end
	-- reserva 1: a direção que o Roblox calcula para o Humanoid (serve para o analógico do celular).
	-- A câmera olha para -Z, então "direita na tela" = +X no mundo.
	if humanoid and humanoid.Parent then
		local direction = humanoid.MoveDirection
		if math.abs(direction.X) > 0.05 then
			return math.clamp(direction.X / math.max(direction.Magnitude, 1e-3), -1, 1)
		end
	end
	-- reserva 2: lê o teclado direto (funciona mesmo sem o PlayerModule)
	local x = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		x -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		x += 1
	end
	return x
end

-- W/S (frente/trás): +1 = frente (W), -1 = trás (S)
local function moveZ()
	if controls then
		local ok, vector = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and vector and vector.Z ~= 0 then
			return math.clamp(-vector.Z, -1, 1)
		end
	end
	if humanoid and humanoid.Parent then
		local direction = humanoid.MoveDirection
		if math.abs(direction.Z) > 0.05 then
			return math.clamp(-direction.Z / math.max(direction.Magnitude, 1e-3), -1, 1)
		end
	end
	local z = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		z += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		z -= 1
	end
	return z
end

-- Estado ------------------------------------------------------------------------------------
local state = "Idle" -- Idle, Airborne, Riding, Zipping, Fallen
local run = nil
local rider: { [string]: any } = {}
local requesting = false
local cooldownUntil = 0
local target = nil
local cycleTarget -- (definida mais abaixo)
local lastAreaIndex = 0
local lastActionAt = 0

local highlight = Instance.new("Highlight")
highlight.Name = "AlvoDoArpao"
highlight.FillColor = Color3.fromRGB(255, 215, 40) -- o peixe escolhido fica todo amarelo
highlight.FillTransparency = 0.12
highlight.OutlineColor = Color3.fromRGB(255, 240, 150)
highlight.OutlineTransparency = 0.4
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
-- sem Adornee, o Highlight marca o próprio pai: ele é colocado dentro do peixe-alvo

-- Círculo amarelo da mira: um anel TRACEJADO deitado no fundo do mar, embaixo de você (ou
-- embaixo do peixe que a assistência pegou). O peixe escolhido brilha em amarelo.
local RING_STUDS = 14
local reticleAnchor = Instance.new("Part")
reticleAnchor.Name = "MiraDoArpao"
reticleAnchor.Anchored = true
reticleAnchor.CanCollide = false
reticleAnchor.CanQuery = false
reticleAnchor.CanTouch = false
reticleAnchor.Transparency = 1
reticleAnchor.Size = Vector3.new(RING_STUDS, 0.1, RING_STUDS)
reticleAnchor.Parent = Workspace
local reticle = Instance.new("SurfaceGui")
reticle.Name = "Circulo"
reticle.Face = Enum.NormalId.Top
reticle.AlwaysOnTop = true
reticle.LightInfluence = 0
reticle.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
reticle.PixelsPerStud = 24
reticle.Enabled = false
reticle.Parent = reticleAnchor
local reticleRing = Instance.new("Frame")
reticleRing.Size = UDim2.fromScale(1, 1)
reticleRing.BackgroundTransparency = 1
reticleRing.Parent = reticle
local reticleScale = Instance.new("UIScale")
reticleScale.Parent = reticleRing
local dashes = {}
do
	local count = 18
	local pixels = RING_STUDS * 24
	local radius = pixels * 0.44
	local dashLength = 2 * math.pi * radius / count * 0.55
	for i = 0, count - 1 do
		local angle = i / count * math.pi * 2
		local dash = Instance.new("Frame")
		dash.BorderSizePixel = 0
		dash.AnchorPoint = Vector2.new(0.5, 0.5)
		dash.Size = UDim2.fromOffset(dashLength, 9)
		dash.Position = UDim2.fromOffset(pixels / 2 + math.cos(angle) * radius, pixels / 2 + math.sin(angle) * radius)
		dash.Rotation = math.deg(angle) + 90
		dash.BackgroundColor3 = Color3.fromRGB(255, 225, 40)
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = dash
		dash.Parent = reticleRing
		table.insert(dashes, dash)
	end
end
local function setReticleColor(color)
	for _, dash in ipairs(dashes) do
		dash.BackgroundColor3 = color
	end
end

local rope = Instance.new("Part")
rope.Name = "CordaDoArpao"
rope.Anchored = true
rope.CanCollide = false
rope.CanQuery = false
rope.CanTouch = false
rope.CastShadow = false
rope.Material = Enum.Material.Neon
rope.Color = Color3.fromRGB(255, 230, 160)
rope.Size = Vector3.new(0.25, 0.25, 1)
rope.Transparency = 1
rope.Parent = Workspace

-- Tela da corrida ---------------------------------------------------------------------------
local gui = UIKit.Gui("RunHUD", 4)
gui.Enabled = false

local topBar = UIKit.Frame(gui, {
	Size = UDim2.fromOffset(520, 64),
	Position = UDim2.new(0.5, 0, 0, 16),
	AnchorPoint = Vector2.new(0.5, 0),
	Color = Color3.fromRGB(20, 30, 50),
	Transparency = 0.25,
	Corner = 14,
	Stroke = 3,
})
UIKit.AutoScale(topBar)
local areaLabel = UIKit.Text(topBar, { Text = "", Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 4), Stroke = 3, Max = 32 })
local distLabel = UIKit.Text(topBar, { Text = "", Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 38), Color = Color3.fromRGB(170, 220, 255), Max = 22 })

RunPanel.Init(gui) -- lista da corrida, barra dos biomas com recorde

local tamePanel = UIKit.Frame(gui, {
	Size = UDim2.fromOffset(460, 104),
	Position = UDim2.new(0.5, 0, 0, 150),
	AnchorPoint = Vector2.new(0.5, 0),
	Transparency = 1,
	Corner = false,
})
UIKit.AutoScale(tamePanel)
local tameName = UIKit.Text(tamePanel, { Text = "", Size = UDim2.new(1, 0, 0, 36), Stroke = 3, Max = 34 })
local tameBarBack = UIKit.Frame(tamePanel, {
	Size = UDim2.new(1, -40, 0, 30),
	Position = UDim2.fromOffset(20, 40),
	Color = Color3.fromRGB(20, 20, 26),
	Corner = 10,
	Stroke = 3,
})
local tameFill = UIKit.Frame(tameBarBack, { Size = UDim2.fromScale(0, 1), Color = UIKit.White, Corner = 10 })
local tameGradient = UIKit.Gradient(tameFill, UIKit.Colors.Green[1], UIKit.Colors.Green[2], 90)
local buckMarker = UIKit.Frame(tameBarBack, { Size = UDim2.new(0, 4, 1, 8), Position = UDim2.fromScale(1, -0.13), Color = Color3.fromRGB(255, 70, 60), Corner = 2 })
local tameStatus = UIKit.Text(tamePanel, { Text = "", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 40), Max = 26 })
tameBarBack.Visible = false -- agora a doma aparece nos anéis ao lado do jogador

local hint = UIKit.Text(gui, {
	Text = "",
	Size = UDim2.fromOffset(700, 36),
	Position = UDim2.new(0.5, 0, 1, -24),
	AnchorPoint = Vector2.new(0.5, 1),
	Color = Color3.fromRGB(230, 240, 255),
	Max = 28,
})
UIKit.AutoScale(hint)

local backButton = UIKit.Button(gui, {
	Text = "Back to beach",
	Icon = "🏖️",
	Color = "Red",
	Size = UDim2.fromOffset(250, 60),
	Position = UDim2.new(1, -16, 0, 16),
	AnchorPoint = Vector2.new(1, 0),
	Max = 28,
})
UIKit.AutoScale(backButton)

local jumpButton = UIKit.Button(gui, {
	Text = "JUMP",
	Color = "Green",
	Size = UDim2.fromOffset(150, 150),
	Position = UDim2.new(1, -30, 1, -40),
	AnchorPoint = Vector2.new(1, 1),
	Corner = 75,
	Max = 40,
})
UIKit.AutoScale(jumpButton)
jumpButton.Visible = UserInputService.TouchEnabled

local banner = UIKit.Text(gui, {
	Text = "",
	Size = UDim2.fromOffset(900, 80),
	Position = UDim2.new(0.5, 0, 0.32, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Stroke = 5,
	Max = 72,
})
UIKit.AutoScale(banner)

local fallPanel = UIKit.Frame(gui, {
	Size = UDim2.fromOffset(520, 300),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Color = UIKit.Panel,
	Corner = 16,
	Stroke = 5,
})
UIKit.AutoScale(fallPanel, Vector2.new(520, 300))
fallPanel.Visible = false
UIKit.Text(fallPanel, { Text = "YOU FELL!", Size = UDim2.new(1, -20, 0, 66), Position = UDim2.fromOffset(10, 14), Color = Color3.fromRGB(255, 90, 80), Stroke = 4, Max = 60 })
local fallInfo = UIKit.Text(fallPanel, { Text = "", Size = UDim2.new(1, -30, 0, 34), Position = UDim2.fromOffset(15, 86), Max = 28 })
local fallCountdown = UIKit.Text(fallPanel, { Text = "", Size = UDim2.new(1, -30, 0, 30), Position = UDim2.fromOffset(15, 124), Color = Color3.fromRGB(200, 200, 210), Max = 26 })
local reviveButton = UIKit.Button(fallPanel, {
	Text = "Revive",
	Color = "Green",
	Size = UDim2.fromOffset(230, 70),
	Position = UDim2.new(0.5, -8, 1, -20),
	AnchorPoint = Vector2.new(1, 1),
	Max = 32,
})
-- coração pixelado que pulsa (só aparece na tela de queda, junto com o botão)
local reviveHeart = RunPanel.PixelHeart(reviveButton, 5)
reviveHeart.AnchorPoint = Vector2.new(0, 0.5)
reviveHeart.Position = UDim2.new(0, 10, 0.5, 0)
reviveHeart.ZIndex = reviveButton.ZIndex + 2
local heartScale = Instance.new("UIScale")
heartScale.Parent = reviveHeart
reviveButton.Label.Size = UDim2.new(1, -70, 0.78, 0)
reviveButton.Label.Position = UDim2.new(0, 62, 0.11, 0)
task.spawn(function()
	while true do
		if fallPanel.Visible and reviveButton.Visible then
			UIKit.Tween(heartScale, 0.28, { Scale = 1.25 }, Enum.EasingStyle.Sine)
			task.wait(0.3)
			UIKit.Tween(heartScale, 0.42, { Scale = 1 }, Enum.EasingStyle.Sine)
			task.wait(0.55)
		else
			heartScale.Scale = 1
			task.wait(0.25)
		end
	end
end)

local homeButton = UIKit.Button(fallPanel, {
	Text = "Leave",
	Color = "Gray",
	Size = UDim2.fromOffset(200, 70),
	Position = UDim2.new(0.5, 8, 1, -20),
	AnchorPoint = Vector2.new(0, 1),
	Max = 32,
})

local reviveProduct = nil
for _, product in ipairs(Config.PRODUCTS) do
	if product.Key == "Revive" then
		reviveProduct = product
	end
end
local reviveAvailable = reviveProduct ~= nil and (reviveProduct.Id ~= 0 or RunService:IsStudio())
if reviveProduct then
	reviveButton.Label.Text = "Revive " .. utf8.char(0xE002) .. reviveProduct.Price
end

-- Círculo de stamina (como no Zelda) ---------------------------------------------------------
-- Uma roda verde ao lado do jogador que esvazia enquanto ele está em cima do peixe.

-- Anel feito de pedacinhos em volta de um círculo: o fundo e o meio ficam TRANSPARENTES de
-- verdade (só a parte colorida aparece). fraction 1 = cheio; esvazia no sentido horário a
-- partir do topo. Devolve set(fraction, color) e o quadro do anel.
local function makeSegmentRing(parent, pixels, position, color, inner, count)
	local holder = Instance.new("Frame")
	holder.Name = "Anel"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(pixels, pixels)
	holder.Position = position
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Parent = parent
	local outerR = pixels / 2
	local innerR = outerR * inner
	local thickness = outerR - innerR
	local midR = (outerR + innerR) / 2
	local width = 2 * math.pi * midR / count + 1.2 -- um pouco de sobra para não ficar fresta
	local segments = {}
	for i = 1, count do
		local angle = (i - 0.5) / count * 360
		local rad = math.rad(angle)
		local seg = Instance.new("Frame")
		seg.BorderSizePixel = 0
		seg.BackgroundColor3 = color
		seg.AnchorPoint = Vector2.new(0.5, 0.5)
		seg.Size = UDim2.fromOffset(width, thickness)
		seg.Position = UDim2.new(0.5, math.sin(rad) * midR, 0.5, -math.cos(rad) * midR)
		seg.Rotation = angle
		seg.Parent = holder
		segments[i] = seg
	end
	return function(fraction, newColor)
		local shown = math.clamp(fraction, 0, 1) * count
		for i, seg in ipairs(segments) do
			seg.Visible = i <= math.ceil(shown - 0.01)
			if newColor then
				seg.BackgroundColor3 = newColor
			end
		end
	end, holder
end

-- Anéis ao lado do jogador: o VERDE grande é a stamina (esvazia), o ROSA pequeno é o
-- progresso da doma (enche até o peixe ser domado).
local wheel = Instance.new("BillboardGui")
wheel.Name = "AneisDaDoma"
wheel.Size = UDim2.fromOffset(110, 70)
wheel.StudsOffset = Vector3.new(3.4, 1.6, 0)
wheel.AlwaysOnTop = true
wheel.LightInfluence = 0
wheel.Enabled = false
wheel.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local setStaminaRing = makeSegmentRing(wheel, 58, UDim2.fromScale(0.68, 0.5), Color3.fromRGB(40, 240, 90), 0.45, 72)
local setTameRing, tameRingBack = makeSegmentRing(wheel, 34, UDim2.fromScale(0.2, 0.5), Color3.fromRGB(255, 110, 200), 0.45, 48)

-- fraction = quanto falta da stamina (anel verde)
local function setWheel(fraction, safe)
	local color = (safe or fraction > 0.3) and Color3.fromRGB(40, 240, 90) or Color3.fromRGB(255, 90 + 120 * math.max(fraction, 0), 50)
	setStaminaRing(fraction, color)
end

local function setTameProgress(fraction)
	if fraction then
		tameRingBack.Visible = true
		setTameRing(fraction)
	else
		tameRingBack.Visible = false
	end
end

local function showBanner(text, color)
	banner.Text = text
	banner.TextColor3 = color or UIKit.White
	banner.TextTransparency = 0
	local stroke = banner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	local scale = banner:FindFirstChild("Pop") or Instance.new("UIScale")
	scale.Name = "Pop"
	scale.Parent = banner
	scale.Scale = 0.6
	UIKit.Tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.6, function()
		if banner.Text == text then
			UIKit.Tween(banner, 0.8, { TextTransparency = 1 }, Enum.EasingStyle.Sine)
			if stroke then
				UIKit.Tween(stroke, 0.8, { Transparency = 1 }, Enum.EasingStyle.Sine)
			end
		end
	end)
end

-- Personagem ----------------------------------------------------------------------------------

local function bindCharacter(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid", 10)
	root = newCharacter:WaitForChild("HumanoidRootPart", 10)
end

local function setCollisionGroup(group)
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

-- a mochila do Roblox (peixes guardados) some durante a corrida
local function setBackpackVisible(visible)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, visible)
	end)
end

local function setupCharacter()
	if not humanoid or not root then
		return false
	end
	humanoid:UnequipTools()
	setBackpackVisible(false)
	humanoid.PlatformStand = true
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0.1)
		end
		table.clear(poseTracks)
		for _, name in ipairs({ "sit", "run", "jump", "fall" }) do
			local folder = animate and animate:FindFirstChild(name)
			local animation = folder and folder:FindFirstChildOfClass("Animation")
			if animation then
				local track = animator:LoadAnimation(animation)
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = name ~= "jump"
				poseTracks[name] = track
			end
		end
		sitTrack = poseTracks.sit
		if sitTrack then
			sitTrack:Play(0.1)
		end
	end
	setCollisionGroup("Riders")
	return true
end

local function restoreCharacter()
	setBackpackVisible(true)
	for _, track in pairs(poseTracks) do
		track:Stop(0.1)
	end
	table.clear(poseTracks)
	sitTrack = nil
	if humanoid and humanoid.Parent then
		humanoid.PlatformStand = false
		local animate = character:FindFirstChild("Animate")
		if animate then
			animate.Disabled = false
		end
	end
	if root and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	setCollisionGroup("Default")
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- troca a pose (com transição suave)
local currentPose = nil
local function setPose(name)
	if currentPose == name then
		return
	end
	currentPose = name
	for key, track in pairs(poseTracks) do
		if key == name then
			track:Play(0.2)
		elseif track.IsPlaying then
			track:Stop(0.25)
		end
	end
end

local function placeRider(cframe, velocity)
	if root and root.Parent then
		root.CFrame = cframe
		root.AssemblyLinearVelocity = velocity or Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

-- Peixes da corrida ---------------------------------------------------------------------------

local function stateColor(required)
	local s = Progression.StaminaState(ClientState.Stat("Stamina"), required)
	return Progression.StateColors[s], Progression.StateIcons[s]
end

-- Etiqueta em cima do peixe (estilo da referência): etiquetas da variação, a raridade em
-- destaque, o nome e "Precisa: ⚡ 265K" com o número verde/amarelo/vermelho.
local function makeLabel(obj)
	local species = obj.Species
	local rarity = Fish.Rarities[species.Rarity]
	local labelGui = Instance.new("BillboardGui")
	labelGui.Name = "Etiqueta"
	labelGui.Size = UDim2.new(10, 0, 4.4, 0)
	labelGui.StudsOffsetWorldSpace = Vector3.new(0, obj.Height / 2 + 4, 0)
	labelGui.MaxDistance = RIDE.LABEL_DISTANCE
	labelGui.LightInfluence = 0
	labelGui.Parent = obj.Root
	local tags = {}
	if obj.Data.M ~= "Normal" then
		table.insert(tags, string.upper(Fish.Mutations[obj.Data.M].Name))
	end
	if obj.Data.Z ~= "Normal" then
		table.insert(tags, string.upper(Fish.Sizes[obj.Data.Z].Name))
	end
	if #tags > 0 then
		UIKit.Text(labelGui, {
			Text = table.concat(tags, "  "),
			Size = UDim2.fromScale(1, 0.2),
			Color = obj.Data.M ~= "Normal" and Fish.Mutations[obj.Data.M].Color or Color3.fromRGB(255, 200, 120),
			Stroke = 2,
		})
	end
	UIKit.Text(labelGui, { Text = rarity.Name, Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.18), Color = rarity.Color, Stroke = 3 })
	obj.NameLabel = UIKit.Text(labelGui, { Text = species.Name, Rich = true, Size = UDim2.fromScale(1, 0.24), Position = UDim2.fromScale(0, 0.47), Stroke = 2.5 })
	obj.StaminaLabel = UIKit.Text(labelGui, {
		Text = "",
		Rich = true,
		Size = UDim2.fromScale(1, 0.28),
		Position = UDim2.fromScale(0, 0.72),
		Stroke = 2.5,
	})
	obj.Label = labelGui
end

local function refreshLabel(obj)
	if obj.NameLabel then
		-- espécie que o jogador ainda não tem no índex: "*NEW" em rosa ao lado do nome
		local isNew = not obj.Tamed and RunPanel.IsNew(obj.Species.Id)
		local text = isNew and ('%s <font color="#%s">*NEW</font>'):format(obj.Species.Name, RunPanel.NEW_COLOR:ToHex()) or obj.Species.Name
		if obj.NameLabel.Text ~= text then
			obj.NameLabel.Text = text
		end
	end
	if obj.StaminaLabel then
		local color = stateColor(obj.Required)
		local text = ('<i>Needs:</i> ⚡ <font color="#%s">%s</font>'):format(color:ToHex(), NumberFormat.Abbreviate(obj.Required))
		if obj.StaminaLabel.Text ~= text then
			obj.StaminaLabel.Text = text
		end
	end
end

local function spawnFish(data, preTamed)
	local species = Fish.Get(data.S)
	local model = FishModel.Build(data.S, data.M, data.Z, { Saddle = true })
	local obj = {
		Data = data,
		Species = species,
		Model = model,
		Root = model.PrimaryPart,
		SeatY = model:GetAttribute("SeatY"),
		SeatZ = model:GetAttribute("SeatZ"),
		Height = model:GetAttribute("Height"),
		Width = model:GetAttribute("Width"),
		Length = model:GetAttribute("Length"),
		Dist = data.Dist,
		X = data.X,
		BaseX = data.X,
		Phase = data.Phase or 0,
		Cruise = Fish.Speed(data.S, data.Z) * RIDE.CRUISE_FACTOR * (data.SpeedMul or 1),
		Required = Fish.RequiredStamina(data.S, data.Z),
		Tamed = preTamed == true,
		Escaped = false,
		TargetableAt = 0,
	}
	obj.Y = Track.SeabedY(obj.Dist) + SWIM + obj.Height / 2
	model:PivotTo(CFrame.new(obj.X, obj.Y, Track.ZOf(obj.Dist)))
	makeLabel(obj)
	refreshLabel(obj)
	model.Parent = run.Folder
	table.insert(run.Active, obj)
	return obj
end

local function destroyFish(obj)
	if obj.Model and highlight.Parent == obj.Model then
		highlight.Parent = nil -- não deixa o Highlight ser destruído junto com o peixe
	end
	if obj.Model then
		obj.Model:Destroy()
		obj.Model = nil
	end
end

local function updateFreeFish(obj, dt, t)
	obj.Dist += obj.Cruise * (obj.Escaped and 1.8 or 1) * dt
	local wander = math.sin(t * 0.7 + obj.Phase) * 5
	local avoid = 0
	for _, ob in ipairs(Track.Obstacles) do
		local ahead = ob.Dist - obj.Dist
		if ahead > -2 and ahead < 30 and math.abs(ob.X - obj.X) < ob.Radius + obj.Width + 3 then
			avoid += ((obj.X >= ob.X) and 1 or -1) * (ob.Radius + 7)
		end
	end
	local limit = Track.HALF_WIDTH - 6
	local targetX = math.clamp(obj.BaseX + wander + avoid, -limit, limit)
	local previousX = obj.X
	obj.X += (targetX - obj.X) * math.min(1, dt * 2.2)
	local bob = math.sin(t * 1.6 + obj.Phase) * 0.6
	local targetY = Track.SeabedY(obj.Dist) + SWIM + obj.Height / 2 + bob
	obj.Y += (targetY - obj.Y) * math.min(1, dt * 2.5)
	-- o giro do peixe acompanha a direção suavemente (antes vinha direto da velocidade de
	-- cada quadro e tremia quando o quadro demorava mais ou menos)
	local targetYaw = math.clamp(-(obj.X - previousX) / math.max(dt, 1e-3) * 0.02, -0.5, 0.5)
	obj.Yaw = (obj.Yaw or 0) + (targetYaw - (obj.Yaw or 0)) * math.min(1, dt * 4)
	obj.Root.CFrame = CFrame.new(obj.X, obj.Y, Track.ZOf(obj.Dist)) * CFrame.Angles(0, obj.Yaw, 0)
	FishModel.Wag(obj.Model, t + obj.Phase, 5)
end

-- Ações -----------------------------------------------------------------------------------------

local endRun -- definida mais abaixo

local function seatCFrame(obj)
	return obj.Root.CFrame * CFrame.new(0, obj.SeatY + RIDER_OFFSET, obj.SeatZ)
end

local function releaseMount()
	local obj = rider.Mount
	rider.Mount = nil
	if obj then
		if obj.Label then
			obj.Label.Enabled = true
		end
		obj.TargetableAt = os.clock() + 1.2
		if not obj.Tamed then
			-- fugiu: nada mais rápido por um tempo, mas dá para tentar montar de novo depois
			-- (antes ele ficava "travado": aparecia na tela mas nunca dava para mirar nele)
			obj.Escaped = true
		end
	end
	return obj
end

local function currentSpeed()
	local obj = rider.Mount
	if obj then
		return Fish.Speed(obj.Data.S, obj.Data.Z)
	end
	return 0
end

local function mount(obj)
	local now = os.clock()
	local stamina = ClientState.Stat("Stamina")
	rider.Mount = obj
	rider.MountAt = now
	rider.TameSent = false
	rider.CascoUsed = false
	rider.SaltoClock = now
	rider.LeapStart = nil
	rider.CanTame = stamina >= obj.Required
	rider.BuckAt = obj.Species.TameTime * math.clamp(stamina / obj.Required, 0.2, 1)
	if obj.Tamed then
		rider.RideTime = RIDE.BASE_RIDE_TIME + 4
		rider.RideEnd = now + rider.RideTime
		rider.WheelAtTame = 1
	end
	if obj.Label then
		obj.Label.Enabled = false
	end
	if obj.Data.Index then
		local index = obj.Data.Index
		task.spawn(function()
			ClientState.Request("Mount", index)
		end)
	end
	setPose("sit")
	state = "Riding"
end

-- começa a mira: tempo lento e o círculo amarelo à frente
local function startAim()
	rider.ManualTarget = nil
	rider.AirStart = os.clock()
	rider.SlowUntil = os.clock() + RIDE.SLOWMO_TIME
	reticle.Enabled = true
end

local function buck(reason)
	local speed = currentSpeed()
	releaseMount()
	rider.Vel = Vector3.new(0, RIDE.BUCK_UP, -speed * 0.55)
	state = "Airborne"
	startAim()
	SoundFx.Play("Buck")
	if reason then
		showBanner(reason, Color3.fromRGB(255, 120, 90))
	end
end

local function freeJump()
	local speed = currentSpeed()
	releaseMount()
	rider.Vel = Vector3.new(0, RIDE.JUMP_UP, -math.max(speed, 20) * 0.6)
	state = "Airborne"
	startAim()
	SoundFx.Play("Jump")
end

local function harpoon(obj, duration)
	releaseMount()
	reticle.Enabled = false
	rider.ZipFrom = rider.Pos
	rider.ZipTarget = obj
	rider.ZipStart = os.clock()
	rider.ZipDuration = duration or RIDE.HARPOON_TIME
	state = "Zipping"
	SoundFx.Play("Harpoon")
end

local function onAction()
	local now = os.clock()
	if now - lastActionAt < 0.25 then
		return
	end
	lastActionAt = now
	if state == "Riding" then
		freeJump()
	elseif state == "Airborne" then
		if target then
			harpoon(target)
		else
			-- errou: o círculo pisca em vermelho
			setReticleColor(Color3.fromRGB(255, 70, 60))
			task.delay(0.2, function()
				setReticleColor(Color3.fromRGB(255, 225, 40))
			end)
		end
	end
end

local function fall()
	state = "Fallen"
	rider.FallAt = os.clock()
	rider.FallPanelShown = false
	rider.ReviveDeadline = nil
	local floorY = Track.SeabedY(rider.Dist)
	rider.Pos = Vector3.new(rider.Pos.X, floorY + 1.2, rider.Pos.Z)
	placeRider(CFrame.new(rider.Pos) * CFrame.Angles(-math.pi / 2, 0, 0))
	showBanner("You fell!", Color3.fromRGB(255, 90, 80))
	SoundFx.Play("Fall")
	highlight.Parent = nil
end

local function revive()
	if state ~= "Fallen" or not run then
		return
	end
	fallPanel.Visible = false
	local area = Track.AreaAt(rider.Dist)
	local species = Fish.ByArea[area.Index][1]
	local obj = spawnFish({ S = species.Id, M = "Normal", Z = "Normal", Dist = rider.Dist + 3, X = rider.Pos.X, Phase = 0, SpeedMul = 1 }, true)
	mount(obj)
	showBanner("Back in!", UIKit.MoneyGreen)
	SoundFx.Play("Revive")
end

-- Começo e fim ------------------------------------------------------------------------------

local function beginRun(seed)
	if not setupCharacter() then
		task.spawn(function()
			ClientState.Request("EndRun", "erro")
		end)
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "PeixesDaCorrida"
	folder.Parent = Workspace
	run = {
		Seed = seed,
		Fish = Track.GenerateRun(seed),
		Start = os.clock(),
		NextSpawn = 1,
		Active = {},
		Folder = folder,
		Tamed = 0,
		LabelClock = 0,
		MaxDist = 0,
	}
	RunPanel.Begin(ClientState.Data and ClientState.Data.BestDist or 0)
	rider = {
		Pos = root.Position :: any,
		Vel = Vector3.new(0, RIDE.DIVE_UP, -RIDE.DIVE_FORWARD),
		Dist = Track.DistOf(root.Position.Z),
	}
	lastAreaIndex = 0
	camera.CameraType = Enum.CameraType.Scriptable
	gui.Enabled = true
	fallPanel.Visible = false
	-- animação de pulo do píer: vai até a ponta do trampolim, agacha, pula em arco, vira de
	-- cabeça para baixo e entra na água com um splash. Depois o mergulho leva ao 1º peixe.
	local first = spawnFish(run.Fish[1])
	run.NextSpawn = 2
	rider.DiveTarget = first
	rider.DiveStart = os.clock()
	rider.DiveFrom = root.Position
	currentPose = nil
	setPose("run")
	state = "Diving"
end

-- splash na água: anel branco que abre e gotinhas que espirram
local function splash(position)
	SoundFx.Play("Splash")
	local folder = Instance.new("Folder")
	folder.Name = "Splash"
	folder.Parent = Workspace
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Color3.new(1, 1, 1)
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(position.X, Track.WATER_Y + 0.15, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = folder
	UIKit.Tween(ring, 0.8, { Size = Vector3.new(0.2, 16, 16), Transparency = 1 }, Enum.EasingStyle.Quad)
	for i = 1, 14 do
		local drop = Instance.new("Part")
		drop.Anchored = true
		drop.CanCollide = false
		drop.CanQuery = false
		drop.CanTouch = false
		drop.CastShadow = false
		drop.Shape = Enum.PartType.Ball
		drop.Material = Enum.Material.SmoothPlastic
		drop.Color = Color3.fromRGB(230, 250, 255)
		drop.Size = Vector3.new(1, 1, 1) * (0.6 + (i % 3) * 0.3)
		drop.CFrame = CFrame.new(position.X, Track.WATER_Y + 0.3, position.Z)
		drop.Parent = folder
		local angle = i / 14 * math.pi * 2
		local up = 4 + (i % 4) * 1.5
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (2.5 + (i % 3))
		UIKit.Tween(drop, 0.35, { CFrame = drop.CFrame + out * 0.6 + Vector3.new(0, up, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.35, function()
			UIKit.Tween(drop, 0.4, { CFrame = drop.CFrame + out * 0.5 + Vector3.new(0, -up - 1, 0), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end
	task.delay(1.2, function()
		folder:Destroy()
	end)
end

-- Pulo do píer, em 4 partes (tudo com curvas suaves, sem "teletransporte"):
--   1. anda até a ponta do trampolim (o tempo depende da distância)
--   2. agacha (o trampolim afunda um pouco)
--   3. pula em arco, virando de cabeça para baixo, e entra na água com splash
--   4. desliza debaixo d'água numa curva até as costas do 1º peixe e senta
local DIVE_CROUCH = 0.25
local DIVE_AIR = 1.05
local DIVE_GLIDE = 1.5
local DIVE_PITCH = math.pi / 2 + 0.45
local function smooth(p)
	return p * p * (3 - 2 * p)
end
local function updateDiving(now)
	local t = now - rider.DiveStart
	local tip = Layout.DiveBoard + Vector3.new(0, 3, 0) -- altura do corpo em pé
	local entry = Vector3.new(0, Track.WATER_Y - 1.5, Track.ZOf(Track.PIER_END + 18))
	if not rider.DiveWalk then
		rider.DiveWalk = math.clamp((rider.DiveFrom - tip).Magnitude / 16, 0.3, 1)
	end
	local walk = rider.DiveWalk
	local pos, pitch
	if t < walk then
		pos = rider.DiveFrom:Lerp(tip, smooth(t / walk))
		pitch = 0
	elseif t < walk + DIVE_CROUCH then
		local p = (t - walk) / DIVE_CROUCH
		pos = tip - Vector3.new(0, math.sin(p * math.pi * 0.5) * 0.8, 0)
		pitch = p * 0.3
	elseif t < walk + DIVE_CROUCH + DIVE_AIR then
		local p = (t - walk - DIVE_CROUCH) / DIVE_AIR
		setPose(p < 0.45 and "jump" or "fall")
		local start = tip - Vector3.new(0, 0.8, 0)
		local flat = start:Lerp(entry, p)
		pos = flat + Vector3.new(0, math.sin(p * math.pi) * 8.5 * (1 - p * 0.25), 0)
		pitch = 0.3 - smooth(p) * (DIVE_PITCH + 0.3)
		if not rider.Splashed and pos.Y <= Track.WATER_Y + 0.5 and p > 0.6 then
			rider.Splashed = true
			splash(pos)
			showBanner("DIVE!", Color3.fromRGB(120, 230, 255))
		end
	else
		local p = math.clamp((t - walk - DIVE_CROUCH - DIVE_AIR) / DIVE_GLIDE, 0, 1)
		if not rider.Splashed then
			rider.Splashed = true
			splash(entry)
			showBanner("DIVE!", Color3.fromRGB(120, 230, 255))
		end
		local fish = rider.DiveTarget
		if not fish or not fish.Model then
			state = "Airborne"
			rider.Vel = Vector3.new(0, 0, -10)
			return
		end
		-- curva (Bézier) da entrada na água até a sela do peixe, que continua nadando
		local seat = seatCFrame(fish).Position
		local control = entry + Vector3.new(0, -10, -14)
		local e = smooth(p)
		local a1 = entry:Lerp(control, e)
		local b1 = control:Lerp(seat, e)
		pos = a1:Lerp(b1, e)
		pitch = -DIVE_PITCH * (1 - smooth(p))
		if p >= 1 then
			rider.Pos = seat
			rider.Dist = Track.DistOf(seat.Z)
			mount(fish)
			return
		end
	end
	local velocity = rider.Pos and (pos - rider.Pos) * 60 or Vector3.zero
	rider.Pos = pos
	rider.Dist = Track.DistOf(pos.Z)
	placeRider(CFrame.new(pos) * CFrame.Angles(pitch, 0, 0), velocity)
end

endRun = function(reason)
	if state == "Idle" then
		return
	end
	state = "Idle"
	highlight.Parent = nil
	local count = run and run.Tamed or 0
	local reached = run and run.MaxDist or 0
	if run then
		for _, obj in ipairs(run.Active) do
			destroyFish(obj)
		end
		if run.Folder then
			run.Folder:Destroy()
		end
	end
	run = nil
	rider = {}
	target = nil
	highlight.Parent = nil
	rope.Transparency = 1
	gui.Enabled = false
	fallPanel.Visible = false
	wheel.Enabled = false
	reticle.Enabled = false
	restoreCharacter()
	cooldownUntil = os.clock() + 2
	task.spawn(function()
		ClientState.Request("EndRun", reason, reached)
	end)
	if count > 0 then
		ClientState.Toast(("Run over: %d fish tamed!"):format(count), "ok")
	elseif reason == "caiu" then
		ClientState.Toast("Train on the treadmill to tame stronger fish.", "info")
	end
end

-- Loop principal ------------------------------------------------------------------------------

local function updateRiding(dt, now, t)
	local obj = rider.Mount
	local species = obj.Species
	local speed = Fish.Speed(obj.Data.S, obj.Data.Z)
	if species.Ability == "Turbo" and now - rider.MountAt > RIDE.TURBO_AFTER then
		speed *= RIDE.TURBO_MULT
	end
	-- a direção acelera e freia suave (sem tranco ao apertar ou soltar A/D)
	rider.Steer = (rider.Steer or 0) + (moveX() - (rider.Steer or 0)) * math.min(1, dt * 7)
	local steer = rider.Steer
	local limit = Track.HALF_WIDTH - 6
	obj.X = math.clamp(obj.X + steer * RIDE.STEER_SPEED * dt, -limit, limit)
	obj.Dist += speed * dt
	local baseY = Track.SeabedY(obj.Dist) + SWIM + obj.Height / 2

	-- habilidade Salto: pula para fora da água de tempos em tempos
	local leaping = false
	local extra = 0
	if species.Ability == "Salto" then
		if not rider.LeapStart and now - rider.SaltoClock > RIDE.SALTO_INTERVAL then
			rider.LeapStart = now
			rider.LeapPeak = math.max(Track.WATER_Y + 8, baseY + 8)
			showBanner("LEAP!", Color3.fromRGB(120, 230, 255))
		end
		if rider.LeapStart then
			local p = (now - rider.LeapStart) / 1.6
			if p >= 1 then
				rider.LeapStart = nil
				rider.SaltoClock = now
			else
				leaping = true
				extra = math.sin(math.pi * p) * (rider.LeapPeak - baseY)
			end
		end
	end
	if leaping then
		obj.Y = baseY + extra
	else
		obj.Y += (baseY - obj.Y) * math.min(1, dt * 4)
	end
	local pitch = leaping and math.cos(math.pi * ((now - rider.LeapStart) / 1.6)) * 0.5 or 0
	obj.Root.CFrame = CFrame.new(obj.X, obj.Y, Track.ZOf(obj.Dist)) * CFrame.Angles(pitch, -steer * 0.25, -steer * 0.2)
	FishModel.Wag(obj.Model, t, 8.5)
	rider.Dist = obj.Dist
	local seat = seatCFrame(obj)
	rider.Pos = seat.Position
	placeRider(seat, Vector3.new(0, 0, -speed))

	-- obstáculos (1 segundo de folga logo depois de montar, para dar tempo de desviar)
	if not leaping and now - rider.MountAt > 1 then
		for _, ob in ipairs(Track.Obstacles) do
			if math.abs(ob.Dist - obj.Dist) < ob.Radius + obj.Length * 0.35 and math.abs(ob.X - obj.X) < ob.Radius + obj.Width * 0.5 then
				if species.Ability == "Casco" and not rider.CascoUsed then
					rider.CascoUsed = true
					obj.X += (obj.X >= ob.X and 1 or -1) * (ob.Radius + obj.Width)
					showBanner("YOUR SHELL PROTECTED YOU!", Color3.fromRGB(120, 230, 255))
				else
					buck("Crash!")
				end
				return
			end
		end
	end

	-- doma
	if not obj.Tamed then
		local elapsed = now - rider.MountAt
		if rider.CanTame then
			if elapsed >= species.TameTime and not rider.TameSent then
				rider.TameSent = true
				local index = obj.Data.Index
				local wasNew = RunPanel.IsNew(species.Id)
				task.spawn(function()
					local result = ClientState.Request("Tame", index)
					if rider.Mount ~= obj or state ~= "Riding" then
						return
					end
					if result.ok then
						obj.Tamed = true
						run.Tamed += 1
						local stamina = math.max(1, ClientState.Stat("Stamina"))
						local ratio = stamina / math.max(1, obj.Required)
						-- o que sobrou da stamina continua gastando no mesmo ritmo da doma
						rider.RideTime = math.clamp(species.TameTime * (ratio - 1), RIDE.BASE_RIDE_TIME, RIDE.MAX_RIDE_TIME)
						rider.RideEnd = os.clock() + rider.RideTime
						rider.WheelAtTame = math.max(0.2, 1 - obj.Required / stamina)
						showBanner("TAMED!", UIKit.MoneyGreen)
						RunPanel.AddTamed(obj.Data, wasNew)
						SoundFx.Play(wasNew and "TameNew" or "Tame")
					else
						buck("It got away!")
					end
				end)
			end
		elseif elapsed >= rider.BuckAt then
			buck("Low stamina! It threw you off")
			return
		end
	elseif rider.RideEnd and now >= rider.RideEnd then
		buck("The fish got tired!")
		return
	end

	if obj.Dist > Track.LENGTH - 25 then
		ClientState.Toast("You reached the end! New areas coming soon.", "raro")
		endRun("fim")
	end
end

local function updateAirborne(realDt, dt)
	rider.Vel += Vector3.new(0, -RIDE.GRAVITY * dt, 0)
	-- A/D move o jogador para os lados no ar (a troca de peixe é no Q/E ou clicando)
	rider.Steer = (rider.Steer or 0) + (moveX() - (rider.Steer or 0)) * math.min(1, realDt * 7)
	local steer = rider.Steer
	local pos = rider.Pos + rider.Vel * dt + Vector3.new(steer * RIDE.AIR_STEER_SPEED * realDt, 0, 0)
	local limit = Track.HALF_WIDTH - 4
	pos = Vector3.new(math.clamp(pos.X, -limit, limit), pos.Y, pos.Z)
	rider.Pos = pos
	rider.Dist = Track.DistOf(pos.Z)
	local tilt = math.clamp(rider.Vel.Y * 0.02, -0.5, 0.5)
	placeRider(CFrame.new(pos) * CFrame.Angles(tilt, 0, -steer * 0.3), rider.Vel * (dt / math.max(realDt, 1e-3)))
	if pos.Y <= Track.SeabedY(rider.Dist) + 2.6 then
		fall()
	end
end

local function updateZipping(now)
	local obj = rider.ZipTarget
	if not obj or not obj.Model then
		state = "Airborne"
		rider.Vel = Vector3.new(0, 0, -10)
		rope.Transparency = 1
		return
	end
	local p = math.clamp((now - rider.ZipStart) / (rider.ZipDuration or RIDE.HARPOON_TIME), 0, 1)
	local eased = p * p * (3 - 2 * p) -- começa e termina suave
	local seat = seatCFrame(obj)
	local arc = rider.ZipDuration and rider.ZipDuration > 0.5 and 0 or 3 -- o mergulho desce reto
	local pos = rider.ZipFrom:Lerp(seat.Position, eased) + Vector3.new(0, math.sin(p * math.pi) * arc, 0)
	rider.Pos = pos
	rider.Dist = Track.DistOf(pos.Z)
	placeRider(CFrame.new(pos) * seat.Rotation)
	-- corda
	local from = pos + Vector3.new(0, 0.5, 0)
	local to = obj.Root.Position
	local length = (to - from).Magnitude
	rope.Size = Vector3.new(0.25, 0.25, math.max(0.1, length))
	rope.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	rope.Transparency = 0.1
	if p >= 1 then
		rope.Transparency = 1
		mount(obj)
	end
end

-- Peixe que o círculo pega (assistência de mira): o MAIS PERTO de você que o arpão alcança,
-- em qualquer direção (até um pouco para trás).
-- peixe que vai bater numa pedra logo depois de você montar (não é uma boa escolha)
local function aboutToHit(obj)
	for _, ob in ipairs(Track.Obstacles) do
		local ahead = ob.Dist - obj.Dist
		if ahead > -ob.Radius and ahead < RIDE.ASSIST_OBSTACLE_AHEAD and math.abs(ob.X - obj.X) < ob.Radius + obj.Width * 0.5 + 2 then
			return true
		end
	end
	return false
end

-- Mira: o peixe MAIS PERTO dentro do alcance. Peixes prestes a bater numa pedra só são
-- escolhidos se não houver outro.
-- Mira: um ponto À FRENTE de você, mais ou menos onde você vai cair. A/D move o ponto para
-- os lados. O alvo é o peixe mais perto desse ponto, e ele fica "grudado" até outro ficar
-- bem mais perto — assim o círculo não fica pulando de um peixe para outro.
-- O ponto de mira segue a direção que você aperta: A/D puxa para a esquerda/direita
-- (prioriza os peixes daquele lado), W para os da frente e S para os de trás.
local function aimPoint()
	local forward = math.clamp(-rider.Vel.Z, 14, 40) * 0.9
	local side, ahead = moveX(), moveZ()
	if ahead > 0.3 then
		forward += 25 -- W: os peixes da frente (mais longe)
	elseif ahead < -0.3 then
		forward = -(RIDE.ASSIST_BEHIND - 2) -- S: os peixes de trás
	end
	return Vector3.new(rider.Pos.X + side * 26, rider.Pos.Y, rider.Pos.Z - forward)
end

local function canTarget(obj, now)
	if not obj or not obj.Model or obj == rider.Mount or now < obj.TargetableAt then
		return false
	end
	if obj.Dist - rider.Dist < -RIDE.ASSIST_BEHIND then
		return false
	end
	-- alcance medido no plano (no ar você fica bem alto; a altura não deve tirar o peixe do alcance)
	local p = obj.Root.Position
	return Vector2.new(p.X - rider.Pos.X, p.Z - rider.Pos.Z).Magnitude < RIDE.HARPOON_RANGE
end

local function chooseTarget(now)
	-- escolhido pelo jogador (A/D ou clique/toque no peixe): fica nele enquanto der
	if rider.ManualTarget and canTarget(rider.ManualTarget, now) then
		return rider.ManualTarget
	end
	rider.ManualTarget = nil
	local aim = aimPoint()
	local function score(obj)
		local p = obj.Root.Position
		local flat = Vector2.new(p.X - aim.X, p.Z - aim.Z).Magnitude
		return flat + (aboutToHit(obj) and 40 or 0) -- prefere peixe que não vai bater numa pedra
	end
	local best, bestScore = nil, math.huge
	for _, obj in ipairs(run.Active) do
		if canTarget(obj, now) then
			local sc = score(obj)
			if sc < bestScore then
				best, bestScore = obj, sc
			end
		end
	end
	-- mantém o alvo atual se ele ainda serve e não está muito pior que o melhor
	-- (apertando uma direção, troca mais fácil para o peixe daquele lado)
	local steering = math.abs(moveX()) > 0.3 or math.abs(moveZ()) > 0.3
	local keep = steering and 1.12 or 1.35
	if target ~= best and canTarget(target, now) and score(target) < bestScore * keep + (steering and 1 or 4) then
		return target
	end
	return best
end

-- A/D no ar: troca o alvo para o próximo peixe à esquerda/direita (um toque = um peixe)
cycleTarget = function(direction, now)
	local current = target
	local cx = current and current.Root.Position.X or rider.Pos.X
	local cz = current and current.Root.Position.Z or rider.Pos.Z - 20
	local best, bestScore = nil, math.huge
	for _, obj in ipairs(run.Active) do
		if obj ~= current and canTarget(obj, now) then
			local p = obj.Root.Position
			local dx = (p.X - cx) * direction
			if dx > 1 then
				-- o mais perto para o lado pedido, sem ir muito para a frente/trás
				local sc = dx + math.abs(p.Z - cz) * 0.6
				if sc < bestScore then
					best, bestScore = obj, sc
				end
			end
		end
	end
	if best then
		rider.ManualTarget = best
		SoundFx.Play("Click")
	end
end

-- clicar/tocar num peixe no ar: escolhe ele e já lança o arpão
local function targetAtScreen(position, now)
	local best, bestDistance = nil, 140
	for _, obj in ipairs(run.Active) do
		if canTarget(obj, now) then
			local screen, visible = camera:WorldToViewportPoint(obj.Root.Position)
			if visible then
				local d = (Vector2.new(screen.X, screen.Y) - position).Magnitude
				if d < bestDistance then
					best, bestDistance = obj, d
				end
			end
		end
	end
	return best
end

local function updateReticle(dt)
	if state ~= "Airborne" then
		reticle.Enabled = false
		return
	end
	reticle.Enabled = true
	-- o círculo fica no fundo, embaixo de você; com um peixe pego pela assistência, desliza
	-- para baixo dele e gira devagar
	-- sem alvo, o círculo fica no ponto de mira (à frente), mostrando para onde você aponta
	local aim = aimPoint()
	local goal = Vector3.new(aim.X, Track.SeabedY(Track.DistOf(aim.Z)) + 0.3, aim.Z)
	if target and target.Model then
		local p = target.Root.Position
		goal = Vector3.new(p.X, Track.SeabedY(target.Dist) + 0.3, p.Z)
		reticleScale.Scale = 1 + math.sin(os.clock() * 10) * 0.05
	else
		reticleScale.Scale = 1
	end
	reticleRing.Rotation = (os.clock() * 25) % 360
	local current = reticleAnchor.Position
	reticleAnchor.CFrame = CFrame.new(current:Lerp(goal, math.min(1, dt * 14)))
end

local function updateHud(now)
	local area = Track.AreaAt(rider.Dist)
	areaLabel.Text = ("AREA %d • %s"):format(area.Index, area.Name)
	distLabel.Text = ("%d m  •  ⚡ %s  •  tamed: %d"):format(math.max(0, math.floor(rider.Dist)), NumberFormat.Abbreviate(ClientState.Stat("Stamina")), run.Tamed)
	run.MaxDist = math.max(run.MaxDist or 0, rider.Dist)
	RunPanel.Update(rider.Dist)
	if area.Index ~= lastAreaIndex then
		if lastAreaIndex ~= 0 then
			showBanner(("AREA %d • %s"):format(area.Index, string.upper(area.Name)), area.Deco[1])
		end
		lastAreaIndex = area.Index
	end

	local obj = rider.Mount
	-- roda de stamina
	if state == "Riding" and obj then
		-- Anel = a stamina: durante a doma esvazia com o que o peixe pede (ou com toda a sua,
		-- se for menos); depois de domar, mostra quanto tempo ainda dá para ficar montado.
		local stamina = math.max(1, ClientState.Stat("Stamina"))
		local fraction
		if obj.Tamed and rider.RideEnd then
			fraction = math.max(0, rider.RideEnd - now) / math.max(0.01, rider.RideTime)
		else
			local spent = obj.Required / obj.Species.TameTime * (now - rider.MountAt)
			fraction = 1 - spent / math.min(stamina, obj.Required)
		end
		-- vermelho só quando a stamina não dá
		setWheel(fraction, rider.CanTame or obj.Tamed)
		if obj.Tamed then
			setTameProgress(nil)
		else
			setTameProgress((now - rider.MountAt) / obj.Species.TameTime)
		end
		if wheel.Parent ~= root then
			wheel.Parent = root
		end
		wheel.Enabled = true
	else
		wheel.Enabled = false
	end

	if state == "Riding" and obj then
		tamePanel.Visible = true
		local rarity = Fish.Rarities[obj.Species.Rarity]
		tameName.Text = obj.Species.Name
		tameName.TextColor3 = rarity.Color
		local elapsed = now - rider.MountAt
		if obj.Tamed and rider.RideEnd then
			local left = math.max(0, rider.RideEnd - now)
			tameFill.Size = UDim2.fromScale(math.clamp(left / rider.RideTime, 0, 1), 1)
			tameGradient.Color = ColorSequence.new(UIKit.Colors.Blue[1], UIKit.Colors.Blue[2])
			buckMarker.Visible = false
			tameStatus.Text = ("Tamed! Ride time: %.1fs — jump to the next one"):format(left)
			tameStatus.TextColor3 = Color3.fromRGB(150, 210, 255)
		else
			local tameTime = obj.Species.TameTime
			tameFill.Size = UDim2.fromScale(math.clamp(elapsed / tameTime, 0, 1), 1)
			if rider.CanTame then
				tameGradient.Color = ColorSequence.new(UIKit.Colors.Green[1], UIKit.Colors.Green[2])
				buckMarker.Visible = false
				tameStatus.Text = ("Taming... %.1fs"):format(math.max(0, tameTime - elapsed))
				tameStatus.TextColor3 = UIKit.MoneyGreen
			else
				tameGradient.Color = ColorSequence.new(UIKit.Colors.Red[1], UIKit.Colors.Red[2])
				buckMarker.Visible = true
				buckMarker.Position = UDim2.new(math.clamp(rider.BuckAt / tameTime, 0, 1), -2, -0.13, 0)
				tameStatus.Text = ("Needs ⚡%s — it will throw you off!"):format(NumberFormat.Abbreviate(obj.Required))
				tameStatus.TextColor3 = Color3.fromRGB(255, 120, 100)
			end
		end
	else
		tamePanel.Visible = false
	end

	jumpButton.Label.Text = state == "Airborne" and "HARPOON" or "JUMP"
	if state == "Riding" and obj and not obj.Tamed and rider.CanTame then
		hint.Text = "Hold on until it's tamed!  •  A/D: dodge the rocks"
	elseif state == "Riding" then
		hint.Text = "SPACE: jump off  •  A/D: dodge"
	elseif state == "Airborne" then
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			hint.Text = target and "Tap a fish to harpoon it  •  HARPOON: the yellow one" or "No fish in range..."
		else
			hint.Text = target and "SPACE: harpoon  •  Q/E: change fish  •  or click a fish" or "No fish in range... (A/D to move)"
		end
	else
		hint.Text = ""
	end
end

local function updateCamera(dt)
	local focus = rider.Pos
	local eye = focus + (state == "Airborne" and Vector3.new(0, 9, 22) or Vector3.new(0, 7, 20))
	local look = focus + Vector3.new(0, state == "Airborne" and -3 or 0, -28)
	if state == "Fallen" then
		eye = focus + Vector3.new(0, 12, 14)
		look = focus
	elseif state == "Diving" then
		-- atrás e acima (de lado a câmera batia no lampião do píer)
		eye = focus + Vector3.new(3, 8, 17)
		look = focus + Vector3.new(0, -2, -10)
	end
	-- a câmera fica debaixo d'água (só sobe junto quando o peixe salta para fora)
	if focus.Y < Track.WATER_Y then
		eye = Vector3.new(eye.X, math.min(eye.Y, Track.WATER_Y - 1.5), eye.Z)
	end
	local desired = CFrame.lookAt(eye, look)
	camera.CFrame = camera.CFrame:Lerp(desired, 1 - math.exp(-dt * 4.5)) -- câmera segue com mais calma
	local speed = state == "Riding" and currentSpeed() or 30
	camera.FieldOfView += ((68 + math.clamp(speed - 30, 0, 40) * 0.25) - camera.FieldOfView) * math.min(1, dt * 1.8)
end

local function updateFallen(now)
	placeRider(CFrame.new(rider.Pos) * CFrame.Angles(-math.pi / 2, 0, 0))
	if not rider.FallPanelShown and now - rider.FallAt >= RIDE.FALL_SHOW_TIME then
		rider.FallPanelShown = true
		fallPanel.Visible = true
		fallInfo.Text = ("Fish tamed this run: %d"):format(run.Tamed)
		reviveButton.Visible = reviveAvailable
		rider.ReviveDeadline = now + (reviveAvailable and RIDE.REVIVE_WINDOW or 2.5)
	end
	if rider.ReviveDeadline then
		local left = rider.ReviveDeadline - now
		fallCountdown.Text = ("Back to the beach in %d..."):format(math.max(0, math.ceil(left)))
		if left <= 0 then
			endRun("caiu")
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	if state == "Idle" or not run then
		return
	end
	if not root or not root.Parent then
		return
	end
	dt = math.min(dt, 0.05)
	local realDt = dt
	local now = os.clock()
	local t = now - run.Start
	-- câmera lenta enquanto mira (volta ao normal no fim)
	if state == "Airborne" and rider.SlowUntil and now < rider.SlowUntil then
		local left = rider.SlowUntil - now
		local scale = left < 0.3 and RIDE.SLOWMO + (1 - RIDE.SLOWMO) * (1 - left / 0.3) or RIDE.SLOWMO
		dt *= scale
	end

	-- novos peixes à frente (no máximo 2 por quadro: montar muitos modelos de uma vez
	-- dava umas travadinhas quando o jogador acelerava)
	local spawned = 0
	while spawned < 2 and run.Fish[run.NextSpawn] and run.Fish[run.NextSpawn].Dist < rider.Dist + RIDE.ACTIVATE_AHEAD do
		spawnFish(run.Fish[run.NextSpawn])
		run.NextSpawn += 1
		spawned += 1
	end

	-- peixes soltos
	for i = #run.Active, 1, -1 do
		local obj = run.Active[i]
		local mounted = obj == rider.Mount or (state == "Zipping" and obj == rider.ZipTarget)
		if not mounted then
			if obj.Dist < rider.Dist - RIDE.DESPAWN_BEHIND or obj.Dist > Track.LENGTH - 12 then
				destroyFish(obj)
				table.remove(run.Active, i)
			else
				updateFreeFish(obj, dt, t)
			end
		end
	end

	if state == "Riding" and rider.Mount then
		updateRiding(dt, now, t)
	elseif state == "Airborne" then
		updateAirborne(realDt, dt)
	elseif state == "Zipping" then
		updateZipping(now)
	elseif state == "Diving" then
		updateDiving(now)
	elseif state == "Fallen" then
		updateFallen(now)
	end
	if state == "Idle" or not run then
		return
	end

	-- alvo do arpão: só no ar, o peixe dentro do círculo
	if state == "Airborne" then
		target = chooseTarget(now)
		-- arpão automático (como nos vídeos de referência): se você não apertar de novo, o
		-- arpão sai sozinho no peixe escolhido logo depois do pulo
		if target and RIDE.AUTO_HARPOON_AFTER and rider.AirStart and now - rider.AirStart >= RIDE.AUTO_HARPOON_AFTER then
			harpoon(target)
			target = nil
		end
	else
		target = nil
	end
	updateReticle(realDt)
	if target and target.Model then
		if highlight.Parent ~= target.Model then
			highlight.Parent = target.Model
		end
	elseif highlight.Parent then
		highlight.Parent = nil
	end

	run.LabelClock += dt
	if run.LabelClock > 0.3 then
		run.LabelClock = 0
		for _, obj in ipairs(run.Active) do
			refreshLabel(obj)
		end
	end

	updateHud(now)
	updateCamera(realDt)
end)

-- Começar a corrida ao entrar na zona de mergulho
RunService.Heartbeat:Connect(function()
	if state ~= "Idle" or requesting or os.clock() < cooldownUntil then
		return
	end
	if not root or not root.Parent or player:GetAttribute("Running") then
		return
	end
	local offset = root.Position - Layout.StartZone
	local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if flat < Track.START_RADIUS and root.Position.Y < Track.PIER_TOP + 5 then
		requesting = true
		task.spawn(function()
			local result = ClientState.Request("StartRun")
			requesting = false
			if result.ok and result.Seed then
				beginRun(result.Seed)
			else
				cooldownUntil = os.clock() + 2
			end
		end)
	end
end)

-- Controles
UserInputService.JumpRequest:Connect(function()
	if state ~= "Idle" then
		onAction()
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or state == "Idle" then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		onAction()
	elseif state == "Airborne" and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1) then
		cycleTarget(-1, os.clock())
	elseif state == "Airborne" and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonR1) then
		cycleTarget(1, os.clock())
	elseif state == "Airborne" and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		local now = os.clock()
		local picked = targetAtScreen(Vector2.new(input.Position.X, input.Position.Y), now)
		if picked then
			rider.ManualTarget = picked
			target = picked
			harpoon(picked)
			target = nil
		end
	end
end)
jumpButton.Activated:Connect(onAction)
backButton.Activated:Connect(function()
	endRun("voltou")
end)
homeButton.Activated:Connect(function()
	endRun("caiu")
end)
reviveButton.Activated:Connect(function()
	if state ~= "Fallen" then
		return
	end
	if rider.ReviveDeadline then
		rider.ReviveDeadline += 20 -- espera a compra
	end
	ClientState.Request("BuyProduct", "Revive")
end)

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RideEvent").OnClientEvent:Connect(function(kind)
	if kind == "Revived" then
		revive()
	end
end)

-- Personagem novo: a corrida acaba (o servidor também encerra)
local function onCharacterAdded(newCharacter)
	if state ~= "Idle" then
		state = "Idle"
		highlight.Parent = nil
		if run and run.Folder then
			run.Folder:Destroy()
		end
		run = nil
		gui.Enabled = false
		highlight.Parent = nil
		rope.Transparency = 1
		wheel.Enabled = false
		setBackpackVisible(true)
		camera.CameraType = Enum.CameraType.Custom
	end
	bindCharacter(newCharacter)
end
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
