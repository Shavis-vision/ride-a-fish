-- FishModel (ModuleScript)
-- Fica em: ReplicatedStorage > Shared > FishModel
--
-- O modelo 3D do peixe, feito de peças estilo Lego. Cada espécie tem uma FAMÍLIA de forma
-- (peixe, tubarão, arraia, tartaruga, baiacu, cavalo-marinho, enguia, lula) e detalhes
-- (bico, lanterna, dentes...). A cor vem da espécie e da mutação (prata, dourado...).
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

local meshFolder, buildFromMesh -- (definidas mais abaixo)

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

-- Família (forma do corpo) e detalhes de cada espécie. Quem não está aqui é "Peixe".
--   Bill = bico comprido, Sail = vela nas costas, Lure = lanterna na testa, Teeth = dentes,
--   BigMouth = boca grande, Wings = barbatanas laterais grandes, TallFins = barbatanas altas,
--   Hammer = cabeça de martelo
local LOOK = {
	baiacu = { Family = "Baiacu" },
	cavalo = { Family = "Cavalo" },
	tartaruga = { Family = "Tartaruga" },
	arraia = { Family = "Arraia" },
	voador = { Wings = true },
	garoupa = { BigMouth = true },
	barracuda = { Teeth = true },
	peixelua = { TallFins = true },
	espada = { Bill = true },
	martelo = { Family = "Tubarao", Hammer = true },
	marlin = { Bill = true, Sail = true },
	branco = { Family = "Tubarao" },
	lanterna = { Lure = true },
	vibora = { Teeth = true, Lure = true },
	pescador = { BigMouth = true, Teeth = true, Lure = true },
	enguia = { Family = "Enguia" },
	lula = { Family = "Lula" },
	duende = { Family = "Tubarao", Bill = true },
	leviata = { Family = "Tubarao" },
}
FishModel.Look = LOOK


-- Modelos 3D prontos -----------------------------------------------------------------------
-- Ficam em ReplicatedStorage > FishMeshes > <id da espécie> (um Model com uma MeshPart, já
-- virado para -Z e centrado na origem). Se a espécie não tiver modelo pronto, o peixe é
-- montado com peças, como antes.
local cachedFolder = nil
meshFolder = function()
	if cachedFolder == nil then
		cachedFolder = ReplicatedStorage:FindFirstChild("FishMeshes") or false
	end
	return cachedFolder or nil
end

-- Mutação num modelo pintado: tira a pintura e aplica a cor/material da mutação.
local MESH_MUTATION = {
	Prata = { Color = Color3.fromRGB(190, 200, 215), Material = Enum.Material.SmoothPlastic, Reflectance = 0.15 },
	Dourado = { Color = Color3.fromRGB(245, 170, 20), Material = Enum.Material.SmoothPlastic, Reflectance = 0.12 },
	Diamante = { Color = Color3.fromRGB(130, 235, 255), Material = Enum.Material.Glass, Reflectance = 0.25, Transparency = 0.15 },
	ArcoIris = { Color = Color3.fromRGB(255, 130, 230), Material = Enum.Material.ForceField, Reflectance = 0 },
}

buildFromMesh = function(template, species, mutation, size, s, L, palette, opts, family)
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

	local source = template:FindFirstChildWhichIsA("MeshPart", true)
	local body = source:Clone()
	body.Name = "Body"
	-- tamanho: a maior medida do modelo vira o comprimento do peixe deste tamanho
	local extents = function(cf, sizeV)
		local r = cf.Rotation
		local x, y, z = r:VectorToWorldSpace(Vector3.new(sizeV.X, 0, 0)), r:VectorToWorldSpace(Vector3.new(0, sizeV.Y, 0)), r:VectorToWorldSpace(Vector3.new(0, 0, sizeV.Z))
		return Vector3.new(
			math.abs(x.X) + math.abs(y.X) + math.abs(z.X),
			math.abs(x.Y) + math.abs(y.Y) + math.abs(z.Y),
			math.abs(x.Z) + math.abs(y.Z) + math.abs(z.Z)
		)
	end
	local srcExt = extents(source.CFrame, source.Size)
	local biggest = math.max(srcExt.X, srcExt.Y, srcExt.Z)
	local target = (template:GetAttribute("Length") or 6.5) * (L / 5)
	local k = target / biggest
	body.Size = source.Size * k
	-- mantém o giro e o centro do modelo pronto (ele já olha para -Z)
	body.CFrame = source.CFrame.Rotation + source.CFrame.Position * k
	body.Anchored = false
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Massless = true
	local look = MESH_MUTATION[mutation]
	if look then
		body.TextureID = ""
		body.Color = look.Color
		body.Material = look.Material
		body.Reflectance = look.Reflectance
		body.Transparency = look.Transparency or 0
	end
	body.Parent = model

	-- o corpo inteiro ondula (o modelo é uma peça só)
	local joint = Instance.new("Motor6D")
	joint.Name = "BodyJoint"
	joint.Part0 = root
	joint.Part1 = body
	joint.Parent = root

	joint.C0 = body.CFrame
	local ext = extents(body.CFrame, body.Size)
	local W, H, Lm = ext.X, ext.Y, ext.Z
	local seatY = H * (template:GetAttribute("SeatY") or 0.42)
	local seatZ = Lm * (template:GetAttribute("SeatZ") or -0.05)

	local function attach(props)
		props.Anchored = false
		props.CanCollide = false
		props.Studs = false
		local part = Brick.Part(model, props)
		part.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = body
		weld.Part1 = part
		weld.C0 = body.CFrame:Inverse() * props.CFrame
		weld.Parent = part
		return part
	end
	if opts.Saddle ~= false then
		-- sela do tamanho do peixe, encostada e INCLINADA como as costas dele (SeatY, SeatZ e
		-- SeatPitch foram medidos no Studio com raios em cima do modelo)
		local pitch = template:GetAttribute("SeatPitch") or 0
		local seatCF = CFrame.new(0, seatY, seatZ) * CFrame.Angles(pitch, 0, 0)
		local sw = math.min(W * 0.75, 2.8 * s) * (template:GetAttribute("SaddleScale") or 1)
		local saddleTemplate = meshFolder():FindFirstChild("_Sela")
		local saddleMesh = saddleTemplate and saddleTemplate:FindFirstChildWhichIsA("MeshPart", true)
		if saddleMesh then
			-- modelo 3D de sela (mesmo estilo low poly dos peixes)
			local part = saddleMesh:Clone()
			part.Name = "Saddle"
			local k2 = sw / saddleMesh.Size.X
			part.Size = saddleMesh.Size * k2
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			local cf = seatCF * CFrame.new(0, part.Size.Y * 0.35, 0)
			part.CFrame = cf
			part.Parent = model
			local weld = Instance.new("Weld")
			weld.Part0 = body
			weld.Part1 = part
			weld.C0 = body.CFrame:Inverse() * cf
			weld.Parent = part
			seatY += part.Size.Y * 0.35
		else
			local sl = math.min(Lm * 0.32, 2.1 * s)
			local t = 0.22 * s
			attach({ Name = "Blanket", Size = Vector3.new(sw + 0.3 * s, t, sl), CFrame = seatCF * CFrame.new(0, t / 2, 0), Color = BLANKET })
			attach({ Name = "Saddle", Size = Vector3.new(sw * 0.72, 0.4 * s, sl * 0.65), CFrame = seatCF * CFrame.new(0, t + 0.2 * s, 0), Color = SADDLE })
			attach({ Name = "SaddleBack", Size = Vector3.new(sw * 0.72, 0.45 * s, 0.3 * s), CFrame = seatCF * CFrame.new(0, t + 0.42 * s, sl * 0.3), Color = SADDLE })
		end
	end

	if palette.Sparkle then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = palette.Sparkle
		sparkles.Parent = body
	end

	model:SetAttribute("Species", species.Id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Size", size)
	model:SetAttribute("Family", family)
	model:SetAttribute("Mesh", true)
	model:SetAttribute("SeatY", seatY + 0.6 * s)
	model:SetAttribute("SeatZ", seatZ)
	model:SetAttribute("Length", Lm)
	model:SetAttribute("Height", H)
	model:SetAttribute("Width", W)
	return model
end

-- Monta o peixe. opts: { Saddle = true/false, Scale = número (sobrepõe o tamanho), Anchored = true }
function FishModel.Build(speciesId, mutation, size, opts)
	opts = opts or {}
	local species = Fish.Get(speciesId) or Fish.Species[1]
	mutation = mutation or "Normal"
	size = size or "Normal"
	local look = LOOK[species.Id] or {}
	local family = look.Family or "Peixe"

	local sizeDef = Fish.Sizes[size] or Fish.Sizes.Normal
	local s = opts.Scale or sizeDef.Scale
	local shape = species.Shape or {}
	local L = 5 * (shape.Length or 1) * s
	local H = 3 * (shape.Height or 1) * s
	local W = 2.4 * s

	local palette = paletteFor(species, mutation)

	-- Modelo 3D pronto (gerado no Studio) para esta espécie? Usa ele no lugar das peças.
	local template = meshFolder() and meshFolder():FindFirstChild(species.Id)
	if template then
		return buildFromMesh(template, species, mutation, size, s, L, palette, opts, family)
	end

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

	-- peça soldada ao root (ou a outra peça). Peixes ficam lisos (sem studs).
	local function piece(props, attachTo)
		props.Anchored = false
		props.CanCollide = false
		props.Reflectance = props.Reflectance or palette.Reflectance
		if props.Studs == nil then
			props.Studs = false
		end
		local part = Brick.Part(model, props)
		part.Massless = true
		local base = attachTo or root
		local weld = Instance.new("Weld")
		weld.Part0 = base
		weld.Part1 = part
		weld.C0 = base.CFrame:ToObjectSpace(part.CFrame)
		weld.C1 = CFrame.new()
		weld.Parent = part
		return part
	end
	local function box(name, size3, cf, key, extra)
		local props = { Name = name, Size = size3, CFrame = cf, Color = typeof(key) == "Color3" and key or color(key) }
		if extra then
			for k, v in pairs(extra) do
				props[k] = v
			end
		end
		return piece(props, extra and extra.AttachTo)
	end
	local function wedge(name, size3, cf, key, attachTo)
		return piece({ Name = name, Class = "WedgePart", Size = size3, CFrame = cf, Color = typeof(key) == "Color3" and key or color(key) }, attachTo)
	end
	local function ball(name, d, pos, c, extra)
		local props = { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = CFrame.new(pos), Color = c, Reflectance = 0 }
		if extra then
			for k, v in pairs(extra) do
				props[k] = v
			end
		end
		return piece(props)
	end
	-- olhos dos dois lados: branco, pupila e um brilhinho (dá vida ao modelo)
	local function eyes(x, y, z, d)
		for _, side in ipairs({ -1, 1 }) do
			ball("Eye", d, Vector3.new(side * x, y, z), WHITE)
			ball("Pupil", d * 0.58, Vector3.new(side * (x + d * 0.24), y, z - d * 0.08), BLACK)
			ball("Shine", d * 0.2, Vector3.new(side * (x + d * 0.42), y + d * 0.16, z - d * 0.2), WHITE, { Material = Enum.Material.Neon })
		end
	end

	-- cauda que balança (Motor6D "TailJoint", usada por FishModel.Wag)
	local function tailJoint(z, y)
		local tailRoot = Brick.Part(model, {
			Name = "TailRoot",
			Size = Vector3.new(0.2, 0.2, 0.2) * s,
			CFrame = CFrame.new(0, y or 0, z),
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
		joint.C0 = CFrame.new(0, y or 0, z)
		joint.C1 = CFrame.new()
		joint.Parent = root
		return tailRoot
	end
	-- cauda em "V" (duas cunhas abertas)
	local function forkTail(tailRoot, z, height, length, upperBias)
		local up = upperBias or 1
		wedge("TailFin", Vector3.new(0.4 * s, height * 0.5 * up, length), CFrame.new(0, height * 0.25 * up, z + length / 2) * CFrame.Angles(-0.35, 0, 0), "Fin", tailRoot)
		wedge("TailFin", Vector3.new(0.4 * s, height * 0.5, length), CFrame.new(0, -height * 0.25, z + length / 2) * CFrame.Angles(0.35, 0, math.pi), "Fin", tailRoot)
	end

	local seatY, seatZ = H / 2, -L * 0.1
	local totalLength = L
	local body

	if family == "Peixe" or family == "Tubarao" then
		local shark = family == "Tubarao"
		-- corpo afinando: cabeça, meio e traseira (silhueta arredondada em vez de um tijolo)
		body = box("Body", Vector3.new(W, H, L * 0.42), CFrame.new(0, 0, -L * 0.02), "Body")
		box("Head", Vector3.new(W * 0.9, H * 0.86, L * 0.3), CFrame.new(0, H * 0.02, -L * 0.36), "Body")
		box("Rear", Vector3.new(W * 0.78, H * 0.72, L * 0.3), CFrame.new(0, H * 0.04, L * 0.34), "Body")
		-- barriga clara por baixo, acompanhando o corpo
		box("Belly", Vector3.new(W * 1.02, H * (shark and 0.42 or 0.34), L * 0.42), CFrame.new(0, -H * (shark and 0.3 or 0.34), -L * 0.02), "Belly")
		box("Belly", Vector3.new(W * 0.92, H * 0.3, L * 0.3), CFrame.new(0, -H * 0.29, -L * 0.36), "Belly")
		box("Belly", Vector3.new(W * 0.8, H * 0.24, L * 0.3), CFrame.new(0, -H * 0.25, L * 0.34), "Belly")
		if not shark then
			-- listras (a cor de destaque da espécie)
			box("Stripe", Vector3.new(W * 1.04, H * 1.02, 0.55 * s), CFrame.new(0, 0, -L * 0.2), "Stripe")
			box("Stripe", Vector3.new(W * 0.82, H * 0.76, 0.5 * s), CFrame.new(0, H * 0.04, L * 0.24), "Stripe")
		else
			-- guelras
			for i = 0, 2 do
				box("Gill", Vector3.new(W * 0.94, H * 0.4, 0.16 * s), CFrame.new(0, H * 0.02, -L * 0.24 + i * 0.4 * s), Brick.Shade(palette.Body, -0.35))
			end
		end
		-- focinho
		local nose = (shark and 2.2 or 1.4) * s * math.sqrt(shape.Length or 1)
		local headFront = -L * 0.51
		wedge("Nose", Vector3.new(W * 0.84, H * 0.44, nose), CFrame.new(0, H * 0.2, headFront - nose / 2), "Body")
		wedge("Jaw", Vector3.new(W * 0.84, H * (look.BigMouth and 0.5 or 0.36), nose * (shark and 0.7 or 0.85)), CFrame.new(0, -H * 0.2, headFront - nose * (shark and 0.35 or 0.42)) * CFrame.Angles(0, 0, math.pi), "Belly")
		-- boca (linha escura)
		box("Mouth", Vector3.new(W * 0.86, 0.14 * s, nose * 0.7), CFrame.new(0, -H * 0.04, headFront - nose * 0.3), BLACK)
		if look.Teeth or shark then
			for i = 0, 2 do
				wedge("Tooth", Vector3.new(W * 0.8, 0.3 * s, 0.25 * s), CFrame.new(0, -H * 0.1, headFront - nose * 0.15 - i * 0.35 * s) * CFrame.Angles(0, 0, math.pi), WHITE)
			end
		end
		totalLength += nose
		if look.Bill then
			local bill = L * 0.55
			piece({ Name = "Bill", Shape = Enum.PartType.Cylinder, Size = Vector3.new(bill, 0.32 * s, 0.32 * s), CFrame = CFrame.new(0, H * 0.08, headFront - nose - bill / 2 + 0.3 * s) * CFrame.Angles(0, math.pi / 2, 0), Color = color("Fin") })
			totalLength += bill
		end
		if look.Hammer then
			box("Hammer", Vector3.new(W * 3, H * 0.3, 1.3 * s), CFrame.new(0, H * 0.12, headFront - nose * 0.4), "Body")
			for _, side in ipairs({ -1, 1 }) do
				ball("Eye", 0.6 * s, Vector3.new(side * W * 1.5, H * 0.14, headFront - nose * 0.4), WHITE)
				ball("Pupil", 0.36 * s, Vector3.new(side * (W * 1.5 + 0.15 * s), H * 0.14, headFront - nose * 0.4 - 0.1 * s), BLACK)
			end
		else
			eyes(W * 0.42, H * 0.18, -L * 0.4, 0.8 * s)
		end
		if look.Lure then
			-- lanterna na testa (brilha no escuro)
			box("LureStem", Vector3.new(0.18 * s, 0.18 * s, 1.6 * s), CFrame.new(0, H * 0.62, -L * 0.48) * CFrame.Angles(0.7, 0, 0), "Fin")
			local bulb = ball("Lure", 0.6 * s, Vector3.new(0, H * 0.75, -L * 0.62), Color3.fromRGB(150, 255, 230), { Material = Enum.Material.Neon })
			local light = Instance.new("PointLight")
			light.Color = bulb.Color
			light.Range = 10 * s
			light.Brightness = 1.5
			light.Parent = bulb
		end
		-- barbatanas
		local dorsalH = H * (shark and 0.75 or look.TallFins and 0.9 or 0.5)
		if look.Sail then
			wedge("Dorsal", Vector3.new(0.3 * s, H * 1.1, L * 0.7), CFrame.new(0, H / 2 + H * 0.55, L * 0.02) * CFrame.Angles(0, math.pi, 0), "Fin")
		else
			wedge("Dorsal", Vector3.new(0.35 * s, dorsalH, L * (shark and 0.3 or 0.4)), CFrame.new(0, H * 0.43 + dorsalH / 2, L * (shark and 0.02 or 0.08)), "Fin")
		end
		if look.TallFins then
			wedge("Anal", Vector3.new(0.35 * s, dorsalH, L * 0.4), CFrame.new(0, -H * 0.43 - dorsalH / 2, L * 0.08) * CFrame.Angles(0, 0, math.pi), "Fin")
		end
		for _, side in ipairs({ -1, 1 }) do
			local fin = look.Wings and 3.2 or shark and 2 or 1.3
			wedge("SideFin", Vector3.new(fin * s, 0.25 * s, 1.5 * s), CFrame.new(side * (W / 2 + fin * 0.45 * s), -H * 0.2, -L * 0.12) * CFrame.Angles(0, math.pi, side * (look.Wings and 0.15 or 0.45)), "Fin")
		end
		if shape.Spikes then
			for i = 0, 2 do
				wedge("Spike", Vector3.new(0.3 * s, 0.7 * s, 0.6 * s), CFrame.new(0, H * 0.43 + 0.35 * s, -L * 0.36 + i * 0.7 * s), "Fin")
			end
		end
		-- cauda
		box("TailStalk", Vector3.new(W * 0.5, H * 0.42, 1.2 * s), CFrame.new(0, H * 0.04, L / 2 + 0.6 * s), "Body")
		local jointZ = L / 2 + 1.1 * s
		local tail = tailJoint(jointZ, H * 0.04)
		local tailLength = (shark and 2.8 or 2.2) * s
		forkTail(tail, jointZ, H * (shark and 1.5 or 1.3), tailLength, shark and 1.35 or 1)
		totalLength += 1.1 * s + tailLength
		seatY, seatZ = H * 0.43, -L * 0.05
	elseif family == "Baiacu" then
		-- bola cheia de espinhos
		local D = math.max(H, W * 1.3)
		body = ball("Body", D, Vector3.new(), palette.Body, { Reflectance = palette.Reflectance })
		ball("Belly", D * 0.86, Vector3.new(0, -D * 0.12, -D * 0.02), palette.Belly, { Reflectance = palette.Reflectance })
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local dir = Vector3.new(math.cos(a), math.sin(a) * 0.9, 0)
			for _, z in ipairs({ -D * 0.2, D * 0.2 }) do
				local pos = dir * D * 0.48 + Vector3.new(0, 0, z)
				box("Spike", Vector3.new(0.22 * s, 0.22 * s, 0.7 * s), CFrame.lookAt(pos, pos + dir + Vector3.new(0, 0, z > 0 and 0.3 or -0.3)), "Fin")
			end
		end
		eyes(D * 0.34, D * 0.14, -D * 0.3, 0.75 * s)
		box("Mouth", Vector3.new(0.7 * s, 0.4 * s, 0.4 * s), CFrame.new(0, -D * 0.06, -D * 0.5), Brick.Shade(palette.Body, -0.3))
		for _, side in ipairs({ -1, 1 }) do
			wedge("SideFin", Vector3.new(1.1 * s, 0.22 * s, 1 * s), CFrame.new(side * D * 0.52, -D * 0.05, -D * 0.05) * CFrame.Angles(0, math.pi, side * 0.5), "Fin")
		end
		local tail = tailJoint(D * 0.5, 0)
		forkTail(tail, D * 0.5, D * 0.6, 1.4 * s)
		L, H, W = D, D, D
		totalLength = D + 1.4 * s
		seatY, seatZ = D * 0.48, 0
	elseif family == "Tartaruga" then
		-- casco em degraus (domo) com placas, cabeça, nadadeiras
		local SW, SL = W * 1.8, L * 1.0
		body = box("Body", Vector3.new(SW, H * 0.4, SL), CFrame.new(0, -H * 0.05, 0), "Body")
		box("Shell", Vector3.new(SW * 0.82, H * 0.28, SL * 0.84), CFrame.new(0, H * 0.29, 0), "Body")
		box("Shell", Vector3.new(SW * 0.56, H * 0.22, SL * 0.6), CFrame.new(0, H * 0.53, 0), Brick.Shade(palette.Body, 0.08))
		for ix = -1, 1 do
			for iz = -1, 1 do
				box("Plate", Vector3.new(SW * 0.2, 0.1 * s, SL * 0.17), CFrame.new(ix * SW * 0.24, H * 0.44, iz * SL * 0.24), "Stripe")
			end
		end
		box("Plastron", Vector3.new(SW * 0.9, H * 0.16, SL * 0.9), CFrame.new(0, -H * 0.3, 0), "Belly")
		box("Head", Vector3.new(W * 0.6, H * 0.45, 1.6 * s), CFrame.new(0, H * 0.02, -SL / 2 - 0.7 * s), "Belly")
		eyes(W * 0.3, H * 0.12, -SL / 2 - 1.1 * s, 0.55 * s)
		for _, side in ipairs({ -1, 1 }) do
			wedge("Flipper", Vector3.new(2.4 * s, 0.25 * s, 1.4 * s), CFrame.new(side * (SW / 2 + 0.9 * s), -H * 0.15, -SL * 0.28) * CFrame.Angles(0, math.pi + side * 0.5, side * 0.2), "Belly")
			wedge("Flipper", Vector3.new(1.4 * s, 0.25 * s, 1 * s), CFrame.new(side * (SW / 2 + 0.5 * s), -H * 0.18, SL * 0.32) * CFrame.Angles(0, side * 0.6, 0), "Belly")
		end
		local tail = tailJoint(SL / 2, -H * 0.1)
		wedge("Tail", Vector3.new(0.4 * s, 0.4 * s, 0.9 * s), CFrame.new(0, -H * 0.1, SL / 2 + 0.45 * s), "Belly", tail)
		W = SW
		totalLength = SL + 2.4 * s
		seatY, seatZ = H * 0.64, 0
	elseif family == "Arraia" then
		-- corpo chato em losango com asas largas e cauda fina
		local span = W * 3.2
		body = box("Body", Vector3.new(W * 1.1, H * 0.55, L * 0.75), CFrame.new(), "Body")
		box("Belly", Vector3.new(W * 1.12, H * 0.18, L * 0.72), CFrame.new(0, -H * 0.22, 0), "Belly")
		for _, side in ipairs({ -1, 1 }) do
			-- asa: duas cunhas (frente e trás) para formar o triângulo
			wedge("Wing", Vector3.new(span / 2, H * 0.22, L * 0.38), CFrame.new(side * (W * 0.55 + span / 4), 0, -L * 0.19) * CFrame.Angles(0, side * math.pi / 2, 0), "Body")
			wedge("Wing", Vector3.new(span / 2, H * 0.22, L * 0.38), CFrame.new(side * (W * 0.55 + span / 4), 0, L * 0.19) * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi), "Body")
			box("Spot", Vector3.new(span * 0.1, 0.06 * s, span * 0.1), CFrame.new(side * (W * 0.55 + span * 0.12), H * 0.12, 0), "Stripe")
		end
		eyes(W * 0.4, H * 0.24, -L * 0.28, 0.5 * s)
		local tail = tailJoint(L * 0.37, 0)
		piece({ Name = "TailWhip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(L * 0.9, 0.25 * s, 0.25 * s), CFrame = CFrame.new(0, 0, L * 0.37 + L * 0.45) * CFrame.Angles(0, math.pi / 2, 0), Color = color("Fin") }, tail)
		W = span
		totalLength = L * 1.6
		seatY, seatZ = H * 0.28, 0
	elseif family == "Cavalo" then
		-- corpo em pé, curvado, com focinho de tubo e cauda enrolada
		local seg = H * 0.3
		body = box("Body", Vector3.new(W * 0.9, seg * 1.2, L * 0.4), CFrame.new(0, 0, 0), "Body")
		box("Chest", Vector3.new(W * 0.85, seg, L * 0.34), CFrame.new(0, seg * 0.95, -L * 0.06), "Body")
		box("Belly", Vector3.new(W * 0.92, seg * 1.6, L * 0.14), CFrame.new(0, seg * 0.3, -L * 0.2), "Belly")
		box("Head", Vector3.new(W * 0.8, seg * 0.9, L * 0.36), CFrame.new(0, seg * 1.8, -L * 0.14), "Body")
		piece({ Name = "Snout", Shape = Enum.PartType.Cylinder, Size = Vector3.new(L * 0.36, 0.5 * s, 0.5 * s), CFrame = CFrame.new(0, seg * 1.7, -L * 0.48) * CFrame.Angles(0, math.pi / 2, 0), Color = color("Body") })
		eyes(W * 0.38, seg * 1.95, -L * 0.18, 0.55 * s)
		for i = 0, 3 do
			wedge("Crest", Vector3.new(0.25 * s, 0.6 * s, 0.6 * s), CFrame.new(0, seg * 2.2 - i * seg * 0.6, L * 0.06 + i * 0.15 * s), "Fin")
		end
		wedge("Dorsal", Vector3.new(0.25 * s, seg, L * 0.24), CFrame.new(0, seg * 0.2, L * 0.28), "Fin")
		local tail = tailJoint(L * 0.05, -seg * 0.8)
		for i = 0, 3 do
			local a = i * 0.7
			box("Tail", Vector3.new(W * (0.6 - i * 0.1), seg * 0.6, 0.9 * s), CFrame.new(0, -seg * 0.8 - math.sin(a) * seg * 0.8, L * 0.05 + math.cos(a) * 0.9 * s * i * 0.5) * CFrame.Angles(a, 0, 0), "Body", { AttachTo = tail })
		end
		H = seg * 4
		totalLength = L * 1.2
		seatY, seatZ = seg * 0.6, L * 0.08
	elseif family == "Enguia" then
		-- corpo comprido em gomos (o fim balança)
		local n = 5
		local segL = L * 1.3 / n
		body = box("Body", Vector3.new(W * 0.8, H * 0.8, segL * 1.05), CFrame.new(0, 0, -segL), "Body")
		box("Head", Vector3.new(W * 0.85, H * 0.85, segL), CFrame.new(0, H * 0.02, -segL * 2), "Body")
		wedge("Jaw", Vector3.new(W * 0.8, H * 0.4, segL * 0.7), CFrame.new(0, -H * 0.2, -segL * 2.85) * CFrame.Angles(0, 0, math.pi), "Belly")
		wedge("Nose", Vector3.new(W * 0.8, H * 0.42, segL * 0.7), CFrame.new(0, H * 0.21, -segL * 2.85), "Body")
		eyes(W * 0.4, H * 0.2, -segL * 2.1, 0.6 * s)
		box("Segment", Vector3.new(W * 0.75, H * 0.75, segL * 1.05), CFrame.new(0, 0, 0), "Body")
		box("Belly", Vector3.new(W * 0.82, H * 0.24, segL * 3), CFrame.new(0, -H * 0.3, -segL), "Belly")
		wedge("Dorsal", Vector3.new(0.25 * s, H * 0.3, segL * 3), CFrame.new(0, H * 0.52, -segL * 0.5), "Fin")
		local tail = tailJoint(segL * 0.5, 0)
		for i = 1, 3 do
			box("Segment", Vector3.new(W * (0.7 - i * 0.12), H * (0.7 - i * 0.12), segL * 1.05), CFrame.new(0, 0, segL * (0.5 + i - 0.5)), i % 2 == 0 and "Stripe" or "Body", { AttachTo = tail })
		end
		wedge("TailFin", Vector3.new(0.25 * s, H * 0.5, segL), CFrame.new(0, 0, segL * 3.9), "Fin", tail)
		L = segL * n
		totalLength = segL * 7
		seatY, seatZ = H * 0.4, -segL * 0.6
	else -- Lula
		-- manto pontudo na frente, olhos grandes e tentáculos para trás (eles balançam)
		body = box("Body", Vector3.new(W, H * 0.9, L * 0.6), CFrame.new(0, 0, -L * 0.05), "Body")
		box("Mantle", Vector3.new(W * 0.8, H * 0.72, L * 0.3), CFrame.new(0, 0, -L * 0.48), "Body")
		wedge("Tip", Vector3.new(W * 0.7, H * 0.62, L * 0.24), CFrame.new(0, 0, -L * 0.75) * CFrame.Angles(0, 0, 0), "Body")
		for _, side in ipairs({ -1, 1 }) do
			wedge("Fin", Vector3.new(1.6 * s, 0.25 * s, L * 0.3), CFrame.new(side * (W / 2 + 0.7 * s), H * 0.05, -L * 0.55) * CFrame.Angles(0, 0, side * 0.2), "Fin")
		end
		box("Spots", Vector3.new(W * 1.02, H * 0.2, L * 0.4), CFrame.new(0, H * 0.25, -L * 0.1), "Stripe")
		box("Head", Vector3.new(W * 0.9, H * 0.8, L * 0.2), CFrame.new(0, -H * 0.02, L * 0.3), "Belly")
		eyes(W * 0.44, H * 0.08, L * 0.28, 1 * s)
		local tail = tailJoint(L * 0.4, -H * 0.05)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local off = Vector3.new(math.cos(a) * W * 0.3, math.sin(a) * H * 0.25 - H * 0.05, 0)
			local len = (i % 3 == 0) and L * 0.9 or L * 0.6
			box("Tentacle", Vector3.new(0.35 * s, 0.35 * s, len), CFrame.new(off + Vector3.new(0, 0, L * 0.4 + len / 2)), i % 2 == 0 and "Body" or "Fin", { AttachTo = tail })
		end
		totalLength = L * 1.9
		seatY, seatZ = H * 0.45, -L * 0.1
	end

	-- sela (para montar)
	if opts.Saddle ~= false then
		box("Blanket", Vector3.new(math.min(W, 3 * s) + 0.5 * s, 0.25 * s, 2.3 * s), CFrame.new(0, seatY + 0.125 * s, seatZ), BLANKET, { Reflectance = 0 })
		box("Saddle", Vector3.new(math.min(W, 3 * s) * 0.7, 0.45 * s, 1.5 * s), CFrame.new(0, seatY + 0.45 * s, seatZ), SADDLE, { Reflectance = 0 })
		box("SaddleBack", Vector3.new(math.min(W, 3 * s) * 0.7, 0.5 * s, 0.35 * s), CFrame.new(0, seatY + 0.75 * s, seatZ + 0.6 * s), SADDLE, { Reflectance = 0 })
	end

	if palette.Sparkle then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = palette.Sparkle
		sparkles.Parent = body
	end

	model:SetAttribute("Species", species.Id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Size", size)
	model:SetAttribute("Family", family)
	model:SetAttribute("SeatY", seatY + 0.7 * s)
	model:SetAttribute("SeatZ", seatZ)
	model:SetAttribute("Length", totalLength)
	model:SetAttribute("Height", H)
	model:SetAttribute("Width", W)

	return model
end

-- Balança a cauda. `speed` = rapidez do balanço (nadando rápido = maior).
function FishModel.Wag(model, t, speed)
	local root = model.PrimaryPart
	local joint = root and root:FindFirstChild("TailJoint")
	if joint then
		joint.Transform = CFrame.Angles(0, math.sin(t * (speed or 6)) * 0.38, 0)
		return
	end
	-- modelo de peça única: o corpo todo ondula de leve
	local bodyJoint = root and root:FindFirstChild("BodyJoint")
	if bodyJoint then
		local a = t * (speed or 6)
		bodyJoint.Transform = CFrame.Angles(0, math.sin(a) * 0.14, math.sin(a + 1.2) * 0.04)
	end
end

return FishModel
