require "Entity/ISUI/CraftRecipe/ISWidgetRecipeListPanel"
require "ISBCWRecipeScrollingListBox"

ISBCWWidgetRecipeListPanel = ISWidgetRecipeListPanel:derive("ISBCWWidgetRecipeListPanel")

function ISBCWWidgetRecipeListPanel:createChildren()
    ISPanel.createChildren(self)

    self.recipeListPanel = ISBCWRecipeScrollingListBox:new(0, 0, 10, 10, self.player, self.logic)
    self.recipeListPanel:initialise()
    self.recipeListPanel:instantiate()

    self.recipeListPanel.onItemMouseHover = function(_self, _item)
        self.callbackTarget:onRecipeItemMouseHover(_item)
    end

    self.recipeListPanel.onScrolled = function(_self)
        self.callbackTarget:onRecipeListPanelScrolled()
    end

    self.recipeListPanel:setOnMouseDownFunction(self, function(_self, _recipe)
        _self.logic:setRecipe(_recipe)
    end)
    self.recipeListPanel.drawDebugLines = self.drawDebugLines

    self:addChild(self.recipeListPanel)
end

function ISBCWWidgetRecipeListPanel:new(x, y, width, height, player, logic, callbackTarget)
    return ISWidgetRecipeListPanel.new(self, x, y, width, height, player, logic, callbackTarget)
end
