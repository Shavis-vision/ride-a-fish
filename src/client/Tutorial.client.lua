-- Tutorial (LocalScript)
-- Fica em: StarterPlayerScripts > Client > Tutorial
--
-- Guia o jogador novo nos primeiros minutos. Setas brilhantes saem do personagem e andam
-- até o lugar certo, com uma marca pulando em cima do destino e um cartão com a instrução.
--   1. ir até a ponta do píer e mergulhar;
--   2. na corrida: ficar no peixe até domar, pular (ESPAÇO) e lançar o arpão (ESPAÇO);
--   3. colocar um peixe no aquário (renda);
--   4. correr na esteira (stamina).
-- O passo feito fica salvo (data.Tut). Quem já domou peixes antes não vê o tutorial.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("Layout"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer
local DONE = 4
local ARROW_COLOR = Color3.fromRGB(255, 220, 40)
local ARROWS = 9
local SPACING = 4

-- Cartão com a instrução -------------------------------------------------------------------
local gui = UIKit.Gui("Tutorial", 3)
local card = UIKit.Frame(gui, {
	Size = UDim2.fromOffset(560, 92),
	Position = UDim2.new(0.5, 0, 1, -130),
	AnchorPoint = Vector2.new(0.5, 1),
	Color = Color3.fromRGB(14, 22, 38),
	Transparency = 0.3,
	Corner = 14,
	Stroke = 3,
	StrokeColor = ARROW_COLOR,
})
UIKit.AutoScale(card)
card.Visible = false
local stepLabel = UIKit.Text(card, { Text = "TUTORIAL", Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(12, 6), Align = Enum.TextXAlignment.Left, Color = ARROW_COLOR, Max = 18, Stroke = 2 })
local textLabel = UIKit.Text(card, { Text = "", Rich = true, Size = UDim2.new(1, -24, 1, -34), Position = UDim2.fromOffset(12, 28), Align = Enum.TextXAlignment.Left, Max = 24, Stroke = 2 })
local skip = UIKit.Button(card, { Text = "Skip", Color = "Gray", Size = UDim2.fromOffset(70, 30), Position = UDim2.new(1, -8, 0, 6), AnchorPoint = Vector2.new(1, 0), Max = 18 })
local cardScale = Instance.new("UIScale")
cardScale.Parent = card

-- Setas no chão + marca no destino -------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "TutorialSetas"
folder.Parent = Workspace

local function neon(size)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = ARROW_COLOR
	part.Size = size
	part.Parent = folder
	return part
end

-- cada seta é um ">" feito de duas barras deitadas
local arrows = {}
for i = 1, ARROWS do
	arrows[i] = { neon(Vector3.new(0.5, 0.15, 2.2)), neon(Vector3.new(0.5, 0.15, 2.2)) }
end

local beacon = neon(Vector3.new(0.3, 8, 8))
beacon.Shape = Enum.PartType.Cylinder
beacon.Transparency = 0.55
local marker = Instance.new("BillboardGui")
marker.Size = UDim2.fromOffset(160, 90)
marker.AlwaysOnTop = true
marker.LightInfluence = 0
marker.Parent = beacon
local markerText = UIKit.Text(marker, { Text = "", Size = UDim2.new(1, 0, 0, 30), Color = ARROW_COLOR, Stroke = 3, Max = 26 })
UIKit.Text(marker, { Text = "▼", Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 32), Color = ARROW_COLOR, Stroke = 3, Max = 48 })

local function setArrowsVisible(visible)
	for _, pair in ipairs(arrows) do
		pair[1].Transparency = visible and 0.1 or 1
		pair[2].Transparency = visible and 0.1 or 1
	end
	beacon.Transparency = visible and 0.55 or 1
	marker.Enabled = visible
end
setArrowsVisible(false)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundY(position, fallback)
	local ok, result = pcall(function()
		return Workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), rayParams)
	end)
	return ok and result and result.Position.Y or fallback
end

local function drawArrows(root, target, t)
	local from = root.Position
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local distance = flat.Magnitude
	if distance < 1 then
		return
	end
	local dir = flat.Unit
	local shift = (t * 6) % SPACING -- as setas andam em direção ao destino
	local footY = from.Y - 3
	for i, pair in ipairs(arrows) do
		local along = 3 + (i - 1) * SPACING + shift
		local show = along < distance - 2
		local p = from + dir * along
		local y = groundY(Vector3.new(p.X, from.Y, p.Z), footY) + 0.25
		local base = CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) + dir)
		-- ">" apontando para a frente: duas barras abertas em V
		pair[1].CFrame = base * CFrame.new(-0.55, 0, 0.45) * CFrame.Angles(0, math.rad(-40), 0)
		pair[2].CFrame = base * CFrame.new(0.55, 0, 0.45) * CFrame.Angles(0, math.rad(40), 0)
		-- some aos poucos no fim da fila
		local fade = show and math.clamp(1 - (i - 1) / ARROWS, 0.25, 1) or 0
		pair[1].Transparency = 1 - fade * 0.9
		pair[2].Transparency = 1 - fade * 0.9
	end
	local gy = groundY(target, target.Y)
	beacon.CFrame = CFrame.new(target.X, gy + 0.2, target.Z) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Size = Vector3.new(0.3, 8 + math.sin(t * 4) * 0.8, 8 + math.sin(t * 4) * 0.8)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 6 + math.abs(math.sin(t * 3)) * 1.5, 0)
end

-- Onde fica cada coisa ---------------------------------------------------------------------
local function myPlot()
	local plots = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Lotes")
	if not plots then
		return nil
	end
	for _, model in ipairs(plots:GetChildren()) do
		if model:GetAttribute("Owner") == player.UserId then
			return model
		end
	end
	return nil
end

local function positionOf(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.Position
	end
	if instance:IsA("Model") then
		return (instance:GetBoundingBox()).Position
	end
	return nil
end

local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local jumpKey = touch and "tap <b>JUMP</b>" or "press <b>SPACE</b>"

-- Qual passo mostrar agora ---------------------------------------------------------------------
-- devolve { Text, Target (Vector3 ou nil), Label }
local function currentStep(data)
	local step = data.Tut or DONE
	if step >= DONE then
		return nil
	end
	local running = player:GetAttribute("Running") == true
	if step == 0 then
		if running then
			return nil
		end
		return { Index = 1, Text = "Walk to the <b>end of the pier</b> and jump in to ride your first fish!", Target = Layout.StartZone, Label = "DIVE HERE!" }
	elseif step == 1 then
		if not running then
			return nil
		end
		return {
			Index = 2,
			Text = ("Stay on the fish until the ring fills: it's <b>TAMED</b>! Then %s to jump and %s again to harpoon the next fish."):format(jumpKey, jumpKey),
		}
	elseif step == 2 then
		if running then
			return nil
		end
		if #(data.Fish or {}) == 0 then
			return { Index = 3, Text = "No fish this time! Go back to the pier and <b>tame one</b>.", Target = Layout.StartZone, Label = "DIVE HERE!" }
		end
		local plot = myPlot()
		return {
			Index = 3,
			Text = "Hold a fish from your <b>backpack</b> (bottom bar) and click to put it in your <b>aquarium</b>. Fish there make money!",
			Target = positionOf(plot and plot:FindFirstChild("Aquario")),
			Label = "AQUARIUM",
		}
	elseif step == 3 then
		if running then
			return nil
		end
		local plot = myPlot()
		local treadmill = plot and plot:FindFirstChild("Esteira")
		return {
			Index = 4,
			Text = "Run on the <b>treadmill</b> to gain <b>stamina</b>. Stronger fish need more stamina!",
			Target = positionOf(treadmill and treadmill:FindFirstChild("Zona")),
			Label = "TREADMILL",
		}
	end
	return nil
end

-- marca o passo como feito (o servidor guarda)
local sent = {}
local function complete(step)
	local data = ClientState.Data
	if not data or (data.Tut or DONE) >= step or sent[step] then
		return
	end
	sent[step] = true
	data.Tut = step -- já atualiza aqui, sem esperar a próxima foto
	task.spawn(function()
		ClientState.Request("Tutorial", step)
	end)
	if step >= DONE then
		ClientState.Toast("Tutorial complete! Have fun riding fish! 🐟", "ok")
	end
end

skip.Activated:Connect(function()
	complete(DONE)
end)

-- o que conclui cada passo
player:GetAttributeChangedSignal("Running"):Connect(function()
	local data = ClientState.Data
	if not data then
		return
	end
	if player:GetAttribute("Running") then
		complete(1)
	elseif (data.Tut or DONE) == 1 then
		complete(2)
	end
end)
player:GetAttributeChangedSignal("Training"):Connect(function()
	local data = ClientState.Data
	if data and player:GetAttribute("Training") and (data.Tut or DONE) == 3 then
		complete(4)
	end
end)
ClientState.Changed.Event:Connect(function(data)
	if (data.Tut or DONE) == 2 and #(data.Aquarium or {}) > 0 then
		complete(3)
	end
end)

local shownIndex = nil
RunService.RenderStepped:Connect(function()
	local data = ClientState.Data
	local step = data and currentStep(data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not step or not root then
		card.Visible = false
		setArrowsVisible(false)
		shownIndex = nil
		return
	end
	if shownIndex ~= step.Index then
		shownIndex = step.Index
		card.Visible = true
		stepLabel.Text = ("TUTORIAL  %d/%d"):format(step.Index, DONE)
		textLabel.Text = step.Text
		cardScale.Scale = 0.7
		UIKit.Tween(cardScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		-- na corrida o cartão sobe (lá embaixo ficam as dicas e o botão de pular)
		card.Position = step.Target and UDim2.new(0.5, 0, 1, -130) or UDim2.new(0.5, 0, 0, 250)
		card.AnchorPoint = step.Target and Vector2.new(0.5, 1) or Vector2.new(0.5, 0)
	end
	if step.Target then
		rayParams.FilterDescendantsInstances = { character, folder }
		setArrowsVisible(true)
		markerText.Text = step.Label or ""
		drawArrows(root, step.Target, os.clock())
	else
		setArrowsVisible(false)
	end
end)
