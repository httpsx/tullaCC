--[[
	tullaCooldownCount
		A basic cooldown count addon

		The purpose of this addon is mainly for me to test performance optimizations
		and also for people who don't care about the extra features of OmniCC
--]]

--constants!
local ICON_SIZE = 36 --the normal size for an icon (don't change this)
local FONT_FACE = STANDARD_TEXT_FONT --what font to use
local FONT_SIZE = 18 --the base font size to use at a scale of 1
local MIN_SCALE = 0.5 --the minimum scale we want to show cooldown counts at, anything below this will be hidden
local MIN_DURATION = 3 --the minimum duration to show cooldown text for
local DAY, HOUR, MINUTE = 86400, 3600, 60 --used for formatting text
local DAYISH, HOURISH, MINUTEISH = 3600 * 23.5, 60 * 59.5, 59.5 --used for formatting text at transition points
local HALFDAYISH, HALFHOURISH, HALFMINUTEISH = DAY/2 + 0.5, HOUR/2 + 0.5, MINUTE/2 + 0.5 --used for calculating next update times

--local bindings!
local format = string.format
local floor = math.floor
local min = math.min
local round = function(x) return floor(x + 0.5) end
local GetTime = GetTime

--returns both what text to display, and how long until the next update
local function getTimeText(s)
	--format text as seconds when at 90 seconds or below
	if s < MINUTEISH then
		local seconds = round(s)
		return seconds, s - (seconds - 0.51)
	--format text as minutes when below an hour
	elseif s < HOURISH then
		local minutes = round(s/MINUTE)
		return minutes .. 'm', minutes > 1 and (s - (minutes*MINUTE - HALFMINUTEISH)) or (s - MINUTEISH)
	--format text as hours when below a day
	elseif s < DAYISH then
		local hours = round(s/HOUR)
		return hours .. 'h', hours > 1 and (s - (hours*HOUR - HALFHOURISH)) or (s - HOURISH)
	--format text as days
	else
		local days = round(s/DAY)
		return days .. 'd', days > 1 and (s - (days*DAY - HALFDAYISH)) or (s - DAYISH)
	end
end

--stops the timer
local function Timer_Stop(self)
	self.enabled = nil
	self:Hide()
end

--forces the given timer to update on the next frame
local function Timer_ForceUpdate(self)
	self.nextUpdate = 0
	self:Show()
end

--scale text when a button's size changes
local function Timer_OnSizeChanged(self, width, height)
	local fontScale = round(width) / ICON_SIZE
	if fontScale == self.fontScale then
		return
	end

	self.fontScale = fontScale
	if fontScale < MIN_SCALE then
		self:Hide()
	else
		self.text:SetFont(FONT_FACE, fontScale * FONT_SIZE, 'OUTLINE')
		if self.enabled then
			Timer_ForceUpdate(self)
		end
	end
end

local function Timer_OnUpdate(self, elapsed)
	if self.nextUpdate > 0 then
		self.nextUpdate = self.nextUpdate - elapsed
	else
		local remain = self.duration - (GetTime() - self.start)
		if round(remain) > 0 then
			local time, nextUpdate = getTimeText(remain)
			self.text:SetText(time)
			self.nextUpdate = nextUpdate
		else
			Timer_Stop(self)
		end
	end
end

local function Timer_Create(cd)
	local scaler = CreateFrame('Frame', nil, cd) --needed since OnSizeChanged has funny triggering if the parent is not visible for some reason
	scaler:SetAllPoints(cd)

	local timer = CreateFrame('Frame', nil, scaler); timer:Hide()
	timer:SetAllPoints(scaler)
	timer:SetScript('OnUpdate', Timer_OnUpdate)

	local text = timer:CreateFontString(nil, 'OVERLAY')
	text:SetPoint('CENTER', 0, 0)
	text:SetTextColor(1, 0.92, 0)
	timer.text = text

	Timer_OnSizeChanged(timer, scaler:GetSize())
	scaler:SetScript('OnSizeChanged', function(self, ...) Timer_OnSizeChanged(timer, ...) end)

	cd.timer = timer
	return timer
end

--ActionButton1Cooldown here, is something we think will always exist
hooksecurefunc(getmetatable(ActionButton1Cooldown).__index, 'SetCooldown', function(cd, start, duration)
	--start timer
	if start > 0 and duration > MIN_DURATION then
		local timer = cd.timer or Timer_Create(cd)
		timer.start = start
		timer.duration = duration
		timer.enabled = true
		timer.nextUpdate = 0
		if timer.fontScale >= MIN_SCALE then timer:Show() end
	--stop timer
	else
		local timer = cd.timer
		if timer then
			Timer_Stop(timer)
		end
	end
end)