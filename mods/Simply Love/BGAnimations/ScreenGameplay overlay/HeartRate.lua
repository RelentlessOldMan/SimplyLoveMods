-- Sends song/course begin and end events (plus pause/resume marks) to the
-- HeartRateMonitor app.  The file writing and schema notes are in
-- ./Scripts/SL-HeartRate.lua
--
-- Song spans begin when the music reaches 0 (not when the screen loads, which
-- includes the lead-in) and end when the screen goes off, or, in course mode,
-- when the next song in the course comes up.  All times are real seconds
-- (chart time / music rate).

local players = GAMESTATE:GetHumanPlayers()
local course_mode = GAMESTATE:IsCourseMode()

local course_id = nil
local prepared = nil     -- begin event for the song at prepared.idx, built ahead of time
local last_music = -math.huge
local finished = false

local Round = function(x, places)
	local m = 10^(places or 3)
	return math.floor(x*m + 0.5) / m
end

local Rate = function()
	return GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate()
end

local SongIndex = function()
	return course_mode and GAMESTATE:GetCourseSongIndex() or 0
end

local SongAndSteps = function(player, idx)
	if course_mode then
		local entry = GAMESTATE:GetCurrentTrail(player):GetTrailEntries()[idx+1]
		if not entry then return nil end
		return entry:GetSong(), entry:GetSteps()
	end
	return GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps(player)
end

-- Stream/break segments in real seconds from music 0, using the theme's own
-- chart parser (16th-note stream, same as the default measure counter).
-- Only ever called for the song that is about to be played, so the theme's
-- per-player chart cache keeps holding the current chart.
local Segments = function(steps, pn, rate)
	local ok = pcall(ParseChartInfo, steps, pn)
	local npm = SL[pn].Streams.NotesPerMeasure
	if not ok or not npm or #npm == 0 then return {}, nil end

	local timing = steps:GetTimingData()
	local segments = {}
	for seq in ivalues(GetStreamSequences(npm, 16)) do
		segments[#segments+1] = {
			kind = seq.isBreak and "break" or "stream",
			start_s = Round(timing:GetElapsedTimeFromBeat(seq.streamStart * 4) / rate),
			end_s = Round(timing:GetElapsedTimeFromBeat(seq.streamEnd * 4) / rate),
			measures = seq.streamEnd - seq.streamStart,
		}
	end
	return segments, SL[pn].Streams.Hash
end

-- Segments written into the simfile by the chart generator, as a comment line
-- before the first #NOTES (StepMania strips // comments, so the engine never
-- sees it):
--    //HRM-SEGMENTS {"v":1,"unit":"beat","segments":[{"kind":"loop","start":0,"end":364,"label":"Loop 1"}, ...]}
-- unit is "beat" or "second" (song seconds).  Returns nil if there's no
-- usable line, so the caller falls back to stream detection.
local FileSegments = function(steps, rate)
	local filename = steps:GetFilename()
	if not filename or filename == "" then return nil end

	local f = RageFileUtil.CreateRageFile()
	local contents
	if f:Open(filename, 1) then contents = f:Read() end
	f:destroy()
	if not contents then return nil end

	local header = contents:sub(1, (contents:find("#NOTES", 1, true) or #contents + 1) - 1)
	local line = header:match("//HRM%-SEGMENTS[ \t]*([^\r\n]+)")
	if not line then return nil end

	local ok, meta = pcall(json.decode, line)
	if not ok or type(meta) ~= "table" or type(meta.segments) ~= "table" then
		Warn("HeartRate: unreadable HRM-SEGMENTS line in " .. filename)
		return nil
	end

	local timing = steps:GetTimingData()
	local ToSeconds = meta.unit == "second"
		and function(t) return t / rate end
		or function(beat) return timing:GetElapsedTimeFromBeat(beat) / rate end

	local segments = {}
	for seg in ivalues(meta.segments) do
		if type(seg.start) == "number" and type(seg["end"]) == "number" then
			segments[#segments+1] = {
				kind = seg.kind or "segment",
				label = seg.label,
				start_s = Round(ToSeconds(seg.start)),
				end_s = Round(ToSeconds(seg["end"])),
				measures = meta.unit ~= "second" and Round((seg["end"] - seg.start) / 4) or nil,
			}
		end
	end
	return segments
end

local Prepare = function(idx)
	local rate = Rate()
	local song
	local ps, labels = {}, {}

	for player in ivalues(players) do
		local pn = ToEnumShortString(player)
		local s, steps = SongAndSteps(player, idx)
		song = song or s
		if steps then
			local difficulty = ToEnumShortString(steps:GetDifficulty())
			local segments, hash = Segments(steps, pn, rate)
			-- the generator's own splits, when the simfile has them, beat stream detection
			segments = FileSegments(steps, rate) or segments
			ps[#ps+1] = {
				player = pn,
				steps_type = ToEnumShortString(steps:GetStepsType()),
				difficulty = difficulty,
				meter = steps:GetMeter(),
				chart_hash = hash,
				segments = segments,
			}
			labels[#labels+1] = (#players > 1 and pn.." " or "") .. difficulty .. " " .. steps:GetMeter()
		end
	end
	if not song then return nil end

	-- one player: segments live at the top level.  two players: each player
	-- keeps their own, and the top level gets the first player's.
	local segments = ps[1] and ps[1].segments or {}
	if #ps == 1 then ps[1].segments = nil end

	return {
		idx = idx,
		song = song,
		label = ("%s [%s]"):format(song:GetDisplayMainTitle(), table.concat(labels, " / ")),
		data = {
			title = song:GetDisplayMainTitle(),
			subtitle = song:GetDisplaySubTitle(),
			artist = song:GetDisplayArtist(),
			pack = song:GetGroupName(),
			rate = rate,
			length_s = Round(song:GetLastSecond() / rate),
			players = ps,
			segments = segments,
		},
	}
end

local BeginSong = function()
	local id = HeartRate.NextId()
	HeartRate.Emit({
		kind = "begin", type = "song", id = id, parent = course_id,
		label = prepared.label, music_seconds = 0, data = prepared.data,
	})
	HeartRate.open = { id = id, idx = prepared.idx, song = prepared.song, label = prepared.label }
end

-- final: the screen is going away (as opposed to moving on to the next
-- song in a course), so an unfinished song means the player quit
local EndSong = function(final)
	local open = HeartRate.open
	if not open then return end
	HeartRate.open = nil

	local stats = STATSMAN:GetCurStageStats()
	local ps, all_failed = {}, true
	for player in ivalues(players) do
		local pss = stats:GetPlayerStageStats(player)
		local failed = pss:GetFailed()
		all_failed = all_failed and failed
		local p = { player = ToEnumShortString(player), failed = failed }
		-- in course mode the stats cover the whole course so far; the
		-- score and grade go on the course's end event instead
		if not course_mode then
			p.score_percent = Round(pss:GetPercentDancePoints() * 100, 2)
			p.grade = ToEnumShortString(pss:GetGrade())
		end
		ps[#ps+1] = p
	end

	local music = GAMESTATE:GetCurMusicSeconds()
	local result = "cleared"
	if all_failed then
		result = "failed"
	elseif final and music < open.song:GetLastSecond() then
		result = "quit"
	end

	HeartRate.Emit({
		kind = "end", type = "song", id = open.id, parent = course_id, label = open.label,
		-- moving on in a course: the song played out to its end
		music_seconds = Round((final and music or open.song:GetLastSecond()) / Rate()),
		data = { result = result, players = ps },
	})
end

local EndCourse = function()
	if not course_id then return end
	local stats = STATSMAN:GetCurStageStats()
	local ps, all_failed = {}, true
	for player in ivalues(players) do
		local pss = stats:GetPlayerStageStats(player)
		all_failed = all_failed and pss:GetFailed()
		ps[#ps+1] = {
			player = ToEnumShortString(player),
			failed = pss:GetFailed(),
			score_percent = Round(pss:GetPercentDancePoints() * 100, 2),
			grade = ToEnumShortString(pss:GetGrade()),
		}
	end
	local course = GAMESTATE:GetCurrentCourse()
	local finished_all = (SongIndex() + 1 >= course:GetNumCourseEntries()) and
		GAMESTATE:GetCurMusicSeconds() >= GAMESTATE:GetCurrentSong():GetLastSecond()

	HeartRate.Emit({
		kind = "end", type = "course", id = course_id, label = course:GetDisplayFullTitle(),
		data = { result = all_failed and "failed" or (finished_all and "cleared" or "quit"), players = ps },
	})
	course_id = nil
end

local Finish = function()
	if finished then return end
	finished = true
	EndSong(true)
	EndCourse()
end

local Mark = function(kind_type)
	HeartRate.Emit({
		kind = "mark", type = kind_type,
		parent = HeartRate.open and HeartRate.open.id or course_id,
		music_seconds = Round(GAMESTATE:GetCurMusicSeconds() / Rate()),
	})
end

local Update = function(self)
	if finished then return end
	local idx = SongIndex()
	local music = GAMESTATE:GetCurMusicSeconds()

	-- course moved on to its next song
	if HeartRate.open and HeartRate.open.idx ~= idx then EndSong(false) end
	if not HeartRate.open and (not prepared or prepared.idx ~= idx) then prepared = Prepare(idx) end

	-- begin when the music crosses 0
	if not HeartRate.open and prepared and prepared.idx == idx and last_music < 0 and music >= 0 then
		BeginSong()
	end
	last_music = music
end

return Def.ActorFrame{
	OnCommand=function(self)
		-- a song left open by a previous gameplay screen (e.g. backed out in
		-- a way that didn't reach OffCommand): close it now, late
		if HeartRate.open then
			HeartRate.Emit({
				kind = "end", type = "song", id = HeartRate.open.id, label = HeartRate.open.label,
				data = { result = "quit", late = true },
			})
			HeartRate.open = nil
		end

		HeartRate.Emit({ kind = "mark", type = "screen", label = "ScreenGameplay", data = { screen = "ScreenGameplay" } })

		if course_mode then
			local course = GAMESTATE:GetCurrentCourse()
			course_id = HeartRate.NextId()
			HeartRate.Emit({
				kind = "begin", type = "course", id = course_id, label = course:GetDisplayFullTitle(),
				data = { title = course:GetDisplayFullTitle(), songs = course:GetNumCourseEntries() },
			})
		end

		prepared = Prepare(SongIndex())
		self:SetUpdateFunction(Update)
	end,

	OffCommand=function(self) Finish() end,
	CancelCommand=function(self) Finish() end,
	-- broadcast by the pause menu and the Ctrl+R restart before they back out
	GameplayQuitMessageCommand=function(self) Finish() end,

	GameplayPausedMessageCommand=function(self) Mark("pause") end,
	GameplayResumedMessageCommand=function(self) Mark("resume") end,
}
