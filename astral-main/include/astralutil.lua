--[[
                        /$$                        /$$
                       | $$                       | $$
   /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
  |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
   /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
  /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
 |  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
  \_______/|_______/    \___/  |__/      \_______/|__/

    @name: astralutil.lua
    @version: 1.0.0
    @date: 06/08/25
    @author: Celeste Softworks © 2025
    @description: Astral utility module responsable for Trails, conversions, calculations and more
--]]

local module = {}
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
local trailTemplate = script:FindFirstChild("Trail_Customized")
local POSSIBLE_KEYS = {
	Enum.KeyCode.E,
	Enum.KeyCode.R,
	Enum.KeyCode.T,
	Enum.KeyCode.Y,
	Enum.KeyCode.U,
	Enum.KeyCode.A,
	Enum.KeyCode.B,
	Enum.KeyCode.C,
	Enum.KeyCode.F,
	Enum.KeyCode.N
}
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = {player.Character}

function module:getRandomKeys(count)
	local keys = {}
	local picked = {}
	while #keys < count do
		local candidate = POSSIBLE_KEYS[math.random(1, #POSSIBLE_KEYS)]
		if not picked[candidate] then
			picked[candidate] = true
			table.insert(keys, candidate)
		end
	end
	return keys
end

function module:getNearestAttackable(position, maxDistance)
	local closest = nil
	local closestDistance = maxDistance or 80
	for _, enemy in CollectionService:GetTagged("Attackable") do
		if enemy:IsA("Model") and enemy.PrimaryPart then
			local dist = (enemy.PrimaryPart.Position - position).Magnitude
			if dist < closestDistance then
				closest = enemy.PrimaryPart
				closestDistance = dist
			end
		end
	end
	return closest
end

local characters = {
	["Chip"] = {
		["Happy"] = Vector2.new(100, 200),
		["Distress"] = Vector2.new(300, 305),
		["Confused"] = Vector2.new(100, 305),
		["Scared"] = Vector2.new(0, 305),
		["Neutral"] = Vector2.new(0, 205),
		["Angry"] = Vector2.new(400, 205),

	},
	
	["Sonic"] = {
		["Talking"] = Vector2.new(0, 100)
	},
	
	["Tails"] = {
		["Chill"] = Vector2.new(0, 0)
	}
}
local charnames = {
	["Chip"] = Vector2.new(0, 475),
	["Sonic"] = Vector2.new(0, 410),
	["Tails"] = Vector2.new(0, 445)

}

function module:showHint(data)
	--// why do i have to def this
	task.spawn(function()
		if game.Players.LocalPlayer.PlayerGui.ScreenGui:FindFirstChild("Hint") then game.Players.LocalPlayer.PlayerGui.ScreenGui:FindFirstChild("Hint"):Destroy() game.ReplicatedStorage.astral.engine.assets.sfx.Hint_Remove:Play() end
		
		local TweenService = game:GetService("TweenService")
		local text = data.Text;
		local character = data.Character;
		local emotion = data.CharacterEmotion;
		local gui = game.Players.LocalPlayer.PlayerGui.ScreenGui.HintSample:Clone();
		gui.Parent = game.Players.LocalPlayer.PlayerGui.ScreenGui
		gui.Name = "Hint"
		gui.CharacterEmotion.ImageRectOffset = characters[character] and characters[character][emotion] or Vector2.new(0, 0)
		gui.ImageLabel.CharName.ImageRectOffset = charnames[character];
		local targetSize = UDim2.new(0.348, 0, 0.197, 0)
		local tweenTime = 0.5 -- secondz g

		gui.Size = UDim2.new(0, 0, 0, 0)
		gui.Visible = true
		game.ReplicatedStorage.astral.engine.assets.sfx.Hint_Start:Play()
		for _, child in gui:GetChildren() do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				child.TextTransparency = 1
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				child.ImageTransparency = 1
			end
		end

		local sizeTween = TweenService:Create(gui, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize})
		sizeTween:Play()

		for _, child in gui:GetChildren() do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				local tween = TweenService:Create(child, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
				tween:Play()
			elseif child.Name == "ImageLabel" then
				local tween = TweenService:Create(child, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0.1})
				tween:Play()
			end
		end
		local tween = TweenService:Create(gui.CharacterEmotion, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0})
		tween:Play()
		
		sizeTween.Completed:Connect(function()
			if not gui.Parent then return end
			gui.Text.Text = ""

			local i = 1
			local output = ""

			while i <= #text do
				if not gui.Parent then break end
				local char = text:sub(i, i)

				if char == "<" then
					-- instantly skip to end of tag
					local tagEnd = text:find(">", i)
					if not tagEnd then break end
					output = output .. text:sub(i, tagEnd)
					gui.Text.Text = output -- ✅ apply immediately
					i = tagEnd
				else
					if not gui.Parent then return end
					output = output .. char
					gui.Text.Text = output
					task.wait(0.05)
				end
				i += 1
			end


			-- ensure
			if not gui.Parent then return end
			gui.Text.Text = text

			task.wait(2)
			if not gui then return end
			local sizeTween = TweenService:Create(gui, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)})
			sizeTween:Play()
			game.ReplicatedStorage.astral.engine.assets.sfx.Hint_Remove:Play()

			for _, child in gui:GetChildren() do
				if child:IsA("TextLabel") or child:IsA("TextButton") then
					local tween = TweenService:Create(child, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
					tween:Play()
				elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
					local tween = TweenService:Create(child, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {ImageTransparency = 1})
					tween:Play()
				end
			end

			sizeTween.Completed:Connect(function()
				gui:Destroy()
			end)
		end)
	end)
end

function module:isObjectVisibleToPlayer(object, player)
	local camera = workspace.CurrentCamera
	if not camera or not object then return false end

	local screenPos, onScreen = camera:WorldToViewportPoint(object.Position)
	if not onScreen then return false end

	return true
end

function module:_isVisible(part)
	-- 1. Check if it's on screen
	local camera = workspace.CurrentCamera
	local screenPoint, onScreen = camera:WorldToViewportPoint(part.Position)
	if not onScreen then return false end

	-- 2. Check if there’s line of sight
	raycastParams.FilterDescendantsInstances = {player.Character, workspace.Rings}
	local result = workspace:Raycast(camera.CFrame.Position, (part.Position - camera.CFrame.Position), raycastParams)

	if result then
		-- If the ray hits something that's NOT the ring, it's blocked
		if result.Instance ~= part then
			-- For models, allow any part inside the same model
			if not (part:IsDescendantOf(result.Instance) or result.Instance:IsDescendantOf(part)) then
				return false
			end
		end
	end

	return true
end

function module:fieldOfView(a)
	game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(0.15), {FieldOfView = a}):Play()
end

function module:setProperty(a, v)
	game.StarterGui:SetAttribute(a,v)
end

function module:getProperty(a)
	return game.StarterGui:GetAttribute(a)
end

function module:findPartBelow()
	local rayOrigin = game.Players.LocalPlayer.Character.PrimaryPart.Position
	local rayDirection = Vector3.new(0, -5, 0)  -- Raycast 5 studs down

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {game.Players.LocalPlayer.Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if raycastResult and raycastResult.Instance then
		return raycastResult.Instance
	end
	return nil
end

function module:setPhysicalProperties(part, friction, frictionWeight)
	if not part or not part:IsA("BasePart") then return end
	local physProps = PhysicalProperties.new(friction, frictionWeight, part.CustomPhysicalProperties.Elasticity, part.CustomPhysicalProperties.FrictionWeight)
	part.CustomPhysicalProperties = PhysicalProperties.new(friction, frictionWeight, 0, 0)
end

function module:get(cfg)
	return script.Parent.Parent["@astral"]:FindFirstChild(cfg).Value
end

function module:_set(cfg, v)
	script.Parent.Parent["@astral"]:FindFirstChild(cfg).Value = v
end

local newTrail = module:get("NewTrail") == true and true or false
function module:createTrailTunnel()
	if newTrail then
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local ringRadius = 1.5
		local segmentCount = 32
		local trailLifetime = 1.25 -- this should match the trail's Lifetime property

		for i = 1, segmentCount do
			local angle = (2 * math.pi / segmentCount) * i
			local offset = Vector3.new(math.cos(angle), math.sin(angle), -0.5) * ringRadius

			local att0 = Instance.new("Attachment")
			att0.Position = offset
			att0.Parent = hrp

			local att1 = Instance.new("Attachment")
			att1.Position = offset * 0.6
			att1.Parent = hrp

			local trail = trailTemplate:Clone()
			trail.Attachment0 = att0
			trail.Attachment1 = att1
			trail.Lifetime = trailLifetime -- ensure this is set
			trail.Parent = hrp
			trail.Enabled = true
			trail.FaceCamera = true
			trail.LightInfluence = 0
			trail.LightEmission = 0.7
			trail.Texture = "rbxassetid://1396776555"
			trail.Transparency = NumberSequence.new(0.8)
			trail.WidthScale = NumberSequence.new(1)
			trail.Color = ColorSequence.new(Color3.fromRGB(0,12,255))

			-- Disable trail after trailLifetime (or shorter if you want)
			task.delay(trailLifetime, function()
				trail.Enabled = false -- stops spawning new parts, triggers fade out

				-- wait for fade-out to complete, then clean up
				task.delay(trailLifetime, function()
					trail:Destroy()
					att0:Destroy()
					att1:Destroy()
				end)
			end)
		end
	else
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local ringRadius = 1.2
		local segmentCount = 32
		local trailLifetime = 1.25 -- this should match the trail's Lifetime property

		for i = 1, segmentCount do
			local angle = (2 * math.pi / segmentCount) * i
			local offset = Vector3.new(math.cos(angle), math.sin(angle), -0.5) * ringRadius

			local att0 = Instance.new("Attachment")
			att0.Position = offset
			att0.Parent = hrp

			local att1 = Instance.new("Attachment")
			att1.Position = offset * 0.6
			att1.Parent = hrp

			local trail = trailTemplate:Clone()
			trail.Attachment0 = att0
			trail.Attachment1 = att1
			trail.Lifetime = trailLifetime -- ensure this is set
			trail.Parent = hrp
			trail.Enabled = true

			-- Disable trail after trailLifetime (or shorter if you want)
			task.delay(trailLifetime, function()
				trail.Enabled = false -- stops spawning new parts, triggers fade out

				-- wait for fade-out to complete, then clean up
				task.delay(trailLifetime, function()
					trail:Destroy()
					att0:Destroy()
					att1:Destroy()
				end)
			end)
		end

	end
end

function module:randomColorSequence()
	local colors = {
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 115, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(64, 255, 30))
		}),
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 86, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(26, 148, 255))
		}),
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(202, 93, 95))
		})
	}

	local x = math.random(1, #colors)
	return colors[x]
end



return module
