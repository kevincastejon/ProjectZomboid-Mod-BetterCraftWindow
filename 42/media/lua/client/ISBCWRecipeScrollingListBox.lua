require "Entity/ISUI/CraftRecipe/ISRecipeScrollingListBox"
require "BCWXpUtils"

local UI_BORDER_SPACING = 10
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_HEADING = getTextManager():getFontHeight(UIFont.Small)
local FONT_SCALE = getTextManager():getFontHeight(UIFont.Small) / 19
local ICON_SCALE = math.max(1, (FONT_SCALE - math.floor(FONT_SCALE)) < 0.5 and math.floor(FONT_SCALE) or math.ceil(FONT_SCALE))
local LIST_ICON_SIZE = 32 * ICON_SCALE
local LIST_SUBICON_SIZE = 16 * ICON_SCALE
local LIST_FAVICON_SIZE = 10 * ICON_SCALE
local LIST_SUBICON_SPACING = 2 * ICON_SCALE
local SUBCATEGORY_INDENT = LIST_ICON_SIZE
local XP_TEXT_GAP = 2 * ICON_SCALE
local XP_ROW_GAP = 2 * ICON_SCALE

ISBCWRecipeScrollingListBox = ISRecipeScrollingListBox:derive("ISBCWRecipeScrollingListBox")

function ISBCWRecipeScrollingListBox:getBCWDisplayedAwards(craftRecipe)
    return BCWXpUtils.getAwards(self.player, craftRecipe)
end

function ISBCWRecipeScrollingListBox:getBCWXPColumnWidth(craftRecipe)
    local awards = self:getBCWDisplayedAwards(craftRecipe)
    local maxWidth = 0

    for _, award in ipairs(awards) do
        local amount = "+" .. BCWXpUtils.formatXP(award.amount)
        local width = LIST_SUBICON_SIZE + XP_TEXT_GAP + getTextManager():MeasureStringX(UIFont.Small, amount)
        maxWidth = math.max(maxWidth, width)
    end

    if maxWidth > 0 then
        maxWidth = maxWidth + UI_BORDER_SPACING
    end

    return maxWidth
end

function ISBCWRecipeScrollingListBox:drawBCWXPColumn(craftRecipe, y, safeDrawWidth, color)
    local awards = self:getBCWDisplayedAwards(craftRecipe)
    if #awards == 0 then return end

    local good = getCore():getGoodHighlitedColor()
    local r, g, b, a = good:getR(), good:getG(), good:getB(), color.a
    if not self:isCraftable(craftRecipe) and not self.player:isBuildCheat() then
        r, g, b, a = 0.7, 0.7, 0.7, 0.75
    end

    local right = safeDrawWidth - UI_BORDER_SPACING
    local startY = y + 4 + LIST_SUBICON_SIZE + XP_ROW_GAP

    for i, award in ipairs(awards) do
        local amountText = "+" .. BCWXpUtils.formatXP(award.amount)
        local textWidth = getTextManager():MeasureStringX(UIFont.Small, amountText)
        local pairWidth = LIST_SUBICON_SIZE + XP_TEXT_GAP + textWidth
        local pairX = right - pairWidth
        local rowY = startY + (i - 1) * (LIST_SUBICON_SIZE + XP_ROW_GAP)

        local icon = BCWXpUtils.getPerkIconTexture(award.perk)
        if icon then
            self:drawTextureScaledAspect(icon, pairX, rowY, LIST_SUBICON_SIZE, LIST_SUBICON_SIZE, a, 1, 1, 1)
        end

        local textY = rowY + ((LIST_SUBICON_SIZE - FONT_HGT_SMALL) / 2)
        self:drawText(amountText, pairX + LIST_SUBICON_SIZE + XP_TEXT_GAP, textY, r, g, b, a, UIFont.Small)

        if i < #awards then
            local sepY = rowY + LIST_SUBICON_SIZE + math.floor(XP_ROW_GAP / 2)
            self:drawRect(pairX, sepY, pairWidth, 1, 0.28, 0.65, 0.65, 0.65)
        end
    end
end

function ISBCWRecipeScrollingListBox:doDrawNode(y, item, _alt)
    local craftRecipe = item and item.item
    local isInGroup = item and item.node and item.node:getParent() ~= nil
    local xOffset = isInGroup and SUBCATEGORY_INDENT or 0

    if not craftRecipe then return y end

    local favString = BaseCraftingLogic.getFavouriteModDataString(craftRecipe)
    local isFavourite = self.player:getModData()[favString] or false

    local yActual = self:getYScroll() + y
    if item.cachedHeight and (yActual > self.height or (yActual + item.cachedHeight) < 0) then
        return y + item.cachedHeight
    end

    if not item.height then item.height = self.itemheight end
    local safeDrawWidth = self:getWidth() - (self.vscroll and self.vscroll:getWidth() or 0) - xOffset
    local cheat = self.player:isBuildCheat()
    local color = self:isCraftable(craftRecipe) and {r=1,g=1,b=1,a=1} or {r=0.5,g=0.5,b=0.5,a=1}

    if self.selected == item.index then
        self:drawSelection(0, y, self:getWidth(), item.height - 1)
    elseif self.mouseoverselected == item.index and self:isMouseOver() and not self:isMouseOverScrollBar() then
        self:drawMouseOverHighlight(0, y, self:getWidth(), item.height - 1)
    end

    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    local colGood = {
        r=getCore():getGoodHighlitedColor():getR(),
        g=getCore():getGoodHighlitedColor():getG(),
        b=getCore():getGoodHighlitedColor():getB(),
        a=getCore():getGoodHighlitedColor():getA(),
    }
    local colBad = {
        r=getCore():getBadHighlitedColor():getR(),
        g=getCore():getBadHighlitedColor():getG(),
        b=getCore():getBadHighlitedColor():getB(),
        a=getCore():getBadHighlitedColor():getA(),
    }
    if cheat then colBad = colGood end

    local detailsLeft = UI_BORDER_SPACING + LIST_ICON_SIZE + UI_BORDER_SPACING + xOffset
    local detailsY = 4

    local fileSize = LIST_SUBICON_SIZE == 16 and "_16.png" or ".png"
    local iconRight = safeDrawWidth - UI_BORDER_SPACING - (LIST_SUBICON_SIZE / 2) - LIST_SUBICON_SPACING

    if craftRecipe:isCanWalk() then
        local tex = getTexture("media/ui/craftingMenus/BuildProperty_Walking" .. fileSize)
        self:drawTextureScaledAspect(tex, iconRight, y + detailsY, LIST_SUBICON_SIZE, LIST_SUBICON_SIZE, color.a, color.r, color.g, color.b)
        iconRight = iconRight - LIST_SUBICON_SIZE - LIST_SUBICON_SPACING
    end
    if not craftRecipe:canBeDoneInDark() and not self.ignoreLightIcon then
        local tex = getTexture("media/ui/craftingMenus/BuildProperty_Light" .. fileSize)
        self:drawTextureScaledAspect(tex, iconRight, y + detailsY, LIST_SUBICON_SIZE, LIST_SUBICON_SIZE, color.a, color.r, color.g, color.b)
        iconRight = iconRight - LIST_SUBICON_SIZE - LIST_SUBICON_SPACING
    end
    if craftRecipe:needToBeLearn() then
        local tex = getTexture("media/ui/craftingMenus/BuildProperty_Book" .. fileSize)
        local alpha = self.player:isRecipeKnown(craftRecipe, true) and 1 or 0.5
        self:drawTextureScaledAspect(tex, iconRight, y + detailsY, LIST_SUBICON_SIZE, LIST_SUBICON_SIZE, alpha, color.r, color.g, color.b)
        iconRight = iconRight - LIST_SUBICON_SIZE - LIST_SUBICON_SPACING
    end
    if not craftRecipe:isInHandCraftCraft() and not self.ignoreSurface then
        local tex = getTexture("media/ui/craftingMenus/BuildProperty_Surface" .. fileSize)
        self:drawTextureScaledAspect(tex, iconRight, y + detailsY, LIST_SUBICON_SIZE, LIST_SUBICON_SIZE, color.a, color.r, color.g, color.b)
        iconRight = iconRight - LIST_SUBICON_SIZE - LIST_SUBICON_SPACING
    end

    local topRightReserved = (safeDrawWidth - iconRight) + UI_BORDER_SPACING
    local xpRightReserved = self:getBCWXPColumnWidth(craftRecipe)
    local rightReserved = math.max(topRightReserved, xpRightReserved)

    local headerAdj = (LIST_SUBICON_SIZE - FONT_HGT_HEADING) / 2
    detailsY = detailsY + headerAdj
    local maxTitleWidth = math.max(40, (safeDrawWidth - detailsLeft) - rightReserved)
    local titleStr = getTextManager():WrapText(UIFont.Small, craftRecipe:getTranslationName(), maxTitleWidth, 2, "...")

    if isDebugEnabled() then
        local tags = ""
        for i=0,craftRecipe:getTags():size()-1 do
            tags = tags .. craftRecipe:getTags():get(i)
            if i < craftRecipe:getTags():size()-1 then tags = tags .. "," end
        end
        titleStr = titleStr .. "\n (tags: " .. tags .. ")"
    end

    self:drawText(titleStr, detailsLeft, y + detailsY, color.r, color.g, color.b, color.a, UIFont.Small)
    detailsY = detailsY + getTextManager():MeasureStringY(UIFont.Small, titleStr)

    if craftRecipe:getTooltip() then
        local text = getText(craftRecipe:getTooltip())
        if self.wrapTooltipText then
            local tooltipWidth = math.max(40, (safeDrawWidth - detailsLeft) - rightReserved)
            text = text:gsub("\n", " ")
            text = getTextManager():WrapText(UIFont.Small, text, tooltipWidth)
        end
        self:drawText(text, detailsLeft, y + detailsY, 0.5, 0.5, 0.5, color.a, UIFont.Small)
        local split = luautils.split(text, "\n")
        for _i,_v in ipairs(split) do detailsY = detailsY + FONT_HGT_SMALL end
    end

    if craftRecipe:getRequiredSkillCount() > 0 then
        for i=0,craftRecipe:getRequiredSkillCount()-1 do
            local requiredSkill = craftRecipe:getRequiredSkill(i)
            local hasSkill = CraftRecipeManager.hasPlayerRequiredSkill(requiredSkill, self.player)
            local lineColor = hasSkill and colGood or colBad
            local text = getText("IGUI_CraftingWindow_Requires2") .. " " .. tostring(requiredSkill:getPerk():getName()) .. " " .. getText("IGUI_CraftingWindow_Level") .. " " .. tostring(requiredSkill:getLevel())
            self:drawText(text, detailsLeft, y + detailsY, lineColor.r, lineColor.g, lineColor.b, lineColor.a, UIFont.Small)
            detailsY = detailsY + FONT_HGT_SMALL
        end
    end

    local awards = self:getBCWDisplayedAwards(craftRecipe)
    local xpHeight = 0
    if #awards > 0 then
        xpHeight = 4 + LIST_SUBICON_SIZE + XP_ROW_GAP + (#awards * LIST_SUBICON_SIZE) + ((#awards - 1) * XP_ROW_GAP) + 4
    end

    local usedHeight = math.max(self.itemheight, detailsY + UI_BORDER_SPACING, xpHeight)
    if isFavourite then
        usedHeight = math.max(usedHeight, LIST_ICON_SIZE + (LIST_FAVICON_SIZE / 2))
    end

    item.height = usedHeight
    item.cachedHeight = usedHeight

    local iconY = y + (usedHeight / 2) - (LIST_ICON_SIZE / 2)
    self:drawTextureScaledAspect(craftRecipe:getIconTexture(), UI_BORDER_SPACING + xOffset, iconY, LIST_ICON_SIZE, LIST_ICON_SIZE, color.a, color.r, color.g, color.b)

    local starY = iconY + LIST_ICON_SIZE - LIST_FAVICON_SIZE
    if isFavourite then
        self:drawTextureScaledAspect(self.starSetTexture, UI_BORDER_SPACING + xOffset, starY, LIST_FAVICON_SIZE, LIST_FAVICON_SIZE, color.a, colGood.r, colGood.g, colGood.b)
    end

    self:drawBCWXPColumn(craftRecipe, y, safeDrawWidth, color)

    return y + usedHeight
end

function ISBCWRecipeScrollingListBox:new(x, y, width, height, player, logic)
    return ISRecipeScrollingListBox.new(self, x, y, width, height, player, logic)
end
