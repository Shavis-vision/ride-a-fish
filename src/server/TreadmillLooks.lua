-- TreadmillLooks (ModuleScript)
-- Fica em: ServerScriptService > Server > TreadmillLooks
--
-- A esteira de cada lote muda de cara conforme o nível (tudo tema do mar). Muda rápido no
-- começo e devagar no fim:
--   nível  1  Ship Deck   madeira de barco, corda, lanternas e boia
--   nível  3  Seashell    areia e rosa, conchas e estrela-do-mar
--   nível  6  Coral Reef  verde-água com corais coloridos nos cantos
--   nível 10  Pearl       branca brilhante, fileira de pérolas e uma ostra com pérola gigante
--   nível 15  Shark       cinza-azulado, barbatana, dentes na frente e cauda atrás
--   nível 22  Abyss       azul-escuro com luzes neon e a "lanterna" do peixe-diabo
--   nível 30  Kraken      roxa com tentáculos subindo pelos cantos
--   nível 40  Poseidon    dourada e água-marinha, tridente, ondas e brilhos
--
--   TreadmillLooks.Apply(plotModel, level, announce) -> nome do visual novo, se mudou de
--       visual e announce = true (aí também solta um brilho)
--
-- As peças que fazem a esteira funcionar (Base, Esteirinha, Listras, Zona, Painel) só mudam
-- de cor; os enfeites de cada visual ficam na pasta "Enfeites" (sem colisão).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brick = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Brick"))

local TreadmillLooks = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

TreadmillLooks.Tiers = {
	{ Level = 1, Name = "Ship Deck", Frame = rgb(150, 100, 58), Side = rgb(110, 72, 40), Rail = rgb(222, 196, 140), Belt = rgb(70, 50, 34), Stripe = rgb(120, 86, 55), Title = rgb(255, 214, 140) },
	{ Level = 3, Name = "Seashell", Frame = rgb(245, 228, 196), Side = rgb(235, 200, 160), Rail = rgb(255, 170, 190), Belt = rgb(60, 52, 60), Stripe = rgb(255, 205, 215), Title = rgb(255, 170, 200) },
	{ Level = 6, Name = "Coral Reef", Frame = rgb(40, 180, 168), Side = rgb(25, 130, 125), Rail = rgb(255, 128, 85), Belt = rgb(25, 45, 55), Stripe = rgb(80, 220, 200), Title = rgb(255, 150, 110) },
	{ Level = 10, Name = "Pearl", Frame = rgb(246, 246, 252), Side = rgb(225, 220, 245), Rail = rgb(230, 222, 255), Belt = rgb(60, 60, 80), Stripe = rgb(235, 230, 255), Title = rgb(240, 235, 255), Shine = 0.12 },
	{ Level = 15, Name = "Shark", Frame = rgb(105, 125, 150), Side = rgb(230, 235, 240), Rail = rgb(45, 58, 76), Belt = rgb(30, 34, 42), Stripe = rgb(150, 165, 185), Title = rgb(200, 220, 240) },
	{ Level = 22, Name = "Abyss", Frame = rgb(16, 26, 60), Side = rgb(10, 14, 30), Rail = rgb(20, 20, 26), Belt = rgb(8, 10, 18), Stripe = rgb(60, 230, 255), Title = rgb(80, 240, 255), Neon = rgb(60, 230, 255) },
	{ Level = 30, Name = "Kraken", Frame = rgb(92, 42, 134), Side = rgb(62, 26, 92), Rail = rgb(170, 70, 160), Belt = rgb(26, 14, 36), Stripe = rgb(220, 120, 255), Title = rgb(230, 150, 255), Neon = rgb(200, 90, 255) },
	{ Level = 40, Name = "Poseidon", Frame = rgb(245, 197, 66), Side = rgb(210, 150, 30), Rail = rgb(63, 224, 208), Belt = rgb(18, 40, 60), Stripe = rgb(120, 255, 240), Title = rgb(255, 225, 90), Neon = rgb(63, 224, 208), Shine = 0.15 },
}

function TreadmillLooks.TierFor(level)
	local index = 1
	for i, tier in ipairs(TreadmillLooks.Tiers) do
		if level >= tier.Level then
			index = i
		end
	end
	return index, TreadmillLooks.Tiers[index]
end

-- peças de estrutura e qual cor do visual cada uma usa
local STRUCTURE = {
	Base = "Frame",
	Capo = "Frame",
	CapoRampa = "Frame",
	RampaTras = "Frame",
	Lateral = "Side",
	Corrimao = "Rail",
	Poste = "Rail",
	Barra = "Rail",
	Esteirinha = "Belt",
}

-- Enfeites ---------------------------------------------------------------------------------
-- Tudo é posto em relação à Base: x = lados (±4.5), y = altura acima do centro da base
-- (o topo da base fica em 0.7), z = frente (+, lado do painel) e trás (-).

local DECOR = {}

local function maker(folder, base)
	local function at(x, y, z, rx, ry, rz)
		return base.CFrame * CFrame.new(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
	end
	local function block(size, cf, color, props)
		props = props or {}
		return Brick.Part(folder, {
			Name = props.Name or "Enfeite",
			Size = size,
			CFrame = cf,
			Color = color,
			Class = props.Class,
			Shape = props.Shape,
			Material = props.Material,
			Transparency = props.Transparency,
			Reflectance = props.Reflectance,
			CanCollide = false,
			CastShadow = props.CastShadow,
			Studs = props.Studs or false,
		})
	end
	local function ball(diameter, cf, color, props)
		props = props or {}
		props.Shape = Enum.PartType.Ball
		return block(Vector3.new(diameter, diameter, diameter), cf, color, props)
	end
	local function glow(part, color, range, brightness)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = range or 10
		light.Brightness = brightness or 1.5
		light.Shadows = false
		light.Parent = part
		return light
	end
	return at, block, ball, glow
end

-- 1. convés de barco: lanternas nos postes e uma boia salva-vidas do lado
DECOR[1] = function(folder, base)
	local at, block, _, glow = maker(folder, base)
	for side = -1, 1, 2 do
		block(Vector3.new(1.2, 0.2, 1.2), at(side * 3.9, 9.05, 6.6), rgb(40, 30, 20))
		local lamp = block(Vector3.new(0.9, 1.1, 0.9), at(side * 3.9, 9.7, 6.6), rgb(255, 210, 110), { Material = Enum.Material.Neon })
		block(Vector3.new(1.2, 0.2, 1.2), at(side * 3.9, 10.35, 6.6), rgb(40, 30, 20))
		glow(lamp, rgb(255, 200, 120), 9, 1.2)
	end
	-- boia (anel de blocos vermelhos e brancos) na lateral esquerda
	local center = at(-4.65, 2.6, -2.5, 0, math.pi / 2, 0)
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		block(Vector3.new(0.55, 0.9, 0.5), center * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.05, 0), i % 2 == 0 and rgb(230, 50, 50) or rgb(245, 245, 245))
	end
	-- tábuas (frisos) no capô
	for i = -1, 1 do
		block(Vector3.new(9.05, 0.08, 0.12), at(0, 2.12, 7.6 + i * 0.8), rgb(95, 62, 34))
	end
end

-- 2. concha: conchas em leque nos cantos da frente e estrelas-do-mar nas laterais
DECOR[2] = function(folder, base)
	local at, block = maker(folder, base)
	local function shell(cf, color)
		for i = -2, 2 do
			block(Vector3.new(0.35, 1.7, 0.25), cf * CFrame.Angles(0, 0, i * 0.32) * CFrame.new(0, 0.85, 0), i % 2 == 0 and color or color:Lerp(rgb(255, 255, 255), 0.35))
		end
		block(Vector3.new(0.8, 0.4, 0.3), cf, color:Lerp(rgb(0, 0, 0), 0.15))
	end
	shell(at(-3.6, 2.15, 8.85), rgb(255, 150, 170))
	shell(at(3.6, 2.15, 8.85), rgb(255, 190, 120))
	local function star(cf, color)
		for i = 0, 4 do
			block(Vector3.new(0.3, 0.9, 0.18), cf * CFrame.Angles(0, 0, i / 5 * math.pi * 2) * CFrame.new(0, 0.45, 0), color)
		end
		block(Vector3.new(0.45, 0.45, 0.22), cf, color:Lerp(rgb(0, 0, 0), 0.1))
	end
	star(at(-4.55, 1.3, 2, 0, -math.pi / 2, 0), rgb(255, 120, 60))
	star(at(4.55, 1.3, -3, 0, math.pi / 2, 0), rgb(255, 90, 140))
	-- pedrinhas de areia em cima das laterais
	for i = -3, 3, 2 do
		block(Vector3.new(0.5, 0.25, 0.5), at(-3.9, 1.95, i * 2), rgb(255, 235, 200))
		block(Vector3.new(0.5, 0.25, 0.5), at(3.9, 1.95, i * 2 + 1), rgb(255, 220, 230))
	end
end

-- 3. coral: corais nos quatro cantos
DECOR[3] = function(folder, base)
	local at, block, ball = maker(folder, base)
	local function coral(x, z, color, height)
		local y = 1.9
		for step = 1, height do
			local w = 0.75 - step * 0.06
			block(Vector3.new(w, 0.9, w), at(x, y + step * 0.85, z), color)
			if step % 2 == 0 then
				block(Vector3.new(0.4, 0.8, 0.4), at(x + 0.45, y + step * 0.85 + 0.2, z, 0, 0, -0.6), color)
				block(Vector3.new(0.4, 0.8, 0.4), at(x - 0.45, y + step * 0.85 + 0.4, z, 0, 0, 0.6), color)
			end
		end
		ball(0.7, at(x, y + height * 0.85 + 0.6, z), color:Lerp(rgb(255, 255, 255), 0.3))
	end
	coral(-3.9, 8.5, rgb(255, 90, 140), 4)
	coral(3.9, 8.5, rgb(255, 150, 60), 3)
	coral(-3.9, -8.3, rgb(170, 90, 255), 3)
	coral(3.9, -8.3, rgb(255, 210, 60), 4)
	-- coral-cérebro e anêmonas na frente
	ball(1.4, at(0, 2.3, 8.6), rgb(255, 130, 170), { Studs = false })
	for i = -1, 1, 2 do
		for k = 0, 4 do
			block(Vector3.new(0.18, 0.9, 0.18), at(i * 2.2 + (k - 2) * 0.22, 2.55, 8.7, 0, 0, (k - 2) * 0.25), rgb(120, 255, 200), { Material = Enum.Material.Neon })
		end
	end
end

-- 4. pérola: fileira de pérolas nas laterais e uma ostra aberta com pérola gigante
DECOR[4] = function(folder, base)
	local at, block, ball, glow = maker(folder, base)
	for i = -4, 4 do
		ball(0.55, at(-3.9, 2.05, i * 1.9), rgb(250, 245, 255), { Reflectance = 0.25, Material = Enum.Material.SmoothPlastic })
		ball(0.55, at(3.9, 2.05, i * 1.9), rgb(250, 245, 255), { Reflectance = 0.25, Material = Enum.Material.SmoothPlastic })
	end
	-- ostra em cima do painel (sem tampar o texto)
	local clam = at(0, 12.15, 6.3)
	block(Vector3.new(2.6, 0.35, 1.8), clam * CFrame.new(0, -0.2, 0), rgb(200, 190, 230))
	block(Vector3.new(2.6, 0.35, 1.8), clam * CFrame.new(0, 0.8, -0.6) * CFrame.Angles(-1.0, 0, 0), rgb(215, 205, 240))
	local pearl = ball(1.1, clam * CFrame.new(0, 0.45, 0.1), rgb(255, 250, 255), { Reflectance = 0.3, Material = Enum.Material.SmoothPlastic })
	glow(pearl, rgb(235, 225, 255), 12, 1.2)
end

-- 5. tubarão: barbatana em cima, dentes na frente, cauda atrás
DECOR[5] = function(folder, base)
	local at, block = maker(folder, base)
	-- barbatana dorsal (duas cunhas) em cima da barra
	block(Vector3.new(0.6, 3.4, 2.6), at(0, 13.4, 6.2), rgb(95, 115, 140), { Class = "WedgePart" })
	block(Vector3.new(0.6, 3.4, 1.3), at(0, 13.4, 8.15, 0, math.pi, 0), rgb(95, 115, 140), { Class = "WedgePart" })
	-- dentes na beira do capô
	for i = -4, 4 do
		block(Vector3.new(0.6, 0.7, 0.3), at(i * 0.95, 1.5, 9.05, 0, 0, math.pi), rgb(250, 250, 250), { Class = "WedgePart" })
	end
	-- olhos nas laterais da frente
	for side = -1, 1, 2 do
		block(Vector3.new(0.12, 0.7, 0.7), at(side * 4.62, 1.4, 7.6), rgb(15, 15, 20))
		block(Vector3.new(0.13, 0.25, 0.25), at(side * 4.63, 1.55, 7.75), rgb(255, 255, 255))
	end
	-- cauda atrás (duas barbatanas abertas)
	-- (de lado, saindo da traseira: não fica na frente de quem sobe na esteira)
	for side = -1, 1, 2 do
		block(Vector3.new(0.5, 2.2, 1.4), at(side * 4.9, 1.9, -9.6, 0.5, 0, side * 0.5), rgb(95, 115, 140), { Class = "WedgePart" })
	end
end

-- 6. abismo: luzes neon nas laterais e a "lanterna" do peixe-diabo pendurada na frente
DECOR[6] = function(folder, base, tier)
	local at, block, ball, glow = maker(folder, base)
	for side = -1, 1, 2 do
		block(Vector3.new(0.15, 0.25, 17.6), at(side * 4.52, 1.25, 0), tier.Neon, { Material = Enum.Material.Neon })
		block(Vector3.new(0.25, 0.25, 0.25), at(side * 3.9, 1.9, -6), tier.Neon, { Material = Enum.Material.Neon })
		block(Vector3.new(0.25, 0.25, 0.25), at(side * 3.9, 1.9, 0), tier.Neon, { Material = Enum.Material.Neon })
		block(Vector3.new(0.25, 0.25, 0.25), at(side * 3.9, 1.9, 6), tier.Neon, { Material = Enum.Material.Neon })
	end
	-- haste curva saindo de cima da barra
	-- (sai de trás do painel, passa por cima e a luz fica pendurada acima do texto)
	local points = {
		Vector3.new(0, 11.4, 7.2),
		Vector3.new(0, 13.2, 7.0),
		Vector3.new(0, 14.0, 6.0),
		Vector3.new(0, 13.9, 4.9),
		Vector3.new(0, 13.3, 4.4),
	}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		local cf = base.CFrame * CFrame.lookAt(mid, b)
		block(Vector3.new(0.25, 0.25, (b - a).Magnitude + 0.15), cf, rgb(30, 30, 40))
	end
	local lure = ball(0.9, at(0, 12.75, 4.3), tier.Neon, { Material = Enum.Material.Neon })
	glow(lure, tier.Neon, 16, 2)
end

-- 7. kraken: quatro tentáculos subindo pelos cantos, com ventosas
DECOR[7] = function(folder, base, tier)
	local at, block = maker(folder, base)
	local function tentacle(x, z, curl)
		local cf = at(x, 1.6, z)
		local width = 1.1
		for step = 1, 7 do
			cf = cf * CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, curl * 0.15)
			block(Vector3.new(width, 0.85, width), cf, tier.Frame:Lerp(tier.Rail, step / 10))
			if step % 2 == 1 then
				block(Vector3.new(0.12, 0.35, 0.35), cf * CFrame.new(-curl * width / 2, 0, 0), rgb(255, 170, 220))
			end
			width *= 0.86
		end
	end
	tentacle(-4.1, 8.6, 1)
	tentacle(4.1, 8.6, -1)
	tentacle(-4.1, -8.4, 1)
	tentacle(4.1, -8.4, -1)
	-- olho do kraken no capô
	block(Vector3.new(1.6, 1.0, 0.2), at(0, 1.6, 9.05), rgb(255, 220, 60), { Material = Enum.Material.Neon })
	block(Vector3.new(0.4, 0.9, 0.22), at(0, 1.6, 9.07), rgb(15, 10, 20))
	for side = -1, 1, 2 do
		block(Vector3.new(0.15, 0.25, 17.6), at(side * 4.52, 1.25, 0), tier.Neon, { Material = Enum.Material.Neon })
	end
end

-- 8. Poseidon: tridente atrás do painel, ondas nas laterais e brilhos
DECOR[8] = function(folder, base, tier)
	local at, block, ball, glow = maker(folder, base)
	local gold = rgb(255, 205, 70)
	-- tridente
	block(Vector3.new(0.5, 9, 0.5), at(0, 9.5, 8.8), gold, { Material = Enum.Material.SmoothPlastic, Reflectance = 0.2 })
	block(Vector3.new(3.4, 0.5, 0.5), at(0, 13.8, 8.8), gold, { Material = Enum.Material.SmoothPlastic, Reflectance = 0.2 })
	for i = -1, 1 do
		block(Vector3.new(0.45, 2.2, 0.45), at(i * 1.45, 15.1, 8.8), gold, { Material = Enum.Material.SmoothPlastic, Reflectance = 0.2 })
		block(Vector3.new(0.6, 0.7, 0.6), at(i * 1.45, 16.4, 8.8, 0, math.pi / 4, 0), tier.Neon, { Class = "WedgePart", Material = Enum.Material.Neon })
	end
	local gem = ball(0.9, at(0, 13.8, 9.15), tier.Neon, { Material = Enum.Material.Neon })
	glow(gem, tier.Neon, 18, 2)
	-- ondas nas laterais
	for side = -1, 1, 2 do
		for i = -3, 3 do
			block(Vector3.new(0.4, 1.0, 1.6), at(side * 4.7, 1.6, i * 2.4, 0, 0, 0), rgb(245, 255, 255), { Class = "WedgePart" })
			block(Vector3.new(0.38, 0.6, 1.4), at(side * 4.72, 1.0, i * 2.4 - 0.4), tier.Neon, { Material = Enum.Material.Neon })
		end
	end
	-- brilhos dourados saindo da esteira
	local emitterPart = block(Vector3.new(6, 0.2, 14), at(0, 2.2, 0), gold, { Transparency = 1 })
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(1, 1.8)
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Color = ColorSequence.new(gold, tier.Neon)
	sparkles.LightEmission = 0.8
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Parent = emitterPart
end

-- "Pufff" quando a esteira muda de visual
local function celebrate(base)
	local burst = Instance.new("ParticleEmitter")
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.8, 1.4)
	burst.Speed = NumberRange.new(8, 16)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	burst.Color = ColorSequence.new(rgb(255, 240, 120), rgb(120, 230, 255))
	burst.LightEmission = 0.8
	burst.Parent = base
	burst:Emit(60)
	task.delay(2, function()
		burst:Destroy()
	end)
end

function TreadmillLooks.Apply(model, level, announce)
	local treadmill = model and model:FindFirstChild("Esteira")
	local base = treadmill and treadmill:FindFirstChild("Base")
	if not base then
		return nil
	end
	local index, tier = TreadmillLooks.TierFor(level or 1)
	local previous = treadmill:GetAttribute("Tier")
	if previous == index then
		return nil
	end
	treadmill:SetAttribute("Tier", index)

	for _, part in ipairs(treadmill:GetChildren()) do
		local key = STRUCTURE[part.Name]
		if key and part:IsA("BasePart") then
			part.Color = tier[key]
			part.Reflectance = (key == "Frame" or key == "Rail") and (tier.Shine or 0) or 0
		end
	end
	local stripes = treadmill:FindFirstChild("Listras")
	if stripes then
		for _, stripe in ipairs(stripes:GetChildren()) do
			if stripe:IsA("BasePart") then
				stripe.Color = tier.Stripe
				stripe.Material = tier.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
	end
	-- nome do visual no painel
	local console = treadmill:FindFirstChild("Painel")
	local gui = console and console:FindFirstChildOfClass("SurfaceGui")
	local frame = gui and gui:FindFirstChildOfClass("Frame")
	local title = frame and frame:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = string.upper(tier.Name)
		title.TextColor3 = tier.Title
	end

	local old = treadmill:FindFirstChild("Enfeites")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Enfeites"
	if DECOR[index] then
		DECOR[index](folder, base, tier)
	end
	folder.Parent = treadmill

	if announce and previous and index > previous then
		celebrate(base)
		return tier.Name
	end
	return nil
end

return TreadmillLooks
