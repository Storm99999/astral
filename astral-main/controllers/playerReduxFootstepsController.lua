--[[
                        /$$                        /$$
                       | $$                       | $$
   /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
  |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
   /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
  /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
 |  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
  \_______/|_______/    \___/  |__/      \_______/|__/

	@name: playerReduxFootstepsController.lua
	@version: 1.0.0
	@author: Celeste Softworks © 2025
	@date: 05/08/25
	@description: Astral Footstep Controller
	
--]]

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local Utils = require(script.Parent.Parent.include["astralutil.lua"])
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local footstepSounds = {
	[Enum.Material.Grass] = {Left = "rbxassetid://122555270783573", Right = "rbxassetid://122555270783573"},
	[Enum.Material.Concrete] = {Left = "rbxassetid://74027612242679", Right = "rbxassetid://74027612242679"},
	[Enum.Material.Metal] = {Left = "rbxassetid://117040210492535", Right = "rbxassetid://117040210492536"},
}

local landSounds = {
	[Enum.Material.Grass] = "rbxassetid://119145235360127",
	[Enum.Material.Concrete] = "rbxassetid://83727368008988",
	[Enum.Material.Metal] = "rbxassetid://78816570880889"
}

local defaultFootstep = {Left = "rbxasset://sounds/action_footsteps_plastic.mp3", Right = "rbxasset://sounds/action_footsteps_plastic.mp3"}
local defaultLandSound = "rbxasset://sounds/action_jump_land.mp3"

local module = {}

local function playFootstep(material, foot)
	local sounds = footstepSounds[material] or defaultFootstep
	local soundId = sounds[foot] or sounds.Left
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 1
	sound.Parent = rootPart
	sound:Play()
	game.Debris:AddItem(sound, 2)
end

local function playLand(material)
	local soundId = landSounds[material] or defaultLandSound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 1
	sound.Parent = rootPart
	sound:Play()
	game.Debris:AddItem(sound, 2)
end

function module.Start()
	humanoid.Parent.PrimaryPart:WaitForChild"Running":Destroy()

	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed then
			local material = humanoid.FloorMaterial
			playLand(material)
			
		end
	end)
	
	while task.wait() do
		if not game.Players.LocalPlayer.Character:FindFirstChild(Utils:get("Jumpball")) then
			local list = {"chr_Sonic_HD.005", "chr_Sonic_HD.006", "chr_Sonic_HD.007", "chr_Sonic_HD.008"}
			for _,v in list do game.Players.LocalPlayer.Character[v].Transparency = 0 end
		end
	end
end

return module
