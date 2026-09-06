require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"
require "ISBCWCraftRecipePanel"

ISBCWHandCraftPanel = ISHandCraftPanel:derive("ISBCWHandCraftPanel")

-- Better Craft Window owns its recipe-list UI.  The vanilla
-- "Show all recipes" checkbox is deliberately not created here;
-- the window context controls seeAllRecipe instead.
function ISBCWHandCraftPanel:createRecipesColumn()
    self.recipesPanel = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISWidgetRecipesPanel,
        0, 0, 10, 10,
        self.player,
        self.craftBench,
        self.isoObject,
        self.logic,
        self
    )

    self.recipesPanel.needSortCombo = true
    self.recipesPanel.needFilterCombo = true
    self.recipesPanel.showAllCraftFilterTickBox = false
    self.recipesPanel.wrapTooltipText = true

    self.recipesPanel:initialise()
    self.recipesPanel:instantiate()
    self.recipesPanel.noTooltip = true

    self.recipesPanel.recipeListPanel.recipeListPanel:setOnMouseDoubleClick(
        self,
        ISHandCraftPanel.onDoubleClick
    )

    local column = self.rootTable:addColumnFill(nil)
    self.rootTable:setElement(column:index(), 0, self.recipesPanel)
end

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

function ISBCWHandCraftPanel:new(
    x,
    y,
    width,
    height,
    player,
    craftBench,
    isoObject,
    recipeQuery,
    seeAllRecipe
)
    local o = ISHandCraftPanel.new(
        self,
        x, y, width, height,
        player,
        craftBench,
        isoObject,
        recipeQuery
    )

    -- ALL context: true.
    -- Workstation contexts: false.
    -- This is set before createChildren()/instantiate(), so the very
    -- first vanilla refreshRecipeList() already uses the right mode.
    o.seeAllRecipe = seeAllRecipe == true

    return o
end
