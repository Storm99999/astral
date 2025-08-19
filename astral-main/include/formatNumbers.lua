--[[
                        /$$                        /$$
                       | $$                       | $$
   /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
  |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
   /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
  /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
 |  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
  \_______/|_______/    \___/  |__/      \_______/|__/

	@name: formatNumbers.lua
	@version: 1.0.0
	@author: Celeste Softworks © 2025
	@date: 05/08/25
	@description: Formats numbers to 3 digits
	
--]]

local module = {}

function module.format(num)
	local str = tostring(num)
	if #str > 3 then
		return str
	end
	while #str < 3 do
		str = "0" .. str
	end
	return str
end

function module.format2(num)
	local str = tostring(num)
	if #str > 2 then
		return str
	end
	while #str < 2 do
		str = "0" .. str
	end
	return str
end

function module.format3(num)
	return string.format("%08d", num)
end

return module
