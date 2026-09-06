require "Entity/ISUI/CraftRecipe/ISWidgetInput"

ISBCWWidgetInput = ISWidgetInput:derive("ISBCWWidgetInput")

local function getDisplayedOutputName(widget)
    if widget.secondary and widget.secondary.iconText and widget.secondary.iconText ~= "" then
        return widget.secondary.iconText
    end

    if widget.primary and widget.primary.iconText and widget.primary.iconText ~= "" then
        return widget.primary.iconText
    end

    return nil
end

function ISBCWWidgetInput:onMouseDown(x, y)
    -- This subclass is only used by the Results panel for FakeOutput/Keep
    -- entries. Preserve vanilla input behaviour everywhere except Shift-click
    -- while the widget is being displayed as an output.
    if self.displayAsOutput and isShiftKeyDown() then
        if self.primary then
            getSoundManager():playUISound("UIActivateButton")
        end

        local itemName = getDisplayedOutputName(self)
        local target = self.bcwHandCraftPanel

        if itemName and target and target.setBCWItemSearchText then
            target:setBCWItemSearchText(itemName)
        end

        return
    end

    return ISWidgetInput.onMouseDown(self, x, y)
end

function ISBCWWidgetInput:new(x, y, width, height, player, logic, inputScript)
    return ISWidgetInput.new(self, x, y, width, height, player, logic, inputScript)
end
