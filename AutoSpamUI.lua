-- AutoSpam: single-window UI with side tabs
-- WoW 1.12 / Turtle WoW, Lua 5.0

local Print = AutoSpam.Print
local Trim = AutoSpam.Trim

local W, H = 360, 510
local ROW_H, ROW_GAP = 36, 2
local TEX = "Interface\\AddOns\\AutoSpam\\Textures\\"
local PORTRAIT_FRAMES, PORTRAIT_GRID, PORTRAIT_STEP = 16, 4, 0.18
local MIN_SCALE, MAX_SCALE = 0.6, 1.6

local TABS = {
    { key = "messages", tip = "Messages", icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { key = "editor",   tip = "Editor",   icon = "Interface\\Icons\\INV_Scroll_03" },
    { key = "settings", tip = "Settings", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
    { key = "help",     tip = "Help",     icon = "Interface\\Icons\\INV_Misc_QuestionMark" },
}

local BOX_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local ROW_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

---------------------------------------------------------------------------
-- Widget helpers
---------------------------------------------------------------------------

local function Label(parent, text, font, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetText(text or "")
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

local function Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w)
    b:SetHeight(h or 22)
    b:SetText(text)
    return b
end

local function AddBlend(tex)
    if tex then tex:SetBlendMode("ADD") end
end

-- Red and gold scroll arrows from the stock UI
local function ArrowButton(parent, dir)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(18)
    b:SetHeight(18)
    local base = "Interface\\Buttons\\UI-ScrollBar-Scroll" .. dir .. "Button-"
    b:SetNormalTexture(base .. "Up")
    b:SetPushedTexture(base .. "Down")
    b:SetDisabledTexture(base .. "Disabled")
    b:SetHighlightTexture(base .. "Highlight")
    AddBlend(b:GetHighlightTexture())
    return b
end

local function CloseStyleButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size)
    b:SetHeight(size)
    b:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    AddBlend(b:GetHighlightTexture())
    return b
end

local function CheckBox(parent, text, size)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetWidth(size or 22)
    cb:SetHeight(size or 22)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    AddBlend(cb:GetHighlightTexture())
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    if text then
        local fs = Label(cb, text, "GameFontHighlight")
        fs:SetPoint("LEFT", cb, "RIGHT", 2, 1)
        cb.label = fs
    end
    return cb
end

local function InputBox(name, parent, w, maxLetters)
    local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    eb:SetWidth(w)
    eb:SetHeight(20)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(maxLetters or 50)
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    return eb
end

local function Slider(name, parent, w, minV, maxV, step, lowText, highText)
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetWidth(w)
    s:SetHeight(16)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    getglobal(name .. "Low"):SetText(lowText)
    getglobal(name .. "High"):SetText(highText)
    getglobal(name .. "Text"):SetText("")
    return s
end

local function CopySet(t)
    local c = {}
    if t then
        for k, v in pairs(t) do
            if v then c[k] = true end
        end
    end
    return c
end

local function SameSet(a, b)
    a = a or {}
    b = b or {}
    for k, v in pairs(a) do
        if v and not b[k] then return false end
    end
    for k, v in pairs(b) do
        if v and not a[k] then return false end
    end
    return true
end

local function FormatTime(sec)
    sec = math.floor(sec or 0)
    if sec < 0 then sec = 0 end
    local m = math.floor(sec / 60)
    local s = sec - m * 60
    if m >= 60 then
        local h = math.floor(m / 60)
        m = m - h * 60
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end

local function Preview(text, maxLen)
    local plain = AutoSpam:PlainText(text)
    if plain == "" then return "|cff777777(no text yet)|r" end
    if string.len(plain) > maxLen then
        plain = string.sub(plain, 1, maxLen - 3) .. "..."
    end
    return plain
end

---------------------------------------------------------------------------
-- Popups (explicit save: confirm before throwing away edits)
---------------------------------------------------------------------------

StaticPopupDialogs["AUTOSPAM_DISCARD"] = {
    text = "You have unsaved changes to '%s'. Discard them?",
    button1 = "Discard",
    button2 = "Cancel",
    OnAccept = function()
        local fn = AutoSpam.pendingAction
        AutoSpam.pendingAction = nil
        if fn then fn() end
    end,
    OnCancel = function()
        AutoSpam.pendingAction = nil
        AutoSpam:UpdateTabs()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["AUTOSPAM_DELETE"] = {
    text = "Delete the message '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
        local m = AutoSpam.pendingDelete
        AutoSpam.pendingDelete = nil
        if m then AutoSpam:DeleteMessage(m) end
    end,
    OnCancel = function()
        AutoSpam.pendingDelete = nil
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function AutoSpam:ConfirmDiscard(fn)
    self.pendingAction = fn
    StaticPopup_Show("AUTOSPAM_DISCARD", self.editMsg and self.editMsg.name or "message")
end

---------------------------------------------------------------------------
-- Resume popup: shown at login when posting was left on at logout
---------------------------------------------------------------------------

-- Popup in the style of the stock dialogs, but with text we can update every frame
local function Dialog(name, leftText, rightText)
    local p = CreateFrame("Frame", name, UIParent)
    p:SetWidth(320)
    p:SetHeight(120)
    p:SetPoint("TOP", UIParent, "TOP", 0, -135)
    p:SetFrameStrata("DIALOG")
    p:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    p:EnableMouse(true)
    p:Hide()

    local text = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOP", p, "TOP", 0, -20)
    text:SetWidth(280)
    p.text = text

    p.button1 = Button(p, leftText, 128, 22)
    p.button1:SetPoint("BOTTOMRIGHT", p, "BOTTOM", -6, 16)
    p.button2 = Button(p, rightText, 128, 22)
    p.button2:SetPoint("BOTTOMLEFT", p, "BOTTOM", 6, 16)

    p.SetBody = function(self, body)
        self.text:SetText(body)
        local h = self.text:GetHeight()
        if h and h > 0 then self:SetHeight(h + 70) end
    end
    return p
end

function AutoSpam:CreateResumePopup()
    local p = Dialog("AutoSpamResumePopup", "Stop posting", "Post now")
    p.stopButton = p.button1
    p.postButton = p.button2
    p.stopButton:SetScript("OnClick", function()
        AutoSpam.resumePopup:Hide()
        if AutoSpam.db.enabled then AutoSpam:TogglePosting() end
    end)
    p.postButton:SetScript("OnClick", function()
        AutoSpam.resumePopup:Hide()
        AutoSpam:PostNow()
    end)
    p:SetScript("OnUpdate", function() AutoSpam:UpdateResumePopup() end)
    self.resumePopup = p
end

-- Dry run reminder after every dry run post, with a countdown to the next one
function AutoSpam:CreateDryRunPopup()
    local p = Dialog("AutoSpamDryRunPopup", "Disable dry run", "Continue dry run")
    p.disableButton = p.button1
    p.continueButton = p.button2
    p.disableButton:SetScript("OnClick", function()
        AutoSpam.dryRunPopup:Hide()
        AutoSpam:SetDryRun(false)
    end)
    p.continueButton:SetScript("OnClick", function()
        AutoSpam.dryRunPopup:Hide()
    end)
    p:SetScript("OnUpdate", function() AutoSpam:UpdateDryRunPopup() end)
    self.dryRunPopup = p
end

function AutoSpam:OnDryRunPost()
    if not self.dryRunPopup then self:CreateDryRunPopup() end
    self:UpdateDryRunPopup()
    self.dryRunPopup:Show()
end

function AutoSpam:UpdateDryRunPopup()
    local p = self.dryRunPopup
    if not p then return end
    if not self.db.dryRun then
        p:Hide()
        return
    end
    local r = self:TimeRemaining()
    local when
    if self.db.enabled and r then
        when = "Next dry run post in |cffffffff" .. FormatTime(math.ceil(r)) .. "|r."
    else
        when = "Posting is stopped, so nothing else will post."
    end
    p:SetBody("That post was only a dry run. It showed up in your chat, but it was never sent and the server didn't see it.\n\n" ..
        when .. "\n\nTurn off dry run and go live?")
end

function AutoSpam:ShowResumePopup()
    if not self.resumePopup then self:CreateResumePopup() end
    local p = self.resumePopup
    self:UpdateResumePopup()
    p:Show()
end

function AutoSpam:UpdateResumePopup()
    local p = self.resumePopup
    if not p then return end
    -- Close on its own once the hold ends (Post now, Stop, or time ran out)
    if not self.resumeHold then
        p:Hide()
        return
    end
    local r = self.resumeDeadline - GetTime()
    if r < 0 then r = 0 end
    p:SetBody("AutoSpam was still posting when you logged out.\n\n" ..
        "It will turn itself off in |cffffffff" .. FormatTime(math.ceil(r)) .. "|r unless you choose Post now.")
end

function AutoSpam:ConfirmDelete(m)
    if not m then return end
    self.pendingDelete = m
    StaticPopup_Show("AUTOSPAM_DELETE", m.name)
end

---------------------------------------------------------------------------
-- Sharing: the Share window (sender) and the offer popup (receiver)
---------------------------------------------------------------------------

function AutoSpam:CreateShareDialog()
    local p = Dialog("AutoSpamShareDialog", "Send to player", "Send to guild")
    p:SetWidth(340)
    p:ClearAllPoints()
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    table.insert(UISpecialFrames, "AutoSpamShareDialog")   -- Escape closes it

    local nl = Label(p, "Player:", "GameFontNormal")
    p.nameLabel = nl
    local nb = InputBox("AutoSpamShareName", p, 150, 12)
    nb:SetPoint("LEFT", nl, "RIGHT", 12, 0)
    nb:SetScript("OnEnterPressed", function() AutoSpam:ShareSendTo(this:GetText()) end)
    nb:SetScript("OnEscapePressed", function() AutoSpam.shareDialog:Hide() end)
    p.nameBox = nb

    -- Three buttons in a row: player, guild, cancel
    p.button1:SetWidth(100)
    p.button2:SetWidth(100)
    p.button1:ClearAllPoints()
    p.button2:ClearAllPoints()
    p.button2:SetPoint("BOTTOM", p, "BOTTOM", 0, 16)
    p.button1:SetPoint("RIGHT", p.button2, "LEFT", -6, 0)
    local cancel = Button(p, "Cancel", 100, 22)
    cancel:SetPoint("LEFT", p.button2, "RIGHT", 6, 0)
    cancel:SetScript("OnClick", function() AutoSpam.shareDialog:Hide() end)
    p.cancelButton = cancel

    p.button1:SetScript("OnClick", function() AutoSpam:ShareSendTo(AutoSpam.shareDialog.nameBox:GetText()) end)
    p.button2:SetScript("OnClick", function() AutoSpam:ShareSendGuild() end)
    p:SetScript("OnHide", function() AutoSpam.shareDialog.nameBox:ClearFocus() end)

    -- Body text on top, name row under it, buttons at the bottom
    p.SetBody = function(self, body)
        self.text:SetText(body)
        local h = self.text:GetHeight() or 30
        self.nameLabel:ClearAllPoints()
        self.nameLabel:SetPoint("TOPLEFT", self, "TOPLEFT", 40, -(20 + h + 14))
        self:SetHeight(h + 112)
    end
    self.shareDialog = p
end

function AutoSpam:OpenShare()
    local m = self.editMsg
    if not m then return end
    if self:EditorIsDirty() then
        Print("Save your changes before sharing, so the message you send is the one you see.", 1, 0.3, 0.3)
        return
    end
    if Trim(m.text) == "" then
        Print("Write some text before sharing.", 1, 0.3, 0.3)
        return
    end
    local inGuild = IsInGuild and IsInGuild()
    if inGuild and GuildRoster then GuildRoster() end   -- fresh online/offline info for the name check
    if not self.shareDialog then self:CreateShareDialog() end
    local p = self.shareDialog
    p.msg = m
    if inGuild then
        p.button2:Enable()
        p:SetBody("Share |cffffd100" .. m.name .. "|r\n\n" ..
            "Send it to any player by name, or offer it to everyone in your guild who has AutoSpam. " ..
            "They get a popup to accept or decline. Auto-invite settings aren't shared.")
    else
        p.button2:Disable()
        p:SetBody("Share |cffffd100" .. m.name .. "|r\n\n" ..
            "Send it to any player by name. They get a popup to accept or decline, " ..
            "as long as they have AutoSpam too. Auto-invite settings aren't shared.")
    end
    p.nameBox:SetText("")
    p:Show()
    p.nameBox:SetFocus()
end

function AutoSpam:ShareSendTo(name)
    local p = self.shareDialog
    if not p or not p.msg then return end
    if self:ShareMessage(p.msg, name) then p:Hide() end
end

function AutoSpam:ShareSendGuild()
    local p = self.shareDialog
    if not p or not p.msg then return end
    if self:ShareMessage(p.msg, nil) then p:Hide() end
end

function AutoSpam:CreateOfferPopup()
    local p = Dialog("AutoSpamOfferPopup", "Accept", "Decline")
    p:ClearAllPoints()
    p:SetPoint("TOP", UIParent, "TOP", 0, -300)   -- clear of the dry run and login popups
    p.button1:SetScript("OnClick", function() AutoSpam:CloseOffer("A") end)
    p.button2:SetScript("OnClick", function() AutoSpam:CloseOffer("D") end)
    p:SetScript("OnUpdate", function() AutoSpam:UpdateOfferPopup() end)
    self.offerPopup = p
end

function AutoSpam:ShowNextOffer()
    if not self.offerPopup then self:CreateOfferPopup() end
    local p = self.offerPopup
    if p:IsShown() and p.offer then return end
    local o = table.remove(self.offers, 1)
    if not o then return end
    p.offer = o
    p.deadline = GetTime() + self.SHARE_ANSWER
    self:UpdateOfferPopup()
    p:Show()
end

function AutoSpam:CloseOffer(answer)
    local p = self.offerPopup
    if not p then return end
    local o = p.offer
    p.offer = nil
    p:Hide()
    self:AnswerOffer(o, answer)
    self:ShowNextOffer()
end

function AutoSpam:UpdateOfferPopup()
    local p = self.offerPopup
    if not p or not p.offer then return end
    local r = p.deadline - GetTime()
    if r <= 0 then
        self:CloseOffer("N")
        return
    end
    local o = p.offer
    p:SetBody("|cffffffff" .. o.from .. "|r wants to share an AutoSpam message with you.\n\n" ..
        "|cffffd100" .. o.name .. "|r  |cff999999[" .. self:ChannelsLabel(o.channels, o.customChannel) .. "]|r\n" ..
        "|cffcccccc" .. Preview(o.text, 160) .. "|r\n\n" ..
        "It's added unchecked, so nothing posts until you turn it on.\n" ..
        "|cff999999Closes in " .. FormatTime(math.ceil(r)) .. "|r")
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------

function AutoSpam:CreateMinimapButton()
    local button = CreateFrame("Button", "AutoSpamMinimapButton", Minimap)
    button:SetWidth(31)
    button:SetHeight(31)
    button:SetFrameStrata("MEDIUM")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:EnableMouse(true)

    -- Same hourglass as the window portrait, animated while posting
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(21)
    icon:SetHeight(21)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -5)
    icon:SetTexture(TEX .. "Hourglass")
    self.minimapIcon = icon

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", 0, 0)

    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then AutoSpam:ToggleWindow() end
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("AutoSpam")
        GameTooltip:AddLine("Left-click: open window", 1, 1, 1)
        GameTooltip:AddLine("Right-click and drag: move button", 1, 1, 1)
        if AutoSpam.db.enabled then
            GameTooltip:AddLine("Posting is on", 0, 1, 0)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnMouseDown", function()
        if arg1 == "RightButton" then
            this.isMoving = true
            this:LockHighlight()
        end
    end)
    button:SetScript("OnMouseUp", function()
        if arg1 == "RightButton" then
            this.isMoving = false
            this:UnlockHighlight()
        end
    end)
    button:SetScript("OnUpdate", function()
        if this.isMoving then
            local mx, my = GetCursorPosition()
            local px, py = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            mx = mx / scale
            my = my / scale
            AutoSpam.db.minimapPos = math.deg(math.atan2(my - py, mx - px))
            AutoSpam:UpdateMinimapButtonPosition()
        end
    end)

    self.minimapButton = button
    self:UpdateMinimapButtonPosition()
end

function AutoSpam:UpdateMinimapButtonPosition()
    local angle = math.rad(self.db.minimapPos or 180)
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

---------------------------------------------------------------------------
-- Main window
---------------------------------------------------------------------------

function AutoSpam:CreateUI()
    self:CreateMinimapButton()

    local f = CreateFrame("Frame", "AutoSpamMainFrame", UIParent)
    self.frame = f
    f:SetWidth(W)
    f:SetHeight(H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:SetScript("OnShow", function() AutoSpam:RefreshUI() end)
    f:Hide()
    table.insert(UISpecialFrames, "AutoSpamMainFrame")

    -- Animated hourglass portrait (sprite sheet, 4x4 frames)
    local pf = CreateFrame("Frame", nil, f)
    pf:SetWidth(72)
    pf:SetHeight(72)
    pf:SetPoint("TOPLEFT", f, "TOPLEFT", -12, 12)
    pf:SetFrameLevel(f:GetFrameLevel() + 5)
    local pt = pf:CreateTexture(nil, "ARTWORK")
    pt:SetAllPoints(pf)
    pt:SetTexture(TEX .. "Hourglass")
    self.portrait = pt
    self.portraitFrame = 0
    self.portraitTimer = 0
    self:SetPortraitFrame(0)

    local title = Label(f, "AutoSpam", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 16, -18)
    local sub = Label(f, "by Fayz", "GameFontHighlightSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -2)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() AutoSpam.frame:Hide() end)

    -- Stats header
    local nextLine = Label(f, "", "GameFontNormal")
    nextLine:SetPoint("TOP", f, "TOP", 18, -54)
    nextLine:SetWidth(W - 100)
    nextLine:SetHeight(14)
    self.statNextMsg = nextLine

    local running = Label(f, "", "GameFontHighlightSmall")
    running:SetPoint("TOPLEFT", f, "TOPLEFT", 66, -74)
    self.statRunning = running
    local sent = Label(f, "", "GameFontHighlightSmall")
    sent:SetPoint("TOP", f, "TOP", 32, -74)
    self.statSent = sent
    local nextIn = Label(f, "", "GameFontHighlightSmall")
    nextIn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -74)
    self.statNextIn = nextIn

    -- Content area that all panels share
    local inset = CreateFrame("Frame", nil, f)
    inset:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -92)
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 44)
    inset:SetBackdrop(BOX_BACKDROP)
    inset:SetBackdropColor(0, 0, 0, 0.5)
    inset:SetBackdropBorderColor(0.4, 0.4, 0.4)
    self.inset = inset

    -- Start / Post now
    local toggle = Button(f, "Start", 100, 24)
    toggle:SetPoint("BOTTOM", f, "BOTTOM", -52, 14)
    toggle:SetScript("OnClick", function() AutoSpam:TogglePosting() end)
    self.toggleButton = toggle

    local postNow = Button(f, "Post now", 90, 24)
    postNow:SetPoint("LEFT", toggle, "RIGHT", 8, 0)
    postNow:SetScript("OnClick", function() AutoSpam:PostNow() end)

    self:CreateScaleGrip(f)
    f:SetScale(self.db.scale or 1)

    -- Panels
    self.panels = {}
    for i = 1, table.getn(TABS) do
        local p = CreateFrame("Frame", nil, inset)
        p:SetAllPoints(inset)
        p:Hide()
        self.panels[TABS[i].key] = p
    end
    self:BuildMessagesPanel(self.panels.messages)
    self:BuildEditorPanel(self.panels.editor)
    self:BuildSettingsPanel(self.panels.settings)
    self:BuildHelpPanel(self.panels.help)

    -- Spellbook-style side tabs
    self.tabs = {}
    for i = 1, table.getn(TABS) do
        local info = TABS[i]
        local t = CreateFrame("CheckButton", "AutoSpamSideTab" .. i, f)
        t:SetWidth(32)
        t:SetHeight(32)
        t:SetPoint("TOPLEFT", f, "TOPRIGHT", -4, -48 - (i - 1) * 48)
        local bg = t:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
        bg:SetWidth(64)
        bg:SetHeight(64)
        bg:SetPoint("TOPLEFT", t, "TOPLEFT", -3, 11)
        t:SetNormalTexture(info.icon)
        t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        AddBlend(t:GetHighlightTexture())
        t:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
        AddBlend(t:GetCheckedTexture())
        t.key = info.key
        t.tip = info.tip
        t:SetScript("OnClick", function()
            AutoSpam:RequestPanel(this.key)
            AutoSpam:UpdateTabs()
        end)
        t:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.tip)
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.tabs[i] = t
    end

    self:EditorLoad(nil)
    self:ShowPanel("messages")
end

---------------------------------------------------------------------------
-- Scale grip (bottom-right corner). Drag to scale, right-click to reset.
---------------------------------------------------------------------------

function AutoSpam:SetWindowScale(s, absLeft, absTop)
    local f = self.frame
    if s < MIN_SCALE then s = MIN_SCALE end
    if s > MAX_SCALE then s = MAX_SCALE end
    s = math.floor(s * 100 + 0.5) / 100
    if not absLeft then
        local eff = f:GetEffectiveScale()
        absLeft = f:GetLeft() * eff
        absTop = f:GetTop() * eff
    end
    f:SetScale(s)
    -- Keep the top-left corner where it was on screen
    local eff = f:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", absLeft / eff, absTop / eff)
    self.db.scale = s
end

function AutoSpam:CreateScaleGrip(f)
    local g = CreateFrame("Button", nil, f)
    g:SetWidth(16)
    g:SetHeight(16)
    g:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    g:SetFrameLevel(f:GetFrameLevel() + 10)
    g:EnableMouse(true)
    g:SetNormalTexture(TEX .. "SizeGrabber-Up")
    g:SetPushedTexture(TEX .. "SizeGrabber-Down")
    g:SetHighlightTexture(TEX .. "SizeGrabber-Highlight")

    g:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag to resize")
        GameTooltip:AddLine("Right-click to reset", 1, 1, 1)
        GameTooltip:Show()
    end)
    g:SetScript("OnLeave", function()
        if not this.sizing then GameTooltip:Hide() end
    end)
    g:SetScript("OnMouseDown", function()
        local frame = AutoSpam.frame
        if arg1 == "LeftButton" then
            local eff = frame:GetEffectiveScale()
            this.left = frame:GetLeft() * eff
            this.top = frame:GetTop() * eff
            this.sizing = true
            this:SetButtonState("PUSHED", 1)   -- stay pressed for the whole drag
        elseif arg1 == "RightButton" then
            AutoSpam:SetWindowScale(1)
        end
    end)
    g:SetScript("OnMouseUp", function()
        if this.sizing then
            this.sizing = false
            this:SetButtonState("NORMAL")
            GameTooltip:Hide()
        end
    end)
    g:SetScript("OnUpdate", function()
        if not this.sizing then return end
        local cx, cy = GetCursorPosition()
        -- Size the window so its bottom-right corner follows the cursor
        local wantEff = ((cx - this.left) / W + (this.top - cy) / H) / 2
        AutoSpam:SetWindowScale(wantEff / UIParent:GetEffectiveScale(), this.left, this.top)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Scale: " .. math.floor(AutoSpam.db.scale * 100 + 0.5) .. "%")
        GameTooltip:Show()
    end)
    self.scaleGrip = g
end

function AutoSpam:ToggleWindow()
    if not self.frame then return end
    if self.frame:IsVisible() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

function AutoSpam:SetPortraitFrame(n)
    local col = math.mod(n, PORTRAIT_GRID)
    local row = math.floor(n / PORTRAIT_GRID)
    local s = 1 / PORTRAIT_GRID
    if self.portrait then
        self.portrait:SetTexCoord(col * s, (col + 1) * s, row * s, (row + 1) * s)
    end
    if self.minimapIcon then
        -- Trim the art's own gold rim so it sits inside the minimap border
        local trim = s * 0.07
        self.minimapIcon:SetTexCoord(col * s + trim, (col + 1) * s - trim, row * s + trim, (row + 1) * s - trim)
    end
end

function AutoSpam:UpdatePortrait()
    if not self.portrait then return end
    if self.db.enabled then
        self.portrait:SetVertexColor(1, 1, 1)
    else
        self.portraitFrame = 0
        self:SetPortraitFrame(0)
        self.portrait:SetVertexColor(0.55, 0.55, 0.55)
    end
end

---------------------------------------------------------------------------
-- Panel switching
---------------------------------------------------------------------------

function AutoSpam:ShowPanel(key)
    for k, p in pairs(self.panels) do
        if k == key then p:Show() else p:Hide() end
    end
    self.activePanel = key
    self:UpdateTabs()
    if key == "messages" then
        self:UpdateList()
    elseif key == "editor" then
        self:EditorChanged()
    elseif key == "settings" then
        self:SettingsLoad()
    end
end

function AutoSpam:RequestPanel(key)
    if key == self.activePanel then return end
    if self.activePanel == "editor" and self:EditorIsDirty() then
        self:ConfirmDiscard(function()
            AutoSpam:EditorLoad(AutoSpam.editMsg)
            AutoSpam:ShowPanel(key)
        end)
        return
    end
    self:ShowPanel(key)
end

function AutoSpam:UpdateTabs()
    if not self.tabs then return end
    for i = 1, table.getn(self.tabs) do
        local t = self.tabs[i]
        if t.key == self.activePanel then t:SetChecked(1) else t:SetChecked(nil) end
    end
end

---------------------------------------------------------------------------
-- Messages panel
---------------------------------------------------------------------------

function AutoSpam:BuildMessagesPanel(p)
    local lbl = Label(p, "New message:", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -14)

    local nameBox = InputBox("AutoSpamNewNameBox", p, 130, 40)
    nameBox:SetPoint("LEFT", lbl, "RIGHT", 12, 0)

    local add = Button(p, "Add", 56, 22)
    add:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)

    local function DoAdd()
        local m = AutoSpam:AddMessage(nameBox:GetText())
        if m then
            nameBox:SetText("")
            nameBox:ClearFocus()
            AutoSpam:OpenInEditor(m)
        end
    end
    add:SetScript("OnClick", DoAdd)
    nameBox:SetScript("OnEnterPressed", DoAdd)

    local sf = CreateFrame("ScrollFrame", "AutoSpamListScroll", p, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -40)
    sf:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -28, 8)
    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(296)
    child:SetHeight(10)
    sf:SetScrollChild(child)
    self.listScroll = sf
    self.listChild = child
    self.rows = {}

    local empty = Label(p, "No messages yet.\nType a name above and click Add.", "GameFontDisable")
    empty:SetPoint("CENTER", p, "CENTER", 0, -10)
    self.listEmpty = empty
end

function AutoSpam:GetRow(i)
    if self.rows[i] then return self.rows[i] end

    local row = CreateFrame("Button", nil, self.listChild)
    row:SetWidth(294)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", self.listChild, "TOPLEFT", 0, -(i - 1) * (ROW_H + ROW_GAP))
    row:SetBackdrop(ROW_BACKDROP)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    AddBlend(row:GetHighlightTexture())
    row:SetScript("OnClick", function()
        if this.msg then AutoSpam:OpenInEditor(this.msg) end
    end)

    local cb = CheckBox(row, nil, 22)
    cb:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -2)
    cb:SetScript("OnClick", function()
        local m = this:GetParent().msg
        if m then AutoSpam:SetMessageEnabled(m, this:GetChecked() and true or false) end
    end)
    row.check = cb

    local line1 = Label(row, "", "GameFontNormal")
    line1:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -5)
    line1:SetWidth(196)
    line1:SetHeight(14)
    line1:SetJustifyH("LEFT")
    row.line1 = line1

    local line2 = Label(row, "", "GameFontHighlightSmall")
    line2:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -1)
    line2:SetWidth(196)
    line2:SetHeight(12)
    line2:SetJustifyH("LEFT")
    line2:SetTextColor(0.65, 0.65, 0.65)
    row.line2 = line2

    local del = CloseStyleButton(row, 24)
    del:SetPoint("RIGHT", row, "RIGHT", -1, 0)
    del:SetScript("OnClick", function() AutoSpam:ConfirmDelete(this:GetParent().msg) end)
    del:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Delete")
        GameTooltip:Show()
    end)
    del:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local down = ArrowButton(row, "Down")
    down:SetPoint("RIGHT", del, "LEFT", 1, 0)
    down:SetScript("OnClick", function() AutoSpam:MoveMessage(this:GetParent().index, 1) end)
    row.down = down

    local up = ArrowButton(row, "Up")
    up:SetPoint("RIGHT", down, "LEFT", 0, 0)
    up:SetScript("OnClick", function() AutoSpam:MoveMessage(this:GetParent().index, -1) end)
    row.up = up

    self.rows[i] = row
    return row
end

function AutoSpam:UpdateList()
    if not self.listChild then return end
    local msgs = self.db.messages
    local n = table.getn(msgs)

    for i = 1, n do
        local m = msgs[i]
        local row = self:GetRow(i)
        row.msg = m
        row.index = i
        row.check:SetChecked(m.enabled and 1 or nil)

        local head = "|cff999999[" .. self:ChannelsLabel(m.channels, m.customChannel) .. "]|r " .. m.name
        if (m.weight or 1) > 1 then head = head .. " |cffaaaaaax" .. m.weight .. "|r" end
        if m.autoInvite then head = head .. " |cff33ff33(inv)|r" end
        row.line1:SetText(head)
        row.line2:SetText(Preview(m.text, 40))

        if m == self.editMsg then
            row:SetBackdropColor(0.35, 0.25, 0, 0.7)
            row:SetBackdropBorderColor(1, 0.82, 0, 0.9)
        else
            row:SetBackdropColor(0, 0, 0, 0.6)
            row:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
        end

        if i == 1 then row.up:Disable() else row.up:Enable() end
        if i == n then row.down:Disable() else row.down:Enable() end
        row:Show()
    end

    for i = n + 1, table.getn(self.rows) do
        self.rows[i].msg = nil
        self.rows[i]:Hide()
    end

    self.listChild:SetHeight(math.max(10, n * (ROW_H + ROW_GAP)))
    self.listScroll:UpdateScrollChildRect()
    if n == 0 then self.listEmpty:Show() else self.listEmpty:Hide() end
end

---------------------------------------------------------------------------
-- Editor panel (explicit save, works on a draft copy)
---------------------------------------------------------------------------

function AutoSpam:BuildEditorPanel(p)
    local none = Label(p, "Pick a message on the Messages tab,\nor add a new one there.", "GameFontDisable")
    none:SetPoint("CENTER", p, "CENTER", 0, 0)
    self.editorNone = none

    local c = CreateFrame("Frame", nil, p)
    c:SetAllPoints(p)
    self.editorBody = c

    -- Name
    local nl = Label(c, "Name:", "GameFontNormal")
    nl:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -14)
    local nameBox = InputBox("AutoSpamEditName", c, 160, 40)
    nameBox:SetPoint("LEFT", nl, "RIGHT", 12, 0)
    nameBox:SetScript("OnTextChanged", function()
        if AutoSpam.draft then
            AutoSpam.draft.name = this:GetText()
            AutoSpam:EditorChanged()
        end
    end)
    self.edName = nameBox

    local dirty = Label(c, "Unsaved", "GameFontNormalSmall", 1, 0.3, 0.3)
    dirty:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -18)
    self.edDirty = dirty

    -- Message text
    local tl = Label(c, "Message text:", "GameFontNormal")
    tl:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -42)
    local count = Label(c, "0 / " .. AutoSpam.MAX_LEN, "GameFontNormalSmall")
    count:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -44)
    self.edCount = count

    local box = CreateFrame("Frame", nil, c)
    box:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -58)
    box:SetWidth(312)
    box:SetHeight(86)
    box:SetBackdrop(BOX_BACKDROP)
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(0.4, 0.4, 0.4)
    box:EnableMouse(true)

    -- Scrolls when the message is longer than the box. It also clips the edit box,
    -- so a selection highlight can't spill outside the box.
    local clip = CreateFrame("ScrollFrame", "AutoSpamEditTextClip", box, "UIPanelScrollFrameTemplate")
    clip:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
    clip:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -28, 8)
    self.edTextScroll = clip

    -- Hidden copy of the text in the same font and width, to measure how tall it wraps
    local measure = box:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
    measure:SetWidth(266)
    measure:SetJustifyH("LEFT")
    measure:Hide()
    self.edTextMeasure = measure

    local textBox = CreateFrame("EditBox", "AutoSpamEditText", clip)
    textBox:SetWidth(270)
    textBox:SetHeight(70)
    textBox:SetMultiLine(true)
    textBox:SetAutoFocus(false)
    textBox:SetMaxLetters(AutoSpam.MAX_LEN)
    textBox:SetFontObject(GameFontHighlight)
    textBox:EnableMouse(true)
    textBox:EnableKeyboard(true)
    textBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    textBox:SetScript("OnEditFocusGained", function()
        AutoSpam.linkFocus = true
        AutoSpam.linkTarget = this
    end)
    textBox:SetScript("OnEditFocusLost", function()
        AutoSpam.linkFocus = false
    end)
    textBox:SetScript("OnTextChanged", function()
        local t = this:GetText()
        if string.find(t, "\n") then
            -- Chat can't carry line breaks; the next OnTextChanged picks up the cleaned text
            local cleaned = string.gsub(t, "\n", " ")
            this:SetText(cleaned)
            return
        end
        if AutoSpam.draft then
            AutoSpam.draft.text = t
            AutoSpam:EditorChanged()
        end
        AutoSpam:FitTextBox()
    end)
    -- Keep the line you're typing on in view
    textBox:SetScript("OnCursorChanged", function()
        AutoSpam.cursorTop = -(arg2 or 0)
        AutoSpam.cursorHeight = arg4 or 14
        AutoSpam:ScrollToCursor()
    end)
    clip:SetScrollChild(textBox)
    box:SetScript("OnMouseDown", function() textBox:SetFocus() end)
    self.edText = textBox

    local tip = Label(c, "Shift-click items to link them. Hover here for placeholders.", "GameFontDisableSmall")
    tip:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 4, -2)
    tip:SetJustifyH("LEFT")

    -- Invisible hover area over the tip that lists placeholders and what they'd fill in right now
    local tipHover = CreateFrame("Frame", nil, c)
    tipHover:SetPoint("TOPLEFT", tip, "TOPLEFT", -2, 2)
    tipHover:SetWidth(310)
    tipHover:SetHeight(14)
    tipHover:EnableMouse(true)
    tipHover:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText("Placeholders")
        GameTooltip:AddLine("Type these into your message. They're filled in each time it posts.", 1, 1, 1, 1)
        GameTooltip:AddLine(" ")
        local list = AutoSpam.PLACEHOLDERS
        for i = 1, table.getn(list) do
            local now = AutoSpam:PlaceholderValue(list[i].key) or ""
            if now == "" then now = "(none)" end
            GameTooltip:AddDoubleLine("{" .. list[i].key .. "}", list[i].desc .. ": |cffffffff" .. now .. "|r", 1, 0.82, 0, 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(" ")
        local example = AutoSpam:ConvertToUTC("Sunday 1300") or "(no PC clock)"
        GameTooltip:AddDoubleLine("{UTC Sunday 1300}", "Your time to UTC: |cffffffff" .. example .. "|r", 1, 0.82, 0, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    tipHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Channel
    local cl = Label(c, "Channel:", "GameFontNormal")
    cl:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -170)

    local dd = CreateFrame("Frame", "AutoSpamChannelDropDown", c, "UIDropDownMenuTemplate")
    dd:SetPoint("LEFT", cl, "RIGHT", -8, -3)
    self.edChannel = dd
    self:BuildChannelList(c, dd)

    local ccl = Label(c, "Channel name:", "GameFontNormalSmall")
    ccl:SetPoint("TOPLEFT", c, "TOPLEFT", 24, -200)
    self.edCustomLabel = ccl
    local custom = InputBox("AutoSpamEditCustom", c, 150, 50)
    custom:SetPoint("LEFT", ccl, "RIGHT", 12, 0)
    custom:SetScript("OnTextChanged", function()
        if AutoSpam.draft then
            AutoSpam.draft.customChannel = this:GetText()
            AutoSpam:EditorChanged()
        end
    end)
    self.edCustom = custom

    -- Weight
    local wl = Label(c, "Weight: x1", "GameFontNormal")
    wl:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -222)
    self.edWeightLabel = wl
    local ws = Slider("AutoSpamEditWeight", c, 290, 1, 10, 1, "1", "10")
    ws:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -240)
    ws:SetScript("OnValueChanged", function()
        local v = math.floor(this:GetValue() + 0.5)
        AutoSpam.edWeightLabel:SetText("Weight: x" .. v)
        if AutoSpam.draft then
            AutoSpam.draft.weight = v
            AutoSpam:EditorChanged()
        end
    end)
    self.edWeight = ws

    -- Auto-invite, all settings belong to this message
    local inv = CheckBox(c, "Auto-invite on whisper", 22)
    inv:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -272)
    inv:SetScript("OnClick", function()
        if AutoSpam.draft then
            AutoSpam.draft.autoInvite = this:GetChecked() and true or false
            AutoSpam:EditorUpdateInviteRow()
            AutoSpam:EditorChanged()
        end
    end)
    self.edInvite = inv

    local conv = CheckBox(c, "Convert to raid", 22)
    conv:SetPoint("TOPLEFT", c, "TOPLEFT", 190, -272)
    conv:SetScript("OnClick", function()
        if AutoSpam.draft then
            AutoSpam.draft.inviteConvert = this:GetChecked() and true or false
            AutoSpam:EditorChanged()
        end
    end)
    conv:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Convert to raid")
        GameTooltip:AddLine("When your party is full, turn it into a raid so invites keep going out.", 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    conv:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.edConvert = conv

    local kl = Label(c, "Keywords:", "GameFontNormalSmall")
    kl:SetPoint("TOPLEFT", c, "TOPLEFT", 36, -302)
    self.edKeywordsLabel = kl
    local kw = InputBox("AutoSpamEditKeywords", c, 200, 120)
    kw:SetPoint("LEFT", kl, "RIGHT", 12, 0)
    kw:SetScript("OnTextChanged", function()
        if AutoSpam.draft then
            AutoSpam.draft.inviteKeywords = this:GetText()
            AutoSpam:EditorChanged()
        end
    end)
    kw:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Keywords")
        GameTooltip:AddLine("Comma separated. The whole whisper has to match one, so \"inv\" works but \"can you inv me\" doesn't.", 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    kw:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.edKeywords = kw

    local invNote = Label(c, "Auto-invite settings are per message.", "GameFontDisableSmall")
    invNote:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -326)

    local save = Button(c, "Save", 90, 22)
    save:SetPoint("BOTTOM", c, "BOTTOM", -100, 10)
    save:SetScript("OnClick", function() AutoSpam:EditorSave() end)

    local revert = Button(c, "Revert", 90, 22)
    revert:SetPoint("BOTTOM", c, "BOTTOM", 0, 10)
    revert:SetScript("OnClick", function()
        if AutoSpam.editMsg then AutoSpam:EditorLoad(AutoSpam.editMsg) end
    end)

    local share = Button(c, "Share", 90, 22)
    share:SetPoint("BOTTOM", c, "BOTTOM", 100, 10)
    share:SetScript("OnClick", function() AutoSpam:OpenShare() end)
    share:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Share")
        GameTooltip:AddLine("Send this message to a player by name, or offer it to your whole guild. They need AutoSpam too.", 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    share:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Channel choices. The stock dropdown list lives outside this window, so it ignores
-- the window's scale and looks out of place; this list is part of the window instead.
-- The dropdown frame is kept only for its look, and its arrow button opens this list.
function AutoSpam:BuildChannelList(parent, dd)
    local ROW = 16
    local n = table.getn(self.CHANNELS)
    local list = CreateFrame("Frame", "AutoSpamChannelList", parent)
    list:SetWidth(150)
    list:SetHeight(n * ROW + 20)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    list:SetBackdropColor(0, 0, 0, 0.95)
    list:SetBackdropBorderColor(0.6, 0.6, 0.6)
    list:EnableMouse(true)
    list:Hide()

    local arrow = getglobal("AutoSpamChannelDropDownButton")
    list:SetPoint("TOPRIGHT", arrow or dd, "BOTTOMRIGHT", 0, -2)

    local function Hover() AutoSpam.channelList.hover = true end
    local function Unhover() AutoSpam.channelList.hover = false end

    list.rows = {}
    for i = 1, n do
        local ch = self.CHANNELS[i]
        local r = CreateFrame("Button", nil, list)
        r:SetWidth(134)
        r:SetHeight(ROW)
        r:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -10 - (i - 1) * ROW)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        AddBlend(r:GetHighlightTexture())
        local check = r:CreateTexture(nil, "ARTWORK")
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check:SetWidth(16)
        check:SetHeight(16)
        check:SetPoint("LEFT", r, "LEFT", 0, 0)
        local label = Label(r, ch.text, "GameFontHighlightSmall")
        label:SetPoint("LEFT", r, "LEFT", 18, 0)
        r.value = ch.value
        r.check = check
        r:SetScript("OnClick", function()
            AutoSpam:EditorToggleChannel(this.value)   -- list stays open so several can be picked
        end)
        r:SetScript("OnEnter", Hover)
        r:SetScript("OnLeave", Unhover)
        list.rows[i] = r
    end

    list:SetScript("OnEnter", Hover)
    list:SetScript("OnLeave", Unhover)
    list:SetScript("OnShow", function()
        this.idle = 0
        AutoSpam:UpdateChannelChecks()
    end)
    -- Close after the mouse has been away for 2 seconds, like the stock dropdown
    list:SetScript("OnUpdate", function()
        if this.hover then
            this.idle = 0
        else
            this.idle = (this.idle or 0) + (arg1 or 0)
            if this.idle > 2 then this:Hide() end
        end
    end)

    if arrow then
        arrow:SetScript("OnClick", function()
            local l = AutoSpam.channelList
            if l:IsShown() then l:Hide() else l:Show() end
        end)
        arrow:SetScript("OnEnter", Hover)
        arrow:SetScript("OnLeave", Unhover)
    end
    parent:SetScript("OnHide", function() AutoSpam.channelList:Hide() end)
    self.channelList = list
end

-- Grow the edit box to fit its text so the scroll frame knows how far it can scroll
function AutoSpam:FitTextBox()
    local tb, sf, fs = self.edText, self.edTextScroll, self.edTextMeasure
    if not tb or not sf or not fs then return end
    fs:SetText(tb:GetText() or "")
    local need = (fs:GetHeight() or 0) + 8
    local view = sf:GetHeight() or 70
    local cursorBottom = (self.cursorTop or 0) + (self.cursorHeight or 0) + 4
    if cursorBottom > need then need = cursorBottom end
    if need < view then need = view end
    tb:SetHeight(need)
    sf:UpdateScrollChildRect()
end

function AutoSpam:ScrollToCursor()
    local sf = self.edTextScroll
    if not sf then return end
    self:FitTextBox()
    local top = self.cursorTop or 0
    local bottom = top + (self.cursorHeight or 14)
    local cur = sf:GetVerticalScroll() or 0
    local view = sf:GetHeight() or 70
    local want = cur
    if top < cur then
        want = top
    elseif bottom > cur + view then
        want = bottom - view
    end
    if want ~= cur then
        local bar = getglobal("AutoSpamEditTextClipScrollBar")
        if bar then bar:SetValue(want) else sf:SetVerticalScroll(want) end
    end
end

function AutoSpam:OpenInEditor(m)
    if not m then return end
    if self.editMsg and m ~= self.editMsg and self:EditorIsDirty() then
        self:ConfirmDiscard(function()
            AutoSpam:EditorLoad(m)
            AutoSpam:ShowPanel("editor")
        end)
        return
    end
    if m ~= self.editMsg then self:EditorLoad(m) end
    self:ShowPanel("editor")
end

function AutoSpam:OnMessageDeleted(m)
    if m == self.editMsg then self:EditorLoad(nil) end
end

function AutoSpam:EditorLoad(m)
    self.editMsg = m
    if not m then
        self.draft = nil
        if self.editorBody then
            self.editorBody:Hide()
            self.editorNone:Show()
        end
        self:UpdateList()
        return
    end

    self.draft = {
        name = m.name,
        text = m.text or "",
        channels = CopySet(m.channels),
        customChannel = m.customChannel or "",
        weight = m.weight or 1,
        autoInvite = m.autoInvite and true or false,
        inviteKeywords = m.inviteKeywords or "",
        inviteConvert = m.inviteConvert and true or false,
    }
    if not self.editorBody then return end
    self.editorBody:Show()
    self.editorNone:Hide()

    local d = self.draft
    self.edName:SetText(d.name)
    self.edText:SetText(d.text)
    self.cursorTop, self.cursorHeight = 0, 14
    self:FitTextBox()
    local bar = getglobal("AutoSpamEditTextClipScrollBar")
    if bar then bar:SetValue(0) end      -- start each message at the top
    self.edCustom:SetText(d.customChannel)
    self.edWeight:SetValue(d.weight)
    self.edWeightLabel:SetText("Weight: x" .. d.weight)
    self.edInvite:SetChecked(d.autoInvite and 1 or nil)
    self.edConvert:SetChecked(d.inviteConvert and 1 or nil)
    self.edKeywords:SetText(d.inviteKeywords)
    self:EditorUpdateInviteRow()
    self:EditorRefreshChannels()
    self:UpdateList()
end

function AutoSpam:EditorToggleChannel(value)
    if not self.draft then return end
    if self.draft.channels[value] then
        self.draft.channels[value] = nil
    else
        self.draft.channels[value] = true
    end
    self:EditorRefreshChannels()
end

function AutoSpam:UpdateChannelChecks()
    local list = self.channelList
    if not list or not self.draft then return end
    for i = 1, table.getn(list.rows) do
        if self.draft.channels[list.rows[i].value] then list.rows[i].check:Show() else list.rows[i].check:Hide() end
    end
end

function AutoSpam:EditorRefreshChannels()
    if not self.draft then return end
    local picked = self:CheckedChannels(self.draft.channels)
    local n = table.getn(picked)
    local label
    if n == 0 then
        label = "|cffff5050None|r"
    elseif n == 1 then
        label = self:ChannelLabel(picked[1], "")
        if picked[1] == "CHANNEL" then label = "Custom Channel" end
    else
        label = self:ChannelsLabel(self.draft.channels, "")
        if string.len(label) > 18 then label = n .. " channels" end
    end
    local text = getglobal("AutoSpamChannelDropDownText")
    if not text then
        -- Some clients don't create the template's label; make our own
        text = self.edChannel:CreateFontString("AutoSpamChannelDropDownText", "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("RIGHT", self.edChannel, "RIGHT", -43, 2)
        text:SetJustifyH("RIGHT")
    end
    text:SetText(label)
    self:UpdateChannelChecks()
    if self.draft.channels["CHANNEL"] then
        self.edCustomLabel:Show()
        self.edCustom:Show()
    else
        self.edCustomLabel:Hide()
        self.edCustom:Hide()
    end
    self:EditorChanged()
end

function AutoSpam:EditorUpdateInviteRow()
    if not self.draft then return end
    if self.draft.autoInvite then
        self.edConvert:Show()
        self.edKeywordsLabel:Show()
        self.edKeywords:Show()
    else
        self.edConvert:Hide()
        self.edKeywordsLabel:Hide()
        self.edKeywords:Hide()
    end
end

function AutoSpam:EditorIsDirty()
    local m, d = self.editMsg, self.draft
    if not m or not d then return false end
    if d.name ~= m.name then return true end
    if d.text ~= (m.text or "") then return true end
    if not SameSet(d.channels, m.channels) then return true end
    if d.customChannel ~= (m.customChannel or "") then return true end
    if d.weight ~= (m.weight or 1) then return true end
    if (d.autoInvite and true or false) ~= (m.autoInvite and true or false) then return true end
    if d.inviteKeywords ~= (m.inviteKeywords or "") then return true end
    if (d.inviteConvert and true or false) ~= (m.inviteConvert and true or false) then return true end
    return false
end

function AutoSpam:EditorChanged()
    if not self.draft or not self.edCount then return end
    local len = string.len(self.draft.text or "")
    self.edCount:SetText(len .. " / " .. self.MAX_LEN)
    if len >= self.MAX_LEN - 15 then
        self.edCount:SetTextColor(1, 0.5, 0)
    else
        self.edCount:SetTextColor(0, 1, 0)
    end
    if self:EditorIsDirty() then self.edDirty:Show() else self.edDirty:Hide() end
end

function AutoSpam:EditorSave()
    local m, d = self.editMsg, self.draft
    if not m or not d then return false end

    local name = Trim(d.name)
    if name == "" then
        Print("The name can't be empty.", 1, 0.3, 0.3)
        return false
    end
    local other = self:FindByName(name)
    if other and other ~= m then
        Print("Another message is already named '" .. name .. "'.", 1, 0.3, 0.3)
        return false
    end
    local picked = self:CheckedChannels(d.channels)
    if table.getn(picked) == 0 then
        Print("Pick at least one channel.", 1, 0.3, 0.3)
        return false
    end
    if d.channels["CHANNEL"] and Trim(d.customChannel) == "" then
        Print("Enter a channel name, or uncheck Custom Channel.", 1, 0.3, 0.3)
        return false
    end
    if d.autoInvite and Trim(d.inviteKeywords) == "" then
        Print("Auto-invite needs at least one keyword.", 1, 0.3, 0.3)
        return false
    end

    m.name = name
    m.text = Trim(d.text)
    m.channels = CopySet(d.channels)
    m.channel = picked[1]   -- kept so older AutoSpam versions can still read the message
    m.customChannel = Trim(d.customChannel)
    m.weight = d.weight
    m.autoInvite = d.autoInvite and true or false
    m.inviteKeywords = Trim(d.inviteKeywords)
    m.inviteConvert = d.inviteConvert and true or false

    self:EditorLoad(m)
    self:ValidateNext()
    Print("Saved '" .. name .. "'.", 0, 1, 0)
    self:RefreshUI()
    return true
end

---------------------------------------------------------------------------
-- Settings panel (settings apply immediately)
---------------------------------------------------------------------------

function AutoSpam:BuildSettingsPanel(p)
    local il = Label(p, "", "GameFontNormal")
    il:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -14)
    self.setIntervalLabel = il

    local is = Slider("AutoSpamIntervalSlider", p, 290, 60, 600, 30, "1 min", "10 min")
    is:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -34)
    is:SetScript("OnValueChanged", function()
        local v = math.floor(this:GetValue() + 0.5)
        AutoSpam.db.interval = v
        AutoSpam.setIntervalLabel:SetText("Post every: |cffffffff" .. FormatTime(v) .. "|r")
    end)
    self.setInterval = is

    local dry = CheckBox(p, "Dry run (print to your chat, send nothing)", 22)
    dry:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -66)
    dry:SetScript("OnClick", function()
        AutoSpam:SetDryRun(this:GetChecked() and true or false)
    end)
    self.setDry = dry

    local dbg = CheckBox(p, "Debug messages", 22)
    dbg:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 10, 10)
    dbg:SetScript("OnClick", function()
        AutoSpam.db.debugMode = this:GetChecked() and true or false
    end)
    self.setDebug = dbg
end

function AutoSpam:SettingsLoad()
    if not self.setInterval then return end
    local db = self.db
    self.setInterval:SetValue(db.interval)
    self.setIntervalLabel:SetText("Post every: |cffffffff" .. FormatTime(db.interval) .. "|r")
    self.setDry:SetChecked(db.dryRun and 1 or nil)
    self.setDebug:SetChecked(db.debugMode and 1 or nil)
end

---------------------------------------------------------------------------
-- Help panel
---------------------------------------------------------------------------

local HELP_TEXT =
    "|cffffd100Getting started|r\n" ..
    "1. On the Messages tab, type a name and click Add.\n" ..
    "2. The Editor opens. Write your text, pick a channel and a weight, then click Save.\n" ..
    "3. Check the box next to the message to enable it.\n" ..
    "4. Click Start. The first post goes out right away.\n\n" ..
    "|cffffd100Saving|r\n" ..
    "Edits only stick when you click Save. If you leave the Editor or pick another message with unsaved changes, you'll be asked whether to discard them. Revert puts the message back the way it was.\n\n" ..
    "|cffffd100Weight|r\n" ..
    "Higher weight posts more often. A weight 5 message posts about five times as often as a weight 1 message. The header shows which message is up next.\n\n" ..
    "|cffffd100Timer|r\n" ..
    "Set the interval on the Settings tab (1 to 10 minutes). Stopping doesn't reset the timer. If it runs out while stopped, the next Start posts right away. Post now sends immediately and restarts the timer.\n\n" ..
    "|cffffd100Logging out while posting|r\n" ..
    "If you log out without stopping, nothing posts when you log back in. A popup counts down 2 minutes: choose Post now to keep going, or Stop posting. If you don't answer, AutoSpam turns itself off.\n\n" ..
    "|cffffd100AFK|r\n" ..
    "Posts keep going out while you're AFK. While posting is on, AutoSpam also stops the 30 minute idle logout and hides the game's repeating \"You have been inactive\" message. Logging out yourself still works.\n\nIf a World or custom channel post doesn't show up in chat within a few seconds, AutoSpam sends it once more and tells you if it still didn't make it.\n\n" ..
    "|cffffd100Channels|r\n" ..
    "Open the channel list and check as many channels as you like. Click again to uncheck. Each post goes to every checked channel, one second apart.\n\n" ..
    "|cffffd100Placeholders|r\n" ..
    "Type {GROUP}, {ZONE}, {TIME}, {NAME} or {GUILD} into a message and it's filled in each time it posts. For example \"LFM MC {GROUP}/40\" posts as \"LFM MC 23/40\". Hover the line under the message box to see them all.\n\n" ..
    "|cffffd100UTC time|r\n" ..
    "Type {UTC Sunday 1300} using your own local time and it posts in UTC, like \"Sunday 1800 UTC\", so everyone can convert it to their own clock. The day is optional, and 1:00 PM style works too.\n" ..
    "It's worked out fresh each time the message posts, for the next time that day and time comes around. Once it passes, posts point to the following week, and if your clocks change before then the UTC time changes to match.\n\n" ..
    "|cffffd100Item links|r\n" ..
    "Click into the message text, then shift-click an item in your bags, on your character, or a link in chat.\n\n" ..
    "|cffffd100Auto-invite|r\n" ..
    "Each message has its own auto-invite switch, keywords and convert-to-raid option in the Editor. Turn it on for your raid LFM and leave it off for guild recruiting. A whisper that exactly matches one of that message's keywords gets an invite, but only while the message is enabled and posting is on.\n\n" ..
    "|cffffd100Sharing|r\n" ..
    "Open a message in the Editor and click Share. Type a player's name and click Send to player, or click Send to guild to offer it to everyone in your guild who has AutoSpam. They get a popup to accept or decline, and you see their answer in chat. Players outside your guild get it by whisper, which AutoSpam hides from chat. If they don't have AutoSpam, they get one whisper saying you tried to share a message. Shared messages arrive unchecked, and auto-invite settings aren't shared.\n\n" ..
    "|cffffd100Dry run|r\n" ..
    "Turn on dry run in Settings to see what would be posted, printed only to your own chat. After each dry run post a popup reminds you, counts down to the next one, and has a button to go live.\n\n" ..
    "|cffffd100Commands|r\n" ..
    "/autospam opens this window. Add start, stop, now, or dryrun.\n\n" ..
    "|cffffd100Questions or bugs?|r\n" ..
    "github.com/TheRealFayz/AutoSpam\n"

function AutoSpam:BuildHelpPanel(p)
    local sf = CreateFrame("ScrollFrame", "AutoSpamHelpScroll", p, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -10)
    sf:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -30, 10)
    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(286)
    child:SetHeight(800)
    sf:SetScrollChild(child)

    local fs = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -2)
    fs:SetWidth(280)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetText(HELP_TEXT)
    local h = fs:GetHeight()
    if h and h > 0 then child:SetHeight(h + 10) end
    sf:UpdateScrollChildRect()
end

---------------------------------------------------------------------------
-- Refresh and tick
---------------------------------------------------------------------------

function AutoSpam:UpdateStats()
    if not self.statNextMsg then return end
    local db = self.db

    local prefix = db.dryRun and "|cff66ccff[Dry run]|r " or ""
    local m = self.nextMsg
    if m then
        self.statNextMsg:SetText(prefix .. "Next: |cff999999[" .. self:ChannelsLabel(m.channels, m.customChannel) .. "]|r " .. m.name)
    else
        self.statNextMsg:SetText(prefix .. "|cff888888Nothing to post yet|r")
    end

    if self.resumeHold then
        self.statRunning:SetText("|cffffd100Running:|r |cffff8000on hold|r")
    elseif db.enabled then
        self.statRunning:SetText("|cffffd100Running:|r " .. FormatTime(GetTime() - self.sessionStart))
    else
        self.statRunning:SetText("|cffffd100Running:|r --")
    end
    self.statSent:SetText("|cffffd100Sent:|r " .. self.sentCount)
    local r = self:TimeRemaining()
    if r then
        self.statNextIn:SetText("|cffffd100Next in:|r " .. FormatTime(math.ceil(r)))
    else
        self.statNextIn:SetText("|cffffd100Next in:|r --")
    end
end

function AutoSpam:RefreshUI()
    if not self.frame then return end
    self.toggleButton:SetText(self.db.enabled and "Stop" or "Start")
    self:UpdateStats()
    self:UpdateList()
    self:UpdatePortrait()
    if self.setDry then self.setDry:SetChecked(self.db.dryRun and 1 or nil) end
    if self.activePanel == "editor" then self:EditorChanged() end
end

function AutoSpam:OnTick(elapsed)
    if not self.frame then return end
    elapsed = elapsed or 0

    -- Animate even with the window closed, since the minimap icon shows it too
    if self.db.enabled and not self.resumeHold then
        self.portraitTimer = self.portraitTimer + elapsed
        if self.portraitTimer >= PORTRAIT_STEP then
            self.portraitTimer = 0
            self.portraitFrame = math.mod(self.portraitFrame + 1, PORTRAIT_FRAMES)
            self:SetPortraitFrame(self.portraitFrame)
        end
    end

    if not self.frame:IsVisible() then return end
    self.statTimer = (self.statTimer or 0) + elapsed
    if self.statTimer >= 0.25 then
        self.statTimer = 0
        self:UpdateStats()
    end
end
