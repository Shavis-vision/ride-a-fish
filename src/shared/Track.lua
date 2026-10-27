-- Track (ModuleScript)
-- Fica em: ReplicatedStorage > Shared > Track
--
-- A pista debaixo d'água: começa na praia (Z = 0) e segue reto para a frente (-Z),
-- afundando. Tudo aqui é igual no servidor e no cliente:
--   * o desenho do fundo (degraus de studs) que o mapa constrói e que os peixes seguem;
--   * as 3 áreas, com cor da água e neblina;
--   * os obstáculos (pedras, corais, algas, cristais);
--   * os peixes de cada corrida, gerados a partir de um número (seed). O servidor sorteia o
--     seed e manda para o cliente: os dois geram a MESMA lista, então o servidor sabe
--     exatamente quais peixes existem e confere cada doma.
--
-- "dist" = distância a partir da beira da praia, para a frente. Z = SHORE_Z - dist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))

local Track = {}

Track.WATER_Y = 0 -- altura da superfície da água
Track.BEACH_Y = 2 -- altura do chão de areia da praia (topo)
Track.SHORE_Z = 0
Track.HALF_WIDTH = 80 -- meia largura da pista (160 studs de largura)
Track.AREA_LENGTH = 900 -- comprimento de cada área
Track.LENGTH = Track.AREA_LENGTH * 3
Track.DEEP_FLOOR_Y = -185 -- fundo escuro bem lá embaixo (só visual)

Track.SLOPE_END = 48 -- a rampa da praia vai até aqui
Track.SLOPE_STEPS = 14 -- degraus de 1 stud cada
Track.SEG = 8 -- comprimento de cada degrau do fundo depois da rampa

Track.START_DIST = 26 -- centro da zona de mergulho (na água rasa)
Track.START_RADIUS = 12
Track.BARRIER_DIST = 46 -- parede invisível para quem não está correndo

Track.FISH_SWIM_HEIGHT = 5 -- altura dos peixes acima do fundo
Track.FIRST_FISH_DIST = 74 -- o peixe garantido fica depois da queda, já no fundo

Track.Areas = {
	{
		Index = 1,
		Name = "Recife Raso",
		Start = 0,
		Finish = 900,
		FogColor = Color3.fromRGB(70, 180, 205),
		FogEnd = 360,
		Tint = Color3.fromRGB(205, 240, 250),
		Brightness = 0.04,
		Sand = Color3.fromRGB(236, 214, 150),
		Rock = Color3.fromRGB(236, 206, 160), -- degraus do recife (pedra clara)
		Rock2 = Color3.fromRGB(120, 205, 110), -- tampa dos degraus (verde, como a grama da praia)
		Deco = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 200, 50), Color3.fromRGB(120, 230, 255), Color3.fromRGB(180, 120, 255) },
	},
	{
		Index = 2,
		Name = "Floresta de Algas",
		Start = 900,
		Finish = 1800,
		FogColor = Color3.fromRGB(70, 160, 140),
		FogEnd = 320,
		Tint = Color3.fromRGB(200, 245, 220),
		Brightness = 0.02,
		Sand = Color3.fromRGB(160, 170, 120),
		Rock = Color3.fromRGB(110, 135, 110),
		Rock2 = Color3.fromRGB(95, 175, 75),
		Deco = { Color3.fromRGB(60, 200, 80), Color3.fromRGB(150, 230, 60), Color3.fromRGB(30, 150, 90), Color3.fromRGB(220, 200, 80) },
	},
	{
		Index = 3,
		Name = "Abismo",
		Start = 1800,
		Finish = 2700,
		FogColor = Color3.fromRGB(45, 90, 160),
		FogEnd = 280,
		Tint = Color3.fromRGB(190, 205, 255),
		Brightness = -0.02,
		Sand = Color3.fromRGB(120, 130, 175),
		Rock = Color3.fromRGB(70, 75, 135),
		Rock2 = Color3.fromRGB(105, 90, 160),
		Deco = { Color3.fromRGB(0, 255, 210), Color3.fromRGB(170, 70, 255), Color3.fromRGB(255, 80, 200), Color3.fromRGB(80, 160, 255) },
	},
}

-- Stamina recomendada para cada área (o peixe mais fraco dela)
for _, area in ipairs(Track.Areas) do
	local lowest = math.huge
	for _, species in ipairs(Fish.ByArea[area.Index] or {}) do
		lowest = math.min(lowest, species.Stamina)
	end
	area.Recommended = lowest
end

function Track.ZOf(dist)
	return Track.SHORE_Z - dist
end

function Track.DistOf(z)
	return Track.SHORE_Z - z
end

function Track.AreaAt(dist)
	for _, area in ipairs(Track.Areas) do
		if dist < area.Finish then
			return area
		end
	end
	return Track.Areas[#Track.Areas]
end

-- O fundo do mar --------------------------------------------------------------------------
-- Pontos de controle (dist, altura). Entre eles a altura desce em linha reta e depois é
-- arredondada para um número inteiro: fica com cara de degraus de Lego.
-- Depois da rampa da praia vem uma QUEDA (o "afundar" do começo da corrida).
-- Na troca de área o fundo cai de novo (cada área é mais funda que a anterior).
local CONTROL = {
	{ 48, -14 },
	{ 66, -32 },
	{ 870, -50 },
	{ 900, -50 },
	{ 932, -66 },
	{ 1770, -86 },
	{ 1800, -86 },
	{ 1832, -104 },
	{ 2700, -132 },
}

local function interpolate(dist)
	if dist <= CONTROL[1][1] then
		return CONTROL[1][2]
	end
	for i = 1, #CONTROL - 1 do
		local a, b = CONTROL[i], CONTROL[i + 1]
		if dist <= b[1] then
			local t = (dist - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return CONTROL[#CONTROL][2]
end

-- Lista dos degraus do fundo: { D0 = início, D1 = fim, Y = altura do topo }
Track.Segments = {}
do
	local stepLength = Track.SLOPE_END / Track.SLOPE_STEPS
	for i = 1, Track.SLOPE_STEPS do
		table.insert(Track.Segments, { D0 = (i - 1) * stepLength, D1 = i * stepLength, Y = Track.BEACH_Y - i })
	end
	local d = Track.SLOPE_END
	while d < Track.LENGTH + 40 do
		local y = math.floor(interpolate(d + Track.SEG / 2) + 0.5)
		table.insert(Track.Segments, { D0 = d, D1 = d + Track.SEG, Y = y })
		d += Track.SEG
	end
end

-- Altura do topo do fundo nesta distância.
function Track.SeabedY(dist)
	if dist < 0 then
		return Track.BEACH_Y
	end
	local index
	if dist < Track.SLOPE_END then
		index = math.floor(dist / (Track.SLOPE_END / Track.SLOPE_STEPS)) + 1
	else
		index = Track.SLOPE_STEPS + math.floor((dist - Track.SLOPE_END) / Track.SEG) + 1
	end
	index = math.clamp(index, 1, #Track.Segments)
	return Track.Segments[index].Y
end

-- Obstáculos (fixos, iguais para todo mundo) -------------------------------------------------
-- { Dist, X, Radius, Height, Kind }
Track.Obstacles = {}
do
	local rng = Random.new(731)
	local d = 200 -- o começo fica livre: dá tempo de domar o primeiro peixe sem bater
	while true do
		local area = Track.AreaAt(d)
		local gap = area.Index == 1 and rng:NextNumber(18, 28) or area.Index == 2 and rng:NextNumber(15, 24) or rng:NextNumber(12, 21)
		d += gap
		if d > Track.LENGTH - 40 then
			break
		end
		local nearGate = false
		for _, a in ipairs(Track.Areas) do
			if a.Index > 1 and math.abs(d - a.Start) < 20 then
				nearGate = true
			end
		end
		if not nearGate then
			local kinds = area.Index == 1 and { "Coral", "Rocha" } or area.Index == 2 and { "Alga", "Rocha" } or { "Cristal", "Rocha" }
			local kind = kinds[rng:NextInteger(1, #kinds)]
			local radius = rng:NextNumber(3.5, 6)
			local height = kind == "Alga" and rng:NextNumber(18, 26) or rng:NextNumber(8, 15)
			table.insert(Track.Obstacles, {
				Dist = d,
				X = rng:NextNumber(-Track.HALF_WIDTH + 10, Track.HALF_WIDTH - 10),
				Radius = radius,
				Height = height,
				Kind = kind,
			})
		end
	end
end

-- Peixes de uma corrida ----------------------------------------------------------------------
-- Gera SEMPRE a mesma lista para o mesmo seed. Cada peixe:
-- { Index, S = espécie, M = mutação, Z = tamanho, Dist, X, Phase, SpeedMul }
-- Distância entre um peixe e o próximo na pista (maior = menos peixes)
Track.FISH_GAP_MIN = 8
Track.FISH_GAP_MAX = 13

function Track.GenerateRun(seed)
	local rng = Random.new(seed)
	local list = {}

	-- Garantido: um Peixe-Palhaço logo depois da zona de mergulho, para o primeiro pulo.
	table.insert(list, {
		Index = 1,
		S = "palhaco",
		M = "Normal",
		Z = "Normal",
		Dist = Track.FIRST_FISH_DIST,
		X = 0,
		Phase = 0,
		SpeedMul = 1,
	})

	local d = Track.FIRST_FISH_DIST + 14
	while d < Track.LENGTH - 40 do
		local area = Track.AreaAt(d)
		local species = Fish.RollSpecies(rng, area.Index)
		local mutation = Fish.RollMutation(rng)
		local size = Fish.RollSize(rng)
		table.insert(list, {
			Index = #list + 1,
			S = species.Id,
			M = mutation,
			Z = size,
			Dist = d,
			X = rng:NextNumber(-Track.HALF_WIDTH + 8, Track.HALF_WIDTH - 8),
			Phase = rng:NextNumber(0, math.pi * 2),
			SpeedMul = rng:NextNumber(0.9, 1.1),
		})
		d += rng:NextNumber(Track.FISH_GAP_MIN, Track.FISH_GAP_MAX)
	end

	return list
end

-- Velocidade máxima possível (o servidor usa para conferir se deu tempo de chegar a um peixe)
Track.MAX_SPEED = 0
for _, species in ipairs(Fish.Species) do
	Track.MAX_SPEED = math.max(Track.MAX_SPEED, species.Speed)
end
Track.MAX_SPEED *= 1.1 * 1.6 -- tamanho Mini e Turbo

return Track
