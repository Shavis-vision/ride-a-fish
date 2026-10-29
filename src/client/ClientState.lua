-- ClientState (ModuleScript)
-- Fica em: StarterPlayerScripts > Client > ClientState
--
-- O que o cliente sabe sobre o jogador: a última "foto" dos dados que o servidor mandou
-- (peixes, aquário, índex...) e um jeito de pedir ações ao servidor.
-- Todas as telas usam este módulo (é o mesmo para todos os scripts do cliente).
--
--   ClientState.Data              -- a foto atual (ou nil antes de chegar)
--   ClientState.Changed.Event     -- dispara quando chega foto nova
--   ClientState.Request("Sell", uid)  -- pede ao servidor; devolve { ok, msg, ... }
--   ClientState.Toast("texto", "ok")  -- aviso na tela

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local action = remotes:WaitForChild("Action")

local ClientState = {}

ClientState.Data = nil
ClientState.Changed = Instance.new("BindableEvent")
ClientState.ToastEvent = Instance.new("BindableEvent")

function ClientState.Toast(text, kind)
	ClientState.ToastEvent:Fire(text, kind or "info")
end

-- ações que dão dinheiro: tocam o som de moedas quando dão certo
local COIN_ACTIONS = { SellMany = true, Sell = true, ClaimIndex = true, ClaimAllIndex = true, ClaimArea = true }

function ClientState.Request(name, ...)
	local ok, result = pcall(action.InvokeServer, action, name, ...)
	if not ok then
		ClientState.Toast("No connection to the server", "erro")
		return { ok = false }
	end
	result = result or { ok = false }
	if result.ok and COIN_ACTIONS[name] then
		local okSound, SoundFx = pcall(require, script.Parent:WaitForChild("SoundFx"))
		if okSound then
			SoundFx.Play("Coins")
		end
	end
	if result.msg then
		ClientState.Toast(result.msg, result.ok and "info" or "erro")
	end
	return result
end

function ClientState.Stat(name)
	return player:GetAttribute(name) or 0
end

function ClientState.FindFish(uid)
	local data = ClientState.Data
	if not data then
		return nil
	end
	for _, entry in ipairs(data.Fish) do
		if entry.Uid == uid then
			return entry
		end
	end
	return nil
end

function ClientState.InAquarium(uid)
	local data = ClientState.Data
	return data ~= nil and table.find(data.Aquarium, uid) ~= nil
end

remotes:WaitForChild("Sync").OnClientEvent:Connect(function(snapshot)
	ClientState.Data = snapshot
	ClientState.Changed:Fire(snapshot)
end)

remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text, kind)
	ClientState.Toast(text, kind)
end)

task.spawn(function()
	ClientState.Request("GetData")
end)

return ClientState
