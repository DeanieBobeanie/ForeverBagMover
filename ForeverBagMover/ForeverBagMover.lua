local addonName = ...
local controller = CreateFrame("Frame", nil, UIParent)
local handles = {}
local gears = {}
local options, pendingReagent, pendingReagentClose, restoringEscape
local db, hooked, refreshing
local keyboardReady, pendingRefresh
local escapeBags
local elapsedSinceCheck = 0
local escapePresses, restoredBags = 0, 0
local Refresh, StopDrag, ChangeHandleSide
local HANDLE_HEIGHT = 20
local VERSION = "1.2.5"

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function Message(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffForever Bag Mover:|r " .. text)
end

local function BagKey(frame)
    if frame == ContainerFrameCombinedBags then return "combined" end
    local id = frame.GetBagID and frame:GetBagID() or frame:GetID()
    if type(id) == "number" and id >= 0 and id <= (NUM_TOTAL_BAG_FRAMES or 5) then
        return "bag" .. id
    end
end

local function Ratio(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function CanChangeLayout(frame)
    if frame.IsForbidden then
        local forbidden = frame:IsForbidden()
        if issecretvalue and issecretvalue(forbidden) then return false end
        if forbidden then return false end
    end
    -- This also covers restrictions inherited from other frames. If the client
    -- cannot confirm permission, leave the frame alone until combat ends.
    if not frame.CanChangeProtectedState then return false end
    local allowed = frame:CanChangeProtectedState()
    if issecretvalue and issecretvalue(allowed) then return false end
    return allowed == true
end

local function ForEachBag(callback)
    if ContainerFrameCombinedBags then callback(ContainerFrameCombinedBags) end
    for i = 1, (NUM_CONTAINER_FRAMES or 7) do
        local frame = _G["ContainerFrame" .. i]
        if frame then callback(frame) end
    end
end

local function IsBackpack(frame)
    local key = BagKey(frame)
    return key == "combined" or key == "bag0"
end

local function QueueReagent(frame)
    if db and db.openReagent and not restoringEscape and frame:IsShown() and IsBackpack(frame) then
        pendingReagent = frame
    end
end

local function OpenPendingReagent()
    local backpack = pendingReagent
    pendingReagent = nil
    if not backpack or not db.openReagent or not backpack:IsShown() or not IsBackpack(backpack) then return end
    local id = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
    if not OpenBag or not IsBagOpen or not C_Container or not C_Container.GetContainerNumSlots then return end
    if IsBagOpen(id) or C_Container.GetContainerNumSlots(id) <= 0 then return end
    if not CanChangeLayout(backpack) then return end
    -- Check the same first available frame that OpenBag would use. Do not
    -- let its full-pool fallback hide an unrelated window or touch a
    -- restricted frame during combat.
    if not ContainerFrameUtil_EnumerateContainerFrames then return end
    local available
    for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
        if not frame:IsShown() and frame:CanUseForBagID(id) then
            if not CanChangeLayout(frame) then return end
            available = true
            break
        end
    end
    if not available then return end
    OpenBag(id)
end

local function ClosePendingReagent()
    if not pendingReagentClose then return end
    pendingReagentClose = nil
    local backpackShown = false
    ForEachBag(function(frame)
        if frame:IsShown() and IsBackpack(frame) then backpackShown = true end
    end)
    -- Wait until Escape restoration and any bag-mode switch finish. If the
    -- backpack stayed open, its reagent bag should stay open too.
    if backpackShown then return end
    local id = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
    ForEachBag(function(frame)
        if frame:IsShown() and BagKey(frame) == "bag" .. id and CanChangeLayout(frame) then
            frame:Hide()
        end
    end)
end

local function ValidPosition(position)
    return type(position) == "table" and type(position.x) == "number"
        and type(position.y) == "number" and position.x >= 0 and position.x <= 1
        and position.y >= 0 and position.y <= 1
end

local function SavePosition(frame, key, movingHandle)
    local source = movingHandle or frame
    local left, top = source:GetLeft(), source:GetTop()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not key or not left or not top or width <= 0 or height <= 0 then return end
    local ratio = Ratio(source)
    left, top = left * ratio, top * ratio
    if movingHandle then
        -- A native layout refresh can reset the bag before combat interrupts
        -- the drag. The detached handle still has the actual dragged position.
        if db.handleSide == "bottom" then
            top = top + frame:GetHeight() * Ratio(frame)
        else
            top = top - movingHandle:GetHeight() * ratio
        end
    end
    db.positions[key] = {
        x = math.max(0, math.min(1, left / width)),
        y = math.max(0, math.min(1, top / height)),
    }
end

local function RestorePosition(frame, position)
    if not ValidPosition(position) then return end
    local ratio = Ratio(frame)
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local left = math.max(0, math.min(position.x * width, width - frame:GetWidth() * ratio))
    local topSpace = db.handleSide == "bottom" and 0 or HANDLE_HEIGHT * ratio
    local bottomSpace = db.handleSide == "bottom" and HANDLE_HEIGHT * ratio or 0
    local top = math.min(height - topSpace,
        math.max(frame:GetHeight() * ratio + bottomSpace, position.y * height))
    local currentLeft, currentTop = frame:GetLeft(), frame:GetTop()
    local _, relative = frame:GetPoint()
    if relative == UIParent and currentLeft and currentTop and math.abs(currentLeft * ratio - left) < 0.1
        and math.abs(currentTop * ratio - top) < 0.1 then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / ratio, top / ratio)
end

local function AnchorBagToHandle(handle)
    local frame = handle.bag
    frame:ClearAllPoints()
    if db.handleSide == "bottom" then
        frame:SetPoint("BOTTOMLEFT", handle, "TOPLEFT", 0, 0)
    else
        frame:SetPoint("TOPLEFT", handle, "BOTTOMLEFT", 0, 0)
    end
end

StopDrag = function(handle, save)
    if not handle.dragging then return end
    handle:StopMovingOrSizing()
    -- The handle remains authoritative if Blizzard has already reset the bag.
    if save and BagKey(handle.bag) == handle.dragKey then
        SavePosition(handle.bag, handle.dragKey, handle)
    end
    handle.dragging = nil
    handle.dragKey = nil
    -- Keep the handle detached until Refresh restores the bag. This also avoids
    -- a circular anchor if combat starts before the bag can be repositioned.
end

local function SyncOptions()
    if not options then return end
    for key, button in pairs(options.checks) do button:SetChecked(db[key]) end
end

local function SetOption(key, value)
    if InCombat() then Message("Wait until combat ends to change bag options."); SyncOptions(); return end
    if key == "locked" then
        for _, handle in pairs(handles) do StopDrag(handle, true) end
    end
    db[key] = value == true
    if key == "escapeCloses" then escapeBags = nil end
    if key == "openReagent" then
        pendingReagent = nil
        if db.openReagent then ForEachBag(QueueReagent) end
    end
    Refresh()
    SyncOptions()
end

local function CreateOptions()
    if options then return end
    options = CreateFrame("Frame", "ForeverBagMoverOptions", UIParent)
    options:SetSize(310, 150)
    options:SetClampedToScreen(true)
    options:SetFrameStrata("DIALOG")
    options:EnableMouse(true)
    local background = options:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.04, 0.06, 0.09, 0.98)
    local title = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", options, "TOPLEFT", 14, -12)
    title:SetText("Forever Bag Mover")
    local close = CreateFrame("Button", nil, options, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", options, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() options:Hide() end)
    options.checks = {}
    local rows = {
        {"locked", "Lock bags and hide handles"},
        {"escapeCloses", "Escape closes bags"},
        {"openReagent", "Open reagent bag with backpack"},
    }
    for index, row in ipairs(rows) do
        local key = row[1]
        local button = CreateFrame("CheckButton", nil, options, "UICheckButtonTemplate")
        button:SetSize(26, 26)
        button:SetPoint("TOPLEFT", options, "TOPLEFT", 10, -34 - (index - 1) * 34)
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", button, "RIGHT", 4, 0)
        label:SetText(row[2])
        button:SetScript("OnClick", function(self) SetOption(key, self:GetChecked() == true) end)
        options.checks[key] = button
    end
    options:Hide()
end

local function AttachGear(frame)
    -- Keep input separate from the native bag header and its click router.
    local gear = CreateFrame("Button", nil, UIParent)
    gears[frame] = gear
    gear.isForeverBagMoverGear = true
    gear.ownerBag = frame
    gear:SetSize(24, 24)
    gear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -6)
    gear:EnableMouse(true)
    if gear.SetMouseClickEnabled then gear:SetMouseClickEnabled(true) end
    gear:SetFrameStrata("HIGH")
    gear:SetNormalTexture("Interface\\AddOns\\ForeverBagMover\\Media\\Movebag")
    gear:SetFrameLevel(100)
    -- Open on press, like Blizzard's header menus. Do not also toggle on
    -- OnClick, which would close the menu again when the button is released.
    gear:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        if InCombat() then Message("Wait until combat ends to change bag options."); return end
        if options:IsShown() and options.owner == frame then options:Hide(); return end
        options.owner = frame
        options:ClearAllPoints()
        options:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -4)
        SyncOptions()
        options:Show()
        GameTooltip:Hide()
    end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Bag options")
        GameTooltip:AddLine("Lock the handles and choose how bags open and close.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)
    gear:Hide()
end

local function Attach(frame)
    if not frame or handles[frame] then return end
    AttachGear(frame)
    -- A separate movable handle leaves bag item clicks and scripts intact.
    local handle = CreateFrame("Button", nil, UIParent)
    handles[frame] = handle
    handle.bag = frame
    handle:SetSize(130, HANDLE_HEIGHT)
    handle:SetMovable(true)
    handle:SetClampedToScreen(true)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:RegisterForClicks("RightButtonUp")
    local background = handle:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.04, 0.08, 0.12, 0.9)
    local label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText("Drag bag")
    handle:SetScript("OnDragStart", function(self)
        if InCombat() or db.locked or not self.bag:IsShown() then return end
        self.dragKey = BagKey(self.bag)
        if not self.dragKey then return end
        self:StartMoving()
        self.dragging = true
        AnchorBagToHandle(self)
    end)
    handle:SetScript("OnDragStop", function(self)
        StopDrag(self, true)
        Refresh()
    end)
    handle:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ChangeHandleSide(db.handleSide == "bottom" and "top" or "bottom")
            GameTooltip:Hide()
        end
    end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Forever Bag Mover")
        GameTooltip:AddLine("Drag to move this bag. Its position saves automatically.", 1, 1, 1, true)
        GameTooltip:AddLine("Right-click to switch all handles between the top and bottom of the bags.", 1, 1, 1, true)
        GameTooltip:AddLine("/bagmove lock hides these handles. /bagmove reset restores the default layout.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:HookScript("OnHide", function()
        StopDrag(handle, true)
        handle:Hide()
        gears[frame]:Hide()
        if pendingReagent == frame then pendingReagent = nil end
        if IsBackpack(frame) then pendingReagentClose = true end
        if options and options.owner == frame then options:Hide() end
    end)
    frame:HookScript("OnShow", function()
        Refresh()
        pendingRefresh = true
        QueueReagent(frame)
    end)
    if frame.CloseButton then
        frame.CloseButton:HookScript("OnClick", function()
            if escapeBags then escapeBags[frame] = nil end
        end)
    end
    handle:Hide()
    QueueReagent(frame)
end

Refresh = function()
    if not db or refreshing then return end
    refreshing = true
    if InCombat() then
        -- Keep existing windows at their saved positions. Do not create or
        -- attach handles in combat, or touch frames whose layout is restricted.
        for frame, handle in pairs(handles) do
            if gears[frame] and CanChangeLayout(gears[frame]) then gears[frame]:Hide() end
            if CanChangeLayout(handle) then
                StopDrag(handle, true)
                handle:Hide()
            end
        end
        -- Include windows first created or opened during combat, even when
        -- they do not have a handle yet.
        ForEachBag(function(frame)
            if frame:IsShown() and CanChangeLayout(frame) then
                local key = BagKey(frame)
                if key then RestorePosition(frame, db.positions[key]) end
            end
        end)
        refreshing = nil
        return
    end
    Attach(ContainerFrameCombinedBags)
    for i = 1, (NUM_CONTAINER_FRAMES or 7) do Attach(_G["ContainerFrame" .. i]) end
    for frame, handle in pairs(handles) do
        gears[frame]:SetScale(Ratio(frame))
        gears[frame]:SetShown(frame:IsShown() and IsBackpack(frame))
        local key = BagKey(frame)
        if frame:IsShown() and key then
            if handle.dragging and key ~= handle.dragKey then StopDrag(handle, false) end
            if handle.dragging then
                -- Blizzard lays bags out again when bags open, close or resize.
                AnchorBagToHandle(handle)
            else
                RestorePosition(frame, db.positions[key])
                handle:SetScale(Ratio(frame))
                handle:ClearAllPoints()
                if db.handleSide == "bottom" then
                    handle:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
                else
                    handle:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
                end
                handle:SetFrameStrata(frame:GetFrameStrata())
                handle:SetFrameLevel(frame:GetFrameLevel() + 10)
            end
            handle:SetShown(not db.locked)
        else
            StopDrag(handle, true)
            handle:Hide()
        end
    end
    refreshing = nil
    SyncOptions()
end

ChangeHandleSide = function(side)
    if InCombat() then Message("Wait until combat ends to move the handles."); return end
    -- Finish any drag using its original anchor before changing sides.
    for _, handle in pairs(handles) do StopDrag(handle, true) end
    db.handleSide = side
    Refresh()
    Message(side == "bottom" and "Handles moved below the bags. Bags can reach the top of the screen."
        or "Handles moved above the bags.")
end

local function RestoreEscapeBags()
    local closed = escapeBags
    escapeBags = nil
    if not closed or db.escapeCloses then return end
    restoringEscape = true
    for frame, key in pairs(closed) do
        if BagKey(frame) == key and not frame:IsShown() and CanChangeLayout(frame) then
            frame:Show()
            restoredBags = restoredBags + 1
        end
    end
    restoringEscape = nil
    Refresh()
end

local function Setup()
    if not db then return end
    if not InCombat() then CreateOptions() end
    if not hooked and type(UpdateContainerFrameAnchors) == "function" then
        hooksecurefunc("UpdateContainerFrameAnchors", function()
            Refresh()
            pendingRefresh = true
        end)
        hooked = true
    end
    Refresh()
    if not keyboardReady and not InCombat() then
        controller:SetFrameStrata("TOOLTIP")
        controller:EnableKeyboard(true)
        -- Always pass input through. Configure this outside combat, never
        -- consume Escape or change propagation from a combat key handler.
        controller:SetPropagateKeyboardInput(true)
        keyboardReady = true
    end
end

controller:SetScript("OnKeyDown", function(_, key)
    escapeBags = nil
    if not db or key ~= "ESCAPE" then return end
    if options then options:Hide() end
    if GetBindingAction and GetBindingAction(key) ~= "TOGGLEGAMEMENU" then return end
    escapePresses = escapePresses + 1
    if db.escapeCloses then return end
    escapeBags = {}
    ForEachBag(function(frame)
        if frame:IsShown() then escapeBags[frame] = BagKey(frame) end
    end)
end)

controller:SetScript("OnUpdate", function(_, elapsed)
    if not db then return end
    RestoreEscapeBags()
    ClosePendingReagent()
    OpenPendingReagent()
    elapsedSinceCheck = elapsedSinceCheck + elapsed
    if pendingRefresh or (InCombat() and elapsedSinceCheck >= 0.1) then
        pendingRefresh = nil
        elapsedSinceCheck = 0
        Refresh()
    end
end)

controller:RegisterEvent("ADDON_LOADED")
controller:RegisterEvent("PLAYER_LOGIN")
controller:RegisterEvent("PLAYER_REGEN_DISABLED")
controller:RegisterEvent("PLAYER_REGEN_ENABLED")
controller:RegisterEvent("DISPLAY_SIZE_CHANGED")
controller:RegisterEvent("UI_SCALE_CHANGED")
controller:RegisterEvent("PLAYER_LOGOUT")
controller:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        if type(ForeverBagMoverDB) ~= "table" then ForeverBagMoverDB = {} end
        db = ForeverBagMoverDB
        if type(db.positions) ~= "table" then db.positions = {} end
        db.locked = db.locked == true
        db.escapeCloses = db.escapeCloses == true
        db.openReagent = db.openReagent ~= false
        if db.handleSide ~= "bottom" then db.handleSide = "top" end
        Setup()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_LOGOUT" then
        if not db then return end
        if options then options:Hide() end
        if event == "PLAYER_LOGOUT" then
            escapeBags, pendingReagent, pendingReagentClose = nil, nil, nil
        end
        for _, handle in pairs(handles) do
            if not InCombat() or CanChangeLayout(handle) then
                StopDrag(handle, true)
                if event == "PLAYER_REGEN_DISABLED" then handle:Hide() end
            end
        end
        if event == "PLAYER_REGEN_DISABLED" then Refresh() end
    else
        Setup()
    end
end)

SLASH_FOREVERBAGMOVER1 = "/bagmove"
SLASH_FOREVERBAGMOVER2 = "/fbm"
SlashCmdList.FOREVERBAGMOVER = function(text)
    if not db then return end
    local command = (text or ""):lower():match("^%s*(.-)%s*$")
    local side = command:match("^anchor%s+(%a+)$")
    if command == "status" then
        Message("Version " .. VERSION .. ". Combat: " .. tostring(InCombat() == true)
            .. ". Keyboard ready: " .. tostring(keyboardReady == true)
            .. ". Escape presses: " .. escapePresses .. ". Bags restored: " .. restoredBags .. ".")
        ForEachBag(function(frame)
            if frame:IsShown() then
                local key = BagKey(frame)
                Message((frame:GetName() or "Bag") .. ": " .. (key or "unknown slot")
                    .. ", saved: " .. tostring(key and ValidPosition(db.positions[key]) or false)
                    .. ", changes allowed: " .. tostring(CanChangeLayout(frame)) .. ".")
            end
        end)
    elseif command == "options" then
        if InCombat() then Message("Wait until combat ends to change bag options."); return end
        options.owner = nil
        options:ClearAllPoints()
        options:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        SyncOptions()
        options:Show()
    elseif side == "top" or side == "bottom" then
        ChangeHandleSide(side)
    elseif command == "reset" or command == "lock" or command == "unlock" then
        if InCombat() then Message("Wait until combat ends to change bag positions."); return end
        for _, handle in pairs(handles) do StopDrag(handle, true) end
        if command == "reset" then
            db.positions = {}
            if UpdateContainerFrameAnchors then UpdateContainerFrameAnchors() end
            Message("Default bag positions restored.")
        else
            db.locked = command == "lock"
            Message(db.locked and "Handles hidden. Positions still save." or "Handles shown. Open your bags and drag a handle.")
        end
        Refresh()
    else
        Message("Open your bags and drag a handle. Right-click a handle to switch it between top and bottom.")
        Message("/bagmove anchor bottom lets bags reach the top of the screen. /bagmove anchor top puts handles above the bags.")
        Message("/bagmove lock hides handles. /bagmove unlock shows them. /bagmove reset restores the default layout.")
        Message("/bagmove status shows the version and combat/Escape checks.")
        Message("Click the backpack gear or use /bagmove options to change bag options.")
    end
end
