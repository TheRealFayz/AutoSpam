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
            messages = {},  -- Each message now stores: {name, text, enabled, channel, customChannel}
            enabled = false,
            debugMode = false
        }
    end
    
    -- Migrate old messages to new format (add channel fields if missing)
    if AutoSpamDB.messages then
        for _, msg in ipairs(AutoSpamDB.messages) do
            if not msg.enabled then
                msg.enabled = false
            end
            if not msg.channel then
                msg.channel = "SAY"
            end
            if not msg.customChannel then
                msg.customChannel = ""
            end
            if not msg.weight then
                msg.weight = 1  -- Default weight for existing messages
            end
        end
    end
    
    self.db = AutoSpamDB
    -- Always start disabled on login/reload
    self.db.enabled = false
    self.currentMessageIndex = 1
    self.timeSincePost = 0
    self.timerStarted = false  -- Timer only runs after first Start Posting click
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
    
    -- Dark background behind text
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetWidth(26)
    background:SetHeight(26)
    background:SetPoint("CENTER", 0, 1)
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetVertexColor(0.1, 0.1, 0.1, 1)
    
    -- "AS" text instead of icon
    local text = button:CreateFontString(nil, "ARTWORK")
    text:SetPoint("CENTER", 0, 1)
    text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    text:SetText("AS")
    text:SetTextColor(1, 0.82, 0)  -- Gold color
    
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

-- Settings Frame - NEW DESIGN
function AutoSpam:CreateSettingsFrame()
    local frame = CreateFrame("Frame", "AutoSpamSettingsFrame", UIParent)
    
    -- Store reference immediately
    self.SettingsFrame = frame
    
    frame:SetWidth(355)
    frame:SetHeight(450)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)  -- Darker background (twice as dark)
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
    
    -- Subtitle "By Fayz"
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("By Fayz")
    subtitle:SetTextColor(1, 1, 1)  -- White color
    
    -- Close Button
    local closeButton = CreateFrame("Button", "AutoSpamCloseButton", frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Help Button (same gold color as other buttons)
    local helpButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    helpButton:SetWidth(60)
    helpButton:SetHeight(20)
    helpButton:SetPoint("RIGHT", closeButton, "LEFT", -5, 0)
    helpButton:SetText("Help")
    helpButton:SetScript("OnClick", function()
        AutoSpam:OpenHelpWindow()
    end)
    
    local yOffset = -60  -- Adjusted for subtitle
    
    -- Start/Stop Button
    local toggleButton = CreateFrame("Button", "AutoSpamToggleButton", frame, "UIPanelButtonTemplate")
    toggleButton:SetWidth(100)
    toggleButton:SetHeight(25)
    toggleButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    toggleButton:SetText(self.db.enabled and "Stop Posting" or "Start Posting")
    toggleButton:SetScript("OnClick", function()
        AutoSpam:TogglePosting()
    end)
    self.ToggleButton = toggleButton
    
    -- Post Now Button
    local postNowButton = CreateFrame("Button", "AutoSpamPostNowButton", frame, "UIPanelButtonTemplate")
    postNowButton:SetWidth(80)
    postNowButton:SetHeight(25)
    postNowButton:SetPoint("LEFT", toggleButton, "RIGHT", 5, 0)
    postNowButton:SetText("Post Now")
    postNowButton:SetScript("OnClick", function()
        AutoSpam:PostNow()
    end)
    
    -- Countdown Timer (next to Post Now button)
    local countdownText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countdownText:SetPoint("LEFT", postNowButton, "RIGHT", 10, 0)
    countdownText:SetText("Next post in: --:--")
    countdownText:SetTextColor(1, 1, 1)  -- White color
    self.CountdownText = countdownText
    
    yOffset = yOffset - 35
    
    -- Interval Slider
    local intervalLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    intervalLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    intervalLabel:SetText("Post Interval:")
    intervalLabel:SetTextColor(1, 0.82, 0)  -- Gold color
    
    -- Interval Display (next to Post Interval label in gold - only updates when slider moves)
    local intervalText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    intervalText:SetPoint("LEFT", intervalLabel, "RIGHT", 5, 0)
    local minutes = math.floor(self.db.interval / 60)
    local seconds = self.db.interval - (minutes * 60)
    intervalText:SetText(string.format("%d:%02d", minutes, seconds))
    intervalText:SetTextColor(1, 0.82, 0)  -- Gold color
    self.IntervalText = intervalText
    
    local intervalSlider = CreateFrame("Slider", "AutoSpamIntervalSlider", frame, "OptionsSliderTemplate")
    intervalSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset - 20)
    intervalSlider:SetWidth(315)
    intervalSlider:SetHeight(15)
    intervalSlider:SetOrientation("HORIZONTAL")
    intervalSlider:SetMinMaxValues(60, 600)
    intervalSlider:SetValueStep(30)
    intervalSlider:SetValue(self.db.interval)
    
    getglobal(intervalSlider:GetName() .. "Low"):SetText("1 min")
    getglobal(intervalSlider:GetName() .. "High"):SetText("10 min")
    
    intervalSlider:SetScript("OnValueChanged", function()
        local value = this:GetValue()
        AutoSpamDB.interval = value
        
        -- Update interval display only (not the countdown timer)
        if AutoSpam.IntervalText then
            local minutes = math.floor(value / 60)
            local seconds = value - (minutes * 60)
            AutoSpam.IntervalText:SetText(string.format("%d:%02d", minutes, seconds))
        end
    end)
    
    yOffset = yOffset - 65
    
    -- Add New Message Section
    local addLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    addLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    addLabel:SetText("Add New Message")
    addLabel:SetTextColor(1, 0.82, 0)  -- Gold color
    
    yOffset = yOffset - 25
    
    local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    nameLabel:SetText("Message Name:")
    nameLabel:SetTextColor(1, 0.82, 0)  -- Gold color
    
    local nameBox = CreateFrame("EditBox", "AutoSpamNewNameBox", frame, "InputBoxTemplate")
    nameBox:SetWidth(150)
    nameBox:SetHeight(20)
    nameBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 120, yOffset)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(50)
    
    local addButton = CreateFrame("Button", "AutoSpamAddButton", frame, "UIPanelButtonTemplate")
    addButton:SetWidth(60)
    addButton:SetHeight(25)
    addButton:SetPoint("LEFT", nameBox, "RIGHT", 5, 0)
    addButton:SetText("Add")
    addButton:SetScript("OnClick", function()
        local name = nameBox:GetText()
        if name and name ~= "" then
            AutoSpam:AddNewMessage(name)
            nameBox:SetText("")
        else
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Please enter a message name.", 1, 0, 0)
        end
    end)
    
    yOffset = yOffset - 40
    
    -- Message List Section
    local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    listLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    listLabel:SetText("Messages")
    listLabel:SetTextColor(1, 0.82, 0)  -- Gold color
    
    yOffset = yOffset - 25
    
    -- Create scrollable message list
    local listBorder = CreateFrame("Frame", "AutoSpamListBorder", frame)
    listBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    listBorder:SetWidth(315)
    listBorder:SetHeight(180)
    listBorder:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    listBorder:SetBackdropColor(0, 0, 0, 0.5)
    listBorder:SetBackdropBorderColor(0.4, 0.4, 0.4)
    
    -- Scrollframe
    local scrollFrame = CreateFrame("ScrollFrame", "AutoSpamMessageScrollFrame", listBorder)
    scrollFrame:SetPoint("TOPLEFT", listBorder, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", listBorder, "BOTTOMRIGHT", -20, 4)
    scrollFrame:EnableMouse(false)
    
    -- Scrollbar
    local scrollBar = CreateFrame("Slider", "AutoSpamMessageScrollBar", listBorder)
    scrollBar:SetPoint("TOPRIGHT", listBorder, "TOPRIGHT", -4, -4)
    scrollBar:SetPoint("BOTTOMRIGHT", listBorder, "BOTTOMRIGHT", -4, 4)
    scrollBar:SetWidth(12)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    
    local scrollThumb = scrollBar:CreateTexture(nil, "OVERLAY")
    scrollThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    scrollThumb:SetWidth(12)
    scrollThumb:SetHeight(20)
    scrollBar:SetThumbTexture(scrollThumb)
    
    scrollBar:SetScript("OnValueChanged", function()
        scrollFrame:SetVerticalScroll(this:GetValue())
    end)
    
    -- Content frame for messages
    local messageList = CreateFrame("Frame", "AutoSpamMessageList", scrollFrame)
    messageList:SetWidth(285)
    messageList:SetHeight(400)
    messageList:EnableMouse(false)
    scrollFrame:SetScrollChild(messageList)
    
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
    
    -- Store references
    self.MessageList = messageList
    self.MessageScrollBar = scrollBar
    
    -- Initial message list update
    self:UpdateMessageList()
end

-- Helper Functions for New UI

function AutoSpam:AddNewMessage(name)
    -- Check if name already exists
    for _, msg in ipairs(self.db.messages) do
        if msg.name == name then
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: A message with that name already exists.", 1, 0, 0)
            return
        end
    end
    
    -- Add new message with default values
    table.insert(self.db.messages, {
        name = name,
        text = "",
        enabled = false,
        channel = "SAY",
        customChannel = "",
        weight = 1  -- Default weight
    })
    
    DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Added message '" .. name .. "'. Click Edit to set the message text.", 0, 1, 0)
    self:UpdateMessageList()
end

function AutoSpam:UpdateMessageList()
    -- Clear existing message rows
    if self.MessageRows then
        for _, row in ipairs(self.MessageRows) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    self.MessageRows = {}
    
    local yPos = -5
    local numMessages = table.getn(self.db.messages)
    
    for i, msg in ipairs(self.db.messages) do
        -- Create row frame with background
        local row = CreateFrame("Frame", nil, self.MessageList)
        row:SetWidth(275)
        row:SetHeight(28)
        row:SetPoint("TOPLEFT", self.MessageList, "TOPLEFT", 5, yPos)
        
        -- Row background
        row:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        row:SetBackdropColor(0, 0, 0, 0.6)
        row:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
        
        -- Enabled checkbox
        local checkbox = CreateFrame("CheckButton", nil, row)
        checkbox:SetWidth(20)
        checkbox:SetHeight(20)
        checkbox:SetPoint("LEFT", row, "LEFT", 5, 0)
        checkbox:EnableMouse(true)
        checkbox:RegisterForClicks("LeftButtonUp")
        checkbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        checkbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        checkbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        
        local checkedTexture = checkbox:GetCheckedTexture()
        checkedTexture:SetVertexColor(1, 1, 0)
        
        checkbox:SetChecked(msg.enabled)
        
        local messageName = msg.name
        checkbox:SetScript("OnClick", function()
            AutoSpam:ToggleMessageEnabled(messageName)
        end)
        
        -- Message name text (gold color like DoiteAuras)
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        local weight = msg.weight or 1  -- Default to 1 if not set
        if weight > 1 then
            nameText:SetText(msg.name .. " (x" .. weight .. ")")
        else
            nameText:SetText(msg.name)
        end
        nameText:SetTextColor(1, 0.82, 0)  -- Gold color
        nameText:SetWidth(90)
        nameText:SetJustifyH("LEFT")
        
        -- Up arrow button (smaller)
        local upButton = CreateFrame("Button", nil, row)
        upButton:SetWidth(8)
        upButton:SetHeight(8)
        upButton:SetPoint("LEFT", nameText, "RIGHT", 21, 0)
        upButton:EnableMouse(true)
        upButton:RegisterForClicks("LeftButtonUp")
        upButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
        upButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
        upButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
        
        local messageIndex = i
        upButton:SetScript("OnClick", function()
            AutoSpam:MoveMessageUp(messageIndex)
        end)
        if i == 1 then
            upButton:Disable()
        end
        
        -- Down arrow button (smaller)
        local downButton = CreateFrame("Button", nil, row)
        downButton:SetWidth(8)
        downButton:SetHeight(8)
        downButton:SetPoint("LEFT", upButton, "RIGHT", 1, 0)
        downButton:EnableMouse(true)
        downButton:RegisterForClicks("LeftButtonUp")
        downButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        downButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
        downButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        downButton:SetScript("OnClick", function()
            AutoSpam:MoveMessageDown(messageIndex)
        end)
        if i == numMessages then
            downButton:Disable()
        end
        
        -- Edit button
        local editButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        editButton:SetWidth(45)
        editButton:SetHeight(20)
        editButton:SetPoint("LEFT", downButton, "RIGHT", 2, 0)
        editButton:SetText("Edit")
        editButton:SetScript("OnClick", function()
            AutoSpam:OpenEditWindow(messageName)
        end)
        
        -- Remove button
        local removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeButton:SetWidth(60)
        removeButton:SetHeight(20)
        removeButton:SetPoint("LEFT", editButton, "RIGHT", 2, 0)
        removeButton:SetText("Remove")
        removeButton:SetScript("OnClick", function()
            AutoSpam:RemoveMessage(messageName)
        end)
        
        table.insert(self.MessageRows, row)
        yPos = yPos - 30  -- 28px row + 2px gap
    end
    
    -- Update scrollbar range
    local contentHeight = math.max(180, numMessages * 30 + 10)
    self.MessageList:SetHeight(contentHeight)
    
    local scrollFrameHeight = 172
    local maxScroll = math.max(0, contentHeight - scrollFrameHeight)
    self.MessageScrollBar:SetMinMaxValues(0, maxScroll)
    
    if maxScroll == 0 then
        self.MessageScrollBar:Hide()
    else
        self.MessageScrollBar:Show()
    end
end

function AutoSpam:ToggleMessageEnabled(messageName)
    for _, msg in ipairs(self.db.messages) do
        if msg.name == messageName then
            msg.enabled = not msg.enabled
            if AutoSpamDB.debugMode then
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: " .. messageName .. " " .. (msg.enabled and "enabled" or "disabled"), 1, 1, 0)
            end
            break
        end
    end
    self:UpdateMessageList()
end

function AutoSpam:MoveMessageUp(index)
    if index > 1 then
        local temp = self.db.messages[index]
        self.db.messages[index] = self.db.messages[index - 1]
        self.db.messages[index - 1] = temp
        self:UpdateMessageList()
    end
end

function AutoSpam:MoveMessageDown(index)
    if index < table.getn(self.db.messages) then
        local temp = self.db.messages[index]
        self.db.messages[index] = self.db.messages[index + 1]
        self.db.messages[index + 1] = temp
        self:UpdateMessageList()
    end
end

function AutoSpam:RemoveMessage(messageName)
    for i, msg in ipairs(self.db.messages) do
        if msg.name == messageName then
            table.remove(self.db.messages, i)
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Removed message '" .. messageName .. "'", 1, 1, 0)
            self:UpdateMessageList()
            return
        end
    end
end

function AutoSpam:OpenEditWindow(messageName)
    -- Sanitize message name for frame name (remove spaces and special chars)
    local sanitizedName = string.gsub(messageName, "[^%w]", "")
    local frameName = "AutoSpamEditFrame_" .. sanitizedName
    
    -- Close all other edit windows first
    for _, msg in ipairs(self.db.messages) do
        local otherSanitizedName = string.gsub(msg.name, "[^%w]", "")
        local otherFrameName = "AutoSpamEditFrame_" .. otherSanitizedName
        if otherFrameName ~= frameName then
            local otherFrame = getglobal(otherFrameName)
            if otherFrame and otherFrame:IsVisible() then
                otherFrame:Hide()
            end
        end
    end
    
    -- Check if frame already exists
    local existingFrame = getglobal(frameName)
    if existingFrame then
        if existingFrame:IsVisible() then
            existingFrame:Hide()
        else
            existingFrame:Show()
            
            -- Update dropdown text when showing existing window
            local dropdownName = "AutoSpamEditChannelDD_" .. sanitizedName
            local dropdown = getglobal(dropdownName)
            if dropdown then
                -- Find the message to get current channel
                local message = nil
                for _, msg in ipairs(self.db.messages) do
                    if msg.name == messageName then
                        message = msg
                        break
                    end
                end
                
                if message then
                    local channels = {
                        {text = "Say", value = "SAY"},
                        {text = "Yell", value = "YELL"},
                        {text = "Guild", value = "GUILD"},
                        {text = "Officer", value = "OFFICER"},
                        {text = "Party", value = "PARTY"},
                        {text = "Raid", value = "RAID"},
                        {text = "World", value = "WORLD"},
                        {text = "Custom Channel", value = "CHANNEL"}
                    }
                    
                    local displayText = "Say"
                    for _, channel in ipairs(channels) do
                        if channel.value == message.channel then
                            displayText = channel.text
                            break
                        end
                    end
                    
                    -- Set the dropdown text
                    local btn = getglobal(dropdownName .. "Text")
                    if btn then
                        btn:SetText(displayText)
                    end
                end
            end
        end
        return
    end
    
    -- Find the message
    local message = nil
    for _, msg in ipairs(self.db.messages) do
        if msg.name == messageName then
            message = msg
            break
        end
    end
    
    if not message then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Message not found.", 1, 0, 0)
        return
    end
    
    -- Create new edit window
    local frame = CreateFrame("Frame", frameName, UIParent)
    frame:SetWidth(355)
    frame:SetHeight(450)
    
    -- Position to the right of the main settings window
    if self.SettingsFrame and self.SettingsFrame:IsVisible() then
        frame:SetPoint("TOPLEFT", self.SettingsFrame, "TOPRIGHT", 5, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)  -- Darker background (twice as dark)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    -- Register for escape key
    table.insert(UISpecialFrames, frameName)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", -25, -20)
    title:SetText("Edit: " .. messageName)
    
    -- Name EditBox (for renaming, initially hidden)
    local nameEditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameEditBox:SetWidth(180)
    nameEditBox:SetHeight(20)
    nameEditBox:SetPoint("TOP", frame, "TOP", -25, -20)
    nameEditBox:SetAutoFocus(false)
    nameEditBox:SetMaxLetters(50)
    nameEditBox:SetFontObject(GameFontNormalLarge)
    nameEditBox:Hide()
    
    -- Rename Button
    local renameButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    renameButton:SetWidth(50)
    renameButton:SetHeight(18)
    renameButton:SetPoint("LEFT", title, "RIGHT", 5, 0)
    renameButton:SetText("Rename")
    
    local isRenaming = false
    
    renameButton:SetScript("OnClick", function()
        if not isRenaming then
            -- Enter rename mode
            isRenaming = true
            title:Hide()
            nameEditBox:SetText(messageName)
            nameEditBox:Show()
            nameEditBox:SetFocus()
            renameButton:SetText("Save")
        else
            -- Save rename
            local newName = nameEditBox:GetText()
            
            -- Validate new name
            if newName == "" then
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Message name cannot be empty.", 1, 0, 0)
                return
            end
            
            -- Check for duplicate names
            local isDuplicate = false
            for _, msg in ipairs(AutoSpam.db.messages) do
                if msg.name == newName and msg.name ~= messageName then
                    isDuplicate = true
                    break
                end
            end
            
            if isDuplicate then
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: A message with that name already exists.", 1, 0, 0)
                return
            end
            
            -- Update the message name
            message.name = newName
            messageName = newName
            
            -- Update UI
            title:SetText("Edit: " .. newName)
            nameEditBox:Hide()
            title:Show()
            renameButton:SetText("Rename")
            isRenaming = false
            
            -- Update message list
            AutoSpam:UpdateMessageList()
            
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Message renamed to '" .. newName .. "'.", 0, 1, 0)
        end
    end)
    
    -- Allow Enter key to save rename
    nameEditBox:SetScript("OnEnterPressed", function()
        renameButton:GetScript("OnClick")()
    end)
    
    -- Allow Escape key to cancel rename
    nameEditBox:SetScript("OnEscapePressed", function()
        nameEditBox:Hide()
        title:Show()
        renameButton:SetText("Rename")
        isRenaming = false
        this:ClearFocus()
    end)
    
    -- Close Button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    local yOffset = -50
    
    -- Message Text Label
    local textLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    textLabel:SetText("Message Text:")
    textLabel:SetTextColor(1, 0.82, 0)
    
    yOffset = yOffset - 20
    
    -- Message Text Input (scrollable)
    local textBorder = CreateFrame("Frame", nil, frame)
    textBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    textBorder:SetWidth(315)
    textBorder:SetHeight(100)
    textBorder:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    textBorder:SetBackdropColor(0, 0, 0, 0.5)
    textBorder:SetBackdropBorderColor(0.4, 0.4, 0.4)
    
    local textScrollFrame = CreateFrame("ScrollFrame", nil, textBorder)
    textScrollFrame:SetPoint("TOPLEFT", textBorder, "TOPLEFT", 4, -4)
    textScrollFrame:SetPoint("BOTTOMRIGHT", textBorder, "BOTTOMRIGHT", -4, 4)
    
    local textBox = CreateFrame("EditBox", nil, textScrollFrame)
    textBox:SetWidth(305)
    textBox:SetHeight(90)
    textBox:SetMultiLine(true)
    textBox:SetAutoFocus(false)
    textBox:SetFontObject(GameFontNormal)
    textBox:SetTextInsets(5, 5, 5, 5)  -- Add padding inside the text box
    textBox:SetText(message.text or "")
    textBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    textScrollFrame:SetScrollChild(textBox)
    
    -- Character counter
    local charCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charCount:SetPoint("TOPRIGHT", textBorder, "BOTTOMRIGHT", 0, -3)
    local currentLength = string.len(message.text or "")
    charCount:SetText(currentLength .. " / 255")
    if currentLength <= 255 then
        charCount:SetTextColor(0, 1, 0)  -- Green
    else
        charCount:SetTextColor(1, 0, 0)  -- Red
    end
    
    -- Update character counter on text change
    textBox:SetScript("OnTextChanged", function()
        local text = this:GetText()
        message.text = text  -- Save to message
        local length = string.len(text)
        charCount:SetText(length .. " / 255")
        if length <= 255 then
            charCount:SetTextColor(0, 1, 0)  -- Green
        else
            charCount:SetTextColor(1, 0, 0)  -- Red
        end
    end)
    
    yOffset = yOffset - 120  -- Adjusted for character counter
    
    -- Channel Label
    local channelLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    channelLabel:SetText("Channel:")
    channelLabel:SetTextColor(1, 0.82, 0)
    
    yOffset = yOffset - 20
    
    -- Channel Dropdown
    local channelDropdown = CreateFrame("Frame", "AutoSpamEditChannelDD_" .. sanitizedName, frame, "UIDropDownMenuTemplate")
    channelDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, yOffset)
    
    -- Custom Channel Input (positioned absolutely beside dropdown area)
    local customChannelBox = CreateFrame("EditBox", "AutoSpamCustomChannel_" .. sanitizedName, frame, "InputBoxTemplate")
    customChannelBox:SetWidth(140)
    customChannelBox:SetHeight(20)
    customChannelBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 175, yOffset - 2)
    customChannelBox:SetAutoFocus(false)
    customChannelBox:SetMaxLetters(50)
    customChannelBox:SetText(message.customChannel or "")
    customChannelBox:EnableMouse(true)
    customChannelBox:EnableKeyboard(true)
    customChannelBox:SetScript("OnTextChanged", function()
        message.customChannel = this:GetText()
    end)
    customChannelBox:SetScript("OnEscapePressed", function() 
        this:ClearFocus() 
    end)
    customChannelBox:SetScript("OnEnterPressed", function() 
        this:ClearFocus() 
    end)
    customChannelBox:Hide()  -- Hidden by default
    
    local channels = {
        {text = "Say", value = "SAY"},
        {text = "Yell", value = "YELL"},
        {text = "Guild", value = "GUILD"},
        {text = "Officer", value = "OFFICER"},
        {text = "Party", value = "PARTY"},
        {text = "Raid", value = "RAID"},
        {text = "World", value = "WORLD"},
        {text = "Custom Channel", value = "CHANNEL"}
    }
    
    -- Capture the custom channel box in closure for dropdown callback
    local customBox = customChannelBox
    
    local success, err = pcall(function()
        UIDropDownMenu_Initialize(channelDropdown, function()
            for _, channel in ipairs(channels) do
                local info = {}
                info.text = channel.text
                info.value = channel.value
                info.func = function()
                    message.channel = info.value
                    UIDropDownMenu_SetSelectedValue(channelDropdown, info.value)
                    -- Set dropdown button text directly
                    local btn = getglobal(channelDropdown:GetName() .. "Text")
                    if btn then
                        btn:SetText(info.text)
                    end
                    -- Show/hide custom channel input
                    if info.value == "CHANNEL" then
                        customBox:Show()
                    else
                        customBox:Hide()
                    end
                    -- Force close dropdown
                    HideDropDownMenu(1)
                end
                info.checked = (message.channel == channel.value)
                UIDropDownMenu_AddButton(info)
            end
        end)
    end)
    
    -- Find initial display text
    local initialText = "Say"
    for _, channel in ipairs(channels) do
        if channel.value == message.channel then
            initialText = channel.text
            break
        end
    end
    
    -- Set the selected value
    UIDropDownMenu_SetSelectedValue(channelDropdown, message.channel)
    
    -- Get or create the text display element
    local dropdownButton = getglobal(channelDropdown:GetName() .. "Button")
    local textElement = getglobal(channelDropdown:GetName() .. "Text")
    
    if not textElement and dropdownButton then
        -- Text element doesn't exist, create it manually
        textElement = dropdownButton:CreateFontString(channelDropdown:GetName() .. "Text", "ARTWORK", "GameFontHighlightSmall")
        textElement:SetPoint("LEFT", dropdownButton, "LEFT", 27, 2)
        textElement:SetPoint("RIGHT", dropdownButton, "RIGHT", -43, 2)
        textElement:SetJustifyH("LEFT")
        textElement:SetText(initialText)
    elseif textElement then
        -- Text element exists, just set it
        textElement:SetText(initialText)
    end
    
    -- Show/hide custom channel box based on saved selection
    if message.channel == "CHANNEL" then
        customChannelBox:Show()
    else
        customChannelBox:Hide()
    end
    
    yOffset = yOffset - 40
    
    -- Weight Label
    local weightLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weightLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    weightLabel:SetText("Weight:")
    weightLabel:SetTextColor(1, 0.82, 0)
    
    -- Weight display (next to Weight label in gold)
    local weightText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weightText:SetPoint("LEFT", weightLabel, "RIGHT", 5, 0)
    weightText:SetText("x" .. (message.weight or 1))
    weightText:SetTextColor(1, 0.82, 0)
    
    yOffset = yOffset - 20
    
    -- Weight Slider
    local weightSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    weightSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    weightSlider:SetWidth(315)
    weightSlider:SetMinMaxValues(1, 10)
    weightSlider:SetValueStep(1)
    weightSlider:SetValue(message.weight or 1)
    
    weightSlider:SetScript("OnValueChanged", function()
        local value = this:GetValue()
        message.weight = value
        weightText:SetText("x" .. value)
        -- Update the message list to show new weight
        AutoSpam:UpdateMessageList()
    end)
    
    yOffset = yOffset - 30
    
    -- Save Button (positioned next to character counter)
    local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveButton:SetWidth(60)
    saveButton:SetHeight(20)
    saveButton:SetPoint("RIGHT", charCount, "LEFT", -10, 0)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        message.text = textBox:GetText()
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Message '" .. messageName .. "' saved.", 0, 1, 0)
    end)
    
    -- Show the frame
    frame:Show()
end


function AutoSpam:OpenHelpWindow()
    local frameName = "AutoSpamHelpFrame"
    
    -- Check if help window already exists
    local existingFrame = getglobal(frameName)
    if existingFrame then
        if existingFrame:IsVisible() then
            existingFrame:Hide()
        else
            existingFrame:Show()
        end
        return
    end
    
    -- Create help window (same style as edit windows)
    local frame = CreateFrame("Frame", frameName, UIParent)
    frame:SetWidth(355)
    frame:SetHeight(450)
    
    -- Position to the left of main window
    if self.SettingsFrame and self.SettingsFrame:IsVisible() then
        frame:SetPoint("TOPRIGHT", self.SettingsFrame, "TOPLEFT", -5, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    -- Register for escape key
    table.insert(UISpecialFrames, frameName)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -20)
    title:SetText("AutoSpam Help")
    title:SetTextColor(1, 0.82, 0)
    
    -- Close Button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Scroll Frame for help content
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)
    
    -- Scroll Bar
    local scrollBar = CreateFrame("Slider", nil, scrollFrame, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -50)
    scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 20)
    scrollBar:SetMinMaxValues(0, 910)
    scrollBar:SetValueStep(20)
    scrollBar:SetValue(0)
    scrollBar:SetScript("OnValueChanged", function()
        scrollFrame:SetVerticalScroll(this:GetValue())
    end)
    
    -- Content Frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(295)
    content:SetHeight(910)
    scrollFrame:SetScrollChild(content)
    
    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function()
        local current = scrollBar:GetValue()
        local minVal, maxVal = scrollBar:GetMinMaxValues()
        if arg1 > 0 then
            scrollBar:SetValue(math.max(minVal, current - 40))
        else
            scrollBar:SetValue(math.min(maxVal, current + 40))
        end
    end)
    
    -- Help Text
    local helpText = "|cFFFFD700WELCOME TO AUTOSPAM|r\n"
    helpText = helpText .. "AutoSpam automatically posts messages to chat channels on a timer. Great for guild recruitment, selling items, raid advertisement, and more!\n\n"
    
    helpText = helpText .. "|cFFFFD700GETTING STARTED|r\n\n"
    helpText = helpText .. "1. |cFF00FF00Add a Message|r\n"
    helpText = helpText .. "   Type a name in the text box and click \"Add Message\"\n"
    helpText = helpText .. "   Example: \"Guild Recruitment\" or \"Selling Herbs\"\n\n"
    helpText = helpText .. "2. |cFF00FF00Edit the Message|r\n"
    helpText = helpText .. "   Click \"Edit\" to open the message editor\n"
    helpText = helpText .. "   - Write your message (max 255 characters)\n"
    helpText = helpText .. "   - Select the chat channel\n"
    helpText = helpText .. "   - Set the weight (how often it posts)\n"
    helpText = helpText .. "   - Click \"Save\" when done\n\n"
    helpText = helpText .. "3. |cFF00FF00Enable the Message|r\n"
    helpText = helpText .. "   Check the box next to the message name to enable it\n\n"
    helpText = helpText .. "4. |cFF00FF00Start Posting|r\n"
    helpText = helpText .. "   Click \"Start Posting\" to begin auto-posting\n"
    helpText = helpText .. "   First post goes out immediately if timer is full\n\n"
    
    helpText = helpText .. "|cFFFFD700MESSAGE SETTINGS|r\n\n"
    helpText = helpText .. "|cFFFFFFFFChannel Options:|r\n"
    helpText = helpText .. "- Say: Local say chat\n"
    helpText = helpText .. "- Yell: Yell (larger radius)\n"
    helpText = helpText .. "- Guild: Guild chat\n"
    helpText = helpText .. "- Officer: Officer chat\n"
    helpText = helpText .. "- Party: Party chat\n"
    helpText = helpText .. "- Raid: Raid chat\n"
    helpText = helpText .. "- World: World channel\n"
    helpText = helpText .. "- Custom Channel: Enter channel name (e.g., \"Trade\", \"LookingForGroup\")\n\n"
    
    helpText = helpText .. "|cFFFFFFFFWeight System:|r\n"
    helpText = helpText .. "Weight determines how often a message posts compared to others. Higher weight = posts more frequently.\n\n"
    helpText = helpText .. "Examples:\n"
    helpText = helpText .. "- Weight 1: Normal frequency (1x)\n"
    helpText = helpText .. "- Weight 3: Posts 3x as often\n"
    helpText = helpText .. "- Weight 10: Posts 10x as often\n\n"
    helpText = helpText .. "If you have:\n"
    helpText = helpText .. "- \"Raid LFM\" (weight 1)\n"
    helpText = helpText .. "- \"Guild Recruitment\" (weight 5)\n"
    helpText = helpText .. "Guild Recruitment will post 5 times as often as Raid LFM.\n\n"
    
    helpText = helpText .. "|cFFFFD700TIMER & POSTING|r\n\n"
    helpText = helpText .. "|cFFFFFFFFPost Interval:|r\n"
    helpText = helpText .. "Controls time between posts (1-10 minutes)\n"
    helpText = helpText .. "Adjust the slider in the main window\n\n"
    
    helpText = helpText .. "|cFFFFFFFFTimer Behavior:|r\n"
    helpText = helpText .. "- Timer starts when you click \"Start Posting\"\n"
    helpText = helpText .. "- Timer counts down continuously once started\n"
    helpText = helpText .. "- When timer hits 0, a random message posts (based on weight)\n"
    helpText = helpText .. "- Clicking \"Stop Posting\" doesn't stop the timer\n"
    helpText = helpText .. "- Timer only stops when it hits 0 while posting is disabled\n"
    helpText = helpText .. "- Click \"Start Posting\" again to resume posting\n\n"
    
    helpText = helpText .. "|cFFFFFFFFPost Now Button:|r\n"
    helpText = helpText .. "Posts immediately and resets the timer\n"
    helpText = helpText .. "Useful when you want to post outside the schedule\n\n"
    
    helpText = helpText .. "|cFFFFD700MANAGING MESSAGES|r\n\n"
    helpText = helpText .. "|cFFFFFFFFEdit:|r Opens the message editor\n"
    helpText = helpText .. "|cFFFFFFFFRename:|r Click \"Rename\" button in edit window to change message name\n"
    helpText = helpText .. "|cFFFFFFFFRemove:|r Deletes the message permanently\n"
    helpText = helpText .. "|cFFFFFFFFUp/Down Arrows:|r Reorder messages in the list\n"
    helpText = helpText .. "|cFFFFFFFFCheckbox:|r Enable/disable individual messages\n\n"
    helpText = helpText .. "Messages with weight > 1 show \"(xN)\" in the list\n\n"
    
    helpText = helpText .. "|cFFFFD700TIPS & BEST PRACTICES|r\n\n"
    helpText = helpText .. "1. |cFF00FF00Test First|r\n"
    helpText = helpText .. "   Create test messages with short timers before going live\n\n"
    helpText = helpText .. "2. |cFF00FF00Use Weights Strategically|r\n"
    helpText = helpText .. "   Set higher weights for important messages\n"
    helpText = helpText .. "   Keep promotional messages at lower weights\n\n"
    helpText = helpText .. "3. |cFF00FF00Vary Your Messages|r\n"
    helpText = helpText .. "   Create multiple versions of similar messages\n"
    helpText = helpText .. "   Prevents spam appearance\n\n"
    helpText = helpText .. "4. |cFF00FF00Watch the Timer|r\n"
    helpText = helpText .. "   The countdown shows when next post happens\n"
    helpText = helpText .. "   Stop posting before logging out to avoid accidental spam\n\n"
    helpText = helpText .. "5. |cFF00FF00Channel Selection|r\n"
    helpText = helpText .. "   Use appropriate channels for content\n"
    helpText = helpText .. "   Trade items -> Trade channel\n"
    helpText = helpText .. "   Recruitment -> World/Guild\n"
    helpText = helpText .. "   Raid LFM -> World channel\n\n"
    helpText = helpText .. "6. |cFF00FF00Character Limit|r\n"
    helpText = helpText .. "   Messages turn red if over 255 characters\n"
    helpText = helpText .. "   Keep messages concise and clear\n\n"
    
    helpText = helpText .. "|cFFFFD700MINIMAP BUTTON|r\n\n"
    helpText = helpText .. "Click the minimap button to toggle the main window\n"
    helpText = helpText .. "Right-click for quick actions\n\n"
    
    helpText = helpText .. "|cFFFFD700QUESTIONS?|r\n\n"
    helpText = helpText .. "For bugs or feature requests, please open a GitHub issue and I will be happy to take a look.\n\n"
    helpText = helpText .. "https://github.com/TheRealFayz/AutoSpam\n\n"
    helpText = helpText .. "Happy posting!\n\n\n"
    
    -- Create text display
    local textDisplay = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textDisplay:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    textDisplay:SetWidth(285)
    textDisplay:SetJustifyH("LEFT")
    textDisplay:SetJustifyV("TOP")
    textDisplay:SetText(helpText)
    
    frame:Show()
end


-- Updated Posting Functions

function AutoSpam:TogglePosting()
    self.db.enabled = not self.db.enabled
    self.ToggleButton:SetText(self.db.enabled and "Stop Posting" or "Start Posting")
    
    if self.db.enabled then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Started posting.", 0, 1, 0)
        -- Start the timer on first "Start Posting" click
        self.timerStarted = true
        
        -- If timer is at full interval (0 elapsed), post immediately
        if self.timeSincePost == 0 then
            self:PostRandomMessage()
            -- Timer stays at 0 and will count up normally
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Stopped posting.", 1, 1, 0)
        -- Timer continues counting even when stopped
    end
    
    -- Update countdown text display
    if self.CountdownText then
        local remaining = self.db.interval - self.timeSincePost
        local minutes = math.floor(remaining / 60)
        local seconds = remaining - (minutes * 60)
        self.CountdownText:SetText(string.format("Next post in: %d:%02d", minutes, seconds))
    end
end

function AutoSpam:PostNow()
    -- Post immediately and reset timer
    self:PostRandomMessage()
    self.timeSincePost = 0
    
    -- Start timer if not already started
    self.timerStarted = true
    
    -- Update countdown text to show full interval
    if self.CountdownText then
        local remaining = self.db.interval - self.timeSincePost
        local minutes = math.floor(remaining / 60)
        local seconds = remaining - (minutes * 60)
        self.CountdownText:SetText(string.format("Next post in: %d:%02d", minutes, seconds))
    end
end

function AutoSpam:PostRandomMessage()
    -- Get all enabled messages
    local enabledMessages = {}
    for _, msg in ipairs(self.db.messages) do
        if msg.enabled then
            table.insert(enabledMessages, msg)
        end
    end
    
    if AutoSpamDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: PostRandomMessage called", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Enabled messages count = " .. table.getn(enabledMessages), 1, 1, 0)
    end
    
    if table.getn(enabledMessages) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: No enabled messages to post.", 1, 0, 0)
        return
    end
    
    -- Build weighted pool (each message appears N times based on weight)
    local weightedPool = {}
    for _, msg in ipairs(enabledMessages) do
        local weight = msg.weight or 1
        for i = 1, weight do
            table.insert(weightedPool, msg)
        end
    end
    
    -- Pick random message from weighted pool
    local randomIndex = math.random(1, table.getn(weightedPool))
    local msg = weightedPool[randomIndex]
    
    if not msg.text or msg.text == "" then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Message '" .. msg.name .. "' has no text. Skipping.", 1, 0.5, 0)
        return
    end
    
    -- Post to the message's configured channel
    local channel = msg.channel
    local customChannel = msg.customChannel
    
    if AutoSpamDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("AutoSpam DEBUG: Posting '" .. msg.name .. "' to " .. channel, 0, 1, 1)
    end
    
    if channel == "SAY" then
        SendChatMessage(msg.text, "SAY")
    elseif channel == "YELL" then
        SendChatMessage(msg.text, "YELL")
    elseif channel == "GUILD" then
        SendChatMessage(msg.text, "GUILD")
    elseif channel == "OFFICER" then
        SendChatMessage(msg.text, "OFFICER")
    elseif channel == "PARTY" then
        SendChatMessage(msg.text, "PARTY")
    elseif channel == "RAID" then
        SendChatMessage(msg.text, "RAID")
    elseif channel == "CHANNEL" then
        if customChannel and customChannel ~= "" then
            local channelNum = GetChannelName(customChannel)
            if channelNum and channelNum > 0 then
                SendChatMessage(msg.text, "CHANNEL", nil, channelNum)
            else
                DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: Channel '" .. customChannel .. "' not found.", 1, 0, 0)
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: No custom channel specified for '" .. msg.name .. "'.", 1, 0, 0)
        end
    elseif channel == "WORLD" then
        -- World channel - try common world channel names
        local worldChannels = {"World", "world", "LookingForGroup", "LFG"}
        local sent = false
        for _, chanName in ipairs(worldChannels) do
            local channelNum = GetChannelName(chanName)
            if channelNum and channelNum > 0 then
                SendChatMessage(msg.text, "CHANNEL", nil, channelNum)
                sent = true
                break
            end
        end
        if not sent then
            DEFAULT_CHAT_FRAME:AddMessage("AutoSpam: World channel not found.", 1, 0, 0)
        end
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
        self:UpdateMessageList()
        
        -- Update countdown text to current position
        if self.CountdownText then
            local remaining = self.db.interval - self.timeSincePost
            local minutes = math.floor(remaining / 60)
            local seconds = remaining - (minutes * 60)
            self.CountdownText:SetText(string.format("Next post in: %d:%02d", minutes, seconds))
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
    -- Update countdown text if frame is visible
    if AutoSpam.CountdownText and AutoSpam.SettingsFrame and AutoSpam.SettingsFrame:IsVisible() then
        local remaining = AutoSpam.db.interval - AutoSpam.timeSincePost
        local minutes = math.floor(remaining / 60)
        local seconds = remaining - (minutes * 60)
        AutoSpam.CountdownText:SetText(string.format("Next post in: %d:%02d", minutes, seconds))
    end
    
    -- Timer only counts when it has been started (by clicking Start Posting)
    if not AutoSpam.db or not AutoSpam.timerStarted then
        return
    end
    
    updateTimer = updateTimer + arg1
    if updateTimer >= 1 then
        AutoSpam.timeSincePost = AutoSpam.timeSincePost + 1
        
        if AutoSpam.timeSincePost >= AutoSpam.db.interval then
            -- Post only if enabled
            if AutoSpam.db.enabled then
                AutoSpam:PostRandomMessage()
                -- Reset timer and keep cycling
                AutoSpam.timeSincePost = 0
            else
                -- Reset timer and STOP counting (don't cycle)
                AutoSpam.timeSincePost = 0
                AutoSpam.timerStarted = false
            end
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
