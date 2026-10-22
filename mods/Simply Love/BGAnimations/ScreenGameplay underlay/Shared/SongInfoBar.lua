local w = SL_WideScale(310, 417)
local h = 22

-- Song Completion Meter
return Def.ActorFrame{
	Name="SongMeter",
	InitCommand=function(self) self:xy(_screen.cx, 20) end,

	-- border
	Def.Quad{ InitCommand=function(self) self:zoomto(w, h) end },
	Def.Quad{ InitCommand=function(self) self:zoomto(w-4, h-4):diffuse(0,0,0,1) end },

	Def.SongMeterDisplay{
		StreamWidth=(w-4),
		Stream=Def.Quad({ InitCommand=function(self) self:zoomy(18):diffuse(GetCurrentColor(true)) end })
	},

	-- Song Title, with the current bpm and how much of the song is done:
	-- "Title, 138 bpm, 42%"  (BPMDisplay.lua hides its own readout to match)
	-- (in 5.1 only ActorFrames have SetUpdateFunction, hence the wrapper)
	Def.ActorFrame{
		InitCommand=function(self)
			local state = GAMESTATE:GetPlayerState(GAMESTATE:GetMasterPlayerNumber())
			local so = GAMESTATE:GetSongOptionsObject("ModsLevel_Song")
			local shown
			self:SetUpdateFunction(function(af)
				local song = GAMESTATE:GetCurrentSong()
				if not song then return end
				local rate = so:MusicRate()
				local bpm = ("%d bpm"):format(round(state:GetSongPosition():GetCurBPS() * 60 * rate))
				if ("%.2f"):format(rate) ~= "1.00" then bpm = bpm .. (" (%gx)"):format(rate) end
				local last = song:GetLastSecond()
				local done = last > 0 and clamp(GAMESTATE:GetCurMusicSeconds() / last, 0, 1) or 0
				local text = ("%s, %s, %d%%"):format(song:GetDisplayFullTitle(), bpm, math.floor(done * 100))
				if text ~= shown then af:GetChild("SongTitle"):settext(text); shown = text end
			end)
		end,

		LoadFont("Common Normal")..{
			Name="SongTitle",
			InitCommand=function(self) self:zoom(0.8):shadowlength(0.6):maxwidth((w - 10) / 0.8) end,
		},
	}
}
