--[[
                        /$$                        /$$
                       | $$                       | $$
   /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
  |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
   /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
  /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
 |  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
  \_______/|_______/    \___/  |__/      \_______/|__/

	@name: playerCollectionController.lua
	@version: 1.0.0
	@author: Celeste Softworks © 2025
	@date: 05/08/25
	@description: Responsible for collecting rings, emeralds, red rings etc.
	
--]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Utils = require(script.Parent.Parent.include["astralutil.lua"])
local TextDraw = require(script.Parent.Parent.include["interfaceTextDraw.lua"])
local f = require(script.Parent.Parent.include["formatNumbers.lua"])

local PICKUP_RADIUS = 4.5-- modify it if you don;t like it.



function playGhostEffect(baseImage)
	local parent = baseImage.Parent
	local ghostCount = 1
	local ghostDelay = 0.04
	local ghosts = {}

	for i = 1, ghostCount do
		local ghost = baseImage:Clone()
		ghost.Name = "Ghost"
		ghost.Parent = parent
		ghost.ZIndex = baseImage.ZIndex - 1
		ghost.ImageTransparency = 1
		ghost.Visible = false
		ghosts[i] = ghost
	end

	for i, ghost in ghosts do
		ghost.Position = baseImage.Position
		ghost.ImageTransparency = baseImage.ImageTransparency + 0.4
		ghost.Visible = true

		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
		local goal = {
			ImageTransparency = 1,
			Position = UDim2.new(
				baseImage.Position.X.Scale - 0.05 * i,
				baseImage.Position.X.Offset,
				baseImage.Position.Y.Scale,
				baseImage.Position.Y.Offset
			)
		}

		local tween = game.TweenService:Create(ghost, tweenInfo, goal)
		tween:Play()
		tween.Completed:Connect(function()
			ghost.Visible = false
			ghost:Destroy()
		end)

		task.wait(ghostDelay)
	end
end

function ringAnimate(ringPart)
	local camera = workspace.CurrentCamera
	local ringWorldPos = ringPart.Position

	local screenPos, onScreen = camera:WorldToViewportPoint(ringWorldPos)
	if not onScreen then return end
	
	local ringImage = script.Ring:Clone()
	ringImage.Parent = game.Players.LocalPlayer.PlayerGui.ScreenGui
	ringImage.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)

	local TweenService = game:GetService("TweenService")

	local targetPos = game.Players.LocalPlayer.PlayerGui.ScreenGui.RingPos.Position

	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(ringImage, tweenInfo, {Position = targetPos})

	tween:Play()

	tween.Completed:Connect(function()
		--[[ Preference ]]
		--playGhostEffect(ringImage)

		ringImage:Destroy()
	end)
end

local frame = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ScreenGui").Letters

TextDraw.Draw({
	Text = f.format(Utils:getProperty("sv_rings")),
	LetterSize = UDim2.new(0, 19, 0, 19),
	Spacing = 0,
	Parent = frame,
	Stroke = true
})

local function collectRing(player, ring)
	if ring.Name == "redring" then
		local m = game.ReplicatedStorage.astral.engine.assets.sfx.RedRing_Start:Clone()
		m.Parent = game.SoundService
		m.Volume = 0.3
		m.PlayOnRemove = true
		m:Destroy()
		local vfx2 = game.ReplicatedStorage.astral.engine.assets.particles.RedCollect:Clone()
		vfx2.Parent = workspace
		vfx2.CFrame = ring.CFrame
		vfx2.Anchored = true
		vfx2.Collect["BigCircle"]:Emit(1)
		vfx2.Collect["Star"]:Emit(1)

		ring:Destroy()
		task.delay(0.35, function()
			vfx2:Destroy()
		end)
		return
	end
	ringAnimate(ring)
	Utils:setProperty("sv_rings", Utils:getProperty("sv_rings")+1)
	TextDraw.Draw({
		Text = f.format(Utils:getProperty("sv_rings")),
		LetterSize = UDim2.new(0, 19, 0, 19),
		Spacing = 0,
		Parent = frame,
		Stroke = true
	})
	local vfx = game.ReplicatedStorage.astral.engine.assets.particles.Sparkles:Clone()
	vfx.Parent = workspace
	vfx.CFrame = ring.CFrame
	vfx.Anchored = true
	vfx.Sparkle.Enabled = false
	vfx.Sparkle:Emit(50)
	local vfx2 = game.ReplicatedStorage.astral.engine.assets.particles.Rainbow:Clone()
	vfx2.Parent = workspace
	vfx2.CFrame = ring.CFrame
	vfx2.Anchored = true
	vfx2.Attachment["1"].Enabled = false
	vfx2.Attachment["1"]:Emit(1)
	local m = game.ReplicatedStorage.astral.engine.assets.sfx.Ring_Start:Clone()
	m.Parent = game.SoundService
	m.Volume = 0.3
	m.PlayOnRemove = true
	m:Destroy()
	Utils:setProperty("sv_boost", math.min(Utils:getProperty("sv_boost") + 5, 100))
	ring:Destroy()
	task.delay(0.35, function()
		vfx:Destroy()
		vfx2:Destroy()
	end)
	game.Players.LocalPlayer.PlayerGui.GUI.Hud.Left.Rings.TextLabel.Text = Utils:getProperty("sv_rings")
end

local module = {};

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local PICKUP_RADIUS = 4.5
local ROTATION_SPEED = 180 

local ROTATION_SPEED = 90 
local UPDATE_INTERVAL = 0.009 -- e (0.9 FPS-ish)

function module.Start()
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart")
	
	if Utils:get("AnimateRings") == true then
		for _, ring in CollectionService:GetTagged("Ring") do
			if ring and ring.Parent then
				ring.CFrame = CFrame.new(ring.CFrame.Position) * CFrame.Angles(0, 0, 0)
			end
		end
	end

	while task.wait() do
		for _, ring in CollectionService:GetTagged("Ring") do
			if ring and ring.Parent then
				-- ! UNCOMMENT IF YOU WANT RING ROTATION EFFECTS ! [PERFORMANCE COST 40FPS-ish]
				--[[
				if Utils:_isVisible(ring, player) then
					local angle = math.rad(ROTATION_SPEED * UPDATE_INTERVAL)
					ring.CFrame = ring.CFrame * CFrame.Angles(angle,0, 0)
				end
				]]
				
				if Utils:get("AnimateRings") == true then
					ring.CFrame *= CFrame.fromEulerAnglesXYZ(0, math.rad(1), 0)
				end

				-- Pickup check
				local distance = (ring.Position - hrp.Position).Magnitude
				if distance <= PICKUP_RADIUS then
					collectRing(player, ring)
				end
			end
			
		end
		for _, ring in CollectionService:GetTagged("HintRing") do
			if ring and ring.Parent then
				-- ! UNCOMMENT IF YOU WANT RING ROTATION EFFECTS ! [PERFORMANCE COST 40FPS-ish]
				--[[
				if Utils:_isVisible(ring, player) then
					local angle = math.rad(ROTATION_SPEED * UPDATE_INTERVAL)
					ring.CFrame = ring.CFrame * CFrame.Angles(angle,0, 0)
				end
				]]

				local angleY = math.rad(1)
				local primaryCFrame = ring.PrimaryPart.CFrame
				ring:SetPrimaryPartCFrame(primaryCFrame * CFrame.Angles(0, angleY, 0))

			
			end
		end
		if Utils:get("ChaosOrbs") == true then
			for _, o in CollectionService:GetTagged("ChaosOrb") do
				if o and o.Parent then				
					local distance = (o.Position - hrp.Position).Magnitude
					if distance <= 2 then
						local m = game.ReplicatedStorage.astral.engine.assets.sfx.ChaosOrb_Start:Clone()
						m.Parent = game.SoundService
						m.Volume = 0.5
						m.PlayOnRemove = true
						m:Destroy()
						o:Destroy()
					end
				end
			end
		end
	end
end


return module;
