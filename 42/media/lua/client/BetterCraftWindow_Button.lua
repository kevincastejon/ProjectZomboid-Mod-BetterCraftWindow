require "ISUI/ISEquippedItem"
require "ISBetterCraftWindow"

local UI_BORDER_SPACING = 10

local function onBetterCraftWindowButton(target)
    if not target or not target.chr then
        return
    end

    ISBetterCraftWindow.toggle(target.chr)
end

local vanillaInitialise = ISEquippedItem.initialise

function ISEquippedItem:initialise()
    vanillaInitialise(self)

    if not self.chr or self.chr:getPlayerNum() ~= 0 or self.bcwButton then
        return
    end

    local reference = self.craftingBtn or self.buildBtn or self.invBtn
    if not reference then
        return
    end

    local y = self:getHeight() + UI_BORDER_SPACING + 5

    self.bcwButton = ISButton:new(
        0,
        y,
        reference:getWidth(),
        reference:getHeight(),
        "BCW",
        self,
        onBetterCraftWindowButton
    )
    self.bcwButton:initialise()
    self.bcwButton:instantiate()
    self.bcwButton:ignoreWidthChange()
    self.bcwButton:ignoreHeightChange()
    self:addChild(self.bcwButton)
    self:addMouseOverToolTipItem(self.bcwButton, "Better Craft Window")

    self:setHeight(self.bcwButton:getBottom())
end
