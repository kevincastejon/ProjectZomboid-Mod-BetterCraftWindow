require "ISUI/ISPanel"

ISWidgetRecipeXP = ISPanel:derive("ISWidgetRecipeXP")


function ISWidgetRecipeXP:initialise()
    ISPanel.initialise(self)
end


function ISWidgetRecipeXP:createChildren()
    ISPanel.createChildren(self)
end


local function getPerkDisplayName(perk)
    if not perk then
        return "Unknown"
    end

    local name = PerkFactory.getPerkName(perk)

    if name and name ~= "" then
        return name
    end

    if perk.getName then
        local fallback = perk:getName()

        if fallback and fallback ~= "" then
            return tostring(fallback)
        end
    end

    return tostring(perk)
end


local function getActualXPMultiplier(player, perk)
    if not player or not perk then
        return 1.0
    end

    local xp = player:getXp()

    if not xp then
        return 1.0
    end

    local multiplier = 1.0

    --
    -- Starting skill / profession boost.
    --
    local perkBoost = xp:getPerkBoost(perk)

    if perkBoost <= 0 then
        multiplier = multiplier * 0.25
    elseif perkBoost == 1 then
        multiplier = multiplier * 0.75
    elseif perkBoost == 2 then
        multiplier = multiplier * 1.0
    elseif perkBoost >= 3 then
        multiplier = multiplier * 1.25
    end

    --
    -- Current XP multiplier handled by vanilla.
    -- This may include temporary/book multipliers.
    --
    local currentMultiplier = xp:getMultiplier(perk)

    if currentMultiplier and currentMultiplier > 0 then
        multiplier = multiplier * currentMultiplier
    end

    return multiplier
end


local function formatXP(value)
    if not value then
        return "0"
    end

    if math.abs(value - math.floor(value)) < 0.0001 then
        return tostring(math.floor(value))
    end

    local text = string.format("%.2f", value)

    text = text:gsub("0+$", "")
    text = text:gsub("%.$", "")

    return text
end


function ISWidgetRecipeXP:getAwards()
    local awards = {}

    local recipe = self.logic and self.logic:getRecipe()

    if not recipe then
        return awards
    end

    local count = recipe:getXPAwardCount()

    if not count or count <= 0 then
        return awards
    end

    for i = 0, count - 1 do
        local award = recipe:getXPAward(i)

        if award then
            local perk = award:getPerk()
            local baseAmount = award:getAmount()

            if perk and baseAmount and baseAmount > 0 then
                local multiplier =
                    getActualXPMultiplier(self.player, perk)

                local amount =
                    baseAmount * multiplier

                table.insert(awards, {
                    perk = perk,
                    name = getPerkDisplayName(perk),
                    baseAmount = baseAmount,
                    multiplier = multiplier,
                    amount = amount
                })
            end
        end
    end

    return awards
end


function ISWidgetRecipeXP:calculateLayout(
    _preferredWidth,
    _preferredHeight
)
    local width =
        math.max(
            self.minimumWidth,
            _preferredWidth or 0
        )

    local awards = self:getAwards()

    local titleHeight =
        getTextManager():getFontHeight(UIFont.Small)

    local lineHeight =
        getTextManager():getFontHeight(UIFont.Small)

    local height = self.margin * 2

    height = height + titleHeight

    if #awards > 0 then
        height = height + self.margin
        height = height + (#awards * lineHeight)
    end

    height =
        math.max(
            height,
            self.minimumHeight
        )

    self:setWidth(width)
    self:setHeight(height)
end


function ISWidgetRecipeXP:prerender()
    ISPanel.prerender(self)

    local awards = self:getAwards()

    local x = self.margin
    local y = self.margin

    self:drawText(
        "CRAFTING EXPERIENCE",
        x,
        y,
        1.0,
        1.0,
        1.0,
        1.0,
        UIFont.Small
    )

    y =
        y
        + getTextManager():getFontHeight(UIFont.Small)
        + self.margin

    for _, award in ipairs(awards) do
        local amountText =
            "+"
            .. formatXP(award.amount)
            .. " XP"

        self:drawText(
            award.name,
            x,
            y,
            0.85,
            0.85,
            0.85,
            1.0,
            UIFont.Small
        )

        local amountWidth =
            getTextManager():MeasureStringX(
                UIFont.Small,
                amountText
            )

        self:drawText(
            amountText,
            self.width
                - self.margin
                - amountWidth,
            y,
            0.35,
            1.0,
            0.35,
            1.0,
            UIFont.Small
        )

        y =
            y
            + getTextManager():getFontHeight(
                UIFont.Small
            )
    end
end


function ISWidgetRecipeXP:render()
    ISPanel.render(self)
end


function ISWidgetRecipeXP:update()
    ISPanel.update(self)
end


function ISWidgetRecipeXP:new(
    x,
    y,
    width,
    height,
    player,
    logic
)
    local o =
        ISPanel.new(
            self,
            x,
            y,
            width,
            height
        )

    o.background = false

    o.player = player
    o.logic = logic

    o.margin = 6

    o.minimumWidth = 0
    o.minimumHeight = 0

    o.autoFillContents = false

    o.isAutoFill = false
    o.isAutoFillX = true
    o.isAutoFillY = false

    return o
end