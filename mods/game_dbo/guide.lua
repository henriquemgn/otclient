-- =============================================================================
-- DBO guide: arrow pointing to the current objective, task tracker, toasts,
-- tutorial messages and the dungeon run bar.
-- =============================================================================

local arrow, arrowLabel, tracker, tutorial, runBar
local arrowTarget = nil
local arrowEvent = nil
local toasts = {}
local runEndsAt = 0
local runTicker = nil

local function mapPanel()
    return modules.game_interface.getMapPanel()
end

local function updateArrow()
    if not arrow or not arrowTarget then
        return
    end
    local player = g_game.getLocalPlayer()
    local map = mapPanel()
    if not player or not map then
        return
    end
    local pos = player:getPosition()
    if not pos then
        return
    end
    local dx, dy = arrowTarget.x - pos.x, arrowTarget.y - pos.y
    local dist = math.max(math.abs(dx), math.abs(dy))
    local floorText = ''
    if arrowTarget.z < pos.z then
        floorText = ' (suba ' .. (pos.z - arrowTarget.z) .. ' andar)'
    elseif arrowTarget.z > pos.z then
        floorText = ' (desca ' .. (arrowTarget.z - pos.z) .. ' andar)'
    end
    if dist <= 1 and arrowTarget.z == pos.z then
        arrow:hide()
        arrowLabel:setText((arrowTarget.label or '') .. ' - chegou!')
    else
        arrow:show()
        local angle = math.deg(math.atan2(dy, dx)) + 90 -- arrow image points up
        arrow:setRotation(angle)
        arrowLabel:setText(string.format('%s - %d sqm%s', arrowTarget.label or 'Objetivo', dist, floorText))
    end
    -- place the arrow on a ring around the character (map centre)
    local rect = map:getRect()
    local cx, cy = rect.x + rect.width / 2, rect.y + rect.height / 2 - 16
    local len = math.sqrt(dx * dx + dy * dy)
    local ux, uy = 0, -1
    if len > 0 then
        ux, uy = dx / len, dy / len
    end
    local radius = math.min(rect.width, rect.height) * 0.22
    arrow:setPosition({ x = math.floor(cx + ux * radius - arrow:getWidth() / 2), y = math.floor(cy + uy * radius - arrow:getHeight() / 2) })
    arrowLabel:setPosition({ x = math.floor(cx + ux * radius - arrowLabel:getWidth() / 2), y = math.floor(cy + uy * radius + arrow:getHeight() / 2) })
end

local function setArrow(data)
    if data.clear then
        arrowTarget = nil
        if arrow then arrow:hide() end
        if arrowLabel then arrowLabel:hide() end
        if arrowEvent then
            removeEvent(arrowEvent)
            arrowEvent = nil
        end
        return
    end
    arrowTarget = { x = data.x, y = data.y, z = data.z, label = data.label }
    arrow:show()
    arrowLabel:show()
    if not arrowEvent then
        arrowEvent = cycleEvent(updateArrow, 100)
    end
    updateArrow()
end

function toast(text, kind)
    local parent = modules.game_interface.getRootPanel()
    local w = g_ui.createWidget('DboToast', parent)
    w:setText(text)
    if kind == 'error' then
        w:setColor('#ff9a8a')
        w:setBorderColor('#a83020')
    elseif kind == 'success' then
        w:setColor('#b8ff9a')
        w:setBorderColor('#40a020')
    end
    table.insert(toasts, 1, w)
    for i, t in ipairs(toasts) do
        t:setPosition({ x = math.floor((parent:getWidth() - t:getWidth()) / 2), y = 80 + (i - 1) * 30 })
    end
    scheduleEvent(function()
        for i, t in ipairs(toasts) do
            if t == w then
                table.remove(toasts, i)
            end
        end
        if not w:isDestroyed() then
            w:destroy()
        end
    end, 3500)
end

local function setTracker(data)
    if not tracker then
        return
    end
    if not data.active then
        tracker:hide()
        return
    end
    tracker:show()
    tracker:getChildById('outfit'):setOutfit({ type = data.look })
    tracker:getChildById('title'):setText(data.monster)
    local progress = tracker:getChildById('progress')
    progress:setText(data.complete and 'Completa! Entregue no Salao' or string.format('%d / %d', data.kills, data.total))
    progress:setColor(data.complete and '#8fe08f' or '#ffffff')
end

local function showTutorial(data)
    if not tutorial then
        return
    end
    tutorial:getChildById('text'):setText(data.text)
    tutorial:show()
    tutorial:raise()
end

local function tickRun()
    if not runBar or not runBar:isVisible() then
        return
    end
    local left = runEndsAt - os.time()
    runBar.timeText = formatTime(left)
    runBar:getChildById('info'):setText(string.format('%s  |  restam %s', runBar.status or '', formatTime(left)))
end

local function setRun(data)
    if not runBar then
        return
    end
    if not data.active then
        runBar:hide()
        if runTicker then
            removeEvent(runTicker)
            runTicker = nil
        end
        return
    end
    runBar:show()
    runBar:getChildById('title'):setText(string.format('%s (%s)', data.name, data.mode))
    local wave = data.wave or 0
    runBar.status = data.text or (wave > 0 and string.format('Onda %d/%d - %d inimigos', wave, data.waves, data.monsters) or '')
    if data.monsters and data.monsters > 0 then
        runBar.status = string.format('%s - %d inimigos', data.text or ('Onda ' .. wave), data.monsters)
    end
    runEndsAt = os.time() + (data.endsAt or 0)
    if not runTicker then
        runTicker = cycleEvent(tickRun, 1000)
    end
    tickRun()
end

-- lifecycle -------------------------------------------------------------------------
function guideInit()
    g_ui.importStyle('guide')
    on('arrow', function(data) if arrow then setArrow(data) end end)
    on('toast', function(data) toast(data.text, data.kind) end)
    on('tracker', setTracker)
    on('tutorial', showTutorial)
    on('dungeon_run', setRun)
    on('dungeon_reward', function(r)
        toast(string.format('Recompensa: %s exp, %s zeni, %d Ki Shards%s', formatNumber(r.exp), formatNumber(r.gold), r.shards,
            r.sphere and ' + ESFERA DO DRAGAO!' or ''), 'success')
    end)
    on('newform', function(data)
        toast('Nova transformacao liberada: ' .. data.name .. '! Clique no botao ao lado do retrato.', 'success')
    end)
    on('celebrate', function(data)
        local cls = getClass(data.class)
        if data.kind == 'unlock' then
            toast((cls and cls.name or 'Personagem') .. ' desbloqueado!', 'success')
        end
    end)
    on('buff', function(data)
        toast(data.name .. ' ativo por ' .. math.floor(data.ms / 1000) .. 's', 'info')
    end)
end

function guideOnGameStart()
    guideOnGameEnd()
    local parent = modules.game_interface.getRootPanel()
    arrow = g_ui.createWidget('DboArrow', parent)
    arrowLabel = g_ui.createWidget('DboArrowLabel', parent)
    arrow:hide()
    arrowLabel:hide()

    tracker = g_ui.createWidget('DboTracker', parent)
    tracker:addAnchor(AnchorTop, 'parent', AnchorTop)
    tracker:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    tracker:setMarginTop(8)
    tracker:setMarginLeft(260)
    tracker:getChildById('guide').onClick = function() send('guide') end
    tracker:hide()

    tutorial = g_ui.createWidget('DboTutorial', parent)
    tutorial:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    tutorial:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    tutorial:setMarginBottom(170)
    tutorial:getChildById('ok').onClick = function() tutorial:hide() end
    tutorial:hide()

    runBar = g_ui.createWidget('DboRunBar', parent)
    runBar:addAnchor(AnchorTop, 'parent', AnchorTop)
    runBar:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    runBar:setMarginTop(70)
    runBar:getChildById('leave').onClick = function() send('dungeon_leave') end
    runBar:hide()
end

function guideOnGameEnd()
    arrowTarget = nil
    if arrowEvent then
        removeEvent(arrowEvent)
        arrowEvent = nil
    end
    if runTicker then
        removeEvent(runTicker)
        runTicker = nil
    end
    for _, w in ipairs({ arrow, arrowLabel, tracker, tutorial, runBar }) do
        if w then
            w:destroy()
        end
    end
    for _, t in ipairs(toasts) do
        if not t:isDestroyed() then
            t:destroy()
        end
    end
    toasts = {}
    arrow, arrowLabel, tracker, tutorial, runBar = nil, nil, nil, nil, nil
end

function guideTerminate()
    guideOnGameEnd()
end
