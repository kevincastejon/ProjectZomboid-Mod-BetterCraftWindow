require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"
require "ISBCWCraftRecipePanel"
require "ISBCWCraftItemFilterPanel"

ISBCWHandCraftPanel = ISHandCraftPanel:derive("ISBCWHandCraftPanel")

local ITEM_FILTER_WIDTH = 185 * (getTextManager():getFontHeight(UIFont.Small) / 19)

-- Better Craft Window owns its category + item-filter area. Vanilla windows
-- are untouched because this override only exists on ISBCWHandCraftPanel.
function ISBCWHandCraftPanel:createRecipeCategoryColumn()
    self.recipeCategories = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISWidgetRecipeCategories,
        0, 0, 10, 10
    )
    self.recipeCategories.autoWidth = true
    self.recipeCategories.callbackTarget = self
    self.recipeCategories:initialise()
    self.recipeCategories:instantiate()

    local categoryColumn = self.rootTable:addColumn(nil)
    self.rootTable:setElement(categoryColumn:index(), 0, self.recipeCategories)

    -- New BCW-only item panel, immediately to the right of Categories.
    self.bcwCraftItemFilterPanel = ISBCWCraftItemFilterPanel:new(
        0, 0,
        ITEM_FILTER_WIDTH,
        10,
        self
    )
    self.bcwCraftItemFilterPanel:initialise()
    self.bcwCraftItemFilterPanel:instantiate()

    self.bcwCraftItemFilterColumn = self.rootTable:addColumn(nil)
    self.rootTable:setElement(
        self.bcwCraftItemFilterColumn:index(),
        0,
        self.bcwCraftItemFilterPanel
    )
end

-- Better Craft Window owns its recipe-list UI. The vanilla
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

function ISBCWHandCraftPanel:getBCWBaseRecipeList()
    if self.seeAllRecipe then
        return ScriptManager.instance:getAllCraftRecipes()
    end

    if self.recipeQuery then
        return CraftRecipeManager.queryRecipes(self.recipeQuery)
    end

    if self.craftBench then
        return self.craftBench:getRecipes()
    end

    return nil
end

function ISBCWHandCraftPanel:rebuildBCWCraftItemList()
    if not self.bcwCraftItemFilterPanel then
        return
    end

    local recipes = self:getBCWBaseRecipeList()
    local byFullName = {}
    local items = {}

    if recipes then
        for recipeIndex = 0, recipes:size() - 1 do
            local recipe = recipes:get(recipeIndex)

            if recipe then
                local inputs = recipe:getInputs()

                if inputs then
                    for inputIndex = 0, inputs:size() - 1 do
                        local input = inputs:get(inputIndex)

                        if input
                            and not input:isAutomationOnly()
                            and input:getResourceType() == ResourceType.Item then

                            local possibleItems = input:getPossibleInputItems()

                            if possibleItems then
                                for itemIndex = 0, possibleItems:size() - 1 do
                                    local itemScript = possibleItems:get(itemIndex)

                                    if itemScript then
                                        local fullName = itemScript:getFullName()

                                        if fullName and fullName ~= "" and not byFullName[fullName] then
                                            local displayName = itemScript:getDisplayName()

                                            local entry = {
                                                fullName = fullName,
                                                displayName = displayName or fullName,
                                                itemScript = itemScript
                                            }

                                            byFullName[fullName] = entry
                                            table.insert(items, entry)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(items, function(a, b)
        local an = string.lower(a.displayName or a.fullName or "")
        local bn = string.lower(b.displayName or b.fullName or "")

        if an == bn then
            return (a.fullName or "") < (b.fullName or "")
        end

        return an < bn
    end)

    self.bcwCraftItems = items
    self.bcwCraftItemFilterPanel:setItems(items)
    self.bcwCraftItemFilterPanel:setSelectedFullName(self.bcwSelectedCraftItemFullName)
end

function ISBCWHandCraftPanel:onBCWCraftItemFilterChanged(entry)
    if not entry or entry.isAll then
        self.bcwSelectedCraftItemFullName = nil
        self:setRecipeFilter(nil, nil)
    else
        self.bcwSelectedCraftItemFullName = entry.fullName

        -- Exact same recipe filter used by vanilla's inventory context action:
        -- "Search recipes..." -> !Full.Item.Type + InputName.
        self:setRecipeFilter("!" .. entry.fullName, "InputName")
    end

    self.logic:checkValidRecipeSelected()
    self:onRecipeChanged(self.logic:getRecipe())
end

-- Vanilla mutates _filterString by appending the mode each time this method is
-- called. That is normally masked by the search widget resetting the string,
-- but a persistent item selection would append "-@-InputName" repeatedly when
-- categories change. Keep the same filtering semantics without mutating state.
function ISBCWHandCraftPanel:filterRecipeList()
    local filterString = self._filterString

    if self._filterMode and filterString and filterString ~= "" then
        filterString = filterString .. "-@-" .. self._filterMode
    end

    self.logic:filterRecipeList(filterString, self._categoryString)
    self.recipesPanel:filterRecipeList()
end

function ISBCWHandCraftPanel:refreshRecipeList(forceRefresh)
    ISHandCraftPanel.refreshRecipeList(self, forceRefresh)
    self:rebuildBCWCraftItemList()
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
    -- This is set before createChildren()/instantiate(), so the very first
    -- vanilla refreshRecipeList() already uses the right mode.
    o.seeAllRecipe = seeAllRecipe == true
    o.bcwSelectedCraftItemFullName = nil
    o.bcwCraftItems = {}

    return o
end
