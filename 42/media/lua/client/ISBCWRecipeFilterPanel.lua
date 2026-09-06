require "Entity/ISUI/CraftRecipe/ISWidgetRecipeFilterPanel"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.NewSmall)
local UI_BORDER_SPACING = 5
local BUTTON_HGT = FONT_HGT_SMALL + 6

ISBCWRecipeFilterPanel = ISWidgetRecipeFilterPanel:derive("ISBCWRecipeFilterPanel")

function ISBCWRecipeFilterPanel:createChildren()
    ISWidgetRecipeFilterPanel.createChildren(self)

    self.unknownRecipeButton = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISButton,
        0, 0, BUTTON_HGT, BUTTON_HGT,
        nil
    )
    self.unknownRecipeButton.image = getTexture("media/ui/craftingMenus/BuildProperty_Book_16.png")
    self.unknownRecipeButton.target = self
    self.unknownRecipeButton.onclick = ISBCWRecipeFilterPanel.onBCWButtonClick
    self.unknownRecipeButton.enable = true
    self.unknownRecipeButton:initialise()
    self.unknownRecipeButton:instantiate()

    -- BCW-only toggle state overlay. The vanilla book texture remains the
    -- primary icon; when the filter is active we draw a small green check
    -- in the bottom-right corner so the state is unambiguous.
    self.unknownRecipeButton.prerender = function(button)
        ISButton.prerender(button)

        if button.bcwToggleActive then
            local size = math.max(8, math.floor(button:getHeight() * 0.38))
            local x = button:getWidth() - size - 2
            local y = button:getHeight() - size - 2

            local good = getCore():getGoodHighlitedColor()

            button:drawRect(
                x,
                y,
                size,
                size,
                0.95,
                0.05,
                0.05,
                0.05
            )

            button:drawRectBorder(
                x,
                y,
                size,
                size,
                1.0,
                good:getR(),
                good:getG(),
                good:getB()
            )

            button:drawTextCentre(
                "✓",
                x + (size / 2),
                y - 1,
                good:getR(),
                good:getG(),
                good:getB(),
                1.0,
                UIFont.Small
            )
        end
    end

    self:addChild(self.unknownRecipeButton)

    self.refreshButton = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISButton,
        0, 0, BUTTON_HGT, BUTTON_HGT,
        nil
    )
    self.refreshButton.image = getTexture("media/ui/Sidebar/48/Furniture_Rotate_48.png")
    self.refreshButton.target = self
    self.refreshButton.onclick = ISBCWRecipeFilterPanel.onBCWButtonClick
    self.refreshButton.enable = true
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self:addChild(self.refreshButton)

    self:updateBCWButtons()
end

function ISBCWRecipeFilterPanel:updateBCWButtons()
    local showUnknown = self.callbackTarget and self.callbackTarget.bcwShowUnknownRecipes == true

    if self.unknownRecipeButton then
        self.unknownRecipeButton.bcwToggleActive = showUnknown

        local good = getCore():getGoodHighlitedColor()

        if showUnknown then
            self.unknownRecipeButton.backgroundColor.a = 0.85
            self.unknownRecipeButton.borderColor.a = 1.0
            self.unknownRecipeButton.borderColor.r = good:getR()
            self.unknownRecipeButton.borderColor.g = good:getG()
            self.unknownRecipeButton.borderColor.b = good:getB()
        else
            self.unknownRecipeButton.backgroundColor.a = 0.35
            self.unknownRecipeButton.borderColor.a = 0.5
            self.unknownRecipeButton.borderColor.r = 1.0
            self.unknownRecipeButton.borderColor.g = 1.0
            self.unknownRecipeButton.borderColor.b = 1.0
        end

        self.unknownRecipeButton.tooltip = showUnknown
            and "Unknown recipes shown. Click to hide them."
            or "Unknown recipes hidden. Click to show them."
    end

    if self.refreshButton then
        self.refreshButton.tooltip = "Refresh crafting data"
    end
end

function ISBCWRecipeFilterPanel:onBCWButtonClick(button)
    if button == self.unknownRecipeButton then
        if self.callbackTarget and self.callbackTarget.toggleBCWHideUnknownRecipes then
            self.callbackTarget:toggleBCWHideUnknownRecipes()
        end
        self:updateBCWButtons()
        return
    end

    if button == self.refreshButton then
        if self.callbackTarget and self.callbackTarget.refreshBCWCraftingData then
            self.callbackTarget:refreshBCWCraftingData()
        end
        return
    end

    ISWidgetRecipeFilterPanel.onButtonClick(self, button)
end

function ISBCWRecipeFilterPanel:calculateLayout(_preferredWidth, _preferredHeight)
    local width = math.max(self.minimumWidth, _preferredWidth or 0)
    local x = UI_BORDER_SPACING + 1

    if self.filterTypeCombo and self.sortCombo then
        local widthDiff = self.viewModeButton:getWidth() + UI_BORDER_SPACING
        local targetWidth = math.max(
            self.sortCombo:getWidth(),
            self.filterTypeCombo:getWidth() + widthDiff
        )
        self.filterTypeCombo:setWidth(targetWidth - widthDiff)
        self.sortCombo:setWidth(targetWidth)
    end

    -- Right-side action strip: view mode, unknown toggle, refresh.
    self.refreshButton:setX(width - self.refreshButton:getWidth() - x)
    self.refreshButton:setY(x)

    self.unknownRecipeButton:setX(
        self.refreshButton:getX() - self.unknownRecipeButton:getWidth() - UI_BORDER_SPACING
    )
    self.unknownRecipeButton:setY(x)

    self.viewModeButton:setX(
        self.unknownRecipeButton:getX() - self.viewModeButton:getWidth() - UI_BORDER_SPACING
    )
    self.viewModeButton:setY(x)

    if self.filterTypeCombo then
        self.filterTypeCombo:setX(
            self.viewModeButton:getX() - self.filterTypeCombo:getWidth() - UI_BORDER_SPACING
        )
        self.filterTypeCombo:setY(self.viewModeButton:getY())
    end

    self.searchEntryBox:setX(x)
    if self.filterTypeCombo then
        self.searchEntryBox:setWidth(
            self.filterTypeCombo:getX() - self.searchEntryBox:getX() - UI_BORDER_SPACING
        )
    else
        self.searchEntryBox:setWidth(
            self.viewModeButton:getX() - self.searchEntryBox:getX() - UI_BORDER_SPACING
        )
    end
    self.searchEntryBox:setY(self.viewModeButton:getY())

    local y = self.searchEntryBox:getBottom() + UI_BORDER_SPACING
    local yOffset = 0

    if self.sortCombo and self.sortComboLabel then
        if self.filterTypeCombo then
            self.sortCombo:setX(self.filterTypeCombo:getX())
        else
            self.sortCombo:setX(
                self.refreshButton:getX() + self.refreshButton:getWidth() - self.sortCombo:getWidth()
            )
        end
        self.sortCombo:setY(y)

        self.sortComboLabel:setX(
            self.sortCombo:getX() - self.sortComboLabel:getWidth() - UI_BORDER_SPACING
        )
        self.sortComboLabel:setY(
            y + ((self.sortCombo:getHeight() - self.sortComboLabel:getHeight()) / 2)
        )
        yOffset = BUTTON_HGT + UI_BORDER_SPACING
    end

    local tickboxWidth = 0

    if self.showAllRecipeTickBox then
        self.showAllRecipeTickBox:setX(x)
        self.showAllRecipeTickBox:setY(y)
        yOffset = BUTTON_HGT + UI_BORDER_SPACING
        tickboxWidth = self.showAllRecipeTickBox:getWidth()
    end

    if self.tickBoxShowAllVersion then
        self.tickBoxShowAllVersion:setX(x)
        self.tickBoxShowAllVersion:setY(y)
        yOffset = BUTTON_HGT + UI_BORDER_SPACING
        tickboxWidth = math.max(self.tickBoxShowAllVersion:getWidth(), tickboxWidth)
    end

    local rightControlsWidth =
        self.viewModeButton:getWidth()
        + self.unknownRecipeButton:getWidth()
        + self.refreshButton:getWidth()
        + (UI_BORDER_SPACING * 2)

    local comboWidth = self.sortCombo and self.sortCombo:getWidth() or 0
    self.minimumWidth = math.max(
        tickboxWidth + comboWidth + UI_BORDER_SPACING,
        rightControlsWidth + 180
    )

    self:setWidth(width)
    self:setHeight(y + yOffset + 1)
end

function ISBCWRecipeFilterPanel:new(x, y, width, height, callbackTarget)
    local o = ISWidgetRecipeFilterPanel.new(self, x, y, width, height, callbackTarget)
    return o
end
