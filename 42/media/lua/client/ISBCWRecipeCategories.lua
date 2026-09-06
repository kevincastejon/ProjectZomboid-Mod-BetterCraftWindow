require "Entity/ISUI/CraftRecipe/ISWidgetRecipeCategories"

local FONT_SCALE = getTextManager():getFontHeight(UIFont.Small) / 19
local MIN_LIST_BOX_WIDTH = 125 * FONT_SCALE
local TEXT_LEFT_PADDING = 15
local TEXT_RIGHT_PADDING = 8 * FONT_SCALE

ISBCWRecipeCategories = ISWidgetRecipeCategories:derive("ISBCWRecipeCategories")

-- Vanilla sizes this column a little too tightly: ISScrollingListBox draws its
-- text at x=15, but the auto-width calculation does not reserve those 15 px.
-- Once the vertical scrollbar is visible, the last characters can therefore
-- end up directly against / underneath the scrollbar.  Keep vanilla behavior
-- but reserve the real left text offset, a small right gutter and the scrollbar.
function ISBCWRecipeCategories:calculateLayout(preferredWidth, preferredHeight)
    local biggestSize = 0

    if self.autoWidth and self.recipeCategoryPanel then
        for _, item in pairs(self.recipeCategoryPanel.items) do
            local size = getTextManager():MeasureStringX(UIFont.Small, item.text)
            if size > biggestSize then
                biggestSize = size
            end
        end
    end

    local width = self.listBoxWidth or MIN_LIST_BOX_WIDTH

    if biggestSize > 0 then
        local desiredWidth = biggestSize + TEXT_LEFT_PADDING + TEXT_RIGHT_PADDING

        if self.recipeCategoryPanel and self.recipeCategoryPanel.vscroll then
            desiredWidth = desiredWidth + self.recipeCategoryPanel.vscroll:getWidth()
        end

        width = math.max(width, desiredWidth)
    end

    self:setWidth(width)

    if self.recipeCategoryPanel then
        self.recipeCategoryPanel:setWidth(width)

        if self.recipeCategoryPanel.vscroll then
            self.recipeCategoryPanel.vscroll:setX(
                width - self.recipeCategoryPanel.vscroll:getWidth()
            )
        end
    end

    self:setHeight(preferredHeight)
    self:setInternalHeight(preferredHeight)
end

function ISBCWRecipeCategories:new(x, y, width, height)
    local o = ISWidgetRecipeCategories.new(self, x, y, width, height)
    return o
end
