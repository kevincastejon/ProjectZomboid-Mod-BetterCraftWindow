require "ISUI/ISPanel"
require "BCWXpUtils"

ISWidgetRecipeXP = ISPanel:derive("ISWidgetRecipeXP")

function ISWidgetRecipeXP:initialise()
    ISPanel.initialise(self)
end

function ISWidgetRecipeXP:createChildren()
    ISPanel.createChildren(self)
end

function ISWidgetRecipeXP:getAwards()
    return BCWXpUtils.getAwards(self.player, self.logic and self.logic:getRecipe() or nil)
end

function ISWidgetRecipeXP:calculateLayout(preferredWidth, preferredHeight)
    local width = math.max(self.minimumWidth, preferredWidth or 0)
    local awards = self:getAwards()
    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    local height = self.margin * 2 + lineHeight
    if #awards > 0 then
        height = height + self.margin + (#awards * lineHeight)
    end
    self:setWidth(width)
    self:setHeight(math.max(height, self.minimumHeight))
end

function ISWidgetRecipeXP:prerender()
    ISPanel.prerender(self)
    local awards = self:getAwards()
    local x, y = self.margin, self.margin
    self:drawText("CRAFTING EXPERIENCE", x, y, 1, 1, 1, 1, UIFont.Small)
    y = y + getTextManager():getFontHeight(UIFont.Small) + self.margin

    local good = getCore():getGoodHighlitedColor()
    for _, award in ipairs(awards) do
        local amountText = "+" .. BCWXpUtils.formatXP(award.amount) .. " XP"
        self:drawText(award.name, x, y, 0.85, 0.85, 0.85, 1, UIFont.Small)
        local amountWidth = getTextManager():MeasureStringX(UIFont.Small, amountText)
        self:drawText(amountText, self.width - self.margin - amountWidth, y, good:getR(), good:getG(), good:getB(), 1, UIFont.Small)
        y = y + getTextManager():getFontHeight(UIFont.Small)
    end
end

function ISWidgetRecipeXP:new(x, y, width, height, player, logic)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.logic = logic
    o.margin = 6
    o.minimumWidth = 100
    o.minimumHeight = 20
    return o
end
