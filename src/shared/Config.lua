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
Config.MAX_STORED_FISH = 200
Config.WALK_SPEED = 24 -- velocidade andando (o padrão do Roblox é 16) -- peixes guardados (fora do aquário). Cheio = precisa vender

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
	HARPOON_RANGE = 62, -- distância máxima do arpão até o próximo peixe
	-- Salto com mira (estilo Rodeo Stampede): ESPAÇO salta do peixe, o tempo fica um pouco
	-- lento e o peixe mais perto fica amarelo. ESPAÇO de novo lança o arpão na hora; se não
	-- apertar, ele sai sozinho depois de AUTO_HARPOON_AFTER segundos.
	SLOWMO = 0.35, -- velocidade do mundo durante o salto (35%: câmera lenta para escolher o peixe)
	SLOWMO_TIME = 1.9, -- segundos (reais) de câmera lenta
	AUTO_HARPOON_AFTER = 1.25, -- o arpão sai sozinho no alvo depois disto (nil = só apertando)
	-- Mira: um ponto à frente (A/D move); o alvo é o peixe mais perto do ponto, dentro do alcance
	ASSIST_BEHIND = 15, -- aceita peixes até esta distância para trás
	ASSIST_OBSTACLE_AHEAD = 60, -- evita peixes com uma pedra a menos disto na frente
	RETICLE_SIZE = 10, -- tamanho do círculo (studs)
	HARPOON_TIME = 0.42, -- segundos voando pela corda até o peixe (suave: acelera e freia)
	GRAVITY = 75, -- "gravidade" do pulo (mais alta = pulo mais curto e rápido)
	JUMP_UP = 32, -- impulso para cima ao pular
	BUCK_UP = 30, -- impulso para cima quando o peixe derruba
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
-- Os passes de stamina são uma ESCADA: x2 → x4 → x6 → x8 (de 2 em 2). Cada degrau custa
-- 3 Robux por "x" (x2 = 6, x4 = 12, x6 = 18, x8 = 24), bem barato para incentivar a compra.
-- Só dá para comprar o próximo degrau, e vale o maior que o jogador tiver.
Config.GAMEPASSES = {
	{ Key = "MoneyX2", Id = 0, Name = "Money x2", Desc = "Your aquarium earns double. Forever!", Price = 115 },
	{ Key = "StaminaX2", Id = 0, Name = "Stamina x2", Desc = "The treadmill gives 2x stamina. Forever!", Price = 6, Ladder = "Stamina", Mult = 2 },
	{ Key = "StaminaX4", Id = 0, Name = "Stamina x4", Desc = "The treadmill gives 4x stamina. Forever!", Price = 12, Ladder = "Stamina", Mult = 4 },
	{ Key = "StaminaX6", Id = 0, Name = "Stamina x6", Desc = "The treadmill gives 6x stamina. Forever!", Price = 18, Ladder = "Stamina", Mult = 6 },
	{ Key = "StaminaX8", Id = 0, Name = "Stamina x8", Desc = "The treadmill gives 8x stamina. Forever!", Price = 24, Ladder = "Stamina", Mult = 8 },
}
Config.PRODUCTS = {
	{ Key = "Revive", Id = 0, Name = "Revive", Price = 25 },
	{ Key = "Cash1", Id = 0, Name = "Small Pack", Price = 29, Minutes = 10, Minimum = 2000 },
	{ Key = "Cash2", Id = 0, Name = "Medium Pack", Price = 99, Minutes = 45, Minimum = 15000 },
	{ Key = "Cash3", Id = 0, Name = "Big Pack", Price = 249, Minutes = 150, Minimum = 60000 },
}
-- Enquanto você treina na esteira, o botão Índex vira a oferta do PRÓXIMO degrau desta
-- escada (some quando o jogador já tem o x8)
Config.TREADMILL_OFFER = "Stamina"
-- Como o bônus de Robux junta com o das auras: "soma" (passe x2 + aura x1.5 = x2.5;
-- passe x8 + aura x1.5 = x8.5).
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
		Haze = 0.6, -- menos "leitoso" ao longe
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

-- Ícones do HUD -----------------------------------------------------------------------------
-- As imagens estão em assets/icons/ (PNG). Envie cada uma no Studio (Ver > Gerenciador de
-- Ativos > Importar) e cole aqui o número (ID) dela. Com 0 aparece o emoji no lugar.
Config.ICONS = {
	Loja = 0, -- assets/icons/loja.png
	Indice = 0, -- assets/icons/indice.png
	Aquario = 0, -- assets/icons/aquario.png
	Stamina = 0, -- assets/icons/stamina.png
	Dinheiro = 0, -- assets/icons/dinheiro.png
}

-- Studs grandes nas peças --------------------------------------------------------------------
-- Envie assets/textures/studs.png no Studio (Gerenciador de Ativos > Importar) e cole o ID aqui.
-- Com 0, ficam os studs normais (pequenos) do Roblox.
Config.STUD_TEXTURE = 0 -- 0 = usa os studs do próprio Roblox (superfície Studs + material Plastic)
Config.STUD_SPACING = 2

-- Céu --------------------------------------------------------------------------------------
-- Opção 1: coloque um Sky em Lighting pelo Studio COM O JOGO PARADO e salve o lugar (Ctrl+S).
--          O jogo mantém o Sky que estiver lá.
-- Opção 2: cole aqui os 6 IDs do céu (no Studio: selecione o Sky e copie SkyboxBk, SkyboxDn,
--          SkyboxFt, SkyboxLf, SkyboxRt e SkyboxUp). Assim o céu fica salvo no GitHub e vale
--          sempre, mesmo se o Sky do lugar for apagado. Deixe nil para usar a opção 1.
Config.SKY = nil
-- Exemplo:
-- Config.SKY = {
-- 	SkyboxBk = "rbxassetid://000", SkyboxDn = "rbxassetid://000", SkyboxFt = "rbxassetid://000",
-- 	SkyboxLf = "rbxassetid://000", SkyboxRt = "rbxassetid://000", SkyboxUp = "rbxassetid://000",
-- 	SunAngularSize = 18, -- opcional
-- }

-- Placar -----------------------------------------------------------------------------------
Config.LEADERBOARD_REFRESH = 5
-- Placares globais (todos os servidores): maior distância e mais peixes domados
Config.GLOBAL_BOARD_REFRESH = 60 -- segundos entre leituras do ranking global
Config.GLOBAL_BOARD_STORES = { Distance = "RideAFish_TopDistancia_v1", Tamed = "RideAFish_TopDomados_v1" }

-- Sons (áudios prontos do Creator Store). Id = 0 desliga o som.
-- Efeitos: Pro Sound Effects (licenciados pelo Roblox) e alguns curtos públicos.
-- Música: faixas da DistroKid (licenciadas, liberadas para qualquer jogo).
Config.SOUNDS = {
	MusicVolume = 0.3,
	EffectsVolume = 0.7,
	Music = { 132521872324308, 97159266806924 }, -- "Beach Tropical Coffee Bossa Nova", "Palm Shimmer"
	Effects = {
		Splash = { Id = 9125703162, Volume = 0.8 }, -- entrar na água
		Jump = { Id = 9120972321, Volume = 0.5 }, -- pular do peixe
		Harpoon = { Id = 9120972444, Volume = 0.6, Speed = 1.2 }, -- arpão voando
		Fall = { Id = 9125409840, Volume = 0.7 }, -- caiu no fundo
		Buck = { Id = 9120310477, Volume = 0.7 }, -- o peixe derrubou
		Tame = { Id = 8630860073, Volume = 0.6 }, -- domou
		TameNew = { Id = 85188102085028, Volume = 0.7 }, -- domou uma espécie nova
		Revive = { Id = 120005759558278, Volume = 0.7 }, -- reviveu
		Click = { Id = 110948579458469, Volume = 0.4 }, -- botões
		Coins = { Id = 1319346243, Volume = 0.5 }, -- dinheiro
		Sell = { Id = 134810204798705, Volume = 0.6 }, -- vender peixes (caixa registradora)
		Buy = { Id = 3406813517, Volume = 0.55 }, -- comprar com dinheiro (melhorias, auras)
	},
}

return Config
