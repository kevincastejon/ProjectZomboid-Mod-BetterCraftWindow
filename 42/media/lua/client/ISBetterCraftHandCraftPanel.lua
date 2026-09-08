require "Entity/ISEntityUI"
require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"
require "ISBetterCraftRecipePanel"
require "ISBetterCraftItemFilterPanel"
require "ISBetterCraftRecipeCategories"
require "ISBetterCraftWidgetRecipesPanel"

ISBCWHandCraftPanel = ISHandCraftPanel:derive("ISBCWHandCraftPanel")

local ITEM_FILTER_WIDTH = 185 * (getTextManager():getFontHeight(UIFont.Small) / 19)

-- Temporary BCW diagnostics.
-- The ALL tab has no CraftBench, so it inherits ISHandCraftPanel:update(),
-- which may call ISEntityUI.FindCraftSurface(). Time both the vanilla helper
-- itself and the complete inherited update so we can correlate UI hitches.

function ISBCWHandCraftPanel:update()
    ISPanel.update(self)

    if self.logic:isCraftActionInProgress() then
        return
    end

    if self.updateTimer > 0 then
        self.updateTimer = self.updateTimer - 1
    end

    if not self.craftBench then
        local newIsoObject = ISEntityUI.FindCraftSurface(self.player, 2)
        if self.isoObject ~= newIsoObject then
            self.isoObject = newIsoObject
            self.parent.isoObject = self.isoObject
            self.logic:setIsoObject(self.isoObject)
            self.updateTimer = 0
            self:updateContainers(true)
        end
    end

    if ISHandCraftPanel.drawDirty and self.updateTimer == 0 then
        ISHandCraftPanel.drawDirty = false
        self:refreshRecipeList()
        self.logic:autoPopulateInputs()

        if #self.recipesPanel.recipeListPanel.recipeListPanel.items < 100 then
            self.updateTimer = 1
        else
            self.updateTimer = 10
        end
    end
end

function ISBCWHandCraftPanel:createRecipeCategoryColumn()
    self.recipeCategories = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISBCWRecipeCategories,
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
        ISBCWWidgetRecipesPanel,
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
    self.recipePanel.bcwHandCraftPanel = self
    self.recipePanel:initialise()
    self.recipePanel:instantiate()
    self.recipePanel.isBuildMenu = false

    self.recipePanelColumn = self.rootTable:addColumn(nil)
    self.rootTable:setElement(self.recipePanelColumn:index(), 0, self.recipePanel)
end


local bcwAvailableWorkstationRecipeTags = nil
local bcwFilteredAllCraftRecipes = nil

local function getBCWAvailableWorkstationRecipeTags()
    if bcwAvailableWorkstationRecipeTags then
        return bcwAvailableWorkstationRecipeTags
    end

    local tags = {}
    local entities = ScriptManager.instance:getAllGameEntities()

    if entities then
        for i = 0, entities:size() - 1 do
            local entityScript = entities:get(i)

            if entityScript and entityScript:containsComponent(ComponentType.CraftBench) then
                local craftBenchScript =
                    entityScript:getComponentScriptFor(ComponentType.CraftBench)
                local query =
                    craftBenchScript and craftBenchScript:getRecipeTagQuery() or nil

                if query and query ~= "" then
                    for tag in string.gmatch(tostring(query), "[^;]+") do
                        tag = string.gsub(tag, "^%s*(.-)%s*$", "%1")

                        if tag ~= "" then
                            tags[tag] = true
                        end
                    end
                end
            end
        end
    end

    bcwAvailableWorkstationRecipeTags = tags
    return bcwAvailableWorkstationRecipeTags
end

local function bcwRecipeHasExistingSpecificWorkstation(recipe, availableTags)
    if not recipe or not recipe:requiresSpecificWorkstation() then
        return true
    end

    local recipeTags = recipe:getTags()
    if not recipeTags then
        return false
    end

    for i = 0, recipeTags:size() - 1 do
        local rawTag = recipeTags:get(i)

        if availableTags[rawTag] == true
            or availableTags[tostring(rawTag)] == true then
            return true
        end
    end

    return false
end

local function getBCWFilteredAllCraftRecipes()
    if bcwFilteredAllCraftRecipes then
        return bcwFilteredAllCraftRecipes
    end

    local allRecipes = ScriptManager.instance:getAllCraftRecipes()
    local availableTags = getBCWAvailableWorkstationRecipeTags()
    local filtered = ArrayList.new()

    if allRecipes then
        for i = 0, allRecipes:size() - 1 do
            local recipe = allRecipes:get(i)

            if bcwRecipeHasExistingSpecificWorkstation(recipe, availableTags) then
                filtered:add(recipe)
            end
        end
    end

    bcwFilteredAllCraftRecipes = filtered
    return bcwFilteredAllCraftRecipes
end

function ISBCWHandCraftPanel:getBCWBaseRecipeList()
    if self.seeAllRecipe then
        return getBCWFilteredAllCraftRecipes()
    end

    if self.recipeQuery then
        return CraftRecipeManager.queryRecipes(self.recipeQuery)
    end

    if self.craftBench then
        return self.craftBench:getRecipes()
    end

    return nil
end

-- The custom item filter must never alter the vanilla category list.
-- self.logic may temporarily contain only the recipes matching the selected
-- BCW item, so asking it for getCategoryList() would make categories disappear
-- and would also change the auto-width of the vanilla category column.
-- Build the category list from the unfiltered context instead, exactly as if
-- no BCW item were selected.
function ISBCWHandCraftPanel:getCategoryList()
    local recipes = self:getBCWBaseRecipeList()

    if not recipes then
        return self.logic:getCategoryList()
    end

    local categoryLogic = HandcraftLogic.new(
        self.player,
        self.craftBench,
        self.isoObject
    )
    categoryLogic:setRecipes(recipes)
    return categoryLogic:getCategoryList()
end

local function addBCWItemEntry(byFullName, items, itemScript, isIngredient, isResult)
    if not itemScript then
        return
    end

    local fullName = itemScript:getFullName()
    if not fullName or fullName == "" then
        return
    end

    local entry = byFullName[fullName]

    if not entry then
        entry = {
            fullName = fullName,
            displayName = itemScript:getDisplayName() or fullName,
            itemScript = itemScript,
            isIngredient = false,
            isResult = false
        }

        byFullName[fullName] = entry
        table.insert(items, entry)
    end

    if isIngredient then
        entry.isIngredient = true
    end

    if isResult then
        entry.isResult = true
    end
end

local function collectBCWRecipeInputs(recipe, byFullName, items)
    local inputs = recipe:getInputs()
    if not inputs then
        return
    end

    for inputIndex = 0, inputs:size() - 1 do
        local input = inputs:get(inputIndex)

        if input
            and not input:isAutomationOnly()
            and input:getResourceType() == ResourceType.Item then

            local possibleItems = input:getPossibleInputItems()

            if possibleItems then
                for itemIndex = 0, possibleItems:size() - 1 do
                    addBCWItemEntry(
                        byFullName,
                        items,
                        possibleItems:get(itemIndex),
                        true,
                        false
                    )
                end
            end
        end
    end
end

local function collectBCWRecipeOutputs(recipe, byFullName, items)
    local outputs = recipe:getOutputs()

    if outputs then
        for outputIndex = 0, outputs:size() - 1 do
            local output = outputs:get(outputIndex)

            if output
                and not output:isAutomationOnly()
                and output:getResourceType() == ResourceType.Item then

                local possibleItems = output:getPossibleResultItems()

                if possibleItems then
                    for itemIndex = 0, possibleItems:size() - 1 do
                        addBCWItemEntry(
                            byFullName,
                            items,
                            possibleItems:get(itemIndex),
                            false,
                            true
                        )
                    end
                end
            end
        end
    end

    -- Match the extra item outputs shown by vanilla's Results widget:
    -- FakeOutput inputs can either create another item or return/keep
    -- one of their possible input items.
    local inputs = recipe:getInputs()

    if inputs then
        for inputIndex = 0, inputs:size() - 1 do
            local input = inputs:get(inputIndex)

            if input
                and not input:isAutomationOnly()
                and input:getResourceType() == ResourceType.Item
                and input:hasFlag(InputFlag.FakeOutput) then

                local createTo = input:getCreateToItemScript()

                if createTo and createTo:getResourceType() == ResourceType.Item then
                    local possibleItems = createTo:getPossibleResultItems()

                    if possibleItems then
                        for itemIndex = 0, possibleItems:size() - 1 do
                            addBCWItemEntry(
                                byFullName,
                                items,
                                possibleItems:get(itemIndex),
                                false,
                                true
                            )
                        end
                    end
                elseif input:isKeep() then
                    local possibleItems = input:getPossibleInputItems()

                    if possibleItems then
                        for itemIndex = 0, possibleItems:size() - 1 do
                            addBCWItemEntry(
                                byFullName,
                                items,
                                possibleItems:get(itemIndex),
                                false,
                                true
                            )
                        end
                    end
                end
            end
        end
    end
end

local function recipeHasBCWInput(recipe, fullName)
    local inputs = recipe:getInputs()
    if not inputs then
        return false
    end

    for inputIndex = 0, inputs:size() - 1 do
        local input = inputs:get(inputIndex)

        if input
            and not input:isAutomationOnly()
            and input:getResourceType() == ResourceType.Item then

            local possibleItems = input:getPossibleInputItems()

            if possibleItems then
                for itemIndex = 0, possibleItems:size() - 1 do
                    local itemScript = possibleItems:get(itemIndex)

                    if itemScript and itemScript:getFullName() == fullName then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function recipeHasBCWOutput(recipe, fullName)
    local outputs = recipe:getOutputs()

    if outputs then
        for outputIndex = 0, outputs:size() - 1 do
            local output = outputs:get(outputIndex)

            if output
                and not output:isAutomationOnly()
                and output:getResourceType() == ResourceType.Item then

                local possibleItems = output:getPossibleResultItems()

                if possibleItems then
                    for itemIndex = 0, possibleItems:size() - 1 do
                        local itemScript = possibleItems:get(itemIndex)

                        if itemScript and itemScript:getFullName() == fullName then
                            return true
                        end
                    end
                end
            end
        end
    end

    local inputs = recipe:getInputs()

    if inputs then
        for inputIndex = 0, inputs:size() - 1 do
            local input = inputs:get(inputIndex)

            if input
                and not input:isAutomationOnly()
                and input:getResourceType() == ResourceType.Item
                and input:hasFlag(InputFlag.FakeOutput) then

                local createTo = input:getCreateToItemScript()

                if createTo and createTo:getResourceType() == ResourceType.Item then
                    local possibleItems = createTo:getPossibleResultItems()

                    if possibleItems then
                        for itemIndex = 0, possibleItems:size() - 1 do
                            local itemScript = possibleItems:get(itemIndex)

                            if itemScript and itemScript:getFullName() == fullName then
                                return true
                            end
                        end
                    end
                end

                if not createTo and input:isKeep() then
                    local possibleItems = input:getPossibleInputItems()

                    if possibleItems then
                        for itemIndex = 0, possibleItems:size() - 1 do
                            local itemScript = possibleItems:get(itemIndex)

                            if itemScript and itemScript:getFullName() == fullName then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

-- Return the unfiltered recipe context restricted to the currently selected
-- vanilla category. This is used only to build BCW's item list; the vanilla
-- category widget itself remains completely untouched.
function ISBCWHandCraftPanel:getBCWCategoryRecipeList()
    local recipes = self:getBCWBaseRecipeList()

    if not recipes then
        return nil
    end

    local category = self._categoryString

    -- Empty category is vanilla's ALL category.
    if not category or category == "" then
        return recipes
    end

    -- Do not ask a second HandcraftLogic to apply the category filter here.
    -- That path did not reliably mirror the category currently selected in
    -- ISWidgetRecipeCategories and caused the BCW item list to be built from
    -- the whole category set. Instead, scope the source recipes explicitly to
    -- the exact category selected by the vanilla category widget.
    local filtered = ArrayList.new()

    for recipeIndex = 0, recipes:size() - 1 do
        local recipe = recipes:get(recipeIndex)

        if recipe then
            local matches = false

            if category == "*" then
                -- Vanilla Favourites category.
                local favString = BaseCraftingLogic.getFavouriteModDataString(recipe)
                matches = self.player:getModData()[favString] == true
            else
                matches = recipe:getCategory() == category
            end

            if matches then
                filtered:add(recipe)
            end
        end
    end

    return filtered
end

local function findBCWCraftItemEntry(items, fullName)
    if not fullName then
        return nil
    end

    for _, entry in ipairs(items or {}) do
        if entry.fullName == fullName then
            return entry
        end
    end

    return nil
end

function ISBCWHandCraftPanel:isBCWCraftItemValidForCurrentType(entry)
    if not entry then
        return false
    end

    local filterType = self.bcwCraftItemFilterType or "Both"

    return filterType == "Both"
        or (filterType == "Ingredient" and entry.isIngredient == true)
        or (filterType == "Result" and entry.isResult == true)
end

local function isBCWRecipeKnown(player, recipe)
    if not recipe then
        return false
    end

    if not recipe:needToBeLearn() then
        return true
    end

    return player:isRecipeKnown(recipe, true)
end

function ISBCWHandCraftPanel:rebuildBCWCraftItemList(forceRebuild)
    if not self.bcwCraftItemFilterPanel then
        return false
    end

    -- The item universe depends on the recipe CONTEXT, not on inventory
    -- availability. Vanilla can mark the hand-craft panel dirty very often
    -- while nothing about this universe has changed. On the ALL tab that
    -- previously meant rescanning ~1000 recipes every dirty refresh.
    --
    -- Keep a tiny context signature and reuse the already-built item list
    -- until the recipe scope actually changes. Favorites are deliberately
    -- excluded from this optimization because their membership can change
    -- without the category string changing.
    local category = self._categoryString or ""
    local canReuse = not forceRebuild
        and category ~= "*"
        and self.bcwCraftItemListBuilt == true
        and self.bcwCraftItemListSeeAll == (self.seeAllRecipe == true)
        and self.bcwCraftItemListCraftBench == self.craftBench
        and self.bcwCraftItemListRecipeQuery == self.recipeQuery
        and self.bcwCraftItemListCategory == category

    if canReuse then
        -- The data and visible item list are already valid for this recipe
        -- context. Do not call setItems() here: that method rebuilds the
        -- entire scrolling UI list and was still costing ~50-60 ms on ALL.
        return false
    end

    -- Important: the item list follows the selected VANILLA category.
    -- Example: selecting Forge only exposes inputs/results from Forge recipes.
    local recipes = self:getBCWCategoryRecipeList()
    local byFullName = {}
    local items = {}

    if recipes then
        for recipeIndex = 0, recipes:size() - 1 do
            local recipe = recipes:get(recipeIndex)

            if recipe then
                -- The Unknown Recipes toggle only filters the recipe list.
                -- BCW's custom item list is always built from the complete
                -- selected-category recipe scope, including unknown recipes.
                collectBCWRecipeInputs(recipe, byFullName, items)
                collectBCWRecipeOutputs(recipe, byFullName, items)
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

    -- A selected item may disappear when the vanilla category changes.
    -- In that case BCW falls back to ALL, rather than keeping a hidden filter.
    if self.bcwSelectedCraftItemFullName then
        local selectedEntry = findBCWCraftItemEntry(
            items,
            self.bcwSelectedCraftItemFullName
        )

        if not self:isBCWCraftItemValidForCurrentType(selectedEntry) then
            self.bcwSelectedCraftItemFullName = nil
        end
    end

    self.bcwCraftItemFilterPanel:setItems(items)
    self.bcwCraftItemFilterPanel:setFilterType(self.bcwCraftItemFilterType or "Both")
    self.bcwCraftItemFilterPanel:setSelectedFullName(self.bcwSelectedCraftItemFullName)

    self.bcwCraftItemListBuilt = true
    self.bcwCraftItemListSeeAll = self.seeAllRecipe == true
    self.bcwCraftItemListCraftBench = self.craftBench
    self.bcwCraftItemListRecipeQuery = self.recipeQuery
    self.bcwCraftItemListCategory = category

    return true
end

function ISBCWHandCraftPanel:recipePassesBCWVisibilityFilters(recipe)
    if self.bcwShowUnknownRecipes and not isBCWRecipeKnown(self.player, recipe) then
        return false
    end

    local fullName = self.bcwSelectedCraftItemFullName
    if not fullName then
        return true
    end

    local filterType = self.bcwCraftItemFilterType or "Both"
    local matchesIngredient = false
    local matchesResult = false

    if filterType == "Both" or filterType == "Ingredient" then
        matchesIngredient = recipeHasBCWInput(recipe, fullName)
    end

    if filterType == "Both" or filterType == "Result" then
        matchesResult = recipeHasBCWOutput(recipe, fullName)
    end

    return matchesIngredient or matchesResult
end

function ISBCWHandCraftPanel:applyBCWCraftItemRecipeFilter()
    local baseRecipes = self:getBCWBaseRecipeList()
    local filteredRecipes = ArrayList.new()

    if baseRecipes then
        for recipeIndex = 0, baseRecipes:size() - 1 do
            local recipe = baseRecipes:get(recipeIndex)

            if recipe and self:recipePassesBCWVisibilityFilters(recipe) then
                filteredRecipes:add(recipe)
            end
        end
    end

    self.logic:setRecipes(filteredRecipes)
    self:filterRecipeList()
end

-- BCW-specific replacement for vanilla Shift-click on Results.
-- It only fills the custom item-search box; it does not touch the vanilla
-- recipe search field or the current item selection/filter.
function ISBCWHandCraftPanel:setBCWItemSearchText(itemName)
    local panel = self.bcwCraftItemFilterPanel
    if not panel or not panel.searchEntry then
        return
    end

    panel.searchEntry:setText(itemName or "")
    panel:onSearchTextChanged()
end

function ISBCWHandCraftPanel:onBCWCraftItemFilterChanged(entry)
    if not entry or entry.isAll then
        self.bcwSelectedCraftItemFullName = nil
    else
        self.bcwSelectedCraftItemFullName = entry.fullName
    end

    self:applyBCWCraftItemRecipeFilter()
    self.logic:checkValidRecipeSelected()
    self:onRecipeChanged(self.logic:getRecipe())
end

function ISBCWHandCraftPanel:onBCWCraftItemFilterTypeChanged(filterType)
    self.bcwCraftItemFilterType = filterType or "Both"

    local selectedEntry = findBCWCraftItemEntry(
        self.bcwCraftItems,
        self.bcwSelectedCraftItemFullName
    )

    if self.bcwSelectedCraftItemFullName
        and not self:isBCWCraftItemValidForCurrentType(selectedEntry) then
        self.bcwSelectedCraftItemFullName = nil
    end

    self.bcwCraftItemFilterPanel:setSelectedFullName(self.bcwSelectedCraftItemFullName)
    self:applyBCWCraftItemRecipeFilter()
    self.logic:checkValidRecipeSelected()
    self:onRecipeChanged(self.logic:getRecipe())
end

-- Category selection remains vanilla-owned. BCW only observes the selected
-- category so it can rebuild its own item list from that category's recipes.
function ISBCWHandCraftPanel:onCategoryChanged(category)
    self._categoryString = category

    self:rebuildBCWCraftItemList()
    self:applyBCWCraftItemRecipeFilter()

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

    -- Vanilla refreshRecipeList() repopulates HandcraftLogic from its normal
    -- source. In ALL mode that restores getAllCraftRecipes(), so the cached
    -- workstation-availability filter must be re-applied after every vanilla
    -- recipe refresh, even when no BCW item/unknown filter is active.
    if self.seeAllRecipe
        or self.bcwSelectedCraftItemFullName ~= nil
        or self.bcwShowUnknownRecipes == true then
        self:applyBCWCraftItemRecipeFilter()
    end
end

function ISBCWHandCraftPanel:toggleBCWHideUnknownRecipes()
    self.bcwShowUnknownRecipes = not self.bcwShowUnknownRecipes

    -- Do not rebuild/filter BCW's item list here: this toggle is strictly
    -- a recipe-visibility filter.
    self:applyBCWCraftItemRecipeFilter()
    self.logic:checkValidRecipeSelected()
    self:onRecipeChanged(self.logic:getRecipe())

    local filterPanel = self.recipesPanel and self.recipesPanel.recipeFilterPanel
    if filterPanel and filterPanel.updateBCWButtons then
        filterPanel:updateBCWButtons()
    end
end

function ISBCWHandCraftPanel:refreshBCWCraftingData(forceItemListRebuild)
    -- Force a complete client-side rescan of inventory containers and recipe
    -- availability. This is intentionally a manual workaround for vanilla UI
    -- states that can remain stale after inventory changes.
    self:updateContainers(true)

    if self.recipeQuery then
        self.logic:setRecipes(CraftRecipeManager.queryRecipes(self.recipeQuery))
    elseif self.craftBench then
        self.logic:setRecipes(self.craftBench:getRecipes())
    end

    if self.seeAllRecipe then
        self.logic:setRecipes(getBCWFilteredAllCraftRecipes())
    end

    -- A manual/full refresh is allowed to rebuild the item universe once.
    -- Periodic vanilla dirty refreshes still use the cached fast path.
    self:rebuildBCWCraftItemList(forceItemListRebuild == true)
    self:applyBCWCraftItemRecipeFilter()

    self.logic:autoPopulateInputs()
    self.logic:checkValidRecipeSelected()
    self:onRecipeChanged(self.logic:getRecipe())

    -- Rebuild the dynamic detail widgets against the fresh cached state.
    self:xuiRecalculateLayout()
end

function ISBCWHandCraftPanel:refreshBCWWindow()
    -- The refresh button belongs to this panel, but the requested operation
    -- is window-wide: workstation discovery/tabs first, then the currently
    -- active crafting panel and its filters/details.
    local window = self.parent
    if window and window.refreshBCWWindow then
        window:refreshBCWWindow()
        return
    end

    -- Safe fallback if this panel is ever hosted outside ISBetterCraftWindow.
    self:refreshBCWCraftingData(true)
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
    o.bcwCraftItemFilterType = "Both"
    o.bcwCraftItems = {}

    -- Cached signature for the expensive item-universe reconstruction.
    o.bcwCraftItemListBuilt = false
    o.bcwCraftItemListSeeAll = nil
    o.bcwCraftItemListCraftBench = nil
    o.bcwCraftItemListRecipeQuery = nil
    o.bcwCraftItemListCategory = nil
    o.bcwShowUnknownRecipes = false

    return o
end
