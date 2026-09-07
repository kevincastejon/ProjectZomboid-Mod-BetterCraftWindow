require "Entity/ISUI/CraftRecipe/ISWidgetOutput"

ISBCWWidgetOutput = ISWidgetOutput:derive("ISBCWWidgetOutput")

local function getDisplayedOutputName(widget)
    -- Vanilla displays the secondary CreateTo result when one exists.
    -- For mapped outputs, updateValues() updates primary.iconText to the
    -- currently resolved output, so this also follows the visible result.
    if widget.secondary and widget.secondary.iconText and widget.secondary.iconText ~= "" then
        return widget.secondary.iconText
    end

    if widget.primary and widget.primary.iconText and widget.primary.iconText ~= "" then
        return widget.primary.iconText
    end

    return nil
end

function ISBCWWidgetOutput:onMouseDown(x, y)
    if self.isBuildMenu then
        return
    end

    if not self.primary then
        return
    end

    getSoundManager():playUISound("UIActivateButton")

    if isShiftKeyDown() then
        local itemName = getDisplayedOutputName(self)
        local target = self.bcwHandCraftPanel

        if itemName and target and target.setBCWItemSearchText then
            target:setBCWItemSearchText(itemName)
        end

        -- Deliberately do NOT call vanilla here: in BCW, Shift-clicking an
        -- output searches the custom item panel instead of the recipe bar.
        return
    end

    -- Vanilla ISWidgetOutput has no other left-click action.
end

function ISBCWWidgetOutput:new(x, y, width, height, player, logic, outputScript)
    return ISWidgetOutput.new(self, x, y, width, height, player, logic, outputScript)
end
