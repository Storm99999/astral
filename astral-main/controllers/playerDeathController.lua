--[[
                        /$$                        /$$
                       | $$                       | $$
   /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
  |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
   /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
  /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
 |  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
  \_______/|_______/    \___/  |__/      \_______/|__/

	@name: playerDeathController.lua
	@version: 1.0.0
	@author: Celeste Softworks © 2025
	@date: 05/08/25
	@description: Controls death mechanic, respawn etc.
	
--]]

local RunService = game:GetService("RunService");
local Players = game:GetService("Players");
local TweenService = game:GetService("TweenService");
local CollectionService = game:GetService("CollectionService");
local RING_MODEL = game.ReplicatedStorage.astral.engine.assets.models.common.ring;
local DROP_RADIUS = 25;
local DROP_SPEED = 10;
local cameraLocked = false;
local connection = nil;
local Utils = require(script.Parent.Parent.include["astralutil.lua"]);
local TextDraw = require(script.Parent.Parent.include["interfaceTextDraw.lua"])
local f = require(script.Parent.Parent.include["formatNumbers.lua"])
local module = {};

function module.Start()
	TextDraw.Draw({
		Text = f.format2(game.StarterGui:GetAttribute("sv_lives")),
		LetterSize = UDim2.new(0, 27, 0, 27),
		Spacing = 0,
		Parent = game.Players.LocalPlayer.PlayerGui.ScreenGui.Hold.Left.Top.LifeIcon.Frame
	})
	print("[astral @ playerDeathController.lua] Death controller initiated: Listening to DeathEvent - Signature:", game.HttpService:GenerateGUID(false))
end;

function module:dropRings()
	local ringCount = Utils:getProperty("sv_rings")
	local player = Players.LocalPlayer
	if ringCount <= 0 then return end
	local frame = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ScreenGui").Letters

	-- Reset player rings
	Utils:setProperty("sv_rings", 0)
	TextDraw.Draw({
		Text = f.format(Utils:getProperty("sv_rings")),
		LetterSize = UDim2.new(0, 19, 0, 19),
		Spacing = 0,
		Parent = frame
	})
	--player.PlayerGui.GUI.Hud.Left.Rings.TextLabel.Text = "0"

	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for i = 1, ringCount do
		local ringClone = RING_MODEL:Clone()
		ringClone.Parent = workspace

		local angle = (i / ringCount) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * DROP_RADIUS
		local startPos = hrp.Position + offset + Vector3.new(0, 2, 0)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {ringClone, player.Character}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local raycastResult = workspace:Raycast(startPos, Vector3.new(0, -50, 0), raycastParams)
		local groundPos
		if raycastResult then
			groundPos = raycastResult.Position + Vector3.new(0, 0.9, 0) -- slight raise to avoid sinking
		else
			groundPos = startPos - Vector3.new(0, 5, 0) -- fallback
		end
		-- Setup position and unanchor
		if ringClone:IsA("BasePart") then
			ringClone.Anchored = false
			ringClone.Position = groundPos
			ringClone.Velocity = Vector3.new(0, -DROP_SPEED, 0)
		elseif ringClone:IsA("Model") and ringClone.PrimaryPart then
			for _, part in ringClone:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = false
				end
			end
			ringClone:SetPrimaryPartCFrame(CFrame.new(startPos))
			ringClone.PrimaryPart.Velocity = Vector3.new(0, -DROP_SPEED, 0)
		end

		CollectionService:AddTag(ringClone, "Ring")

		-- Anchor when hitting something (ground)
		local conn
		local function onTouched(hit)
			if hit and hit:IsDescendantOf(workspace) and not ringClone:IsDescendantOf(hit) then
				if ringClone:IsA("BasePart") then
					ringClone.Anchored = true
					ringClone.Velocity = Vector3.new(0, 0, 0)
					-- Raise ring a bit above current position
					ringClone.Position = ringClone.Position + Vector3.new(0, 0.7, 0)
				end
				if conn then conn:Disconnect() end
			end
		end


		if ringClone:IsA("BasePart") then
			conn = ringClone.Touched:Connect(onTouched)
		end

		coroutine.wrap(function()
			task.wait(4) -- wait 2 seconds before blinking

			local blinkDuration = 1.5
			local startTime = tick()
			local transparencyGoal1 = 1
			local transparencyGoal0 = 0
			local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

			while tick() - startTime < blinkDuration and ringClone.Parent do
				if ringClone:IsA("BasePart") then
					local tween1 = TweenService:Create(ringClone, tweenInfo, {Transparency = transparencyGoal1})
					tween1:Play()
					tween1.Completed:Wait()
					local tween2 = TweenService:Create(ringClone, tweenInfo, {Transparency = transparencyGoal0})
					tween2:Play()
					tween2.Completed:Wait()
				end
			end

			if ringClone.Parent then
				ringClone:Destroy()
			end
		end)()
	end
end



function module:dropOrbs()
	if Utils:get("ChaosOrbs") == false then return end
	local player = game.Players.LocalPlayer

	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for i = 1, 3 do
		local ringClone = game.ReplicatedStorage.astral.engine.assets.models.common.Chaos_Orb:Clone()
		ringClone.Parent = workspace

		local angle = (i / 3) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * DROP_RADIUS
		local startPos = hrp.Position + offset + Vector3.new(0, 2, 0)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {ringClone, player.Character}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local raycastResult = workspace:Raycast(startPos, Vector3.new(0, -50, 0), raycastParams)
		local groundPos
		if raycastResult then
			groundPos = raycastResult.Position + Vector3.new(0, 0.75, 0)
		else
			groundPos = startPos - Vector3.new(0, 5, 0)
		end

		CollectionService:AddTag(ringClone, "ChaosOrb")

		-- Anchor on touch
		local connTouch
		local function onTouched(hit)
			if hit and hit:IsDescendantOf(workspace) and not ringClone:IsDescendantOf(hit) then
				if ringClone:IsA("BasePart") then
					ringClone.Anchored = true
					ringClone.Velocity = Vector3.new(0, 0, 0)
					ringClone.Position = ringClone.Position + Vector3.new(0, 0.7, 0)
				end
				if connTouch then connTouch:Disconnect() end
			end
		end
		if ringClone:IsA("BasePart") then
			connTouch = ringClone.Touched:Connect(onTouched)
		end

		local behindDistance = 3
		local sideSpacing = 2

		local followAlpha = 0.1
		local catchUpAlpha = 0.5
		local followDuration = 2
		local catchUpTransition = 1

		local moveThreshold = 0.1

		local movingTime = 0
		local lastTick = tick()
		local followConn

		followConn = RunService.RenderStepped:Connect(function()
			if not ringClone or not ringClone.Parent or not hrp then
				if followConn then
					followConn:Disconnect()
					followConn = nil
				end
				return
			end

			if ringClone.Anchored == true then
				local currentTick = tick()
				local deltaTime = currentTick - lastTick
				lastTick = currentTick

				local hrpVelocity = game.Players.LocalPlayer.Character.Humanoid.WalkSpeed
				local isMoving = hrpVelocity >= 90

				if isMoving then
					movingTime = movingTime + deltaTime
				else
					movingTime = 0
				end

				if isMoving and movingTime < followDuration then
					-- Follow behind while moving AND timer < 2 sec
					local hrpCFrame = hrp.CFrame
					local basePos = hrpCFrame.Position - hrpCFrame.LookVector * behindDistance
					local sideOffset = (i - 2) * sideSpacing
					local targetPos = basePos + hrpCFrame.RightVector * sideOffset
					ringClone.Position = ringClone.Position:Lerp(targetPos, followAlpha)

				else
					-- Catch-up phase (either stopped or 2+ seconds moving)
					-- Smoothly transition lerp alpha from followAlpha to catchUpAlpha over catchUpTransition duration
					local catchupElapsed = math.clamp(movingTime - followDuration, 0, catchUpTransition)
					local t = catchupElapsed / catchUpTransition
					local alpha = followAlpha + (catchUpAlpha - followAlpha) * t

					ringClone.Position = ringClone.Position:Lerp(hrp.Position, alpha)
				end
			end
		end)




	end
end


function module:lockCamera(pos)
	local player = Players.LocalPlayer
	if cameraLocked then return end
	cameraLocked = true

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid
	local rootPart
	local camera = workspace.CurrentCamera
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")

	camera.CameraType = Enum.CameraType.Scriptable

	connection = RunService.RenderStepped:Connect(function()
		if not rootPart then return end
		-- Camera stays locked at lockPos, but looks at player's current position
		camera.CFrame = CFrame.new(pos, rootPart.Position)
	end)
end

function module:unlockCamera()
	if not cameraLocked then return end
	local camera = workspace.CurrentCamera
	cameraLocked = false
	camera.CameraType = Enum.CameraType.Custom
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

function module:Die()
	game.Players.LocalPlayer.PlayerGui.ScreenGui.Enabled = false

	local circle = game.Players.LocalPlayer.PlayerGui.GUI:WaitForChild("Circle"); 
	circle.Visible = true
	circle.AnchorPoint = Vector2.new(0.5, 0.5);
	circle.Position = UDim2.new(0.5, 0, 0.5, 0);
	circle.Size = UDim2.new(0, 0, 0, 0);

	local viewportSize = workspace.CurrentCamera.ViewportSize;
	local diagonal = math.sqrt(viewportSize.X^2 + viewportSize.Y^2);
	local finalScale = diagonal / viewportSize.Y; -- scale x)

	--// Tween
	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out);


	local goal = { Size = UDim2.new(finalScale * 2, 0, finalScale * 2, 0) };

	local tween = TweenService:Create(circle, tweenInfo, goal);
	tween:Play();
	task.spawn(function()
		task.wait(0.2)
		game.Players.LocalPlayer.Character.PrimaryPart.CFrame = CollectionService:GetTagged("Spawn")[1] and CollectionService:GetTagged("Spawn")[1].CFrame + Vector3.new(0, 5, 0) or workspace.BackupSpawn.Value+Vector3.new(0, 5, 0);
	end)
	task.wait(2)
	local tweenInfo2 = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	local goal2 = {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0) -- just to be sure
	}

	local tween2 = TweenService:Create(circle, tweenInfo2, goal2)
	tween2:Play()
	tween2.Completed:Wait()
	game.Players.LocalPlayer.PlayerGui.ScreenGui.Enabled = true
	Utils:setProperty("sv_boost", 100)
	TextDraw.Draw({
		Text = f.format2(game.StarterGui:GetAttribute("sv_lives")),
		LetterSize = UDim2.new(0, 27, 0, 27),
		Spacing = 0,
		Parent = game.Players.LocalPlayer.PlayerGui.ScreenGui.Hold.Left.Top.LifeIcon.Frame
	})
	--game.Players.LocalPlayer.PlayerGui.GUI.Hud.Right.Lives.TextLabel.Text = tostring(game.StarterGui:GetAttribute("sv_lives"))
end;

return module;
