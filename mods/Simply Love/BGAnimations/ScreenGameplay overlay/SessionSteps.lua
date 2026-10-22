-- Adds this stage's steps to the session totals shown in the ScreenSelectMusic
-- header: steps hit (any timing window) out of steps judged (hits + misses).
-- Mines don't count.  Songs that are quit or restarted count up to where they
-- were left.

local hit_windows = { "W1", "W2", "W3", "W4", "W5" }
local counted = false

local Count = function()
	if counted then return end
	counted = true

	local totals = SL.Global.SessionSteps
	if not totals then return end

	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
		local hit = 0
		for w in ivalues(hit_windows) do
			hit = hit + pss:GetTapNoteScores("TapNoteScore_" .. w)
		end
		totals.hit = totals.hit + hit
		totals.total = totals.total + hit + pss:GetTapNoteScores("TapNoteScore_Miss")
	end
end

return Def.Actor{
	OffCommand=Count,
	CancelCommand=Count,
	GameplayQuitMessageCommand=Count,
}
