require "Entity/ISUI/CraftRecipe/ISCraftRecipePanel"
require "ISWidgetRecipeXP"
require "ISBCWWidgetIngredientsOutputs"
require "ISBCWWidgetIngredientsInputs"

ISBCWCraftRecipePanel = ISCraftRecipePanel:derive("ISBCWCraftRecipePanel")

function ISBCWCraftRecipePanel:createDynamicChildren()
    self.rootTable:clearTable()

    local recipe = self.logic:getRecipe()
    if not recipe then
        self:xuiRecalculateLayout()
        return
    end

    self.rootTable:addColumnFill(nil)

    local row

    local favString = BaseCraftingLogic.getFavouriteModDataString(recipe)
    local isFavourite = self.player:getModData()[favString] or false

    self.titleWidget = ISXuiSkin.build(
        self.xuiSkin,
        "S_WidgetTitleHeader_Std",
        ISWidgetTitleHeader,
        0, 0, 10, 10,
        recipe,
        self.player,
        self.logic,
        isFavourite
    )
    self.titleWidget:initialise()
    self.titleWidget:instantiate()

    row = self.rootTable:addRow()
    self.rootTable:setElement(0, row:index(), self.titleWidget)

    self.rootTable:addRowFill(nil)

    self.inputs = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISBCWWidgetIngredientsInputs,
        0, 0, 10, 10,
        self.player,
        self.logic
    )
    self.inputs.isBuildMenu = self.isBuildMenu
    self.inputs.interactiveMode = true
    self.inputs.bcwHandCraftPanel = self.bcwHandCraftPanel
    self.inputs:initialise()
    self.inputs:instantiate()

    row = self.rootTable:addRow()
    self.rootTable:setElement(0, row:index(), self.inputs)

    self.outputs = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISBCWWidgetIngredientsOutputs,
        0, 0, 10, 10,
        self.player,
        self.logic
    )
    self.outputs.isBuildMenu = self.isBuildMenu
    self.outputs.interactiveMode = true
    self.outputs.bcwHandCraftPanel = self.bcwHandCraftPanel
    self.outputs:initialise()
    self.outputs:instantiate()

    if #self.outputs.outputs > 0 then
        row = self.rootTable:addRow()
        self.rootTable:setElement(0, row:index(), self.outputs)
    else
        self.outputs = nil
    end

    self.bcwXPWidget = nil

    local xpCount = recipe:getXPAwardCount()
    if xpCount and xpCount > 0 then
        self.bcwXPWidget = ISWidgetRecipeXP:new(
            0, 0, 10, 10,
            self.player,
            self.logic
        )
        self.bcwXPWidget:initialise()
        self.bcwXPWidget:instantiate()

        row = self.rootTable:addRow()
        self.rootTable:setElement(0, row:index(), self.bcwXPWidget)
    end

    self.rootTable:addRowFill(nil)

    self.craftControl = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISWidgetHandCraftControl,
        0, 0, 10, 10,
        self.player,
        self.logic
    )
    self.craftControl.interactiveMode = true
    self.craftControl.allowBatchCraft = recipe:isAllowBatchCraft()
    self.craftControl:initialise()
    self.craftControl:instantiate()

    row = self.rootTable:addRow()
    self.rootTable:setElement(0, row:index(), self.craftControl)

    self:xuiRecalculateLayout()
end

function ISBCWCraftRecipePanel:new(x, y, width, height, player, logic)
    return ISCraftRecipePanel.new(self, x, y, width, height, player, logic)
end
