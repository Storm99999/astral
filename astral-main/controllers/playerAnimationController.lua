--[[
                        /$$                        /$$
                       | $$                       | $$
   /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
  |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
   /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
  /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
 |  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
  \_______/|_______/    \___/  |__/      \_______/|__/

    @name: playerAnimationController.lua
    @version: 1.2.1
    @date: 05/08/25
    @author: Celeste Softworks © 2025
    @description: Plays idle/walk/run/jump animations based on momentum using Animator
--]]

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--// Includes
local Utils = require(script.Parent.Parent.include["astralutil.lua"])
local Death = require(script.Parent.Parent.controllers["playerDeathController.lua"])
local TextDraw = require(script.Parent.Parent.include["interfaceTextDraw.lua"])
local f = require(script.Parent.Parent.include["formatNumbers.lua"])
local rankModule = require(script.Parent.Parent.include["rankInterpolationModule.lua"])
local distortion = require(ReplicatedStorage.astral.engine.ext["distortion.lua"])

--// Module
local module = {}

--// Config
local IDLE_THRESHOLD = 0.1
local WALK_THRESHOLD = 49
local RUN_THRESHOLD = 50
local JET_THRESHOLD = 85
local DASHING_THRESHOLD = 121
local BOOSTIN_THRESHOLD = 230

--// Animation state
local currentTrack = nil
local lastFloorMaterial = Enum.Material.Air
local landedRecently = false
local jumpball = nil
local isTricking = false
--// Jump & cooldown config
local jumpThreshold = 0.10       -- Time threshold to distinguish jump vs jumpball (seconds)
local shortJumpPower = 32.9      -- JumpPower for short jump
local jumpballPower = 50.145     -- JumpPower for jumpball
local jumpCooldown = 0.5         -- Cooldown in seconds before next jump allowed
local rot = -90

--// State for jump input
local jumpPressTime = nil
local lastPressDuration = nil
local jumpAnim = "Jumpball"
local jumpballList = {"Jumpball", "Jumpball2", "Jumpball3", "Generations"}
local lastJumpTime = 0
local isBoosting = false
local boostObj = nil
local AirBoosted = false
local isQTE = false
local currentQTEConnection = nil
local qteFinished = false
local takingDamage = false
local currentSession = {}
local player = Players.LocalPlayer
local rail = nil
local onPath = false
local lastPath = nil
local pathTime = 0
local pathSpeed = 0
local pathXOffset = 0
local jumpTime = 0
local isRail = false
local bodyVelocity, bodyGyro, grindSound, spark1, spark2
local crouching = false
local speedMultiplier = 1

game.ReplicatedStorage.astral.engine.assets.sfx.Stages["Windmill Isle"]:Play()
local footstepSounds = {
	[Enum.Material.Grass] = {Left = "rbxassetid://122555270783573", Right = "rbxassetid://104370572237767"},
	[Enum.Material.Concrete] = {Left = "rbxassetid://74027612242679", Right = "rbxassetid://81950328263388"},
	[Enum.Material.Metal] = {Left = "rbxassetid://117040210492535", Right = "rbxassetid://117040210492535"},
}


local defaultFootstep = {Left = "rbxasset://sounds/action_footsteps_plastic.mp3", Right = "rbxasset://sounds/action_footsteps_plastic.mp3"}

local module = {}
local SFX = ReplicatedStorage:WaitForChild("astral"):WaitForChild("engine"):WaitForChild("assets"):WaitForChild("sfx")

local function playFootstep(material, foot)
	local soundName = material.Name .. "_" .. foot 
	local sound = SFX:FindFirstChild(soundName)
	if sound then
		sound:Play()
	else
		warn("Footstep sound not found:", soundName)
		SFX.Plastic:Play()
	end
end

--// Helper to load animations using Animator
local function loadAnimations(animator)
	local animFolder = ReplicatedStorage:FindFirstChild("astral")
		:FindFirstChild("engine")
		:FindFirstChild("assets")
		:FindFirstChild("animations")

	if not animFolder then
		warn("[astral @ playerAnimationController] Animation folder not found.")
		return {}
	end

	local function load(id)
		local obj = animFolder:FindFirstChild(id)
		if not obj then
			warn("[astral @ playerAnimationController] Animation", id, "not found.")
			return nil
		end

		local animTrack = animator:LoadAnimation(obj)
		animTrack:GetMarkerReachedSignal("Footstep"):Connect(function(p)
			local material = game.Players.LocalPlayer.Character.Humanoid.FloorMaterial

			if p == "Left" then
				playFootstep(material, "Left")
			elseif p == "Right" then
				playFootstep(material, "Right")
			end
		end)
		return animTrack
	end

	return {
		Idle = load("Idle"),
		Walk = load("Walk"),
		Run  = load("Run"),
		Fall = load("Fall"),
		Jump = load("Jump"),
		Land = load("Land"),
		Jet = load("Jet"),
		Dash = load("Dash"),
		Boost = load("Boost"),
		TrickA = load("TrickA"),
		TrickB = load("TrickB"),
		Stomp = load("Stomp"),
		Spring = load("Spring"),
		QTE = load("QTE"),
		Damage = load("Damage"),
		Standup = load("Standup"),
		AirBoost = load("AirBoost"),
		Jumpball = load("Jumpball"),
		Grind = load("Grind"),
		Dance = load("Dance"),
		ResultLook = load("ResultLook"),
		Trip = load("Trip")
	}
end

module.LoadAnimations = loadAnimations


local shiftP = Players.LocalPlayer.PlayerGui:WaitForChild("Freecam")
shiftP:Destroy()

--[[// Helper to play animation safely with priority and clash prevention																								                                                                         																										]]																				
local finish = false





local function playAnimation(animations, name)
	-- Prevent jumpball animation if AirBoost is active
	if name == "Jumpball" and AirBoosted then
		return
	end

	if currentTrack and currentTrack.IsPlaying then
		if currentTrack.Name == name then return end

		-- Stop jumpball, fall, and jump animations immediately when switching
		if currentTrack.Name == "Jumpball" or currentTrack.Name == "Fall" or currentTrack.Name == "Jump" then
			currentTrack:Stop()
		else
			currentTrack:Stop(0.4)
		end
	end

	local newTrack = animations[name]
	if newTrack then
		if name == "AirBoost" or name == "Spring" then
			newTrack.Priority = Enum.AnimationPriority.Action
		else
			newTrack.Priority = Enum.AnimationPriority.Movement
		end

		if name == "Dash" then
			newTrack:AdjustSpeed(2)
		else
			newTrack:AdjustSpeed(1) -- Normal speed for other
		end
		newTrack:Play()

		if name == "Dash" or name == "Boost" then
			if name == "Dash" then
				newTrack:AdjustSpeed(4)
			end
			if name == "Boost" then
				newTrack:AdjustSpeed(Utils:get("BoostAnimSpeed"))
			end
		else
			newTrack:AdjustSpeed(1)
		end
		currentTrack = newTrack
	end
end




local canTakeDMG = true;
--// Main controller
function module.Start()
	local player = Players.LocalPlayer
	if not player then return end

	local humanoid
	local animations
	
	local function attachToRail(newRail)
		if (newRail ~= rail or rail == nil) and player.Character then
			isRail = true
			local character = player.Character
			playAnimation(animations, "Grind")
			if rail == nil then
				local speedDiff = math.max((character.HumanoidRootPart.Velocity.Magnitude - 80) / 75, 0)
				speedMultiplier = 1 + speedDiff
			end

			rail = newRail
			bodyVelocity.MaxForce = Vector3.new(10000, 10000, 10000)
			bodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)

			grindSound.Pitch = 1
			grindSound:Play()

			bodyGyro.CFrame = rail.CFrame
			character.Humanoid.PlatformStand = true

			local xOffset = rail.CFrame:ToObjectSpace(character.HumanoidRootPart.CFrame).Position.X
			pathXOffset = xOffset

			local zOffset = rail.CFrame:ToObjectSpace(character.HumanoidRootPart.CFrame).Position.Z
			local rot = character.HumanoidRootPart.CFrame - character.HumanoidRootPart.CFrame.Position

			character.HumanoidRootPart.CFrame = CFrame.new((rail.CFrame * CFrame.new(xOffset, 3, zOffset)).Position) * rot
			local velocityDirection = CFrame.new(character.HumanoidRootPart.Position, rail.CFrame * CFrame.new(0, 3, -rail.Size.Z / 2 - 2).Position).LookVector
			local velocity = velocityDirection * (80 * speedMultiplier)
			character.HumanoidRootPart.Velocity = velocity
			bodyVelocity.Velocity = velocity
		end
	end
	
	task.spawn(function()
		task.delay(1, function()
			Utils:showHint({
				Character = "Chip",
				CharacterEmotion = "Happy",
				Text = 'Welcome to <font color="#800080">Astral</font> Engine!\n\nEngine Build: ' .. script.Parent.Parent["@astral"]:GetAttribute("EngineVersion")
			})
		end)
	end)

	local function attachToPath(newPath)
		if (newPath ~= rail or rail == nil) and player.Character then
			local character = player.Character
			local humanoid = character.Humanoid
			local hrp = character.HumanoidRootPart
			local moveDirMag = humanoid.MoveDirection.Magnitude
			local hrpVelMag = hrp.Velocity.Magnitude

			if moveDirMag > 0.5 and (hrpVelMag > 32 or newPath.CFrame.LookVector.Y < 0) then
				if not (tick() - pathTime < 0.5 and newPath == lastPath) then
					if rail == nil then
						pathSpeed = math.max(64, hrpVelMag)
					end

					rail = newPath
					onPath = true
					bodyVelocity.MaxForce = Vector3.new(10000, 10000, 10000)
					bodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)

					if not grindSound.IsPlaying then
						grindSound:Play()
					end

					bodyGyro.CFrame = rail.CFrame
					humanoid.PlatformStand = true

					local xOffset = rail.CFrame:ToObjectSpace(hrp.CFrame).Position.X
					if not rail:FindFirstChild("Center") then
						pathXOffset = 0
					else
						pathXOffset = xOffset
					end

					local zOffset = rail.CFrame:ToObjectSpace(hrp.CFrame).Position.Z
					local rot = hrp.CFrame - hrp.CFrame.Position

					hrp.CFrame = CFrame.new((rail.CFrame * CFrame.new(xOffset, 3, zOffset)).Position) * rot
					local velocityDir = CFrame.new(hrp.Position, rail.CFrame * CFrame.new(pathXOffset, 3, -rail.Size.Z / 2 - 2).Position).LookVector
					local velocity = velocityDir * pathSpeed
					hrp.Velocity = velocity
					bodyVelocity.Velocity = velocity
				end
			end
		end
	end

	local function bindPartTouch(part)
		part.Touched:Connect(function(touchedPart)
			if tick() - jumpTime > 1 then
				local CollectionService = game:GetService("CollectionService")

				if CollectionService:HasTag(touchedPart, "Rail") then
					attachToRail(touchedPart)
				elseif touchedPart.Name == "Pathlock" and CollectionService:HasTag(touchedPart, "Rail") then
					attachToPath(touchedPart)
				end
			end
		end)
	end

	local TweenService = game:GetService("TweenService")
	local currentReticle = nil



	local function removeHomingReticle()
		if currentReticle then
			local reticle = currentReticle
			currentReticle = nil

			local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local tween = TweenService:Create(reticle, tweenInfo, { Size = UDim2.new(0, 0, 0, 0) })
			tween:Play()
			tween.Completed:Connect(function()
				reticle:Destroy()
			end)
		end
	end

	local function createHomingReticle(target)
		if currentReticle then
			currentReticle:Destroy()
			currentReticle = nil
		end

		if not target then
			return
		end

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 0, 0, 0) -- Start
		billboard.StudsOffset = Vector3.new(0, 2, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = target

		local image = Instance.new("ImageLabel")
		image.Size = UDim2.new(1, 0, 1, 0)
		image.BackgroundTransparency = 1
		image.Image = "http://www.roblox.com/asset/?id=10414482597" 
		image.Parent = billboard
		image.ImageColor3 = Color3.fromRGB(117, 255, 96)
		billboard.Parent = target
		currentReticle = billboard
		game.ReplicatedStorage.astral.engine.assets.sfx.HomingAttack_Lock:Play()

		local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(billboard, tweenInfo, { Size = UDim2.new(0, 64, 0, 64) })
		tween:Play()
		task.delay(1, function()
			if billboard.Parent and billboard == currentReticle then
				removeHomingReticle()
			elseif billboard.Parent then
				billboard:Destroy()
			end
		end)
	end
	local canattack = true
	local idx = 1
	local shockwave = game.Players.LocalPlayer.PlayerGui.ScreenGui:WaitForChild("Shockwave")

	local function playShockwave()
		shockwave.Size = UDim2.fromScale(0, 0)
		shockwave.ImageTransparency = 0

		local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(shockwave, tweenInfo, {
			Size = UDim2.new(1,0,1,0),
			--ImageTransparency = 1
		})
		tween:Play()
		tween.Completed:Connect(function()
			shockwave.ImageTransparency =1
		end)
	end
	
	local function camShake(intensity, duration)
		local startTime = tick()
		local cam = workspace.CurrentCamera
		local conn

		conn = game:GetService("RunService").RenderStepped:Connect(function()
			local elapsed = tick() - startTime
			if elapsed > duration then
				conn:Disconnect()
				cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + cam.CFrame.LookVector) -- resetz
				return
			end

			local offset = Vector3.new(
				(math.random() - 0.5) * intensity,
				(math.random() - 0.5) * intensity,
				0
			)
			cam.CFrame = cam.CFrame * CFrame.new(offset)
		end)
	end


	-- Handlez
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.T and not isQTE then
			idx += 1;
			if (idx > 3) then idx = 1 end
			Utils:_set("Jumpball", jumpballList[idx])
			Utils:showHint({
				Character = "Chip",
				CharacterEmotion = "Happy",
				Text = "Sonic, press T to change your jumpball!"
			})
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.LeftShift then
			if isQTE then return end
			if takingDamage then return end
			--if game.ReplicatedStorage.astral.engine.assets.sfx.Stages.EqualizerSoundEffect then
			--game.ReplicatedStorage.astral.engine.assets.sfx.Stages.EqualizerSoundEffect.Parent = game.ReplicatedStorage.astral.engine.assets.sfx.Stages["Windmill Isle"][][][][][][][][][]][][][][][][][][][][][][][][][][][][][][][]
			--end
			--game.ReplicatedStorage.astral.engine.assets.sfx.Stages["Windmill Isle"]:Stop()
			--game.ReplicatedStorage.astral.engine.assets.sfx.Stages["Windmill Isle"]:Resume()
			local humanoid2 = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid2.MoveDirection.Magnitude < 0.1 then
				return
			else
				if Utils:getProperty("sv_boost") <= 0 then return end
				playShockwave()
				if Utils:get("CamShakeBoost") then
					camShake(.6, .1)
				end
				if Utils:get("DistortionEffect") then
					distortion.CreateCameraBubble(
						Vector3.zero,   -- start size
						5,                    -- start transparency
						Vector3.new(60.5, 0.5, 60.5),   -- end size
						1                      -- lifetime
	
					)
				end
				Utils:fieldOfView(85)
				Utils:setProperty("r_isBoosting", true)
				if humanoid2 and humanoid2.FloorMaterial == Enum.Material.Air then
					AirBoosted = true
					local list = {"chr_Sonic_HD.005", "chr_Sonic_HD.006", "chr_Sonic_HD.007", "chr_Sonic_HD.008"}
					for _,v in list do game.Players.LocalPlayer.Character[v].Transparency = 0 end
					-- Destroy jumpball
					if jumpball then
						jumpball:Destroy()
						jumpball = nil
					end

					-- Stop jumpball animation if playing
					if animations.Jumpball and animations.Jumpball.IsPlaying then
						animations.Jumpball:Stop()
					end
					local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
					local dashStrength = 156
					rootPart.Velocity = rootPart.Velocity + rootPart.CFrame.LookVector * dashStrength

					playAnimation(animations, "AirBoost")

					-- Reset AirBoosted when land
					task.spawn(function()
						repeat task.wait() until not (humanoid2.FloorMaterial == Enum.Material.Air)
						AirBoosted = false
					end)
				end
				
				if Utils:get("NewBoost") then
					boostObj = ReplicatedStorage.astral.engine.assets.misc.Boost:Clone()
					boostObj.Parent = humanoid.Parent
					--boostObj.PrimaryPart = boostObj:FindFirstChild("Main")
					local animController = boostObj:FindFirstChildOfClass("AnimationController")
					if animController then
						local rotationAnim = animController:LoadAnimation(game.ReplicatedStorage.astral.engine.assets.animations.BoostModel)
						rotationAnim:Play()
						rotationAnim:AdjustSpeed(5)

					end
				else
					boostObj = ReplicatedStorage.astral.engine.assets.misc.NewBoost:Clone()
					boostObj.Parent = humanoid.Parent
					boostObj.PrimaryPart = boostObj:FindFirstChild("Main")
				end
				boostObj:SetPrimaryPartCFrame(player.Character.PrimaryPart.CFrame * CFrame.new(0, 0, -0.9))

				isBoosting = true
				humanoid.WalkSpeed = 230
				local angle = 0
				local r = ReplicatedStorage.astral.engine.assets.voices.boost:GetChildren()[math.random(1, #ReplicatedStorage.astral.engine.assets.voices.boost:GetChildren())]:Clone()
				r.PlayOnRemove = true
				r.Parent = game.SoundService
				r:Destroy()

				local r2 = ReplicatedStorage.astral.engine.assets.sfx.Boost_Start:Clone()
				r2.PlayOnRemove = true
				r2.Parent = game.SoundService
				r2:Destroy()

				local r3 = ReplicatedStorage.astral.engine.assets.sfx.Boost_Air:Clone()
				r3.Parent = game.SoundService
				r3:Play()
				local r4 = ReplicatedStorage.astral.engine.assets.sfx.Boost_Upkeep:Clone()
				r4.Parent = game.SoundService
				r4:Play()

				task.spawn(function()
					repeat
						game["Run Service"].Heartbeat:Wait() -- ~600 FPS - dont need speedscale for this x)
						if boostObj and boostObj.PrimaryPart then
							isBoosting = true
							humanoid.WalkSpeed = 230
							angle += math.rad(180) * 0.3 -- rotates 180° per second 3
							if Utils:get("NewBoost") then
								local charCFrame = player.Character.PrimaryPart.CFrame * CFrame.new(0, 0, -0.9)
								--local rotation = CFrame.Angles(0, 0, angle)
								boostObj:SetPrimaryPartCFrame(charCFrame)
							else
								local charCFrame = player.Character.PrimaryPart.CFrame * CFrame.new(0, 0, -0.9)
								local rotation = CFrame.Angles(0, 0, angle)
								boostObj:SetPrimaryPartCFrame(charCFrame * rotation)
							end
						end
					until not boostObj or Utils:getProperty("sv_boost") <= 0 or isTricking or takingDamage
					Utils:fieldOfView(70)
					Utils:setProperty("r_isBoosting", false)
					if game.SoundService:FindFirstChild("Boost_Air") then game.SoundService:FindFirstChild("Boost_Air"):Destroy() end  
					if game.SoundService:FindFirstChild("Boost_Upkeep") then game.SoundService:FindFirstChild("Boost_Upkeep"):Destroy() end 
				end)
			end
		end
		local angle2 = 0
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Q then
			if not (humanoid.FloorMaterial == Enum.Material.Air) then return end
			if isQTE then return end
			if takingDamage then return end
			if jumpball then jumpball:Destroy() end
			isTricking = true
			workspace.Gravity = 650 
			local r = ReplicatedStorage.astral.engine.assets.sfx.Stomp_Start:Clone()
			r.PlayOnRemove = true
			r.Parent = game.SoundService
			r:Destroy()
			task.spawn(function()
				local trickTrack = animations["Stomp"]
				trickTrack.Priority = Enum.AnimationPriority.Action -- Set priority to highest since it would override anim otherwise

				playAnimation(animations, "Stomp")
				local stompVFX = game.ReplicatedStorage.astral.engine.assets.misc.Stomp:Clone()
				stompVFX.Parent = game.Players.LocalPlayer.Character

				repeat game["Run Service"].Heartbeat:Wait()
					local baseCFrame = game.Players.LocalPlayer.Character.PrimaryPart.CFrame.Position - Vector3.new(0, 2, 0)
					local rotation = CFrame.Angles(0, angle2, 0) -- rotate around.

					angle2 += math.rad(5) -- rotate 5 degrees per frame
					stompVFX:SetPrimaryPartCFrame(CFrame.new(baseCFrame) * rotation)
				until not (humanoid.FloorMaterial == Enum.Material.Air) or takingDamage

				stompVFX:Destroy()

				--stompParticle:Destroy()
				workspace.Gravity = 170
				if takingDamage then
					workspace.Gravity = 0
				end
				isTricking = false
				r = ReplicatedStorage.astral.engine.assets.sfx.Stomp_Land:Clone()
				r.PlayOnRemove = true
				r.Parent = game.SoundService
				r:Destroy()
				local stompParticle = game.ReplicatedStorage.astral.engine.assets.particles.Stomp:Clone()
				stompParticle.Parent = game.Players.LocalPlayer.Character
				--stompParticle.CFrame = game.Players.LocalPlayer.Character.PrimaryPart.CFrame - Vector3.new(0, 2, 0)
				local player = game.Players.LocalPlayer
				local rootPart = player.Character and player.Character.PrimaryPart
				if not rootPart then return end

				local rayOrigin = rootPart.Position
				local rayDirection = Vector3.new(0, -50, 0)  

				local raycastParams = RaycastParams.new()
				raycastParams.FilterDescendantsInstances = {player.Character} -- ignore player character
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude

				local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

				if raycastResult then
					local groundPosition = raycastResult.Position
					stompParticle.Particle.WorldCFrame = CFrame.new(groundPosition) * CFrame.Angles(0, rootPart.Orientation.Y, 0)
				else
					stompParticle.Particle.WorldCFrame = rootPart.CFrame - Vector3.new(0, 8.2, 0)
				end

				--stompParticle.Particle.Shock1:Emit(10)
				--stompParticle.Particle.Shock2:Emit(50)
				task.spawn(function()
					task.wait(0.3)
					stompParticle:Destroy()
				end)
			end)
		end

		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
			if isQTE then return end
			if takingDamage then return end
			local character = player.Character
			local target = Utils:getNearestAttackable(player.Character:FindFirstChild("HumanoidRootPart").Position, 80)
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local target = Utils:getNearestAttackable(hrp.Position, 80)
				if target and Utils:isObjectVisibleToPlayer(target, player) then
					createHomingReticle(target)
				else
					removeHomingReticle()
				end
			end

			if rail ~= nil then
				jumpTime = tick()
				rail = nil
				onPath = false
				bodyVelocity.MaxForce = Vector3.new(0, 0, 0)
				bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
				--spark1.Enabled = false
				--spark2.Enabled = false
				grindSound:Stop()
				character.Humanoid.PlatformStand = false
				character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				local hrp = character.HumanoidRootPart
				hrp.Velocity = hrp.Velocity + hrp.CFrame.UpVector * 50
				hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z))
				isRail = false
			end
			if not (humanoid.FloorMaterial == Enum.Material.Air) then
				local r = ReplicatedStorage.astral.engine.assets.sfx.Jump_Start:Clone()
				r.PlayOnRemove = true
				r.Parent = game.SoundService
				r:Destroy()
			end
			jumpPressTime = tick()
			if jumpball and jumpball.PrimaryPart or humanoid.FloorMaterial == Enum.Material.Air then
				if isQTE then return end
				--print(target and target.Name or "No target")
				if target and Utils:isObjectVisibleToPlayer(target, game.Players.LocalPlayer)  then
					
					if not canattack then return end
					--createHomingReticle(target)
					if game.Players.LocalPlayer.Character.PrimaryPart:FindFirstChild("BV") then
						game.Players.LocalPlayer.Character.PrimaryPart:FindFirstChild("BV"):Destroy()
					
					end
					if game.Players.LocalPlayer.Character.PrimaryPart:FindFirstChild("BP") then
						game.Players.LocalPlayer.Character.PrimaryPart:FindFirstChild("BP"):Destroy()

					end
					canTakeDMG =false
					canattack = false
					task.delay(0.25, function()
						canattack= true
					end)
					if jumpball then jumpball:Destroy() end
					jumpAnim = "Jumpball"

					--target.CanCollide = false
					local r = ReplicatedStorage.astral.engine.assets.sfx.HomingAttack_Start:Clone()
					r.PlayOnRemove = true
					r.Parent = game.SoundService
					r:Destroy()
					removeHomingReticle()
					humanoid.PlatformStand = true -- disables jumping/movement temp
					local hrp = player.Character:FindFirstChild("HumanoidRootPart")
					local dir = (target.Position - hrp.Position).Unit
					hrp.CFrame = CFrame.new(hrp.Position, target.Position)
					local bv = Instance.new("BodyVelocity")
					bv.Name = 'BV'
					bv.Velocity = dir * 190
					bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
					bv.P = 1e4
					bv.Parent = hrp
					local bp = Instance.new("BodyPosition")
					bp.Position = target.Position
					bp.MaxForce = Vector3.new(1e5, 1e5, 1e5)
					bp.Name = 'BP'
					bp.P = 5e4
					bp.D = 1e3
					bp.Parent = hrp
					if not (target.Name == "spring") then
						r = ReplicatedStorage.astral.engine.assets.sfx.Explosion1_Start:Clone()
						r.PlayOnRemove = true
						r.Parent = game.SoundService
						r:Destroy()
					end
					Utils:setProperty("sv_score", Utils:getProperty("sv_score")+500)
					task.wait(.2)

					bv:Destroy()
					bp:Destroy()
					r = ReplicatedStorage.astral.engine.assets.voices.boost:GetChildren()[math.random(1, #ReplicatedStorage.astral.engine.assets.voices.boost:GetChildren())]:Clone()
					r.PlayOnRemove = true
					r.Parent = game.SoundService
					r:Destroy()
					if not (target.Name == "spring") then
						local rand = math.random(1, 2)
						local trickAnimName = (rand == 1) and "TrickA" or "TrickB"
						local trickTrack = animations[trickAnimName]

						if trickTrack then
							task.spawn(function()
								isTricking = true
								trickTrack.Looped = false 
								playAnimation(animations, trickAnimName)
								trickTrack.Stopped:Wait()
								isTricking = false
								task.delay(0.3, function()
									canTakeDMG = true
								end)
							end)
						end
					end
					humanoid.PlatformStand = false
					local bodyPos = nil
					if not (target.Name == "spring") then
						local vel = hrp.Velocity
						hrp.Velocity = Vector3.new(0, vel.Y, 0)
						bodyPos = Instance.new("BodyPosition")
						bodyPos.MaxForce = Vector3.new(0, 1e5, 0) -- only vertical force
						bodyPos.P = 1e4
						bodyPos.Position = hrp.Position + Vector3.new(0, 30, 0) -- push 10 studs up
						bodyPos.Parent = hrp
					end



					task.delay(0.1, function()
						if bodyPos then bodyPos:Destroy() end
						if not (target.Name == "spring") then
							local vel = hrp.Velocity
							hrp.Velocity = Vector3.new(0, vel.Y, 0)
						end
					end)
					local tpos = target.Position
					if not (target.Name == "spring") then
						if target and target.Parent then target.Parent:Destroy() end
					end
					if not (target.Name == "spring") then
						local exp = Instance.new("Explosion")
						exp.Parent = workspace
						exp.BlastPressure = 0
						exp.DestroyJointRadiusPercent = 0
						exp.ExplosionType=Enum.ExplosionType.NoCraters
						exp.Position = tpos
						task.delay(0.5, function()
							exp:Destroy()
						end)
					end
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
					if hrp then
						local target = Utils:getNearestAttackable(hrp.Position, 80)
						if target and Utils:isObjectVisibleToPlayer(target, player) then
							createHomingReticle(target)
						else
							removeHomingReticle()
						end
					end
				else
					if jumpball and jumpball.PrimaryPart then
						local r = ReplicatedStorage.astral.engine.assets.sfx.HomingAttack_Start:Clone()
						r.PlayOnRemove = true
						r.Parent = game.SoundService
						r:Destroy()
						local humanoid2 = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
						local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
						jumpball:Destroy()
						local dashStrength = 156
						rootPart.Velocity = rootPart.Velocity + rootPart.CFrame.LookVector * dashStrength
						Utils:createTrailTunnel()
					end
				end
			end
		end
	end)
	local hdelay=false
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
			if not jumpPressTime then return end
			lastPressDuration = tick() - jumpPressTime
			jumpPressTime = nil
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.LeftShift then
			Utils:setProperty("r_isBoosting", false)
			Utils:fieldOfView(70)

			if boostObj then 
				boostObj:Destroy() 
				boostObj = nil 
				isBoosting = false 
				--game.ReplicatedStorage.astral.engine.assets.sfx.Stages["Windmill Isle"]:Stop()
				--game.ReplicatedStorage.astral.engine.assets.sfx.Stages["Windmill Isle"]:Resume()
				if game.SoundService:FindFirstChild("Boost_Air") then game.SoundService:FindFirstChild("Boost_Air"):Destroy() end  
				if game.SoundService:FindFirstChild("Boost_Upkeep") then game.SoundService:FindFirstChild("Boost_Upkeep"):Destroy() end 
			end
		end
	end)
	local speedThresholds = {
		["01"] = 16,
		["02"] = 22,
		["03"] = 30,
		["04"] = 40,
		["05"] = 50,
		["06"] = 60,
		["07"] = 70,
		["08"] = 80,
		["09"] = 90,
		["10"] = 100,
		["11"] = 105,
		["12"] = 110,
		["13"] = 115,
		["14"] = 120,
		["15"] = 121,
		["16"] = 122,
		["17"] = 123,
		["18"] = 124,
		["19"] = 125,
		["20"] = 230,
	}

	local startTime = os.clock()


	local frame = game.Players.LocalPlayer.PlayerGui.ScreenGui.Hold.Left.Bottom.Gauge.Speed
	local function updateSpeedometer(currentSpeed)
		for i = 1, 20 do
			local labelName = (i <= 9) and ("0"..i) or tostring(i)
			local indicator = frame:FindFirstChild(labelName)
			if indicator and indicator:IsA("ImageLabel") then
				local threshold = speedThresholds[labelName] or math.huge
				indicator.Visible = currentSpeed >= threshold
			end
		end
	end
	local Can = true;
	local d = false;
	local function tweenBallColor(ball)

		local goal = {Color = Color3.fromRGB(255, 255, 127)}
		local tweenInfo = TweenInfo.new(
			0.5,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out
		)

		local tween = TweenService:Create(ball, tweenInfo, goal)
		tween:Play()
	end
	local df = true;
	local function playCP(controller, animId)
		if not controller or not controller:IsA("AnimationController") then return end
		--local animation = Instance.new("Animation")
		--animation.AnimationId = animId
		local track = controller:LoadAnimation(game.ReplicatedStorage.astral.engine.assets.animations.Enemy.Checkpoint)
		track:Play()
		track:AdjustSpeed(1.5)
	end

	task.spawn(function()
		local CollectionService = game.CollectionService
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local hrp = game.Players.LocalPlayer.Character.PrimaryPart

		while task.wait() do
			task.spawn(function()
				local elapsed = os.clock() - startTime

				local minutes = math.floor(elapsed / 60)
				local seconds = math.floor(elapsed % 60)
				local milliseconds = math.floor((elapsed * 100) % 100) -- hundredths

				local timeString = string.format("%02d:%02d:%02d", minutes, seconds, milliseconds)
				TextDraw.Draw({
					Text = timeString,
					LetterSize = UDim2.new(0, 20, 0,20),
					Spacing = 0,
					Parent = game.Players.LocalPlayer.PlayerGui.ScreenGui.Hold.Left.Top.TimeBar.TimeValue
				})
				Utils:setProperty("sv_time", timeString)
				task.wait()
			end)
			if not isTricking and not canTakeDMG and not takingDamage then
				canTakeDMG = true
			end
			
			for _, bomb in CollectionService:GetTagged("Bomb") do
				if bomb and bomb.Parent then
					local bombSize = bomb.PrimaryPart.Size
					local checkRadius = math.max(bombSize.X, bombSize.Y, bombSize.Z) / 2 + 4 -- half size + some buffer
					
					local distance = (bomb.PrimaryPart.Position - hrp.Position).Magnitude
					
					if distance <= checkRadius then
						game.ReplicatedStorage.astral.engine.assets.sfx.Bomb_Explode:Play()
						local r = ReplicatedStorage.astral.engine.assets.voices.hurt:GetChildren()[math.random(1, #ReplicatedStorage.astral.engine.assets.voices.hurt:GetChildren())]:Clone()
						r.PlayOnRemove = true
						r.Parent = game.SoundService
						r:Destroy()
						if Utils:getProperty("r_isBoosting") then
							if Utils:getProperty("sv_rings") > 0 then
								canTakeDMG = false
								game.ReplicatedStorage.astral.engine.assets.sfx.Ring_Drop:Play()
								takingDamage = true
								playAnimation(animations, "Trip")
								task.delay(1, function()
									takingDamage = false
								end)
								task.delay(2, function()
									canTakeDMG = true
								end)
							else
								canTakeDMG = false
								takingDamage = true
								playAnimation(animations, "Damage")
								task.spawn(function()
									repeat task.wait()
										game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 0
									until not takingDamage
								end)

								local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
								if hrp then
									local bodyPos = Instance.new("BodyPosition")
									bodyPos.MaxForce = Vector3.new(1e5, 1e5, 1e5)
									bodyPos.P = 1e4

									local direction = (-hrp.CFrame.LookVector + Vector3.new(0, 0.3, 0)).Unit
									local knockbackDistance = 40
									bodyPos.Position = hrp.Position + direction * knockbackDistance
									bodyPos.Parent = hrp

									task.delay(0.15, function()
										bodyPos:Destroy()
									end)
								end

								task.delay(1.39, function()
									Utils:setProperty("sv_lives", Utils:getProperty("sv_lives") - 1)
									TextDraw.Draw({
										Text = f.format2(Utils:getProperty("sv_lives")),
										LetterSize = UDim2.new(0, 27, 0, 27),
										Spacing = 0,
										Parent = game.Players.LocalPlayer.PlayerGui.ScreenGui.Hold.Left.Top.LifeIcon.Frame
									})
									Death:Die()
								end)

								task.delay(3, function()
									canTakeDMG = true
									takingDamage = false
								end)
							end
						else
							if Utils:getProperty("sv_rings") > 0 then
								canTakeDMG = false
								game.ReplicatedStorage.astral.engine.assets.sfx.Ring_Drop:Play()
								takingDamage = true
								playAnimation(animations, "Damage")
								task.spawn(function()
									repeat task.wait()
										game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 0
									until not takingDamage
								end)

								local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
								if hrp then
									local bodyPos = Instance.new("BodyPosition")
									bodyPos.MaxForce = Vector3.new(1e5, 1e5, 1e5)
									bodyPos.P = 1e4

									local direction = (-hrp.CFrame.LookVector + Vector3.new(0, 0.3, 0)).Unit
									local knockbackDistance = 40
									bodyPos.Position = hrp.Position + direction * knockbackDistance
									bodyPos.Parent = hrp

									task.delay(0.15, function()
										bodyPos:Destroy()
										Death:dropRings()
									end)
								end

								task.delay(1, function()
									playAnimation(animations, "Standup")
									task.wait(0.46)
									takingDamage = false
								end)
								task.delay(2, function()
									canTakeDMG = true
								end)
							else
								canTakeDMG = false
								takingDamage = true
								playAnimation(animations, "Damage")
								task.spawn(function()
									repeat task.wait()
										game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 0
									until not takingDamage
								end)

								local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
								if hrp then
									local bodyPos = Instance.new("BodyPosition")
									bodyPos.MaxForce = Vector3.new(1e5, 1e5, 1e5)
									bodyPos.P = 1e4

									local direction = (-hrp.CFrame.LookVector + Vector3.new(0, 0.3, 0)).Unit
									local knockbackDistance = 40
									bodyPos.Position = hrp.Position + direction * knockbackDistance
									bodyPos.Parent = hrp

									task.delay(0.15, function()
										bodyPos:Destroy()
									end)
								end

								task.delay(1.39, function()
									Utils:setProperty("sv_lives", Utils:getProperty("sv_lives") - 1)
									TextDraw.Draw({
										Text = f.format2(Utils:getProperty("sv_lives")),
										LetterSize = UDim2.new(0, 27, 0, 27),
										Spacing = 0,
										Parent = game.Players.LocalPlayer.PlayerGui.ScreenGui.Hold.Left.Top.LifeIcon.Frame
									})
									Death:Die()
								end)

								task.delay(3, function()
									canTakeDMG = true
									takingDamage = false
								end)
							end
						end
						local e = Instance.new("Explosion", workspace)
						e.BlastPressure = 0
						e.DestroyJointRadiusPercent = 0
						e.Position = bomb.PrimaryPart.Position
						bomb:Destroy()
					end
				end
			end
			
			for _, bomb in CollectionService:GetTagged("HintRing") do
				if bomb and bomb.Parent then
					local bombSize = bomb.PrimaryPart.Size
					local checkRadius = math.max(bombSize.X, bombSize.Y, bombSize.Z) / 2 + 4 -- half size + some buffer

					local distance = (bomb.PrimaryPart.Position - hrp.Position).Magnitude

					if distance <= checkRadius then
						if not hdelay then
							hdelay=true
							Utils:showHint({
								Character = bomb:GetAttribute("Character"),
								CharacterEmotion = bomb:GetAttribute("CharacterEmotion"),
								Text = string.gsub(bomb:GetAttribute("Text") or "", "\\n", "\n")
							})
							task.delay(5,function()
								hdelay=false
							end)
						end
					end
				end
			end
			
			for _, cp in CollectionService:GetTagged("Checkpoints") do
				if cp and cp.Parent then
					local cpSize = cp.cmn_obj_pointmarker.Size
					local checkRadius = math.max(cpSize.X, cpSize.Y, cpSize.Z) / 2 + 4 -- half size + some buffer

					local distance = (cp.cmn_obj_pointmarker.Position - hrp.Position).Magnitude
					
					if distance <= checkRadius and not d then
						d = true
						game.ReplicatedStorage.astral.engine.assets.sfx.Checkpoint_Start:Play()
						local pointR = cp:WaitForChild("pointmarkerL")
						local controllerR = pointR:FindFirstChildWhichIsA("AnimationController")
						local ballR = pointR:WaitForChild("cmn_obj_pointmarkerL_ball")

						if controllerR then
							playCP(controllerR, game.ReplicatedStorage.astral.engine.assets.animations.Enemy.Checkpoint)
							tweenBallColor(ballR)
						end

						local pointL = cp:WaitForChild("pointmarkerR")
						local controllerL = pointL:FindFirstChildWhichIsA("AnimationController")
						local ballL = pointL:WaitForChild("cmn_obj_pointmarkerL_ball")

						if controllerL then
							playCP(controllerL, game.ReplicatedStorage.astral.engine.assets.animations.Enemy.Checkpoint)
							tweenBallColor(ballL)
						end
						if cp:FindFirstChild("Beam") then
							cp.Beam:Destroy()
							cp.light_source.PointLight:Destroy()
						end
						task.delay(1, function()
							d = false
						end)
					end
				end
			end
			updateSpeedometer(game.Players.LocalPlayer.Character.Humanoid.WalkSpeed)
			for _, spring in CollectionService:GetTagged("Springs") do
				if spring.PrimaryPart and spring.Parent then
					local springSize = spring.PrimaryPart.Size
					local checkRadius = math.max(springSize.X, springSize.Y, springSize.Z) / 2 + 4 -- half size + some buffer

					local distance = (spring.PrimaryPart.Position - hrp.Position).Magnitude

					if distance <= checkRadius then
						Can = false
						isTricking = true

						task.spawn(function()
							playAnimation(animations, "Spring")
							task.wait(0.4)
							isTricking=false

						end)
						local Character = game.Players.LocalPlayer.Character
						if Character.PrimaryPart:FindFirstChildOfClass("BodyPosition") then
							Character.PrimaryPart:FindFirstChildOfClass("BodyPosition"):Destroy()
						end
						task.spawn(function()
							repeat
								task.wait(0.0000000001)
								Character.Humanoid.WalkSpeed = 0
							until not isTricking
						end)
						local HumanoidRootPart=Character:WaitForChild("HumanoidRootPart")
						local Boost = Instance.new("BodyPosition")
						Boost.Parent = HumanoidRootPart
						Boost.D = 1000
						Boost.P = 15000
						Boost.MaxForce = Vector3.new(1e6, 1e6, 1e6) -- full XYZ 

						local endpoint = spring.PrimaryPart:FindFirstChild("Endpoint", true)

						if endpoint and endpoint:IsA("Attachment") then
							Boost.Position = endpoint.WorldPosition
						else
							-- fallback
							Boost.Position = Vector3.new(0, HumanoidRootPart.Position.Y + spring:GetAttribute("Power"), 0)
						end
						game.ReplicatedStorage.astral.engine.assets.sfx.Spring_Start:Play()
						game.Debris:AddItem(Boost,0.6)
						task.wait(0.75)
						Can=true
					end
				end
			end
			
			for _, spring in CollectionService:GetTagged("DashRing") do
				if spring.PrimaryPart and spring.Parent then
					local springSize = spring.PrimaryPart.Size
					local checkRadius = math.max(springSize.X, springSize.Y, springSize.Z) / 2 + 4 -- half size + some buffer

					local distance = (spring.PrimaryPart.Position - hrp.Position).Magnitude

					if distance <= checkRadius then
						Can = false
						isTricking = true
						local Character = game.Players.LocalPlayer.Character
						if Character.PrimaryPart:FindFirstChildOfClass("BodyPosition") then
							Character.PrimaryPart:FindFirstChildOfClass("BodyPosition"):Destroy()
						end
						local vfx2 = game.ReplicatedStorage.astral.engine.assets.particles.DashRing:Clone()
						vfx2.Parent = workspace
						vfx2.CFrame = spring.PrimaryPart.CFrame--game.Players.LocalPlayer.Character.PrimaryPart.CFrame
						--vfx2.Attachment["1"].Enabled = true
						vfx2.Attachment.Stars:Emit(30)
						local r = ReplicatedStorage.astral.engine.assets.voices.boost:GetChildren()[math.random(1, #ReplicatedStorage.astral.engine.assets.voices.boost:GetChildren())]:Clone()
						r.PlayOnRemove = true
						r.Parent = game.SoundService
						r:Destroy()
						local rainbow = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromHSV(0/6, 1, 1)),
							ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
							ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
							ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
							ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
							ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
							ColorSequenceKeypoint.new(1, Color3.fromHSV(6/6, 1, 1)),
						}
						vfx2.Attachment.Stars.Color = rainbow

						
						task.delay(1,function()
							vfx2:Destroy()
						end)
						task.spawn(function()
							playAnimation(animations, "Spring")
							task.wait(0.2)
							isTricking=false
						end)
						local Character = game.Players.LocalPlayer.Character
						if Character.PrimaryPart:FindFirstChildOfClass("BodyPosition") then
							Character.PrimaryPart:FindFirstChildOfClass("BodyPosition"):Destroy()
						end
						Character.Humanoid.WalkSpeed = 0

						local HumanoidRootPart=Character:WaitForChild("HumanoidRootPart")
						local Boost = Instance.new("BodyPosition")
						Boost.Parent = HumanoidRootPart
						Boost.D = 1000
						Boost.P = 15000
						Boost.MaxForce = Vector3.new(1e6, 1e6, 1e6) -- full XYZ 

						local endpoint = spring.PrimaryPart:FindFirstChild("Endpoint", true)

						if endpoint and endpoint:IsA("Attachment") then
							Boost.Position = endpoint.WorldPosition
						else
							-- fallback
							Boost.Position = Vector3.new(0, HumanoidRootPart.Position.Y + spring:GetAttribute("Power"), 0)
						end
						game.ReplicatedStorage.astral.engine.assets.sfx.DashRing_Start:Play()
						game.Debris:AddItem(Boost,0.4)
						task.wait(0.4)
						Can=true
					end
				end
			end
			
			for _, o in CollectionService:GetTagged("Oneup") do
				if o.PrimaryPart and o.Parent then
					local springSize = o.PrimaryPart.Size
					local checkRadius = math.max(springSize.X, springSize.Y, springSize.Z) / 2 + 4 -- half size + some buffer

					local distance = (o.PrimaryPart.Position - hrp.Position).Magnitude

					if distance <= checkRadius then
						ReplicatedStorage.astral.engine.assets.sfx.Oneup_Start:Play()
						Utils:setProperty("sv_lives", Utils:getProperty("sv_lives") + 1)
						o:Destroy()
						TextDraw.Draw({
							Text = f.format2(Utils:getProperty("sv_lives")),
							LetterSize = UDim2.new(0, 27, 0, 27),
							Spacing = 0,
							Parent = game.Players.LocalPlayer.PlayerGui.ScreenGui.Hold.Left.Top.LifeIcon.Frame
						})
					end
				end
			end
			
			for _, enemy in CollectionService:GetTagged("Enemy") do
				if enemy and enemy.Parent then
					local obj = enemy.PrimaryPart
					if obj and obj.Parent then
						local enemySize = obj.Size
						local checkRadius = math.max(enemySize.X, enemySize.Y, enemySize.Z) / 2 + 2 -- half size + some buffer

						local distance = (obj.Position - hrp.Position).Magnitude
						if distance <= checkRadius then
							if Utils:getProperty("r_isBoosting") or jumpball or isTricking or humanoid.FloorMaterial == Enum.Material.Air  and not takingDamage then
								if not obj.Parent:GetAttribute("Alive") then
									continue
								end
								obj.Parent:SetAttribute("Alive", false)

								ReplicatedStorage.astral.engine.network.astral_server_response:FireServer(obj)

								local expl = Instance.new("Explosion")
								expl.DestroyJointRadiusPercent = 0
								expl.BlastPressure = 0
								expl.Position = obj.Position
								expl.Parent = workspace
								expl.ExplosionType = Enum.ExplosionType.NoCraters

								local r = ReplicatedStorage.astral.engine.assets.sfx.Explosion1_Start:Clone()
								r.PlayOnRemove = true
								r.Parent = game.SoundService
								r:Destroy()
								Death:dropOrbs()
								Utils:setProperty("sv_boost", math.min(Utils:getProperty("sv_boost") + Utils:get"BoostOnEnemyKill" or 0, 100))
								Utils:setProperty("sv_score", Utils:getProperty("sv_score") + 800)


								if jumpball and not isTricking then
									local vel = hrp.Velocity
									hrp.Velocity = Vector3.new(0, vel.Y, 0)
									local bodyPos = Instance.new("BodyPosition")
									bodyPos.MaxForce = Vector3.new(0, 1e5, 0) -- vertical force only
									bodyPos.P = 1e4
									bodyPos.Position = hrp.Position + Vector3.new(0, 30, 0)
									bodyPos.Parent = hrp
									task.delay(0.1, function()
										if bodyPos then bodyPos:Destroy() end
									end)
								end

								task.delay(1.5, function()
									if obj then obj:Destroy() end
								end)

								print("[astral @ astral_client_response] Received Hit - Signature:", game.HttpService:GenerateGUID(false))

							else
								if not obj.Parent:GetAttribute("Alive") then
									continue
								end
								--print("Alive:", obj.Parent:GetAttribute("Alive"), "jumpball:", jumpball, "isTricking:", isTricking, "canTakeDMG:", canTakeDMG)

								if jumpball then continue end
								if isTricking then continue end
								if not canTakeDMG then continue end

								local r = ReplicatedStorage.astral.engine.assets.voices.hurt:GetChildren()[math.random(1, #ReplicatedStorage.astral.engine.assets.voices.hurt:GetChildren())]:Clone()
								r.PlayOnRemove = true
								r.Parent = game.SoundService
								r:Destroy()

								if Utils:getProperty("sv_rings") > 0 then
									canTakeDMG = false
									game.ReplicatedStorage.astral.engine.assets.sfx.Ring_Drop:Play()
									takingDamage = true
									playAnimation(animations, "Damage")
									task.spawn(function()
										repeat task.wait()
											game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 0
										until not takingDamage
									end)

									local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
									if hrp then
										local bodyPos = Instance.new("BodyPosition")
										bodyPos.MaxForce = Vector3.new(1e5, 1e5, 1e5)
										bodyPos.P = 1e4

										local direction = (-hrp.CFrame.LookVector + Vector3.new(0, 0.3, 0)).Unit
										local knockbackDistance = 40
										bodyPos.Position = hrp.Position + direction * knockbackDistance
										bodyPos.Parent = hrp

										task.delay(0.15, function()
											bodyPos:Destroy()
											Death:dropRings()
										end)
									end

									task.delay(1, function()
										playAnimation(animations, "Standup")
										task.wait(0.46)
										takingDamage = false
									end)
									task.delay(2, function()
										canTakeDMG = true
									end)
								else
									canTakeDMG = false
									takingDamage = true
									playAnimation(animations, "Damage")
									task.spawn(function()
										repeat task.wait()
											game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 0
										until not takingDamage
									end)

									local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
									if hrp then
										local bodyPos = Instance.new("BodyPosition")
										bodyPos.MaxForce = Vector3.new(1e5, 1e5, 1e5)
										bodyPos.P = 1e4

										local direction = (-hrp.CFrame.LookVector + Vector3.new(0, 0.3, 0)).Unit
										local knockbackDistance = 40
										bodyPos.Position = hrp.Position + direction * knockbackDistance
										bodyPos.Parent = hrp

										task.delay(0.15, function()
											bodyPos:Destroy()
										end)
									end

									task.delay(1.39, function()
										Utils:setProperty("sv_lives", Utils:getProperty("sv_lives") - 1)
										TextDraw.Draw({
											Text = f.format2(Utils:getProperty("sv_lives")),
											LetterSize = UDim2.new(0, 27, 0, 27),
											Spacing = 0,
											Parent = game.Players.LocalPlayer.PlayerGui.ScreenGui.Hold.Left.Top.LifeIcon.Frame
										})
										Death:Die()
									end)

									task.delay(3, function()
										canTakeDMG = true
										takingDamage = false
									end)
								end

								workspace.Gravity = 170
							end
						end
					end
				end
			end
		end
	end)


	local cooldowns = {}
	local falldeath = false

	game.ReplicatedStorage.astral.engine.network.astral_net.OnClientEvent:Connect(function(a, pos, time, keys, obj)
		if rawequal(a, "Spring") then
			isTricking = true
			task.spawn(function()
				playAnimation(animations, "Spring")
				task.wait(0.4)
				isTricking=false
			end)
		elseif rawequal(a, "Ring") then
			local m = game.ReplicatedStorage.astral.engine.assets.sfx.Ring_Start:Clone()
			m.Parent = game.SoundService
			m.PlayOnRemove = true
			m:Destroy()
			Utils:setProperty("sv_boost", math.min(Utils:getProperty("sv_boost") + 5, 100))
		elseif rawequal(a, "Deathfall") then
			if falldeath then return end
			falldeath = true
			task.spawn(function()
				takingDamage = true
				local r = ReplicatedStorage.astral.engine.assets.voices.generic.Uahhhhhhh:Clone()
				r.PlayOnRemove = true
				r.Parent = game.SoundService
				r:Destroy()
				Death:lockCamera(pos)
				task.wait(1.2)
				Utils:setProperty("sv_lives", Utils:getProperty("sv_lives") - 1)
				Death:Die()
				Death:unlockCamera()
				task.delay(0.5, function()
					takingDamage = false
					falldeath=false
					workspace.Gravity =  170
				end)
			end)

		elseif rawequal(a, "Hit") then -- 0x1 astral_client_response
			return

		elseif rawequal(a, "Goalring") then
			if finish then return end
			game.ReplicatedStorage.astral.engine.assets.sfx.Goalring_Start:Play()
			finish = true
			takingDamage = true
			playAnimation(animations, "Idle")
			local TweenService = game.TweenService
			game.Players.LocalPlayer.PlayerGui.ScreenGui.Enabled = false

			local circle = game.Players.LocalPlayer.PlayerGui.GUI:WaitForChild("WhiteCircle"); 
			circle.Visible = true


			--// Tween
			local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut);


			local goal = { BackgroundTransparency = 0 };

			local tween = TweenService:Create(circle, tweenInfo, goal);
			tween:Play();
			task.spawn(function()
				task.wait(1)
				game.Players.LocalPlayer.Character.PrimaryPart.CFrame = pos
				game:GetService("CollectionService"):GetTagged("Goalring")[1].Transparency = 1
				for _,v in game:GetService("CollectionService"):GetTagged("Goalring")[1]:GetDescendants() do
					if v:IsA("Part") or v:IsA("MeshPart") then
						v.Transparency = 1
					end
					if v:IsA("PointLight") or v:IsA("Trail") then
						v.Enabled = false
					end
				end
				for _,v in game:GetService("CollectionService"):GetTagged("Goalring")[1].RainbowMesh:GetDescendants() do

					if v:IsA("Beam") then
						v.Enabled = false
					end
				end
			end)

			local tweenInfo2 = TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)

			local goal2 = {
				BackgroundTransparency = 1
			}
			local tween2 = TweenService:Create(circle, tweenInfo2, goal2)

			task.delay(2, function()
				tween2:Play()
			end)

			task.wait(0.2)
			local character = player.Character or player.CharacterAdded:Wait()
			local hrp = character:WaitForChild("HumanoidRootPart")

			local targetPart = game:GetService("CollectionService"):GetTagged("Goalring")[1].Look

			local camera = workspace.CurrentCamera
			camera.CameraType = Enum.CameraType.Scriptable;
			local cameraOffset = Vector3.new(0, 2, -20)
			local direction = (targetPart.Position - hrp.Position)
			direction = Vector3.new(direction.X, 0, direction.Z)
			hrp.CFrame = pos
			hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + direction)
			local p5 = hrp.Position
			tween.Completed:Wait()
			RunService.RenderStepped:Connect(function(deltaTime)
				character.Humanoid.WalkSpeed = 0
				hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + direction)

				local lookVector = hrp.CFrame.LookVector
				local rightVector = -hrp.CFrame.RightVector

				local cameraPos = hrp.Position
				- lookVector * -20  -- behind
					+ Vector3.new(0, 2, 0)     -- above
					+ rightVector * 15      -- to the right
				local lookAtPos = game:GetService("CollectionService"):GetTagged("Goalring")[1].goal_reference.Position

				camera.CFrame = CFrame.new(cameraPos, lookAtPos)
			end)
			tween2.Completed:Wait()
			playAnimation(animations, "ResultLook")
			--game:GetService("CollectionService"):GetTagged("Goalring")[1].Rank.SurfaceGui.Enabled = true
			local frame = game.Players.LocalPlayer.PlayerGui.FinishGUI.Hold
			local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
			local offscreenX = 2
			local result_title = frame.result_title
			result_title.Position = UDim2.new(-offscreenX, 0, result_title.Position.Y.Scale, 0)
			result_title.Visible = true
			local t = TweenService:Create(result_title, tweenInfo, {
				Position = UDim2.new(0, 0, result_title.Position.Y.Scale, 0)
			})
			t:Play()
			t.Completed:Wait()
			local s = game.ReplicatedStorage.astral.engine.assets.sfx.Goal.Bar:Clone()
			s.Parent = game.SoundService
			s.PlayOnRemove = true
			s:Destroy()
			for i = 1, 6 do
				local num = frame:FindFirstChild("result_num_" .. i)
				local tag = frame:FindFirstChild("result_num_" .. i .. "_tag")

				if num and tag then
					local numY = num.Position.Y.Scale
					local tagY = tag.Position.Y.Scale

					num.Position = UDim2.new(offscreenX, 0, numY, 0)
					tag.Position = UDim2.new(offscreenX, 0, tagY, 0)
					num.Visible = true
					tag.Visible = true
					local numTween = TweenService:Create(num, tweenInfo, {
						Position = UDim2.new(0.524, 0, numY, 0)
					})
					local tagTween = TweenService:Create(tag, tweenInfo, {
						Position = UDim2.new(0.524, 0, tagY, 0)
					})

					numTween:Play()
					tagTween:Play()

					numTween.Completed:Wait()
					if i == 2 then
						TextDraw.Draw({
							Text = f.format(Utils:getProperty("sv_rings")),
							LetterSize = UDim2.new(0,30, 0, 30),
							Spacing = 0,
							Parent = num.Value
						}) 
					elseif i == 1 then
						TextDraw.Draw({
							Text = Utils:getProperty("sv_time"),
							LetterSize = UDim2.new(0, 30, 0, 30),
							Spacing = 0,
							Parent = num.Value
						}) 
					elseif i == 3 then
						TextDraw.Draw({
							Text = tostring(Utils:getProperty("sv_score")),
							LetterSize = UDim2.new(0, 30, 0,30),
							Spacing = 0,
							Parent = num.Value
						}) 
					end
					local s = game.ReplicatedStorage.astral.engine.assets.sfx.Goal.Bar:Clone()
					s.Parent = game.SoundService
					s.PlayOnRemove = true
					s:Destroy()
					if i == 6 then
						local s = game.ReplicatedStorage.astral.engine.assets.sfx.Goal.Total:Clone()
						s.Parent = game.SoundService
						s.PlayOnRemove = true
						s:Destroy()
						TextDraw.Draw({
							Text = f.format3(tostring(Utils:getProperty("sv_score"))),
							LetterSize = UDim2.new(0, 30, 0,30),
							Spacing = 0,
							Parent = tag.Value
						}) 
						task.wait(1.5)
						local s = game.ReplicatedStorage.astral.engine.assets.sfx.Goal.Finalverdict:Clone()
						s.Parent = game.SoundService
						s.PlayOnRemove = true
						s:Destroy()
						frame.rank_txt.Visible = true
						local r = rankModule:GetStageRank(Utils:getProperty("sv_time"), Utils:getProperty("sv_rings"), Utils:getProperty("sv_score"))
						
						frame.rank.rank_img_S.Visible = false
						frame.rank["rank_img_"..r].Visible = true
						frame.rank.Visible = true
						local s = game.ReplicatedStorage.astral.engine.assets.sfx.Goal.S:Clone()
						s.Parent = game.SoundService
						s.PlayOnRemove = true
						s:Destroy()
						playAnimation(animations, "Idle")
						task.spawn(function()
							local imageLabel = frame.rank["rank_img_"..r]

							for _, brillianceLabel in imageLabel:GetChildren() do
								if brillianceLabel:IsA("ImageLabel") and string.find(brillianceLabel.Name:lower(), "brilliance") then
									for _, child in brillianceLabel:GetChildren() do
										if child:IsA("ImageLabel") then
											spawn(function()
												while true do
													local tweenOut = TweenService:Create(child, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1})
													tweenOut:Play()
													tweenOut.Completed:Wait()

													local tweenIn = TweenService:Create(child, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 0})
													tweenIn:Play()
													tweenIn.Completed:Wait()
												end
											end)
										end
									end
								end
							end
						end)
					end
				end
			end
		elseif rawequal(a, "QTE") then
			isTricking = true
			playAnimation(animations, "QTE")
			workspace.Gravity = 1
			jumpAnim = "Jumpball"
			local thisSession = currentSession

			-- Cleanup
			if currentQTEConnection then
				currentQTEConnection:Disconnect()
				currentQTEConnection = nil
			end

			qteFinished = false
			isQTE = true

			local gui = game.Players.LocalPlayer.PlayerGui.QTE
			local mainFrame = gui.mainFrame

			-- Clean up old buttons x)
			for _, v in mainFrame:GetChildren() do
				if v:IsA("Frame") and v.Name ~= "Template" then
					v:Destroy()
				end
			end

			gui.Enabled = true
			local RunService = game:GetService("RunService")
			local timebar = gui:WaitForChild("Timebar")
			local fill = timebar.Frame:WaitForChild("Fill")

			local QTE_TOTAL_TIME = time
			local startTime = tick()

			local updateConnection
			updateConnection = RunService.Heartbeat:Connect(function()
				if qteFinished or not isQTE then
					fill.Size = UDim2.new(0, 0, 1, 0)  -- empty the bar when done
					updateConnection:Disconnect()
					return
				end

				local elapsedTime = tick() - startTime
				local timeLeft = math.clamp(QTE_TOTAL_TIME - elapsedTime, 0, QTE_TOTAL_TIME)
				local progress = timeLeft / QTE_TOTAL_TIME

				fill.Size = UDim2.new(progress, 1, 1, 0)


			end)

			local player = game.Players.LocalPlayer
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			task.spawn(function()
				repeat task.wait() 
					if humanoid then
						humanoid.WalkSpeed = 0
					end
				until not isQTE
			end)

			local requiredKeys = Utils:getRandomKeys(keys)
			for _, key in requiredKeys do
				local template = mainFrame.Template:Clone()
				template.Name = key.Name
				template.UIGradient.Color = Utils:randomColorSequence()
				template.TextLabel.Text = key.Name
				template.Visible = true
				template.Parent = mainFrame
				--print("-", key.Name)
			end

			local currentIndex = 1

			local function fail()
				if updateConnection then
					updateConnection:Disconnect()
					updateConnection = nil
				end
				currentSession = {} -- invalidate

				if qteFinished then return end
				qteFinished = true
				task.spawn(function()
					local TweenService = game:GetService("TweenService")

					local rank = gui.Parent.ScreenGui.Rank
					rank.ImageRectOffset = Vector2.new(0,145)
					local parent = rank.Parent
					rank.Visible = true

					-- Settinkz
					local startX = 1.5
					local centerX = 0.5
					local endX = -0.5
					local tweenTimeIn = 0.3
					local tweenTimeOut = 0.5
					local ghostCount = 5
					local ghostDelay = 0.04

					local ghosts = {}
					for i = 1, ghostCount do
						local ghost = rank:Clone()
						ghost.Name = "Ghost"
						ghost.Parent = parent
						ghost.ZIndex = rank.ZIndex - 1
						ghost.ImageTransparency = 1 
						ghosts[i] = ghost
					end

					local function resetGhosts()
						for _, ghost in ipairs(ghosts) do
							ghost.ImageTransparency = 1
							ghost.Position = rank.Position
							ghost.Visible = false
							ghost:Destroy()
						end
					end

					local function playGhostEffect()
						for i, ghost in ipairs(ghosts) do
							ghost.Position = rank.Position
							ghost.ImageTransparency = rank.ImageTransparency + 0.4
							ghost.Visible = true

							local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
							local goal = {
								ImageTransparency = 1,
								Position = UDim2.new(
									rank.Position.X.Scale - 0.05 * i,
									rank.Position.X.Offset,
									rank.Position.Y.Scale,
									rank.Position.Y.Offset
								),
							}

							local tween = TweenService:Create(ghost, tweenInfo, goal)
							tween:Play()

							tween.Completed:Connect(function()
								ghost.Visible = false
							end)

							task.wait(ghostDelay)
						end
					end

					-- Main
					rank.Position = UDim2.new(startX, 0, rank.Position.Y.Scale, rank.Position.Y.Offset)
					rank.ImageTransparency = 0
					rank.Visible = true
					resetGhosts()

					local tweenIn = TweenService:Create(rank, TweenInfo.new(tweenTimeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(centerX, 0, rank.Position.Y.Scale, rank.Position.Y.Offset)})
					tweenIn:Play()
					tweenIn.Completed:Wait()

					playGhostEffect()

					task.wait(0.1)

					local tweenOut = TweenService:Create(rank, TweenInfo.new(tweenTimeOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(endX, 0, rank.Position.Y.Scale, rank.Position.Y.Offset)})
					tweenOut:Play()
					tweenOut.Completed:Wait()

					rank.Visible = false
					resetGhosts()

				end)
				workspace.Gravity = 170
				--print("Fail!")
				isQTE = false
				isTricking = false

				local m = game.ReplicatedStorage.astral.engine.assets.sfx.Trick_Fail:Clone()
				m.Parent = game.SoundService
				m.PlayOnRemove = true
				m:Destroy()

				gui.Enabled = false

				if currentQTEConnection then
					currentQTEConnection:Disconnect()
					currentQTEConnection = nil
				end

				-- Clean up UI
				for _, v in mainFrame:GetChildren() do
					if v:IsA("Frame") and v.Name ~= "Template" then
						v:Destroy()
					end
				end
			end

			local function pass()
				currentSession = {} -- invalidate old sessions to prevent old delays firing again
				isTricking = false
				if updateConnection then
					updateConnection:Disconnect()
					updateConnection = nil
				end
				if qteFinished then return end
				task.spawn(function()
					local TweenService = game:GetService("TweenService")

					local rank = gui.Parent.ScreenGui.Rank
					rank.ImageRectOffset = Vector2.new(0,0)
					local parent = rank.Parent
					rank.Visible = true

					-- Settings
					local startX = 1.5
					local centerX = 0.5
					local endX = -0.5
					local tweenTimeIn = 0.3
					local tweenTimeOut = 0.5
					local ghostCount = 5
					local ghostDelay = 0.04

					-- Create and cache ghost pool once
					local ghosts = {}
					for i = 1, ghostCount do
						local ghost = rank:Clone()
						ghost.Name = "Ghost"
						ghost.Parent = parent
						ghost.ZIndex = rank.ZIndex - 1
						ghost.ImageTransparency = 1 -- Start invisible
						ghosts[i] = ghost
					end

					local function resetGhosts()
						for _, ghost in ipairs(ghosts) do
							ghost.ImageTransparency = 1
							ghost.Position = rank.Position
							ghost.Visible = false
							ghost:Destroy()
						end
					end

					local function playGhostEffect()
						for i, ghost in ipairs(ghosts) do
							ghost.Position = rank.Position
							ghost.ImageTransparency = rank.ImageTransparency + 0.4
							ghost.Visible = true

							local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
							local goal = {
								ImageTransparency = 1,
								Position = UDim2.new(
									rank.Position.X.Scale - 0.05 * i,
									rank.Position.X.Offset,
									rank.Position.Y.Scale,
									rank.Position.Y.Offset
								),
							}

							local tween = TweenService:Create(ghost, tweenInfo, goal)
							tween:Play()

							-- Hide ghost when tween finishes instead of destroying
							tween.Completed:Connect(function()
								ghost.Visible = false
							end)

							task.wait(ghostDelay)
						end
					end

					-- Main animation
					rank.Position = UDim2.new(startX, 0, rank.Position.Y.Scale, rank.Position.Y.Offset)
					rank.ImageTransparency = 0
					rank.Visible = true
					resetGhosts()

					local tweenIn = TweenService:Create(rank, TweenInfo.new(tweenTimeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(centerX, 0, rank.Position.Y.Scale, rank.Position.Y.Offset)})
					tweenIn:Play()
					tweenIn.Completed:Wait()

					playGhostEffect()

					task.wait(0.1)

					local tweenOut = TweenService:Create(rank, TweenInfo.new(tweenTimeOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(endX, 0, rank.Position.Y.Scale, rank.Position.Y.Offset)})
					tweenOut:Play()
					tweenOut.Completed:Wait()

					rank.Visible = false
					resetGhosts()

				end)
				isTricking = true
				playAnimation(animations, "TrickA")
				local m = game.ReplicatedStorage.astral.engine.assets.voices.generic.FeelingGood:Clone()
				m.Parent = game.SoundService
				m.PlayOnRemove = true
				m:Destroy()
				task.delay(.5, function()
					qteFinished = true
					isTricking = false
					isQTE = false
				end)
				workspace.Gravity = 170

				local m = game.ReplicatedStorage.astral.engine.assets.sfx.Trick_Success:Clone()
				m.Parent = game.SoundService
				m.PlayOnRemove = true
				m:Destroy()

				gui.Enabled = false

				if currentQTEConnection then
					currentQTEConnection:Disconnect()
					currentQTEConnection = nil
				end


				-- Clean up UI
				for _, v in mainFrame:GetChildren() do
					if v:IsA("Frame") and v.Name ~= "Template" then
						v:Destroy()
					end
				end

				-- Boost
				local Boost = Instance.new("BodyPosition")
				Boost.Parent = player.Character.PrimaryPart
				Boost.D = 1000
				Boost.P = 15000
				Boost.MaxForce = Vector3.new(1e6, 1e6, 1e6)
				Boost.Position = pos
				game.Debris:AddItem(Boost, 0.6)
			end

			currentQTEConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed or not isQTE or qteFinished then return end
				
				if not (input.UserInputType == Enum.UserInputType.Keyboard) then return end

				local expectedKey = requiredKeys[currentIndex]
				if input.KeyCode == expectedKey then
					mainFrame[expectedKey.Name]:Destroy()

					local m = game.ReplicatedStorage.astral.engine.assets.sfx.Trick_ButtonPress:Clone()
					m.Parent = game.SoundService
					m.PlayOnRemove = true
					m:Destroy()

					currentIndex += 1
					if currentIndex > #requiredKeys then
						pass()
					end
				else
					fail()
				end
			end)

			task.delay(time, function()
				if isQTE and not qteFinished and thisSession == currentSession then
					fail()
				end
			end)
		end


	end)


	local function onCharacterAdded(character)
		humanoid = character:WaitForChild("Humanoid")
		local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
		animations = loadAnimations(animator)

		task.spawn(function()
			local hrp = character:WaitForChild("HumanoidRootPart")
			local leftFoot = character:WaitForChild("chr_Sonic_HD.005")  -- Change if needed
			local rightFoot = character:WaitForChild("chr_Sonic_HD.002") -- Change if needed
			local humanoid = character:WaitForChild("Humanoid")

			bodyVelocity = Instance.new("BodyVelocity", hrp)
			bodyGyro = Instance.new("BodyGyro", hrp)
			bodyVelocity.MaxForce = Vector3.new(0, 0, 0)
			bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
			bodyGyro.D = 50

			grindSound = game.ReplicatedStorage.astral.engine.assets.sfx.Rail_Loop:Clone()

			grindSound.Parent = hrp

			speedMultiplier = 1

			humanoid.Changed:Connect(function(property)
				if property == "Jump" and humanoid.Jump and rail ~= nil then
					humanoid.Jump = false
				end
			end)

			character.ChildAdded:Connect(function(child)
				if child:IsA("BasePart") then
					bindPartTouch(child)
				end
			end)

			for _, child in character:GetChildren() do
				if child:IsA("BasePart") then
					bindPartTouch(child)
				end
			end
		end)

		-- Jumping event triggers jump anim and sets jump power
		humanoid.Jumping:Connect(function()
			if isTricking then return end
			if finish then return end
			
			local now = tick()
			if now - lastJumpTime < jumpCooldown then
				return
			end
			lastJumpTime = now
			local r = ReplicatedStorage.astral.engine.assets.voices.jump:GetChildren()[math.random(1, #ReplicatedStorage.astral.engine.assets.voices.jump:GetChildren())]:Clone()
			r.PlayOnRemove = true
			r.Parent = game.SoundService
			r:Destroy()
			if lastPressDuration and lastPressDuration >= jumpThreshold then
				local list = {"chr_Sonic_HD.005", "chr_Sonic_HD.006", "chr_Sonic_HD.007", "chr_Sonic_HD.008"}
				for _,v in list do if not rawequal(Utils:get("Jumpball"), "Jumpball2") and not rawequal(Utils:get("Jumpball"), "T") then game.Players.LocalPlayer.Character[v].Transparency = 1 end end
				jumpAnim = "Jumpball"
				humanoid.JumpPower = jumpballPower
				jumpball = ReplicatedStorage.astral.engine.assets.misc[Utils:get("Jumpball")]:Clone()
				jumpball.Parent = humanoid.Parent
				task.spawn(function()
					local connection
					connection = RunService.Heartbeat:Connect(function(dt)
						if jumpball and jumpball.PrimaryPart and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
							rot += 5 * dt * 240  -- speed scaling ritual raaaaaa
							if rot >= 90 then
								rot = -90
							end

							jumpball:SetPrimaryPartCFrame(
								player.Character.HumanoidRootPart.CFrame 
									* CFrame.Angles(-math.rad(rot), 0, 0)
									+ Vector3.new(0, 0.76, 0)
							)
						else
							-- Stop updating x)
							if connection then
								connection:Disconnect()
							end
						end
					end)
				end)
			else
				jumpAnim = "Jump"
				humanoid.JumpPower = shortJumpPower
			end


			playAnimation(animations, jumpAnim)
			lastPressDuration = nil
		end)

		humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
			local currentMaterial = humanoid.FloorMaterial
			if lastFloorMaterial == Enum.Material.Air and currentMaterial ~= Enum.Material.Air then
				-- Uncomment to play landing animation
				-- landedRecently = true
				-- playAnimation(animations, "Land")
				-- task.delay(0.4, function() landedRecently = false end)
				if jumpball then jumpball:Destroy() jumpball = nil end
			end
			lastFloorMaterial = currentMaterial
		end)
		local originalProperties = {} -- table to store original properties per part
		local currentPart = nil
		local modifying = false
		local rootPart = game.Players.LocalPlayer.Character.PrimaryPart


		local function applyCustomPhysics(part)
			if not part or not part:IsA("BasePart") then return end
			if not originalProperties[part] then
				local phys = part.CustomPhysicalProperties
				if phys then
					originalProperties[part] = {
						Density = phys.Density,
						Friction = phys.Friction,
						Elasticity = phys.Elasticity,
						FrictionWeight = phys.FrictionWeight,
						ElasticityWeight = phys.ElasticityWeight,
					}
				else
					originalProperties[part] = {
						Density = 0.7,
						Friction = part.Friction,
						Elasticity = 0,
						FrictionWeight = 1,
						ElasticityWeight = 0,
					}
				end
			end
			local orig = originalProperties[part]
			part.CustomPhysicalProperties = PhysicalProperties.new(
				orig.Density,
				0,             -- friction
				orig.Elasticity,
				25,            -- frictionWeight
				orig.ElasticityWeight
			)
		end

		local function resetCustomPhysics(part)
			if not part or not part:IsA("BasePart") then return end
			local orig = originalProperties[part]
			if orig then
				part.CustomPhysicalProperties = PhysicalProperties.new(
					orig.Density,
					orig.Friction,
					orig.Elasticity,
					orig.FrictionWeight,
					orig.ElasticityWeight
				)
				originalProperties[part] = nil
			end
		end

		task.spawn(function()
			local r2 = ReplicatedStorage.astral.engine.assets.sfx.Drift_Loop:Clone()
			r2.Parent = game.SoundService

			local function onInputBegan(input, gameProcessed)
				if gameProcessed then return end
				if input.KeyCode == Enum.KeyCode.R and not modifying then
					currentPart = Utils:findPartBelow()
					if currentPart then
						applyCustomPhysics(currentPart)
						local r = ReplicatedStorage.astral.engine.assets.voices.drift:GetChildren()[math.random(1, #ReplicatedStorage.astral.engine.assets.voices.drift:GetChildren())]:Clone()
						r.PlayOnRemove = true
						r.Parent = game.SoundService
						r:Destroy()
						modifying = true
						r2:Play()
					end
				end
			end

			local function onInputEnded(input, gameProcessed)
				if gameProcessed then return end
				if input.KeyCode == Enum.KeyCode.R and modifying then
					r2:Stop()
					if game.Players.LocalPlayer.Character["ParticlePart"]:FindFirstChild("Drift") then
						game.Players.LocalPlayer.Character["ParticlePart"]:FindFirstChild("Drift"):Destroy()
					end
					if currentPart then
						resetCustomPhysics(currentPart)
						currentPart = nil
					end
					modifying = false
				end
			end


			UserInputService.InputBegan:Connect(onInputBegan)
			UserInputService.InputEnded:Connect(onInputEnded)
		end)
		local p0 = {}
		local trailc = false

		RunService.Heartbeat:Connect(function(dt)
			if not humanoid or not humanoid.Parent then return end
			if AirBoosted then return end
			if takingDamage then return end
			if isTricking then return end
			if isRail then return end
			local rootPart = humanoid.Parent:FindFirstChild("HumanoidRootPart")
			if not rootPart then return end

			local yVelocity = rootPart.Velocity.Y
			local moveDir = humanoid.MoveDirection.Magnitude
			local speed = humanoid.WalkSpeed
			local isAirborne = humanoid.FloorMaterial == Enum.Material.Air

			if game.UserInputService:IsKeyDown(Enum.KeyCode.R) then
				if modifying and game.Players.LocalPlayer.Character["ParticlePart"]:FindFirstChild("Drift") then
					game.Players.LocalPlayer.Character["ParticlePart"]:FindFirstChild("Drift").Attachment.WorldCFrame = game.Players.LocalPlayer.Character["chr_Sonic_HD.007"].CFrame - Vector3.new(0, 2, 0)
				end
				if modifying and not isAirborne then
					local newPart = Utils:findPartBelow()
					if not game.Players.LocalPlayer.Character["ParticlePart"]:FindFirstChild("Drift") then
						local d = game.ReplicatedStorage.astral.engine.assets.particles.Drift:Clone()
						d.Parent = game.Players.LocalPlayer.Character["ParticlePart"]
					end
					if newPart ~= currentPart then
						if currentPart then
							resetCustomPhysics(currentPart)
						end
						currentPart = newPart
						if currentPart then
							applyCustomPhysics(currentPart)
						end
					end
				end
				if not trailc then
					Utils:createTrailTunnel()
					trailc = true
					task.delay(1, function()
						trailc = false
					end)
				end
				local part = Utils:findPartBelow()

				playAnimation(animations, "Jumpball")
				local dashStrength = 40
				rootPart.Velocity = rootPart.Velocity + rootPart.CFrame.LookVector * dashStrength * dt
				Utils:setProperty("r_footsteps", false)

				return
			end

			if isAirborne then
				if yVelocity > 0.5 and not AirBoosted then
					playAnimation(animations, jumpAnim)  -- ascending jump or jumpball
				elseif yVelocity < -80 or (yVelocity < -1 and not jumpball) then
					playAnimation(animations, "Fall")    -- fast descending
					if jumpball then jumpball:Destroy() jumpball = nil end
				else
					playAnimation(animations, jumpAnim)  -- neutral velocity in air
				end
			else
				if moveDir < IDLE_THRESHOLD then
					playAnimation(animations, "Idle")
					Utils:setProperty("r_footsteps", false)

				elseif speed < WALK_THRESHOLD then
					playAnimation(animations, "Walk")
				elseif speed >= RUN_THRESHOLD and not (speed >= JET_THRESHOLD) then
					playAnimation(animations, "Run")
					Utils:setProperty("r_footsteps", true)
				elseif speed >= JET_THRESHOLD and not (speed >= DASHING_THRESHOLD) then
					playAnimation(animations, "Jet")
					Utils:setProperty("r_footsteps", true)
				elseif speed >= DASHING_THRESHOLD and not (speed >= BOOSTIN_THRESHOLD) then
					playAnimation(animations, "Dash")
					Utils:setProperty("r_footsteps", true)
				elseif speed >= BOOSTIN_THRESHOLD then
					playAnimation(animations, "Boost")
					Utils:setProperty("r_footsteps", true)
				end
			end
		end)

		-- Reset jump power when landed or running
		humanoid.StateChanged:Connect(function(oldState, newState)
			if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
				if jumpball then jumpball:Destroy() end
				humanoid.JumpPower = shortJumpPower
			end
		end)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	local lastTick = tick()
	RunService:BindToRenderStep("RailGrinding", Enum.RenderPriority.Character.Value, function()
		local deltaTime = (tick() - lastTick) * 60
		lastTick = tick()

		if rail ~= nil and player.Character then
			local character = player.Character
			local hrp = character.HumanoidRootPart

			local targetPos = (rail.CFrame * CFrame.new(pathXOffset, 2.5, -rail.Size.Z / 2 - 2)).Position
			local distToTarget = (hrp.Position - targetPos).Magnitude
			local distToRail = (hrp.Position - rail.Position).Magnitude

			if distToTarget < 4 or distToRail > rail.Size.Z + 2 or (onPath and character.Humanoid.MoveDirection.Magnitude < 0.5) then
				pathTime = tick()
				lastPath = rail
				rail = nil
				onPath = false
				bodyVelocity.MaxForce = Vector3.new(0, 0, 0)

				local oldGyroCFrame = bodyGyro.CFrame
				task.delay(0.025, function()
					if bodyGyro.CFrame == oldGyroCFrame then
						isRail = false
						bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
						character.Humanoid.PlatformStand = false
						grindSound:Stop()
					end
				end)
			else
				if onPath then
					bodyGyro.CFrame = rail.CFrame
					local velocityDir = CFrame.new(hrp.Position, rail.CFrame * CFrame.new(pathXOffset, 3, -rail.Size.Z / 2 - 2).Position).LookVector
					local velocity = velocityDir * pathSpeed
					hrp.Velocity = velocity
					bodyVelocity.Velocity = velocity

					if not grindSound.IsPlaying then
						grindSound:Play()
					end
				else
					bodyGyro.CFrame = rail.CFrame
					local velocityDir = CFrame.new(hrp.Position, rail.CFrame * CFrame.new(0, 3, -rail.Size.Z / 2 - 2).Position).LookVector
					local velocity = velocityDir * (80 * speedMultiplier)
					hrp.Velocity = velocity
					bodyVelocity.Velocity = velocity

					if velocity.Y < 0 and crouching then
						if speedMultiplier < 2 then
							speedMultiplier = math.min(speedMultiplier + (1 / 60) * deltaTime, 2)
						end
					else
						if speedMultiplier > 1 then
							speedMultiplier = math.max(speedMultiplier - (1 / 60) * deltaTime, 1)
						end
					end

					if speedMultiplier > 2 then
						speedMultiplier = math.min(speedMultiplier - (speedMultiplier / 32), 2)
					end
				end
			end
		end
	end)
end

--// extension
local humanoid = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
humanoid.StateChanged:Connect(function(old, new)
	if new == Enum.HumanoidStateType.FallingDown then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)

return module
