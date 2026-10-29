-- LeaderboardService (ModuleScript)
-- Fica em: ServerScriptService > Server > LeaderboardService
--
-- Os placares de madeira da praça (modelos feitos no Studio, em Workspace > Map > Praca):
--   * Placar           "TOP INCOME"   : jogadores DESTE servidor por renda por segundo;
--   * PlacarDistancia  "LONGEST DIVE" : recorde de distância de TODOS os servidores;
--   * PlacarDomados    "MOST TAMED"   : total de peixes domados de TODOS os servidores.
-- Cada placar tem uma peça "Tela" com SurfaceGui "Gui" e um Frame "List" (as linhas).
--
-- Os rankings globais usam OrderedDataStore. Se o DataStore não responder (Studio sem
-- acesso à API), o placar mostra só quem está no servidor.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local LeaderboardService = {}

local ROWS = 8
local MEDALS = {
	Color3.fromRGB(255, 215, 60),
	Color3.fromRGB(210, 215, 230),
	Color3.fromRGB(230, 150, 90),
}

local BOARDS = {
	{
		Model = "Placar",
		Global = false,
		Value = function(player)
			return player:GetAttribute("Income") or 0
		end,
		Format = function(v)
			return "$" .. NumberFormat.Rate(v) .. "/s"
		end,
		Color = Color3.fromRGB(90, 255, 90),
	},
	{
		Model = "PlacarDistancia",
		Global = true,
		Store = "Distance",
		Value = function(player)
			local data = DataService.Get(player)
			return data and data.BestDist or 0
		end,
		Format = function(v)
			return NumberFormat.Abbreviate(math.floor(v)) .. " m"
		end,
		Color = Color3.fromRGB(110, 210, 255),
	},
	{
		Model = "PlacarDomados",
		Global = true,
		Store = "Tamed",
		Value = function(player)
			local data = DataService.Get(player)
			return data and data.Tamed or 0
		end,
		Format = function(v)
			return NumberFormat.Abbreviate(math.floor(v)) .. " 🐟"
		end,
		Color = Color3.fromRGB(255, 180, 90),
	},
}

local function listFrame(modelName)
	local map = Workspace:FindFirstChild("Map")
	local plaza = map and map:FindFirstChild("Praca")
	local board = plaza and plaza:FindFirstChild(modelName)
	local screen = board and board:FindFirstChild("Tela", true)
	local gui = screen and screen:FindFirstChild("Gui")
	return gui and gui:FindFirstChild("List")
end

-- nomes de quem não está no servidor (guardados para não perguntar de novo)
local names = {}
local function nameOf(userId)
	local online = Players:GetPlayerByUserId(userId)
	if online then
		return online.DisplayName
	end
	if names[userId] == nil then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = ok and name or "Player"
	end
	return names[userId]
end

local function draw(board, rows)
	local list = listFrame(board.Model)
	if not list then
		return
	end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for rank = 1, math.min(ROWS, #rows) do
		local item = rows[rank]
		local row = Instance.new("Frame")
		row.Name = "Linha"
		row.LayoutOrder = rank
		row.Size = UDim2.new(1, 0, 0.115, 0)
		row.BackgroundColor3 = (rank % 2 == 0) and Color3.fromRGB(70, 46, 26) or Color3.fromRGB(58, 38, 21)
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.Parent = list
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = row

		local function text(value, x, width, color, align)
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(x, 0.1)
			label.Size = UDim2.fromScale(width, 0.8)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextXAlignment = align or Enum.TextXAlignment.Left
			label.TextColor3 = color
			label.Text = value
			label.Parent = row
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = Color3.fromRGB(30, 18, 8)
			stroke.Parent = label
		end
		text(tostring(rank), 0.02, 0.08, MEDALS[rank] or Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
		text(item.Name, 0.12, 0.5, Color3.new(1, 1, 1))
		text(board.Format(item.Value), 0.6, 0.38, board.Color, Enum.TextXAlignment.Right)
	end
end

-- jogadores do servidor, do maior para o menor
local function serverRows(board)
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local value = board.Value(player)
		if board.Global and value <= 0 then
			continue
		end
		table.insert(rows, { UserId = player.UserId, Name = player.DisplayName, Value = value })
	end
	table.sort(rows, function(a, b)
		return a.Value > b.Value
	end)
	return rows
end

-- Rankings globais -------------------------------------------------------------------------
local stores = {}
local globalTop = {} -- [store] = { {UserId, Value} }
local written = {} -- [store][userId] = último valor gravado

local function storeFor(key)
	if stores[key] == nil then
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.GLOBAL_BOARD_STORES[key])
		stores[key] = ok and store or false
	end
	return stores[key] or nil
end

local function syncGlobal(board)
	local store = storeFor(board.Store)
	if not store then
		return
	end
	written[board.Store] = written[board.Store] or {}
	local done = written[board.Store]
	-- grava só quem melhorou desde a última vez
	for _, player in ipairs(Players:GetPlayers()) do
		local value = math.floor(board.Value(player))
		if value > 0 and value > (done[player.UserId] or 0) then
			local ok = pcall(store.SetAsync, store, tostring(player.UserId), value)
			if ok then
				done[player.UserId] = value
			end
		end
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, ROWS)
	if ok and pages then
		local top = {}
		for _, item in ipairs(pages:GetCurrentPage()) do
			local userId = tonumber(item.key)
			if userId then
				table.insert(top, { UserId = userId, Value = item.value })
			end
		end
		globalTop[board.Store] = top
	end
end

-- junta o global com os valores ao vivo de quem está no servidor (o mais alto vale)
local function globalRows(board)
	local byUser = {}
	for _, item in ipairs(globalTop[board.Store] or {}) do
		byUser[item.UserId] = item.Value
	end
	for _, row in ipairs(serverRows(board)) do
		byUser[row.UserId] = math.max(byUser[row.UserId] or 0, row.Value)
	end
	local rows = {}
	for userId, value in pairs(byUser) do
		table.insert(rows, { UserId = userId, Value = value })
	end
	table.sort(rows, function(a, b)
		return a.Value > b.Value
	end)
	for i = #rows, ROWS + 1, -1 do
		rows[i] = nil
	end
	for _, row in ipairs(rows) do
		row.Name = nameOf(row.UserId)
	end
	return rows
end

local function refresh()
	for _, board in ipairs(BOARDS) do
		draw(board, board.Global and globalRows(board) or serverRows(board))
	end
end

function LeaderboardService.Start()
	task.spawn(function()
		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn("[Leaderboard] " .. tostring(err))
			end
			task.wait(Config.LEADERBOARD_REFRESH)
		end
	end)
	task.spawn(function()
		task.wait(10)
		while true do
			for _, board in ipairs(BOARDS) do
				if board.Global then
					pcall(syncGlobal, board)
				end
			end
			task.wait(Config.GLOBAL_BOARD_REFRESH)
		end
	end)
end

return LeaderboardService
