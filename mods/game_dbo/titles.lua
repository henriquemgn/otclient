-- =============================================================================
-- DBO - class name + stars above player names (attached widget per creature)
-- =============================================================================

local titles = {} -- creatureId -> { c = className, s = stars }
local pending = {}
local requestEvent

local TITLE_ID = 'dboTitle'

local function applyTitle(creature)
    if not creature or not creature:isPlayer() then
        return
    end
    local t = titles[creature:getId()]
    local widget = creature:getAttachedWidgetById(TITLE_ID)
    if not t then
        if widget then
            creature:detachWidgetById(TITLE_ID)
        end
        return
    end
    if not widget then
        widget = g_ui.createWidget('DboCreatureTitle')
        widget:setId(TITLE_ID)
        creature:attachWidget(widget)
    end
    widget:getChildById('cls'):setText(t.c)
    setStars(widget:getChildById('stars'), t.s or 1)
end

local function flushRequests()
    requestEvent = nil
    local ids = {}
    for id in pairs(pending) do
        ids[#ids + 1] = id
    end
    pending = {}
    if #ids > 0 then
        send('who', { ids = ids })
    end
end

local function request(creature)
    pending[creature:getId()] = true
    if not requestEvent then
        requestEvent = scheduleEvent(flushRequests, 300)
    end
end

local function onCreatureAppear(creature)
    if not creature:isPlayer() then
        return
    end
    if titles[creature:getId()] then
        applyTitle(creature)
    end
    -- always refresh: the class/stars may have changed while out of sight
    request(creature)
end

local function onCreatureDisappear(creature)
    if creature:isPlayer() and creature:getAttachedWidgetById(TITLE_ID) then
        creature:detachWidgetById(TITLE_ID)
    end
end

on('titles', function(data)
    for _, t in ipairs(data.list or {}) do
        titles[t.id] = { c = t.c, s = t.s }
        local creature = g_map.getCreatureById(t.id)
        if creature and creature:getPosition() and creature:getPosition().x ~= 65535 then
            applyTitle(creature)
        end
    end
end)

function titlesOnGameStart()
    titles = {}
    pending = {}
    -- players already on screen
    scheduleEvent(function()
        for _, creature in ipairs(g_map.getSpectators(g_game.getLocalPlayer():getPosition(), true)) do
            if creature:isPlayer() then
                request(creature)
            end
        end
    end, 800)
end

function titlesOnGameEnd()
    if requestEvent then
        removeEvent(requestEvent)
        requestEvent = nil
    end
    titles = {}
    pending = {}
end

function titlesInit()
    connect(Creature, { onAppear = onCreatureAppear, onDisappear = onCreatureDisappear })
end

function titlesTerminate()
    disconnect(Creature, { onAppear = onCreatureAppear, onDisappear = onCreatureDisappear })
    titlesOnGameEnd()
end
