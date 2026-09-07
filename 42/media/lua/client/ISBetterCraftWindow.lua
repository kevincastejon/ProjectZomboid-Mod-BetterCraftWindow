require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISUIElement"
require "Entity/ISEntityUI"
require "ISBCWHandCraftPanel"

ISBetterCraftWindow = ISCollapsableWindow:derive("ISBetterCraftWindow")

ISBetterCraftWindow.instances = {}
ISBetterCraftWindow.SCAN_RADIUS = 3
ISBetterCraftWindow.SCAN_INTERVAL = 60
ISBetterCraftWindow.DEBUG_WORKSTATION_SCAN = true

local function bcwNowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    return 0
end
ISBetterCraftWindow.TAB_HEIGHT = 28
ISBetterCraftWindow.TAB_MARGIN = 6
ISBetterCraftWindow.TAB_GAP = 4

local function getCraftBench(obj)
    if not obj then
        return nil
    end
    return obj:getComponent(ComponentType.CraftBench)
end

local function getWorkstationName(obj)
    if not obj then
        return "Workstation"
    end

    local props = obj:getProperties()
    if props and props:has("CustomName") then
        local customName = props:get("CustomName")
        if customName and customName ~= "" then
            return tostring(customName)
        end
    end

    local name = obj:getName()
    if name and name ~= "" then
        return tostring(name)
    end

    return "Workstation"
end

local function getDistance(player, obj)
    if not player or not obj or not obj:getSquare() then
        return 999999
    end
    return obj:getSquare():DistToProper(player)
end

local function findEntry(list, obj)
    if not list or not obj then
        return nil
    end

    for _, entry in ipairs(list) do
        if entry.isoObject == obj then
            return entry
        end
    end

    return nil
end

function ISBetterCraftWindow:scanWorkstations()
    local _bcwScanStart = bcwNowMs()
    local result = {}

    if not self.player or not self.player:getSquare() then
        return result
    end

    local sx = math.floor(self.player:getX())
    local sy = math.floor(self.player:getY())
    local sz = math.floor(self.player:getZ())
    local radius = ISBetterCraftWindow.SCAN_RADIUS

    for x = sx - radius, sx + radius do
        for y = sy - radius, sy + radius do
            local square = getCell():getGridSquare(x, y, sz)

            -- Do not pre-filter workstation squares with canReachTo().
            -- Multi-tile workstations may expose an interactable tile near the
            -- player while the actual IsoObject carrying the CraftBench
            -- component is anchored on another square that fails canReachTo().
            --
            -- For tab discovery BCW only needs to know that the CraftBench
            -- exists nearby. Actual usability/ownership is handled later when
            -- the workstation tab is selected.
            if square then
                local objects = square:getObjects()

                -- Unlike vanilla FindCraftSurface(), BCW is enumerating actual
                -- workstation entities, not looking for a generic crafting
                -- surface. Some CraftBench objects can legitimately be the
                -- first (index 0) or the only object on their square.
                --
                -- Starting at index 1 made those workstations invisible to the
                -- periodic scan. A direct world click could inject one into
                -- the tab list, but the next scan would fail to rediscover it
                -- and remove the tab again.
                if objects and objects:size() > 0 then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        local craftBench = getCraftBench(obj)

                        if craftBench and not findEntry(result, obj) then
                            -- Match vanilla HandcraftLogic:isCharacterInRangeOfWorkbench().
                            -- Vanilla does NOT use the square scan radius or canReachTo()
                            -- for a specific CraftBench. It validates the exact
                            -- workstation IsoObject with:
                            --     isoObject:getSquare():DistToProper(player) < 3
                            local distance = getDistance(self.player, obj)

                            if distance < 3.0 then
                                table.insert(result, {
                                    isoObject = obj,
                                    craftBench = craftBench,
                                    name = getWorkstationName(obj),
                                    distance = distance
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(result, function(a, b)
        if a.distance ~= b.distance then
            return a.distance < b.distance
        end
        return a.name < b.name
    end)
    for _, entry in ipairs(result) do
        entry.displayName = entry.name
    end

    if ISBetterCraftWindow.DEBUG_WORKSTATION_SCAN then
        local ps = self.player and self.player:getSquare()
        print(string.format(
            "[BCW SCAN] scan=%dms player=%d,%d,%d found=%d",
            bcwNowMs() - _bcwScanStart,
            ps and ps:getX() or -1,
            ps and ps:getY() or -1,
            ps and ps:getZ() or -1,
            #result
        ))

        for _, entry in ipairs(result) do
            local sq = entry.isoObject and entry.isoObject:getSquare()
            print(string.format(
                "[BCW SCAN]   + %s anchor=%d,%d,%d dist=%.2f",
                tostring(entry.displayName or entry.name or "?"),
                sq and sq:getX() or -1,
                sq and sq:getY() or -1,
                sq and sq:getZ() or -1,
                tonumber(entry.distance) or -1
            ))
        end
    end

    return result
end

function ISBetterCraftWindow:isWorkstationAvailable(entry)
    if not entry or not entry.isoObject then
        return false
    end

    return ISEntityUI.CanPlayerUseEntity(self.player, entry.isoObject)
end

function ISBetterCraftWindow:isCrafting()
    return self.handCraftPanel
        and self.handCraftPanel.logic
        and self.handCraftPanel.logic:isCraftActionInProgress()
end

function ISBetterCraftWindow:releaseWorkstation()
    local obj = self.activeWorkstation
    if not obj then
        return
    end

    if obj:isUsingPlayer(self.player) then
        obj:setUsingPlayer(nil)
    end

    self.activeWorkstation = nil
    self.activeCraftBench = nil
end

function ISBetterCraftWindow:claimWorkstation(entry)
    if not entry or not entry.isoObject or not entry.craftBench then
        return false
    end

    if not self:isWorkstationAvailable(entry) then
        return false
    end

    entry.isoObject:setUsingPlayer(self.player)
    self.activeWorkstation = entry.isoObject
    self.activeCraftBench = entry.craftBench
    self.selectedWorkstation = entry.isoObject
    return true
end

function ISBetterCraftWindow:destroyBusyContent()
    if not self.busyContent then
        return
    end

    self:removeChild(self.busyContent)
    self.busyContent = nil
end

function ISBetterCraftWindow:createBusyContent()
    self:destroyBusyContent()

    local panel = ISUIElement:new(0, 0, 10, 10)
    panel:initialise()
    panel:instantiate()

    panel.prerender = function(_self)
        _self:drawRect(0, 0, _self:getWidth(), _self:getHeight(), 1.0, 0, 0, 0)

        local cx = _self:getWidth() / 2
        local cy = _self:getHeight() / 2

        _self:drawTextCentre(
            "This Workstation is busy",
            cx,
            cy - (getTextManager():getFontHeight(UIFont.Medium) / 2),
            1, 1, 1, 1,
            UIFont.Medium
        )
    end

    self.busyContent = panel
    self:addChild(panel)
end

function ISBetterCraftWindow:destroyHandCraftPanel()
    if not self.handCraftPanel then
        return
    end

    self.handCraftPanel:OnCloseWindow()
    self:removeChild(self.handCraftPanel)
    self.handCraftPanel = nil
end

function ISBetterCraftWindow:createHandCraftPanel(entry)
    self:destroyBusyContent()
    self:destroyHandCraftPanel()

    local craftBench = nil
    local isoObject = nil
    local recipeQuery = nil

    if entry then
        craftBench = entry.craftBench
        isoObject = entry.isoObject
    else
        isoObject = ISEntityUI.FindCraftSurface(self.player, 1)
        recipeQuery = "InHandCraft;AnySurfaceCraft"
    end

    local skin = XuiManager.GetDefaultSkin()
    self.handCraftPanel = ISXuiSkin.build(
        skin,
        nil,
        ISBCWHandCraftPanel,
        0, 0, 10, 10,
        self.player,
        craftBench,
        isoObject,
        recipeQuery,
        entry == nil
    )

    self.handCraftPanel:initialise()
    self.handCraftPanel:instantiate()
    self:addChild(self.handCraftPanel)

    self.isoObject = isoObject
    self.handCraftPanel:updateContainers(true)
    self.handCraftPanel:refreshRecipeList(true)

    self:calculateLayout(self.width, self.height)
end

function ISBetterCraftWindow:setContext(entry)
    if self:isCrafting() then
        return
    end

    if entry then
        if self.selectedWorkstation == entry.isoObject then
            return
        end

        if not self:isWorkstationAvailable(entry) then
            self:releaseWorkstation()
            self:destroyHandCraftPanel()

            self.selectedWorkstation = entry.isoObject
            self.busyWorkstation = entry.isoObject
            self:createBusyContent()

            self:calculateLayout(self.width, self.height)
            self:updateTabState()
            return
        end
    elseif not self.selectedWorkstation and not self.activeWorkstation then
        return
    end

    self:releaseWorkstation()
    self.selectedWorkstation = nil
    self.busyWorkstation = nil
    self:destroyBusyContent()

    if entry and not self:claimWorkstation(entry) then
        self.selectedWorkstation = entry.isoObject
        self.busyWorkstation = entry.isoObject
        self:destroyHandCraftPanel()
        self:createBusyContent()
        self:calculateLayout(self.width, self.height)
        self:updateTabState()
        return
    end

    if entry then
        self.selectedWorkstation = entry.isoObject
    end

    self:createHandCraftPanel(entry)
    self:updateTabState()
end

function ISBetterCraftWindow:onTabClick(button)
    if button then
        self:setContext(button.bcwEntry)
    end
end

function ISBetterCraftWindow:onRefreshClick(button)
    self:refreshBCWWindow()
end

function ISBetterCraftWindow:clearTabs()
    if not self.tabButtons then
        self.tabButtons = {}
        return
    end

    for _, button in ipairs(self.tabButtons) do
        self:removeChild(button)
    end

    self.tabButtons = {}
end

function ISBetterCraftWindow:createTab(title, entry)
    local textWidth = getTextManager():MeasureStringX(UIFont.Small, title)
    local width = math.max(64, textWidth + 24)

    local button = ISButton:new(
        0, 0,
        width,
        ISBetterCraftWindow.TAB_HEIGHT,
        title,
        self,
        ISBetterCraftWindow.onTabClick
    )
    button:initialise()
    button:instantiate()
    button.bcwEntry = entry

    self:addChild(button)
    table.insert(self.tabButtons, button)
end

function ISBetterCraftWindow:rebuildTabs()
    self:clearTabs()
    self:createTab("ALL", nil)

    for _, entry in ipairs(self.workstations) do
        self:createTab(entry.displayName, entry)
    end

    self:updateTabState()
    self.dirtyLayout = true
end

function ISBetterCraftWindow:updateTabState()
    if not self.tabButtons then
        return
    end

    for _, button in ipairs(self.tabButtons) do
        local entry = button.bcwEntry
        local selected

        if entry then
            selected = entry.isoObject == self.selectedWorkstation
        else
            selected = self.selectedWorkstation == nil
        end

        if selected then
            button.backgroundColor.a = 0.8
            button.borderColor.a = 1.0
        else
            button.backgroundColor.a = 0.35
            button.borderColor.a = 0.5
        end

        button.enable = true

        if entry and not self:isWorkstationAvailable(entry) then
            button.tooltip = "Workstation currently occupied"
        else
            button.tooltip = nil
        end
    end
end

function ISBetterCraftWindow:workstationListsDiffer(oldList, newList)
    if #oldList ~= #newList then
        return true
    end

    for _, entry in ipairs(newList) do
        if not findEntry(oldList, entry.isoObject) then
            return true
        end
    end

    return false
end

function ISBetterCraftWindow:refreshWorkstations(force)
    local _bcwRefreshStart = bcwNowMs()
    local oldList = self.workstations or {}

    local _bcwBeforeScan = bcwNowMs()
    local newList = self:scanWorkstations()
    local _bcwAfterScan = bcwNowMs()

    local _bcwBeforeCompare = bcwNowMs()
    local changed = force or self:workstationListsDiffer(oldList, newList)
    local _bcwAfterCompare = bcwNowMs()

    if ISBetterCraftWindow.DEBUG_WORKSTATION_SCAN and changed then
        for _, oldEntry in ipairs(oldList) do
            if not findEntry(newList, oldEntry.isoObject) then
                local sq = oldEntry.isoObject and oldEntry.isoObject:getSquare()
                print(string.format(
                    "[BCW SCAN] REMOVED %s anchor=%d,%d,%d",
                    tostring(oldEntry.displayName or oldEntry.name or "?"),
                    sq and sq:getX() or -1,
                    sq and sq:getY() or -1,
                    sq and sq:getZ() or -1
                ))
            end
        end

        for _, newEntry in ipairs(newList) do
            if not findEntry(oldList, newEntry.isoObject) then
                local sq = newEntry.isoObject and newEntry.isoObject:getSquare()
                print(string.format(
                    "[BCW SCAN] ADDED %s anchor=%d,%d,%d",
                    tostring(newEntry.displayName or newEntry.name or "?"),
                    sq and sq:getX() or -1,
                    sq and sq:getY() or -1,
                    sq and sq:getZ() or -1
                ))
            end
        end
    end

    self.workstations = newList

    local _bcwBeforeTabs = bcwNowMs()
    if changed then
        self:rebuildTabs()
    else
        self:updateTabState()
    end
    local _bcwAfterTabs = bcwNowMs()

    if ISBetterCraftWindow.DEBUG_WORKSTATION_SCAN then
        print(string.format(
            "[BCW PERF] scan=%dms compare=%dms tabs+availability=%dms subtotal=%dms changed=%s",
            _bcwAfterScan - _bcwBeforeScan,
            _bcwAfterCompare - _bcwBeforeCompare,
            _bcwAfterTabs - _bcwBeforeTabs,
            bcwNowMs() - _bcwRefreshStart,
            tostring(changed)
        ))
    end

    if self.selectedWorkstation
        and not findEntry(self.workstations, self.selectedWorkstation)
        and not self:isCrafting() then
        self:setContext(nil)
        return
    end

    -- If the currently-selected busy workstation becomes available,
    -- automatically claim it and restore the real crafting UI.
    if self.busyWorkstation
        and self.selectedWorkstation == self.busyWorkstation
        and not self:isCrafting() then

        local entry = findEntry(self.workstations, self.busyWorkstation)

        if entry and self:isWorkstationAvailable(entry) then
            self:destroyBusyContent()

            if self:claimWorkstation(entry) then
                self.busyWorkstation = nil
                self.selectedWorkstation = entry.isoObject
                self:createHandCraftPanel(entry)
                self:updateTabState()
                return
            end

            -- Another player may have claimed it between the availability
            -- check and our claim attempt. Keep the busy state in that case.
            self:createBusyContent()
        end
    end

    if self.activeWorkstation
        and not self.activeWorkstation:isUsingPlayer(self.player)
        and not self:isCrafting() then
        local lostObject = self.activeWorkstation
        local entry = findEntry(self.workstations, lostObject)

        self.activeWorkstation = nil
        self.activeCraftBench = nil

        if entry then
            self.selectedWorkstation = lostObject
            self.busyWorkstation = lostObject
            self:destroyHandCraftPanel()
            self:createBusyContent()
            self:calculateLayout(self.width, self.height)
            self:updateTabState()
        else
            self.selectedWorkstation = nil
            self.busyWorkstation = nil
            self:destroyBusyContent()
            self:createHandCraftPanel(nil)
            self:updateTabState()
        end
    end
end

function ISBetterCraftWindow:layoutTabs()
    local margin = ISBetterCraftWindow.TAB_MARGIN
    local gap = ISBetterCraftWindow.TAB_GAP
    local tabHeight = ISBetterCraftWindow.TAB_HEIGHT
    local x = margin
    local firstRowY = self:titleBarHeight() + margin
    local y = firstRowY
    local normalMaxRight = self.width - margin
    local refreshWidth = self.refreshButton and self.refreshButton:getWidth() or 0
    local firstRowMaxRight = normalMaxRight

    -- Keep the refresh control permanently at the far right of the first
    -- workstation-tab row and reserve its space so tabs never overlap it.
    if self.refreshButton then
        self.refreshButton:setWidth(tabHeight)
        self.refreshButton:setHeight(tabHeight)
        self.refreshButton:setX(self.width - margin - tabHeight)
        self.refreshButton:setY(firstRowY)
        firstRowMaxRight = self.refreshButton:getX() - gap
    end

    local bottom = firstRowY + tabHeight

    for _, button in ipairs(self.tabButtons) do
        local maxRight = (y == firstRowY) and firstRowMaxRight or normalMaxRight

        if x > margin and x + button:getWidth() > maxRight then
            x = margin
            y = y + tabHeight + gap
            maxRight = normalMaxRight
        end

        button:setX(x)
        button:setY(y)
        button:setHeight(tabHeight)

        x = button:getRight() + gap
        bottom = math.max(bottom, button:getBottom())
    end

    if self.refreshButton then
        bottom = math.max(bottom, self.refreshButton:getBottom())
    end

    return bottom + margin
end


function ISBetterCraftWindow:xuiRecalculateLayout(_preferredWidth, _preferredHeight, _force, _anchorRight)
    -- Child XUI widgets (notably the vanilla manual ingredient panel)
    -- request a root-window relayout when they open/close or rebuild.
    -- Our custom window must handle that request just like ISHandcraftWindow.
    -- We only mark the layout dirty here; the actual recalculation is deferred
    -- to prerender so we don't reintroduce the recipe-list scroll reset bug.
    if self.calculateLayout and ((not self.dirtyLayout) or _force) then
        self.xuiPreferredResizeWidth = self.width
        self.xuiPreferredResizeHeight = self.height
        self.xuiResizeAnchorRight = _anchorRight == true

        if _preferredWidth then
            if _preferredWidth < 0 then
                -- A negative XUI width request is emitted when the vanilla
                -- manual ingredient column closes. Vanilla uses that to shrink
                -- its own outer window, but BCW should keep the user's chosen
                -- window size and simply let the remaining columns reclaim the
                -- freed space.
                self.xuiPreferredResizeWidth = self.width
            else
                -- Positive requests are still honoured. This is what lets the
                -- manual ingredient column grow the window when there isn't
                -- enough room to display it without clipping.
                self.xuiPreferredResizeWidth = math.max(self.width, _preferredWidth)
            end
        end

        if _preferredHeight then
            if _preferredHeight < 0 then
                self.xuiPreferredResizeHeight = self.height + _preferredHeight
            else
                self.xuiPreferredResizeHeight = _preferredHeight
            end
        end

        self.dirtyLayout = true
    end
end

local function syncResizeWidgets(window)
    if not window or not window.resizable then
        return
    end

    -- CRITICAL: never move a resize widget while it owns mouse capture.
    -- ISResizeWidget computes the drag delta from its own local mouse
    -- coordinates (getMouseX/getMouseY - downX/downY). Moving the widget
    -- during the drag changes that coordinate system and amplifies/reverses
    -- the delta, which is what made BCW resize jump wildly.
    --
    -- We only resync the hitboxes after the drag has ended. This still fixes
    -- the old minimum-size issue, where a clamped child-driven layout could
    -- leave the hitbox one frame away from the rendered bottom edge.
    if (window.resizeWidget and window.resizeWidget.resizing)
    or (window.resizeWidget2 and window.resizeWidget2.resizing) then
        return
    end

    local rh = window:resizeWidgetHeight()

    if window.resizeWidget then
        local x = window.width - rh
        local y = window.height - rh

        if window.resizeWidget:getX() ~= x then
            window.resizeWidget:setX(x)
        end
        if window.resizeWidget:getY() ~= y then
            window.resizeWidget:setY(y)
        end
        if window.resizeWidget:getWidth() ~= rh then
            window.resizeWidget:setWidth(rh)
        end
        if window.resizeWidget:getHeight() ~= rh then
            window.resizeWidget:setHeight(rh)
        end

        window.resizeWidget:bringToTop()
    end

    if window.resizeWidget2 then
        local width = math.max(0, window.width - rh)
        local y = window.height - rh

        if window.resizeWidget2:getX() ~= 0 then
            window.resizeWidget2:setX(0)
        end
        if window.resizeWidget2:getY() ~= y then
            window.resizeWidget2:setY(y)
        end
        if window.resizeWidget2:getWidth() ~= width then
            window.resizeWidget2:setWidth(width)
        end
        if window.resizeWidget2:getHeight() ~= rh then
            window.resizeWidget2:setHeight(rh)
        end

        window.resizeWidget2:bringToTop()
    end
end

local function installStableResizeDrag(widget)
    if not widget then
        return
    end

    -- ISResizeWidget's vanilla delta is expressed in the widget's local
    -- coordinates. That works for vanilla windows because the resize handle
    -- moves with the border while dragging. BCW has a dynamic XUI layout that
    -- can move/clamp the border independently, which made the local delta get
    -- applied more than once and caused resize amplification.
    --
    -- Use screen-space mouse coordinates and the window size captured at the
    -- beginning of the drag instead. The requested size is therefore always:
    --     initialSize + totalMouseDisplacement
    -- and can never accumulate from frame to frame.
    widget.onMouseDown = function(self, x, y)
        if not self:getIsVisible() then
            return
        end

        self.bcwStartMouseX = getMouseX()
        self.bcwStartMouseY = getMouseY()
        self.bcwStartWidth = self.target:getWidth()
        self.bcwStartHeight = self.target:getHeight()

        self.resizing = true
        self:setCapture(true)
        return true
    end

    local function resizeFromScreenMouse(self)
        if not self.resizing then
            return
        end

        local dx = getMouseX() - self.bcwStartMouseX
        local dy = getMouseY() - self.bcwStartMouseY

        local width = self.bcwStartWidth
        if not self.yonly then
            width = width + dx
        end

        local height = self.bcwStartHeight + dy

        -- Keep the bottom edge on-screen, matching vanilla ISResizeWidget.
        local maxScreenHeight = getCore():getScreenHeight() - self.target:getY()
        height = math.min(height, maxScreenHeight)

        self.target:calculateLayout(width, height)
    end

    widget.onMouseMove = function(self, dx, dy)
        self.mouseOver = true
        resizeFromScreenMouse(self)
    end

    widget.onMouseMoveOutside = function(self, dx, dy)
        self.mouseOver = false
        resizeFromScreenMouse(self)
    end

    local function finishResize(self)
        if not self:getIsVisible() then
            return
        end

        self.resizing = false
        self:setCapture(false)
        syncResizeWidgets(self.target)
        return true
    end

    widget.onMouseUp = finishResize
    widget.onMouseUpOutside = finishResize
end

function ISBetterCraftWindow:calculateLayout(preferredWidth, preferredHeight)
    local requestedWidth = preferredWidth or self.width
    local requestedHeight = preferredHeight or self.height

    -- The bottom resize bar is Y-only. While it owns mouse capture, the
    -- window width must remain absolutely stable. If calculateLayout changes
    -- the width during that drag, the anchored ISResizeWidget2 changes its
    -- local coordinate system and the next dy becomes incorrect.
    local verticalResize = self.resizeWidget2 and self.resizeWidget2.resizing
    if verticalResize then
        requestedWidth = self.width
    end

    local width = math.max(self.minimumWidth, requestedWidth)
    local height = math.max(self.minimumHeight, requestedHeight)

    if self.maximumWidth and self.maximumWidth > 0 then
        width = math.min(width, self.maximumWidth)
    end
    if self.maximumHeight and self.maximumHeight > 0 then
        height = math.min(height, self.maximumHeight)
    end

    local resizeHeight = self.resizable and self:resizeWidgetHeight() or 0

    if self.busyContent then
        self:setWidth(width)
        self:setHeight(height)

        local contentY = self:layoutTabs()

        self.busyContent:setX(0)
        self.busyContent:setY(contentY)
        self.busyContent:setWidth(width)
        self.busyContent:setHeight(math.max(0, height - contentY - resizeHeight))


        self.busyContent:bringToTop()

        syncResizeWidgets(self)
        self.dirtyLayout = false
        return
    end

    if self.handCraftPanel then
        -- Match vanilla ISHandcraftWindow: first ask the child for its
        -- intrinsic minimum size without constraining it to the current
        -- height. This makes the horizontal minimum independent from vertical
        -- resizing (manual ingredient panel included).
        self.handCraftPanel:calculateLayout(0, 0)
        width = math.max(width, self.handCraftPanel:getWidth())
    end

    -- Never let a Y-only drag alter the outer width. Any genuine width-growth
    -- request (for example opening the vanilla manual ingredient panel) is
    -- handled by xuiRecalculateLayout outside of an active vertical drag.
    if verticalResize then
        width = self.width
    end

    self:setWidth(width)
    self:setHeight(height)

    local contentY = self:layoutTabs()

    if self.handCraftPanel then
        self.handCraftPanel:setX(0)
        self.handCraftPanel:setY(contentY)
        self.handCraftPanel:calculateLayout(
            width,
            math.max(0, height - contentY - resizeHeight)
        )

        -- Height may legitimately be forced upward by the child. Width is
        -- only allowed to grow here when this is not a Y-only mouse drag.
        if not verticalResize then
            width = math.max(width, self.handCraftPanel:getWidth())
        end

        height = math.max(
            height,
            self.handCraftPanel:getHeight() + contentY + resizeHeight
        )

        self:setWidth(width)
        self:setHeight(height)

        -- If width grew in the final child pass, recalculate once with the
        -- actual outer width so fill columns receive the correct geometry.
        if not verticalResize and self.handCraftPanel:getWidth() < width then
            contentY = self:layoutTabs()
            self.handCraftPanel:setX(0)
            self.handCraftPanel:setY(contentY)
            self.handCraftPanel:calculateLayout(
                width,
                math.max(0, height - contentY - resizeHeight)
            )
            height = math.max(
                height,
                self.handCraftPanel:getHeight() + contentY + resizeHeight
            )
            self:setHeight(height)
        end
    end


    syncResizeWidgets(self)
    self.dirtyLayout = false
end

function ISBetterCraftWindow:onResize()
    -- Do not recalculate the layout from onResize().
    -- ISResizeWidget normally calls setWidth()/setHeight() separately, and
    -- the anchored resize widgets move between those two calls. During a
    -- drag that changes the widget's local mouse coordinates and causes the
    -- resize delta to be applied repeatedly / amplified.
    --
    -- Our resize widgets call calculateLayout() directly instead (see
    -- createChildren), exactly like vanilla ISEntityWindow does.
    ISUIElement.onResize(self)
end

function ISBetterCraftWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    -- BCW uses a screen-space drag baseline instead of ISResizeWidget's
    -- local-coordinate delta. This keeps resizing strictly 1:1 with the mouse
    -- even when the XUI layout reaches a minimum size or changes internally.
    installStableResizeDrag(self.resizeWidget)
    installStableResizeDrag(self.resizeWidget2)

    self.tabButtons = {}
    self.workstations = self:scanWorkstations()
    self.activeWorkstation = nil
    self.activeCraftBench = nil
    self.selectedWorkstation = nil
    self.busyWorkstation = nil
    self.busyContent = nil

    -- Window-wide refresh belongs to the workstation-tab row.
    -- Use a conventional circular-arrow glyph instead of the unrelated
    -- furniture-rotate texture previously used in the recipe filter strip.
    self.refreshButton = ISButton:new(
        0, 0,
        ISBetterCraftWindow.TAB_HEIGHT,
        ISBetterCraftWindow.TAB_HEIGHT,
        "",
        self,
        ISBetterCraftWindow.onRefreshClick
    )
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self.refreshButton:setImage(getTexture("media/textures/BCW_Refresh.png"))
    self.refreshButton:forceImageSize(
        math.max(14, ISBetterCraftWindow.TAB_HEIGHT - 10),
        math.max(14, ISBetterCraftWindow.TAB_HEIGHT - 10)
    )
    self.refreshButton.tooltip = "Refresh entire crafting window"
    self.refreshButton.enable = true
    self:addChild(self.refreshButton)

    self:rebuildTabs()
    self:createHandCraftPanel(nil)
end

function ISBetterCraftWindow:refreshBCWWindow()
    if not self.player or self.player:isDead() then
        return
    end

    -- Re-evaluate the complete workstation/tab state immediately using the
    -- same rules as the periodic world refresh. This may legitimately switch
    -- back to ALL if the selected workstation is no longer in range.
    self:refreshWorkstations(true)

    -- refreshWorkstations() can replace/destroy the hand-craft panel when the
    -- current workstation context changes, so always fetch the live panel
    -- after that operation rather than using the old button owner.
    local panel = self.handCraftPanel
    if panel and panel.refreshBCWCraftingData then
        panel:refreshBCWCraftingData(true)
    end

    -- Force a complete layout pass so tabs, filters, recipe/details and
    -- resize-dependent geometry all reflect the freshly rebuilt state.
    self:calculateLayout(self.width, self.height)
    self.dirtyLayout = true
end

function ISBetterCraftWindow:update()
    ISCollapsableWindow.update(self)

    if not self.player or self.player:isDead() then
        self:close()
        return
    end

    self.scanTimer = self.scanTimer - 1
    if self.scanTimer <= 0 then
        self.scanTimer = ISBetterCraftWindow.SCAN_INTERVAL
        self:refreshWorkstations(false)
    end
end

function ISBetterCraftWindow:prerender()
    self:stayOnSplitScreen()

    -- Do not recalculate the entire HandCraft layout every frame.
    -- ISWidgetRecipeListPanel:onResize() calls ensureVisible(selected),
    -- which would otherwise force the scroll position back to the
    -- selected recipe immediately after every mouse-wheel scroll.
    --
    -- When an XUI child explicitly asks for a relayout (for example when
    -- the vanilla manual ingredient panel opens/closes), use the preferred
    -- size requested by that child. This mirrors vanilla ISHandcraftWindow.
    if self.dirtyLayout then
        local oldX = self:getX()
        local oldWidth = self:getWidth()

        self:calculateLayout(
            self.xuiPreferredResizeWidth or self.width,
            self.xuiPreferredResizeHeight or self.height
        )

        if self.xuiResizeAnchorRight then
            self:setX(oldX - (self:getWidth() - oldWidth))
            self.xuiResizeAnchorRight = false
        end

        self.xuiPreferredResizeWidth = self.width
        self.xuiPreferredResizeHeight = self.height
    end

    -- If a drag just ended, put the resize hitboxes back on the actual
    -- rendered border. During the drag syncResizeWidgets() intentionally
    -- does nothing so the mouse delta remains stable.
    syncResizeWidgets(self)

    ISCollapsableWindow.prerender(self)
end

function ISBetterCraftWindow:stayOnSplitScreen()
    ISUIElement.stayOnSplitScreen(self, self.playerNum)
end

function ISBetterCraftWindow:close()
    if self.bcwClosing then
        return
    end

    if self:isCrafting() then
        return
    end

    self.bcwClosing = true
    self:destroyHandCraftPanel()
    self:releaseWorkstation()

    ISBetterCraftWindow.instances[self.playerNum] = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

function ISBetterCraftWindow:new(x, y, width, height, player)
    local o = ISCollapsableWindow.new(self, x, y, width, height)

    o.player = player
    o.playerNum = player:getPlayerNum()
    o.title = "Better Craft Window"
    o.minimumWidth = 1050
    o.minimumHeight = 550
    o.resizable = true

    o.workstations = {}
    o.tabButtons = {}
    o.activeWorkstation = nil
    o.activeCraftBench = nil
    o.handCraftPanel = nil
    o.isoObject = nil
    o.scanTimer = ISBetterCraftWindow.SCAN_INTERVAL
    o.bcwClosing = false
    o.dirtyLayout = true
    o.xuiPreferredResizeWidth = width
    o.xuiPreferredResizeHeight = height
    o.xuiResizeAnchorRight = false

    return o
end

function ISBetterCraftWindow:selectWorkstationObject(isoObject)
    if not isoObject then
        self:setContext(nil)
        return false
    end

    local craftBench = getCraftBench(isoObject)
    if not craftBench then
        return false
    end

    -- Re-scan first so the tab list reflects the world at the moment the
    -- workstation was clicked.
    self:refreshWorkstations(true)

    local entry = findEntry(self.workstations, isoObject)

    if not entry then
        -- A workstation opened through the vanilla object-click path is
        -- already a valid nearby entity. If the periodic BCW scan omitted it
        -- for an edge case, inject it into the current tab list rather than
        -- falling back to ALL.
        entry = {
            isoObject = isoObject,
            craftBench = craftBench,
            name = getWorkstationName(isoObject),
            displayName = getWorkstationName(isoObject),
            distance = getDistance(self.player, isoObject)
        }

        table.insert(self.workstations, entry)

        -- Rebuild duplicate numbering exactly like scanWorkstations().
        local totals = {}
        local counts = {}

        for _, workstation in ipairs(self.workstations) do
            totals[workstation.name] = (totals[workstation.name] or 0) + 1
        end

        for _, workstation in ipairs(self.workstations) do
            local name = workstation.name
            counts[name] = (counts[name] or 0) + 1

            if totals[name] > 1 then
                workstation.displayName = name .. " (" .. tostring(counts[name]) .. ")"
            else
                workstation.displayName = name
            end
        end

        self:rebuildTabs()
    end

    self:setContext(entry)
    self:bringToTop()
    return true
end

function ISBetterCraftWindow.open(player)
    if not player then
        return nil
    end

    local playerNum = player:getPlayerNum()
    local existing = ISBetterCraftWindow.instances[playerNum]

    if existing then
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end

    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local width = math.max(1050, math.min(1500, screenWidth - 100))
    local height = math.max(550, math.min(800, screenHeight - 100))
    local x = math.floor((screenWidth - width) / 2)
    local y = math.floor((screenHeight - height) / 2)

    local window = ISBetterCraftWindow:new(x, y, width, height, player)
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    window:bringToTop()

    ISBetterCraftWindow.instances[playerNum] = window
    return window
end

function ISBetterCraftWindow.openForWorkstation(player, isoObject)
    if not player or not isoObject then
        return nil
    end

    local window = ISBetterCraftWindow.open(player)
    if not window then
        return nil
    end

    window:selectWorkstationObject(isoObject)
    return window
end

function ISBetterCraftWindow.toggle(player)
    if not player then
        return
    end

    local playerNum = player:getPlayerNum()
    local window = ISBetterCraftWindow.instances[playerNum]

    if window then
        window:close()
    else
        ISBetterCraftWindow.open(player)
    end
end
