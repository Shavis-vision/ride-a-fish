-- WorldFx (LocalScript)
-- Fica em: StarterPlayerScripts > Client > WorldFx
--
-- Efeitos que só rodam no seu computador:
--   * debaixo d'água: tela azulada, neblina da área (Recife, Algas, Abismo) e bolhas subindo;
--   * anéis das barracas: pisou, a loja abre; saiu, fecha;
--   * esteira: animação de correr e a esteira andando enquanto você treina;
--   * aquários: os peixes balançam a cauda e boiam;
--   * placas de melhoria dos lotes dos outros ficam sem o botão "E".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Track = require(Shared:WaitForChild("Track"))
local Layout = require(Shared:WaitForChild("Layout"))
local FishModel = require(Shared:WaitForChild("FishModel"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local map = Workspace:WaitForChild("Map")
local plots = map:WaitForChild("Lotes")

-- Debaixo d'água -----------------------------------------------------------------------------
local surface = {
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
	FogColor = Lighting.FogColor,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
}
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "Submarino"
tint.Enabled = false
tint.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Name = "SubmarinoBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting

local bubblesGui = UIKit.Gui("Bolhas", 0)
bubblesGui.Enabled = false

local underwater = false
local fogColor = Track.Areas[1].FogColor
local fogEnd = Track.Areas[1].FogEnd

local function setUnderwater(value)
	if value == underwater then
		return
	end
	underwater = value
	tint.Enabled = value
	blur.Enabled = value
	bubblesGui.Enabled = value
	if value then
		if atmosphere then
			atmosphere.Parent = nil
		end
		Lighting.FogStart = 6
	else
		if atmosphere then
			atmosphere.Parent = Lighting
		end
		for key, v in pairs(surface) do
			Lighting[key] = v
		end
	end
end

local bubbleClock = 0
local function spawnBubble()
	local size = math.random(8, 22)
	local bubble = UIKit.Frame(bubblesGui, {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.new(math.random(), 0, 1, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Color3.fromRGB(220, 245, 255),
		Transparency = 0.55,
		Corner = 999,
		Stroke = 1.5,
		StrokeColor = Color3.fromRGB(255, 255, 255),
	})
	local duration = math.random(25, 45) / 10
	UIKit.Tween(bubble, duration, {
		Position = UDim2.new(bubble.Position.X.Scale + (math.random() - 0.5) * 0.08, 0, -0.05, 0),
		BackgroundTransparency = 0.9,
	}, Enum.EasingStyle.Sine)
	task.delay(duration, function()
		bubble:Destroy()
	end)
end

RunService.RenderStepped:Connect(function(dt)
	local position = camera.CFrame.Position
	setUnderwater(position.Y < Track.WATER_Y - 0.3)
	if not underwater then
		return
	end
	local dist = Track.DistOf(position.Z)
	local area = Track.AreaAt(math.max(0, dist))
	local k = math.min(1, dt * 1.5)
	fogColor = fogColor:Lerp(area.FogColor, k)
	fogEnd += (area.FogEnd - fogEnd) * k
	Lighting.FogColor = fogColor
	Lighting.FogEnd = fogEnd
	local depth = math.clamp((Track.WATER_Y - position.Y) / 110, 0, 1)
	Lighting.Ambient = fogColor:Lerp(Color3.fromRGB(150, 160, 170), 0.5 - depth * 0.3)
	Lighting.OutdoorAmbient = fogColor:Lerp(Color3.fromRGB(170, 190, 210), 0.5 - depth * 0.3)
	Lighting.Brightness = surface.Brightness * (1 - depth * 0.6)
	tint.TintColor = tint.TintColor:Lerp(area.Tint, k)
	tint.Brightness = area.Brightness
	tint.Contrast = 0.05
	tint.Saturation = 0.1
	blur.Size = 2

	bubbleClock += dt
	if bubbleClock > 0.22 then
		bubbleClock = 0
		spawnBubble()
	end
end)

-- Anéis das barracas ----------------------------------------------------------------------------
local inside = {}
local ringClock = 0
RunService.Heartbeat:Connect(function(dt)
	ringClock += dt
	if ringClock < 0.15 then
		return
	end
	ringClock = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or player:GetAttribute("Running") then
		return
	end
	for _, ring in ipairs(Layout.ShopRings) do
		local offset = root.Position - ring.Position
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		local isInside = flat < ring.Radius and math.abs(offset.Y) < 8
		if isInside and not inside[ring.Shop] then
			inside[ring.Shop] = true
			UIKit.OpenWindow(ring.Shop)
		elseif not isInside and inside[ring.Shop] then
			inside[ring.Shop] = false
			local window = UIKit.Windows[ring.Shop]
			if window and window.IsOpen then
				window.Close()
			end
		end
	end
end)

-- Placas: só o dono vê o botão de melhorar ------------------------------------------------------
local function updatePrompts(model)
	local mine = model:GetAttribute("Owner") == player.UserId
	for _, prompt in ipairs(model:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = mine
		end
	end
end
for _, model in ipairs(plots:GetChildren()) do
	updatePrompts(model)
	model:GetAttributeChangedSignal("Owner"):Connect(function()
		updatePrompts(model)
	end)
end

-- Esteira: correr e esteira andando ----------------------------------------------------------
local runTrack = nil
local function setTrainingAnimation(training)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if training then
		if runTrack or not animator then
			return
		end
		local animate = character:FindFirstChild("Animate")
		local runFolder = animate and animate:FindFirstChild("run")
		local animation = runFolder and runFolder:FindFirstChildOfClass("Animation")
		if animation then
			runTrack = animator:LoadAnimation(animation)
			runTrack.Priority = Enum.AnimationPriority.Movement
			runTrack.Looped = true
			runTrack:Play(0.2)
		end
	elseif runTrack then
		runTrack:Stop(0.2)
		runTrack = nil
	end
end
player:GetAttributeChangedSignal("Training"):Connect(function()
	setTrainingAnimation(player:GetAttribute("Training") == true)
end)
player.CharacterAdded:Connect(function()
	runTrack = nil
end)

local stripeBase = {}
local function stripesOf(model)
	local treadmill = model:FindFirstChild("Esteira")
	local folder = treadmill and treadmill:FindFirstChild("Listras")
	local base = treadmill and treadmill:FindFirstChild("Base")
	if not folder or not base then
		return nil
	end
	if not stripeBase[model] then
		local list = {}
		for _, stripe in ipairs(folder:GetChildren()) do
			table.insert(list, { Part = stripe, Offset = base.CFrame:ToObjectSpace(stripe.CFrame) })
		end
		stripeBase[model] = { Base = base, List = list }
	end
	return stripeBase[model]
end

local function ownerTraining(model)
	local ownerId = model:GetAttribute("Owner")
	if not ownerId then
		return false
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	return owner ~= nil and owner:GetAttribute("Training") == true
end

local beltShift = 0
RunService.RenderStepped:Connect(function(dt)
	beltShift = (beltShift + dt * 9) % 2
	local t = os.clock()
	for _, model in ipairs(plots:GetChildren()) do
		-- esteira
		if ownerTraining(model) then
			local info = stripesOf(model)
			if info then
				for _, item in ipairs(info.List) do
					local z = item.Offset.Position.Z - beltShift
					if z < -7.8 then
						z += 16
					end
					item.Part.CFrame = info.Base.CFrame * CFrame.new(item.Offset.Position.X, item.Offset.Position.Y, z)
				end
			end
		end
		-- peixes do aquário
		local aquarium = model:FindFirstChild("Aquario")
		local folder = aquarium and aquarium:FindFirstChild("Peixes")
		if folder then
			for _, fish in ipairs(folder:GetChildren()) do
				local rootPart = fish.PrimaryPart
				local baseY = fish:GetAttribute("BaseY")
				if rootPart and baseY then
					local phase = fish:GetAttribute("Bob") or 0
					local cf = rootPart.CFrame
					local p = cf.Position
					rootPart.CFrame = CFrame.new(p.X, baseY + math.sin(t * 1.4 + phase) * 0.45, p.Z) * cf.Rotation
					FishModel.Wag(fish, t + phase, 5)
				end
			end
		end
	end
end)
