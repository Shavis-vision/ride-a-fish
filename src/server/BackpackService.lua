-- BackpackService (ModuleScript)
-- Fica em: ServerScriptService > Server > BackpackService
--
-- Os peixes GUARDADOS (fora do aquário) ficam na mochila padrão do Roblox, como ferramentas
-- (Tools) na barra de baixo. Segurando um peixe:
--   * ele aparece na mão do jogador;
--   * clicar (ou tocar na tela) coloca o peixe no aquário, se houver vaga.
-- A lista é refeita sempre que os dados mudam (Net.Sync) e quando o personagem nasce.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))
local FishModel = require(Shared:WaitForChild("FishModel"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local BackpackService = {}
BackpackService.PlaceInAquarium = nil :: ((Player, number) -> any)? -- o Main liga isto ao ShopService

local function toolsOf(player)
	local tools = {}
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in ipairs(containers) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("FishUid") then
					tools[item:GetAttribute("FishUid")] = item
				end
			end
		end
	end
	return tools
end

local function attachModel(tool, entry)
	local handle = tool:FindFirstChild("Handle")
	if not handle or tool:FindFirstChild("Peixe") then
		return
	end
	local sizeDef = Fish.Sizes[entry.Z] or Fish.Sizes.Normal
	local model = FishModel.Build(entry.S, entry.M, entry.Z, { Saddle = false, Scale = 0.42 * sizeDef.Scale ^ 0.5, Anchored = false })
	model.Name = "Peixe"
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Massless = true
			part.CanCollide = false
		end
	end
	-- o peixe fica na mão, de lado, com a cabeça para a frente do jogador
	model:PivotTo(handle.CFrame * CFrame.new(0, 0.4, -0.6))
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = model.PrimaryPart
	weld.C0 = CFrame.new(0, 0.4, -0.6)
	weld.Parent = model.PrimaryPart
	model.Parent = tool
end

local function makeTool(player, entry)
	local species = Fish.Get(entry.S)
	if not species then
		return nil
	end
	local tool = Instance.new("Tool")
	local tags = Fish.Tags(entry)
	tool.Name = species.Name
	tool.ToolTip = (tags ~= "" and (tags .. " • ") or "") .. "$" .. NumberFormat.Rate(Fish.Income(entry)) .. "/s • click to place in aquarium"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("FishUid", entry.Uid)
	tool:SetAttribute("Income", Fish.Income(entry))

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 0.6, 0.6)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.Grip = CFrame.new(0, -0.2, 0.4)

	tool.Equipped:Connect(function()
		attachModel(tool, entry)
	end)
	tool.Unequipped:Connect(function()
		local model = tool:FindFirstChild("Peixe")
		if model then
			model:Destroy()
		end
	end)
	tool.Activated:Connect(function()
		if BackpackService.PlaceInAquarium then
			BackpackService.PlaceInAquarium(player, entry.Uid)
		end
	end)
	return tool
end

-- Deixa a mochila igual aos peixes guardados (cria os que faltam, tira os que saíram).
function BackpackService.Refresh(player)
	local data = DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	local wanted = {}
	local stored = {}
	for _, entry in ipairs(data.Fish) do
		if not DataService.InAquarium(data, entry.Uid) then
			wanted[entry.Uid] = true
			table.insert(stored, entry)
		end
	end
	local tools = toolsOf(player)
	for uid, tool in pairs(tools) do
		if not wanted[uid] then
			tool:Destroy()
			tools[uid] = nil
		end
	end
	-- os que mais rendem entram primeiro (ficam nos primeiros espaços da barra)
	table.sort(stored, function(a, b)
		return Fish.Income(a) > Fish.Income(b)
	end)
	for _, entry in ipairs(stored) do
		if not tools[entry.Uid] then
			local tool = makeTool(player, entry)
			if tool then
				tool.Parent = backpack
			end
		end
	end
end

return BackpackService
