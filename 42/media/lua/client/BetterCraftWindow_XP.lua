require "Entity/ISUI/CraftRecipe/ISCraftRecipePanel"
require "ISWidgetRecipeXP"


local vanillaCreateDynamicChildren =
    ISCraftRecipePanel.createDynamicChildren


function ISCraftRecipePanel:createDynamicChildren()

    --
    -- On laisse d'abord vanilla construire toute la fenêtre.
    --
    vanillaCreateDynamicChildren(self)

    if not self.rootTable then
        return
    end

    local recipe = self.logic and self.logic:getRecipe()

    if not recipe then
        return
    end

    local xpCount = recipe:getXPAwardCount()

    --
    -- Pas d'XP déclarée = pas de section.
    --
    if not xpCount or xpCount <= 0 then
        return
    end

    --
    -- Crée notre widget.
    --
    self.bcwXPWidget = ISWidgetRecipeXP:new(
        0,
        0,
        10,
        10,
        self.player,
        self.logic
    )

    self.bcwXPWidget:initialise()
    self.bcwXPWidget:instantiate()

    --
    -- IMPORTANT :
    --
    -- vanilla a déjà construit son tableau dans cet ordre :
    --
    -- Title
    -- filler
    -- Inputs
    -- Outputs
    -- filler
    -- CraftControl
    --
    -- À ce stade addRow() ajouterait l'XP tout en bas,
    -- après le bouton de craft.
    --
    -- Donc cette première version est volontairement simple :
    -- elle ajoute la section XP au tableau et on valide d'abord
    -- son comportement / API sur ta 42.20.4.
    --
    local row = self.rootTable:addRow()

    self.rootTable:setElement(
        0,
        row:index(),
        self.bcwXPWidget
    )

    self:xuiRecalculateLayout()
end