require "Entity/ISUI/CraftRecipe/ISWidgetInput"

ISBCWWidgetInput = ISWidgetInput:derive("ISBCWWidgetInput")

local function getDisplayedItemName(widget)
    -- Match the item name currently shown by the vanilla widget. When a
    -- secondary CreateTo/FakeOutput entry is displayed, vanilla treats that
    -- as the visible item; otherwise use the primary entry.
    if widget.secondary and widget.secondary.iconText and widget.secondary.iconText ~= "" then
        return widget.secondary.iconText
    end

    if widget.primary and widget.primary.iconText and widget.primary.iconText ~= "" then
        return widget.primary.iconText
    end

    return nil
end

function ISBCWWidgetInput:onMouseDown(x, y)
    if self.isBuildMenu then
        return ISWidgetInput.onMouseDown(self, x, y)
    end

    if isShiftKeyDown() then
        if self.primary then
            getSoundManager():playUISound("UIActivateButton")
        end

        local itemName = getDisplayedItemName(self)
        local target = self.bcwHandCraftPanel

        if itemName and target and target.setBCWItemSearchText then
            target:setBCWItemSearchText(itemName)
        end

        -- In BCW, Shift-click on both required items and result-like input
        -- widgets searches the custom item panel. Do not call vanilla here,
        -- otherwise it would also populate the vanilla recipe-search field.
        return
    end

    -- Plain click keeps the normal vanilla behaviour, including opening and
    -- closing the manual compatible-ingredients selector.
    return ISWidgetInput.onMouseDown(self, x, y)
end

function ISBCWWidgetInput:new(x, y, width, height, player, logic, inputScript)
    return ISWidgetInput.new(self, x, y, width, height, player, logic, inputScript)
end
