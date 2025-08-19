return {
	["Windmill Isle"] = {
		Name = "Windmill Isle",
		Weights = { Time = 1, Rings = 0, Score = 0 },
		TimeMax = 680,  -- slower than this = worst score for time
		TimeBest = 60,  -- faster than this = best score for time
		RingMax = 950,  -- max rings possible
		ScoreMax = 50000, -- max score possible

		RankThresholds = {
			S = 75,
			A = 65,
			B = 50,
			C = 40,
			D = 30,
			E = 0
		}
	}

}
