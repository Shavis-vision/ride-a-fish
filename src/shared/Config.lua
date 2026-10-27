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
	-- aparece o círculo amarelo; ESPAÇO de novo lança o arpão no peixe que estiver no círculo.
	SLOWMO = 0.35, -- velocidade do mundo durante a mira (35%)
	SLOWMO_TIME = 2.4, -- segundos (reais) de câmera lenta
	AIM_START = 18, -- o círculo começa esta distância à frente
	AIM_MIN = 6,
	AIM_MAX = 42,
	AIM_SPEED = 38, -- velocidade do círculo (A/D e W/S ou analógico)
	ASSIST_RADIUS = 10, -- assistência de mira: peixe a esta distância do círculo é "pego" por ele
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

-- Placar -----------------------------------------------------------------------------------
Config.LEADERBOARD_REFRESH = 5

return Config
