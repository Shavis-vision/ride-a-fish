-- Net (ModuleScript)
-- Fica em: ServerScriptService > Server > Net
--
-- A conversa entre servidor e cliente, num lugar só:
--   * ReplicatedStorage > Remotes > Action (RemoteFunction): o cliente pede algo ("Vender",
--     "Domar"...) e o servidor responde. Cada serviço registra as ações dele com Net.On.
--   * Remotes > Sync (RemoteEvent): o servidor manda a "foto" dos dados do jogador (peixes,
--     aquário, índex...) sempre que algo muda. Dinheiro e stamina vão por atributos do
--     jogador (mudam toda hora e o Roblox já replica sozinho).
--   * Remotes > Notify: avisos curtos na tela ("Sem dinheiro", "Novo peixe no índex!").
--   * Remotes > RideEvent: avisos da corrida (reviver).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local remotes
local handlers = {}
local pending = {}
local snapshotBuilder = nil

local function make(className, name)
	local remote = remotes:FindFirstChild(name) or Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

function Net.Start()
	remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage

	Net.Action = make("RemoteFunction", "Action")
	Net.SyncEvent = make("RemoteEvent", "Sync")
	Net.NotifyEvent = make("RemoteEvent", "Notify")
	Net.RideEvent = make("RemoteEvent", "RideEvent")

	Net.Action.OnServerInvoke = function(player, action, ...)
		local handler = type(action) == "string" and handlers[action]
		if not handler then
			return { ok = false, msg = "Ação desconhecida" }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(("[Net] erro na ação %s de %s: %s"):format(action, player.Name, tostring(result)))
			return { ok = false, msg = "Algo deu errado. Tente de novo." }
		end
		return result or { ok = true }
	end
end

-- Registra uma ação que o cliente pode pedir.
function Net.On(action, handler)
	handlers[action] = handler
end

-- Quem monta a "foto" dos dados (o Main liga isto ao DataService).
function Net.SetSnapshotBuilder(builder)
	snapshotBuilder = builder
end

-- Pede para mandar os dados de novo ao cliente (junta vários pedidos do mesmo instante).
function Net.Sync(player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		if player.Parent and snapshotBuilder then
			local snapshot = snapshotBuilder(player)
			if snapshot then
				Net.SyncEvent:FireClient(player, snapshot)
			end
		end
	end)
end

-- Aviso na tela. kind: "info", "ok", "erro", "raro"
function Net.Notify(player, text, kind)
	if Net.NotifyEvent then
		Net.NotifyEvent:FireClient(player, text, kind or "info")
	end
end

return Net
