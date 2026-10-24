-- AutoSpam: core logic (data, timer, posting, AFK, auto-invite, links)
-- WoW 1.12 / Turtle WoW, Lua 5.0

AutoSpam = {}

AutoSpam.CHANNELS = {
    { text = "Say",            value = "SAY" },
    { text = "Yell",           value = "YELL" },
    { text = "Guild",          value = "GUILD" },
    { text = "Officer",        value = "OFFICER" },
    { text = "Party",          value = "PARTY" },
    { text = "Raid",           value = "RAID" },
    { text = "World",          value = "WORLD" },
    { text = "Custom Channel", value = "CHANNEL" },
}

local WORLD_CHANNELS = { "World", "world", "LookingForGroup", "LFG" }
local INVITE_COOLDOWN = 10   -- seconds before the same player can trigger another invite
local DEFAULT_KEYWORDS = "inv, invite, +1"
AutoSpam.MAX_LEN = 511       -- longest message the editor and sender allow
local CHANNEL_GAP = 1         -- seconds between channels when a message posts to several
local RESUME_DELAY = 120     -- seconds before posting turns itself off after logging in while still running

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Print(msg, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100AutoSpam:|r " .. msg, r or 1, g or 1, b or 1)
end
AutoSpam.Print = Print

local function Trim(s)
    if not s then return "" end
    local r = string.gsub(s, "^%s*(.-)%s*$", "%1")
    return r
end
AutoSpam.Trim = Trim

function AutoSpam:ChannelLabel(channel, customChannel)
    if channel == "CHANNEL" then
        local c = Trim(customChannel)
        if c ~= "" then return c end
        return "Custom"
    end
    for i = 1, table.getn(self.CHANNELS) do
        if self.CHANNELS[i].value == channel then
            return self.CHANNELS[i].text
        end
    end
    return "Say"
end

-- Checked channels in menu order, as a list of values
function AutoSpam:CheckedChannels(channels)
    local list = {}
    if not channels then return list end
    for i = 1, table.getn(self.CHANNELS) do
        local v = self.CHANNELS[i].value
        if channels[v] then table.insert(list, v) end
    end
    return list
end

-- "Say, World" style label for a set of channels
function AutoSpam:ChannelsLabel(channels, customChannel)
    local list = self:CheckedChannels(channels)
    if table.getn(list) == 0 then return "No channel" end
    local names = {}
    for i = 1, table.getn(list) do
        table.insert(names, self:ChannelLabel(list[i], customChannel))
    end
    return table.concat(names, ", ")
end

-- Display version of message text: item links shown as their [Name]
function AutoSpam:PlainText(text)
    if not text then return "" end
    local r = string.gsub(text, "|c%x%x%x%x%x%x%x%x|H.-|h(.-)|h|r", "%1")
    return r
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

function AutoSpam:Initialize()
    if not AutoSpamDB then AutoSpamDB = {} end
    local db = AutoSpamDB

    if not db.messages then db.messages = {} end
    if not db.minimapPos then db.minimapPos = 180 end
    if not db.interval then db.interval = 300 end
    if db.debugMode == nil then db.debugMode = false end
    if db.dryRun == nil then db.dryRun = false end
    if not db.scale then db.scale = 1 end

    -- Bring messages saved by older versions up to the current format
    for i = 1, table.getn(db.messages) do
        local m = db.messages[i]
        if not m.name or m.name == "" then m.name = "Message " .. i end
        if not m.text then m.text = "" end
        if not m.channel then m.channel = "SAY" end
        -- Messages can post to several channels now; older ones had just one
        if type(m.channels) ~= "table" then
            m.channels = {}
            m.channels[m.channel] = true
        end
        if not m.customChannel then m.customChannel = "" end
        if not m.weight then m.weight = 1 end
        m.weight = math.floor(m.weight + 0.5)
        if m.weight < 1 then m.weight = 1 end
        if not m.enabled then m.enabled = false end
        if not m.autoInvite then m.autoInvite = false end
        -- Older builds kept keywords and convert-to-raid globally; seed each message from them
        if not m.inviteKeywords then m.inviteKeywords = db.inviteKeywords or DEFAULT_KEYWORDS end
        if m.inviteConvert == nil then m.inviteConvert = (db.autoConvertRaid == true) end
    end

    self.db = db
    self.lastPostTime = 0         -- GetTime() of the last post, 0 = never
    self.timerStarted = false     -- timer runs only after Start or Post now
    self.sessionStart = 0
    self.sentCount = 0

    -- Still running at logout? Hold everything (no posts, no invites) and ask.
    -- Unless the player picks Post now within RESUME_DELAY seconds, posting turns off.
    self.resumed = db.enabled and true or false
    self.resumeHold = false
    if self.resumed then
        db.enabled = true
        self.resumeHold = true
        self.resumeDeadline = GetTime() + RESUME_DELAY
    else
        db.enabled = false
    end
    self.nextMsg = nil
    self.recentInvites = {}
    self.inviteQueue = {}
    self.sendQueue = {}
    self.echoWatch = {}
end

---------------------------------------------------------------------------
-- Message management
---------------------------------------------------------------------------

function AutoSpam:FindByName(name)
    for i = 1, table.getn(self.db.messages) do
        if self.db.messages[i].name == name then
            return self.db.messages[i]
        end
    end
    return nil
end

function AutoSpam:AddMessage(name)
    name = Trim(name)
    if name == "" then
        Print("Enter a name for the new message.", 1, 0.3, 0.3)
        return nil
    end
    if self:FindByName(name) then
        Print("A message named '" .. name .. "' already exists.", 1, 0.3, 0.3)
        return nil
    end
    local m = {
        name = name, text = "", enabled = false,
        channel = "SAY", channels = { SAY = true }, customChannel = "", weight = 1,
        autoInvite = false, inviteKeywords = DEFAULT_KEYWORDS, inviteConvert = false,
    }
    table.insert(self.db.messages, m)
    self:RefreshUI()
    return m
end

function AutoSpam:DeleteMessage(m)
    for i = 1, table.getn(self.db.messages) do
        if self.db.messages[i] == m then
            table.remove(self.db.messages, i)
            Print("Removed '" .. m.name .. "'.", 1, 1, 0)
            if self.OnMessageDeleted then self:OnMessageDeleted(m) end
            self:ValidateNext()
            self:RefreshUI()
            return
        end
    end
end

function AutoSpam:MoveMessage(index, dir)
    local list = self.db.messages
    local other = index + dir
    if not list[index] or not list[other] then return end
    local tmp = list[index]
    list[index] = list[other]
    list[other] = tmp
    self:RefreshUI()
end

function AutoSpam:SetMessageEnabled(m, enabled)
    m.enabled = enabled and true or false
    if self.db.debugMode then
        Print("'" .. m.name .. "' " .. (m.enabled and "enabled" or "disabled") .. ".", 1, 1, 0)
    end
    self:ValidateNext()
    self:RefreshUI()
end

---------------------------------------------------------------------------
-- Weighted selection (the next message is picked ahead of time so the UI can show it)
---------------------------------------------------------------------------

function AutoSpam:IsEligible(m)
    if not m or not m.enabled or not m.text or m.text == "" then return false end
    for i = 1, table.getn(self.db.messages) do
        if self.db.messages[i] == m then return true end
    end
    return false
end

function AutoSpam:RollNext()
    local total = 0
    local list = {}
    for i = 1, table.getn(self.db.messages) do
        local m = self.db.messages[i]
        if self:IsEligible(m) then
            table.insert(list, m)
            total = total + (m.weight or 1)
        end
    end
    if total <= 0 then
        self.nextMsg = nil
        return nil
    end
    local r = math.random(1, total)
    for i = 1, table.getn(list) do
        r = r - (list[i].weight or 1)
        if r <= 0 then
            self.nextMsg = list[i]
            return list[i]
        end
    end
    self.nextMsg = list[table.getn(list)]
    return self.nextMsg
end

function AutoSpam:ValidateNext()
    if not self:IsEligible(self.nextMsg) then
        self:RollNext()
    end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

-- Fill in {GROUP}, {ZONE} and friends at the moment a message posts
AutoSpam.PLACEHOLDERS = {
    { key = "GROUP", desc = "How many are in your group" },
    { key = "ZONE",  desc = "The zone you're in" },
    { key = "TIME",  desc = "Server time" },
    { key = "NAME",  desc = "Your character's name" },
    { key = "GUILD", desc = "Your guild's name" },
}

function AutoSpam:PlaceholderValue(key)
    if key == "GROUP" then
        local raidN = GetNumRaidMembers()
        if raidN > 0 then return tostring(raidN) end
        return tostring(GetNumPartyMembers() + 1)
    elseif key == "ZONE" then
        return GetZoneText() or ""
    elseif key == "TIME" then
        local h, mins = GetGameTime()
        local suffix = "AM"
        if h >= 12 then suffix = "PM" end
        local h12 = math.mod(h, 12)
        if h12 == 0 then h12 = 12 end
        return string.format("%d:%02d %s", h12, mins, suffix)
    elseif key == "NAME" then
        return UnitName("player") or ""
    elseif key == "GUILD" then
        return GetGuildInfo("player") or ""
    end
    return nil
end

-- {UTC Sunday 1300}: your local day/time converted to UTC
local DAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

-- Day word in the same style it was typed: Sun, Sunday or Sundays, matching upper case
local function DayLike(word, typedIndex, newIndex)
    local typedFull = string.lower(DAYS[typedIndex])
    local full = DAYS[newIndex]
    local lw = string.lower(word)
    local out
    if lw == typedFull then
        out = full
    elseif lw == typedFull .. "s" then
        out = full .. "s"
    else
        out = string.sub(full, 1, 3)
    end
    if word == string.upper(word) then out = string.upper(out) end
    return out
end

-- Reads "Sunday 1300", "Sun 1:00 PM", "1pm" or "13:00".
-- Returns a table describing it, or nil if it can't be read.
local function ParseDayTime(spec)
    local s = Trim(spec)
    local p = {}
    local _, _, w, rest = string.find(s, "^(%a+)%s+(.+)$")
    if w and string.find(rest, "^%d") then
        local key = string.lower(string.sub(w, 1, 3))
        for i = 1, 7 do
            if string.lower(string.sub(DAYS[i], 1, 3)) == key then p.dayIndex = i end
        end
        if not p.dayIndex then return nil end
        p.dayWord = w
        s = rest
    end

    local h, m, a, b, c
    _, _, a, b, c = string.find(s, "^(%d%d?):(%d%d)%s*([AaPp]%.?[Mm]%.?)$")
    if a then
        h, m, p.ampm, p.colon = a, b, c, true
    else
        _, _, a, b = string.find(s, "^(%d%d?):(%d%d)$")
        if a then
            h, m, p.colon = a, b, true
        else
            _, _, a, c = string.find(s, "^(%d%d?)%s*([AaPp]%.?[Mm]%.?)$")
            if a then
                h, p.ampm = a, c
            else
                _, _, a, b = string.find(s, "^(%d?%d)(%d%d)$")
                if not a then return nil end
                h, m = a, b
            end
        end
    end
    p.hadMinutes = m and true or false
    p.spaceBeforeAmpm = string.find(s, "%s[AaPp]") and true or false

    h = tonumber(h)
    local mins = 0
    if m then mins = tonumber(m) end
    if mins > 59 then return nil end
    if p.ampm then
        if h < 1 or h > 12 then return nil end
        if h == 12 then h = 0 end
        if string.find(string.lower(p.ampm), "^p") then h = h + 12 end
    elseif h > 23 then
        return nil
    end
    p.hour, p.min = h, mins
    return p
end

-- Writes a time back in the style it was typed
local function FormatLike(p, day, h, mins)
    local out
    if p.ampm then
        local suffix = "AM"
        if h >= 12 then suffix = "PM" end
        if string.find(p.ampm, "%l") then suffix = string.lower(suffix) end
        local h12 = math.mod(h, 12)
        if h12 == 0 then h12 = 12 end
        if p.hadMinutes or mins ~= 0 then
            out = string.format("%d:%02d", h12, mins)
        else
            out = tostring(h12)
        end
        if p.spaceBeforeAmpm then out = out .. " " end
        out = out .. suffix
    elseif p.colon then
        out = string.format("%02d:%02d", h, mins)
    else
        out = string.format("%02d%02d", h, mins)
    end
    if p.dayWord then out = DayLike(p.dayWord, p.dayIndex, day) .. " " .. out end
    return out
end

-- Turns your local day and time into UTC. Works out the actual date it falls on
-- (the next one, if you gave a day), so a daylight saving change in between is
-- handled. Returns nil if the text can't be read or the client has no clock.
function AutoSpam:ConvertToUTC(spec)
    if not date or not time then return nil end
    local p = ParseDayTime(spec)
    if not p then return nil end

    local now = time()
    local lt = date("*t", now)
    if not lt or not lt.wday then return nil end
    local ahead = 0
    if p.dayIndex then
        ahead = math.mod(p.dayIndex - lt.wday + 7, 7)
        if ahead == 0 and p.hour * 60 + p.min < lt.hour * 60 + lt.min then ahead = 7 end
    end

    local t = time({ year = lt.year, month = lt.month, day = lt.day + ahead, hour = p.hour, min = p.min, sec = 0 })
    if not t then return nil end
    -- Check that moment really reads as the typed time on this PC; Lua 5.0 assumes
    -- standard time, so during daylight saving it lands an hour off without this
    local chk = date("*t", t)
    local diff = (p.hour * 60 + p.min) - (chk.hour * 60 + chk.min)
    if diff > 720 then diff = diff - 1440 end
    if diff < -720 then diff = diff + 1440 end
    t = t + diff * 60

    local u = date("!*t", t)
    if not u or not u.wday then return nil end
    return FormatLike(p, u.wday, u.hour, u.min) .. " UTC"
end

function AutoSpam:ExpandText(text)
    local out = string.gsub(text or "", "({[Uu][Tt][Cc]%s+([^{}]-)})", function(whole, spec)
        return AutoSpam:ConvertToUTC(spec) or whole   -- unreadable: leave it as typed
    end)
    out = string.gsub(out, "{(%a+)}", function(word)
        local v = AutoSpam:PlaceholderValue(string.upper(word))
        if v then return v end
        return "{" .. word .. "}"   -- not a placeholder, leave it alone
    end)
    return out
end

-- Sends one queued item to one channel
function AutoSpam:SendToChannel(item)
    local text, ch = item.text, item.channel
    if ch == "SAY" or ch == "YELL" or ch == "GUILD" or ch == "OFFICER" or ch == "PARTY" or ch == "RAID" then
        SendChatMessage(text, ch)
        return true
    elseif ch == "CHANNEL" then
        local name = Trim(item.custom)
        if name == "" then
            Print("'" .. item.name .. "' has no custom channel set.", 1, 0.3, 0.3)
            return false
        end
        local lookup = tonumber(name) or name
        local id = GetChannelName(lookup)
        if id and id > 0 then
            self:WatchEcho(item, name)   -- before sending, in case the echo is instant
            SendChatMessage(text, "CHANNEL", nil, id)
            return true
        end
        Print("Channel '" .. name .. "' not found. Join it first.", 1, 0.3, 0.3)
        return false
    elseif ch == "WORLD" then
        for i = 1, table.getn(WORLD_CHANNELS) do
            local id = GetChannelName(WORLD_CHANNELS[i])
            if id and id > 0 then
                self:WatchEcho(item, WORLD_CHANNELS[i])
                SendChatMessage(text, "CHANNEL", nil, id)
                return true
            end
        end
        Print("World channel not found.", 1, 0.3, 0.3)
        return false
    end
    return false
end

---------------------------------------------------------------------------
-- Post check: the server echoes every channel message back to the sender.
-- If ours doesn't come back within a few seconds, the server dropped it
-- (spam filter, mute, channel rule), so say so instead of failing silently.
---------------------------------------------------------------------------

local ECHO_WAIT = 6

local function Squash(t)
    t = string.gsub(t or "", "%s+", " ")
    return string.lower(Trim(t))
end

function AutoSpam:WatchEcho(item, chanName)
    table.insert(self.echoWatch, {
        key = Squash(item.text), name = item.name, chan = chanName, item = item,
        deadline = GetTime() + ECHO_WAIT,
    })
end

function AutoSpam:OnChannelEcho(text, author)
    if author ~= UnitName("player") or table.getn(self.echoWatch) == 0 then return end
    local key = Squash(text)
    for i = 1, table.getn(self.echoWatch) do
        local w = self.echoWatch[i]
        -- Exact match, or the server trimmed or reworded the end slightly
        if w.key == key or string.sub(w.key, 1, 40) == string.sub(key, 1, 40) then
            table.remove(self.echoWatch, i)
            if self.db.debugMode then
                Print("'" .. w.name .. "' showed up in " .. w.chan .. ".", 0, 1, 1)
            end
            return
        end
    end
end

function AutoSpam:OnSystemDuringWatch(text)
    if table.getn(self.echoWatch) > 0 and text and text ~= "" then
        self.echoSystemMsg = text
    end
end

function AutoSpam:CheckEchoes(now)
    local i = 1
    while self.echoWatch[i] do
        local w = self.echoWatch[i]
        if now >= w.deadline then
            table.remove(self.echoWatch, i)
            if not w.item.retried and self.db.enabled then
                -- Dropped once: send it one more time
                w.item.retried = true
                Print("'" .. w.name .. "' didn't show up in " .. w.chan .. ". Sending it once more.", 1, 0.82, 0)
                self:SendToChannel(w.item)
            else
                Print("'" .. w.name .. "' was sent twice but never showed up in " .. w.chan .. ". The server probably blocked it.", 1, 0.3, 0.3)
                if self.echoSystemMsg then
                    Print("Server said: " .. self.echoSystemMsg, 1, 0.3, 0.3)
                end
            end
        else
            i = i + 1
        end
    end
    if table.getn(self.echoWatch) == 0 then self.echoSystemMsg = nil end
end

function AutoSpam:SendText(m)
    local text = self:ExpandText(m.text)
    if string.len(text) > self.MAX_LEN then
        Print("'" .. m.name .. "' runs over " .. self.MAX_LEN .. " characters once placeholders are filled in, so it was skipped. Shorten it a little.", 1, 0.3, 0.3)
        return false
    end
    local list = self:CheckedChannels(m.channels)
    if table.getn(list) == 0 then
        Print("'" .. m.name .. "' has no channel picked.", 1, 0.3, 0.3)
        return false
    end

    if self.db.dryRun then
        for i = 1, table.getn(list) do
            DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[AutoSpam dry run]|r |cffaaaaaa[" .. self:ChannelLabel(list[i], m.customChannel) .. "]|r " .. text)
        end
        if self.OnDryRunPost then self:OnDryRunPost() end
        return true
    end

    -- One channel goes now, each extra one waits CHANNEL_GAP more seconds
    local now = GetTime()
    for i = 1, table.getn(list) do
        table.insert(self.sendQueue, {
            at = now + (i - 1) * CHANNEL_GAP,
            text = text, channel = list[i], custom = m.customChannel, name = m.name,
        })
    end
    self:ProcessSendQueue(now)
    return true
end

function AutoSpam:ProcessSendQueue(now)
    local q = self.sendQueue
    while q[1] and now >= q[1].at do
        local item = table.remove(q, 1)
        self:SendToChannel(item)
    end
end

function AutoSpam:SetDryRun(on)
    self.db.dryRun = on and true or false
    if self.db.dryRun then
        Print("Dry run on. Posts print to your chat only.", 0.4, 0.8, 1)
    else
        Print("Dry run off. Posts go live.", 0, 1, 0)
    end
    self:RefreshUI()
end

function AutoSpam:PostNext()
    self:ValidateNext()
    local m = self.nextMsg
    if not m then
        Print("Nothing to post. Enable a message that has text.", 1, 0.3, 0.3)
        self:RefreshUI()
        return false
    end
    if self.db.debugMode then
        Print("Posting '" .. m.name .. "'.", 0, 1, 1)
    end
    local ok = self:SendText(m)
    if ok then self.sentCount = self.sentCount + 1 end
    self:RollNext()
    self:RefreshUI()
    return ok
end

function AutoSpam:EndResumeHold()
    if self.resumeHold then
        -- Posting picks up again from the login popup: start the Running clock now
        self.sessionStart = GetTime()
        self.sentCount = 0
    end
    self.resumeHold = false
end

-- Called when nobody answered the login popup in time
function AutoSpam:ResumeTimedOut()
    self.resumeHold = false
    self.db.enabled = false
    self.timerStarted = false
    self.lastPostTime = 0
    Print("Posting turned itself off since it was left on at logout. Click Start when you're ready.", 1, 0.5, 0)
    self:RefreshUI()
end

function AutoSpam:TogglePosting()
    self:EndResumeHold()
    local db = self.db
    db.enabled = not db.enabled
    if db.enabled then
        Print("Started posting." .. (db.dryRun and " (dry run)" or ""), 0, 1, 0)
        self.sessionStart = GetTime()
        self.sentCount = 0
        self.timerStarted = true
        if self.lastPostTime == 0 then
            -- Timer was idle: post right away and start the clock
            self:PostNext()
            self.lastPostTime = GetTime()
        else
            self:ValidateNext()
        end
    else
        Print("Stopped posting.", 1, 1, 0)
    end
    self:RefreshUI()
end

function AutoSpam:PostNow()
    self:EndResumeHold()
    self:PostNext()
    self.lastPostTime = GetTime()
    self.timerStarted = true
    self:RefreshUI()
end

function AutoSpam:TimeRemaining()
    if self.resumeHold or not self.timerStarted then return nil end
    local r = self.db.interval - (GetTime() - self.lastPostTime)
    if r < 0 then r = 0 end
    return r
end

---------------------------------------------------------------------------
-- Auto-invite (each message has its own switch, keywords and convert option;
-- only enabled messages count, and only while posting is running)
---------------------------------------------------------------------------

function AutoSpam:MatchesKeyword(text, keywords)
    local said = string.lower(Trim(text))
    if said == "" then return false end
    for kw in string.gfind(keywords or "", "[^,]+") do
        local k = string.lower(Trim(kw))
        if k ~= "" and said == k then return true end
    end
    return false
end

function AutoSpam:FindInviteMessage(text)
    if not self.db.enabled or self.resumeHold then return nil end
    for i = 1, table.getn(self.db.messages) do
        local m = self.db.messages[i]
        if m.enabled and m.autoInvite and self:MatchesKeyword(text, m.inviteKeywords) then
            return m
        end
    end
    return nil
end

function AutoSpam:IsInMyGroup(name)
    local raidN = GetNumRaidMembers()
    if raidN > 0 then
        for i = 1, raidN do
            if GetRaidRosterInfo(i) == name then return true end
        end
        return false
    end
    for i = 1, GetNumPartyMembers() do
        if UnitName("party" .. i) == name then return true end
    end
    return false
end

function AutoSpam:HandleWhisper(text, sender)
    if not text or not sender or sender == "" then return end
    if sender == UnitName("player") then return end
    local m = self:FindInviteMessage(text)
    if not m then return end
    if self:IsInMyGroup(sender) then return end

    local now = GetTime()
    if self.recentInvites[sender] and now - self.recentInvites[sender] < INVITE_COOLDOWN then return end

    local delay = 0
    local raidN = GetNumRaidMembers()
    local partyN = GetNumPartyMembers()
    if raidN > 0 then
        if not (IsRaidLeader() or IsRaidOfficer()) then return end
        if raidN >= 40 then
            Print("Raid is full, couldn't invite " .. sender .. ".", 1, 0.5, 0)
            return
        end
    elseif partyN > 0 then
        if not IsPartyLeader() then return end
        if partyN >= 4 then
            if not m.inviteConvert then
                Print("Party is full, couldn't invite " .. sender .. ". Turn on 'Convert to raid' for '" .. m.name .. "' to keep inviting.", 1, 0.5, 0)
                return
            end
            if not self.db.dryRun then ConvertToRaid() end
            delay = 1.5   -- give the server a moment to finish the conversion
        end
    end

    self.recentInvites[sender] = now
    if self.db.dryRun then
        Print("Dry run: would invite " .. sender .. " (" .. m.name .. ").", 0.4, 0.8, 1)
        return
    end
    table.insert(self.inviteQueue, { name = sender, at = now + delay, msg = m.name })
end

function AutoSpam:ProcessInviteQueue(now)
    local q = self.inviteQueue
    local i = 1
    while i <= table.getn(q) do
        if now >= q[i].at then
            InviteByName(q[i].name)
            Print("Invited " .. q[i].name .. " (" .. q[i].msg .. ").", 0, 1, 0)
            table.remove(q, i)
        else
            i = i + 1
        end
    end
end

---------------------------------------------------------------------------
-- Shift-click links into the message editor
---------------------------------------------------------------------------

function AutoSpam:InsertLink(link)
    if not link or not self.linkFocus or not self.linkTarget then return false end
    if not self.linkTarget:IsVisible() then return false end
    local cur = self.linkTarget:GetText() or ""
    if string.len(cur) + string.len(link) > self.MAX_LEN then
        Print("Not enough room for that link (" .. self.MAX_LEN .. " character limit).", 1, 0.3, 0.3)
        return true
    end
    self.linkTarget:Insert(link)
    return true
end

function AutoSpam:InstallLinkHooks()
    if SetItemRef then
        local origSetItemRef = SetItemRef
        SetItemRef = function(link, text, button)
            if IsShiftKeyDown() and AutoSpam:InsertLink(text) then return end
            origSetItemRef(link, text, button)
        end
    end
    if ContainerFrameItemButton_OnClick then
        local origBag = ContainerFrameItemButton_OnClick
        ContainerFrameItemButton_OnClick = function(button, ignoreModifiers)
            if button == "LeftButton" and IsShiftKeyDown() and not ignoreModifiers and AutoSpam.linkFocus then
                local link = GetContainerItemLink(this:GetParent():GetID(), this:GetID())
                if AutoSpam:InsertLink(link) then return end
            end
            origBag(button, ignoreModifiers)
        end
    end
    if PaperDollItemSlotButton_OnClick then
        local origPaperDoll = PaperDollItemSlotButton_OnClick
        PaperDollItemSlotButton_OnClick = function(button, ignoreModifiers)
            if button == "LeftButton" and IsShiftKeyDown() and not ignoreModifiers and AutoSpam.linkFocus then
                local link = GetInventoryItemLink("player", this:GetID())
                if AutoSpam:InsertLink(link) then return end
            end
            origPaperDoll(button, ignoreModifiers)
        end
    end
end

---------------------------------------------------------------------------
-- UI hooks (replaced by AutoSpamUI.lua)
---------------------------------------------------------------------------

function AutoSpam:RefreshUI() end
function AutoSpam:OnTick(elapsed) end

---------------------------------------------------------------------------
-- Timer loop (GetTime based, frame-rate independent)
---------------------------------------------------------------------------

local tickFrame = CreateFrame("Frame")
tickFrame:SetScript("OnUpdate", function()
    if not AutoSpam.db then return end
    local now = GetTime()

    if AutoSpam.resumeHold and now >= AutoSpam.resumeDeadline then
        AutoSpam:ResumeTimedOut()
    end

    if AutoSpam.timerStarted and now - AutoSpam.lastPostTime >= AutoSpam.db.interval then
        if AutoSpam.db.enabled then
            AutoSpam.lastPostTime = now
            -- Post straight away, AFK or not. The server takes channel messages
            -- from AFK players fine; toggling /afk first only added a second
            -- chat packet right before the post.
            AutoSpam:PostNext()
        else
            -- Timer ran out while stopped: go idle so the next Start posts immediately
            AutoSpam.timerStarted = false
            AutoSpam.lastPostTime = 0
            AutoSpam:RefreshUI()
        end
    end

    if table.getn(AutoSpam.inviteQueue) > 0 then
        AutoSpam:ProcessInviteQueue(now)
    end
    if table.getn(AutoSpam.sendQueue) > 0 then
        AutoSpam:ProcessSendQueue(now)
    end
    if table.getn(AutoSpam.echoWatch) > 0 then
        AutoSpam:CheckEchoes(now)
    end

    -- UIParent may show the logout popup after our event handler ran; hide it again
    if AutoSpam.campHideAt and now >= AutoSpam.campHideAt then
        AutoSpam.campHideAt = nil
        if StaticPopup_Hide then StaticPopup_Hide("CAMP") end
    end

    AutoSpam:OnTick(arg1)
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_AUTOSPAM1 = "/autospam"
SLASH_AUTOSPAM2 = "/aspam"
SlashCmdList["AUTOSPAM"] = function(msg)
    if not AutoSpam.db then return end
    local cmd = string.lower(Trim(msg))
    if cmd == "start" then
        if not AutoSpam.db.enabled then AutoSpam:TogglePosting() end
    elseif cmd == "stop" then
        if AutoSpam.db.enabled then AutoSpam:TogglePosting() end
    elseif cmd == "now" then
        AutoSpam:PostNow()
    elseif cmd == "dryrun" then
        AutoSpam:SetDryRun(not AutoSpam.db.dryRun)
    elseif cmd == "time" then
        -- Shows the clock behind {UTC ...} so a wrong conversion can be tracked down
        local pc, utc = "unavailable", "unavailable"
        if date then
            local t = date("*t")
            if t and t.hour then pc = string.format("%02d:%02d", t.hour, t.min) end
            local u = date("!*t")
            if u and u.hour then utc = string.format("%02d:%02d", u.hour, u.min) end
        end
        Print("Your PC: " .. pc .. "   UTC: " .. utc)
        Print("Sun 1300 your time = " .. (AutoSpam:ConvertToUTC("Sun 1300") or "?"))
    elseif cmd == "help" then
        Print("/autospam: open the window. Options: start, stop, now, dryrun, time.")
    else
        if AutoSpam.ToggleWindow then AutoSpam:ToggleWindow() end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Idle logout guard
-- After 30 minutes without keyboard or mouse input the client starts the
-- same 20 second logout countdown as /camp (PLAYER_CAMPING). Chat posts and
-- clearing the AFK flag don't count as input, so while posting is running
-- we cancel that countdown. Logouts you start yourself (/logout, /camp, the
-- game menu, the keybind) all go through Logout(), so we mark those and
-- leave them alone.
---------------------------------------------------------------------------

AutoSpam.userLogoutAt = 0
local origLogout = Logout
Logout = function()
    AutoSpam.userLogoutAt = GetTime()
    if origLogout then return origLogout() end
end

function AutoSpam:HandleCamping()
    if not self.db or not self.db.enabled or self.resumeHold then return end
    if GetTime() - self.userLogoutAt < 5 then return end
    if not CancelLogout then return end
    CancelLogout()
    if StaticPopup_Hide then StaticPopup_Hide("CAMP") end
    self.campHideAt = GetTime() + 0.2
    Print("Stopped an idle logout so posting can keep going.", 1, 0.82, 0)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:RegisterEvent("PLAYER_CAMPING")
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if AutoSpam.initialized then return end
        AutoSpam:Initialize()
        AutoSpam:InstallLinkHooks()
        if AutoSpam.CreateUI then
            local ok, err = pcall(function() AutoSpam:CreateUI() end)
            if not ok then
                Print("UI error: " .. tostring(err), 1, 0, 0)
            end
        end
        AutoSpam.initialized = true
        AutoSpam:RollNext()
        AutoSpam:RefreshUI()
        Print("loaded. Type /autospam or click the minimap button.", 0, 1, 1)
        if AutoSpam.resumed then
            Print("You didn't stop posting before logging out. AutoSpam will turn itself off in 2 minutes unless you choose Post now.", 1, 0.5, 0)
            if AutoSpam.ShowResumePopup then AutoSpam:ShowResumePopup() end
        end
    elseif event == "CHAT_MSG_WHISPER" then
        if AutoSpam.initialized then
            AutoSpam:HandleWhisper(arg1, arg2)
        end
    elseif event == "PLAYER_CAMPING" then
        AutoSpam:HandleCamping()
    elseif event == "CHAT_MSG_CHANNEL" then
        if AutoSpam.initialized then AutoSpam:OnChannelEcho(arg1, arg2) end
    elseif event == "CHAT_MSG_SYSTEM" then
        if AutoSpam.initialized then AutoSpam:OnSystemDuringWatch(arg1) end
    end
end)
