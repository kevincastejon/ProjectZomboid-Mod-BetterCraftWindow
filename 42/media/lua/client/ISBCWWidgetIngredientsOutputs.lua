require "Entity/ISUI/CraftRecipe/ISWidgetIngredientsOutputs"
require "ISBCWWidgetOutput"
require "ISBCWWidgetInput"

ISBCWWidgetIngredientsOutputs = ISWidgetIngredientsOutputs:derive("ISBCWWidgetIngredientsOutputs")

function ISBCWWidgetIngredientsOutputs:addOutput(outputScript)
    local output = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISBCWWidgetOutput,
        0, 0, 10, 10,
        self.player,
        self.logic,
        outputScript
    )

    output.interactiveMode = self.interactiveMode
    output.isBuildMenu = self.isBuildMenu
    output.bcwHandCraftPanel = self.bcwHandCraftPanel
    output:initialise()
    output:instantiate()

    self:addChild(output)
    table.insert(self.outputs, output)
end

function ISBCWWidgetIngredientsOutputs:addInput(inputScript)
    if inputScript:isKeep() then
        return
    end

    if inputScript:getCreateToItemScript() then
        local output = ISXuiSkin.build(
            self.xuiSkin,
            "S_NeedsAStyle",
            ISBCWWidgetInput,
            0, 0, 10, 10,
            self.player,
            self.logic,
            inputScript
        )

        output.interactiveMode = self.interactiveMode
        output.isBuildMenu = self.isBuildMenu
        output.displayAsOutput = true
        output.bcwHandCraftPanel = self.bcwHandCraftPanel
        output:initialise()
        output:instantiate()

        self:addChild(output)
        table.insert(self.outputs, output)

        local iconLink = ISXuiSkin.build(
            self.xuiSkin,
            "S_NeedsAStyle",
            ISImage,
            0, 0, 19, 12,
            self.textureLink
        )
        iconLink.autoScale = true
        iconLink:initialise()
        iconLink:instantiate()
        self:addChild(iconLink)
        output.iconLink = iconLink
    end
end

function ISBCWWidgetIngredientsOutputs:addKeeps(inputScript)
    if not inputScript:isKeep() then
        return
    end

    local output = ISXuiSkin.build(
        self.xuiSkin,
        "S_NeedsAStyle",
        ISBCWWidgetInput,
        0, 0, 10, 10,
        self.player,
        self.logic,
        inputScript
    )

    output.interactiveMode = self.interactiveMode
    output.isBuildMenu = self.isBuildMenu
    output.displayAsOutput = true
    output.bcwHandCraftPanel = self.bcwHandCraftPanel
    output:initialise()
    output:instantiate()

    self:addChild(output)
    table.insert(self.outputs, output)

    if inputScript:getCreateToItemScript() then
        local iconLink = ISXuiSkin.build(
            self.xuiSkin,
            "S_NeedsAStyle",
            ISImage,
            0, 0, 19, 12,
            self.textureLink
        )
        iconLink.autoScale = true
        iconLink:initialise()
        iconLink:instantiate()
        self:addChild(iconLink)
        output.iconLink = iconLink
    end
end

function ISBCWWidgetIngredientsOutputs:new(x, y, width, height, player, logic)
    return ISWidgetIngredientsOutputs.new(self, x, y, width, height, player, logic)
end
