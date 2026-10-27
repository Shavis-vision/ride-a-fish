-- Layout (ModuleScript)
-- Fica em: ReplicatedStorage > Shared > Layout
--
-- Onde cada coisa fica na praia: lotes dos jogadores, barracas, placar e zona de mergulho.
-- O servidor usa para construir; o cliente usa para saber onde abrir as lojas.
--
-- A praia fica em Z > 0 (atrás da beira da água). A água começa em Z = 0 e a pista
-- segue para -Z. Os lotes ficam dos dois lados da praça central.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Track = require(Shared:WaitForChild("Track"))

local Layout = {}

Layout.BEACH = {
	MinX = -340,
	MaxX = 340,
	MinZ = 0,
	MaxZ = 200,
}

Layout.PLOT_SIZE = Vector3.new(72, 1, 92) -- largura (X) e fundo (Z) de cada lote
Layout.PLOT_CENTER_Z = 96

-- Lotes: 3 à esquerda e 3 à direita da praça. A frente de cada lote olha para o mar (-Z).
Layout.Plots = {}
for index, x in ipairs({ -104, 104, -184, 184, -264, 264 }) do
	local center = Vector3.new(x, Track.BEACH_Y, Layout.PLOT_CENTER_Z)
	Layout.Plots[index] = {
		Index = index,
		Center = center,
		-- dentro do lote (coordenadas relativas ao centro)
		Aquarium = center + Vector3.new(0, 0, 30), -- no fundo do lote
		Treadmill = center + Vector3.new(0, 0, 2), -- na frente do aquário
		TreadmillSign = center + Vector3.new(-16, 0, 4),
		AquariumSign = center + Vector3.new(16, 0, 4),
		Spawn = center + Vector3.new(0, 3, -34),
	}
end

-- Praça central (entre os lotes)
Layout.SellStall = Vector3.new(-30, Track.BEACH_Y, 80)
Layout.AuraStall = Vector3.new(30, Track.BEACH_Y, 80)
Layout.Statue = Vector3.new(0, Track.BEACH_Y, 120)
Layout.Leaderboard = Vector3.new(0, Track.BEACH_Y, 150)

-- Anéis no chão que abrem as lojas ao pisar
Layout.ShopRings = {
	-- logo na frente do balcão (o balcão vai de Z 74 a 78)
	{ Shop = "Sell", Position = Vector3.new(-30, Track.BEACH_Y, 67), Radius = 7, Color = Color3.fromRGB(255, 60, 60) },
	{ Shop = "Aura", Position = Vector3.new(30, Track.BEACH_Y, 67), Radius = 7, Color = Color3.fromRGB(200, 60, 255) },
}

-- Zona de mergulho: na água rasa, logo depois da areia
Layout.StartZone = Vector3.new(0, Track.SeabedY(Track.START_DIST), Track.ZOf(Track.START_DIST))

-- Ponto de nascimento geral (antes de receber um lote)
Layout.LobbySpawn = Vector3.new(0, Track.BEACH_Y + 0.5, 98)

return Layout
