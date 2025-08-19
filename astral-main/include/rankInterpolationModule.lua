--[[
                        /$$                        /$$
                       | $$                       | $$
   /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
  |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
   /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
  /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
 |  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
  \_______/|_______/    \___/  |__/      \_______/|__/

	@name: rankInterpolationModule.lua
	@version: 1.0.0
	@author: Celeste Softworks © 2025
	@date: 05/08/25
	@description: Calculates player rank based on time, rings and score
	
--]]

local RankingModule = {}

function mapRange(value, min, max, reverse)
	local percent = math.clamp((value - min) / (max - min), 0, 1)
	if reverse then percent = 1 - percent end
	return percent * 100
end

local function timeStringToSeconds(timeStr)
	local minutes, seconds, milliseconds = timeStr:match("(%d+):(%d+):(%d+)")
	minutes = tonumber(minutes) or 0
	seconds = tonumber(seconds) or 0
	milliseconds = tonumber(milliseconds) or 0

	return minutes * 60 + seconds + (milliseconds / 100)
end

function RankingModule:GetStageRank(time, rings, score)
	local stage = require(script.Parent.Parent.include["stageData.lua"])[script.Parent.Parent["@astral"].StageName.Value]
	if not stage then
		warn("No ranking data for stage: " .. tostring(stage.Name))
		return "N/A"
	end

	local timeScore = mapRange(timeStringToSeconds(time), stage.TimeBest, stage.TimeMax, true)
	local ringScore = mapRange(rings, 0, stage.RingMax, false)
	local scoreScore = mapRange(score, 0, stage.ScoreMax, false)
	
	print(timeScore, ringScore, scoreScore)

	local total = (timeScore * stage.Weights.Time)
		+ (ringScore * stage.Weights.Rings)
		+ (scoreScore * stage.Weights.Score)

	for rank, threshold in stage.RankThresholds do
		if total >= threshold then
			return rank
		end
	end

	return "E" -- fall back
end

return RankingModule
