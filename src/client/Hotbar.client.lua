-- Hotbar (LocalScript)
-- Fica em: StarterPlayerScripts > Client > Hotbar
--
-- A barra de baixo com os peixes guardados (substitui a mochila padrão do Roblox):
--   * 8 espaços com a foto 3D de cada peixe, a cor da raridade, a borda da mutação e a renda;
--   * teclas 1 a 8 (ou clique/toque) seguram o peixe na mão; de novo, guarda;
--   * o botão da MOCHILA (ou a tecla `) abre a janela com TODOS os peixes guardados;
--     clicar num peixe lá também segura ele.
-- Os peixes continuam sendo ferramentas (Tools) que o servidor cria (BackpackService); esta
-- tela só mostra e equipa. Some durante a corrida.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer

local SLOTS = 8
local SLOT = 70 -- tamanho de cada espaço
local GAP = 7
local MAX_VIEWPORTS = 48 -- na janela da mochila (fotos 3D pesam)
local KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
}
local MUTATION_BORDER = {
	Normal = Color3.fromRGB(20, 20, 26),
	Prata = Color3.fromRGB(225, 230, 240),
	Dourado = Color3.fromRGB(255, 200, 60),
	Diamante = Color3.fromRGB(120, 230, 255),
	ArcoIris = Color3.fromRGB(255, 120, 220),
}

-- some com a mochila padrão do Roblox (tenta de novo: no começo o CoreGui pode não estar pronto)
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

-- Ferramentas (peixes) -------------------------------------------------------------------------
local function fishTools()
	local list = {}
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in ipairs(containers) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("FishUid") then
					table.insert(list, item)
				end
			end
		end
	end
	-- os que mais rendem primeiro
	table.sort(list, function(a, b)
		local ia, ib = a:GetAttribute("Income") or 0, b:GetAttribute("Income") or 0
		if ia == ib then
			return a:GetAttribute("FishUid") < b:GetAttribute("FishUid")
		end
		return ia > ib
	end)
	return list
end

local function equippedTool()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool")
end

local function toggle(tool)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not tool or not tool.Parent then
		return
	end
	if tool.Parent == character then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

-- Visual de um peixe (usado na barra e na mochila) ------------------------------------------
local function fishFace(button, entry, opts)
	local species = Fish.Get(entry.S)
	if not species then
		return
	end
	local rarity = Fish.Rarities[species.Rarity]
	UIKit.Gradient(button, rarity.Color:Lerp(Color3.new(1, 1, 1), 0.15), rarity.Color:Lerp(Color3.new(0, 0, 0), 0.6), 90)
	UIKit.Studs(button, opts.Size, { Spacing = opts.Spacing, Transparency = 0.86, EdgeTransparency = 0.8 })
	if opts.Viewport ~= false then
		UIKit.Viewport(button, entry, {
			Size = opts.ViewSize or UDim2.new(1, -6, 1, -18),
			Position = opts.ViewPos or UDim2.fromOffset(3, 2),
			Rotation = 70,
			ZIndex = 2,
		})
	else
		UIKit.Text(button, { Text = "🐟", Size = opts.ViewSize or UDim2.new(1, 0, 0.6, 0), Position = opts.ViewPos or UDim2.fromScale(0, 0.1), Stroke = 1, ZIndex = 2 })
	end
end

-- Barra ----------------------------------------------------------------------------------------
local gui = UIKit.Gui("Hotbar", 2)
local width = SLOTS * (SLOT + GAP) + SLOT + 8 + GAP
local bar = UIKit.Frame(gui, {
	Name = "Barra",
	Size = UDim2.fromOffset(width, SLOT + 14),
	Position = UDim2.new(0.5, 0, 1, -10),
	AnchorPoint = Vector2.new(0.5, 1),
	Color = Color3.fromRGB(20, 26, 40),
	Transparency = 0.35,
	Corner = 14,
	Stroke = 3,
})
UIKit.AutoScale(bar, Vector2.new(width, SLOT + 14))
UIKit.Studs(bar, Vector2.new(width, SLOT + 14), { Spacing = 21, Transparency = 0.92, EdgeTransparency = 0.88 })

local slotFrames = {}
for i = 1, SLOTS do
	local holder = UIKit.Frame(bar, {
		Name = "Espaco" .. i,
		Size = UDim2.fromOffset(SLOT, SLOT),
		Position = UDim2.fromOffset(GAP + (i - 1) * (SLOT + GAP), 7),
		Transparency = 1,
		Corner = false,
	})
	slotFrames[i] = { Holder = holder }
end

-- botão da mochila (no fim da barra)
local bagButton = UIKit.Button(bar, {
	Name = "Mochila",
	Text = "",
	Color = "Orange",
	Style = "Hud",
	Size = UDim2.fromOffset(SLOT + 8, SLOT),
	Position = UDim2.fromOffset(GAP + SLOTS * (SLOT + GAP), 7),
	Corner = 10,
})
UIKit.Text(bagButton, { Text = "🎒", Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.04), Stroke = 2, ZIndex = 3 })
local bagCount = UIKit.Text(bagButton, { Text = "0", Size = UDim2.new(1, -6, 0.34, 0), Position = UDim2.new(0, 3, 0.64, 0), Max = 22, Stroke = 2.5, ZIndex = 3 })
local bagKey = UIKit.Text(bagButton, { Text = "`", Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(4, 2), Max = 16, Stroke = 2, ZIndex = 4 })
bagKey.Visible = UserInputService.KeyboardEnabled

local empty = UIKit.Text(bar, {
	Text = "Tame fish to fill your bar!",
	Size = UDim2.new(0, SLOTS * (SLOT + GAP), 1, -20),
	Position = UDim2.fromOffset(GAP, 10),
	Color = Color3.fromRGB(190, 200, 215),
	Max = 26,
	ZIndex = 3,
})

local slotTools = {}

local function buildSlot(i, tool)
	local slot = slotFrames[i]
	UIKit.Clear(slot.Holder)
	slot.Button = nil
	slotTools[i] = tool
	if not tool then
		return
	end
	local entry = ClientState.FindFish(tool:GetAttribute("FishUid"))
	if not entry then
		return
	end
	local button = Instance.new("TextButton")
	button.Name = "Peixe"
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromScale(1, 1)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = UIKit.White
	button.BorderSizePixel = 0
	UIKit.Corner(button, 10)
	local stroke = UIKit.Stroke(button, entry.M ~= "Normal" and 3.5 or 3, MUTATION_BORDER[entry.M] or MUTATION_BORDER.Normal, Enum.ApplyStrokeMode.Border)
	button.Parent = slot.Holder
	fishFace(button, entry, { Size = Vector2.new(SLOT, SLOT), Spacing = 17 })
	UIKit.Text(button, { Text = tostring(i), Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(4, 2), Max = 17, Stroke = 2.5, ZIndex = 4 })
	UIKit.Text(button, {
		Text = "$" .. NumberFormat.Rate(Fish.Income(entry)) .. "/s",
		Size = UDim2.new(1, -4, 0, 16),
		Position = UDim2.new(0, 2, 1, -17),
		Color = UIKit.MoneyGreen,
		Max = 15,
		Stroke = 2,
		ZIndex = 4,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function()
		UIKit.Tween(scale, 0.15, { Scale = 1.06 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.15, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		toggle(slotTools[i])
	end)
	slot.Button = button
	slot.Stroke = stroke
	slot.Mutation = entry.M
end

-- destaca o peixe que está na mão (borda branca e o espaço sobe um pouco)
local function refreshSelection()
	local held = equippedTool()
	for i, slot in ipairs(slotFrames) do
		local button = slot.Button
		if button then
			local on = held ~= nil and slotTools[i] == held
			slot.Stroke.Color = on and UIKit.White or (MUTATION_BORDER[slot.Mutation] or MUTATION_BORDER.Normal)
			slot.Stroke.Thickness = on and 4.5 or (slot.Mutation ~= "Normal" and 3.5 or 3)
			UIKit.Tween(button, 0.15, { Position = on and UDim2.new(0.5, 0, 0.5, -8) or UDim2.fromScale(0.5, 0.5) })
		end
	end
end

local backpackWindow -- (criada mais abaixo)
local renderBackpack

local function refreshBar()
	local tools = fishTools()
	for i = 1, SLOTS do
		local tool = tools[i]
		local uid = tool and tool:GetAttribute("FishUid")
		local slot = slotFrames[i]
		if slot.Uid ~= uid or (tool and not slot.Button) then
			slot.Uid = uid
			buildSlot(i, tool)
		else
			slotTools[i] = tool
		end
	end
	empty.Visible = #tools == 0
	bagCount.Text = tostring(#tools)
	refreshSelection()
	if backpackWindow and backpackWindow.IsOpen then
		renderBackpack()
	end
end

-- refaz a barra uma vez só, mesmo quando muitas ferramentas mudam juntas
local pending = false
local function schedule()
	if pending then
		return
	end
	pending = true
	task.delay(0.1, function()
		pending = false
		refreshBar()
	end)
end

-- Janela da mochila ----------------------------------------------------------------------------
backpackWindow = UIKit.Window("Backpack", { Title = "Backpack", Icon = "🎒", Size = Vector2.new(980, 620), Header = "Orange" })
local info = UIKit.Text(backpackWindow.Body, {
	Text = "",
	Size = UDim2.new(1, -20, 0, 30),
	Position = UDim2.fromOffset(10, 0),
	Align = Enum.TextXAlignment.Left,
	Color = Color3.fromRGB(200, 210, 225),
	Max = 24,
})
local gridArea = UIKit.Frame(backpackWindow.Body, {
	Name = "Peixes",
	Size = UDim2.new(1, 0, 1, -40),
	Position = UDim2.fromOffset(0, 40),
	Color = Color3.fromRGB(16, 16, 20),
	Transparency = 0.45,
	Corner = 10,
	Stroke = 3,
})
UIKit.StudsFill(gridArea, { Spacing = 30, Transparency = 0.94 })
local grid = UIKit.Scroll(gridArea, {
	Size = UDim2.new(1, -12, 1, -12),
	Position = UDim2.fromOffset(6, 6),
	Grid = UDim2.fromOffset(170, 196),
	GridPadding = UDim2.fromOffset(10, 10),
})

function renderBackpack()
	UIKit.Clear(grid)
	local tools = fishTools()
	local held = equippedTool()
	info.Text = (#tools == 0) and "Your backpack is empty. Tame fish in the ocean!"
		or ("%d fish  •  the best %d are on your bar  •  click a fish to hold it"):format(#tools, math.min(SLOTS, #tools))
	for order, tool in ipairs(tools) do
		local entry = ClientState.FindFish(tool:GetAttribute("FishUid"))
		local species = entry and Fish.Get(entry.S)
		if species then
			local rarity = Fish.Rarities[species.Rarity]
			local on = tool == held
			local card = Instance.new("TextButton")
			card.Name = "Peixe" .. entry.Uid
			card.Text = ""
			card.AutoButtonColor = false
			card.LayoutOrder = order
			card.BackgroundColor3 = UIKit.White
			card.BorderSizePixel = 0
			UIKit.Corner(card, 10)
			UIKit.Stroke(card, on and 5 or 3, on and UIKit.White or (MUTATION_BORDER[entry.M] or MUTATION_BORDER.Normal), Enum.ApplyStrokeMode.Border)
			card.Parent = grid
			fishFace(card, entry, {
				Size = Vector2.new(170, 196),
				Spacing = 24,
				Viewport = order <= MAX_VIEWPORTS,
				ViewSize = UDim2.new(1, -10, 0, 104),
				ViewPos = UDim2.fromOffset(5, 32),
			})
			UIKit.Text(card, { Text = species.Name, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 4), Max = 22, Stroke = 2.5, ZIndex = 4 })
			local tags = Fish.Tags(entry)
			if tags ~= "" then
				UIKit.Text(card, {
					Text = tags,
					Size = UDim2.new(1, -12, 0, 18),
					Position = UDim2.fromOffset(6, 136),
					Color = entry.M ~= "Normal" and Fish.Mutations[entry.M].Color or Color3.fromRGB(255, 200, 130),
					Max = 16,
					Stroke = 2,
					ZIndex = 4,
				})
			end
			UIKit.Text(card, {
				Text = "$" .. NumberFormat.Rate(Fish.Income(entry)) .. "/s",
				Size = UDim2.new(1, -12, 0, 28),
				Position = UDim2.new(0, 6, 1, -34),
				Color = UIKit.MoneyGreen,
				Max = 24,
				Stroke = 3,
				ZIndex = 4,
			})
			UIKit.Text(card, {
				Text = rarity.Name,
				Size = UDim2.new(1, -12, 0, 14),
				Position = UDim2.fromOffset(6, 28),
				Color = rarity.Color:Lerp(UIKit.White, 0.4),
				Max = 13,
				Stroke = 1.5,
				ZIndex = 4,
			})
			if on then
				UIKit.Text(card, { Text = "IN HAND", Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 120), Color = UIKit.White, Max = 15, Stroke = 2, ZIndex = 4 })
			end
			card.Activated:Connect(function()
				toggle(tool)
				backpackWindow.Close()
			end)
		end
	end
end

backpackWindow.Opened.Event:Connect(renderBackpack)
bagButton.Activated:Connect(function()
	backpackWindow.Toggle()
end)

-- Teclado ----------------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not bar.Visible then
		return
	end
	local index = KEYS[input.KeyCode]
	if index then
		toggle(slotTools[index])
	elseif input.KeyCode == Enum.KeyCode.Backquote then
		backpackWindow.Toggle()
	end
end)

-- Quando refazer --------------------------------------------------------------------------------
local function watch(container)
	if not container then
		return
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			schedule()
		end
	end)
	container.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			schedule()
		end
	end)
end

local function onCharacter(character)
	watch(character)
	task.defer(function()
		watch(player:WaitForChild("Backpack"))
		schedule()
	end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
ClientState.Changed.Event:Connect(schedule)

-- some durante a corrida (lá embaixo ficam as dicas e o botão de pular)
local function updateVisible()
	local running = player:GetAttribute("Running") == true
	bar.Visible = not running
	if running then
		backpackWindow.Close()
	end
end
player:GetAttributeChangedSignal("Running"):Connect(updateVisible)
updateVisible()
