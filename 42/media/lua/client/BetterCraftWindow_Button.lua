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

    -- Generic crafting always opens/toggles BCW on ALL.
    -- recipeFilter (including Project Cook's Alt-click "*") is intentionally
    -- not forwarded because BCW owns its own filtering UI.
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
