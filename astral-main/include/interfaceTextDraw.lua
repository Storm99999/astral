--[[
                        /$$                        /$$
                       | $$                       | $$
   /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
  |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
   /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
  /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
 |  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
  \_______/|_______/    \___/  |__/      \_______/|__/

	@name: interfaceTextDraw.lua
	@version: 1.0.0
	@author: Celeste Softworks © 2025
	@date: 05/08/25
	@description: Draws text from Image sprites
	
--]]

local module = {};

module.SpritesheetImage = "rbxassetid://13547138725"
module.Digits = {
	["0"] = {Offset = Vector2.new(61, 123),    Size = Vector2.new(60, 56)},
	["1"] = {Offset = Vector2.new(1, 3),   Size = Vector2.new(60, 56)},
	["2"] = {Offset = Vector2.new(61, 3),   Size = Vector2.new(60, 56)},
	["3"] = {Offset = Vector2.new(123, 3),   Size = Vector2.new(60, 56)},
	["4"] = {Offset = Vector2.new(191, 3),  Size = Vector2.new(60, 56)},
	["5"] = {Offset = Vector2.new(1, 63),  Size = Vector2.new(60, 56)},
	["6"] = {Offset = Vector2.new(61, 63),  Size = Vector2.new(60, 56)},
	["7"] = {Offset = Vector2.new(123, 63),  Size = Vector2.new(60, 56)},
	["8"] = {Offset = Vector2.new(191, 63),  Size = Vector2.new(60, 56)},
	["9"] = {Offset = Vector2.new(1, 123),  Size = Vector2.new(60, 56)},
}

function module.Draw(params)

	local text = params.Text or ""
	local letterSize = params.LetterSize or UDim2.new(0, 32, 0, 48)
	local spacing = params.Spacing or 4
	local parent = params.Parent
	local stroke = params.Stroke or false

	if not parent then
		return
	end

	-- clear x)
	for _, child in parent:GetChildren() do
		if child:IsA("ImageLabel") then
			child:Destroy()
		end
	end

	local parentWidth = parent.AbsoluteSize.X
	local parentHeight = parent.AbsoluteSize.Y
	if parentWidth == 0 or parentHeight == 0 then
		return
	end

	-- convert scale
	local letterSizeScale = UDim2.new(
		letterSize.X.Offset / parentWidth, 0,
		letterSize.Y.Offset / parentHeight, 0
	)


	local spacingScale = spacing / parentWidth

	local xScale = 0 -- start at 0 scale

	for i = 1, #text do
		local char = string.sub(text, i, i)
		local digitData = module.Digits[char]

		if char == " " then
			xScale = xScale + letterSizeScale.X.Scale + spacingScale
		elseif digitData then
			local letter = Instance.new("ImageLabel")
			letter.BackgroundTransparency = 1
			letter.Size = letterSizeScale
			letter.Position = UDim2.new(xScale, 0, 0, 0)
			letter.Image = module.SpritesheetImage
			letter.ImageRectOffset = digitData.Offset
			letter.ImageRectSize = digitData.Size
			letter.Parent = parent
			letter.ScaleType = Enum.ScaleType.Fit
			letter.AnchorPoint = Vector2.new(0, 0)

			xScale = xScale + letterSizeScale.X.Scale + spacingScale
		else
			xScale = xScale + letterSizeScale.X.Scale + spacingScale
		end
	end
end


return module;
