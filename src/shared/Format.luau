-- Format.luau — tiny shared formatting helpers, used by the HUD and the
-- win screen so a time reads the same everywhere it is shown.

local Format = {}

-- 83.42 -> "01:23.4"
function Format.Time(seconds: number): string
	seconds = math.max(0, seconds)
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%02d:%04.1f", minutes, rest)
end

-- The rank a finished run earns, from its time and star count. A run that
-- started past stage 1 is labelled a partial climb instead.
function Format.Rank(
	seconds: number,
	stars: number,
	startStage: number,
	parTimes: { number },
	totalStars: number
): string
	if startStage > 1 then
		return "PARTIAL CLIMB"
	elseif seconds <= parTimes[1] and stars >= totalStars then
		return "STARFALL LEGEND"
	elseif seconds <= parTimes[2] then
		return "CROWN ACE"
	elseif seconds <= parTimes[3] then
		return "CROWN CLIMBER"
	else
		return "CROWN FINISHER"
	end
end

return Format
