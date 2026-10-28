-- TrainingFx (LocalScript)
-- Fica em: StarterPlayerScripts > Client > TrainingFx
--
-- Enquanto você corre na esteira, números "+N" (a stamina ganha) e raios ⚡ saltam do
-- personagem, sobem e somem — como o "+2" a cada passo dos jogos de esteira.
-- Só roda no seu computador e só para você (não pesa para os outros).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NumberFormat"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INTERVAL = 0.45 -- segundos entre cada "+N"
local LIFE = 1.0 -- quanto tempo cada número fica na tela
local MAX_ALIVE = 8

local alive = 0
local random = Random.new()

local function pop(root, text, isIcon)
	if alive >= MAX_ALIVE then
		return
	end
	alive += 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "TrainingPop"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromScale(isIcon and 1.6 or 3.2, 1.6)
	gui.ResetOnSpawn = false
	local start = Vector3.new(random:NextNumber(-2.6, 2.6), random:NextNumber(0.5, 2.2), random:NextNumber(-1.5, 1.5))
	gui.StudsOffsetWorldSpace = start

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = isIcon and Color3.fromRGB(255, 225, 60) or Color3.fromRGB(235, 235, 245)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(40, 40, 50)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	gui.Parent = playerGui

	-- entra "estourando", sobe devagar e some
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(LIFE, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = start + Vector3.new(0, 3.2, 0),
	}):Play()
	task.delay(LIFE * 0.55, function()
		local fade = TweenInfo.new(LIFE * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	end)
	task.delay(LIFE + 0.05, function()
		gui:Destroy()
		alive -= 1
	end)
end

local elapsed = 0
local count = 0
RunService.Heartbeat:Connect(function(dt)
	if player:GetAttribute("Training") ~= true then
		elapsed = 0
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	elapsed += dt
	if elapsed < INTERVAL then
		return
	end
	elapsed -= INTERVAL
	count += 1
	local rate = player:GetAttribute("StaminaRate") or 0
	local gain = rate * INTERVAL
	if gain > 0 then
		pop(root, "+" .. NumberFormat.Rate(gain), false)
	end
	if count % 2 == 0 then
		pop(root, "⚡", true)
	end
end)
