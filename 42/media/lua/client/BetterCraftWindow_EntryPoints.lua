require "Entity/ISEntityUI"
require "ISBetterCraftWindow"

local vanillaOpenHandcraftWindow = ISEntityUI.OpenHandcraftWindow
local vanillaOpenWindow = ISEntityUI.OpenWindow

-- Redirect the actual generic handcraft-window entry point instead of the
-- sidebar button callback.
--
-- This is intentionally compatible with Project Cook: its hover popup calls
-- ISEntityUI.OpenHandcraftWindow() for the left/crafting half of the popup,
-- so it naturally reaches BCW while Project Cook's right/cooking half remains
-- completely untouched.
function ISEntityUI.OpenHandcraftWindow(player, isoObject, recipeFilter, ...)
    if not player then
        return vanillaOpenHandcraftWindow(player, isoObject, recipeFilter, ...)
    end

    -- Vanilla's inventory context-menu action calls:
    -- OpenHandcraftWindow(player, nil, "*", false, nil, "!Base.ItemType")
    -- Preserve that special item-search request instead of treating it like
    -- the normal Crafting-button toggle.
    local extra = { ... }
    local itemString = extra[3]

    if itemString and itemString ~= "" then
        local window = ISBetterCraftWindow.open(player)
        if not window then
            return
        end

        -- The inventory recipe lookup is always a generic/ALL context.
        window:setContext(nil)

        if window.handCraftPanel and window.handCraftPanel.setBCWRecipeSearchForItem then
            window.handCraftPanel:setBCWRecipeSearchForItem(itemString)
        end

        window:bringToTop()
        return
    end

    -- Generic crafting keeps the existing toggle behavior. recipeFilter
    -- (including Project Cook's Alt-click "*") remains intentionally ignored
    -- because BCW owns its own filtering UI.
    ISBetterCraftWindow.toggle(player)
end

-- Redirect only entity windows backed by a real CraftBench component.
-- Everything else (generators, radios, appliances, Project Cook UI, etc.)
-- continues through the currently-installed vanilla/modded OpenWindow path.
function ISEntityUI.OpenWindow(player, entity, ...)
    if entity then
        local craftBench = entity:getComponent(ComponentType.CraftBench)

        if craftBench then
            if not ISEntityUI.CanOpenWindowFor(player, entity) then
                return
            end

            -- Do not call CanPlayerUseEntity here: BCW deliberately allows an
            -- occupied workstation to be selected so it can show its busy UI.
            ISBetterCraftWindow.openForWorkstation(player, entity)
            return
        end
    end

    return vanillaOpenWindow(player, entity, ...)
end
