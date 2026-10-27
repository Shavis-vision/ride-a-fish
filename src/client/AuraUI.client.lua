-- AuraUI (LocalScript)
-- Fica em: StarterPlayerScripts > Client > AuraUI
--
-- Barraca das AURAS (abre ao pisar no anel roxo). Cada aura é melhor que a anterior
-- (+0.5 no multiplicador de stamina da esteira) e só se compra com dinheiro do jogo,
-- em ordem. As antigas podem ser equipadas só pelo visual: o bônus é sempre o da melhor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared:WaitForChild("Progression"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local window = UIKit.Window("Aura", { Title = "Auras", Size = Vector2.new(860, 640), Header = "Purple" })
local body = window.Body

UIKit.Text(body, {
	Text = "Auras multiplicam a stamina da esteira. O bônus é sempre o da melhor aura que você comprou.",
	Size = UDim2.new(1, 0, 0, 44),
	Color = Color3.fromRGB(220, 200, 255),
	Max = 24,
	Stroke = 2,
})
local list = UIKit.Scroll(body, { Size = UDim2.new(1, 0, 1, -54), Position = UDim2.fromOffset(0, 54), Padding = 8 })

local function render()
	if not window.IsOpen then
		return
	end
	UIKit.Clear(list)
	local data = ClientState.Data
	if not data then
		return
	end
	local money = ClientState.Stat("Money")

	-- "nenhuma" (tirar a aura)
	local none = UIKit.Frame(list, { Size = UDim2.new(1, -8, 0, 70), Color = UIKit.White, LayoutOrder = 0, Corner = 10, Stroke = 3 })
	UIKit.Gradient(none, Color3.fromRGB(52, 52, 64), Color3.fromRGB(32, 32, 40), 90)
	UIKit.Text(none, { Text = "Sem aura (só visual)", Size = UDim2.new(0.6, 0, 0, 40), Position = UDim2.fromOffset(20, 15), Align = Enum.TextXAlignment.Left, Max = 28 })
	UIKit.Button(none, {
		Text = data.Aura == 0 and "Equipada" or "Equipar",
		Color = data.Aura == 0 and "Gray" or "Blue",
		Size = UDim2.fromOffset(200, 54),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Max = 28,
		OnClick = function()
			if data.Aura ~= 0 then
				ClientState.Request("EquipAura", 0)
			end
		end,
	})

	for i, aura in ipairs(Progression.Auras) do
		local owned = i <= data.BestAura
		local isNext = i == data.BestAura + 1
		local frame = UIKit.Frame(list, { Size = UDim2.new(1, -8, 0, 96), Color = UIKit.White, LayoutOrder = i, Corner = 10, Stroke = 3 })
		UIKit.Gradient(frame, Color3.fromRGB(56, 50, 70), Color3.fromRGB(34, 30, 44), 90)
		local orb = UIKit.Frame(frame, {
			Size = UDim2.fromOffset(74, 74),
			Position = UDim2.fromOffset(12, 11),
			Color = aura.Color,
			Corner = 37,
			Stroke = 3,
		})
		UIKit.Gradient(orb, aura.Color:Lerp(Color3.new(1, 1, 1), 0.5), aura.Color, 90)
		if not owned and not isNext then
			UIKit.Text(orb, { Text = "🔒", Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), Stroke = 1 })
		end
		UIKit.Text(frame, {
			Text = aura.Name,
			Size = UDim2.new(0.45, 0, 0, 40),
			Position = UDim2.fromOffset(102, 8),
			Align = Enum.TextXAlignment.Left,
			Color = aura.Color:Lerp(Color3.new(1, 1, 1), 0.3),
			Max = 34,
		})
		UIKit.Text(frame, {
			Text = ("⚡ x%s stamina na esteira"):format(tostring(aura.Mult)),
			Size = UDim2.new(0.45, 0, 0, 30),
			Position = UDim2.fromOffset(102, 52),
			Align = Enum.TextXAlignment.Left,
			Color = UIKit.StaminaYellow,
			Max = 26,
		})
		local text, color, action
		if owned then
			if data.Aura == i then
				text, color = "Equipada", "Gray"
			else
				text, color, action = "Equipar", "Blue", "EquipAura"
			end
		elseif isNext then
			text = NumberFormat.Money(aura.Price)
			color = money >= aura.Price and "Green" or "Red"
			action = "BuyAura"
		else
			text, color = NumberFormat.Money(aura.Price), "Gray"
		end
		UIKit.Button(frame, {
			Text = text,
			Color = color,
			Size = UDim2.fromOffset(230, 62),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Max = 30,
			OnClick = function()
				if action then
					ClientState.Request(action, i)
				elseif not owned then
					ClientState.Toast("Compre as auras anteriores primeiro", "info")
				end
			end,
		})
	end
end

window.Opened.Event:Connect(render)
ClientState.Changed.Event:Connect(render)
