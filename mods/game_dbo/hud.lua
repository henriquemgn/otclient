-- =============================================================================
-- DBO HUD - orbs, skills (1-6), potions (7-8), class portrait, transform
-- =============================================================================

hud = nil
local slots = {}
local cooldowns = {}
local cooldownTicker = nil
local ORB_SIZE = 100
local KEYS = { '1', '2', '3', '4', '5', '6', '7', '8' }
local FKEYS = { 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8' }

local function spellIcon(name)
    return '/images/dbo/spells/' .. name:lower():gsub(' ', '_')
end

local function setOrb(orb, value, max, color)
    local pct = max > 0 and math.max(0, math.min(1, value / max)) or 0
    local h = math.floor(ORB_SIZE * pct + 0.5)
    local fill = orb:getChildById('fill')
    if h <= 0 then
        fill:setVisible(false)
    else
        fill:setVisible(true)
        fill:setHeight(h)
        fill:setImageClip({ x = 0, y = ORB_SIZE - h, width = ORB_SIZE, height = h })
    end
    orb:getChildById('value'):setText(formatNumber(value) .. '\n' .. formatNumber(max))
end

local function onHealthChange(localPlayer, health, maxHealth)
    if hud then
        setOrb(hud:getChildById('healthOrb'), health, maxHealth)
    end
end

local function onManaChange(localPlayer, mana, maxMana)
    if hud then
        setOrb(hud:getChildById('manaOrb'), mana, maxMana)
    end
end

local function onLevelChange(localPlayer, level, levelPercent)
    if not hud then
        return
    end
    hud:getChildById('level'):setText(level)
    local expBar = hud:getChildById('bar'):getChildById('expBar')
    local fill = expBar:getChildById('expFill')
    fill:setWidth(math.floor((expBar:getWidth() - 2) * (levelPercent or 0) / 100))
    expBar:setTooltip(string.format('Nivel %d - %d%%', level, levelPercent or 0))
    refreshSlots()
end

local function useSlot(index)
    if not g_game.isOnline() then
        return
    end
    local slot = slots[index]
    if not slot or not slot.data then
        return
    end
    if slot.kind == 'spell' then
        local player = g_game.getLocalPlayer()
        if player and player:getLevel() < slot.data.level then
            modules.game_textmessage.displayFailureMessage(string.format('Nivel %d necessario.', slot.data.level))
            return
        end
        g_game.talk(slot.data.words)
    else
        g_game.useInventoryItem(slot.data.clientId or slot.data.item)
    end
end

local function createSlot(index, x)
    local slotsPanel = hud:getChildById('bar'):getChildById('slots')
    local w = g_ui.createWidget('DboSlot', slotsPanel)
    w:addAnchor(AnchorTop, 'parent', AnchorTop)
    w:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    w:setMarginLeft(x)
    w:getChildById('key'):setText(KEYS[index])
    w.onClick = function() useSlot(index) end
    w.onHoverChange = function(widget, hovered)
        widget:getChildById('hover'):setVisible(hovered)
    end
    slots[index] = { widget = w, kind = index <= 6 and 'spell' or 'potion' }
end

function refreshSlots()
    if not hud then
        return
    end
    local player = g_game.getLocalPlayer()
    local level = player and player:getLevel() or 1
    for i = 1, 6 do
        local slot = slots[i]
        local data = state.spells[i]
        slot.data = data
        local w = slot.widget
        if data then
            w:getChildById('icon'):setImageSource(spellIcon(data.name))
            local locked = level < data.level
            w:getChildById('lock'):setVisible(locked)
            w:getChildById('lockText'):setText(locked and ('Nv ' .. data.level) or '')
            w:setTooltip(string.format('%s\nNivel %d - Ki %d - Recarga %.1fs', data.name, data.level, data.mana, data.cooldown / 1000))
        else
            w:getChildById('icon'):setImageSource('')
            w:getChildById('lock'):setVisible(false)
            w:getChildById('lockText'):setText('')
            w:setTooltip('')
        end
    end
    for i = 7, 8 do
        local slot = slots[i]
        local data
        for _, p in ipairs(state.potions) do
            if p.slot == i then
                data = p
            end
        end
        slot.data = data
        local w = slot.widget
        local item = w:getChildById('item')
        if data then
            item:setVisible(true)
            item:setItemId(data.clientId)
            w:getChildById('count'):setText(data.count or 0)
            w:setTooltip(data.name)
            w:getChildById('lock'):setVisible((data.count or 0) <= 0)
        else
            item:setVisible(false)
        end
    end
end

local function tickCooldowns()
    local now = g_clock.millis()
    local any = false
    for index, cd in pairs(cooldowns) do
        local slot = slots[index]
        local remaining = cd.ends - now
        local bar = slot.widget:getChildById('cooldown')
        local text = slot.widget:getChildById('cooldownText')
        if remaining <= 0 then
            bar:setVisible(false)
            text:setText('')
            cooldowns[index] = nil
        else
            any = true
            bar:setVisible(true)
            bar:setPercent(100 - math.floor(remaining * 100 / cd.total))
            text:setText(remaining >= 1000 and tostring(math.ceil(remaining / 1000)) or '')
        end
    end
    if not any and cooldownTicker then
        removeEvent(cooldownTicker)
        cooldownTicker = nil
    end
end

local function startCooldown(index, ms)
    if not slots[index] then
        return
    end
    cooldowns[index] = { ends = g_clock.millis() + ms, total = ms }
    if not cooldownTicker then
        cooldownTicker = cycleEvent(tickCooldowns, 100)
    end
    tickCooldowns()
end

function refreshHud()
    if not hud then
        return
    end
    local cls = getActiveClass()
    local portrait = hud:getChildById('portrait')
    if cls then
        portrait:setOutfit({ type = cls.look })
        portrait:setTooltip(string.format('%s (%s)\nClique para trocar de personagem', cls.name, cls.role))
        setStars(hud:getChildById('stars'), cls.stars)
        local tb = hud:getChildById('transformButton')
        local nextForm = cls.forms[cls.form + 1]
        local canTransform = cls.bestForm > cls.form
        tb:getChildById('badge'):setVisible(canTransform)
        tb:getChildById('badge'):setText('!')
        tb:setTooltip(canTransform and ('Transformar: ' .. cls.forms[cls.bestForm].name)
            or (nextForm and string.format('Proxima transformacao: %s (nivel %d)\nClique para voltar a forma base', nextForm.name, nextForm.level)
            or 'Forma maxima! Clique para voltar a forma base'))
    end
    local wish = hud:getChildById('menu'):getChildById('wishButton')
    wish:getChildById('badge'):setVisible((state.spheres or 0) > 0)
    wish:getChildById('badge'):setText(state.spheres or 0)
    refreshSlots()
end

function onTransformClick()
    local cls = getActiveClass()
    if not cls then
        return
    end
    if cls.bestForm > cls.form then
        send('transform', { index = cls.bestForm })
    else
        -- cycle back to base form / or to the best one
        send('transform', { index = cls.form > 1 and 1 or cls.bestForm })
    end
end

-- lifecycle -----------------------------------------------------------------------
function hudInit()
    on('state', function()
        refreshHud()
    end)
    on('cd', function(data)
        startCooldown(data.slot, data.ms)
    end)
    on('potions', function(data)
        for _, p in ipairs(data.potions or {}) do
            for _, sp in ipairs(state.potions) do
                if sp.slot == p.slot then
                    sp.count = p.count
                end
            end
        end
        refreshSlots()
    end)
    connect(LocalPlayer, {
        onHealthChange = onHealthChange,
        onManaChange = onManaChange,
        onLevelChange = onLevelChange,
    })
end

function hudTerminate()
    disconnect(LocalPlayer, {
        onHealthChange = onHealthChange,
        onManaChange = onManaChange,
        onLevelChange = onLevelChange,
    })
    hudOnGameEnd()
end

function hudOnGameStart()
    if hud then
        hud:destroy()
    end
    hud = g_ui.loadUI('hud', modules.game_interface.getRootPanel())
    hud:raise()
    local h, m = hud:getChildById('healthOrb'), hud:getChildById('manaOrb')
    h:getChildById('frame'):setImageSource('/images/dbo/orb_frame_hp')
    h:getChildById('fill'):setImageSource('/images/dbo/orb_hp')
    h:getChildById('label'):setText('HP')
    m:getChildById('frame'):setImageSource('/images/dbo/orb_frame_ki')
    m:getChildById('fill'):setImageSource('/images/dbo/orb_ki')
    m:getChildById('label'):setText('KI')
    local menu = hud:getChildById('menu')
    menu:getChildById('wishButton'):getChildById('icon'):setImageSource('/images/dbo/btn_wish')
    menu:getChildById('forgeButton'):getChildById('icon'):setImageSource('/images/dbo/btn_forge')
    menu:getChildById('dungeonButton'):getChildById('icon'):setImageSource('/images/dbo/btn_dungeon')
    menu:getChildById('tasksButton'):getChildById('icon'):setImageSource('/images/dbo/btn_tasks')
    hud:getChildById('transformButton'):getChildById('icon'):setImageSource('/images/dbo/btn_radar')

    slots = {}
    local x = 0
    for i = 1, 8 do
        createSlot(i, x)
        x = x + 48
        if i == 6 then
            x = x + 8
        end
    end

    local player = g_game.getLocalPlayer()
    if player then
        onHealthChange(player, player:getHealth(), player:getMaxHealth())
        onManaChange(player, player:getMana(), player:getMaxMana())
        onLevelChange(player, player:getLevel(), player:getLevelPercent())
    end

    local root = modules.game_interface.getRootPanel()
    for i = 1, 8 do
        g_keyboard.bindKeyDown(FKEYS[i], function() useSlot(i) end, root)
        g_keyboard.bindKeyDown(KEYS[i], function()
            -- number keys only when the chat is not being typed in
            if modules.game_console and modules.game_console.isChatEnabled and modules.game_console.isChatEnabled() then
                return
            end
            useSlot(i)
        end, root)
    end
end

function hudOnGameEnd()
    local root = modules.game_interface.getRootPanel()
    if root then
        for i = 1, 8 do
            g_keyboard.unbindKeyDown(FKEYS[i], nil, root)
            g_keyboard.unbindKeyDown(KEYS[i], nil, root)
        end
    end
    if cooldownTicker then
        removeEvent(cooldownTicker)
        cooldownTicker = nil
    end
    cooldowns = {}
    if hud then
        hud:destroy()
        hud = nil
    end
end
