require "Entity/ISUI/CraftRecipe/ISWidgetIngredientsInputs"
require "ISBetterCraftWidgetInput"

ISBCWWidgetIngredientsInputs = ISWidgetIngredientsInputs:derive("ISBCWWidgetIngredientsInputs")

function ISBCWWidgetIngredientsInputs:addInput(inputScript)
    local input = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISBCWWidgetInput,
        0, 0, 10, 10,
        self.player,
        self.logic,
        inputScript
    )

    input.isBuildMenu = self.isBuildMenu
    input.interactiveMode = self.interactiveMode
    input.bcwHandCraftPanel = self.bcwHandCraftPanel
    input:initialise()
    input:instantiate()

    self.panel:addChild(input)
    table.insert(self.inputs, input)
end

function ISBCWWidgetIngredientsInputs:new(x, y, width, height, player, logic)
    return ISWidgetIngredientsInputs.new(self, x, y, width, height, player, logic)
end
