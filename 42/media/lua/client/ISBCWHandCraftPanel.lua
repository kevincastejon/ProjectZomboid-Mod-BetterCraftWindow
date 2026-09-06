require "Entity/ISEntityUI"
require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"
require "ISBCWCraftRecipePanel"
require "ISBCWCraftItemFilterPanel"
require "ISBCWRecipeCategories"
require "ISBCWWidgetRecipesPanel"

ISBCWHandCraftPanel = ISHandCraftPanel:derive("ISBCWHandCraftPanel")

local ITEM_FILTER_WIDTH = 185 * (getTextManager():getFontHeight(UIFont.Small) / 19)

-- Temporary BCW diagnostics.
-- The ALL tab has no CraftBench, so it inherits ISHandCraftPanel:update(),
-- which may call ISEntityUI.FindCraftSurface(). Time both the vanilla helper
-- itself and the complete inherited update so we can correlate UI hitches.
local function bcwDiagNowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    return 0
end

if not _G.BCW_DIAG_FINDCRAFT_INSTALLED then
    _G.BCW_DIAG_FINDCRAFT_INSTALLED = true
    _G.BCW_DIAG_FINDCRAFT_ORIGINAL = ISEntityUI.FindCraftSurface
    _G.BCW_DIAG_FINDCRAFT_CALLS = 0
    _G.BCW_DIAG_FINDCRAFT_TOTAL = 0
    _G.BCW_DIAG_FINDCRAFT_MAX = 0

    ISEntityUI.FindCraftSurface = function(player, radius)
        local t0 = bcwDiagNowMs()
        local result = _G.BCW_DIAG_FINDCRAFT_ORIGINAL(player, radius)
        local dt = bcwDiagNowMs() - t0

        _G.BCW_DIAG_FINDCRAFT_CALLS = _G.BCW_DIAG_FINDCRAFT_CALLS + 1
        _G.BCW_DIAG_FINDCRAFT_TOTAL = _G.BCW_DIAG_FINDCRAFT_TOTAL + dt
        if dt > _G.BCW_DIAG_FINDCRAFT_MAX then
            _G.BCW_DIAG_FINDCRAFT_MAX = dt
        end

        -- Log individual expensive calls, plus a periodic aggregate so that
        -- cheap-but-very-frequent calls are visible without flooding console.
        if dt >= 2 then
            local sq = player and player:getSquare()
            print(string.format(
                "[BCW ALL PERF] FindCraftSurface radius=%s took=%dms player=%d,%d,%d",
                tostring(radius),
                dt,
                sq and sq:getX() or -1,
                sq and sq:getY() or -1,
                sq and sq:getZ() or -1
            ))
        end

        if (_G.BCW_DIAG_FINDCRAFT_CALLS % 120) == 0 then
            print(string.format(
                "[BCW ALL PERF] FindCraftSurface summary calls=%d total=%dms avg=%.3fms max=%dms",
                _G.BCW_DIAG_FINDCRAFT_CALLS,
                _G.BCW_DIAG_FINDCRAFT_TOTAL,
                _G.BCW_DIAG_FINDCRAFT_TOTAL / _G.BCW_DIAG_FINDCRAFT_CALLS,
                _G.BCW_DIAG_FINDCRAFT_MAX
            ))
        end

        return result
    end
end

function ISBCWHandCraftPanel:update()
    local totalStart = bcwDiagNowMs()

    local t0 = bcwDiagNowMs()
    ISPanel.update(self)
    local panelMs = bcwDiagNowMs() - t0

    t0 = bcwDiagNowMs()
    local crafting = self.logic:isCraftActionInProgress()
    local craftCheckMs = bcwDiagNowMs() - t0

    if crafting then
        return
    end

    if self.updateTimer > 0 then
        self.updateTimer = self.updateTimer - 1
    end

    local findSurfaceMs = 0
    local setIsoMs = 0
    local surfaceContainersMs = 0
    local surfaceChanged = false

    if not self.craftBench then
        t0 = bcwDiagNowMs()
        local newIsoObject = ISEntityUI.FindCraftSurface(self.player, 2)
        findSurfaceMs = bcwDiagNowMs() - t0

        if self.isoObject ~= newIsoObject then
            surfaceChanged = true

            t0 = bcwDiagNowMs()
            self.isoObject = newIsoObject
            self.parent.isoObject = self.isoObject
            self.logic:setIsoObject(self.isoObject)
            self.updateTimer = 0
            setIsoMs = bcwDiagNowMs() - t0

            t0 = bcwDiagNowMs()
            self:updateContainers(true)
            surfaceContainersMs = bcwDiagNowMs() - t0
        end
    end

    local dirty = false
    local refreshMs = 0
    local autoPopulateMs = 0
    local recipeCount = -1

    if ISHandCraftPanel.drawDirty and self.updateTimer == 0 then
        dirty = true
        ISHandCraftPanel.drawDirty = false

        t0 = bcwDiagNowMs()
        self:refreshRecipeList()
        refreshMs = bcwDiagNowMs() - t0

        t0 = bcwDiagNowMs()
        self.logic:autoPopulateInputs()
        autoPopulateMs = bcwDiagNowMs() - t0

        if self.recipesPanel
            and self.recipesPanel.recipeListPanel
            and self.recipesPanel.recipeListPanel.recipeListPanel
            and self.recipesPanel.recipeListPanel.recipeListPanel.items then
            recipeCount = #self.recipesPanel.recipeListPanel.recipeListPanel.items
        end

        if recipeCount >= 0 and recipeCount < 100 then
            self.updateTimer = 1
        else
            self.updateTimer = 10
        end
    end

    local totalMs = bcwDiagNowMs() - totalStart

    if totalMs >= 4 or dirty or surfaceChanged then
        print(string.format(
            "[BCW UPDATE DETAIL] total=%dms panel=%d craftCheck=%d findSurface=%d surfaceChanged=%s setIso=%d surfaceContainers=%d dirty=%s refresh=%d autoPopulate=%d recipes=%d timer=%d craftBench=%s isoObject=%s",
            totalMs,
            panelMs,
            craftCheckMs,
            findSurfaceMs,
            tostring(surfaceChanged),
            setIsoMs,
            surfaceContainersMs,
            tostring(dirty),
            refreshMs,
            autoPopulateMs,
            recipeCount,
            tonumber(self.updateTimer) or -1,
            tostring(self.craftBench ~= nil),
            tostring(self.isoObject ~= nil)
        ))
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

-- The custom item filter must never alter the vanilla category list.
-- self.logic may temporarily contain only the recipes matching the selected
-- BCW item, so asking it for getCategoryList() would make categories disappear
-- and would also change the auto-width of the vanilla category column.
-- Build the category list from the unfiltered context instead, exactly as if
-- no BCW item were selected.
function ISBCWHandCraftPanel:getCategoryList()
    local totalStart = bcwDiagNowMs()

    local t0 = bcwDiagNowMs()
    local recipes = self:getBCWBaseRecipeList()
    local baseListMs = bcwDiagNowMs() - t0

    if not recipes then
        t0 = bcwDiagNowMs()
        local result = self.logic:getCategoryList()
        local logicCategoriesMs = bcwDiagNowMs() - t0
        local totalMs = bcwDiagNowMs() - totalStart

        if totalMs >= 2 then
            print(string.format(
                "[BCW CATEGORY DETAIL] total=%dms baseList=%d logicCategories=%d customLogic=false",
                totalMs,
                baseListMs,
                logicCategoriesMs
            ))
        end
        return result
    end

    t0 = bcwDiagNowMs()
    local categoryLogic = HandcraftLogic.new(
        self.player,
        self.craftBench,
        self.isoObject
    )
    local newLogicMs = bcwDiagNowMs() - t0

    t0 = bcwDiagNowMs()
    categoryLogic:setRecipes(recipes)
    local setRecipesMs = bcwDiagNowMs() - t0

    t0 = bcwDiagNowMs()
    local result = categoryLogic:getCategoryList()
    local getCategoriesMs = bcwDiagNowMs() - t0

    local totalMs = bcwDiagNowMs() - totalStart
    if totalMs >= 2 then
        print(string.format(
            "[BCW CATEGORY DETAIL] total=%dms baseList=%d newLogic=%d setRecipes=%d getCategories=%d customLogic=true",
            totalMs,
            baseListMs,
            newLogicMs,
            setRecipesMs,
            getCategoriesMs
        ))
    end

    return result
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
    local totalStart = bcwDiagNowMs()

    local t0 = bcwDiagNowMs()
    ISHandCraftPanel.refreshRecipeList(self, forceRefresh)
    local vanillaRefreshMs = bcwDiagNowMs() - t0

    t0 = bcwDiagNowMs()
    local itemListRebuilt = self:rebuildBCWCraftItemList()
    local rebuildItemsMs = bcwDiagNowMs() - t0

    local applyFilterMs = 0
    local appliedFilter = self.bcwSelectedCraftItemFullName ~= nil or self.bcwShowUnknownRecipes == true
    if appliedFilter then
        t0 = bcwDiagNowMs()
        self:applyBCWCraftItemRecipeFilter()
        applyFilterMs = bcwDiagNowMs() - t0
    end

    local totalMs = bcwDiagNowMs() - totalStart
    if totalMs >= 2 then
        print(string.format(
            "[BCW REFRESH DETAIL] total=%dms vanillaRefresh=%d rebuildItemList=%d rebuilt=%s applyFilter=%d appliedFilter=%s seeAll=%s craftBench=%s",
            totalMs,
            vanillaRefreshMs,
            rebuildItemsMs,
            tostring(itemListRebuilt == true),
            applyFilterMs,
            tostring(appliedFilter),
            tostring(self.seeAllRecipe == true),
            tostring(self.craftBench ~= nil)
        ))
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

function ISBCWHandCraftPanel:refreshBCWCraftingData()
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
        self.logic:setRecipes(ScriptManager.instance:getAllCraftRecipes())
    end

    self:rebuildBCWCraftItemList()
    self:applyBCWCraftItemRecipeFilter()

    self.logic:autoPopulateInputs()
    self.logic:checkValidRecipeSelected()
    self:onRecipeChanged(self.logic:getRecipe())

    -- Rebuild the dynamic detail widgets against the fresh cached state.
    self:xuiRecalculateLayout()
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
