require "Entity/ISUI/CraftRecipe/ISWidgetRecipesPanel"
require "ISBCWWidgetRecipeListPanel"

ISBCWWidgetRecipesPanel = ISWidgetRecipesPanel:derive("ISBCWWidgetRecipesPanel")

function ISBCWWidgetRecipesPanel:createRecipeListPanel(_parentTable)
    self.recipeListPanelRow = _parentTable:addRowFill(nil)

    self.recipeListPanel = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISBCWWidgetRecipeListPanel,
        0, 0, 10, 10,
        self.player,
        self.logic,
        self
    )
    self.recipeListPanel.expandToFitTooltip = self.expandToFitTooltip
    self.recipeListPanel.wrapTooltipText = self.wrapTooltipText
    self.recipeListPanel.ignoreSurface = self.ignoreSurface
    self.recipeListPanel.ignoreLightIcon = self.ignoreLightIcon
    self.recipeListPanel:initialise()
    self.recipeListPanel:instantiate()

    _parentTable:setElement(0, self.recipeListPanelRow:index(), self.recipeListPanel)
    _parentTable:cell(0, self.recipeListPanelRow:index()).padding = 0
end

function ISBCWWidgetRecipesPanel:new(x, y, width, height, player, craftBench, isoObject, logic, callbackTarget)
    return ISWidgetRecipesPanel.new(self, x, y, width, height, player, craftBench, isoObject, logic, callbackTarget)
end
