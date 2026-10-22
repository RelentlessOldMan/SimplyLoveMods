-- Quick Start from the title menu: does what picking 1 Player, ITG, and Regular
-- on the usual screens would, then goes on to ScreenProfileLoad (and from there
-- to ScreenSelectMusic).  The theme color is whatever was picked last time.

return Def.Actor{
	InitCommand=function(self)
		-- single, on the side of whoever pressed Start
		local player = GAMESTATE:GetMasterPlayerNumber() or PLAYER_1
		if not GAMESTATE:IsHumanPlayer(player) then GAMESTATE:JoinPlayer(player) end
		GAMESTATE:UnjoinPlayer(OtherPlayer[player])
		GAMESTATE:SetCurrentStyle("single")

		-- same as choosing ITG in ScreenSelectPlayMode
		SL.Global.GameMode = "ITG"
		SetGameModePreferences()
		THEME:ReloadMetrics()

		-- same as choosing Regular in ScreenSelectPlayMode2
		GAMESTATE:SetCurrentPlayMode("PlayMode_Regular")

		self:queuecommand("Transition")
	end,
	TransitionCommand=function(self)
		SCREENMAN:SetNewScreen("ScreenProfileLoad")
	end,
}
