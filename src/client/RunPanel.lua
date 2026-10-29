-- RunPanel (ModuleScript)
-- Fica em: StarterPlayerScripts > Client > RunPanel
--
-- Peças extras da tela da corrida (usadas pelo RideController):
--   * lista simples e transparente, à esquerda, com os peixes domados NESTA corrida
--     (espécie nova no índex aparece com "*NEW" ao lado do nome);
--   * barra de progresso no topo com uma "foto" de cada bioma (modelos de
--     ReplicatedStorage > BiomeIcons), o marcador do jogador e a linha do recorde;
--   * coração pixelado (botão de reviver).
--
--   RunPanel.Init(gui)            -- uma vez, com a ScreenGui da corrida
--   RunPanel.Begin(bestDist)      -- começou a corrida
--   RunPanel.AddTamed(entry, new) -- domou { S, M, Z }
--   RunPanel.Update(dist)         -- todo quadro
--   RunPanel.IsNew(speciesId)     -- a espécie ainda não está no índex?
--   RunPanel.PixelHeart(parent, pixel) -> Frame

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))
local Track = require(Shared:WaitForChild("Track"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local BiomeArt = require(script.Parent:WaitForChild("BiomeArt"))

local RunPanel = {}

RunPanel.NEW_COLOR = Color3.fromRGB(255, 70, 200) -- rosa forte: destaca bem em cima da água
RunPanel.BEST_COLOR = Color3.fromRGB(255, 205, 40)

local MAX_ROWS = 8

local listFrame, listTitle, rows, extraLabel
local bar, marker, bestLine, bestLabel
local tamedCount = 0
local hidden = 0

function RunPanel.IsNew(speciesId)
	local data = ClientState.Data
	return data ~= nil and data.Index ~= nil and data.Index[speciesId] == nil
end

-- Coração em pixel art (9 x 8 quadradinhos), vermelho com brilho e contorno escuro.
local HEART = {
	"..XX.XX..",
	".XoOXOOX.",
	"XoOOOOOOX",
	"XOOOOOOOX",
	".XOOOOOX.",
	"..XOOOX..",
	"...XOX...",
	"....X....",
}
function RunPanel.PixelHeart(parent, pixel)
	pixel = pixel or 5
	local frame = Instance.new("Frame")
	frame.Name = "PixelHeart"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(pixel * 9, pixel * 8)
	for y, line in ipairs(HEART) do
		for x = 1, #line do
			local c = line:sub(x, x)
			if c ~= "." then
				local p = Instance.new("Frame")
				p.BorderSizePixel = 0
				p.Size = UDim2.fromOffset(pixel, pixel)
				p.Position = UDim2.fromOffset((x - 1) * pixel, (y - 1) * pixel)
				p.BackgroundColor3 = c == "X" and Color3.fromRGB(60, 10, 20) or c == "o" and Color3.fromRGB(255, 200, 200) or Color3.fromRGB(235, 40, 60)
				p.Parent = frame
			end
		end
	end
	frame.Parent = parent
	return frame
end

function RunPanel.Init(gui)
	-- lista da corrida (esquerda, quase transparente)
	listFrame = UIKit.Frame(gui, {
		Name = "RunList",
		Size = UDim2.fromOffset(250, 40),
		Position = UDim2.new(0, 16, 0.3, 0),
		Color = Color3.fromRGB(10, 20, 35),
		Transparency = 0.7,
		Corner = 10,
	})
	UIKit.AutoScale(listFrame)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = listFrame
	UIKit.Padding(listFrame, 8)
	UIKit.StudsFill(listFrame, { Spacing = 20, Transparency = 0.9, EdgeTransparency = 0.85 })
	local auto = Instance.new("UISizeConstraint")
	auto.MinSize = Vector2.new(250, 40)
	auto.Parent = listFrame
	listFrame.AutomaticSize = Enum.AutomaticSize.Y
	listTitle = UIKit.Text(listFrame, { Text = "THIS RUN", Size = UDim2.new(1, 0, 0, 22), Align = Enum.TextXAlignment.Left, Color = Color3.fromRGB(170, 220, 255), Max = 20, LayoutOrder = 0, Stroke = 2 })
	extraLabel = UIKit.Text(listFrame, { Text = "", Size = UDim2.new(1, 0, 0, 18), Align = Enum.TextXAlignment.Left, Color = Color3.fromRGB(200, 200, 210), Max = 16, LayoutOrder = 999, Stroke = 1.5 })
	extraLabel.Visible = false
	rows = {}

	-- barra de progresso com os biomas
	bar = UIKit.Frame(gui, {
		Name = "Progress",
		Size = UDim2.fromOffset(540, 54),
		Position = UDim2.new(0.5, 0, 0, 88),
		AnchorPoint = Vector2.new(0.5, 0),
		Transparency = 1,
		Corner = false,
	})
	UIKit.AutoScale(bar)
	-- um quadro por bioma (como na referência): nome em cima, borda colorida, imagem/cena
	for i, area in ipairs(Track.Areas) do
		local width = (area.Finish - area.Start) / Track.LENGTH
		local x = area.Start / Track.LENGTH
		local seg = UIKit.Frame(bar, {
			Name = "Bioma" .. i,
			Size = UDim2.new(width, -6, 1, 0),
			Position = UDim2.new(x, 3, 0, 0),
			Color = area.FogColor,
			Corner = 7,
			Stroke = 3,
			StrokeColor = BiomeArt.BorderColors[i] or UIKit.White,
		})
		seg.ClipsDescendants = true
		local art = BiomeArt.Picture(seg, i)
		UIKit.Corner(art, 7)
		UIKit.StudsFill(seg, { Spacing = 13, Transparency = 0.8, EdgeTransparency = 0.7, ZIndex = 4 })
		UIKit.Text(seg, { Text = area.Name, Size = UDim2.new(1, -8, 0, 17), Position = UDim2.new(0, 4, 0, 2), Max = 16, Stroke = 2, ZIndex = 5 })
	end
	-- recorde: linha vertical dourada
	bestLine = UIKit.Frame(bar, { Name = "Best", Size = UDim2.new(0, 4, 1, 8), Position = UDim2.new(0, 0, 0, -4), AnchorPoint = Vector2.new(0.5, 0), Color = RunPanel.BEST_COLOR, Corner = 2, Stroke = 1.5, ZIndex = 6 })
	bestLabel = UIKit.Text(bestLine, { Text = "BEST", Size = UDim2.fromOffset(110, 16), Position = UDim2.new(0.5, 0, 1, 2), AnchorPoint = Vector2.new(0.5, 0), Color = RunPanel.BEST_COLOR, Max = 15, Stroke = 2, ZIndex = 6 })
	-- jogador: linha branca com a foto do avatar em cima
	marker = UIKit.Frame(bar, { Name = "Player", Size = UDim2.new(0, 4, 1, 8), Position = UDim2.new(0, 0, 0, -4), AnchorPoint = Vector2.new(0.5, 0), Color = UIKit.White, Corner = 2, Stroke = 1.5, ZIndex = 7 })
	local head = Instance.new("ImageLabel")
	head.Name = "Head"
	head.Size = UDim2.fromOffset(28, 28)
	head.Position = UDim2.new(0.5, 0, 1, 0)
	head.AnchorPoint = Vector2.new(0.5, 0)
	head.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
	head.ZIndex = 7
	head.Parent = marker
	UIKit.Corner(head, 13)
	UIKit.Stroke(head, 2, UIKit.White, Enum.ApplyStrokeMode.Border)
	task.spawn(function()
		local player = Players.LocalPlayer
		local ok, image = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		if ok then
			head.Image = image
		end
	end)
end

local function clearRows()
	for _, row in ipairs(rows) do
		row:Destroy()
	end
	rows = {}
	tamedCount = 0
	hidden = 0
	extraLabel.Visible = false
end

local function withCommas(n)
	local text = tostring(n)
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function RunPanel.Begin(bestDist)
	if not listFrame then
		return
	end
	clearRows()
	listTitle.Text = "THIS RUN"
	bestLine.Visible = (bestDist or 0) > 0
	bestLine.Position = UDim2.new(math.clamp((bestDist or 0) / Track.LENGTH, 0, 1), 0, 0, -4)
	bestLabel.Text = "◆ BEST " .. withCommas(math.floor(bestDist or 0)) .. " m"
end

function RunPanel.AddTamed(entry, isNew)
	if not listFrame then
		return
	end
	tamedCount += 1
	listTitle.Text = ("THIS RUN  •  %d"):format(tamedCount)
	local species = Fish.Get(entry.S)
	if not species then
		return
	end
	local rarity = Fish.Rarities[species.Rarity]
	local tags = {}
	if entry.M and entry.M ~= "Normal" then
		table.insert(tags, ('<font color="#%s">%s</font>'):format(Fish.Mutations[entry.M].Color:ToHex(), Fish.Mutations[entry.M].Name))
	end
	if entry.Z and entry.Z ~= "Normal" then
		table.insert(tags, Fish.Sizes[entry.Z].Name)
	end
	local text = ('<font color="#%s">●</font> %s'):format(rarity.Color:ToHex(), species.Name)
	if #tags > 0 then
		text ..= ' <font size="13">' .. table.concat(tags, " ") .. "</font>"
	end
	if isNew then
		text ..= (' <font color="#%s">*NEW</font>'):format(RunPanel.NEW_COLOR:ToHex())
	end
	local row = UIKit.Text(listFrame, { Text = text, Rich = true, Size = UDim2.new(1, 0, 0, 20), Align = Enum.TextXAlignment.Left, Max = 18, Stroke = 1.5 })
	row.LayoutOrder = -tamedCount -- o mais novo em cima
	table.insert(rows, row)
	-- entra deslizando
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = row
	UIKit.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	if #rows > MAX_ROWS then
		local oldest = table.remove(rows, 1)
		if oldest then
			oldest:Destroy()
		end
		hidden += 1
		extraLabel.Visible = true
		extraLabel.Text = ("+%d more"):format(hidden)
	end
end

function RunPanel.Update(dist)
	if not marker then
		return
	end
	local f = math.clamp(dist / Track.LENGTH, 0, 1)
	marker.Position = UDim2.new(f, 0, 0, -4)
	-- passou do recorde nesta corrida: a linha vira "NEW BEST!" e acompanha o jogador
	local data = ClientState.Data
	local best = data and data.BestDist or 0
	if bestLine.Visible and dist > best then
		bestLabel.Text = "◆ NEW BEST!"
		bestLine.Position = marker.Position
	end
end

return RunPanel
