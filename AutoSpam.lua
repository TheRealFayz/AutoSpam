-- AutoSpam: Automatically post messages at intervals
-- Compatible with WoW 1.12 and Turtle WoW

AutoSpam = {}
AutoSpam.MinimapButton = {}

-- Initialize saved variables
function AutoSpam:Initialize()
    if not AutoSpamDB then
        AutoSpamDB = {
            minimapPos = 180,
            interval = 300, -- 5 minutes default
            messages = {},
            activeMessages = {},
            channel = "SAY",
            customChannel = "",
            enabled = false,
            debugMode = false
        }
    end
    
    self.db = AutoSpamDB
    self.currentMessageIndex = 1
    self.timeSincePost = 0
end

-- Minimap button functions
function AutoSpam:CreateMinimapButton()
    local button = CreateFrame("Button", "AutoSpamMinimapButton", Minimap)
    button:SetWidth(31)
    button:SetHeight(31)
    button:SetFrameStrata("MEDIUM")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:EnableMouse(true)
    
    -- Icon texture (using chat bubble icon)
    local icon = button:CreateTexture("AutoSpamMinimapIcon", "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
    
    -- Border
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", 0, 0)
    
    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            if AutoSpam.SettingsFrame then
                AutoSpam:ToggleSettingsFrame()
            end
        end
    end)
    
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("AutoSpam")
        GameTooltip:AddLine("Left-click: Open settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click and drag: Move button", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Dragging functionality (right-click drag only to avoid conflict)
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
            
            local angle = math.deg(math.atan2(my - py, mx - px))
            AutoSpamDB.minimapPos = angle
            AutoSpam:UpdateMinimapButtonPosition()
        end
    end)
    
    self.MinimapButton = button
    self:UpdateMinimapButtonPosition()
end

function AutoSpam:UpdateMinimapButtonPosition()
    local angle = math.rad(self.db.minimapPos or 180)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    self.MinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Settings Frame
function AutoSpam:CreateSettingsFrame()
    local frame = CreateFrame("Frame", "AutoSpamSettingsFrame", UIParent)
    
    -- Store reference immediately
    self.SettingsFrame = frame
    
    frame:SetWidth(480)
    frame:SetHeight(380)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:Hide()
    
    -- Register for escape key
    table.insert(UISpecialFrames, "AutoSpamSettingsFrame")
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -20)
    title:SetText("AutoSpam")
    
    -- Create scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "AutoSpamScrollFrame", frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 50)
    scrollFrame:EnableMouse(false)
    
    -- Create scrollbar
    local scrollBar = CreateFrame("Slider", "AutoSpamScrollBar", scrollFrame)
    scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -55)
    scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 60)
    scrollBar:SetWidth(16)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)
    
    -- Scrollbar textures
    scrollBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
    })
    
    local scrollThumb = scrollBar:CreateTexture(nil, "OVERLAY")
    scrollThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    scrollThumb:SetWidth(16)
    scrollThumb:SetHeight(24)
    scrollBar:SetThumbTexture(scrollThumb)
    
    scrollBar:SetScript("OnValueChanged", function()
        scrollFrame:SetVerticalScroll(this:GetValue())
    end)
    
    -- Content frame
    local content = CreateFrame("Frame", "AutoSpamContent", scrollFrame)
    content:SetWidth(400)
    content:SetHeight(590)
    content:EnableMouse(false)
    scrollFrame:SetScrollChild(content)
    
    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function()
        local current = scrollBar:GetValue()
        local minVal, maxVal = scrollBar:GetMinMaxValues()
        if arg1 > 0 then
            scrollBar:SetValue(math.max(minVal, current - 20))
        else
            scrollBar:SetValue(math.min(maxVal, current + 20))
        end
    end)
    
    -- Update scrollbar range when content changes
    local function UpdateScrollRange()
        local contentHeight = 590
        local frameHeight = scrollFrame:GetHeight()
        local maxScroll = math.max(0, contentHeight - frameHeight)
        scrollBar:SetMinMaxValues(0, maxScroll)
        if maxScroll == 0 then
            scrollBar:Hide()
        else
            scrollBar:Show()
        end
    end
    
    scrollFrame:SetScript("OnShow", UpdateScrollRange)
    UpdateScrollRange()
    
    local yOffset = -10
    
    -- Debug Mode Checkbox
    local debugCheck = CreateFrame("CheckButton", "AutoSpamDebugCheck", content)
    debugCheck:SetWidth(20)
    debugCheck:SetHeight(20)
    debugCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    debugCheck:EnableMouse(true)
    debugCheck:RegisterForClicks("LeftButtonUp")
    debugCheck:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    debugCheck:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    debugCheck:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    debugCheck:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    debugCheck:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    
    -- Make checkmark yellow
    local checkedTexture = debugCheck:GetCheckedTexture()
    checkedTexture:SetVertexColor(1, 1, 0)
    
    debugCheck:SetChecked(self.db.debugMode)
    
    local debugLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugLabel:SetPoint("LEFT", debugCheck, "RIGHT", 5, 0)
    debugLabel:SetText("Debug Mode")
    
    debugCheck:SetScript("OnClick", function()
        AutoSpamDB.debugMode = this:GetChecked() and true or false
        if AutoSpamDB.debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Debug mode enabled", 0, 1, 0)
        else
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Debug mode disabled", 1, 1, 0)
        end
    end)
    
    yOffset = yOffset - 30
    
    -- Section 1: Interval Settings
    local intervalLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    intervalLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 15, yOffset)
    intervalLabel:SetText("Post Interval")
    yOffset = yOffset - 22
    
    local intervalSlider = CreateFrame("Slider", "AutoSpamIntervalSlider", content)
    intervalSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    intervalSlider:SetWidth(350)
    intervalSlider:SetHeight(20)
    intervalSlider:SetOrientation("HORIZONTAL")
    intervalSlider:SetMinMaxValues(60, 600)
    intervalSlider:SetValueStep(30)
    intervalSlider:SetValue(self.db.interval)
    
    intervalSlider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
    })
    
    local sliderThumb = intervalSlider:CreateTexture(nil, "OVERLAY")
    sliderThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    sliderThumb:SetWidth(32)
    sliderThumb:SetHeight(32)
    intervalSlider:SetThumbTexture(sliderThumb)
    
    local intervalText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    intervalText:SetPoint("TOP", intervalSlider, "BOTTOM", 0, -5)
    intervalText:SetText(AutoSpam:FormatTime(self.db.interval))
    
    intervalSlider:SetScript("OnValueChanged", function()
        local value = this:GetValue()
        AutoSpamDB.interval = value
        intervalText:SetText(AutoSpam:FormatTime(value))
    end)
    
    yOffset = yOffset - 45
    
    -- Section 2: Message Management
    local messageLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    messageLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 15, yOffset)
    messageLabel:SetText("Message Management")
    yOffset = yOffset - 20
    
    -- Message Name
    local nameLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    nameLabel:SetText("Message Name:")
    yOffset = yOffset - 18
    
    local nameBox = CreateFrame("EditBox", "AutoSpamNameBox", content)
    nameBox:SetWidth(350)
    nameBox:SetHeight(25)
    nameBox:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    nameBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    nameBox:SetBackdropColor(0, 0, 0, 0.5)
    nameBox:SetBackdropBorderColor(0.4, 0.4, 0.4)
    nameBox:SetFontObject(GameFontNormal)
    nameBox:SetTextInsets(8, 8, 0, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    
    yOffset = yOffset - 32
    
    -- Message Text
    local textLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    textLabel:SetText("Message Text:")
    yOffset = yOffset - 18
    
    local textBox = CreateFrame("EditBox", "AutoSpamTextBox", content)
    textBox:SetWidth(350)
    textBox:SetHeight(60)
    textBox:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    textBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    textBox:SetBackdropColor(0, 0, 0, 0.5)
    textBox:SetBackdropBorderColor(0.4, 0.4, 0.4)
    textBox:SetFontObject(GameFontNormal)
    textBox:SetTextInsets(8, 8, 8, 8)
    textBox:SetMultiLine(true)
    textBox:SetAutoFocus(false)
    textBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    
    yOffset = yOffset - 68
    
    -- Save and Navigation Buttons
    local saveButton = CreateFrame("Button", "AutoSpamSaveButton", content, "UIPanelButtonTemplate")
    saveButton:SetWidth(85)
    saveButton:SetHeight(25)
    saveButton:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        AutoSpam:SaveMessage(nameBox:GetText(), textBox:GetText())
    end)
    
    local prevButton = CreateFrame("Button", "AutoSpamPrevButton", content, "UIPanelButtonTemplate")
    prevButton:SetWidth(65)
    prevButton:SetHeight(25)
    prevButton:SetPoint("LEFT", saveButton, "RIGHT", 5, 0)
    prevButton:SetText("< Prev")
    prevButton:SetScript("OnClick", function()
        AutoSpam:NavigateMessage(-1)
    end)
    
    local nextButton = CreateFrame("Button", "AutoSpamNextButton", content, "UIPanelButtonTemplate")
    nextButton:SetWidth(65)
    nextButton:SetHeight(25)
    nextButton:SetPoint("LEFT", prevButton, "RIGHT", 5, 0)
    nextButton:SetText("Next >")
    nextButton:SetScript("OnClick", function()
        AutoSpam:NavigateMessage(1)
    end)
    
    local deleteButton = CreateFrame("Button", "AutoSpamDeleteButton", content, "UIPanelButtonTemplate")
    deleteButton:SetWidth(65)
    deleteButton:SetHeight(25)
    deleteButton:SetPoint("LEFT", nextButton, "RIGHT", 5, 0)
    deleteButton:SetText("Delete")
    deleteButton:SetScript("OnClick", function()
        AutoSpam:DeleteCurrentMessage()
    end)
    
    yOffset = yOffset - 30
    
    local currentMsgLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currentMsgLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    currentMsgLabel:SetText("No messages saved")
    
    yOffset = yOffset - 22
    
    -- Section 3: Active Messages Selection
    local activeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    activeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 15, yOffset)
    activeLabel:SetText("Active Messages")
    yOffset = yOffset - 18
    
    local activeInfo = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    activeInfo:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    activeInfo:SetText("Click to toggle active/inactive:")
    yOffset = yOffset - 18
    
    -- Create fixed border frame for active messages
    local activeBorder = CreateFrame("Frame", "AutoSpamActiveBorder", content)
    activeBorder:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    activeBorder:SetWidth(310)
    activeBorder:SetHeight(100)
    activeBorder:SetFrameLevel(content:GetFrameLevel() + 10)
    activeBorder:EnableMouse(false)
    activeBorder:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    activeBorder:SetBackdropColor(0, 0, 0, 0.5)
    activeBorder:SetBackdropBorderColor(0.4, 0.4, 0.4)
    
    -- Create scrollable list inside the border for active messages
    local activeScrollFrame = CreateFrame("ScrollFrame", "AutoSpamActiveScrollFrame", activeBorder)
    activeScrollFrame:SetPoint("TOPLEFT", activeBorder, "TOPLEFT", 4, -4)
    activeScrollFrame:SetPoint("BOTTOMRIGHT", activeBorder, "BOTTOMRIGHT", -20, 4)
    activeScrollFrame:EnableMouse(false)
    
    -- Scrollbar for active messages
    local activeScrollBar = CreateFrame("Slider", "AutoSpamActiveScrollBar", activeBorder)
    activeScrollBar:SetPoint("TOPRIGHT", activeBorder, "TOPRIGHT", -4, -4)
    activeScrollBar:SetPoint("BOTTOMRIGHT", activeBorder, "BOTTOMRIGHT", -4, 4)
    activeScrollBar:SetWidth(12)
    activeScrollBar:SetOrientation("VERTICAL")
    activeScrollBar:SetMinMaxValues(0, 1)
    activeScrollBar:SetValue(0)
    
    local activeScrollThumb = activeScrollBar:CreateTexture(nil, "OVERLAY")
    activeScrollThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    activeScrollThumb:SetWidth(12)
    activeScrollThumb:SetHeight(20)
    activeScrollBar:SetThumbTexture(activeScrollThumb)
    
    activeScrollBar:SetScript("OnValueChanged", function()
        activeScrollFrame:SetVerticalScroll(this:GetValue())
    end)
    
    -- Content frame for active messages (no backdrop, just holds checkboxes)
    local activeList = CreateFrame("Frame", "AutoSpamActiveList", activeScrollFrame)
    activeList:SetWidth(270)
    activeList:SetHeight(400)
    activeList:SetFrameStrata("DIALOG")
    activeList:EnableMouse(false)
    activeScrollFrame:SetScrollChild(activeList)
    
    -- Enable mouse wheel scrolling for active messages
    activeScrollFrame:EnableMouseWheel(true)
    activeScrollFrame:SetScript("OnMouseWheel", function()
        local current = activeScrollBar:GetValue()
        local minVal, maxVal = activeScrollBar:GetMinMaxValues()
        if arg1 > 0 then
            activeScrollBar:SetValue(math.max(minVal, current - 20))
        else
            activeScrollBar:SetValue(math.min(maxVal, current + 20))
        end
    end)
    
    yOffset = yOffset - 108
    
    -- Section 4: Channel Selection
    local channelLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    channelLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 15, yOffset)
    channelLabel:SetText("Channel Settings")
    yOffset = yOffset - 22
    
    local channelDropdown = CreateFrame("Frame", "AutoSpamChannelDropdown", content, "UIDropDownMenuTemplate")
    channelDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", 5, yOffset)
    
    yOffset = yOffset - 35
    
    local customChannelLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    customChannelLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    customChannelLabel:SetText("Custom Channel Name:")
    yOffset = yOffset - 18
    
    local customChannelBox = CreateFrame("EditBox", "AutoSpamCustomChannelBox", content)
    customChannelBox:SetWidth(350)
    customChannelBox:SetHeight(25)
    customChannelBox:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    customChannelBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    customChannelBox:SetBackdropColor(0, 0, 0, 0.5)
    customChannelBox:SetBackdropBorderColor(0.4, 0.4, 0.4)
    customChannelBox:SetFontObject(GameFontNormal)
    customChannelBox:SetTextInsets(8, 8, 0, 0)
    customChannelBox:SetAutoFocus(false)
    customChannelBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    customChannelBox:SetScript("OnEnterPressed", function() 
        AutoSpamDB.customChannel = this:GetText()
        this:ClearFocus() 
    end)
    customChannelBox:SetScript("OnTextChanged", function()
        AutoSpamDB.customChannel = this:GetText()
    end)
    customChannelBox:SetText(self.db.customChannel)
    
    yOffset = yOffset - 38
    
    -- Start/Stop Button
    local toggleButton = CreateFrame("Button", "AutoSpamToggleButton", content, "UIPanelButtonTemplate")
    toggleButton:SetWidth(180)
    toggleButton:SetHeight(35)
    toggleButton:SetPoint("TOPLEFT", content, "TOPLEFT", 100, yOffset)
    toggleButton:SetText(self.db.enabled and "Stop Posting" or "Start Posting")
    toggleButton:SetScript("OnClick", function()
        AutoSpam:TogglePosting()
    end)
    
    -- Close Button
    local closeButton = CreateFrame("Button", "AutoSpamCloseButton", frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Store other references
    self.SettingsContent = content
    self.NameBox = nameBox
    self.TextBox = textBox
    self.CurrentMsgLabel = currentMsgLabel
    self.ActiveBorder = activeBorder
    self.ActiveList = activeList
    self.ActiveScrollBar = activeScrollBar
    self.ChannelDropdown = channelDropdown
    self.CustomChannelBox = customChannelBox
    self.ToggleButton = toggleButton
    
    -- Initialize channel dropdown with error protection
    local success, err = pcall(function()
        UIDropDownMenu_Initialize(channelDropdown, function()
            AutoSpam:InitializeChannelDropdown()
        end)
        UIDropDownMenu_SetWidth(150, channelDropdown)
        UIDropDownMenu_SetSelectedValue(channelDropdown, self.db.channel)
    end)
    
    if not success then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Dropdown init error: " .. tostring(err), 1, 0, 0)
    end
    
    self:UpdateActiveMessageList()
end

function AutoSpam:InitializeChannelDropdown()
    local channels = {
        {text = "Say", value = "SAY"},
        {text = "Yell", value = "YELL"},
        {text = "Guild", value = "GUILD"},
        {text = "Officer", value = "OFFICER"},
        {text = "Party", value = "PARTY"},
        {text = "Raid", value = "RAID"},
        {text = "Custom Channel", value = "CHANNEL"}
    }
    
    if AutoSpamDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Initializing dropdown, current channel = " .. tostring(AutoSpamDB.channel), 1, 1, 0)
    end
    
    for _, channel in ipairs(channels) do
        local info = {}
        info.text = channel.text
        info.value = channel.value
        info.func = function(button)
            if AutoSpamDB.debugMode then
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Clicked, this=" .. tostring(this) .. " arg1=" .. tostring(arg1), 1, 0.5, 0)
            end
            local selectedValue = this and this.value or channel.value
            if AutoSpamDB.debugMode then
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Selected value = " .. tostring(selectedValue), 1, 0.5, 0)
            end
            AutoSpamDB.channel = selectedValue
            UIDropDownMenu_SetSelectedValue(AutoSpam.ChannelDropdown, selectedValue)
            if AutoSpamDB.debugMode then
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Set channel to " .. selectedValue, 0, 1, 1)
            end
        end
        info.checked = (AutoSpamDB.channel == channel.value)
        if AutoSpamDB.debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("  " .. channel.text .. " checked = " .. tostring(info.checked), 0.7, 0.7, 0.7)
        end
        UIDropDownMenu_AddButton(info)
    end
end

function AutoSpam:ToggleSettingsFrame()
    if not self.SettingsFrame then
        return
    end
    
    if self.SettingsFrame:IsVisible() then
        self.SettingsFrame:Hide()
    else
        self.SettingsFrame:Show()
        self:UpdateActiveMessageList()
        self:LoadCurrentMessage()
    end
end

function AutoSpam:SaveMessage(name, text)
    if not name or name == "" then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Please enter a message name.", 1, 0, 0)
        return
    end
    
    if not text or text == "" then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Please enter message text.", 1, 0, 0)
        return
    end
    
    -- Check if updating existing message
    local found = false
    for i, msg in ipairs(self.db.messages) do
        if msg.name == name then
            msg.text = text
            found = true
            self.currentMessageIndex = i
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Message '" .. name .. "' updated.", 0, 1, 0)
            break
        end
    end
    
    if not found then
        table.insert(self.db.messages, {name = name, text = text})
        self.currentMessageIndex = table.getn(self.db.messages)
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Message '" .. name .. "' saved.", 0, 1, 0)
    end
    
    self:UpdateActiveMessageList()
    self:UpdateCurrentMessageLabel()
end

function AutoSpam:DeleteCurrentMessage()
    if table.getn(self.db.messages) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: No messages to delete.", 1, 0, 0)
        return
    end
    
    local msg = self.db.messages[self.currentMessageIndex]
    if msg then
        -- Remove from active messages if present
        for i, name in ipairs(self.db.activeMessages) do
            if name == msg.name then
                table.remove(self.db.activeMessages, i)
                break
            end
        end
        
        table.remove(self.db.messages, self.currentMessageIndex)
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Message deleted.", 1, 1, 0)
        
        if self.currentMessageIndex > table.getn(self.db.messages) then
            self.currentMessageIndex = table.getn(self.db.messages)
        end
        if self.currentMessageIndex < 1 then
            self.currentMessageIndex = 1
        end
        
        self:LoadCurrentMessage()
        self:UpdateActiveMessageList()
    end
end

function AutoSpam:NavigateMessage(direction)
    if table.getn(self.db.messages) == 0 then
        return
    end
    
    self.currentMessageIndex = self.currentMessageIndex + direction
    
    if self.currentMessageIndex > table.getn(self.db.messages) then
        self.currentMessageIndex = 1
    elseif self.currentMessageIndex < 1 then
        self.currentMessageIndex = table.getn(self.db.messages)
    end
    
    self:LoadCurrentMessage()
end

function AutoSpam:LoadCurrentMessage()
    if table.getn(self.db.messages) == 0 then
        self.NameBox:SetText("")
        self.TextBox:SetText("")
        self:UpdateCurrentMessageLabel()
        return
    end
    
    local msg = self.db.messages[self.currentMessageIndex]
    if msg then
        self.NameBox:SetText(msg.name)
        self.TextBox:SetText(msg.text)
        self:UpdateCurrentMessageLabel()
    end
end

function AutoSpam:UpdateCurrentMessageLabel()
    if table.getn(self.db.messages) == 0 then
        self.CurrentMsgLabel:SetText("No messages saved")
    else
        self.CurrentMsgLabel:SetText("Viewing message " .. self.currentMessageIndex .. " of " .. table.getn(self.db.messages))
    end
end

function AutoSpam:UpdateActiveMessageList()
    -- Clear old checkboxes
    if self.ActiveCheckboxes then
        for _, checkbox in ipairs(self.ActiveCheckboxes) do
            checkbox:Hide()
            checkbox:SetParent(nil)
        end
    end
    self.ActiveCheckboxes = {}
    
    local yPos = -8
    local numMessages = table.getn(self.db.messages)
    
    for i, msg in ipairs(self.db.messages) do
        local isActive = false
        for _, name in ipairs(self.db.activeMessages) do
            if name == msg.name then
                isActive = true
                break
            end
        end
        
        -- Create button as direct child of content (without name to avoid reuse issues)
        local button = CreateFrame("CheckButton", nil, self.SettingsContent)
        button:SetWidth(18)
        button:SetHeight(18)
        -- Position it inside the activeBorder area
        button:SetPoint("TOPLEFT", self.ActiveBorder, "TOPLEFT", 12, yPos - 4)
        button:SetFrameLevel(self.SettingsContent:GetFrameLevel() + 100)
        button:EnableMouse(true)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        if AutoSpamDB.debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Created checkbox " .. i .. " at yPos=" .. yPos, 0.5, 0.5, 0.5)
        end
        
        button:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        button:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        button:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        button:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
        
        -- Make checkmark yellow
        local checkedTexture = button:GetCheckedTexture()
        checkedTexture:SetVertexColor(1, 1, 0)
        
        button:SetChecked(isActive)
        
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", button, "RIGHT", 5, 0)
        label:SetText(msg.name)
        
        -- Store checkbox reference so we can clear it later
        table.insert(self.ActiveCheckboxes, button)
        
        -- Create local copy for closure
        local messageName = msg.name
        
        button:SetScript("OnClick", function()
            if AutoSpamDB.debugMode then
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: OnClick fired for: " .. messageName, 1, 0, 1)
            end
            AutoSpam:ToggleActiveMessage(messageName)
        end)
        
        button:SetScript("OnMouseUp", function()
            if AutoSpamDB.debugMode then
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: OnMouseUp fired for: " .. messageName, 1, 1, 0)
            end
        end)
        
        yPos = yPos - 20
    end
    
    -- Update scrollbar range
    local contentHeight = math.max(100, numMessages * 20 + 16)
    self.ActiveList:SetHeight(contentHeight)
    
    local scrollFrameHeight = 100
    local maxScroll = math.max(0, contentHeight - scrollFrameHeight)
    self.ActiveScrollBar:SetMinMaxValues(0, maxScroll)
    
    if maxScroll == 0 then
        self.ActiveScrollBar:Hide()
    else
        self.ActiveScrollBar:Show()
    end
end

function AutoSpam:ToggleActiveMessage(name)
    if AutoSpamDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: ToggleActiveMessage called for: " .. name, 1, 1, 0)
    end
    
    local found = false
    for i, activeName in ipairs(self.db.activeMessages) do
        if activeName == name then
            table.remove(self.db.activeMessages, i)
            found = true
            if AutoSpamDB.debugMode then
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Removed from active list", 1, 0.5, 0)
            end
            break
        end
    end
    
    if not found then
        table.insert(self.db.activeMessages, name)
        if AutoSpamDB.debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Added to active list", 0, 1, 0)
        end
    end
    
    if AutoSpamDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Active messages now: " .. table.getn(self.db.activeMessages), 1, 1, 0)
    end
    
    self:UpdateActiveMessageList()
end

function AutoSpam:TogglePosting()
    self.db.enabled = not self.db.enabled
    self.ToggleButton:SetText(self.db.enabled and "Stop Posting" or "Start Posting")
    
    if self.db.enabled then
        self.timeSincePost = 0
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Started posting.", 0, 1, 0)
        -- Post immediately on start
        self:PostRandomMessage()
    else
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Stopped posting.", 1, 1, 0)
    end
end

function AutoSpam:PostRandomMessage()
    if AutoSpamDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: PostRandomMessage called", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Active messages count = " .. table.getn(self.db.activeMessages), 1, 1, 0)
        for i, name in ipairs(self.db.activeMessages) do
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG:   Active[" .. i .. "] = " .. name, 0.7, 0.7, 0.7)
        end
    end
    
    if table.getn(self.db.activeMessages) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: No active messages to post.", 1, 0, 0)
        return
    end
    
    -- Find all messages that are active
    local activeMessageTexts = {}
    for _, activeName in ipairs(self.db.activeMessages) do
        for _, msg in ipairs(self.db.messages) do
            if msg.name == activeName then
                table.insert(activeMessageTexts, msg.text)
                break
            end
        end
    end
    
    if AutoSpamDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Found " .. table.getn(activeMessageTexts) .. " active message texts", 1, 1, 0)
    end
    
    if table.getn(activeMessageTexts) == 0 then
        return
    end
    
    -- Pick random message
    local randomIndex = math.random(1, table.getn(activeMessageTexts))
    local message = activeMessageTexts[randomIndex]
    
    -- Post to channel
    if self.db.channel == "SAY" then
        SendChatMessage(message, "SAY")
    elseif self.db.channel == "YELL" then
        SendChatMessage(message, "YELL")
    elseif self.db.channel == "GUILD" then
        SendChatMessage(message, "GUILD")
    elseif self.db.channel == "OFFICER" then
        SendChatMessage(message, "OFFICER")
    elseif self.db.channel == "PARTY" then
        SendChatMessage(message, "PARTY")
    elseif self.db.channel == "RAID" then
        SendChatMessage(message, "RAID")
    elseif self.db.channel == "CHANNEL" then
        if self.db.customChannel and self.db.customChannel ~= "" then
            local channelNum = GetChannelName(self.db.customChannel)
            if channelNum and channelNum > 0 then
                SendChatMessage(message, "CHANNEL", nil, channelNum)
            else
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Custom channel '" .. self.db.customChannel .. "' not found.", 1, 0, 0)
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: No custom channel specified.", 1, 0, 0)
        end
    end
end

function AutoSpam:FormatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds - (minutes * 60)
    if secs == 0 then
        return minutes .. " min"
    else
        return minutes .. " min " .. secs .. " sec"
    end
end

-- Event Frame for Updates
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local isInitialized = false

local updateTimer = 0
eventFrame:SetScript("OnUpdate", function()
    if not AutoSpam.db or not AutoSpam.db.enabled then
        return
    end
    
    updateTimer = updateTimer + arg1
    if updateTimer >= 1 then
        AutoSpam.timeSincePost = AutoSpam.timeSincePost + 1
        
        if AutoSpam.timeSincePost >= AutoSpam.db.interval then
            AutoSpam:PostRandomMessage()
            AutoSpam.timeSincePost = 0
        end
        
        updateTimer = 0
    end
end)

eventFrame:SetScript("OnEvent", function()
    if isInitialized then
        return
    end
    
    if event == "VARIABLES_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        local success, err = pcall(function()
            AutoSpam:Initialize()
        end)
        if not success then
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam Init Error: " .. tostring(err), 1, 0, 0)
            return
        end
        
        success, err = pcall(function()
            AutoSpam:CreateMinimapButton()
        end)
        if not success then
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam Minimap Error: " .. tostring(err), 1, 0, 0)
            return
        end
        
        success, err = pcall(function()
            AutoSpam:CreateSettingsFrame()
        end)
        if not success then
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam Settings Error: " .. tostring(err), 1, 0, 0)
            return
        end
        
        isInitialized = true
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam loaded. Click the minimap button to configure.", 0, 1, 1)
    end
end)