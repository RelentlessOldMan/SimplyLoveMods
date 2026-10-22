-- Saves the profiles of joined players right away, so mods changed in the
-- options (speed mod, etc.) survive a restart even if no song is finished.
-- Stock SL only saves on ScreenProfileSave, after evaluation.
SaveProfilesNow = function()
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		if PROFILEMAN:IsPersistentProfile(player) then
			SL[ToEnumShortString(player)].PlayerOptionsString =
				GAMESTATE:GetPlayerState(player):GetPlayerOptionsString("ModsLevel_Preferred")
			PROFILEMAN:SaveProfile(player)
		end
	end
end
