require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"
require "Entity/ISEntityUI"

local WRF = {}
WRF.DEBUG = true


local function log(msg)
    if WRF.DEBUG then
        print("[WorkstationRangeFix] " .. tostring(msg))
    end
end


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


-- ============================================================
-- ISHandCraftPanel
--
-- Le menu Surface reçoit parfois :
--
-- craftBench = nil
-- isoObject  = véritable workstation
--
-- On restaure le CraftBench AVANT la création du HandcraftLogic.
-- ============================================================

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

    local detectedBench = nil

    if not craftBench and isoObject then
        detectedBench = getCraftBench(isoObject)

        if detectedBench then
            log("================================")
            log("CraftBench missing during ISHandCraftPanel:new")
            log("IsoObject = " .. tostring(isoObject))
            log("Detected CraftBench = " .. tostring(detectedBench))

            craftBench = detectedBench
        end
    end


    -- Une vraie workstation doit également être enregistrée
    -- comme utilisée par ce joueur.
    --
    -- ISHandcraftAction:isValid() l'exige.
    if craftBench and isoObject then

        if canClaimWorkstation(isoObject, player) then

            if not isoObject:isUsingPlayer(player) then
                log(
                    "Claiming workstation for player: "
                    .. tostring(player)
                )

                isoObject:setUsingPlayer(player)
            end

            log(
                "isUsingPlayer after claim = "
                .. tostring(isoObject:isUsingPlayer(player))
            )

        else

            log(
                "Workstation already used by another player: "
                .. tostring(isoObject:getUsingPlayer())
            )

            -- Ne surtout pas voler une workstation
            -- actuellement utilisée par un autre joueur.
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
        -- On mémorise uniquement les workstations que CE panel
        -- a réellement associées à son HandcraftLogic.
        panel.WRF_claimedObject =
            craftBench and isoObject or nil

        panel.WRF_claimedPlayer =
            craftBench and player or nil
    end


    if panel and panel.logic then
        log(
            "Panel created - logic CraftBench = "
            .. tostring(panel.logic:getCraftBench())
        )

        if isoObject then
            log(
                "Panel created - isUsingPlayer = "
                .. tostring(isoObject:isUsingPlayer(player))
            )
        end
    end


    return panel
end


-- ============================================================
-- Libération de la workstation
-- ============================================================

local function releasePanelWorkstation(panel)

    if not panel then
        return
    end

    local obj = panel.WRF_claimedObject
    local player = panel.WRF_claimedPlayer

    if not obj or not player then
        return
    end

    -- Ne libérer que si elle est toujours réservée
    -- par ce même joueur.
    if obj:isUsingPlayer(player) then

        log(
            "Releasing workstation: "
            .. tostring(obj)
        )

        obj:setUsingPlayer(nil)
    end

    panel.WRF_claimedObject = nil
    panel.WRF_claimedPlayer = nil
end


-- Plusieurs fenêtres B42 appellent OnCloseWindow() sur leurs panels.
-- ISHandCraftPanel peut ne pas l'implémenter selon le contexte,
-- donc on préserve l'éventuelle implémentation existante.

local vanillaOnCloseWindow =
    ISHandCraftPanel.OnCloseWindow

function ISHandCraftPanel:OnCloseWindow()

    releasePanelWorkstation(self)

    if vanillaOnCloseWindow then
        return vanillaOnCloseWindow(self)
    end
end


log("loaded")