require "ISUI/ISEquippedItem"
require "Entity/ISEntityUI"
require "ISBetterCraftWindow"

local vanillaOnOptionMouseDown = ISEquippedItem.onOptionMouseDown
local vanillaOpenWindow = ISEntityUI.OpenWindow

-- Redirect only the vanilla Crafting button.
function ISEquippedItem:onOptionMouseDown(button, x, y)
    if button and button.internal == "CRAFTING" then
        ISBetterCraftWindow.toggle(self.chr)
        return
    end

    return vanillaOnOptionMouseDown(self, button, x, y)
end

-- Redirect only entity windows backed by a real CraftBench component.
-- Everything else (generators, radios, appliances, etc.) remains vanilla.
function ISEntityUI.OpenWindow(player, entity)
    if entity then
        local craftBench = entity:getComponent(ComponentType.CraftBench)

        if craftBench then
            if not ISEntityUI.CanOpenWindowFor(player, entity) then
                return
            end

            -- Deliberately do NOT call CanPlayerUseEntity here. BCW allows an
            -- occupied workstation tab to open and display its busy message.
            ISBetterCraftWindow.openForWorkstation(player, entity)
            return
        end
    end

    return vanillaOpenWindow(player, entity)
end
