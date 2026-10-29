-- SettingsUI (LocalScript)
-- Fica em: StarterPlayerScripts > Client > SettingsUI
--
-- Botão de engrenagem (à direita, embaixo do aquário) que abre as CONFIGURAÇÕES:
--   * volume da música (0 a 100%);
--   * volume dos efeitos (0 a 100%);
--   * modo performance: esconde os enfeites pequenos do mapa (corais, conchas, pedrinhas,
--     bandeirinhas...), desliga sombras, raios de luz, desfoque, bolhas e a água animada.
--     Bom para celular e computador fraco.
-- Tudo vale na hora e fica salvo nos dados do jogador (data.Set).

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local SoundFx = require(script.Parent:WaitForChild("SoundFx"))

local player = Players.LocalPlayer

local settings = { Mu = 1, Fx = 1, Perf = false }

-- Modo performance -----------------------------------------------------------------------------
-- pastas com os enfeites pequenos (só somem no seu computador)
local DECOR = {
	{ "Oceano", "RecifeDecoracao" },
	{ "Oceano", "Decoracao" },
	{ "Praia", "Decoracao" },
	{ "Praia", "Bandeirinhas" },
}
local function setHidden(object, hidden)
	if object:IsA("BasePart") or object:IsA("Decal") then
		object.LocalTransparencyModifier = hidden and 1 or 0
	end
end

local decorFolders = {}
local function watchDecor()
	local map = Workspace:WaitForChild("Map")
	for _, path in ipairs(DECOR) do
		task.spawn(function()
			local area = map:WaitForChild(path[1], 30)
			local folder = area and area:WaitForChild(path[2], 30)
			if not folder then
				return
			end
			table.insert(decorFolders, folder)
			-- peças que chegam depois (o mapa vem aos poucos com o StreamingEnabled)
			folder.DescendantAdded:Connect(function(object)
				if settings.Perf then
					setHidden(object, true)
				end
			end)
			if settings.Perf then
				for _, object in ipairs(folder:GetDescendants()) do
					setHidden(object, true)
				end
			end
		end)
	end
end
watchDecor()

local lightingBackup = nil
local function applyPerformance(on)
	player:SetAttribute("PerfMode", on)
	for _, folder in ipairs(decorFolders) do
		for _, object in ipairs(folder:GetDescendants()) do
			setHidden(object, on)
		end
	end
	if on then
		if not lightingBackup then
			lightingBackup = { GlobalShadows = Lighting.GlobalShadows, Effects = {} }
			for _, effect in ipairs(Lighting:GetChildren()) do
				-- bloom, raios do sol e profundidade de campo pesam; a cor da água fica
				if effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") then
					lightingBackup.Effects[effect] = effect.Enabled
					effect.Enabled = false
				end
			end
		end
		Lighting.GlobalShadows = false
	elseif lightingBackup then
		Lighting.GlobalShadows = lightingBackup.GlobalShadows
		for effect, enabled in pairs(lightingBackup.Effects) do
			if effect.Parent then
				effect.Enabled = enabled
			end
		end
		lightingBackup = nil
	end
end

local function applyAll()
	SoundFx.SetVolumes(settings.Mu, settings.Fx)
	if (player:GetAttribute("PerfMode") == true) ~= settings.Perf then
		applyPerformance(settings.Perf)
	end
end

-- salva no servidor um pouco depois da última mudança (arrastar o volume não manda mil pedidos)
local saveToken = 0
local function save()
	saveToken += 1
	local token = saveToken
	task.delay(1, function()
		if token == saveToken then
			ClientState.Request("Settings", { Mu = settings.Mu, Fx = settings.Fx, Perf = settings.Perf })
		end
	end)
end

-- Botão da engrenagem ------------------------------------------------------------------------
local gui = UIKit.Gui("Settings", 2)
local holder = UIKit.Frame(gui, {
	Name = "Engrenagem",
	Size = UDim2.fromOffset(100, 72),
	Position = UDim2.new(1, -22, 0.5, 50),
	AnchorPoint = Vector2.new(1, 0),
	Transparency = 1,
	Corner = false,
})
UIKit.AutoScale(holder)
local gearButton = UIKit.Button(holder, {
	Name = "Configuracoes",
	Text = "",
	Color = "Gray",
	Style = "Hud",
	Size = UDim2.fromOffset(72, 72),
	Position = UDim2.new(1, 0, 0, 0),
	AnchorPoint = Vector2.new(1, 0),
})
UIKit.Text(gearButton, { Text = "⚙️", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Stroke = 2, ZIndex = 3 })

-- Janela -----------------------------------------------------------------------------------------
local window = UIKit.Window("Settings", { Title = "Settings", Icon = "⚙️", Size = Vector2.new(640, 470), Header = "Gray" })
local body = window.Body

local function row(y, title)
	local frame = UIKit.Frame(body, {
		Size = UDim2.new(1, 0, 0, 104),
		Position = UDim2.fromOffset(0, y),
		Color = Color3.fromRGB(16, 16, 22),
		Transparency = 0.35,
		Corner = 12,
		Stroke = 3,
	})
	UIKit.Studs(frame, Vector2.new(612, 104), { Spacing = 26, Transparency = 0.93 })
	UIKit.Text(frame, { Text = title, Size = UDim2.new(0.6, 0, 0, 34), Position = UDim2.fromOffset(18, 10), Align = Enum.TextXAlignment.Left, Max = 30, Stroke = 3, ZIndex = 2 })
	return frame
end

-- barra de volume que dá para arrastar (mouse ou dedo)
local function slider(frame, key, icon)
	local valueLabel = UIKit.Text(frame, { Text = "", Size = UDim2.new(0.35, 0, 0, 34), Position = UDim2.new(1, -18, 0, 10), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Color = UIKit.StaminaYellow, Max = 28, Stroke = 3, ZIndex = 2 })
	local mute = UIKit.Button(frame, { Text = icon, Color = "Blue", Size = UDim2.fromOffset(52, 40), Position = UDim2.fromOffset(16, 52), Max = 26, ZIndex = 2 })
	local track = UIKit.Frame(frame, {
		Name = "Barra",
		Size = UDim2.new(1, -110, 0, 22),
		Position = UDim2.fromOffset(86, 61),
		Color = Color3.fromRGB(40, 40, 52),
		Corner = 11,
		Stroke = 3,
		ZIndex = 2,
	})
	track.Active = true
	local fill = UIKit.Frame(track, { Name = "Cheio", Size = UDim2.fromScale(1, 1), Color = UIKit.White, Corner = 11, ZIndex = 3 })
	UIKit.Gradient(fill, UIKit.Colors.Lime[1], UIKit.Colors.Lime[2], 90)
	local knob = UIKit.Frame(track, {
		Name = "Bolinha",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromScale(1, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = UIKit.White,
		Corner = 17,
		Stroke = 3,
		ZIndex = 4,
	})

	local lastNonZero = 1
	local function show()
		local v = settings[key]
		fill.Size = UDim2.fromScale(v, 1)
		fill.Visible = v > 0.01
		knob.Position = UDim2.fromScale(v, 0.5)
		valueLabel.Text = ("%d%%"):format(math.floor(v * 100 + 0.5))
		mute.Label.Text = v <= 0.001 and "🔇" or icon
	end
	local function set(v)
		v = math.clamp(v, 0, 1)
		if v > 0.01 then
			lastNonZero = v
		end
		settings[key] = v
		show()
		applyAll()
		save()
	end
	local function fromScreen(x)
		local left, width = track.AbsolutePosition.X, track.AbsoluteSize.X
		return width > 0 and (x - left) / width or settings[key]
	end

	local dragging = false
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			set(fromScreen(input.Position.X))
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			set(fromScreen(input.Position.X))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	-- botão do ícone: liga/desliga o som (volta ao volume de antes)
	mute.Activated:Connect(function()
		set(settings[key] > 0.001 and 0 or lastNonZero)
	end)
	return show
end

local showMusic = slider(row(0, "🎵 Music"), "Mu", "🔊")
local showEffects = slider(row(116, "💥 Sound effects"), "Fx", "🔊")

-- modo performance
local perfRow = UIKit.Frame(body, {
	Size = UDim2.new(1, 0, 0, 124),
	Position = UDim2.fromOffset(0, 232),
	Color = Color3.fromRGB(16, 16, 22),
	Transparency = 0.35,
	Corner = 12,
	Stroke = 3,
})
UIKit.Studs(perfRow, Vector2.new(612, 124), { Spacing = 26, Transparency = 0.93 })
UIKit.Text(perfRow, { Text = "⚡ Performance mode", Size = UDim2.new(0.65, 0, 0, 34), Position = UDim2.fromOffset(18, 10), Align = Enum.TextXAlignment.Left, Max = 30, Stroke = 3, ZIndex = 2 })
UIKit.Text(perfRow, {
	Text = "Hides small decorations, shadows, light rays and bubbles. The game runs lighter on phones and slow computers.",
	Size = UDim2.new(1, -200, 0, 64),
	Position = UDim2.fromOffset(18, 48),
	Align = Enum.TextXAlignment.Left,
	Color = Color3.fromRGB(190, 200, 215),
	Max = 20,
	Stroke = 1.5,
	ZIndex = 2,
})
local perfButton, perfLabel = UIKit.Button(perfRow, {
	Text = "OFF",
	Color = "Gray",
	Size = UDim2.fromOffset(150, 64),
	Position = UDim2.new(1, -18, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	Max = 34,
	ZIndex = 2,
})
local function showPerf()
	perfLabel.Text = settings.Perf and "ON" or "OFF"
	UIKit.SetButtonColor(perfButton, settings.Perf and "Green" or "Gray")
end
perfButton.Activated:Connect(function()
	settings.Perf = not settings.Perf
	showPerf()
	applyAll()
	save()
end)

local function showAll()
	showMusic()
	showEffects()
	showPerf()
end

gearButton.Activated:Connect(function()
	window.Toggle()
end)
window.Opened.Event:Connect(showAll)

-- carrega o que estava salvo (só na primeira foto dos dados)
local loaded = false
local function load(data)
	if loaded or not data or type(data.Set) ~= "table" then
		return
	end
	loaded = true
	settings.Mu = tonumber(data.Set.Mu) or 1
	settings.Fx = tonumber(data.Set.Fx) or 1
	settings.Perf = data.Set.Perf == true
	applyAll()
	showAll()
end
ClientState.Changed.Event:Connect(load)
load(ClientState.Data)
showAll()

-- some durante a corrida
local function updateVisible()
	holder.Visible = player:GetAttribute("Running") ~= true
end
player:GetAttributeChangedSignal("Running"):Connect(updateVisible)
updateVisible()
