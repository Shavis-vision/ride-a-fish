-- Brick (ModuleScript)
-- Fica em: ReplicatedStorage > Shared > Brick
--
-- Atalho para criar peças com cara de Lego: material Plastic e studs (bolinhas) em cima.
-- Usado pelo mapa (MapService) e pelo modelo do peixe (FishModel).
--
--   Brick.Part(parent, {
--       Size = Vector3, CFrame = CFrame (ou Position = Vector3), Color = Color3,
--       Class = "Part" | "WedgePart" | "CornerWedgePart", Shape = Enum.PartType.Cylinder,
--       Studs = false (sem bolinhas), Transparency = 0.5, CanCollide = false,
--       Material = Enum.Material.Neon, Anchored = false, Name = "Nome",
--   })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Brick = {}

-- Studs grandes (textura) em cima das peças, como nas referências. Enquanto
-- Config.STUD_TEXTURE for 0, usa os studs normais do Roblox (pequenos).
local STUD_IMAGE = (Config.STUD_TEXTURE or 0) ~= 0 and ("rbxassetid://" .. tostring(Config.STUD_TEXTURE)) or nil
local STUD_SPACING = Config.STUD_SPACING or 2

local function addStudTexture(part)
	local texture = Instance.new("Texture")
	texture.Name = "Studs"
	texture.Texture = STUD_IMAGE
	texture.Face = Enum.NormalId.Top
	texture.StudsPerTileU = STUD_SPACING
	texture.StudsPerTileV = STUD_SPACING
	-- alinha os studs entre peças vizinhas (para peças retas)
	local corner = part.CFrame.Position - part.Size / 2
	texture.OffsetStudsU = -(corner.X % STUD_SPACING)
	texture.OffsetStudsV = -(corner.Z % STUD_SPACING)
	texture.Parent = part
end

function Brick.Part(parent, props)
	local part = Instance.new(props.Class or "Part")
	part.Name = props.Name or "Brick"
	part.Anchored = props.Anchored ~= false
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Size = props.Size
	if props.CFrame then
		part.CFrame = props.CFrame
	elseif props.Position then
		part.CFrame = CFrame.new(props.Position)
	end
	part.Color = props.Color or Color3.new(1, 1, 1)
	part.Material = props.Material or Enum.Material.SmoothPlastic -- liso, sem o "chuvisco" do Plastic
	local wantsStuds = props.Studs ~= false
	-- textura só em peças com topo de pelo menos 2x2 studs (peixes e detalhes ficam lisos)
	local textured = wantsStuds and STUD_IMAGE ~= nil and part.Size.X >= 2 and part.Size.Z >= 2 and (props.Class == nil or props.Class == "Part") and props.Shape == nil
	part.TopSurface = (wantsStuds and not textured) and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
	if textured then
		addStudTexture(part)
	end
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = props.Transparency or 0
	part.Reflectance = props.Reflectance or 0
	if props.CanCollide ~= nil then
		part.CanCollide = props.CanCollide
	end
	if props.CanCollide == false then
		part.CanTouch = props.CanTouch == true
		part.CanQuery = props.CanQuery == true
	end
	if props.CastShadow ~= nil then
		part.CastShadow = props.CastShadow
	end
	part.Parent = parent
	return part
end

-- O Roblox não deixa uma peça passar de 2048 studs em nenhum lado: caixas maiores que isso
-- são divididas em pedaços.
local MAX_PART = 2000

-- Caixa a partir de dois cantos (mais fácil para chão e paredes).
function Brick.Box(parent, minCorner, maxCorner, props)
	props = props or {}
	local low = Vector3.new(math.min(minCorner.X, maxCorner.X), math.min(minCorner.Y, maxCorner.Y), math.min(minCorner.Z, maxCorner.Z))
	local high = Vector3.new(math.max(minCorner.X, maxCorner.X), math.max(minCorner.Y, maxCorner.Y), math.max(minCorner.Z, maxCorner.Z))
	local size = high - low
	if size.X > MAX_PART or size.Z > MAX_PART or size.Y > MAX_PART then
		local first = nil
		local alongX = size.X >= size.Z and size.X >= size.Y
		local alongZ = not alongX and size.Z >= size.Y
		local length = alongX and size.X or alongZ and size.Z or size.Y
		local pieces = math.ceil(length / MAX_PART)
		for i = 0, pieces - 1 do
			local a = i / pieces
			local b = (i + 1) / pieces
			local pieceLow, pieceHigh
			if alongX then
				pieceLow = Vector3.new(low.X + size.X * a, low.Y, low.Z)
				pieceHigh = Vector3.new(low.X + size.X * b, high.Y, high.Z)
			elseif alongZ then
				pieceLow = Vector3.new(low.X, low.Y, low.Z + size.Z * a)
				pieceHigh = Vector3.new(high.X, high.Y, low.Z + size.Z * b)
			else
				pieceLow = Vector3.new(low.X, low.Y + size.Y * a, low.Z)
				pieceHigh = Vector3.new(high.X, low.Y + size.Y * b, high.Z)
			end
			local part = Brick.Box(parent, pieceLow, pieceHigh, table.clone(props))
			first = first or part
		end
		return first
	end
	props.Size = size
	props.CFrame = CFrame.new((low + high) / 2)
	return Brick.Part(parent, props)
end

-- Clareia (amount > 0) ou escurece (amount < 0) uma cor.
function Brick.Shade(color, amount)
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

function Brick.Folder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Brick.Model(parent, name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

return Brick
