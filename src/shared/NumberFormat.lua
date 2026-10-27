-- NumberFormat (ModuleScript)
-- Fica em: ReplicatedStorage > Shared > NumberFormat
--
-- Transforma números grandes em texto curto: 1500 -> "1.5K", 2300000 -> "2.3M".

local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 999 -> "999" | 1500 -> "1.5K" | 2000000 -> "2M"
function NumberFormat.Abbreviate(value)
	value = math.floor(value)

	if value < 1000 then
		return tostring(value)
	end

	local index = 1
	local scaled = value
	while scaled >= 1000 and index < #SUFFIXES do
		scaled = scaled / 1000
		index += 1
	end

	-- uma casa decimal, sem arredondar para cima (999.99K nunca vira "1000K")
	local text = string.format("%.1f", math.floor(scaled * 10) / 10)
	text = string.gsub(text, "%.0$", "")

	return text .. SUFFIXES[index]
end

-- Renda por segundo: mostra uma casa decimal quando há (1.5 -> "1.5", 13 -> "13", 1500 -> "1.5K").
function NumberFormat.Rate(value)
	if value >= 1000 then
		return NumberFormat.Abbreviate(value)
	end

	-- +1e-9 evita que 2.3 * 10 vire 22.999999 e perca a casa decimal
	local text = string.format("%.1f", math.floor(value * 10 + 1e-9) / 10)
	text = string.gsub(text, "%.0$", "")
	return text
end

-- 1500 -> "$1.5K"
function NumberFormat.Money(value)
	return "$" .. NumberFormat.Abbreviate(value)
end

-- Tempo em segundos -> "45s", "12m 30s", "2h 05m", "3d 4h".
function NumberFormat.Duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return seconds .. "s"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m " .. string.format("%02d", seconds % 60) .. "s"
	elseif seconds < 86400 then
		return math.floor(seconds / 3600) .. "h " .. string.format("%02d", math.floor(seconds % 3600 / 60)) .. "m"
	end
	return math.floor(seconds / 86400) .. "d " .. math.floor(seconds % 86400 / 3600) .. "h"
end


return NumberFormat
