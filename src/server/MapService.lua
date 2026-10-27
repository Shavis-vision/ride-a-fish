-- MapService (ModuleScript)
-- Fica em: ServerScriptService > Server > MapService
--
-- Constrói o mapa inteiro por código, em peças com studs (estilo Lego), dentro de
-- Workspace > Map:
--   * a praia (areia, rampa para a água, paredões em degraus, coqueiros, guarda-sóis...);
--   * a água (superfície transparente) e a pista submarina com 3 áreas, paredes de recife,
--     obstáculos, decoração, portais de área e a parede de "em breve" no fim;
--   * a praça: barracas de VENDER PEIXES e AURAS, estátua, placar e a zona de mergulho;
--   * os 6 lotes (chão, cerca, aquário, esteira e placas de melhoria).
--
-- Se já existir um Workspace > Map (por exemplo, um mapa que você "congelou" no Studio),
-- ele é mantido e nada é construído de novo.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Brick = require(Shared:WaitForChild("Brick"))
local Track = require(Shared:WaitForChild("Track"))
local Layout = require(Shared:WaitForChild("Layout"))
local FishModel = require(Shared:WaitForChild("FishModel"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local MapService = {}

local FONT = Enum.Font.FredokaOne
local rgb = Color3.fromRGB

local SAND = rgb(238, 216, 156)
local SAND_DARK = rgb(222, 196, 132)
local WET_SAND = rgb(206, 180, 120)
local GRASS = rgb(110, 200, 70)
local WOOD = rgb(160, 108, 60)
local WOOD_DARK = rgb(110, 72, 40)
local WOOD_LIGHT = rgb(196, 146, 88)
local WHITE = rgb(248, 248, 248)
local STONE = rgb(120, 125, 135)

local PLOT_COLORS = {
	rgb(120, 190, 255),
	rgb(255, 150, 160),
	rgb(150, 230, 140),
	rgb(255, 205, 110),
	rgb(200, 160, 255),
	rgb(110, 225, 215),
}

-- Textos em placas -------------------------------------------------------------------------

local function stroke(label, thickness)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = rgb(20, 20, 30)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = label
	return s
end

-- Escreve texto numa face de uma peça. lines = { { Text, Color, Size (0-1 da altura) } }
local function surfaceText(part, face, lines, background, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- placas muito largas usam menos pixels por stud (o Roblox limita o tamanho da tela)
	gui.PixelsPerStud = pixelsPerStud or math.clamp(math.floor(3000 / math.max(part.Size.X, 1)), 10, 40)
	gui.LightInfluence = 0
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = background or rgb(30, 30, 40)
	frame.BackgroundTransparency = background and 0 or 1
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	for i, line in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.Name = line.Name or ("Line" .. i)
		label.LayoutOrder = i
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.94, line.Size or 0.3)
		label.Font = FONT
		label.Text = line.Text
		label.TextScaled = true
		label.TextColor3 = line.Color or WHITE
		label.Parent = frame
		stroke(label, line.Stroke or 4)
	end
	return gui
end

-- Texto grande flutuando (como "SELL DINOS" nas referências)
local function floatingTitle(parent, position, text, color, widthStuds)
	local anchor = Brick.Part(parent, {
		Name = "TitleAnchor",
		Size = Vector3.new(1, 1, 1),
		Position = position,
		Transparency = 1,
		CanCollide = false,
		Studs = false,
		CastShadow = false,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(widthStuds, 0, widthStuds * 0.22, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = gui
	stroke(label, 6)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Brick.Shade(color, 0.35), Brick.Shade(color, -0.15))
	gradient.Rotation = 90
	gradient.Parent = label
	return anchor
end

-- Iluminação de praia ensolarada ---------------------------------------------------------

-- A luz vem de Config.LIGHTING (preset escolhido em Config.LIGHTING_PRESET).
local function setupLighting()
	local preset = Config.LIGHTING[Config.LIGHTING_PRESET] or Config.LIGHTING.Antiga
	local function color(values)
		return rgb(values[1], values[2], values[3])
	end
	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = color(preset.Ambient)
	Lighting.OutdoorAmbient = color(preset.OutdoorAmbient)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 100000
	Lighting.FogStart = 0
	Lighting.FogColor = rgb(190, 225, 255)
	if preset.ShadowSoftness then
		Lighting.ShadowSoftness = preset.ShadowSoftness
	end
	if preset.LightingStyle then
		-- propriedade nova do Roblox; se a versão do Studio não tiver, segue sem ela
		pcall(function()
			Lighting.LightingStyle = Enum.LightingStyle[preset.LightingStyle]
		end)
	end

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = rgb(200, 230, 255)
	atmosphere.Decay = rgb(110, 160, 220)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting

	-- O céu: se você colocou um Sky em Lighting pelo Studio (ex.: o "anime sky" da Toolbox),
	-- ele é mantido do jeito que está. Só cria um céu padrão se não houver nenhum.
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SunAngularSize = 18
		sky.Parent = Lighting
	end

	local bloom = Lighting:FindFirstChild("MapBloom") or Instance.new("BloomEffect")
	bloom.Name = "MapBloom"
	bloom.Intensity = preset.BloomIntensity
	bloom.Size = preset.BloomSize
	bloom.Threshold = preset.BloomThreshold
	bloom.Parent = Lighting

	local correction = Lighting:FindFirstChild("MapCor")
	if preset.ColorCorrection then
		correction = correction or Instance.new("ColorCorrectionEffect")
		correction.Name = "MapCor"
		correction.Contrast = preset.ColorCorrection.Contrast
		correction.Saturation = preset.ColorCorrection.Saturation
		correction.TintColor = color(preset.ColorCorrection.Tint)
		correction.Parent = Lighting
	elseif correction then
		correction:Destroy()
	end
end

local function setupCollisionGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Barrier")
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Riders")
	end)
	PhysicsService:CollisionGroupSetCollidable("Barrier", "Riders", false)
end

-- Peças de cenário reutilizáveis ----------------------------------------------------------

local function palmTree(parent, base, height, lean, rng)
	local model = Brick.Model(parent, "Coqueiro")
	local segments = math.floor(height / 2)
	local pos = base
	for i = 1, segments do
		local t = i / segments
		local offset = Vector3.new(lean.X * t * t, 0, lean.Z * t * t)
		local color = (i % 2 == 0) and rgb(150, 100, 55) or rgb(125, 82, 45)
		local size = 1.9 - t * 0.5
		Brick.Part(model, {
			Size = Vector3.new(size, 2, size),
			Position = base + offset + Vector3.new(0, (i - 0.5) * 2, 0),
			Color = color,
		})
		pos = base + offset + Vector3.new(0, i * 2, 0)
	end
	-- cocos
	for i = 1, 3 do
		local angle = i * math.pi * 2 / 3
		Brick.Part(model, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.3, 1.3, 1.3),
			Position = pos + Vector3.new(math.cos(angle) * 0.9, -0.6, math.sin(angle) * 0.9),
			Color = rgb(110, 70, 35),
			Studs = false,
		})
	end
	-- folhas
	local leafColors = { rgb(70, 180, 60), rgb(95, 205, 75) }
	for i = 1, 7 do
		local angle = i * math.pi * 2 / 7 + rng:NextNumber(-0.15, 0.15)
		local pivot = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, angle, 0) * CFrame.Angles(-0.28, 0, 0)
		Brick.Part(model, {
			Size = Vector3.new(1.6, 0.4, 7),
			CFrame = pivot * CFrame.new(0, 0, -3.3),
			Color = leafColors[i % 2 + 1],
		})
		Brick.Part(model, {
			Size = Vector3.new(1.1, 0.4, 3.4),
			CFrame = pivot * CFrame.new(0, 0, -6.6) * CFrame.Angles(-0.55, 0, 0) * CFrame.new(0, 0, -1.4),
			Color = leafColors[(i + 1) % 2 + 1],
		})
	end
	return model
end

local function umbrella(parent, base, colorA, rng)
	local model = Brick.Model(parent, "GuardaSol")
	Brick.Part(model, { Size = Vector3.new(0.6, 10, 0.6), Position = base + Vector3.new(0, 5, 0), Color = WHITE, Studs = false })
	local tilt = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
	local top = CFrame.new(base + Vector3.new(0, 10, 0)) * tilt
	-- discos em camadas formam a cúpula
	local layers = { { 11, colorA }, { 8, WHITE }, { 5, colorA }, { 2.2, WHITE } }
	for i, layer in ipairs(layers) do
		Brick.Part(model, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, layer[1], layer[1]),
			CFrame = top * CFrame.new(0, (i - 1) * 0.45, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = layer[2],
			Studs = false,
			CanCollide = false,
		})
	end
	-- toalha
	local towel = Brick.Part(model, {
		Size = Vector3.new(4, 0.2, 7),
		CFrame = CFrame.new(base + Vector3.new(3.5, 0.1, 1)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
		Color = colorA,
		Studs = false,
		CanCollide = false,
	})
	for i = -1, 1, 2 do
		Brick.Part(model, {
			Size = Vector3.new(4.05, 0.22, 0.8),
			CFrame = towel.CFrame * CFrame.new(0, 0, i * 2.2),
			Color = WHITE,
			Studs = false,
			CanCollide = false,
		})
	end
	return model
end

local function rockCluster(parent, base, scale, color, rng)
	local model = Brick.Model(parent, "Pedras")
	local count = rng:NextInteger(2, 4)
	for i = 1, count do
		local size = Vector3.new(rng:NextNumber(2, 4.5), rng:NextNumber(1.5, 3.5), rng:NextNumber(2, 4.5)) * scale
		Brick.Part(model, {
			Size = size,
			CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-2, 2) * scale, size.Y / 2, rng:NextNumber(-2, 2) * scale))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = Brick.Shade(color, rng:NextNumber(-0.12, 0.12)),
		})
	end
	return model
end

local function sandcastle(parent, base)
	local model = Brick.Model(parent, "CasteloDeAreia")
	Brick.Part(model, { Size = Vector3.new(7, 2, 7), Position = base + Vector3.new(0, 1, 0), Color = SAND_DARK })
	for _, corner in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
		Brick.Part(model, { Size = Vector3.new(1.8, 4, 1.8), Position = base + Vector3.new(corner[1], 4, corner[2]), Color = SAND_DARK })
		Brick.Part(model, { Size = Vector3.new(2.2, 0.8, 2.2), Position = base + Vector3.new(corner[1], 6.4, corner[2]), Color = SAND })
	end
	Brick.Part(model, { Size = Vector3.new(3, 6, 3), Position = base + Vector3.new(0, 5, 0), Color = SAND })
	Brick.Part(model, { Size = Vector3.new(0.3, 3, 0.3), Position = base + Vector3.new(0, 9.5, 0), Color = WHITE, Studs = false })
	Brick.Part(model, { Size = Vector3.new(0.2, 1.2, 2), Position = base + Vector3.new(0, 10.4, 1), Color = rgb(255, 60, 60), Studs = false })
	return model
end

local function buoy(parent, position, color)
	local model = Brick.Model(parent, "Boia")
	Brick.Part(model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 2.6, 2.6),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		CanCollide = false,
	})
	Brick.Part(model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2.8, 2.8),
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = WHITE,
		CanCollide = false,
	})
	return model
end

-- Bonequinho estilo Lego (vendedores)
local function minifig(parent, cframe, shirt, hair)
	local model = Brick.Model(parent, "Vendedor")
	local yellow = rgb(255, 205, 40)
	local function part(size, offset, color, shape)
		return Brick.Part(model, { Size = size, CFrame = cframe * CFrame.new(offset), Color = color, Shape = shape, CanCollide = false })
	end
	part(Vector3.new(1.4, 2.6, 1.4), Vector3.new(-0.75, 1.3, 0), rgb(40, 70, 160))
	part(Vector3.new(1.4, 2.6, 1.4), Vector3.new(0.75, 1.3, 0), rgb(40, 70, 160))
	part(Vector3.new(3, 0.6, 1.5), Vector3.new(0, 2.9, 0), rgb(40, 70, 160))
	part(Vector3.new(3, 3, 1.5), Vector3.new(0, 4.7, 0), shirt)
	part(Vector3.new(0.9, 2.6, 1), Vector3.new(-1.95, 4.6, 0), shirt)
	part(Vector3.new(0.9, 2.6, 1), Vector3.new(1.95, 4.6, 0), shirt)
	part(Vector3.new(0.9, 0.8, 0.9), Vector3.new(-1.95, 3, 0), yellow)
	part(Vector3.new(0.9, 0.8, 0.9), Vector3.new(1.95, 3, 0), yellow)
	local head = part(Vector3.new(2.2, 2.4, 2.2), Vector3.new(0, 7.4, 0), yellow, Enum.PartType.Cylinder)
	head.CFrame = cframe * CFrame.new(0, 7.4, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	-- o cilindro está deitado: a "frente" do rosto fica na face Front da peça girada
	face.Parent = head
	part(Vector3.new(2.4, 0.9, 2.4), Vector3.new(0, 8.9, 0), hair)
	return model
end

-- Praia ------------------------------------------------------------------------------------

local function buildBeach(map)
	local folder = Brick.Folder(map, "Praia")
	local b = Layout.BEACH
	local top = Track.BEACH_Y

	-- areia principal e areia molhada perto da água
	Brick.Box(folder, Vector3.new(b.MinX, top - 8, 12), Vector3.new(b.MaxX, top, b.MaxZ + 80), { Name = "Areia", Color = SAND })
	Brick.Box(folder, Vector3.new(b.MinX, top - 8, 0), Vector3.new(b.MaxX, top, 12), { Name = "AreiaMolhada", Color = WET_SAND })

	-- rampa em degraus para dentro da água (a largura toda da praia)
	for i = 1, Track.SLOPE_STEPS do
		local seg = Track.Segments[i]
		local shade = Brick.Shade(WET_SAND, -0.03 * i)
		Brick.Box(
			folder,
			Vector3.new(b.MinX, seg.Y - 14, Track.ZOf(seg.D1)),
			Vector3.new(b.MaxX, seg.Y, Track.ZOf(seg.D0)),
			{ Name = "Rampa", Color = shade }
		)
	end

	-- plataforma rasa dos lados da pista (até onde a neblina deixa ver)
	local rng = Random.new(42)
	for side = -1, 1, 2 do
		local d = Track.SLOPE_END
		while d < 420 do
			local length = 40
			local y = math.floor(-13 - (d - Track.SLOPE_END) / 40 + rng:NextNumber(-1, 1))
			local x0 = side * (Track.HALF_WIDTH + 14)
			local x1 = side * (b.MaxX + 60)
			Brick.Box(folder, Vector3.new(math.min(x0, x1), y - 30, Track.ZOf(d + length)), Vector3.new(math.max(x0, x1), y, Track.ZOf(d)), {
				Name = "PlataformaRasa",
				Color = Brick.Shade(Track.Areas[1].Sand, -0.05 - 0.02 * ((d / 40) % 2)),
			})
			d += length
		end
	end

	-- paredões em degraus atrás da praia (estilo das referências: xadrez + grama em cima)
	local tiers = { { Z0 = b.MaxZ, Z1 = b.MaxZ + 16, H = 14 }, { Z0 = b.MaxZ + 16, Z1 = b.MaxZ + 34, H = 30 }, { Z0 = b.MaxZ + 34, Z1 = b.MaxZ + 60, H = 52 } }
	local checkA, checkB = rgb(232, 218, 178), rgb(212, 196, 152)
	for t, tier in ipairs(tiers) do
		local x = b.MinX - 80
		local index = 0
		while x < b.MaxX + 80 do
			local width = 20
			local h = tier.H + ((index * 7 + t * 3) % 3) * 2
			Brick.Box(folder, Vector3.new(x, top, tier.Z0), Vector3.new(x + width, top + h, tier.Z1), {
				Name = "Paredao",
				Color = (index + t) % 2 == 0 and checkA or checkB,
			})
			Brick.Box(folder, Vector3.new(x - 0.1, top + h, tier.Z0 - 0.1), Vector3.new(x + width + 0.1, top + h + 2, tier.Z1 + 0.1), {
				Name = "Grama",
				Color = (index % 2 == 0) and GRASS or Brick.Shade(GRASS, 0.12),
			})
			x += width
			index += 1
		end
	end

	-- paredões dos lados (entram um pouco na água)
	for side = -1, 1, 2 do
		local xInner = side * b.MaxX
		local spans = { { 0, 16 }, { 16, 34 }, { 34, 60 } }
		for t = 1, 3 do
			local x0 = xInner + side * spans[t][1]
			local x1 = xInner + side * spans[t][2]
			local z = -60
			local index = 0
			while z < b.MaxZ + 60 do
				local depth = 20
				local h = 12 + t * 14 + ((index * 5 + t) % 3) * 2
				local base = z < 0 and -40 or top
				Brick.Box(folder, Vector3.new(math.min(x0, x1), base, z), Vector3.new(math.max(x0, x1), top + h, z + depth), {
					Name = "Paredao",
					Color = (index + t) % 2 == 0 and checkA or checkB,
				})
				Brick.Box(
					folder,
					Vector3.new(math.min(x0, x1) - 0.1, top + h, z - 0.1),
					Vector3.new(math.max(x0, x1) + 0.1, top + h + 2, z + depth + 0.1),
					{ Name = "Grama", Color = (index % 2 == 0) and GRASS or Brick.Shade(GRASS, 0.12) }
				)
				z += depth
				index += 1
			end
		end
	end

	-- paredes invisíveis em volta da praia
	local function invisibleWall(minCorner, maxCorner)
		Brick.Box(folder, minCorner, maxCorner, { Name = "ParedeInvisivel", Transparency = 1, Studs = false, CastShadow = false })
	end
	invisibleWall(Vector3.new(b.MinX - 2, -60, -60), Vector3.new(b.MinX, 120, b.MaxZ + 10))
	invisibleWall(Vector3.new(b.MaxX, -60, -60), Vector3.new(b.MaxX + 2, 120, b.MaxZ + 10))
	invisibleWall(Vector3.new(b.MinX, top, b.MaxZ - 2), Vector3.new(b.MaxX, 120, b.MaxZ))

	-- barreira na água: só quem está correndo passa (grupo de colisão "Riders")
	local barrier = Brick.Box(
		folder,
		Vector3.new(b.MinX, -60, Track.ZOf(Track.BARRIER_DIST) - 1),
		Vector3.new(b.MaxX, 30, Track.ZOf(Track.BARRIER_DIST)),
		{ Name = "Barreira", Transparency = 1, Studs = false, CastShadow = false }
	)
	barrier.CollisionGroup = "Barrier"

	-- decoração da praia
	local deco = Brick.Folder(folder, "Decoracao")
	local palmSpots = {
		{ -60, 30 }, { 60, 30 }, { -64, 150 }, { 64, 150 }, { -140, 22 }, { 140, 22 }, { -222, 24 }, { 222, 24 },
		{ -300, 30 }, { 300, 30 }, { -144, 170 }, { 144, 170 }, { -224, 172 }, { 224, 172 }, { -304, 170 }, { 304, 170 },
		{ -20, 176 }, { 22, 182 },
	}
	for _, spot in ipairs(palmSpots) do
		local leanAngle = rng:NextNumber(0, math.pi * 2)
		palmTree(deco, Vector3.new(spot[1], top, spot[2]), rng:NextInteger(14, 20), Vector3.new(math.cos(leanAngle) * 3, 0, math.sin(leanAngle) * 3), rng)
	end
	local umbrellaColors = { rgb(255, 70, 70), rgb(60, 150, 255), rgb(255, 200, 40), rgb(80, 210, 110) }
	for i, x in ipairs({ -270, -205, -150, -95, 95, 150, 205, 270 }) do
		umbrella(deco, Vector3.new(x, top, 16 + (i % 2) * 6), umbrellaColors[i % 4 + 1], rng)
	end
	for _, spot in ipairs({ { -80, 12 }, { 80, 10 }, { -320, 60 }, { 320, 80 }, { -30, 190 }, { 40, 192 }, { -330, 150 }, { 330, 140 } }) do
		rockCluster(deco, Vector3.new(spot[1], top, spot[2]), 1.2, STONE, rng)
	end
	sandcastle(deco, Vector3.new(-120, top, 8))
	sandcastle(deco, Vector3.new(236, top, 8))

	-- torre de salva-vidas
	local tower = Brick.Model(deco, "SalvaVidas")
	local tbase = Vector3.new(66, top, 14)
	for _, c in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
		Brick.Part(tower, { Size = Vector3.new(1, 10, 1), Position = tbase + Vector3.new(c[1], 5, c[2]), Color = WHITE })
	end
	Brick.Part(tower, { Size = Vector3.new(8, 1, 8), Position = tbase + Vector3.new(0, 10.5, 0), Color = WOOD })
	Brick.Part(tower, { Size = Vector3.new(7, 5, 7), Position = tbase + Vector3.new(0, 13.5, 1), Color = rgb(230, 50, 50) })
	Brick.Part(tower, { Size = Vector3.new(8, 1, 8.4), Position = tbase + Vector3.new(0, 16.5, 1), Color = WHITE })
	for i = 0, 4 do
		Brick.Part(tower, { Size = Vector3.new(3, 0.4, 1), Position = tbase + Vector3.new(0, 1.5 + i * 2, -5 - i * 0.4), Color = WOOD_LIGHT })
	end

	-- passarela de madeira da praça até a água
	local walk = Brick.Folder(folder, "Passarela")
	for z = 4, 70, 2.2 do
		Brick.Part(walk, {
			Size = Vector3.new(14, 0.4, 2),
			Position = Vector3.new(0, top + 0.2, z),
			Color = (math.floor(z / 2.2) % 2 == 0) and WOOD_LIGHT or WOOD,
			Studs = false,
		})
	end

	-- texto "ZONA DE MERGULHO" no chão, perto da água
	local textPart = Brick.Part(folder, {
		Name = "TextoZona",
		Size = Vector3.new(44, 0.1, 9),
		Position = Vector3.new(0, top + 0.45, 3),
		Transparency = 1,
		CanCollide = false,
		Studs = false,
	})
	surfaceText(textPart, Enum.NormalId.Top, { { Text = "ZONA DE MERGULHO", Size = 0.9, Color = WHITE, Stroke = 6 } })

	-- arco de entrada sobre a água
	local arch = Brick.Model(folder, "ArcoMergulho")
	for side = -1, 1, 2 do
		for i = 0, 5 do
			Brick.Part(arch, {
				Size = Vector3.new(3, 3, 3),
				Position = Vector3.new(side * 20, top + 1.5 + i * 3, -2),
				Color = (i % 2 == 0) and rgb(255, 80, 80) or WHITE,
			})
		end
	end
	local beam = Brick.Part(arch, { Name = "Placa", Size = Vector3.new(44, 5, 2), Position = Vector3.new(0, top + 20.5, -2), Color = rgb(40, 150, 255) })
	surfaceText(beam, Enum.NormalId.Back, { { Text = "MERGULHE PARA COMEÇAR", Size = 0.8, Color = WHITE } })
	surfaceText(beam, Enum.NormalId.Front, { { Text = "BOA SORTE!", Size = 0.8, Color = WHITE } })

	-- boias marcando a faixa de mergulho
	for d = 4, Track.BARRIER_DIST, 7 do
		for side = -1, 1, 2 do
			buoy(folder, Vector3.new(side * 24, Track.WATER_Y + 0.4, Track.ZOf(d)), (math.floor(d / 7) % 2 == 0) and rgb(255, 60, 60) or rgb(255, 200, 40))
		end
	end

	-- anel da zona de mergulho (dentro da água rasa)
	local ring = Brick.Part(folder, {
		Name = "AnelMergulho",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, Track.START_RADIUS * 2, Track.START_RADIUS * 2),
		CFrame = CFrame.new(Layout.StartZone + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = rgb(60, 255, 230),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
		Studs = false,
	})
	ring:SetAttribute("StartZone", true)
	floatingTitle(folder, Vector3.new(0, Track.WATER_Y + 7, Track.ZOf(Track.START_DIST)), "MERGULHE ↓", rgb(80, 255, 230), 18)
end

-- Água e pista submarina ----------------------------------------------------------------

local function buildOcean(map)
	local folder = Brick.Folder(map, "Oceano")
	local b = Layout.BEACH

	-- superfície da água (transparente, com studs)
	Brick.Box(folder, Vector3.new(b.MinX - 120, Track.WATER_Y - 1, Track.ZOf(Track.LENGTH + 120)), Vector3.new(b.MaxX + 120, Track.WATER_Y, 4), {
		Name = "Agua",
		Color = rgb(40, 165, 255),
		Transparency = 0.42,
		Reflectance = 0.05,
		CanCollide = false,
		CastShadow = false,
	})
	-- espuma na beira
	Brick.Box(folder, Vector3.new(b.MinX, Track.WATER_Y, -1), Vector3.new(b.MaxX, Track.WATER_Y + 0.25, 2.5), {
		Name = "Espuma",
		Color = WHITE,
		Transparency = 0.25,
		CanCollide = false,
		CastShadow = false,
		Studs = false,
	})
	-- fundo escuro bem embaixo
	Brick.Box(folder, Vector3.new(-700, Track.DEEP_FLOOR_Y - 2, Track.ZOf(Track.LENGTH + 200)), Vector3.new(700, Track.DEEP_FLOOR_Y, 0), {
		Name = "FundoEscuro",
		Color = rgb(10, 25, 60),
		CanCollide = false,
		CastShadow = false,
	})

	-- fundo da pista: um bloco por degrau
	local floor = Brick.Folder(folder, "FundoPista")
	for i = Track.SLOPE_STEPS + 1, #Track.Segments do
		local seg = Track.Segments[i]
		local area = Track.AreaAt(seg.D0)
		Brick.Box(
			floor,
			Vector3.new(-Track.HALF_WIDTH - 16, seg.Y - 24, Track.ZOf(seg.D1)),
			Vector3.new(Track.HALF_WIDTH + 16, seg.Y, Track.ZOf(seg.D0)),
			{ Name = "Fundo", Color = Brick.Shade(area.Sand, (i % 2 == 0) and 0.04 or -0.03) }
		)
	end

	-- paredes de recife dos dois lados
	local walls = Brick.Folder(folder, "Recife")
	local rng = Random.new(1203)
	local d = Track.SLOPE_END
	local index = 0
	while d < Track.LENGTH + 30 do
		local chunk = 16
		local area = Track.AreaAt(d)
		local seabed = math.min(Track.SeabedY(d), Track.SeabedY(d + chunk - 0.1))
		for side = -1, 1, 2 do
			local heightAbove = 18 + ((index * 3 + (side > 0 and 1 or 0)) % 4) * 3 + rng:NextNumber(0, 4)
			local wallTop = math.min(Track.WATER_Y - 3, seabed + heightAbove)
			local x0 = side * Track.HALF_WIDTH
			local x1 = side * (Track.HALF_WIDTH + 14)
			local color = (index + (side > 0 and 1 or 0)) % 2 == 0 and area.Rock or Brick.Shade(area.Rock, 0.1)
			Brick.Box(walls, Vector3.new(math.min(x0, x1), seabed - 20, Track.ZOf(d + chunk)), Vector3.new(math.max(x0, x1), wallTop - 3, Track.ZOf(d)), {
				Name = "Parede",
				Color = color,
			})
			Brick.Box(
				walls,
				Vector3.new(math.min(x0, x1) - side * 1, wallTop - 3, Track.ZOf(d + chunk) + 0.5),
				Vector3.new(math.max(x0, x1) - side * 1, wallTop, Track.ZOf(d) - 0.5),
				{ Name = "Topo", Color = area.Rock2 }
			)
			-- degrauzinho para dentro (deixa a parede menos reta)
			if rng:NextNumber() < 0.5 then
				local inner = side * (Track.HALF_WIDTH - rng:NextNumber(2, 5))
				Brick.Box(
					walls,
					Vector3.new(math.min(inner, x0), seabed, Track.ZOf(d + chunk * 0.7)),
					Vector3.new(math.max(inner, x0), seabed + rng:NextNumber(3, 8), Track.ZOf(d + chunk * 0.2)),
					{ Name = "Degrau", Color = area.Rock2 }
				)
			end
		end
		d += chunk
		index += 1
	end

	-- obstáculos
	local obstacles = Brick.Folder(folder, "Obstaculos")
	for i, ob in ipairs(Track.Obstacles) do
		local area = Track.AreaAt(ob.Dist)
		local base = Vector3.new(ob.X, Track.SeabedY(ob.Dist), Track.ZOf(ob.Dist))
		local model = Brick.Model(obstacles, ob.Kind .. i)
		model:SetAttribute("Obstacle", true)
		model:SetAttribute("Radius", ob.Radius)
		local r = ob.Radius
		if ob.Kind == "Rocha" then
			local grey = area.Index == 3 and rgb(60, 55, 80) or rgb(125, 120, 130)
			Brick.Part(model, { Size = Vector3.new(r * 2, ob.Height * 0.55, r * 2), Position = base + Vector3.new(0, ob.Height * 0.275, 0), Color = grey })
			Brick.Part(model, {
				Size = Vector3.new(r * 1.5, ob.Height * 0.3, r * 1.4),
				Position = base + Vector3.new(r * 0.15, ob.Height * 0.7, -r * 0.1),
				Color = Brick.Shade(grey, 0.1),
			})
			Brick.Part(model, {
				Size = Vector3.new(r * 0.9, ob.Height * 0.15, r * 0.9),
				Position = base + Vector3.new(-r * 0.1, ob.Height * 0.925, 0),
				Color = Brick.Shade(grey, 0.2),
			})
		elseif ob.Kind == "Coral" then
			local color = area.Deco[(i % #area.Deco) + 1]
			Brick.Part(model, { Size = Vector3.new(r * 1.6, 2, r * 1.6), Position = base + Vector3.new(0, 1, 0), Color = rgb(150, 140, 150) })
			Brick.Part(model, { Size = Vector3.new(1.6, ob.Height, 1.6), Position = base + Vector3.new(0, ob.Height / 2 + 1, 0), Color = color })
			for k = 1, 4 do
				local angle = k * math.pi / 2 + i
				local h = ob.Height * (0.45 + 0.1 * k)
				local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (r * 0.55)
				Brick.Part(model, { Size = Vector3.new(1.2, h * 0.5, 1.2), Position = base + out + Vector3.new(0, h * 0.75, 0), Color = color })
				Brick.Part(model, { Size = Vector3.new(r * 0.55, 1.2, 1.2), CFrame = CFrame.new(base + out * 0.5 + Vector3.new(0, h * 0.5, 0)) * CFrame.Angles(0, -angle, 0), Color = color })
			end
		elseif ob.Kind == "Alga" then
			for k = 1, 3 do
				local offset = Vector3.new(math.cos(k * 2.1) * r * 0.5, 0, math.sin(k * 2.1) * r * 0.5)
				local h = ob.Height * (0.75 + 0.12 * k)
				local blocks = math.floor(h / 2)
				for j = 1, blocks do
					Brick.Part(model, {
						Size = Vector3.new(1.2, 2, 1.2),
						Position = base + offset + Vector3.new(math.sin(j * 0.6 + k) * 0.6, j * 2 - 1, 0),
						Color = (j % 2 == 0) and rgb(60, 170, 70) or rgb(90, 200, 80),
					})
					if j % 3 == 0 then
						Brick.Part(model, {
							Class = "WedgePart",
							Size = Vector3.new(0.4, 1.4, 2.2),
							CFrame = CFrame.new(base + offset + Vector3.new(0.8, j * 2 - 1, 0)) * CFrame.Angles(0, (j % 2) * math.pi, 0),
							Color = rgb(130, 220, 90),
						})
					end
				end
			end
		else -- Cristal
			local color = area.Deco[(i % #area.Deco) + 1]
			Brick.Part(model, { Size = Vector3.new(r * 1.8, 2, r * 1.8), Position = base + Vector3.new(0, 1, 0), Color = area.Rock2 })
			for k = 1, 4 do
				local h = ob.Height * (0.5 + k * 0.12)
				local crystal = Brick.Part(model, {
					Size = Vector3.new(1.6, h, 1.6),
					CFrame = CFrame.new(base + Vector3.new(math.cos(k * 1.7) * r * 0.4, h / 2 + 1, math.sin(k * 1.7) * r * 0.4))
						* CFrame.Angles(math.cos(k) * 0.25, k, math.sin(k) * 0.25),
					Color = color,
					Material = Enum.Material.Neon,
					Transparency = 0.15,
					Studs = false,
				})
				if k == 1 then
					local light = Instance.new("PointLight")
					light.Color = color
					light.Range = 22
					light.Brightness = 2
					light.Parent = crystal
				end
			end
		end
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = false
			end
		end
	end

	-- decoração do fundo (sem colisão): corais pequenos, estrelas, conchas, capim
	local deco = Brick.Folder(folder, "Decoracao")
	local drng = Random.new(77)
	local dd = 52
	while dd < Track.LENGTH do
		dd += drng:NextNumber(5, 10)
		local area = Track.AreaAt(dd)
		local side = drng:NextNumber() < 0.5 and -1 or 1
		local x = side * drng:NextNumber(Track.HALF_WIDTH - 9, Track.HALF_WIDTH - 1)
		if drng:NextNumber() < 0.25 then
			x = drng:NextNumber(-Track.HALF_WIDTH + 4, Track.HALF_WIDTH - 4)
		end
		local base = Vector3.new(x, Track.SeabedY(dd), Track.ZOf(dd))
		local roll = drng:NextNumber()
		local color = area.Deco[drng:NextInteger(1, #area.Deco)]
		if roll < 0.3 then
			-- tufo de capim/alga baixinha
			for k = 1, 3 do
				local h = drng:NextNumber(1.5, 4) * (area.Index == 2 and 2 or 1)
				Brick.Part(deco, {
					Size = Vector3.new(0.6, h, 0.6),
					Position = base + Vector3.new(k * 0.7 - 1.4, h / 2, drng:NextNumber(-0.6, 0.6)),
					Color = area.Index == 3 and color or rgb(70, 180, 70),
					Material = area.Index == 3 and Enum.Material.Neon or Enum.Material.Plastic,
					CanCollide = false,
				})
			end
		elseif roll < 0.5 then
			-- estrela-do-mar
			for k = 0, 1 do
				Brick.Part(deco, {
					Size = Vector3.new(3, 0.4, 0.8),
					CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, k * math.pi / 2 + 0.4, 0),
					Color = rgb(255, 120, 60),
					CanCollide = false,
				})
			end
		elseif roll < 0.65 then
			-- concha
			Brick.Part(deco, {
				Class = "WedgePart",
				Size = Vector3.new(1.6, 0.8, 1.4),
				Position = base + Vector3.new(0, 0.4, 0),
				Color = rgb(255, 225, 230),
				CanCollide = false,
			})
		else
			-- coral pequeno em blocos
			local h = drng:NextNumber(2, 5)
			Brick.Part(deco, { Size = Vector3.new(2, h, 2), Position = base + Vector3.new(0, h / 2, 0), Color = color, CanCollide = false })
			Brick.Part(deco, { Size = Vector3.new(1.2, h * 0.6, 1.2), Position = base + Vector3.new(1.4, h * 0.3, 0.6), Color = Brick.Shade(color, 0.2), CanCollide = false })
		end
	end

	-- algas altas junto às paredes da Floresta de Algas
	local krng = Random.new(5)
	local kelpArea = Track.Areas[2]
	local kd = kelpArea.Start + 10
	while kd < kelpArea.Finish - 10 do
		kd += krng:NextNumber(6, 12)
		for side = -1, 1, 2 do
			if krng:NextNumber() < 0.7 then
				local x = side * krng:NextNumber(Track.HALF_WIDTH - 6, Track.HALF_WIDTH - 2)
				local base = Vector3.new(x, Track.SeabedY(kd), Track.ZOf(kd))
				local blocks = krng:NextInteger(8, 16)
				for j = 1, blocks do
					Brick.Part(deco, {
						Size = Vector3.new(1, 2, 1),
						Position = base + Vector3.new(math.sin(j * 0.5 + kd) * 0.7, j * 2 - 1, 0),
						Color = (j % 2 == 0) and rgb(50, 150, 60) or rgb(80, 185, 70),
						CanCollide = false,
					})
				end
			end
		end
	end

	-- raios de luz no Recife Raso
	local lrng = Random.new(9)
	for _ = 1, 28 do
		local dist = lrng:NextNumber(60, Track.Areas[1].Finish - 20)
		local x = lrng:NextNumber(-35, 35)
		local seabed = Track.SeabedY(dist)
		local height = Track.WATER_Y - seabed
		Brick.Part(deco, {
			Name = "RaioDeLuz",
			Size = Vector3.new(lrng:NextNumber(4, 8), height, lrng:NextNumber(2, 4)),
			CFrame = CFrame.new(x, seabed + height / 2, Track.ZOf(dist)) * CFrame.Angles(0.25, lrng:NextNumber(-0.4, 0.4), 0.2),
			Color = rgb(220, 250, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.88,
			CanCollide = false,
			CastShadow = false,
			Studs = false,
		})
	end

	-- portais das áreas
	local gates = Brick.Folder(folder, "Portais")
	for _, area in ipairs(Track.Areas) do
		if area.Index == 1 then
			continue -- a área 1 já tem o arco "MERGULHE PARA COMEÇAR" na praia
		end
		local dist = area.Start
		local seabed = Track.SeabedY(dist)
		local z = Track.ZOf(dist)
		local gate = Brick.Model(gates, "Portal" .. area.Index)
		local height = 26
		for side = -1, 1, 2 do
			for j = 0, math.floor(height / 4) - 1 do
				Brick.Part(gate, {
					Size = Vector3.new(4, 4, 4),
					Position = Vector3.new(side * (Track.HALF_WIDTH - 3), seabed + 2 + j * 4, z),
					Color = (j % 2 == 0) and area.Rock2 or Brick.Shade(area.Rock2, -0.2),
					CanCollide = false,
				})
			end
		end
		local board = Brick.Part(gate, {
			Name = "Placa",
			Size = Vector3.new(Track.HALF_WIDTH * 2 - 2, 7, 1.5),
			Position = Vector3.new(0, seabed + height + 1.5, z),
			Color = rgb(25, 30, 50),
			CanCollide = false,
		})
		surfaceText(board, Enum.NormalId.Back, {
			{ Text = ("ÁREA %d • %s"):format(area.Index, string.upper(area.Name)), Size = 0.55, Color = area.Deco[1] },
			{ Text = "⚡ " .. NumberFormat.Abbreviate(area.Recommended) .. " recomendado", Size = 0.35, Color = WHITE },
		})
	end

	-- parede do fim
	local endZ = Track.ZOf(Track.LENGTH)
	local endWall = Brick.Box(folder, Vector3.new(-Track.HALF_WIDTH - 14, Track.SeabedY(Track.LENGTH) - 20, endZ - 6), Vector3.new(Track.HALF_WIDTH + 14, Track.WATER_Y - 3, endZ), {
		Name = "ParedeFim",
		Color = Track.Areas[3].Rock,
		CanCollide = false,
	})
	local endSign = Brick.Part(folder, {
		Name = "PlacaFim",
		Size = Vector3.new(60, 12, 1),
		Position = Vector3.new(0, Track.SeabedY(Track.LENGTH) + 20, endZ + 0.6),
		Color = rgb(20, 20, 35),
		CanCollide = false,
	})
	surfaceText(endSign, Enum.NormalId.Back, {
		{ Text = "EM BREVE", Size = 0.5, Color = rgb(255, 220, 60) },
		{ Text = "novas áreas e peixes", Size = 0.3, Color = WHITE },
	})
	endWall:SetAttribute("TrackEnd", true)
end

-- Praça: barracas, estátua e placar ------------------------------------------------------

local function stall(parent, position, title, titleColor, stripeColor, shirt)
	local model = Brick.Model(parent, title)
	local cf = CFrame.new(position)

	-- balcão
	Brick.Part(model, { Name = "Balcao", Size = Vector3.new(20, 4, 4), CFrame = cf * CFrame.new(0, 2, -4), Color = WOOD })
	Brick.Part(model, { Size = Vector3.new(21, 0.8, 5), CFrame = cf * CFrame.new(0, 4.4, -4), Color = WOOD_LIGHT })
	-- frente do balcão com tábuas alternadas
	for i = -4, 4 do
		Brick.Part(model, {
			Size = Vector3.new(2, 3.6, 0.3),
			CFrame = cf * CFrame.new(i * 2.2, 2, -6.1),
			Color = (i % 2 == 0) and WOOD_DARK or WOOD,
			Studs = false,
		})
	end
	-- postes e fundo
	for _, c in ipairs({ { -9.5, -5.5 }, { 9.5, -5.5 }, { -9.5, 5.5 }, { 9.5, 5.5 } }) do
		Brick.Part(model, { Size = Vector3.new(1.4, 13, 1.4), CFrame = cf * CFrame.new(c[1], 6.5, c[2]), Color = WOOD_DARK })
	end
	Brick.Part(model, { Size = Vector3.new(20, 10, 1), CFrame = cf * CFrame.new(0, 5, 6), Color = WOOD_LIGHT })

	-- toldo em arco com listras
	local radius, yc, stripes = 7, 12.5, 9
	local stripeWidth = 22 / stripes
	local steps = 8
	for s = 0, stripes - 1 do
		local x = -11 + stripeWidth * (s + 0.5)
		local color = (s % 2 == 0) and stripeColor or WHITE
		for k = 0, steps - 1 do
			local a0 = math.pi * k / steps
			local a1 = math.pi * (k + 1) / steps
			local am = (a0 + a1) / 2
			local center = Vector3.new(x, yc + radius * math.sin(am), -radius * math.cos(am))
			local tangent = Vector3.new(0, math.cos(am), math.sin(am))
			local normal = Vector3.new(0, math.sin(am), -math.cos(am))
			local length = 2 * radius * math.sin((a1 - a0) / 2) + 0.15
			Brick.Part(model, {
				Size = Vector3.new(stripeWidth + 0.02, 0.6, length),
				CFrame = cf * CFrame.lookAt(center, center + tangent, normal),
				Color = color,
				CanCollide = false,
			})
		end
	end

	minifig(model, cf * CFrame.new(0, 0, 1.5), shirt, rgb(90, 50, 30))
	floatingTitle(model, position + Vector3.new(0, 24, 0), title, titleColor, 26)
	return model
end

local function shopRing(parent, ring)
	local model = Brick.Model(parent, "Anel" .. ring.Shop)
	Brick.Part(model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, ring.Radius * 2, ring.Radius * 2),
		CFrame = CFrame.new(ring.Position + Vector3.new(0, 0.52, 0)) * CFrame.Angles(0, 0, math.pi / 2), -- acima do piso da praça
		Color = ring.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
		Studs = false,
	})
	Brick.Part(model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, ring.Radius * 2 - 1.4, ring.Radius * 2 - 1.4),
		CFrame = CFrame.new(ring.Position + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Brick.Shade(ring.Color, 0.55),
		Transparency = 0.55,
		CanCollide = false,
		Studs = false,
	})
end

local function buildPlaza(map)
	local folder = Brick.Folder(map, "Praca")
	local top = Track.BEACH_Y

	-- piso da praça (placas brancas e azuis)
	for gx = -5, 4 do
		for gz = 0, 8 do
			Brick.Part(folder, {
				Name = "Piso",
				Size = Vector3.new(10, 0.4, 10),
				Position = Vector3.new(gx * 10 + 5, top + 0.2, 64 + gz * 10),
				Color = ((gx + gz) % 2 == 0) and rgb(245, 240, 225) or rgb(200, 225, 245),
			})
		end
	end

	-- barraca de vender peixes (com peixes no balcão)
	local sell = stall(folder, Layout.SellStall + Vector3.new(0, 0.4, 0), "VENDER PEIXES", rgb(255, 70, 70), rgb(230, 40, 40), rgb(230, 60, 60))
	for i, id in ipairs({ "palhaco", "cirurgiao", "baiacu" }) do
		local fish = FishModel.Build(id, "Normal", "Normal", { Saddle = false, Scale = 0.45 })
		fish:PivotTo(CFrame.new(Layout.SellStall + Vector3.new(-6 + i * 3.5, 5.6, -4)) * CFrame.Angles(0, math.pi / 2, 0))
		fish.Parent = sell
	end

	-- barraca das auras (com esferas brilhando)
	local aura = stall(folder, Layout.AuraStall + Vector3.new(0, 0.4, 0), "AURAS", rgb(200, 90, 255), rgb(160, 60, 230), rgb(150, 80, 220))
	for i, c in ipairs({ rgb(160, 230, 255), rgb(255, 120, 140), rgb(230, 120, 255) }) do
		local orb = Brick.Part(aura, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.8, 1.8, 1.8),
			Position = Layout.AuraStall + Vector3.new(-6 + i * 3.5, 6.3, -4),
			Color = c,
			Material = Enum.Material.Neon,
			Studs = false,
		})
		local light = Instance.new("PointLight")
		light.Color = c
		light.Range = 8
		light.Parent = orb
	end

	for _, ring in ipairs(Layout.ShopRings) do
		shopRing(folder, ring)
	end

	-- estátua de peixe com fonte
	local statue = Brick.Model(folder, "Estatua")
	local sp = Layout.Statue
	Brick.Part(statue, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 22, 22),
		CFrame = CFrame.new(sp + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = rgb(235, 235, 240),
	})
	Brick.Part(statue, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 19, 19),
		CFrame = CFrame.new(sp + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = rgb(60, 170, 255),
		Transparency = 0.3,
		CanCollide = false,
	})
	Brick.Part(statue, { Size = Vector3.new(5, 7, 5), Position = sp + Vector3.new(0, 5.5, 0), Color = rgb(225, 225, 230) })
	local big = FishModel.Build("voador", "Dourado", "Normal", { Saddle = true, Scale = 2.2 })
	big:PivotTo(CFrame.new(sp + Vector3.new(0, 15, 0)) * CFrame.Angles(0.35, math.pi * 0.8, 0))
	big.Parent = statue

	-- spawn geral
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPraca"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(Layout.LobbySpawn)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	-- placar
	local board = Brick.Model(folder, "Placar")
	local lp = Layout.Leaderboard
	for side = -1, 1, 2 do
		Brick.Part(board, { Size = Vector3.new(2.4, 26, 2.4), Position = lp + Vector3.new(side * 16, 13, 0), Color = rgb(40, 45, 55) })
	end
	Brick.Part(board, { Size = Vector3.new(34, 2, 3), Position = lp + Vector3.new(0, 27, 0), Color = GRASS })
	local screen = Brick.Part(board, { Name = "Tela", Size = Vector3.new(30, 20, 1.2), Position = lp + Vector3.new(0, 15.5, 0), Color = rgb(25, 28, 36) })
	for i = -2, 2 do
		Brick.Part(board, { Size = Vector3.new(2, 2, 2), Position = lp + Vector3.new(i * 3, 29, 0), Color = rgb(255, 210, 40) })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = screen
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.16)
	title.BackgroundTransparency = 1
	title.Font = FONT
	title.Text = "TOP RENDA"
	title.TextScaled = true
	title.TextColor3 = rgb(255, 220, 60)
	title.Parent = gui
	stroke(title, 4)
	local list = Instance.new("Frame")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.04, 0.18)
	list.Size = UDim2.fromScale(0.92, 0.8)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
end

-- Lotes ------------------------------------------------------------------------------------

local function buildPlot(parent, plot)
	local model = Brick.Model(parent, "Lote" .. plot.Index)
	model:SetAttribute("PlotIndex", plot.Index)
	local accent = PLOT_COLORS[plot.Index] or PLOT_COLORS[1]
	local c = plot.Center
	local floorTop = c.Y + 1
	local half = Layout.PLOT_SIZE / 2

	-- chão em xadrez da cor do lote
	local tiles = 6
	local tileX = Layout.PLOT_SIZE.X / tiles
	local tileZ = Layout.PLOT_SIZE.Z / 8
	for ix = 0, tiles - 1 do
		for iz = 0, 7 do
			Brick.Part(model, {
				Name = "Chao",
				Size = Vector3.new(tileX, 1, tileZ),
				Position = Vector3.new(c.X - half.X + tileX * (ix + 0.5), c.Y + 0.5, c.Z - half.Z + tileZ * (iz + 0.5)),
				Color = ((ix + iz) % 2 == 0) and accent or Brick.Shade(accent, 0.25),
			})
		end
	end
	-- borda branca
	for _, edge in ipairs({ { -1, 0 }, { 1, 0 }, { 0, 1 } }) do
		local size = edge[2] == 0 and Vector3.new(1.4, 1.4, Layout.PLOT_SIZE.Z) or Vector3.new(Layout.PLOT_SIZE.X + 1.4, 1.4, 1.4)
		Brick.Part(model, {
			Name = "Borda",
			Size = size,
			Position = Vector3.new(c.X + edge[1] * half.X, floorTop + 0.2, c.Z + edge[2] * half.Z),
			Color = WHITE,
		})
	end
	-- cerca de madeira (lados e fundo), frente aberta
	local function fenceLine(from, to)
		local delta = to - from
		local length = delta.Magnitude
		local count = math.floor(length / 6)
		for i = 0, count do
			local p = from + delta * (i / count)
			Brick.Part(model, { Name = "Poste", Size = Vector3.new(1, 5, 1), Position = p + Vector3.new(0, 2.5, 0), Color = WOOD_DARK })
		end
		for _, h in ipairs({ 2, 4 }) do
			Brick.Part(model, {
				Name = "Trilho",
				Size = Vector3.new(0.5, 0.7, length),
				CFrame = CFrame.lookAt(from + delta / 2 + Vector3.new(0, h, 0), to + Vector3.new(0, h, 0)),
				Color = (h == 2) and WOOD or WHITE,
				Studs = false,
			})
		end
	end
	local y = floorTop + 0.9
	fenceLine(Vector3.new(c.X - half.X, y, c.Z - half.Z + 14), Vector3.new(c.X - half.X, y, c.Z + half.Z))
	fenceLine(Vector3.new(c.X + half.X, y, c.Z - half.Z + 14), Vector3.new(c.X + half.X, y, c.Z + half.Z))
	fenceLine(Vector3.new(c.X - half.X, y, c.Z + half.Z), Vector3.new(c.X + half.X, y, c.Z + half.Z))

	-- AQUÁRIO -----------------------------------------------------------------
	local aq = Brick.Model(model, "Aquario")
	local a = plot.Aquarium
	local aBase = Vector3.new(a.X, floorTop, a.Z)
	local width, depth, tall = 46, 18, 20
	Brick.Part(aq, { Name = "Armario", Size = Vector3.new(width + 2, 4, depth + 2), Position = aBase + Vector3.new(0, 2, 0), Color = WOOD_DARK })
	for i = -5, 5 do
		Brick.Part(aq, {
			Size = Vector3.new(3.6, 3, 0.3),
			Position = aBase + Vector3.new(i * 4.2, 2, -depth / 2 - 1.1),
			Color = (i % 2 == 0) and WOOD or WOOD_LIGHT,
			Studs = false,
		})
	end
	local inner = aBase + Vector3.new(0, 4, 0)
	-- fundo pintado de oceano (opaco) e areia
	Brick.Part(aq, { Name = "FundoAquario", Size = Vector3.new(width, tall, 0.8), Position = inner + Vector3.new(0, tall / 2, depth / 2 - 0.4), Color = rgb(30, 110, 200) })
	Brick.Part(aq, { Size = Vector3.new(width, tall * 0.4, 0.9), Position = inner + Vector3.new(0, tall * 0.2, depth / 2 - 0.45), Color = rgb(20, 85, 170) })
	Brick.Part(aq, { Name = "AreiaAquario", Size = Vector3.new(width, 1.2, depth), Position = inner + Vector3.new(0, 0.6, 0), Color = SAND })
	-- vidros
	local glass = { Color = rgb(190, 235, 255), Transparency = 0.72, Reflectance = 0.08, Studs = false }
	local function glassPart(size, pos, name)
		local props = table.clone(glass)
		props.Size = size
		props.Position = pos
		props.Name = name
		Brick.Part(aq, props)
	end
	glassPart(Vector3.new(width, tall, 0.4), inner + Vector3.new(0, tall / 2, -depth / 2 + 0.2), "VidroFrente")
	glassPart(Vector3.new(0.4, tall, depth), inner + Vector3.new(-width / 2 + 0.2, tall / 2, 0), "VidroLado")
	glassPart(Vector3.new(0.4, tall, depth), inner + Vector3.new(width / 2 - 0.2, tall / 2, 0), "VidroLado")
	-- água dentro
	Brick.Part(aq, {
		Name = "AguaAquario",
		Size = Vector3.new(width - 1, tall - 3, depth - 1.6),
		Position = inner + Vector3.new(0, 1.2 + (tall - 3) / 2, 0),
		Color = rgb(70, 180, 255),
		Transparency = 0.82,
		CanCollide = false,
		CastShadow = false,
	})
	-- moldura
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			Brick.Part(aq, { Size = Vector3.new(1, tall + 1, 1), Position = inner + Vector3.new(sx * width / 2, tall / 2, sz * depth / 2), Color = rgb(30, 35, 45) })
		end
	end
	Brick.Part(aq, { Size = Vector3.new(width + 1, 1, 1), Position = inner + Vector3.new(0, tall, -depth / 2), Color = rgb(30, 35, 45) })
	Brick.Part(aq, { Size = Vector3.new(width + 1, 1, 1), Position = inner + Vector3.new(0, tall, depth / 2), Color = rgb(30, 35, 45) })
	Brick.Part(aq, { Size = Vector3.new(1, 1, depth), Position = inner + Vector3.new(-width / 2, tall, 0), Color = rgb(30, 35, 45) })
	Brick.Part(aq, { Size = Vector3.new(1, 1, depth), Position = inner + Vector3.new(width / 2, tall, 0), Color = rgb(30, 35, 45) })
	local lamp = Brick.Part(aq, { Size = Vector3.new(width - 4, 0.6, 1.2), Position = inner + Vector3.new(0, tall + 0.6, depth / 2 - 2), Color = WHITE, Material = Enum.Material.Neon })
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 20
	light.Brightness = 1.2
	light.Angle = 120
	light.Color = rgb(200, 240, 255)
	light.Parent = lamp
	-- decoração dentro: corais e um castelinho
	local drng = Random.new(plot.Index * 13)
	for i = 1, 7 do
		local x = -width / 2 + 3 + (i - 1) * (width - 6) / 6
		local h = drng:NextNumber(1.5, 4)
		Brick.Part(aq, {
			Size = Vector3.new(1.4, h, 1.4),
			Position = inner + Vector3.new(x, 1.2 + h / 2, depth / 2 - 3),
			Color = Track.Areas[1].Deco[(i % 4) + 1],
			CanCollide = false,
		})
	end
	Brick.Part(aq, { Size = Vector3.new(3, 3, 3), Position = inner + Vector3.new(width / 2 - 4, 2.7, depth / 2 - 4), Color = rgb(180, 180, 190), CanCollide = false })
	Brick.Part(aq, { Size = Vector3.new(1.2, 2, 1.2), Position = inner + Vector3.new(width / 2 - 4, 5.2, depth / 2 - 4), Color = rgb(200, 200, 210), CanCollide = false })
	local bubbles = Brick.Part(aq, {
		Name = "Bolhas",
		Size = Vector3.new(width - 4, 0.2, 2),
		Position = inner + Vector3.new(0, 1.4, 0),
		Transparency = 1,
		CanCollide = false,
		Studs = false,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(2.5, 3.5)
	emitter.Speed = NumberRange.new(4, 6)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new(0.35)
	emitter.Transparency = NumberSequence.new(0.3)
	emitter.LightEmission = 0.4
	emitter.Color = ColorSequence.new(rgb(220, 245, 255))
	emitter.Parent = bubbles

	-- onde os peixes ficam (PlotService põe os modelos aqui)
	local display = Brick.Folder(aq, "Peixes")
	display:SetAttribute("Origin", inner)

	-- nome do dono em cima do aquário
	local nameAnchor = Brick.Part(aq, {
		Name = "NomeDono",
		Size = Vector3.new(1, 1, 1),
		Position = inner + Vector3.new(0, tall + 8, 0),
		Transparency = 1,
		CanCollide = false,
		Studs = false,
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Gui"
	billboard.Size = UDim2.new(30, 0, 9, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 300
	billboard.Parent = nameAnchor
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Size = UDim2.fromScale(0.3, 0.5)
	avatar.SizeConstraint = Enum.SizeConstraint.RelativeYY
	avatar.Position = UDim2.fromScale(0.5, 0)
	avatar.AnchorPoint = Vector2.new(0.5, 0)
	avatar.BackgroundColor3 = rgb(30, 30, 40)
	avatar.Image = ""
	avatar.Parent = billboard
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatar
	local owner = Instance.new("TextLabel")
	owner.Name = "Owner"
	owner.Size = UDim2.fromScale(1, 0.28)
	owner.Position = UDim2.fromScale(0, 0.5)
	owner.BackgroundTransparency = 1
	owner.Font = FONT
	owner.Text = "Lote livre"
	owner.TextScaled = true
	owner.TextColor3 = WHITE
	owner.Parent = billboard
	stroke(owner, 3)
	local income = Instance.new("TextLabel")
	income.Name = "Income"
	income.Size = UDim2.fromScale(1, 0.22)
	income.Position = UDim2.fromScale(0, 0.78)
	income.BackgroundTransparency = 1
	income.Font = FONT
	income.Text = ""
	income.TextScaled = true
	income.TextColor3 = rgb(90, 255, 90)
	income.Parent = billboard
	stroke(income, 3)

	-- ESTEIRA -----------------------------------------------------------------
	local tm = Brick.Model(model, "Esteira")
	local t = Vector3.new(plot.Treadmill.X, floorTop, plot.Treadmill.Z)
	Brick.Part(tm, { Name = "Base", Size = Vector3.new(9, 1.4, 17), Position = t + Vector3.new(0, 0.7, 0), Color = rgb(50, 55, 65) })
	Brick.Part(tm, { Name = "Esteirinha", Size = Vector3.new(6.6, 0.3, 15.6), Position = t + Vector3.new(0, 1.55, 0), Color = rgb(25, 25, 30), Studs = false })
	local stripes = Brick.Folder(tm, "Listras")
	for i = 0, 7 do
		Brick.Part(stripes, {
			Name = "Listra",
			Size = Vector3.new(6.4, 0.32, 0.5),
			Position = t + Vector3.new(0, 1.58, -7.5 + i * 2),
			Color = rgb(70, 70, 80),
			CanCollide = false,
			Studs = false,
		})
	end
	for side = -1, 1, 2 do
		Brick.Part(tm, { Size = Vector3.new(1, 0.9, 17), Position = t + Vector3.new(side * 4.4, 1.85, 0), Color = accent })
		Brick.Part(tm, { Size = Vector3.new(0.8, 5.5, 0.8), Position = t + Vector3.new(side * 3.9, 4.1, 7), Color = rgb(200, 205, 215), Studs = false })
		Brick.Part(tm, { Size = Vector3.new(0.6, 0.6, 6), Position = t + Vector3.new(side * 3.9, 5.6, 4.2), Color = rgb(200, 205, 215), Studs = false })
	end
	Brick.Part(tm, { Size = Vector3.new(8.4, 0.8, 0.8), Position = t + Vector3.new(0, 6.6, 7), Color = rgb(200, 205, 215), Studs = false })
	local console = Brick.Part(tm, {
		Name = "Painel",
		Size = Vector3.new(6, 3, 0.6),
		CFrame = CFrame.new(t + Vector3.new(0, 8.4, 7.2)) * CFrame.Angles(-0.35, 0, 0),
		Color = rgb(40, 45, 55),
	})
	surfaceText(console, Enum.NormalId.Front, {
		{ Name = "Title", Text = "ESTEIRA", Size = 0.4, Color = rgb(120, 230, 255) },
		{ Name = "Rate", Text = "⚡ +2/s", Size = 0.45, Color = rgb(255, 230, 60) },
	}, rgb(20, 25, 35))
	local zone = Brick.Part(tm, {
		Name = "Zona",
		Size = Vector3.new(6.6, 7, 15),
		Position = t + Vector3.new(0, 5, 0),
		Transparency = 1,
		CanCollide = false,
		Studs = false,
		CastShadow = false,
	})
	zone:SetAttribute("TreadmillZone", true)

	-- PLACAS DE MELHORIA -------------------------------------------------------
	-- Placas de melhoria DEITADAS NO CHÃO (inclinadas para quem chega pela frente do lote):
	-- quadro preto com título, nível e ganho, e na frente um BOTÃO DE PREÇO de verdade (peça
	-- com ClickDetector): clicar/tocar nele compra. Verde = dá para comprar, vermelho = falta
	-- dinheiro. Um "!" vermelho aparece em cima quando dá para comprar. PlotService preenche.
	local TILT = CFrame.Angles(math.rad(70), 0, 0) -- a face da frente olha para cima e para o jogador
	local function upgradeSign(name, position, title, icon)
		local sign = Brick.Model(model, name)
		local p = Vector3.new(position.X, floorTop, position.Z)
		local boardCF = CFrame.new(p + Vector3.new(0, 2.6, 1.6)) * TILT
		Brick.Part(sign, { Name = "Apoio", Size = Vector3.new(11.6, 3, 1.2), Position = p + Vector3.new(0, 1.5, 4.8), Color = rgb(28, 28, 32) })
		local board = Brick.Part(sign, {
			Name = "Placa",
			Size = Vector3.new(11, 7, 0.6),
			CFrame = boardCF,
			Color = rgb(18, 18, 22),
			Studs = false,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Gui"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = board
		local frame = Instance.new("Frame")
		frame.Name = "Board"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = rgb(18, 18, 22)
		frame.BorderSizePixel = 0
		frame.Parent = gui
		local border = Instance.new("UIStroke")
		border.Thickness = 8
		border.Color = rgb(55, 55, 65)
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.Parent = frame
		local function line(labelName, text, x, y, w, h, color)
			local label = Instance.new("TextLabel")
			label.Name = labelName
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(x, y)
			label.Size = UDim2.fromScale(w, h)
			label.Font = FONT
			label.Text = text
			label.TextScaled = true
			label.TextColor3 = color
			label.Parent = frame
			stroke(label, 4)
			return label
		end
		line("Icon", icon, 0.04, 0.08, 0.18, 0.4, WHITE)
		line("Title", title, 0.22, 0.08, 0.74, 0.3, WHITE)
		line("Level", "Nível 1 > Nível 2", 0.22, 0.4, 0.74, 0.22, rgb(120, 255, 90))
		line("Info", "", 0.05, 0.66, 0.9, 0.24, rgb(255, 225, 80))

		-- botão de preço (peça clicável)
		local button = Brick.Part(sign, {
			Name = "Botao",
			Size = Vector3.new(9.4, 2.4, 0.9),
			CFrame = boardCF * CFrame.new(0, -3.5 - 1.5, 0.15),
			Color = rgb(60, 200, 60),
		})
		local buttonGui = Instance.new("SurfaceGui")
		buttonGui.Name = "Gui"
		buttonGui.Face = Enum.NormalId.Front
		buttonGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		buttonGui.PixelsPerStud = 40
		buttonGui.LightInfluence = 0
		buttonGui.Parent = button
		local buttonFrame = Instance.new("Frame")
		buttonFrame.Name = "Board"
		buttonFrame.Size = UDim2.fromScale(1, 1)
		buttonFrame.BackgroundTransparency = 1
		buttonFrame.Parent = buttonGui
		local buttonBorder = Instance.new("UIStroke")
		buttonBorder.Thickness = 6
		buttonBorder.Color = rgb(15, 15, 20)
		buttonBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		buttonBorder.Parent = buttonFrame
		local cash = Instance.new("TextLabel")
		cash.Name = "Cash"
		cash.BackgroundTransparency = 1
		cash.Position = UDim2.fromScale(0.04, 0.1)
		cash.Size = UDim2.fromScale(0.16, 0.8)
		cash.Font = FONT
		cash.Text = "💵"
		cash.TextScaled = true
		cash.Parent = buttonFrame
		local price = Instance.new("TextLabel")
		price.Name = "Label"
		price.BackgroundTransparency = 1
		price.Position = UDim2.fromScale(0.2, 0.08)
		price.Size = UDim2.fromScale(0.76, 0.84)
		price.Font = FONT
		price.Text = "$0"
		price.TextScaled = true
		price.TextColor3 = WHITE
		price.Parent = buttonFrame
		stroke(price, 4)
		local click = Instance.new("ClickDetector")
		click.Name = "Click"
		click.MaxActivationDistance = 40
		click.Parent = button

		-- "!" quando dá para comprar
		local alertAnchor = Brick.Part(sign, {
			Name = "Alerta",
			Size = Vector3.new(1, 1, 1),
			Position = p + Vector3.new(0, 8, 2),
			Transparency = 1,
			CanCollide = false,
			Studs = false,
		})
		local alert = Instance.new("BillboardGui")
		alert.Name = "Gui"
		alert.Size = UDim2.new(3, 0, 4, 0)
		alert.LightInfluence = 0
		alert.Enabled = false
		alert.Parent = alertAnchor
		local mark = Instance.new("TextLabel")
		mark.Size = UDim2.fromScale(1, 1)
		mark.BackgroundTransparency = 1
		mark.Font = FONT
		mark.Text = "!"
		mark.TextScaled = true
		mark.TextColor3 = rgb(255, 40, 40)
		mark.Parent = alert
		stroke(mark, 4)
		return sign
	end
	upgradeSign("PlacaEsteira", plot.TreadmillSign, "Melhorar Esteira", "⚡")
	upgradeSign("PlacaAquario", plot.AquariumSign, "Melhorar Aquário", "🐟")

	-- marca de onde o jogador nasce
	Brick.Part(model, {
		Name = "Casa",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 8, 8),
		CFrame = CFrame.new(Vector3.new(plot.Spawn.X, floorTop + 0.12, plot.Spawn.Z)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Brick.Shade(accent, -0.2),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
		Studs = false,
	})

	return model
end

-- Construção geral ----------------------------------------------------------------------

function MapService.Build()
	setupCollisionGroups()
	setupLighting()

	-- tira a base e o spawn padrão de lugar novo (ficariam no meio da água)
	for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
		local default = Workspace:FindFirstChild(name)
		if default and default:IsA("BasePart") then
			default:Destroy()
		end
	end

	local existing = Workspace:FindFirstChild("Map")
	if existing then
		return existing
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	buildBeach(map)
	buildOcean(map)
	buildPlaza(map)
	local plots = Brick.Folder(map, "Lotes")
	for _, plot in ipairs(Layout.Plots) do
		buildPlot(plots, plot)
	end

	map.Parent = Workspace
	return map
end

function MapService.GetPlotModel(index)
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Lotes")
	return plots and plots:FindFirstChild("Lote" .. index)
end

return MapService
