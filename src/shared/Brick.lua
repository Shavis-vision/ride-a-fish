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

local Brick = {}

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
	part.Material = props.Material or Enum.Material.Plastic
	part.TopSurface = (props.Studs == false) and Enum.SurfaceType.Smooth or Enum.SurfaceType.Studs
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

-- Caixa a partir de dois cantos (mais fácil para chão e paredes).
function Brick.Box(parent, minCorner, maxCorner, props)
	props = props or {}
	local size = maxCorner - minCorner
	props.Size = Vector3.new(math.abs(size.X), math.abs(size.Y), math.abs(size.Z))
	props.CFrame = CFrame.new((minCorner + maxCorner) / 2)
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
