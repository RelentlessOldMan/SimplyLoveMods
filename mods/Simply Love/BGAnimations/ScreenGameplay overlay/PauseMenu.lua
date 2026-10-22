-- Pause menu for ScreenGameplay.
--
-- Spacebar (or the Select button) toggles pause.  While paused, a small menu
-- is shown that can be driven from the keyboard or the pad:
--    Up/Down/Left/Right : move the cursor
--    Start              : choose the highlighted item
--    Back / Spacebar    : resume
--
-- The engine's ScreenGameplay:PauseGame(bool) does the actual freezing of the
-- music and notes; this file only adds input handling and the menu on top.

local paused = false
local leaving = false
local cursor = 1
local af
local menu -- the actual on-screen ActorFrame, captured in InitCommand

local choices = {
	{ text="Resume" },
	{ text="Restart Song", hidden=GAMESTATE:IsCourseMode() },
	{ text=GAMESTATE:IsCourseMode() and "Exit Course" or "Exit to Song Select" },
}
-- drop choices that don't apply
for i=#choices,1,-1 do
	if choices[i].hidden then table.remove(choices, i) end
end

local SongIsOver = function()
	local song = GAMESTATE:GetCurrentSong()
	return song and GAMESTATE:GetCurMusicSeconds() >= song:GetLastSecond()
end

local SetPaused = function(state)
	local screen = SCREENMAN:GetTopScreen()
	if not screen or not screen.PauseGame then return end
	paused = state
	screen:PauseGame(state)
	MESSAGEMAN:Broadcast(state and "GameplayPaused" or "GameplayResumed")
	if state then
		cursor = 1
		menu:playcommand("Show")
	else
		menu:playcommand("Hide")
	end
end

local Choose = function()
	local screen = SCREENMAN:GetTopScreen()
	local choice = choices[cursor].text

	if choice == "Resume" then
		SetPaused(false)
		return
	end

	leaving = true
	SetPaused(false)
	MESSAGEMAN:Broadcast("GameplayQuit")
	if choice == "Restart Song" then
		-- same approach as the theme's Ctrl+R restart
		screen:SetPrevScreenName("ScreenGameplay"):SetNextScreenName("ScreenGameplay")
	end
	-- backing out of gameplay fails the players (see FailOnHoldStart.lua),
	-- so an early exit isn't recorded as a pass
	screen:begin_backing_out()
end

local Move = function(dir)
	cursor = ((cursor - 1 + dir) % #choices) + 1
	menu:playcommand("Update")
	SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
end

local InputHandler = function(event)
	if not event or leaving then return false end
	if event.type ~= "InputEventType_FirstPress" then return paused end

	local key = event.DeviceInput.button
	local btn = event.GameButton
	local toggle = (key == "DeviceButton_space" or btn == "Select")

	if not paused then
		if toggle and not SongIsOver() then
			SetPaused(true)
			return true
		end
		return false
	end

	-- paused: we own all input
	if toggle or btn == "Back" then
		SetPaused(false)
	elseif btn == "Start" then
		Choose()
	elseif btn == "Up" or btn == "MenuUp" or btn == "Left" or btn == "MenuLeft" then
		Move(-1)
	elseif btn == "Down" or btn == "MenuDown" or btn == "Right" or btn == "MenuRight" then
		Move(1)
	end
	return true
end

local row_h = 36
local box_w = 320
-- top padding + rows + room for the hint at the bottom
local box_h = 20 + #choices * row_h + 36

af = Def.ActorFrame{
	Name="PauseMenu",
	InitCommand=function(self) menu = self; self:visible(false) end,
	OnCommand=function(self) SCREENMAN:GetTopScreen():AddInputCallback(InputHandler) end,
	ShowCommand=function(self) self:visible(true):playcommand("Update") end,
	HideCommand=function(self) self:visible(false) end,

	-- dim the whole screen
	Def.Quad{
		InitCommand=function(self) self:FullScreen():diffuse(0,0,0,0.75) end,
	},

	Def.ActorFrame{
		InitCommand=function(self) self:xy(_screen.cx, _screen.cy) end,

		-- border + box
		Def.Quad{
			InitCommand=function(self) self:zoomto(box_w+4, box_h+4):diffuse(GetCurrentColor(true)) end,
		},
		Def.Quad{
			InitCommand=function(self) self:zoomto(box_w, box_h):diffuse(0.1,0.1,0.1,1) end,
		},

		LoadFont("Common Bold")..{
			Text="PAUSED",
			InitCommand=function(self)
				self:y(-box_h/2 - 60):zoom(1.5):shadowlength(2)
					:diffuseshift():effectperiod(1.5)
					:effectcolor1(Color.White):effectcolor2(GetCurrentColor(true))
			end,
		},
		LoadFont("Common Normal")..{
			Text="Space / Back to resume",
			InitCommand=function(self) self:y(box_h/2 - 16):zoom(0.7):diffuse(0.6,0.6,0.6,1) end,
		},
	},
}

-- menu rows
local first_y = _screen.cy - box_h/2 + 20 + row_h/2
for i, choice in ipairs(choices) do
	af[#af+1] = Def.ActorFrame{
		InitCommand=function(self) self:xy(_screen.cx, first_y + (i-1)*row_h) end,
		UpdateCommand=function(self)
			self:GetChild("Highlight"):visible(i == cursor)
			self:GetChild("Label"):diffuse(i == cursor and Color.Black or Color.White)
		end,

		Def.Quad{
			Name="Highlight",
			InitCommand=function(self) self:zoomto(box_w - 40, row_h - 6):diffuse(GetCurrentColor(true)) end,
		},
		LoadFont("Common Normal")..{
			Name="Label",
			Text=choice.text,
			InitCommand=function(self) self:zoom(1.1) end,
		},
	}
end

return af
