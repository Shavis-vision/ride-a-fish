-- LeaderboardService (ModuleScript)
-- Fica em: ServerScriptService > Server > LeaderboardService
--
-- O placar "TOP RENDA" da praça: os jogadores deste servidor em ordem de renda por segundo.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local LeaderboardService = {}

local MEDALS = {
	Color3.fromRGB(255, 215, 60),
	Color3.fromRGB(210, 215, 230),
	Color3.fromRGB(230, 150, 90),
}

local function listFrame()
	local map = Workspace:FindFirstChild("Map")
	local screen = map and map:FindFirstChild("Praca") and map.Praca:FindFirstChild("Placar") and map.Praca.Placar:FindFirstChild("Tela")
	local gui = screen and screen:FindFirstChild("Gui")
	return gui and gui:FindFirstChild("List")
end

local function refresh()
	local list = listFrame()
	if not list then
		return
	end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return (a:GetAttribute("Income") or 0) > (b:GetAttribute("Income") or 0)
	end)
	for rank = 1, math.min(8, #players) do
		local player = players[rank]
		local row = Instance.new("Frame")
		row.Name = "Linha"
		row.LayoutOrder = rank
		row.Size = UDim2.new(1, 0, 0.115, 0)
		row.BackgroundColor3 = (rank % 2 == 0) and Color3.fromRGB(40, 44, 56) or Color3.fromRGB(32, 35, 46)
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
		end
		text(tostring(rank), 0.02, 0.08, MEDALS[rank] or Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
		text(player.DisplayName, 0.12, 0.5, Color3.new(1, 1, 1))
		text("$" .. NumberFormat.Rate(player:GetAttribute("Income") or 0) .. "/s", 0.6, 0.38, Color3.fromRGB(90, 255, 90), Enum.TextXAlignment.Right)
	end
end

function LeaderboardService.Start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(Config.LEADERBOARD_REFRESH)
		end
	end)
end

return LeaderboardService
