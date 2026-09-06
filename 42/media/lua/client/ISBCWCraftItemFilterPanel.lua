require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_SCALE = FONT_HGT_SMALL / 19
local UI_BORDER_SPACING = 6
local PANEL_WIDTH = 185 * FONT_SCALE
local SEARCH_HEIGHT = FONT_HGT_SMALL + 8

ISBCWCraftItemFilterPanel = ISPanel:derive("ISBCWCraftItemFilterPanel")

function ISBCWCraftItemFilterPanel:initialise()
    ISPanel.initialise(self)
end

function ISBCWCraftItemFilterPanel:createChildren()
    ISPanel.createChildren(self)

    self.searchEntry = ISTextEntryBox:new(
        "",
        0,
        0,
        self.listBoxWidth or PANEL_WIDTH,
        SEARCH_HEIGHT
    )
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self.searchEntry:setClearButton(true)
    self.searchEntry:setPlaceholderText("Search items...")
    self.searchEntry.onTextChange = function()
        self:onSearchTextChanged()
    end
    self:addChild(self.searchEntry)

    self.itemList = ISScrollingListBox:new(
        0,
        self.searchEntry:getBottom() + UI_BORDER_SPACING,
        self.listBoxWidth or PANEL_WIDTH,
        0
    )
    self.itemList:initialise()
    self.itemList:instantiate()
    self.itemList.itemheight = FONT_HGT_SMALL + 10
    self.itemList.font = UIFont.Small
    self.itemList.drawBorder = true
    self.itemList.selected = 1
    self.itemList:setOnMouseDownFunction(self, self.onItemSelected)
    self:addChild(self.itemList)
end

function ISBCWCraftItemFilterPanel:setItems(items)
    self.items = items or {}
    self:rebuildVisibleList()
end

function ISBCWCraftItemFilterPanel:setSelectedFullName(fullName)
    self.selectedFullName = fullName
    self:rebuildVisibleList()
end

function ISBCWCraftItemFilterPanel:onSearchTextChanged()
    self:rebuildVisibleList()
end

function ISBCWCraftItemFilterPanel:rebuildVisibleList()
    if not self.itemList then
        return
    end

    local search = ""
    if self.searchEntry then
        search = string.lower(self.searchEntry:getInternalText() or "")
    end

    self.itemList:clear()

    local allEntry = {
        isAll = true,
        displayName = "ALL",
        fullName = nil
    }

    local allItem = self.itemList:addItem("ALL", allEntry)
    if not self.selectedFullName then
        self.itemList.selected = allItem.itemindex
    end

    for _, entry in ipairs(self.items) do
        local displayName = entry.displayName or entry.fullName or "Unknown"
        local haystack = string.lower(displayName .. " " .. (entry.fullName or ""))

        if search == "" or string.find(haystack, search, 1, true) then
            local listItem = self.itemList:addItem(displayName, entry)

            if self.selectedFullName and entry.fullName == self.selectedFullName then
                self.itemList.selected = listItem.itemindex
            end
        end
    end

    self.itemList:setScrollHeight(#self.itemList.items * self.itemList.itemheight)
end

function ISBCWCraftItemFilterPanel:onItemSelected(entry)
    if not entry then
        return
    end

    if entry.isAll then
        self.selectedFullName = nil
    else
        self.selectedFullName = entry.fullName
    end

    self:rebuildVisibleList()

    if self.callbackTarget and self.callbackTarget.onBCWCraftItemFilterChanged then
        self.callbackTarget:onBCWCraftItemFilterChanged(entry)
    end
end

function ISBCWCraftItemFilterPanel:calculateLayout(preferredWidth, preferredHeight)
    local width = self.listBoxWidth or PANEL_WIDTH
    local height = math.max(0, preferredHeight or self.height or 0)

    self:setWidth(width)
    self:setHeight(height)

    if self.searchEntry then
        self.searchEntry:setX(0)
        self.searchEntry:setY(0)
        self.searchEntry:setWidth(width)
        self.searchEntry:setHeight(SEARCH_HEIGHT)
    end

    if self.itemList then
        local listY = SEARCH_HEIGHT + UI_BORDER_SPACING
        self.itemList:setX(0)
        self.itemList:setY(listY)
        self.itemList:setWidth(width)
        self.itemList:setHeight(math.max(0, height - listY))

        if self.itemList.vscroll then
            self.itemList.vscroll:setX(width - self.itemList.vscroll:getWidth())
            self.itemList.vscroll:setHeight(self.itemList:getHeight())
        end
    end
end

function ISBCWCraftItemFilterPanel:onResize()
    ISUIElement.onResize(self)
end

function ISBCWCraftItemFilterPanel:prerender()
    ISPanel.prerender(self)

    if self.itemList and self.itemList.vscroll then
        self.itemList.vscroll:setHeight(self.itemList:getHeight())
    end
end

function ISBCWCraftItemFilterPanel:render()
    ISPanel.render(self)
end

function ISBCWCraftItemFilterPanel:update()
    ISPanel.update(self)
end

function ISBCWCraftItemFilterPanel:new(x, y, width, height, callbackTarget)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.background = false
    o.callbackTarget = callbackTarget
    o.items = {}
    o.selectedFullName = nil
    o.listBoxWidth = width or PANEL_WIDTH
    o.minimumWidth = o.listBoxWidth
    o.minimumHeight = 0

    return o
end
