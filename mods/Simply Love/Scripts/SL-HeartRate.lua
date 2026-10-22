-- ----------------------------------------------------------------
-- Gameplay event feed for the HeartRateMonitor app.
--
-- Each event is written as its own small JSON file to
--    /Save/HeartRate/events/<stamp>-<seq>.json
-- (on Windows: %APPDATA%\StepMania 5.1\Save\HeartRate\events\)
-- The app polls that folder, ingests each file, and deletes it.
-- RageFile can't append, which is why it's one file per event.
--
-- Nothing is written unless /Save/HeartRate/ already exists, so players
-- without the app don't collect a pile of files nobody reads.  Create that
-- folder (or let the app do it) to turn the feed on.
--
-- Event schema (v1):
--    {v, source, seq, kind="begin"|"end"|"mark", type, id, parent,
--     label, time, music_seconds, data}
-- All times in seconds are real time (chart time / music rate).
--
-- The gameplay side lives in ./BGAnimations/ScreenGameplay overlay/HeartRate.lua
-- ----------------------------------------------------------------

HeartRate = {
	dir = "/Save/HeartRate/events/",
	-- taken once when the theme's scripts load; filenames sort by it so a
	-- backlog left from a previous run never misorders against this one
	stamp = ("%04d%02d%02d-%02d%02d%02d"):format(Year(), MonthOfYear()+1, DayOfMonth(), Hour(), Minute(), Second()),
	seq = 0,
	-- the song span that is currently open, if any (see the overlay)
	open = nil,
}

HeartRate.Now = function()
	return ("%04d-%02d-%02dT%02d:%02d:%02d"):format(Year(), MonthOfYear()+1, DayOfMonth(), Hour(), Minute(), Second())
end

-- the ids of begin/end pairs are "<stamp>-<seq of the begin>"
HeartRate.NextId = function()
	return ("%s-%06d"):format(HeartRate.stamp, HeartRate.seq + 1)
end

HeartRate.Emit = function(event)
	if not FILEMAN:DoesFileExist("/Save/HeartRate/") then return end

	HeartRate.seq = HeartRate.seq + 1
	event.v = 1
	event.source = "simply-love"
	event.seq = HeartRate.seq
	event.time = HeartRate.Now()

	local ok, str = pcall(json.encode, event)
	if not ok then
		Warn("HeartRate: couldn't encode event: " .. tostring(str))
		return
	end

	local path = ("%s%s-%06d.json"):format(HeartRate.dir, HeartRate.stamp, HeartRate.seq)
	local f = RageFileUtil.CreateRageFile()
	if f:Open(path, 2) then
		f:Write(str)
		f:Close()
	else
		Warn("HeartRate: couldn't write " .. path)
	end
	f:destroy()
end
