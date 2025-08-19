--[[
                        /$$                        /$$
                       | $$                       | $$
   /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
  |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
   /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
  /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
 |  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
  \_______/|_______/    \___/  |__/      \_______/|__/

	@name: playerInterfaceSwayController.lua
	@version: 1.0.1
	@author: Celeste Softworks © 2025
	@date: 16/08/25
	@description: Adds Sway to the UI
	
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Utils = require(script.Parent.Parent.include["astralutil.lua"])

local module = {}

function module.Start()
	local character = script.Parent.Parent.Parent
	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")

	local acceleration = 55
	local lastTime = tick()

	local tiltAmount = math.rad(Utils:get("MaxAnimTilt")) -- max tilt angle, modify in @astral Object
	local tiltSpeed = 0.01 
	local currentTilt = 0

	RunService.Heartbeat:Connect(function(dt)
		if humanoid.FloorMaterial == Enum.Material.Air then return end
		if Utils:getProperty("r_isSlope") then return end
		local moveDir = humanoid.MoveDirection
		local targetTilt = 0

		if moveDir.Magnitude > 0 then
			local relative = rootPart.CFrame:VectorToObjectSpace(moveDir)

			if math.abs(relative.X) > 0.2 then
				targetTilt = -tiltAmount * math.sign(relative.X)
			end
		end

		-- smoothzzzzzzzzzz
		currentTilt = currentTilt + (targetTilt - currentTilt) * tiltSpeed

		-- apply that
		if humanoid:GetState() == Enum.HumanoidStateType.Jumping then targetTilt = 0 end
		local pos = rootPart.Position
		local lookVector = rootPart.CFrame.LookVector
		rootPart.CFrame = CFrame.new(pos, pos + lookVector) * CFrame.Angles(0, 0, currentTilt)
	end)

	task.spawn(function()
		while task.wait() do
			local now = tick()
			local dt = now - lastTime
			lastTime = now

			if humanoid.MoveDirection == Vector3.new(0, 0, 0) then
				humanoid.WalkSpeed = 2
			else
				humanoid.WalkSpeed = humanoid.WalkSpeed + acceleration * dt
				if humanoid.WalkSpeed > 120 then
					humanoid.WalkSpeed = 121
				end
			end
		end
	end)
end

return module


local UISwayHandler = {}
UISwayHandler.__index = UISwayHandler

-- Services
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Initialize the sway handler x)
function UISwayHandler.new()
	local self = setmetatable({}, UISwayHandler)
	self.player = Players.LocalPlayer
	return self
end

function UISwayHandler:addSwayEffect(ui)
	CollectionService:AddTag(ui, "Sway")

	RunService:BindToRenderStep("binduiSway_" .. ui.Name, Enum.RenderPriority.Last.Value, function()
		for _, element in pairs(CollectionService:GetTagged("Sway")) do
			local mouseDelta = UserInputService:GetMouseDelta()
			TweenService:Create(element, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(mouseDelta.X, mouseDelta.Y),
				Rotation = (0 - mouseDelta.X) * -0.5
			}):Play()
		end
	end)
end

function UISwayHandler:removeSwayEffect(ui)
	if CollectionService:HasTag(ui, "Sway") then
		CollectionService:RemoveTag(ui, "Sway")
	end
end

-- Initialize
function UISwayHandler:Start()
	local ui = game.Players.LocalPlayer.PlayerGui:WaitForChild("GUI").Main
	
	CollectionService:AddTag(ui, "Sway")

	RunService:BindToRenderStep("binduiSway_" .. ui.Name, Enum.RenderPriority.Last.Value, function()
		for _, element in pairs(CollectionService:GetTagged("Sway")) do
			local mouseDelta = UserInputService:GetMouseDelta()
			TweenService:Create(element, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(mouseDelta.X, mouseDelta.Y),
				Rotation = (0 - mouseDelta.X) * -0.5
			}):Play()
		end
	end)
end

return UISwayHandler
