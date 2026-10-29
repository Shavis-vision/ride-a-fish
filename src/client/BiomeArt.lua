-- BiomeArt (ModuleScript)
-- Fica em: StarterPlayerScripts > Client > BiomeArt
--
-- O "quadro" de cada bioma (usado na barra da corrida e no índex).
--   * Se Config.BIOME_IMAGES[área] tiver um ID de imagem (subida no Creator Hub), mostra a
--     imagem pintada.
--   * Senão, mostra uma cena 3D pequena (ReplicatedStorage > BiomeIcons > "1"/"2"/"3") em cima
--     de um fundo "pintado": degradê da água, raios de luz e bolhas.
--
--   BiomeArt.Picture(parent, areaIndex, { ZIndex = 1, Zoom = 1 }) -> Frame

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Track = require(Shared:WaitForChild("Track"))

local BiomeArt = {}

-- cor da borda de cada bioma (bem viva, como nos jogos de referência)
BiomeArt.BorderColors = {
	Color3.fromRGB(80, 220, 255), -- Shallow Reef
	Color3.fromRGB(110, 235, 90), -- Kelp Forest
	Color3.fromRGB(170, 100, 255), -- The Abyss
}

local function gradient(frame, top, bottom)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = frame
end

function BiomeArt.Picture(parent, areaIndex, opts)
	opts = opts or {}
	local z = opts.ZIndex or 1
	local area = Track.Areas[areaIndex]
	local holder = Instance.new("Frame")
	holder.Name = "BiomeArt"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundColor3 = Color3.new(1, 1, 1)
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.ZIndex = z
	holder.Parent = parent

	local imageId = Config.BIOME_IMAGES and Config.BIOME_IMAGES[areaIndex]
	if imageId and imageId ~= 0 then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = "rbxassetid://" .. imageId
		image.ScaleType = Enum.ScaleType.Crop
		image.ZIndex = z
		image.Parent = holder
		return holder
	end

	-- fundo "pintado": água clara em cima, escura embaixo
	local fog = area and area.FogColor or Color3.fromRGB(60, 150, 200)
	gradient(holder, fog:Lerp(Color3.new(1, 1, 1), 0.45), fog:Lerp(Color3.new(0, 0, 0), 0.45))
	-- raios de luz descendo
	for i = 1, 3 do
		local ray = Instance.new("Frame")
		ray.BackgroundColor3 = Color3.new(1, 1, 1)
		ray.BackgroundTransparency = 0.82
		ray.BorderSizePixel = 0
		ray.Size = UDim2.new(0.12, 0, 1.4, 0)
		ray.Position = UDim2.new(0.12 + i * 0.22, 0, -0.2, 0)
		ray.Rotation = 18
		ray.ZIndex = z
		ray.Parent = holder
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new(0.2, 1)
		fade.Parent = ray
	end
	-- bolhas
	for i, p in ipairs({ { 0.15, 0.3, 0.06 }, { 0.82, 0.22, 0.05 }, { 0.7, 0.5, 0.035 }, { 0.25, 0.6, 0.04 } }) do
		local bubble = Instance.new("Frame")
		bubble.Name = "Bolha" .. i
		bubble.BackgroundColor3 = Color3.new(1, 1, 1)
		bubble.BackgroundTransparency = 0.55
		bubble.Size = UDim2.fromScale(p[3], p[3])
		bubble.SizeConstraint = Enum.SizeConstraint.RelativeXX
		bubble.Position = UDim2.fromScale(p[1], p[2])
		bubble.ZIndex = z + 1
		bubble.Parent = holder
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = bubble
	end

	-- a cena 3D
	local icons = ReplicatedStorage:FindFirstChild("BiomeIcons")
	local template = icons and icons:FindFirstChild(tostring(areaIndex))
	if template then
		local viewport = Instance.new("ViewportFrame")
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.Ambient = Color3.fromRGB(200, 200, 210)
		viewport.LightColor = Color3.new(1, 1, 1)
		viewport.LightDirection = Vector3.new(-0.5, -1, -0.4)
		viewport.ZIndex = z + 1
		local model = template:Clone()
		model.Parent = viewport
		local cf, size = model:GetBoundingBox()
		local camera = Instance.new("Camera")
		camera.FieldOfView = 32
		local radius = math.max(size.X, size.Y, size.Z) / (opts.Zoom or 1)
		camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(radius * 0.25, radius * 0.35, radius * 1.65), cf.Position + Vector3.new(0, -size.Y * 0.08, 0))
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		viewport.Parent = holder
	end
	return holder
end

return BiomeArt
