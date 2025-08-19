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





local module = {};

local RunService = game:GetService("RunService")



function module.Start()
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	local bar = game.Players.LocalPlayer.PlayerGui.ScreenGui.Hold.Left.Bottom.Gauge
	local fill = bar.Gauge.GaugeFill

	local originalWidthScale = fill.Size.X.Scale -- use Scale instead of Offset g
	local maxHealth = 100

	local tweenInfo = TweenInfo.new(
		0.25, -- x) adjust
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	task.spawn(function()
		while true do
			task.wait()
			if game.StarterGui:GetAttribute("r_isBoosting") then
				game.StarterGui:SetAttribute("sv_boost", game.StarterGui:GetAttribute("sv_boost") - .045)
			end
		end
	end)

	local function updateHealthBar()
		local healthPercent = math.clamp(game.StarterGui:GetAttribute("sv_boost") / maxHealth, 0, 1)
		local newScale = originalWidthScale * healthPercent

		-- Tween the size smoothly using scale in X, keep Y.Scale unchanged
		local tween = TweenService:Create(
			fill,
			tweenInfo,
			{ Size = UDim2.new(newScale, 0, fill.Size.Y.Scale, 0) }
		)
		tween:Play()
	end

	-- Update when health changes
	while task.wait() do
		updateHealthBar()
		TextDraw.Draw({
			Text = f.format3(Utils:getProperty("sv_score")),
			LetterSize = UDim2.new(0, 19, 0, 19),
			Spacing = 0,
			Parent = game.Players.LocalPlayer.PlayerGui.ScreenGui.Hold.Left.Top.ScoreBar.ScoreValue,
			Stroke = true
		})
	end

end


return module;
