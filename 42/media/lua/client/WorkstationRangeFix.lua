require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"

local function getCraftBench(obj)
    if not obj then
        return nil
    end

    return obj:getComponent(ComponentType.CraftBench)
end


local function canClaimWorkstation(obj, player)
    if not obj or not player then
        return false
    end

    local usingPlayer = obj:getUsingPlayer()

    return usingPlayer == nil or usingPlayer == player
end


local vanillaNew = ISHandCraftPanel.new

function ISHandCraftPanel:new(
    x,
    y,
    width,
    height,
    player,
    craftBench,
    isoObject,
    recipeQuery
)
    if not craftBench and isoObject then
        local detectedBench = getCraftBench(isoObject)

        if detectedBench then
            craftBench = detectedBench
        end
    end

    if craftBench and isoObject then
        if canClaimWorkstation(isoObject, player) then
            if not isoObject:isUsingPlayer(player) then
                isoObject:setUsingPlayer(player)
            end
        else
            -- Workstation already used by another player.
            -- Do not steal it.
            craftBench = nil
        end
    end

    local panel = vanillaNew(
        self,
        x,
        y,
        width,
        height,
        player,
        craftBench,
        isoObject,
        recipeQuery
    )

    if panel then
        panel.WRF_claimedObject =
            craftBench and isoObject or nil

        panel.WRF_claimedPlayer =
            craftBench and player or nil
    end

    return panel
end


local function releasePanelWorkstation(panel)
    if not panel then
        return
    end

    local obj = panel.WRF_claimedObject
    local player = panel.WRF_claimedPlayer

    if not obj or not player then
        return
    end

    if obj:isUsingPlayer(player) then
        obj:setUsingPlayer(nil)
    end

    panel.WRF_claimedObject = nil
    panel.WRF_claimedPlayer = nil
end


local vanillaOnCloseWindow =
    ISHandCraftPanel.OnCloseWindow

function ISHandCraftPanel:OnCloseWindow()
    releasePanelWorkstation(self)

    if vanillaOnCloseWindow then
        return vanillaOnCloseWindow(self)
    end
end