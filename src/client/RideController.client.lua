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
--      amarelo à frente (mire com A/D e W/S; ele gruda no peixe mais perto). ESPAÇO de novo
--      lança o arpão no peixe que estiver dentro do círculo.
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

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local RIDE = Config.RIDE
local RIDER_OFFSET = 1.9 -- altura do HumanoidRootPart acima da sela
local SWIM = Track.FISH_SWIM_HEIGHT

local character, humanoid, root, sitTrack
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

-- Para frente (+1) / para trás (-1): W/S, setas ou analógico (a câmera olha para -Z)
local function moveForward()
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
local lastAreaIndex = 0
local lastActionAt = 0

local highlight = Instance.new("Highlight")
highlight.Name = "AlvoDoArpao"
highlight.FillTransparency = 0.55
highlight.OutlineTransparency = 0
highlight.OutlineColor = Color3.new(1, 1, 1)
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
-- sem Adornee, o Highlight marca o próprio pai: ele é colocado dentro do peixe-alvo

-- Círculo amarelo da mira (fica no ponto para onde você vai lançar o arpão)
local reticleAnchor = Instance.new("Part")
reticleAnchor.Name = "MiraDoArpao"
reticleAnchor.Anchored = true
reticleAnchor.CanCollide = false
reticleAnchor.CanQuery = false
reticleAnchor.CanTouch = false
reticleAnchor.Transparency = 1
reticleAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
reticleAnchor.Parent = Workspace
local reticle = Instance.new("BillboardGui")
reticle.Name = "Circulo"
reticle.Size = UDim2.new(RIDE.RETICLE_SIZE, 0, RIDE.RETICLE_SIZE, 0)
reticle.AlwaysOnTop = true
reticle.LightInfluence = 0
reticle.Enabled = false
reticle.Parent = reticleAnchor
local reticleRing = Instance.new("Frame")
reticleRing.Size = UDim2.fromScale(1, 1)
reticleRing.BackgroundColor3 = Color3.fromRGB(255, 225, 40)
reticleRing.BackgroundTransparency = 0.85
reticleRing.Parent = reticle
local reticleCorner = Instance.new("UICorner")
reticleCorner.CornerRadius = UDim.new(1, 0)
reticleCorner.Parent = reticleRing
local reticleStroke = Instance.new("UIStroke")
reticleStroke.Color = Color3.fromRGB(255, 225, 40)
reticleStroke.Thickness = 5
reticleStroke.Parent = reticleRing
local reticleScale = Instance.new("UIScale")
reticleScale.Parent = reticleRing

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

local tamePanel = UIKit.Frame(gui, {
	Size = UDim2.fromOffset(460, 104),
	Position = UDim2.new(0.5, 0, 0, 96),
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
local tameStatus = UIKit.Text(tamePanel, { Text = "", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 74), Max = 26 })

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
	Text = "Voltar à praia",
	Icon = "🏖️",
	Color = "Red",
	Size = UDim2.fromOffset(250, 60),
	Position = UDim2.new(1, -16, 0, 16),
	AnchorPoint = Vector2.new(1, 0),
	Max = 28,
})
UIKit.AutoScale(backButton)

local jumpButton = UIKit.Button(gui, {
	Text = "PULAR",
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
UIKit.Text(fallPanel, { Text = "VOCÊ CAIU!", Size = UDim2.new(1, -20, 0, 66), Position = UDim2.fromOffset(10, 14), Color = Color3.fromRGB(255, 90, 80), Stroke = 4, Max = 60 })
local fallInfo = UIKit.Text(fallPanel, { Text = "", Size = UDim2.new(1, -30, 0, 34), Position = UDim2.fromOffset(15, 86), Max = 28 })
local fallCountdown = UIKit.Text(fallPanel, { Text = "", Size = UDim2.new(1, -30, 0, 30), Position = UDim2.fromOffset(15, 124), Color = Color3.fromRGB(200, 200, 210), Max = 26 })
local reviveButton = UIKit.Button(fallPanel, {
	Text = "Reviver",
	Icon = "❤️",
	Color = "Green",
	Size = UDim2.fromOffset(230, 70),
	Position = UDim2.new(0.5, -8, 1, -20),
	AnchorPoint = Vector2.new(1, 1),
	Max = 32,
})
local homeButton = UIKit.Button(fallPanel, {
	Text = "Voltar",
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
	reviveButton.Label.Text = "Reviver " .. utf8.char(0xE002) .. reviveProduct.Price
end

-- Círculo de stamina (como no Zelda) ---------------------------------------------------------
-- Uma roda verde ao lado do jogador que esvazia enquanto ele está em cima do peixe.
-- Desenho: duas metades com corte (ClipsDescendants) e um UIGradient com degrau no meio; girar
-- o degrau mostra só a fatia certa de cada metade.
local wheel = Instance.new("BillboardGui")
wheel.Name = "RodaDeStamina"
wheel.Size = UDim2.fromOffset(74, 74)
wheel.StudsOffset = Vector3.new(3.2, 1.6, 0)
wheel.AlwaysOnTop = true
wheel.LightInfluence = 0
wheel.Enabled = false
local wheelBack = UIKit.Frame(wheel, { Size = UDim2.fromScale(1, 1), Color = Color3.fromRGB(20, 25, 20), Transparency = 0.35, Corner = 999, Stroke = 3 })
local STEP = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.499, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 0),
})
local function wheelHalf(isRight)
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(0.5, 1)
	clip.Position = UDim2.fromScale(isRight and 0.5 or 0, 0)
	clip.ZIndex = 2
	clip.Parent = wheelBack
	local circle = Instance.new("Frame")
	circle.BorderSizePixel = 0
	circle.Size = UDim2.fromScale(2, 1)
	circle.Position = UDim2.fromScale(isRight and -1 or 0, 0)
	circle.BackgroundColor3 = Color3.fromRGB(90, 230, 70)
	circle.ZIndex = 2
	UIKit.Corner(circle, 999)
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = STEP
	gradient.Parent = circle
	circle.Parent = clip
	return circle, gradient
end
local wheelRight, wheelRightGradient = wheelHalf(true)
local wheelLeft, wheelLeftGradient = wheelHalf(false)
local wheelHole = UIKit.Frame(wheelBack, {
	Size = UDim2.fromScale(0.58, 0.58),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Color = Color3.fromRGB(20, 25, 20),
	Transparency = 0.1,
	Corner = 999,
	ZIndex = 3,
})
UIKit.Text(wheelHole, { Text = "⚡", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 4, Stroke = 1 })

-- fraction: 1 = cheia, 0 = vazia (some no sentido horário a partir do topo)
local function setWheel(fraction)
	fraction = math.clamp(fraction, 0, 1)
	local angle = fraction * 360
	if fraction >= 0.5 then
		wheelRightGradient.Rotation = 0
		wheelLeft.Visible = true
		wheelLeftGradient.Rotation = angle - 180
	else
		wheelRightGradient.Rotation = angle - 180
		wheelLeft.Visible = false
	end
	local color = fraction > 0.3 and Color3.fromRGB(90, 230, 70) or Color3.fromRGB(255, 90 + 120 * fraction, 50)
	wheelRight.BackgroundColor3 = color
	wheelLeft.BackgroundColor3 = color
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
	UIKit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.6, function()
		if banner.Text == text then
			UIKit.Tween(banner, 0.5, { TextTransparency = 1 })
			if stroke then
				UIKit.Tween(stroke, 0.5, { Transparency = 1 })
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
		local sit = animate and animate:FindFirstChild("sit")
		local animation = sit and sit:FindFirstChildOfClass("Animation")
		if animation then
			sitTrack = animator:LoadAnimation(animation)
			sitTrack.Priority = Enum.AnimationPriority.Action
			sitTrack.Looped = true
			sitTrack:Play(0.1)
		end
	end
	setCollisionGroup("Riders")
	return true
end

local function restoreCharacter()
	setBackpackVisible(true)
	if sitTrack then
		sitTrack:Stop(0.1)
		sitTrack = nil
	end
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

local function makeLabel(obj)
	local species = obj.Species
	local rarity = Fish.Rarities[species.Rarity]
	local labelGui = Instance.new("BillboardGui")
	labelGui.Name = "Etiqueta"
	labelGui.Size = UDim2.new(9, 0, 3.2, 0)
	labelGui.StudsOffsetWorldSpace = Vector3.new(0, obj.Height / 2 + 3.2, 0)
	labelGui.MaxDistance = RIDE.LABEL_DISTANCE
	labelGui.LightInfluence = 0
	labelGui.Parent = obj.Root
	UIKit.Text(labelGui, { Text = species.Name, Size = UDim2.fromScale(1, 0.38), Color = rarity.Color, Stroke = 2 })
	local tags = Fish.Tags(obj.Data)
	if tags ~= "" then
		UIKit.Text(labelGui, {
			Text = tags,
			Size = UDim2.fromScale(1, 0.26),
			Position = UDim2.fromScale(0, 0.36),
			Color = Fish.Mutations[obj.Data.M].Color,
			Stroke = 2,
		})
	end
	obj.StaminaLabel = UIKit.Text(labelGui, {
		Text = "",
		Size = UDim2.fromScale(1, 0.36),
		Position = UDim2.fromScale(0, 0.64),
		Stroke = 2,
	})
	obj.Label = labelGui
end

local function refreshLabel(obj)
	if obj.StaminaLabel then
		local color, icon = stateColor(obj.Required)
		obj.StaminaLabel.Text = "⚡ " .. NumberFormat.Abbreviate(obj.Required) .. " " .. icon
		obj.StaminaLabel.TextColor3 = color
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
	local yaw = math.clamp(-(obj.X - previousX) / math.max(dt, 1e-3) * 0.02, -0.5, 0.5)
	obj.Root.CFrame = CFrame.new(obj.X, obj.Y, Track.ZOf(obj.Dist)) * CFrame.Angles(0, yaw, 0)
	FishModel.Wag(obj.Model, t + obj.Phase, 8)
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
			obj.Escaped = true -- fugiu: não dá mais para domar este
			if obj.Label then
				obj.Label.Enabled = false
			end
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
	state = "Riding"
end

-- começa a mira: tempo lento e o círculo amarelo à frente
local function startAim()
	rider.SlowUntil = os.clock() + RIDE.SLOWMO_TIME
	rider.AimX = rider.Pos.X
	rider.AimAhead = RIDE.AIM_START
	reticle.Enabled = true
end

local function buck(reason)
	local speed = currentSpeed()
	releaseMount()
	rider.Vel = Vector3.new(0, RIDE.BUCK_UP, -speed * 0.55)
	state = "Airborne"
	startAim()
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
end

local function harpoon(obj, duration)
	releaseMount()
	reticle.Enabled = false
	rider.ZipFrom = rider.Pos
	rider.ZipTarget = obj
	rider.ZipStart = os.clock()
	rider.ZipDuration = duration or RIDE.HARPOON_TIME
	state = "Zipping"
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
			reticleStroke.Color = Color3.fromRGB(255, 70, 60)
			task.delay(0.2, function()
				reticleStroke.Color = Color3.fromRGB(255, 225, 40)
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
	showBanner("Caiu!", Color3.fromRGB(255, 90, 80))
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
	showBanner("De volta!", UIKit.MoneyGreen)
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
	}
	rider = {
		Pos = root.Position :: any,
		Vel = Vector3.new(0, RIDE.DIVE_UP, -RIDE.DIVE_FORWARD),
		Dist = Track.DistOf(root.Position.Z),
	}
	lastAreaIndex = 0
	camera.CameraType = Enum.CameraType.Scriptable
	gui.Enabled = true
	fallPanel.Visible = false
	state = "Airborne"
	-- o mergulho já leva direto ao primeiro peixe (garantido), para ninguém cair logo de cara
	local first = spawnFish(run.Fish[1])
	run.NextSpawn = 2
	harpoon(first, 1.1)
	showBanner("MERGULHO!", Color3.fromRGB(120, 230, 255))
end

endRun = function(reason)
	if state == "Idle" then
		return
	end
	state = "Idle"
	highlight.Parent = nil
	local count = run and run.Tamed or 0
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
		ClientState.Request("EndRun", reason)
	end)
	if count > 0 then
		ClientState.Toast(("Corrida terminada: %d peixe(s) domado(s)!"):format(count), "ok")
	elseif reason == "caiu" then
		ClientState.Toast("Treine na esteira para domar peixes mais fortes.", "info")
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
	local steer = moveX()
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
			showBanner("SALTO!", Color3.fromRGB(120, 230, 255))
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
	FishModel.Wag(obj.Model, t, 14)
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
					showBanner("O CASCO TE PROTEGEU!", Color3.fromRGB(120, 230, 255))
				else
					buck("Bateu!")
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
						showBanner("DOMADO!", UIKit.MoneyGreen)
					else
						buck("Escapou!")
					end
				end)
			end
		elseif elapsed >= rider.BuckAt then
			buck("Stamina baixa! Ele te derrubou")
			return
		end
	elseif rider.RideEnd and now >= rider.RideEnd then
		buck("O peixe cansou!")
		return
	end

	if obj.Dist > Track.LENGTH - 25 then
		ClientState.Toast("Você chegou ao fim! Novas áreas em breve.", "raro")
		endRun("fim")
	end
end

local function updateAirborne(realDt, dt)
	rider.Vel += Vector3.new(0, -RIDE.GRAVITY * dt, 0)
	local steer = moveX()
	-- o círculo anda rápido (no tempo real); o corpo vai indo atrás dele devagar
	local limitAim = Track.HALF_WIDTH - 5
	rider.AimX = math.clamp((rider.AimX or rider.Pos.X) + steer * RIDE.AIM_SPEED * realDt, -limitAim, limitAim)
	rider.AimAhead = math.clamp((rider.AimAhead or RIDE.AIM_START) + moveForward() * RIDE.AIM_SPEED * realDt, RIDE.AIM_MIN, RIDE.AIM_MAX)
	local drift = math.clamp(rider.AimX - rider.Pos.X, -1, 1) * RIDE.AIR_STEER_SPEED * 0.5
	local pos = rider.Pos + rider.Vel * dt + Vector3.new(drift * dt, 0, 0)
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
	local eased = 1 - (1 - p) ^ 2
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

-- Peixe dentro do círculo amarelo (com assistência de mira: o mais perto do centro, até
-- ASSIST_RADIUS de distância, e que o arpão alcance).
local function chooseTarget(now)
	local aimDist = rider.Dist + (rider.AimAhead or RIDE.AIM_START)
	local aimX = rider.AimX or rider.Pos.X
	local best, bestScore = nil, math.huge
	for _, obj in ipairs(run.Active) do
		if obj.Model and obj ~= rider.Mount and not obj.Escaped and now >= obj.TargetableAt then
			local offset = Vector2.new(obj.X - aimX, obj.Dist - aimDist).Magnitude
			if offset < RIDE.ASSIST_RADIUS and (obj.Root.Position - rider.Pos).Magnitude < RIDE.HARPOON_RANGE then
				if offset < bestScore then
					best, bestScore = obj, offset
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
	local aimDist = rider.Dist + (rider.AimAhead or RIDE.AIM_START)
	local aimPoint = Vector3.new(rider.AimX or rider.Pos.X, Track.SeabedY(aimDist) + SWIM + 2, Track.ZOf(aimDist))
	local goal = aimPoint
	if target and target.Model then
		goal = target.Root.Position
		-- assistência: o círculo "gruda" no peixe
		rider.AimX += (target.X - rider.AimX) * math.min(1, dt * 5)
		rider.AimAhead += ((target.Dist - rider.Dist) - rider.AimAhead) * math.min(1, dt * 5)
		reticleRing.BackgroundTransparency = 0.6
		reticleScale.Scale = 0.85 + math.sin(os.clock() * 12) * 0.08
	else
		reticleRing.BackgroundTransparency = 0.88
		reticleScale.Scale = 1
	end
	local current = reticleAnchor.Position
	reticleAnchor.CFrame = CFrame.new(current:Lerp(goal, math.min(1, dt * 14)))
end

local function updateHud(now)
	local area = Track.AreaAt(rider.Dist)
	areaLabel.Text = ("ÁREA %d • %s"):format(area.Index, area.Name)
	distLabel.Text = ("%d m  •  ⚡ %s  •  domados: %d"):format(math.max(0, math.floor(rider.Dist)), NumberFormat.Abbreviate(ClientState.Stat("Stamina")), run.Tamed)
	if area.Index ~= lastAreaIndex then
		if lastAreaIndex ~= 0 then
			showBanner(("ÁREA %d • %s"):format(area.Index, string.upper(area.Name)), area.Deco[1])
		end
		lastAreaIndex = area.Index
	end

	local obj = rider.Mount
	-- roda de stamina
	if state == "Riding" and obj then
		local fraction
		if obj.Tamed and rider.RideEnd then
			local start = rider.WheelAtTame or 1
			fraction = start * math.max(0, rider.RideEnd - now) / math.max(0.01, rider.RideTime)
		else
			local stamina = math.max(1, ClientState.Stat("Stamina"))
			local spent = obj.Required / obj.Species.TameTime * (now - rider.MountAt)
			fraction = 1 - spent / stamina
		end
		setWheel(fraction)
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
			tameStatus.Text = ("Domado! Fôlego: %.1fs — pule para o próximo"):format(left)
			tameStatus.TextColor3 = Color3.fromRGB(150, 210, 255)
		else
			local tameTime = obj.Species.TameTime
			tameFill.Size = UDim2.fromScale(math.clamp(elapsed / tameTime, 0, 1), 1)
			if rider.CanTame then
				tameGradient.Color = ColorSequence.new(UIKit.Colors.Green[1], UIKit.Colors.Green[2])
				buckMarker.Visible = false
				tameStatus.Text = ("Domando... %.1fs"):format(math.max(0, tameTime - elapsed))
				tameStatus.TextColor3 = UIKit.MoneyGreen
			else
				tameGradient.Color = ColorSequence.new(UIKit.Colors.Red[1], UIKit.Colors.Red[2])
				buckMarker.Visible = true
				buckMarker.Position = UDim2.new(math.clamp(rider.BuckAt / tameTime, 0, 1), -2, -0.13, 0)
				tameStatus.Text = ("Precisa de ⚡%s — ele vai te derrubar!"):format(NumberFormat.Abbreviate(obj.Required))
				tameStatus.TextColor3 = Color3.fromRGB(255, 120, 100)
			end
		end
	else
		tamePanel.Visible = false
	end

	jumpButton.Label.Text = state == "Airborne" and "ARPÃO" or "PULAR"
	if state == "Riding" and obj and not obj.Tamed and rider.CanTame then
		hint.Text = "Segure firme até domar!  •  A/D (ou analógico): desviar das pedras"
	elseif state == "Riding" then
		hint.Text = "ESPAÇO: saltar do peixe  •  A/D: desviar"
	elseif state == "Airborne" then
		hint.Text = target and "ESPAÇO: lançar o arpão!" or "Leve o círculo amarelo até um peixe (A/D e W/S)"
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
	end
	-- a câmera fica debaixo d'água (só sobe junto quando o peixe salta para fora)
	if focus.Y < Track.WATER_Y then
		eye = Vector3.new(eye.X, math.min(eye.Y, Track.WATER_Y - 1.5), eye.Z)
	end
	local desired = CFrame.lookAt(eye, look)
	camera.CFrame = camera.CFrame:Lerp(desired, 1 - math.exp(-dt * 8))
	local speed = state == "Riding" and currentSpeed() or 30
	camera.FieldOfView += ((68 + math.clamp(speed - 30, 0, 40) * 0.25) - camera.FieldOfView) * math.min(1, dt * 3)
end

local function updateFallen(now)
	placeRider(CFrame.new(rider.Pos) * CFrame.Angles(-math.pi / 2, 0, 0))
	if not rider.FallPanelShown and now - rider.FallAt >= RIDE.FALL_SHOW_TIME then
		rider.FallPanelShown = true
		fallPanel.Visible = true
		fallInfo.Text = ("Peixes domados nesta corrida: %d"):format(run.Tamed)
		reviveButton.Visible = reviveAvailable
		rider.ReviveDeadline = now + (reviveAvailable and RIDE.REVIVE_WINDOW or 2.5)
	end
	if rider.ReviveDeadline then
		local left = rider.ReviveDeadline - now
		fallCountdown.Text = ("Voltando para a praia em %d..."):format(math.max(0, math.ceil(left)))
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

	-- novos peixes à frente
	while run.Fish[run.NextSpawn] and run.Fish[run.NextSpawn].Dist < rider.Dist + RIDE.ACTIVATE_AHEAD do
		spawnFish(run.Fish[run.NextSpawn])
		run.NextSpawn += 1
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
	elseif state == "Fallen" then
		updateFallen(now)
	end
	if state == "Idle" or not run then
		return
	end

	-- alvo do arpão: só no ar, o peixe dentro do círculo
	if state == "Airborne" then
		target = chooseTarget(now)
	else
		target = nil
	end
	updateReticle(realDt)
	if target and target.Model then
		highlight.FillColor = stateColor(target.Required)
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
	if flat < Track.START_RADIUS and root.Position.Y < Track.WATER_Y + 1 then
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
