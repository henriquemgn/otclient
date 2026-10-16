-- =============================================================================
-- DBO client module - networking and lifecycle
-- Talks to the server scripts in data/scripts/dbo (extended opcode 120, JSON).
-- =============================================================================

OPCODE = 120

state = {
    active = 0,
    classes = {},
    spells = {},
    potions = {},
    coins = 0,
    spheres = 0,
    stats = {},
    config = {},
}

local handlers = {}

function on(msgType, fn)
    handlers[msgType] = handlers[msgType] or {}
    table.insert(handlers[msgType], fn)
end

function send(action, data)
    local protocol = g_game.getProtocolGame()
    if not protocol then
        return
    end
    data = data or {}
    data.a = action
    protocol:sendExtendedOpcode(OPCODE, json.encode(data))
end

local chunks = {}

local function onExtendedOpcode(protocol, opcode, buffer)
    -- multi-part message: "#<part>/<total>|<data>"
    if buffer:sub(1, 1) == '#' then
        local part, total, rest = buffer:match('^#(%d+)/(%d+)|(.*)$')
        part, total = tonumber(part), tonumber(total)
        if not part then
            return
        end
        if part == 1 then
            chunks = {}
        end
        chunks[part] = rest
        if part < total then
            return
        end
        buffer = table.concat(chunks)
        chunks = {}
    end
    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= 'table' then
        g_logger.warning('[game_dbo] invalid message: ' .. tostring(buffer):sub(1, 120))
        return
    end
    local list = handlers[data.t]
    if not list then
        return
    end
    for _, fn in ipairs(list) do
        local success, err = pcall(fn, data)
        if not success then
            g_logger.error('[game_dbo] handler "' .. tostring(data.t) .. '": ' .. tostring(err))
        end
    end
end

on('state', function(data)
    state.active = data.active
    state.classes = data.classes or {}
    state.spells = data.spells or {}
    state.potions = data.potions or {}
    state.coins = data.coins or 0
    state.spheres = data.spheres or 0
    state.sphereClientId = data.sphereClientId
    state.stats = data.stats or {}
    state.config = data.config or {}
    state.level = data.level
end)

function getClass(id)
    for _, c in ipairs(state.classes) do
        if c.id == id then
            return c
        end
    end
    return nil
end

function getActiveClass()
    return getClass(state.active)
end

local helloEvent

local function onGameStart()
    interfaceOnGameStart()
    windowsDestroy()
    windowsCreate()
    hudOnGameStart()
    guideOnGameStart()
    -- the server answers with the full state ("state", "tracker", "arrow"...)
    helloEvent = scheduleEvent(function()
        helloEvent = nil
        send('hello')
    end, 600)
end

local function onGameEnd()
    if helloEvent then
        removeEvent(helloEvent)
        helloEvent = nil
    end
    hudOnGameEnd()
    windowsOnGameEnd()
    guideOnGameEnd()
end

function init()
    g_ui.importStyle('styles')
    ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)
    connect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
    hudInit()
    windowsInit()
    guideInit()
    if g_game.isOnline() then
        onGameStart()
    end
end

function terminate()
    disconnect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
    hudTerminate()
    windowsTerminate()
    guideTerminate()
    accountTerminate()
end

-- helpers -----------------------------------------------------------------------
function formatNumber(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(math.abs(n))
    local out = s:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
    return (n < 0 and '-' or '') .. out
end

function formatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds >= 3600 then
        return string.format('%dh%02dm', seconds / 3600, (seconds % 3600) / 60)
    end
    return string.format('%d:%02d', seconds / 60, seconds % 60)
end

function setStars(panel, stars, max)
    max = max or 5
    for i = 1, max do
        local w = panel:getChildById('star' .. i)
        if w then
            w:setImageSource(i <= stars and '/images/dbo/star_small' or '/images/dbo/star_small_empty')
        end
    end
end
