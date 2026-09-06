require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "Entity/ISEntityUI"
require "ISBCWHandCraftPanel"

ISBetterCraftWindow = ISCollapsableWindow:derive("ISBetterCraftWindow")

ISBetterCraftWindow.instances = {}
ISBetterCraftWindow.SCAN_RADIUS = 3
ISBetterCraftWindow.SCAN_INTERVAL = 60
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
    local result = {}

    if not self.player or not self.player:getSquare() then
        return result
    end

    local sx = math.floor(self.player:getX())
    local sy = math.floor(self.player:getY())
    local sz = math.floor(self.player:getZ())
    local playerSquare = self.player:getSquare()
    local radius = ISBetterCraftWindow.SCAN_RADIUS

    for x = sx - radius, sx + radius do
        for y = sy - radius, sy + radius do
            local square = getCell():getGridSquare(x, y, sz)

            if square and playerSquare:canReachTo(square) then
                local objects = square:getObjects()

                if objects and objects:size() > 1 then
                    for i = 1, objects:size() - 1 do
                        local obj = objects:get(i)
                        local craftBench = getCraftBench(obj)

                        if craftBench and not findEntry(result, obj) then
                            table.insert(result, {
                                isoObject = obj,
                                craftBench = craftBench,
                                name = getWorkstationName(obj),
                                distance = getDistance(self.player, obj)
                            })
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

    local totals = {}
    local counts = {}

    for _, entry in ipairs(result) do
        totals[entry.name] = (totals[entry.name] or 0) + 1
    end

    for _, entry in ipairs(result) do
        local name = entry.name
        counts[name] = (counts[name] or 0) + 1

        if totals[name] > 1 then
            entry.displayName = name .. " (" .. tostring(counts[name]) .. ")"
        else
            entry.displayName = name
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
    return true
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
        if self.activeWorkstation == entry.isoObject then
            return
        end

        if not self:isWorkstationAvailable(entry) then
            if isClient() then
                self.player:Say(getText("IGUI_ObjectAlreadyUsedSayMessage"))
            end
            return
        end
    elseif not self.activeWorkstation then
        return
    end

    self:releaseWorkstation()

    if entry and not self:claimWorkstation(entry) then
        self:createHandCraftPanel(nil)
        self:updateTabState()
        return
    end

    self:createHandCraftPanel(entry)
    self:updateTabState()
end

function ISBetterCraftWindow:onTabClick(button)
    if button then
        self:setContext(button.bcwEntry)
    end
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
            selected = entry.isoObject == self.activeWorkstation
        else
            selected = self.activeWorkstation == nil
        end

        if selected then
            button.backgroundColor.a = 0.8
            button.borderColor.a = 1.0
        else
            button.backgroundColor.a = 0.35
            button.borderColor.a = 0.5
        end

        if entry then
            button.enable = selected or self:isWorkstationAvailable(entry)
        else
            button.enable = true
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
    local newList = self:scanWorkstations()
    local changed = force or self:workstationListsDiffer(self.workstations, newList)
    self.workstations = newList

    if changed then
        self:rebuildTabs()
    else
        self:updateTabState()
    end

    if self.activeWorkstation
        and not findEntry(self.workstations, self.activeWorkstation)
        and not self:isCrafting() then
        self:setContext(nil)
        return
    end

    if self.activeWorkstation
        and not self.activeWorkstation:isUsingPlayer(self.player)
        and not self:isCrafting() then
        self.activeWorkstation = nil
        self.activeCraftBench = nil
        self:createHandCraftPanel(nil)
        self:updateTabState()
    end
end

function ISBetterCraftWindow:layoutTabs()
    local margin = ISBetterCraftWindow.TAB_MARGIN
    local gap = ISBetterCraftWindow.TAB_GAP
    local tabHeight = ISBetterCraftWindow.TAB_HEIGHT
    local x = margin
    local y = self:titleBarHeight() + margin
    local maxRight = self.width - margin
    local bottom = y + tabHeight

    for _, button in ipairs(self.tabButtons) do
        if x > margin and x + button:getWidth() > maxRight then
            x = margin
            y = y + tabHeight + gap
        end

        button:setX(x)
        button:setY(y)
        button:setHeight(tabHeight)

        x = button:getRight() + gap
        bottom = math.max(bottom, button:getBottom())
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

function ISBetterCraftWindow:calculateLayout(preferredWidth, preferredHeight)
    local width = math.max(self.minimumWidth, preferredWidth or self.width)
    local height = math.max(self.minimumHeight, preferredHeight or self.height)

    -- First use the requested outer size so tab wrapping is calculated for
    -- the width the player is trying to use.
    self:setWidth(width)
    self:setHeight(height)

    local contentY = self:layoutTabs()
    local resizeHeight = self.resizable and self:resizeWidgetHeight() or 0

    if self.handCraftPanel then
        self.handCraftPanel:setX(0)
        self.handCraftPanel:setY(contentY)

        -- The hand-craft panel is allowed to overrule the requested width.
        -- This is important when vanilla shows the manual ingredient panel:
        -- rootTable then needs another whole column. ISHandCraftPanel already
        -- reports that requirement by becoming wider than the preferred width.
        self.handCraftPanel:calculateLayout(
            width,
            math.max(0, height - contentY - resizeHeight)
        )

        local requiredWidth = self.handCraftPanel:getWidth()
        local requiredHeight = self.handCraftPanel:getHeight() + contentY + resizeHeight

        width = math.max(width, requiredWidth)
        height = math.max(height, requiredHeight)

        -- If the child forced the window wider, run one final pass using the
        -- actual width. This keeps percentage/fill columns and the vanilla
        -- ingredient panel responsive instead of leaving them laid out for
        -- the too-small requested size.
        if width ~= self:getWidth() or height ~= self:getHeight() then
            self:setWidth(width)
            self:setHeight(height)

            contentY = self:layoutTabs()

            self.handCraftPanel:setX(0)
            self.handCraftPanel:setY(contentY)
            self.handCraftPanel:calculateLayout(
                width,
                math.max(0, height - contentY - resizeHeight)
            )

            -- One last guard in case the second pass reveals a slightly larger
            -- minimum due to changed tab wrapping or XUI column calculation.
            width = math.max(width, self.handCraftPanel:getWidth())
            height = math.max(
                height,
                self.handCraftPanel:getHeight() + contentY + resizeHeight
            )

            self:setWidth(width)
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

    -- Vanilla ISEntityWindow uses a custom resizeFunction for the same
    -- reason: resizing a layout-heavy window through setWidth()/setHeight()
    -- makes anchored children interfere with the drag calculation.
    -- Feed the requested mouse size straight into our layout in one pass.
    if self.resizeWidget then
        self.resizeWidget.resizeFunction = ISBetterCraftWindow.calculateLayout
    end
    if self.resizeWidget2 then
        self.resizeWidget2.resizeFunction = ISBetterCraftWindow.calculateLayout
    end

    self.tabButtons = {}
    self.workstations = self:scanWorkstations()
    self.activeWorkstation = nil
    self.activeCraftBench = nil

    self:rebuildTabs()
    self:createHandCraftPanel(nil)
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
