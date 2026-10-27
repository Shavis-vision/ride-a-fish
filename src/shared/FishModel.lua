-- FishModel (ModuleScript)
-- Fica em: ReplicatedStorage > Shared > FishModel
--
-- O modelo 3D do peixe, feito de peças estilo Lego. Por enquanto é UM modelo só para todas
-- as espécies: muda a cor, as proporções (comprimento/altura), os espinhos, a mutação
-- (prata, dourado...) e o tamanho.
--
--   local model = FishModel.Build("palhaco", "Dourado", "Gigante", { Saddle = true })
--   model:PivotTo(CFrame.new(0, 10, 0))
--   FishModel.Wag(model, os.clock())   -- balança a cauda (chame todo quadro)
--
-- O peixe olha para -Z (a frente do modelo). A peça "Root" é a âncora: mova só ela.
-- Atributos do modelo: SeatY/SeatZ (onde senta o jogador), Length, Height, Width.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))
local Brick = require(Shared:WaitForChild("Brick"))

local FishModel = {}

local WHITE = Color3.fromRGB(250, 250, 250)
local BLACK = Color3.fromRGB(20, 20, 25)
local SADDLE = Color3.fromRGB(120, 70, 35)
local BLANKET = Color3.fromRGB(200, 40, 40)

-- Cores finais conforme a mutação
local function paletteFor(species, mutation)
	local c = species.Colors
	local palette = { Body = c.Body, Belly = c.Belly, Fin = c.Fin, Stripe = c.Stripe, Reflectance = 0 }
	if mutation == "Prata" then
		local silver = Color3.fromRGB(210, 220, 235)
		palette.Body = c.Body:Lerp(silver, 0.7)
		palette.Belly = c.Belly:Lerp(WHITE, 0.6)
		palette.Fin = c.Fin:Lerp(silver, 0.5)
		palette.Stripe = c.Stripe:Lerp(silver, 0.4)
		palette.Reflectance = 0.25
	elseif mutation == "Dourado" then
		local gold = Color3.fromRGB(255, 200, 40)
		palette.Body = c.Body:Lerp(gold, 0.8)
		palette.Belly = Color3.fromRGB(255, 235, 150)
		palette.Fin = c.Fin:Lerp(Color3.fromRGB(255, 160, 0), 0.7)
		palette.Stripe = c.Stripe:Lerp(Color3.fromRGB(255, 250, 200), 0.6)
		palette.Reflectance = 0.2
		palette.Sparkle = Color3.fromRGB(255, 220, 80)
	elseif mutation == "Diamante" then
		local diamond = Color3.fromRGB(130, 235, 255)
		palette.Body = c.Body:Lerp(diamond, 0.85)
		palette.Belly = Color3.fromRGB(220, 250, 255)
		palette.Fin = c.Fin:Lerp(Color3.fromRGB(60, 200, 255), 0.7)
		palette.Stripe = Color3.fromRGB(255, 255, 255)
		palette.Reflectance = 0.35
		palette.Sparkle = Color3.fromRGB(150, 240, 255)
	elseif mutation == "ArcoIris" then
		palette.Rainbow = true
		palette.Sparkle = Color3.fromRGB(255, 150, 230)
	end
	return palette
end

local rainbowIndex = 0
local function rainbow()
	rainbowIndex += 1
	return Color3.fromHSV((rainbowIndex * 0.13) % 1, 0.75, 1)
end

-- Monta o peixe. opts: { Saddle = true/false, Scale = número (sobrepõe o tamanho), Anchored = true }
function FishModel.Build(speciesId, mutation, size, opts)
	opts = opts or {}
	local species = Fish.Get(speciesId) or Fish.Species[1]
	mutation = mutation or "Normal"
	size = size or "Normal"

	local sizeDef = Fish.Sizes[size] or Fish.Sizes.Normal
	local s = opts.Scale or sizeDef.Scale
	local shape = species.Shape or {}
	local L = 5 * (shape.Length or 1) * s
	local H = 3 * (shape.Height or 1) * s
	local W = 2.4 * s

	local palette = paletteFor(species, mutation)
	local function color(key)
		if palette.Rainbow then
			return rainbow()
		end
		return palette[key]
	end

	local model = Instance.new("Model")
	model.Name = species.Name

	local root = Brick.Part(model, {
		Name = "Root",
		Size = Vector3.new(1, 1, 1) * s,
		CFrame = CFrame.new(),
		Transparency = 1,
		CanCollide = false,
		Studs = false,
		CastShadow = false,
		Anchored = opts.Anchored ~= false,
	})
	model.PrimaryPart = root

	local function piece(props, attachTo)
		props.Anchored = false
		props.CanCollide = false
		props.Reflectance = props.Reflectance or palette.Reflectance
		local part = Brick.Part(model, props)
		part.Massless = true
		-- Weld com deslocamento fixo (C0): o peixe fica inteiro mesmo se for movido antes de
		-- entrar no Workspace (a WeldConstraint não garante isso)
		local base = attachTo or root
		local weld = Instance.new("Weld")
		weld.Part0 = base
		weld.Part1 = part
		weld.C0 = base.CFrame:ToObjectSpace(part.CFrame)
		weld.C1 = CFrame.new()
		weld.Parent = part
		return part
	end

	-- corpo
	local body = piece({ Name = "Body", Size = Vector3.new(W, H, L), CFrame = CFrame.new(), Color = color("Body") })
	piece({
		Name = "Belly",
		Size = Vector3.new(W + 0.08 * s, H * 0.32, L * 0.92),
		CFrame = CFrame.new(0, -H / 2 + H * 0.16 - 0.04 * s, 0),
		Color = color("Belly"),
		Studs = false,
	})
	for _, z in ipairs({ -L * 0.18, L * 0.22 }) do
		piece({
			Name = "Stripe",
			Size = Vector3.new(W + 0.14 * s, H + 0.18 * s, 0.7 * s),
			CFrame = CFrame.new(0, 0, z),
			Color = color("Stripe"),
		})
	end

	-- focinho (duas cunhas formando uma ponta)
	local noseLength = 1.8 * s * math.sqrt(shape.Length or 1)
	piece({
		Name = "Nose",
		Class = "WedgePart",
		Size = Vector3.new(W * 0.92, H * 0.5, noseLength),
		CFrame = CFrame.new(0, H * 0.25, -L / 2 - noseLength / 2),
		Color = color("Body"),
	})
	piece({
		Name = "Jaw",
		Class = "WedgePart",
		Size = Vector3.new(W * 0.92, H * 0.5, noseLength),
		CFrame = CFrame.new(0, -H * 0.25, -L / 2 - noseLength / 2) * CFrame.Angles(0, 0, math.pi),
		Color = color("Belly"),
		Studs = false,
	})

	-- olhos (um cilindro atravessa a cabeça e aparece dos dois lados)
	piece({
		Name = "Eye",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(W + 0.12 * s, 0.95 * s, 0.95 * s),
		CFrame = CFrame.new(0, H * 0.18, -L / 2 + 0.95 * s),
		Color = WHITE,
		Reflectance = 0,
		Studs = false,
	})
	piece({
		Name = "Pupil",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(W + 0.24 * s, 0.5 * s, 0.5 * s),
		CFrame = CFrame.new(0, H * 0.18, -L / 2 + 0.8 * s),
		Color = BLACK,
		Reflectance = 0,
		Studs = false,
	})

	-- barbatanas
	piece({
		Name = "Dorsal",
		Class = "WedgePart",
		Size = Vector3.new(0.45 * s, H * 0.55, L * 0.45),
		CFrame = CFrame.new(0, H / 2 + H * 0.275, L * 0.08),
		Color = color("Fin"),
	})
	for _, side in ipairs({ -1, 1 }) do
		piece({
			Name = "SideFin",
			Size = Vector3.new(1.4 * s, 0.3 * s, 1.3 * s),
			CFrame = CFrame.new(side * (W / 2 + 0.55 * s), -H * 0.18, -L * 0.08) * CFrame.Angles(0, 0, side * -0.4),
			Color = color("Fin"),
		})
	end

	-- espinhos
	if shape.Spikes then
		for i = 0, 2 do
			piece({
				Name = "Spike",
				Class = "WedgePart",
				Size = Vector3.new(0.3 * s, 0.7 * s, 0.6 * s),
				CFrame = CFrame.new(0, H / 2 + 0.35 * s, -L * 0.38 + i * 0.75 * s),
				Color = color("Fin"),
			})
		end
	end

	-- cauda: um pedaço fixo e as barbatanas que balançam (Motor6D)
	piece({
		Name = "TailStalk",
		Size = Vector3.new(W * 0.55, H * 0.45, 1.4 * s),
		CFrame = CFrame.new(0, 0, L / 2 + 0.7 * s),
		Color = color("Body"),
	})
	local jointZ = L / 2 + 1.3 * s
	local tailRoot = Brick.Part(model, {
		Name = "TailRoot",
		Size = Vector3.new(0.2, 0.2, 0.2) * s,
		CFrame = CFrame.new(0, 0, jointZ),
		Transparency = 1,
		CanCollide = false,
		Studs = false,
		CastShadow = false,
		Anchored = false,
	})
	tailRoot.Massless = true
	local joint = Instance.new("Motor6D")
	joint.Name = "TailJoint"
	joint.Part0 = root
	joint.Part1 = tailRoot
	joint.C0 = CFrame.new(0, 0, jointZ)
	joint.C1 = CFrame.new()
	joint.Parent = root

	local tailLength = 2.4 * s
	piece({
		Name = "TailFin",
		Class = "WedgePart",
		Size = Vector3.new(0.5 * s, H * 0.75, tailLength),
		CFrame = CFrame.new(0, H * 0.375, jointZ + tailLength / 2),
		Color = color("Fin"),
	}, tailRoot)
	piece({
		Name = "TailFin",
		Class = "WedgePart",
		Size = Vector3.new(0.5 * s, H * 0.75, tailLength),
		CFrame = CFrame.new(0, -H * 0.375, jointZ + tailLength / 2) * CFrame.Angles(0, 0, math.pi),
		Color = color("Fin"),
	}, tailRoot)

	-- sela (para montar)
	local seatZ = -L * 0.1
	if opts.Saddle ~= false then
		piece({
			Name = "Blanket",
			Size = Vector3.new(W + 0.5 * s, 0.25 * s, 2.3 * s),
			CFrame = CFrame.new(0, H / 2 + 0.125 * s, seatZ),
			Color = BLANKET,
			Reflectance = 0,
		})
		piece({
			Name = "Saddle",
			Size = Vector3.new(W * 0.75, 0.5 * s, 1.6 * s),
			CFrame = CFrame.new(0, H / 2 + 0.5 * s, seatZ),
			Color = SADDLE,
			Reflectance = 0,
		})
	end

	if palette.Sparkle then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = palette.Sparkle
		sparkles.Parent = body
	end

	model:SetAttribute("Species", species.Id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Size", size)
	model:SetAttribute("SeatY", H / 2 + 0.75 * s)
	model:SetAttribute("SeatZ", seatZ)
	model:SetAttribute("Length", L + noseLength + 1.3 * s + tailLength)
	model:SetAttribute("Height", H)
	model:SetAttribute("Width", W)

	return model
end

-- Balança a cauda. `speed` = rapidez do balanço (nadando rápido = maior).
function FishModel.Wag(model, t, speed)
	local root = model.PrimaryPart
	local joint = root and root:FindFirstChild("TailJoint")
	if joint then
		joint.Transform = CFrame.Angles(0, math.sin(t * (speed or 6)) * 0.45, 0)
	end
end

return FishModel
