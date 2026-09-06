require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"
require "ISBCWCraftRecipePanel"

ISBCWHandCraftPanel = ISHandCraftPanel:derive("ISBCWHandCraftPanel")

function ISBCWHandCraftPanel:createRecipePanel()
    self.recipePanel = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISBCWCraftRecipePanel,
        0, 0, 10, 10,
        self.player,
        self.logic
    )
    self.recipePanel:initialise()
    self.recipePanel:instantiate()
    self.recipePanel.isBuildMenu = false

    self.recipePanelColumn = self.rootTable:addColumn(nil)
    self.rootTable:setElement(self.recipePanelColumn:index(), 0, self.recipePanel)
end

function ISBCWHandCraftPanel:new(x, y, width, height, player, craftBench, isoObject, recipeQuery)
    return ISHandCraftPanel.new(
        self,
        x, y, width, height,
        player,
        craftBench,
        isoObject,
        recipeQuery
    )
end
