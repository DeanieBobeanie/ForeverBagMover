local frames, combat, nativeLayout = {}, false, false
local Frame = {}
Frame.__index = Frame
local function noop() end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({kind=kind, name=name, parent=parent, shown=true, scale=1,
        width=160, height=200, left=0, top=400, scripts={}, events={}}, Frame)
    frames[#frames+1] = frame
    if name then _G[name] = frame end
    return frame
end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end; fn(...) end
end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:SetSize(w,h) self.width=w; self.height=h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetScale(value) self.scale=value end
function Frame:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:GetID() return self.id end
function Frame:GetName() return self.name end
function Frame:GetBagID() return self.id end
function Frame:IsForbidden() return self.forbidden == true end
function Frame:CanChangeProtectedState()
    return not self.forbidden and not (combat and (self.protected or self.ancestorRestricted))
end
local function assertPositionAllowed(frame)
    assert(nativeLayout or frame:CanChangeProtectedState(), 'Attempt to change a restricted frame position')
end
function Frame:SetPoint(point, relative, target, x, y)
    assertPositionAllowed(self)
    assert(relative ~= self, 'self anchor')
    local ancestor = relative
    for i=1,30 do
        if not ancestor then break end
        assert(ancestor ~= self, 'circular anchor')
        ancestor = ancestor.anchor and ancestor.anchor.relative
    end
    self.anchor = {point=point,relative=relative,target=target,x=x or 0,y=y or 0}
end
function Frame:ClearAllPoints() assertPositionAllowed(self); self.anchor=nil end
function Frame:GetPoint()
    local a=self.anchor
    if a then return a.point,a.relative,a.target,a.x,a.y end
end
function Frame:Rect()
    local a = self.anchor
    if not a then return self.left,self.top end
    local left, top = a.relative:Rect()
    local ratio = a.relative:GetEffectiveScale()/self:GetEffectiveScale()
    left, top = left*ratio, top*ratio
    if a.target == 'BOTTOMLEFT' then top=top-a.relative.height*ratio end
    if a.target == 'BOTTOMRIGHT' then left=left+a.relative.width*ratio; top=top-a.relative.height*ratio end
    if a.target == 'TOPRIGHT' then left=left+a.relative.width*ratio end
    left,top=left+a.x,top+a.y
    if a.point == 'BOTTOMLEFT' then top=top+self.height end
    if a.point == 'BOTTOMRIGHT' then top=top+self.height; left=left-self.width end
    return left,top
end
function Frame:GetLeft() local left=self:Rect(); return left end
function Frame:GetTop() local _,top=self:Rect(); return top end
function Frame:StartMoving() self.left,self.top=self:Rect(); self.anchor=nil; self.moving=true end
function Frame:StopMovingOrSizing() self.moving=false end
function Frame:IsShown() return self.shown end
function Frame:Show()
    assert(nativeLayout or self:CanChangeProtectedState(), 'Attempt to show a restricted frame')
    local old=self.shown; self.shown=true
    if not old and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Frame:Hide() local old=self.shown; self.shown=false; if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:SetShown(value) if value then self:Show() else self:Hide() end end
function Frame:SetChecked(value) self.checked=value end
function Frame:GetChecked() return self.checked end
function Frame:SetNormalTexture(value) self.normalTexture=value end
Frame.SetHighlightTexture=noop
function Frame:GetFrameStrata() return self.strata or 'MEDIUM' end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:CreateTexture() return {SetAllPoints=noop,SetColorTexture=noop,SetSize=noop,SetPoint=noop,SetRotation=noop} end
function Frame:CreateFontString() return {SetPoint=noop,SetText=noop} end
Frame.SetMovable=noop; Frame.SetClampedToScreen=noop
function Frame:EnableMouse(value) self.mouseEnabled=value end
function Frame:SetMouseClickEnabled(value) self.mouseClickEnabled=value end
function Frame:SetFrameStrata(value) self.strata=value end
function Frame:SetFrameLevel(value) self.level=value end
Frame.RegisterForDrag=noop; Frame.RegisterForClicks=noop
function Frame:EnableKeyboard(value) assert(not combat); self.keyboard=value end
function Frame:SetPropagateKeyboardInput(value)
    assert(not combat and value == true, 'Keyboard input must always pass through')
    self.propagate=value
end
local escapeBinding='TOGGLEGAMEMENU'
function GetBindingAction() return escapeBinding end
local function keyDown(key)
    for _,frame in ipairs(frames) do
        if frame.keyboard and frame.scripts.OnKeyDown then
            assert(frame.propagate)
            frame.scripts.OnKeyDown(frame,key)
        end
    end
end
local function tick()
    for _,frame in ipairs(frames) do
        if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame,0.11) end
    end
end
function InCombatLockdown() return combat end
function hooksecurefunc(name, fn)
    assert(name=='UpdateContainerFrameAnchors', 'Unexpected native hook')
    local original=_G[name]
    _G[name]=function(...) local result=original(...); fn(...); return result end
end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=noop}
GameTooltip={SetOwner=noop,SetText=noop,AddLine=noop,Show=noop,Hide=noop}
UIParent=CreateFrame('Frame'); UIParent:SetSize(1920,1080); UIParent.top=1080
NUM_TOTAL_BAG_FRAMES=5; NUM_CONTAINER_FRAMES=2
ContainerFrame1=CreateFrame('Frame','ContainerFrame1',UIParent); ContainerFrame1.id=0
ContainerFrame2=CreateFrame('Frame','ContainerFrame2',UIParent); ContainerFrame2.id=1
ContainerFrameCombinedBags=CreateFrame('Frame','ContainerFrameCombinedBags',UIParent); ContainerFrameCombinedBags.id=0
ContainerFrameCombinedBags:SetSize(480,600); ContainerFrameCombinedBags:Hide()
local function layout()
    nativeLayout=true
    for _,frame in ipairs({ContainerFrame1,ContainerFrame2,ContainerFrameCombinedBags}) do
        if frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-10,85)
        end
    end
    nativeLayout=false
end
UpdateContainerFrameAnchors=layout
layout()
-- Model native closing, including the captured handler used by Forever.
UISpecialFrames={}
local menuOpens, dialogShown, nativeCloses, nativeEscape = 0, false, 0, false
local dispatching, vendorShown, missBags = false, false, false
function debugstack()
    error('Escape must not depend on call-stack text')
end
function CloseAllBags()
    assert(nativeEscape, 'CloseAllBags must be called by the native Escape path, not the add-on')
    nativeCloses=nativeCloses+1
    local closed=false
    if not missBags then
        local bags={ContainerFrameCombinedBags}
        for i=1,NUM_CONTAINER_FRAMES do bags[#bags+1]=_G['ContainerFrame'..i] end
        for _,frame in ipairs(bags) do
            if frame:IsShown() then frame:Hide(); closed=true end
        end
    end
    return closed
end
local originalCloseAllBags=CloseAllBags
local function closeSpecialWindows()
    local closed=false
    for _,name in pairs(UISpecialFrames) do
        local frame=_G[name]
        if frame and frame:IsShown() then frame:Hide(); closed=true end
    end
    return closed
end
if escapeMode=='modern' then
    GameMenuEscPriority={AddOn=8}
    function RegisterGameMenuEscHandler()
        error('The add-on must not register a callback in the game-menu Escape dispatcher')
    end
else
    RegisterGameMenuEscHandler=nil
    GameMenuEscPriority=nil
end
function CloseAllWindows()
    local bagsClosed=CloseAllBags()
    local windowsClosed=closeSpecialWindows()
    if vendorShown then vendorShown=false; windowsClosed=true end
    return bagsClosed or windowsClosed
end
local capturedCloseAllWindows=CloseAllWindows
function ToggleGameMenu()
    if dialogShown then dialogShown=false; return true end
    nativeEscape=true
    local closed=capturedCloseAllWindows()
    nativeEscape=false
    if closed then return true end
    menuOpens=menuOpens+1
    return false
end
local function pressEscape()
    keyDown('ESCAPE')
    dispatching=true
    local result=ToggleGameMenu()
    dispatching=false
    tick()
    return result
end
local function closeWithBagKey()
    keyDown('B')
    nativeEscape=true
    CloseAllBags()
    nativeEscape=false
    tick()
end
-- LOAD ADDON HERE
local controller=frames[#frames]
local function event(name,arg) controller.scripts.OnEvent(controller,name,arg) end
local function handleFor(bag)
    for _,frame in ipairs(frames) do if frame.bag==bag then return frame end end
    error('missing handle')
end
local function near(a,b) assert(math.abs(a-b)<0.001,tostring(a)..' ~= '..tostring(b)) end
local function drag(bag,left,top,stop)
    local handle=handleFor(bag)
    handle.scripts.OnDragStart(handle)
    assert(handle.moving)
    handle.left=left
    handle.top=ForeverBagMoverDB.handleSide == 'bottom' and top-bag:GetHeight() or top+20
    if stop ~= false then handle.scripts.OnDragStop(handle) end
    return handle
end
event('ADDON_LOADED','ForeverBagMover')
event('PLAYER_LOGIN')
event('ADDON_LOADED','UnrelatedAddon')
assert(#UISpecialFrames==0)
assert(CloseAllBags==originalCloseAllBags)
assert(CloseAllWindows==capturedCloseAllWindows)
assert(nativeCloses==0)
assert(ForeverBagMoverDB.handleSide=='top')
drag(ContainerFrame1,400,700)
near(ContainerFrame1:GetLeft(),400); near(ContainerFrame1:GetTop(),700)
UpdateContainerFrameAnchors()
near(ContainerFrame1:GetLeft(),400)
ContainerFrame1:Hide(); ContainerFrame1:Show(); UpdateContainerFrameAnchors()
near(ContainerFrame1:GetLeft(),400)
-- Frame names are reused when bags open in a different order.
ContainerFrame1.id=1; ContainerFrame2.id=0
UpdateContainerFrameAnchors()
near(ContainerFrame2:GetLeft(),400)
assert(ContainerFrame1:GetLeft()~=400)
drag(ContainerFrame1,800,650)
near(ForeverBagMoverDB.positions.bag1.x,800/1920)
ContainerFrame1:Hide(); ContainerFrame2:Hide(); ContainerFrameCombinedBags:Show()
drag(ContainerFrameCombinedBags,600,800)
near(ForeverBagMoverDB.positions.combined.x,600/1920)
assert(ForeverBagMoverDB.positions.bag0 and ForeverBagMoverDB.positions.bag1)
-- A layout refresh while dragging must keep following the handle.
local handle=drag(ContainerFrameCombinedBags,500,750,false)
UpdateContainerFrameAnchors()
near(ContainerFrameCombinedBags:GetLeft(),500)
handle.left=550
near(ContainerFrameCombinedBags:GetLeft(),550)
handle.scripts.OnDragStop(handle)
-- Blizzard may reset layout before our combat event arrives. Recover the
-- position from the moving handle, not the reset bag frame.
drag(ContainerFrameCombinedBags,450,700,false)
combat=true
UpdateContainerFrameAnchors()
event('PLAYER_REGEN_DISABLED')
assert(not handle.moving and not handle:IsShown())
near(ContainerFrameCombinedBags:GetLeft(),450)
near(ContainerFrameCombinedBags:GetTop(),700)
local saved=ForeverBagMoverDB.positions.combined
near(saved.x,450/1920)
near(saved.y,700/1080)
for i=1,3 do
    UpdateContainerFrameAnchors()
    near(ContainerFrameCombinedBags:GetLeft(),450)
    near(ContainerFrameCombinedBags:GetTop(),700)
    assert(not handle:IsShown())
end
ContainerFrameCombinedBags:Hide(); ContainerFrameCombinedBags:Show()
UpdateContainerFrameAnchors()
near(ContainerFrameCombinedBags:GetLeft(),450)
assert(not handle:IsShown())
-- A late native layout, or a caller holding the original function, can
-- bypass the global hook after OnShow. The next update must correct it.
ContainerFrameCombinedBags:Hide(); ContainerFrameCombinedBags:Show()
layout()
assert(ContainerFrameCombinedBags.anchor.point=='BOTTOMRIGHT')
tick()
near(ContainerFrameCombinedBags:GetLeft(),450)
layout(); tick()
near(ContainerFrameCombinedBags:GetLeft(),450)
-- Bags that did not exist when handles were attached still get positions.
NUM_CONTAINER_FRAMES=3
local lateBag=CreateFrame('Frame','ContainerFrame3',UIParent); lateBag.id=2
ForeverBagMoverDB.positions.bag2={x=0.25,y=0.75}
tick()
near(lateBag:GetLeft(),480); near(lateBag:GetTop(),810)
lateBag:Hide(); NUM_CONTAINER_FRAMES=2; ContainerFrame3=nil
-- Restricted frames must be left to Blizzard during combat.
for _,restriction in ipairs({'protected','ancestorRestricted','forbidden'}) do
    ContainerFrameCombinedBags[restriction]=true
    UpdateContainerFrameAnchors()
    assert(ContainerFrameCombinedBags.anchor.point=='BOTTOMRIGHT')
    assert(ForeverBagMoverDB.positions.combined==saved)
    ContainerFrameCombinedBags[restriction]=nil
    UpdateContainerFrameAnchors()
    near(ContainerFrameCombinedBags:GetLeft(),450)
end
SlashCmdList.FOREVERBAGMOVER('reset')
assert(ForeverBagMoverDB.positions.combined==saved)
handle.scripts.OnDragStart(handle); assert(not handle.moving)
combat=false; event('PLAYER_REGEN_ENABLED')
near(ContainerFrameCombinedBags:GetLeft(),450); assert(handle:IsShown())
SlashCmdList.FOREVERBAGMOVER('lock'); assert(not handle:IsShown())
UpdateContainerFrameAnchors(); near(ContainerFrameCombinedBags:GetLeft(),450)
SlashCmdList.FOREVERBAGMOVER('unlock'); assert(handle:IsShown())
-- A completed drag and separate bag windows must also survive combat relayout.
ContainerFrameCombinedBags:Hide(); ContainerFrame1:Show(); ContainerFrame2:Show()
combat=true; event('PLAYER_REGEN_DISABLED')
UpdateContainerFrameAnchors()
near(ContainerFrame1:GetLeft(),800); near(ContainerFrame2:GetLeft(),400)
assert(not handleFor(ContainerFrame1):IsShown() and not handleFor(ContainerFrame2):IsShown())
combat=false; event('PLAYER_REGEN_ENABLED')
ContainerFrame1:Hide(); ContainerFrame2:Hide(); ContainerFrameCombinedBags:Show()
-- Close a bag mid-drag, then reopen it.
drag(ContainerFrameCombinedBags,350,700,false)
ContainerFrameCombinedBags:Hide(); assert(not handle.moving and not handle:IsShown())
ContainerFrameCombinedBags:Show(); near(ContainerFrameCombinedBags:GetLeft(),350)
-- Bottom handles let the bag reach the screen's top edge, including after
-- Blizzard lays bags out again and after closing and reopening the window.
SlashCmdList.FOREVERBAGMOVER('anchor bottom')
assert(ForeverBagMoverDB.handleSide=='bottom')
near(ContainerFrameCombinedBags:GetLeft(),350)
near(ContainerFrameCombinedBags:GetTop(),700)
assert(handle.anchor.point=='TOPLEFT' and handle.anchor.target=='BOTTOMLEFT')
drag(ContainerFrameCombinedBags,350,1080,false)
UpdateContainerFrameAnchors()
near(ContainerFrameCombinedBags:GetTop(),1080)
handle.scripts.OnDragStop(handle)
near(ContainerFrameCombinedBags:GetTop(),1080)
near(handle:GetTop(),480)
near(ForeverBagMoverDB.positions.combined.y,1)
ContainerFrameCombinedBags:Hide(); ContainerFrameCombinedBags:Show()
near(ContainerFrameCombinedBags:GetTop(),1080)
-- Switching sides during a drag must not create circular anchors or jump.
drag(ContainerFrameCombinedBags,350,700,false)
handle.scripts.OnClick(handle,'RightButton')
assert(ForeverBagMoverDB.handleSide=='top' and not handle.moving)
near(ContainerFrameCombinedBags:GetTop(),700)
handle.scripts.OnClick(handle,'RightButton')
assert(ForeverBagMoverDB.handleSide=='bottom')
near(ContainerFrameCombinedBags:GetTop(),700)
-- Keep the bottom handle visible when releasing a bag at the bottom edge.
drag(ContainerFrameCombinedBags,350,600)
near(ContainerFrameCombinedBags:GetTop(),620)
near(handle:GetTop()-handle:GetHeight(),0)
combat=true
SlashCmdList.FOREVERBAGMOVER('anchor top')
handle.scripts.OnClick(handle,'RightButton')
assert(ForeverBagMoverDB.handleSide=='bottom')
combat=false
SlashCmdList.FOREVERBAGMOVER('anchor sideways')
assert(ForeverBagMoverDB.handleSide=='bottom')
-- Hidden handles can be moved through the command as well.
SlashCmdList.FOREVERBAGMOVER('lock')
SlashCmdList.FOREVERBAGMOVER('anchor top')
assert(not handle:IsShown() and ForeverBagMoverDB.handleSide=='top')
SlashCmdList.FOREVERBAGMOVER('unlock')
drag(ContainerFrameCombinedBags,350,700)
-- Escape restores only windows closed by that dispatch. Dialogs run first.
dialogShown=true
assert(pressEscape() and ContainerFrameCombinedBags:IsShown())
assert(pressEscape() and ContainerFrameCombinedBags:IsShown())
assert(handle:IsShown() and menuOpens==0)
near(ContainerFrameCombinedBags:GetLeft(),350)
near(ContainerFrameCombinedBags:GetTop(),700)
-- Repeated Escape must not register additional hooks or open hidden bags.
for i=1,3 do
    assert(pressEscape() and ContainerFrameCombinedBags:IsShown())
    assert(not ContainerFrame1:IsShown() and not ContainerFrame2:IsShown())
end
-- An interrupted drag saves its final position before restoring the bag.
drag(ContainerFrameCombinedBags,360,720,false)
assert(pressEscape() and not handle.moving and handle:IsShown())
near(ContainerFrameCombinedBags:GetLeft(),360)
near(ContainerFrameCombinedBags:GetTop(),720)
SlashCmdList.FOREVERBAGMOVER('lock')
assert(pressEscape() and ContainerFrameCombinedBags:IsShown())
assert(not handle:IsShown())
SlashCmdList.FOREVERBAGMOVER('unlock')
-- X, bag keys, and non-Escape closes must stay closed.
ContainerFrameCombinedBags:Hide()
assert(not handle:IsShown())
assert(not pressEscape() and menuOpens==1)
assert(not ContainerFrameCombinedBags:IsShown())
ContainerFrame1:Show(); ContainerFrame2:Show()
assert(pressEscape())
assert(ContainerFrame1:IsShown() and ContainerFrame2:IsShown())
closeWithBagKey()
assert(not ContainerFrame1:IsShown() and not ContainerFrame2:IsShown())
-- A partial selection remains partial when Escape also closes a vendor.
ContainerFrame2:Show(); vendorShown=true
assert(pressEscape() and not vendorShown)
assert(ContainerFrame2:IsShown() and not ContainerFrame1:IsShown())
ContainerFrame2:Hide()
ContainerFrameCombinedBags:Show()
combat=true; event('PLAYER_REGEN_DISABLED')
assert(pressEscape() and ContainerFrameCombinedBags:IsShown())
assert(not handle:IsShown())
near(ContainerFrameCombinedBags:GetLeft(),360)
for _,restriction in ipairs({'protected','ancestorRestricted','forbidden'}) do
    ContainerFrameCombinedBags[restriction]=true
    assert(pressEscape() and not ContainerFrameCombinedBags:IsShown())
    ContainerFrameCombinedBags[restriction]=nil
    assert(not pressEscape()) -- A skipped restoration must not remain queued.
    ContainerFrameCombinedBags:Show()
end
combat=false; event('PLAYER_REGEN_ENABLED')
assert(handle:IsShown())
SlashCmdList.FOREVERBAGMOVER('anchor bottom')
assert(pressEscape() and ContainerFrameCombinedBags:IsShown())
SlashCmdList.FOREVERBAGMOVER('anchor top')
-- If Blizzard misses a bag, it stays open without an extra close registration.
missBags=true
assert(not pressEscape() and ContainerFrameCombinedBags:IsShown())
missBags=false
closeWithBagKey()
assert(not ContainerFrameCombinedBags:IsShown())
ContainerFrameCombinedBags:Show()
drag(ContainerFrameCombinedBags,350,700)
assert(nativeCloses>0 and #UISpecialFrames==0)
-- Escape followed by an explicit bag key before the next update stays closed.
keyDown('ESCAPE')
closeWithBagKey()
assert(not ContainerFrameCombinedBags:IsShown())
ContainerFrameCombinedBags:Show()
-- Honor a remapped Escape and do not retain stale snapshots.
escapeBinding='SOMEOTHERBINDING'
assert(pressEscape() and not ContainerFrameCombinedBags:IsShown())
escapeBinding='TOGGLEGAMEMENU'
ContainerFrameCombinedBags:Show()
SlashCmdList.FOREVERBAGMOVER('status')
-- Coordinates survive changed scales and fit a smaller screen.
ContainerFrameCombinedBags:SetScale(0.8); UIParent:SetScale(0.75)
event('UI_SCALE_CHANGED')
near(ContainerFrameCombinedBags:GetLeft()*0.8,350)
ForeverBagMoverDB.positions.combined={x=0.99,y=0.99}
UIParent:SetSize(800,600); UIParent.top=600
event('DISPLAY_SIZE_CHANGED')
assert((ContainerFrameCombinedBags:GetLeft()+480)*0.8<=800.001)
assert((ContainerFrameCombinedBags:GetTop()+20)*0.8<=600.001)
assert(ContainerFrameCombinedBags:GetTop()>=600)
SlashCmdList.FOREVERBAGMOVER('anchor bottom')
drag(ContainerFrameCombinedBags,200,750)
near(ContainerFrameCombinedBags:GetTop()*0.8,600)
near(handle:GetTop()*0.8,120)
UpdateContainerFrameAnchors()
near(ContainerFrameCombinedBags:GetTop()*0.8,600)
-- A bottom handle at a different UI scale remains authoritative if combat
-- starts during a drag. Locking handles must not disable combat positioning.
drag(ContainerFrameCombinedBags,210,750,false)
combat=true; UpdateContainerFrameAnchors(); event('PLAYER_REGEN_DISABLED')
near(ContainerFrameCombinedBags:GetLeft()*0.8,168)
near(ContainerFrameCombinedBags:GetTop()*0.8,600)
assert(not handle.moving and not handle:IsShown())
combat=false; event('PLAYER_REGEN_ENABLED')
SlashCmdList.FOREVERBAGMOVER('lock')
combat=true; event('PLAYER_REGEN_DISABLED'); UpdateContainerFrameAnchors()
near(ContainerFrameCombinedBags:GetLeft()*0.8,168)
near(ContainerFrameCombinedBags:GetTop()*0.8,600)
assert(not handle:IsShown())
combat=false; event('PLAYER_REGEN_ENABLED')
SlashCmdList.FOREVERBAGMOVER('unlock')
-- The same setting applies to individual bags without changing their keys.
ContainerFrameCombinedBags:Hide(); ContainerFrame2:Show()
drag(ContainerFrame2,100,1080)
near(ContainerFrame2:GetTop(),600)
near(handleFor(ContainerFrame2):GetTop(),400)
assert(ForeverBagMoverDB.positions.bag0)
ContainerFrame2:Hide(); ContainerFrameCombinedBags:Show()
-- The gear remains accessible when handles are locked and follows bag IDs.
local function gearFor(bag)
    for _,frame in ipairs(frames) do
        if frame.ownerBag==bag and frame.isForeverBagMoverGear then return frame end
    end
    error('missing gear')
end
local function chooseOption(key, value)
    local check=ForeverBagMoverOptions.checks[key]
    check:SetChecked(value)
    check.scripts.OnClick(check)
end
local gear=gearFor(ContainerFrameCombinedBags)
assert(gear:IsShown())
assert(gear.parent==UIParent and gear.mouseEnabled and gear.mouseClickEnabled)
assert(gear:GetFrameStrata()=='HIGH')
-- A header can take the release event. The menu must already be open on
-- press, and a normal full click must not toggle it a second time.
gear.scripts.OnMouseDown(gear,'LeftButton')
if gear.scripts.OnClick then gear.scripts.OnClick(gear,'LeftButton') end
assert(ForeverBagMoverOptions:IsShown())
gear.scripts.OnMouseDown(gear,'RightButton')
assert(ForeverBagMoverOptions:IsShown())
gear.scripts.OnMouseDown(gear,'LeftButton')
assert(not ForeverBagMoverOptions:IsShown())
gear.scripts.OnMouseDown(gear,'LeftButton')
chooseOption('locked',true)
assert(ForeverBagMoverDB.locked and not handle:IsShown() and gear:IsShown())
chooseOption('locked',false)
assert(handle:IsShown())
chooseOption('escapeCloses',true)
assert(pressEscape() and not ContainerFrameCombinedBags:IsShown())
assert(not ForeverBagMoverOptions:IsShown())
ContainerFrameCombinedBags:Show()
chooseOption('escapeCloses',false)
assert(pressEscape() and ContainerFrameCombinedBags:IsShown())
combat=true; event('PLAYER_REGEN_DISABLED')
assert(not gear:IsShown())
chooseOption('locked',true)
assert(not ForeverBagMoverDB.locked)
gear.scripts.OnMouseDown(gear,'LeftButton')
assert(not ForeverBagMoverOptions:IsShown())
combat=false; event('PLAYER_REGEN_ENABLED')
ContainerFrameCombinedBags:Hide(); ContainerFrame1:Show(); ContainerFrame2:Show()
assert(not gear:IsShown())
assert(not gearFor(ContainerFrame1):IsShown()) -- ID 1 after earlier frame reuse
assert(gearFor(ContainerFrame2):IsShown()) -- Backpack is now in frame 2
near(gearFor(ContainerFrame2):GetEffectiveScale(), ContainerFrame2:GetEffectiveScale())
ContainerFrame1:Hide(); ContainerFrame2:Hide()

-- Reagent opening follows backpack openings, not every layout refresh.
NUM_CONTAINER_FRAMES=3
local reagent=CreateFrame('Frame','ContainerFrame3',UIParent); reagent.id=5; reagent:Hide()
local reagentSlots, reagentOpens, mergedReagent = 32, 0, false
C_Container={GetContainerNumSlots=function(id) assert(id==5); return reagentSlots end}
function Frame:CanUseForBagID(id) return self==reagent and id==5 end
function ContainerFrameUtil_EnumerateContainerFrames()
    return ipairs({ContainerFrameCombinedBags,ContainerFrame1,ContainerFrame2,reagent})
end
function IsBagOpen(id)
    assert(id==5)
    return reagent:IsShown() or (mergedReagent and ContainerFrameCombinedBags:IsShown())
end
function OpenBag(id)
    assert(id==5)
    reagentOpens=reagentOpens+1
    reagent:Show()
end
event('ADDON_LOADED','ReagentTest')
assert(ForeverBagMoverDB.openReagent)
ContainerFrameCombinedBags:Show(); tick()
assert(reagent:IsShown() and reagentOpens==1)
tick(); UpdateContainerFrameAnchors(); tick()
assert(reagentOpens==1)
reagent:Hide(); tick()
assert(not reagent:IsShown()) -- A manual close is respected.
assert(pressEscape() and not reagent:IsShown()) -- Restore does not reopen it.
closeWithBagKey()
ContainerFrame2:Show(); tick()
assert(reagent:IsShown() and reagentOpens==2)
closeWithBagKey()
ContainerFrame2:Show(); reagent:Show(); tick() -- Shift+B already opened both.
assert(reagentOpens==2)
closeWithBagKey()
ContainerFrame2:Show(); ContainerFrame2:Hide(); tick()
assert(not reagent:IsShown()) -- Cancel an opening if backpack closes first.
reagentSlots=0
ContainerFrame2:Show(); tick()
assert(not reagent:IsShown() and reagentOpens==2)
ContainerFrame2:Hide(); reagentSlots=32
chooseOption('openReagent',false)
ContainerFrameCombinedBags:Show(); tick()
assert(not reagent:IsShown())
chooseOption('openReagent',true); tick()
assert(reagent:IsShown() and reagentOpens==3)
closeWithBagKey()
combat=true; event('PLAYER_REGEN_DISABLED')
ContainerFrameCombinedBags:Show(); tick()
assert(reagent:IsShown() and reagentOpens==4)
closeWithBagKey()
reagent.protected=true
ContainerFrameCombinedBags:Show(); tick()
assert(not reagent:IsShown() and reagentOpens==4)
reagent.protected=nil
combat=false; event('PLAYER_REGEN_ENABLED')
closeWithBagKey()
mergedReagent=true
ContainerFrameCombinedBags:Show(); tick()
assert(not reagent:IsShown() and reagentOpens==4)
mergedReagent=false
chooseOption('openReagent',false)
-- A main-bag X or combined-backpack toggle can leave the reagent bag open
-- in Blizzard's close path. Close it after confirming the backpack stayed shut.
reagent:Show()
ContainerFrameCombinedBags:Hide(); tick()
assert(not reagent:IsShown())
ContainerFrame2:Show(); reagent:Show()
ContainerFrame2:Hide(); tick()
assert(not reagent:IsShown())
-- Keep both bags with Escape retention, including when the native close
-- path hides only the backpack. Enabling Escape closing should close both.
ContainerFrameCombinedBags:Show(); reagent:Show()
chooseOption('escapeCloses',false)
keyDown('ESCAPE'); ContainerFrameCombinedBags:Hide(); tick()
assert(ContainerFrameCombinedBags:IsShown() and reagent:IsShown())
chooseOption('escapeCloses',true)
keyDown('ESCAPE'); ContainerFrameCombinedBags:Hide(); tick()
assert(not ContainerFrameCombinedBags:IsShown() and not reagent:IsShown())
chooseOption('escapeCloses',false)
-- A mode switch or quick reopen should not close the reagent bag afterward.
ContainerFrameCombinedBags:Show(); reagent:Show()
ContainerFrameCombinedBags:Hide(); ContainerFrame2:Show(); tick()
assert(reagent:IsShown())
ContainerFrame2:Hide(); ContainerFrame2:Show(); tick()
assert(reagent:IsShown())
-- Combat closing works for ordinary frames and leaves restricted ones alone.
combat=true; event('PLAYER_REGEN_DISABLED')
ContainerFrame2:Hide(); tick()
assert(not reagent:IsShown())
ContainerFrame2:Show(); reagent:Show(); reagent.protected=true
ContainerFrame2:Hide(); tick()
assert(reagent:IsShown())
reagent.protected=nil; combat=false; event('PLAYER_REGEN_ENABLED')
tick()
assert(reagent:IsShown()) -- A skipped close does not linger after combat.
reagent:Hide()
-- Opening the reagent bag by itself must still be possible.
reagent:Show(); tick()
assert(reagent:IsShown())
reagent:Hide(); ContainerFrameCombinedBags:Show()
-- Reset removes both modes and lets the default layout run again.
SlashCmdList.FOREVERBAGMOVER('reset')
assert(next(ForeverBagMoverDB.positions)==nil)
assert(ContainerFrameCombinedBags.anchor.point=='BOTTOMRIGHT')
-- Simulate a fresh login with saved data and no old hooks or handles.
for _,frame in ipairs(frames) do frame.keyboard=false; frame.scripts.OnUpdate=nil end
ForeverBagMoverDB={positions={combined={x=0.2,y=1}},locked=true,handleSide='bottom',escapeCloses=true,openReagent=false}
for _,bag in ipairs({ContainerFrame1,ContainerFrame2,ContainerFrameCombinedBags}) do bag.scripts={} end
UpdateContainerFrameAnchors=layout
