BCWXpUtils = BCWXpUtils or {}

local ICON_BASE_PATH = "media/ui/BetterCraftWindow/skills/"

local function normalizePerkType(perk)
    if not perk then return nil end
    if perk.getType then return perk:getType() end
    return perk
end

function BCWXpUtils.getPerkDisplayName(perk)
    if not perk then return "Unknown" end
    local perkType = normalizePerkType(perk)
    local name = perkType and PerkFactory.getPerkName(perkType) or nil
    if name and name ~= "" then return name end
    if perk.getName then
        local fallback = perk:getName()
        if fallback and fallback ~= "" then return tostring(fallback) end
    end
    return tostring(perk)
end

function BCWXpUtils.getActualXPMultiplier(player, perk)
    if not player or not perk then return 1.0 end
    local xp = player:getXp()
    if not xp then return 1.0 end

    local perkType = normalizePerkType(perk)
    if not perkType then return 1.0 end

    local multiplier = 1.0
    local perkBoost = xp:getPerkBoost(perkType)

    if perkBoost <= 0 then
        multiplier = multiplier * 0.25
    elseif perkBoost == 1 then
        multiplier = multiplier * 0.75
    elseif perkBoost == 2 then
        multiplier = multiplier * 1.0
    elseif perkBoost >= 3 then
        multiplier = multiplier * 1.25
    end

    local currentMultiplier = xp:getMultiplier(perkType)
    if currentMultiplier and currentMultiplier > 0 then
        multiplier = multiplier * currentMultiplier
    end

    return multiplier
end

function BCWXpUtils.formatXP(value)
    if not value then return "0" end
    if math.abs(value - math.floor(value)) < 0.0001 then
        return tostring(math.floor(value))
    end
    local text = string.format("%.2f", value)
    return text:gsub("0+$", ""):gsub("%.$", "")
end

function BCWXpUtils.getAwards(player, recipe)
    local result = {}
    if not recipe then return result end

    local count = recipe:getXPAwardCount()
    if not count or count <= 0 then return result end

    for i = 0, count - 1 do
        local award = recipe:getXPAward(i)
        if award then
            local perk = award:getPerk()
            local baseAmount = award:getAmount()
            if perk and baseAmount and baseAmount > 0 then
                table.insert(result, {
                    perk = perk,
                    name = BCWXpUtils.getPerkDisplayName(perk),
                    amount = baseAmount * BCWXpUtils.getActualXPMultiplier(player, perk),
                    baseAmount = baseAmount,
                })
            end
        end
    end

    return result
end

function BCWXpUtils.getPerkIconKey(perk)
    local perkType = normalizePerkType(perk)
    if not perkType then return "Generic" end

    local key = tostring(perkType):gsub("[^%w_]", "")
    local aliases = {
        Forge = "Blacksmith",
        Smithing = "Blacksmith",
        Metalwork = "MetalWelding",
        Sewing = "Tailoring",
        FirstAid = "Doctor",
        Carpentry = "Woodwork",
        Scavenging = "PlantScavenging",
    }
    return aliases[key] or key
end

function BCWXpUtils.getPerkIconTexture(perk)
    local key = BCWXpUtils.getPerkIconKey(perk)
    return getTexture(ICON_BASE_PATH .. key .. ".png")
        or getTexture(ICON_BASE_PATH .. "Generic.png")
end
