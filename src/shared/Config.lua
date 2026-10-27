-- Config (ModuleScript)
-- Fica em: ReplicatedStorage > Shared > Config
--
-- Todos os números do jogo num lugar só. Para balancear, mexa aqui.
-- Os peixes ficam em Fish.lua, o mapa e a pista em Track.lua e Layout.lua.

local Config = {}

Config.GAME_NAME = "Ride a Fish"

-- Começo do jogador ---------------------------------------------------------------------
Config.STARTING_MONEY = 0
Config.STARTING_STAMINA = 12 -- dá para domar o primeiro peixe (Peixe-Palhaço pede 10)
Config.MAX_STORED_FISH = 200 -- peixes guardados (fora do aquário). Cheio = precisa vender

-- Esteira (treino de stamina) -------------------------------------------------------------
-- Stamina por segundo no nível N = BASE_RATE * RATE_GROWTH^(N-1)
-- Preço para subir do nível N para N+1 = BASE_COST * COST_GROWTH^(N-1)
Config.TREADMILL = {
	BASE_RATE = 2,
	RATE_GROWTH = 1.55,
	BASE_COST = 60,
	COST_GROWTH = 2.1,
	MAX_LEVEL = 40,
	TICK = 0.25, -- de quanto em quanto tempo o servidor confere quem está treinando
}

-- Aquário (vagas que rendem dinheiro) -----------------------------------------------------
-- Vagas no nível N = START_SLOTS + (N-1), até MAX_SLOTS
-- Preço para subir do nível N para N+1 = BASE_COST * COST_GROWTH^(N-1)
Config.AQUARIUM = {
	START_SLOTS = 4,
	MAX_SLOTS = 16,
	BASE_COST = 400,
	COST_GROWTH = 2.6,
}

-- Corrida ----------------------------------------------------------------------------------
Config.RIDE = {
	HARPOON_RANGE = 46, -- distância máxima do arpão até o próximo peixe
	-- Salto com mira (estilo Rodeo Stampede): ESPAÇO salta do peixe, o tempo fica lento e
	-- aparece o círculo amarelo EMBAIXO de você (A/D move você e o círculo para os lados).
	-- ESPAÇO de novo lança o arpão no peixe que estiver no círculo.
	SLOWMO = 0.35, -- velocidade do mundo durante o salto (35%)
	SLOWMO_TIME = 2.4, -- segundos (reais) de câmera lenta
	-- Assistência de mira: pega o peixe MAIS PERTO dentro do alcance do arpão (HARPOON_RANGE)
	ASSIST_BEHIND = 15, -- aceita peixes até esta distância para trás
	ASSIST_OBSTACLE_AHEAD = 60, -- evita peixes com uma pedra a menos disto na frente
	RETICLE_SIZE = 10, -- tamanho do círculo (studs)
	HARPOON_TIME = 0.32, -- segundos voando pela corda até o peixe
	GRAVITY = 40, -- "gravidade" debaixo d'água (mais leve que a normal)
	JUMP_UP = 20, -- impulso para cima ao pular sem alvo
	BUCK_UP = 24, -- impulso para cima quando o peixe derruba
	DIVE_UP = 10, -- impulso ao mergulhar na zona de início
	DIVE_FORWARD = 30,
	STEER_SPEED = 28, -- velocidade de lado (esquerda/direita) montado
	AIR_STEER_SPEED = 18,
	CRUISE_FACTOR = 0.45, -- peixe sem ninguém nada a 45% da velocidade dele
	ACTIVATE_AHEAD = 230, -- peixes começam a nadar quando você chega a esta distância
	DESPAWN_BEHIND = 70, -- peixes que ficaram para trás somem
	LABEL_DISTANCE = 130, -- até onde aparecem nome e stamina dos peixes
	BASE_RIDE_TIME = 4, -- segundos que um peixe domado aguenta você (mínimo)
	MAX_RIDE_TIME = 22,
	TAME_TOLERANCE = 0.8, -- o servidor aceita a doma com 80% do tempo (atraso de rede)
	FALL_SHOW_TIME = 2.2, -- segundos caído no fundo antes da tela de queda
	REVIVE_WINDOW = 5, -- segundos para decidir reviver (se o produto estiver configurado)
	SALTO_INTERVAL = 5, -- habilidade "Salto": de quanto em quanto tempo o peixe pula para fora
	TURBO_AFTER = 3, -- habilidade "Turbo": acelera depois deste tempo montado
	TURBO_MULT = 1.6,
}

-- Cores da stamina necessária (verde: dá; amarelo: quase; vermelho: falta muito)
Config.STAMINA_YELLOW_AT = 0.8 -- 80% ou mais do necessário = amarelo

-- Economia ---------------------------------------------------------------------------------
Config.INCOME_TICK = 1 -- o dinheiro do aquário entra a cada 1 segundo
Config.SELL_SECONDS = 20 -- um peixe vendido vale 20 segundos da renda dele
Config.INDEX_REWARD = {
	MONEY_SECONDS = 90, -- prêmio do índex = 90 segundos da renda do peixe (versão normal)
	STAMINA_FRACTION = 0.15, -- e 15% da stamina que ele pede
}
Config.AREA_REWARD = {
	MONEY_SECONDS = 300, -- completar a área = 300 segundos da renda somada dos 8 peixes
	STAMINA_FRACTION = 0.5, -- e metade da stamina somada
}

-- Robux --------------------------------------------------------------------------------------
-- Troque os Id = 0 pelos números criados no Creator Hub (Monetização). Com Id = 0 o botão
-- aparece como "Em breve" e nada é cobrado.
Config.GAMEPASSES = {
	{ Key = "MoneyX2", Id = 0, Name = "Dinheiro x2", Desc = "O aquário rende o dobro. Para sempre!", Price = 115 },
	{ Key = "StaminaX2", Id = 0, Name = "Stamina x2", Desc = "A esteira dá o dobro de stamina. Para sempre!", Price = 149 },
}
Config.PRODUCTS = {
	{ Key = "Revive", Id = 0, Name = "Reviver", Price = 25 },
	{ Key = "Cash1", Id = 0, Name = "Pacote pequeno", Price = 29, Minutes = 10, Minimum = 2000 },
	{ Key = "Cash2", Id = 0, Name = "Pacote médio", Price = 99, Minutes = 45, Minimum = 15000 },
	{ Key = "Cash3", Id = 0, Name = "Pacote grande", Price = 249, Minutes = 150, Minimum = 60000 },
}
-- Passe que aparece no lugar do botão Índex enquanto você treina na esteira
-- (some quando o jogador já tem o passe)
Config.TREADMILL_OFFER = "StaminaX2"
-- Como o bônus de Robux junta com o das auras: "soma" (x2 + aura 1.5 = x2.5).
-- Assim a aura vale o mesmo para quem pagou e para quem não pagou.
Config.BONUS_MODE = "soma"

-- Salvamento ---------------------------------------------------------------------------------
Config.DATA_STORE_NAME = "RideAFish_Dados_v1"
Config.SESSION_LOCK_TIMEOUT = 150
Config.SESSION_LOCK_WAIT = 12
Config.SESSION_LOCK_POLL = 3
Config.AUTOSAVE_INTERVAL = 60
Config.DATA_RETRIES = 3
Config.DATA_RETRY_DELAY = 1

-- Luz do mapa ------------------------------------------------------------------------------
-- Escolha a luz trocando o nome na linha abaixo: "Referencia" (parecida com as fotos de
-- referência), "Antiga" (a da primeira versão) ou "Nova" (a dos valores do Carlos).
Config.LIGHTING_PRESET = "Referencia"
Config.LIGHTING = {
	-- clara e suave, cores vivas, neblina leve azulada (como nas fotos de referência)
	Referencia = {
		ClockTime = 14,
		Brightness = 3,
		Ambient = { 135, 135, 150 },
		OutdoorAmbient = { 170, 175, 190 },
		LightingStyle = nil,
		ShadowSoftness = 0.35,
		BloomIntensity = 0.3,
		BloomSize = 24,
		BloomThreshold = 2,
		Glare = 0,
		Haze = 1.2,
		Density = 0.3,
		ColorCorrection = { Contrast = 0.08, Saturation = 0.18, Tint = { 255, 255, 255 } },
	},
	-- escolhida pelo Carlos em 27/out/2026
	Nova = {
		ClockTime = 13.5,
		Brightness = 4,
		Ambient = { 124, 155, 184 },
		OutdoorAmbient = { 157, 178, 255 },
		LightingStyle = "Realistic",
		ShadowSoftness = 1,
		-- limite do bloom mais alto: só neon e aura brilham (com 1.6 a tela ficava branca)
		BloomIntensity = 0.4,
		BloomSize = 56,
		BloomThreshold = 2.3,
		Glare = 0, -- sem clarão do sol na neblina
		ColorCorrection = { Contrast = 0.5, Saturation = 0.5, Tint = { 243, 234, 255 } },
	},
	-- a da primeira versão (sem correção de cor)
	Antiga = {
		ClockTime = 13.5,
		Brightness = 2.6,
		Ambient = { 120, 120, 130 },
		OutdoorAmbient = { 150, 160, 175 },
		LightingStyle = nil,
		ShadowSoftness = nil,
		BloomIntensity = 0.6,
		BloomSize = 24,
		BloomThreshold = 1.6,
		Glare = 0.15,
		ColorCorrection = nil,
	},
}

-- Placar -----------------------------------------------------------------------------------
Config.LEADERBOARD_REFRESH = 5

return Config
