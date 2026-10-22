-- Two more numbers beside the player's score:
--    PROJ : the score you'd end with if you keep playing like you have so far
--           (points so far / points possible so far)
--    MAX  : the best score still reachable (points so far + everything left
--           played perfectly)
--
-- With one player they're drawn as big as the score itself, in the space the
-- other player's side of the header would use (the BPM now lives in the song
-- title bar, see SongInfoBar.lua).  With two players there isn't room, so
-- they're small and stacked beside each score.

local player = ...
local pn = ToEnumShortString(player)
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
local big = #GAMESTATE:GetHumanPlayers() == 1

-- P1 grows rightward from the score, P2 leftward
local dir = (player == PLAYER_1) and 1 or -1
local gap = 24

local Percent = function(fraction)
	return FormatPercentScore(clamp(fraction, 0, 1)):sub(1, -2)
end

-- star paces get the full-combo colors from Graphics/Player combo.lua,
-- shimmering the same way: 3-4 stars blue, 2 stars gold, 1 star green
local tiers = {
	{ at=0.99, colors={color("#C8FFFF"), color("#6BF0FF")} },
	{ at=0.98, colors={color("#FDFFC9"), color("#FDDB85")} },
	{ at=0.96, colors={color("#C9FFC9"), color("#94FEC1")} },
}

local Tint = function(number, fraction, plain)
	for tier in ivalues(tiers) do
		if fraction >= tier.at then
			number:diffuseshift():effectperiod(0.8)
				:effectcolor1(tier.colors[1]):effectcolor2(tier.colors[2])
			return
		end
	end
	number:stopeffect():diffuse(plain)
end

-- one labeled number; the frame's x is the number's outer edge
local Block = function(name, label, dim)
	local c = dim and {0.7, 0.7, 0.7, 1} or {1, 1, 1, 1}
	return Def.ActorFrame{
		Name=name,
		LoadFont(big and "Wendy/_wendy monospace numbers" or "Common Normal")..{
			Name="Number",
			InitCommand=function(self) self:halign(dir == 1 and 1 or 0):valign(1):diffuse(c) end,
		},
		LoadFont("Common Normal")..{
			Name="Label",
			Text=label,
			InitCommand=function(self) self:halign(dir == 1 and 1 or 0):valign(1):diffuse(c):shadowlength(1) end,
		},
	}
end

return Def.ActorFrame{
	Name=pn.."ScoreProjection",
	OnCommand=function(self)
		local score = self:GetParent():GetChild(pn.."Score")
		if not score then self:visible(false) return end

		-- room for the widest score, so nothing moves as the numbers change
		local text = score:GetText()
		local score_w = score:settext("100.00"):GetZoomedWidth()
		local score_h = score:GetZoomedHeight()
		score:settext(text)

		-- the score is right-aligned; this is its inner edge
		local edge = (dir == 1) and score:GetX() or score:GetX() - score_w
		self:y(score:GetY())

		if big then
			-- same font and size as the score, label small to the left of each number
			local x = edge
			for name in ivalues({"Projected", "Max"}) do
				local block = self:GetChild(name)
				local number = block:GetChild("Number"):zoom(score:GetZoom())
				local label = block:GetChild("Label"):zoom(0.8)
				local num_w = number:settext("100.00"):GetZoomedWidth()
				local label_w = label:GetZoomedWidth()
				-- label vertically centered on the number
				local label_y = -(number:GetZoomedHeight() - label:GetZoomedHeight()) / 2

				if dir == 1 then
					-- [LABEL 00.00] reading left to right, x is the right edge
					x = x + gap + label_w + 6 + num_w
					block:x(x)
					label:x(-num_w - 6):y(label_y)
				else
					-- mirrored: [00.00 LABEL] going leftward, x is the left edge
					x = x - gap - label_w - 6 - num_w
					block:x(x)
					label:x(num_w + 6):y(label_y)
				end
			end
		else
			-- small, stacked: number and label on one line each
			for i, name in ipairs({"Projected", "Max"}) do
				local block = self:GetChild(name)
				block:x(edge + dir * 8):y((i == 1 and -0.5 or 0) * score_h)
				block:GetChild("Number"):zoom(0.75)
				block:GetChild("Label"):visible(false)
			end
		end

		self:playcommand("Redraw")
	end,
	JudgmentMessageCommand=function(self, params)
		if params.Player == player then self:queuecommand("Redraw") end
	end,
	RedrawCommand=function(self)
		local actual = pss:GetActualDancePoints()
		local possible = pss:GetPossibleDancePoints()
		local so_far = pss:GetCurrentPossibleDancePoints()
		if possible <= 0 then return end

		local projected = so_far > 0 and actual / so_far or 1
		local max = (actual + possible - so_far) / possible

		local number = self:GetChild("Projected"):GetChild("Number")
		number:settext((big and "" or "proj ") .. Percent(projected))
		Tint(number, projected, {1, 1, 1, 1})

		number = self:GetChild("Max"):GetChild("Number")
		number:settext((big and "" or "max ") .. Percent(max))
		Tint(number, max, {0.7, 0.7, 0.7, 1})
	end,

	Block("Projected", "PROJ"),
	Block("Max", "MAX", true),
}
