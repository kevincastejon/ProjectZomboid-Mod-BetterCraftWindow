require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISComboBox"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_SCALE = FONT_HGT_SMALL / 19
local UI_BORDER_SPACING = 6
local PANEL_WIDTH = 185 * FONT_SCALE
local CONTROL_HEIGHT = FONT_HGT_SMALL + 8

ISBCWCraftItemFilterPanel = ISPanel:derive("ISBCWCraftItemFilterPanel")

function ISBCWCraftItemFilterPanel:initialise()
    ISPanel.initialise(self)
end

function ISBCWCraftItemFilterPanel:createChildren()
    ISPanel.createChildren(self)

    local width = self.listBoxWidth or PANEL_WIDTH

    self.searchEntry = ISTextEntryBox:new(
        "",
        0,
        0,
        width,
        CONTROL_HEIGHT
    )
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self.searchEntry:setClearButton(true)
    self.searchEntry:setPlaceholderText("Search items...")
    self.searchEntry.onTextChange = function()
        self:onSearchTextChanged()
    end
    self:addChild(self.searchEntry)

    self.typeCombo = ISComboBox:new(
        0,
        self.searchEntry:getBottom() + UI_BORDER_SPACING,
        width,
        CONTROL_HEIGHT,
        self,
        ISBCWCraftItemFilterPanel.onTypeChanged
    )
    self.typeCombo:initialise()
    self.typeCombo:instantiate()
    self.typeCombo.font = UIFont.Small
    self.typeCombo:addOptionWithData("Both", "Both")
    self.typeCombo:addOptionWithData("Ingredient", "Ingredient")
    self.typeCombo:addOptionWithData("Result", "Result")
    self.typeCombo:selectData(self.filterType or "Both")
    self:addChild(self.typeCombo)

    self.itemList = ISScrollingListBox:new(
        0,
        self.typeCombo:getBottom() + UI_BORDER_SPACING,
        width,
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

    -- Keep the controls above the scrolling list in the draw order.
    -- ISScrollingListBox can otherwise paint scrolled rows over them.
    self.searchEntry:bringToTop()
    self.typeCombo:bringToTop()
end

function ISBCWCraftItemFilterPanel:setItems(items)
    self.items = items or {}
    self:rebuildVisibleList()
end

function ISBCWCraftItemFilterPanel:setSelectedFullName(fullName)
    self.selectedFullName = fullName
    self:rebuildVisibleList()
end

function ISBCWCraftItemFilterPanel:setFilterType(filterType)
    self.filterType = filterType or "Both"

    if self.typeCombo then
        self.typeCombo:selectData(self.filterType)
    end

    self:rebuildVisibleList()
end

function ISBCWCraftItemFilterPanel:getFilterType()
    return self.filterType or "Both"
end

function ISBCWCraftItemFilterPanel:onSearchTextChanged()
    self:rebuildVisibleList()
end

function ISBCWCraftItemFilterPanel:onTypeChanged(combo)
    local selected = combo and combo.options[combo:getSelected()]
    local filterType = selected and selected.data or "Both"

    self.filterType = filterType

    if self.callbackTarget and self.callbackTarget.onBCWCraftItemFilterTypeChanged then
        self.callbackTarget:onBCWCraftItemFilterTypeChanged(filterType)
    else
        self:rebuildVisibleList()
    end
end

function ISBCWCraftItemFilterPanel:entryMatchesType(entry)
    local filterType = self:getFilterType()

    if filterType == "Ingredient" then
        return entry.isIngredient == true
    end

    if filterType == "Result" then
        return entry.isResult == true
    end

    return entry.isIngredient == true or entry.isResult == true
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
    local selectedFound = not self.selectedFullName

    if not self.selectedFullName then
        self.itemList.selected = allItem.itemindex
    end

    for _, entry in ipairs(self.items) do
        if self:entryMatchesType(entry) then
            local displayName = entry.displayName or entry.fullName or "Unknown"
            local haystack = string.lower(displayName .. " " .. (entry.fullName or ""))

            if search == "" or string.find(haystack, search, 1, true) then
                local listItem = self.itemList:addItem(displayName, entry)

                if self.selectedFullName and entry.fullName == self.selectedFullName then
                    self.itemList.selected = listItem.itemindex
                    selectedFound = true
                end
            end
        end
    end

    -- If the currently selected item isn't part of this type anymore,
    -- visually fall back to ALL. The parent will also clear the recipe filter.
    if not selectedFound then
        self.itemList.selected = allItem.itemindex
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
        self.searchEntry:setHeight(CONTROL_HEIGHT)
    end

    if self.typeCombo then
        local comboY = CONTROL_HEIGHT + UI_BORDER_SPACING
        self.typeCombo:setX(0)
        self.typeCombo:setY(comboY)
        self.typeCombo:setWidth(width)
        self.typeCombo:setHeight(CONTROL_HEIGHT)
    end

    if self.itemList then
        local listY = (CONTROL_HEIGHT * 2) + (UI_BORDER_SPACING * 2)
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
    o.filterType = "Both"
    o.listBoxWidth = width or PANEL_WIDTH
    o.minimumWidth = o.listBoxWidth
    o.minimumHeight = 0

    return o
end
