--[[
                        /$$                        /$$
                       | $$                       | $$
   /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
  |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
   /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
  /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
 |  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
  \_______/|_______/    \___/  |__/      \_______/|__/

	@name: playerSlopeController.lua
	@version: 1.0.0
	@author: Celeste Softworks © 2025
	@date: 05/08/25
	@description: Slope physics controller, responsible for sticking.
	
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local module = {}

-- Settings
local smoothSpeed = 10          -- Rotation smoothing
local stickForceMultiplier = 2  -- How strongly to press down
local slopeBufferTime = 0.15    -- How long to keep last slope after lost contact
local rayLength = 10            -- How far rays should go
local moveThreshold = 0.4       -- Min speed

function module.Start()
	repeat task.wait() until game:IsLoaded()
	local plr = Players.LocalPlayer
	local char = plr.Character or plr.CharacterAdded:Wait()
	local HRP = char:WaitForChild("HumanoidRootPart")
	local Reference = HRP:WaitForChild("Reference")
	local Humanoid = char:WaitForChild("Humanoid")
	task.wait(1)

	local currentTransform = Reference.Transform
	local lastSlopeTime = 0
	local lastNormal = Vector3.new(0, 1, 0)

	local attachment = Instance.new("Attachment", HRP)
	local stickForce = Instance.new("VectorForce")
	stickForce.Attachment0 = attachment
	stickForce.RelativeTo = Enum.ActuatorRelativeTo.World
	stickForce.Parent = HRP

	local function getAverageNormal()
		local offsets = {
			Vector3.new(0, 0, 0),
			Vector3.new(0, 0, 2),
			Vector3.new(0, 0, -2),
			Vector3.new(2, 0, 0),
			Vector3.new(-2, 0, 0)
		}

		local totalNormal = Vector3.new()
		local hitCount = 0
		local onSlope = false

		for _, offset in offsets do
			local origin = HRP.Position + (HRP.CFrame:VectorToWorldSpace(offset))
			local ray = Ray.new(origin, Vector3.new(0, -rayLength, 0))
			local part, _, normal = Workspace:FindPartOnRayWithIgnoreList(ray, {char})
			if part then
				totalNormal += normal
				hitCount += 1
				if string.find(part.Name, "Sloped") then
					onSlope = true
				end
			end
		end


		game.StarterGui:SetAttribute("r_isSlope", onSlope)

		if hitCount > 0 then
			return (totalNormal / hitCount).Unit, onSlope
		else
			return Vector3.new(0, 1, 0), false
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		local state = Humanoid:GetState()

		-- Stopx)
		if state == Enum.HumanoidStateType.Jumping 
			or state == Enum.HumanoidStateType.Freefall 
			or Humanoid.FloorMaterial == Enum.Material.Air then
			stickForce.Force = Vector3.new()
			return
		end

		local normal, onSlope = getAverageNormal()

		if onSlope then
			lastNormal = normal
			lastSlopeTime = tick()
		elseif tick() - lastSlopeTime <= slopeBufferTime then
			normal = lastNormal
			onSlope = true
		end

		local targetTransform
		if onSlope then
			local vector = (HRP.CFrame - HRP.CFrame.p):VectorToObjectSpace(normal)
			targetTransform = CFrame.Angles(vector.z, 0, -vector.x)
		else
			targetTransform = CFrame.new()
		end
		currentTransform = currentTransform:Lerp(targetTransform, math.clamp(smoothSpeed * dt, 0, 1))
		Reference.Transform = currentTransform

		-- apply
		if onSlope and Humanoid.WalkSpeed > 2 then
			local downVector = -normal * Workspace.Gravity * HRP.AssemblyMass * stickForceMultiplier
			stickForce.Force = downVector
		else
			stickForce.Force = Vector3.new()
		end
	end)
end

return module
