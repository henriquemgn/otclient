-- =============================================================================
-- DBO - Loot Stash window (server: data/scripts/dbo/lootstash.lua)
-- =============================================================================

local lootWindow
local data = { loot = {}, depot = {}, nearDepot = false }
local tab = 'loot'

local function shortCount(n)
    if n >= 1000000 then
        return string.format('%dkk', math.floor(n / 1000000))
    elseif n >= 10000 then
        return string.format('%dk', math.floor(n / 1000))
    end
    return tostring(n)
end

local function openMenu(entry)
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    if tab == 'loot' then
        menu:addOption('Pegar tudo', function() send('ls_take', { id = entry.id }) end)
        if entry.count > 1 then
            menu:addOption('Pegar quantidade...', function()
                askAmount(string.format('Pegar quantos %s? (max %d)', entry.name, entry.count), entry.count, function(n)
                    send('ls_take', { id = entry.id, count = n })
                end)
            end)
        end
        menu:addSeparator()
        menu:addOption(string.format('Jogar fora %d %s', entry.count, entry.name), function() send('ls_discard', { id = entry.id }) end)
    else
        menu:addOption('Retirar tudo', function() send('ds_withdraw', { id = entry.id, count = entry.count }) end)
        if entry.count > 1 then
            menu:addOption('Retirar quantidade...', function()
                askAmount(string.format('Retirar quantos %s? (max %d)', entry.name, entry.count), entry.count, function(n)
                    send('ds_withdraw', { id = entry.id, count = n })
                end)
            end)
        end
    end
    menu:display(g_window.getMousePosition())
end

local function refresh()
    if not lootWindow then
        return
    end
    local list = tab == 'loot' and data.loot or data.depot
    lootWindow:getChildById('tabLoot'):setOn(tab == 'loot')
    lootWindow:getChildById('tabDepot'):setOn(tab == 'depot')
    local grid = lootWindow:getChildById('grid')
    grid:destroyChildren()
    for _, entry in ipairs(list or {}) do
        local cell = g_ui.createWidget('DboLootCell', grid)
        cell:setItemId(entry.cid)
        cell:setItemCount(1)
        cell:getChildById('amount'):setText(shortCount(entry.count))
        cell:setTooltip(string.format('%d %s\n%s', entry.count, entry.name,
            tab == 'loot' and 'Clique: pegar para a bag\nBotao direito: jogar fora' or 'Clique: retirar (ao lado de um depot)'))
        cell.onMouseRelease = function(widget, pos, button)
            if button == MouseRightButton then
                openMenu(entry)
                return true
            end
            if button == MouseLeftButton and tab == 'loot' then
                send('ls_take', { id = entry.id })
                return true
            end
            if button == MouseLeftButton and tab == 'depot' then
                send('ds_withdraw', { id = entry.id, count = entry.count })
                return true
            end
        end
    end
    local hint = lootWindow:getChildById('hint')
    if tab == 'loot' then
        hint:setText(#(data.loot or {}) == 0 and 'Mate monstros: o loot vem para ca.' or 'Clique: pegar. Botao direito: jogar fora.')
    else
        hint:setText(data.nearDepot and 'Clique num item para retirar.' or 'Va ate um depot para retirar.')
    end
end

local function setTab(name)
    tab = name
    refresh()
    if name == 'depot' then
        send('lootstash')
    end
end

function toggleLootStash()
    if not lootWindow then
        return
    end
    if lootWindow:isVisible() then
        lootWindow:hide()
    else
        lootWindow:show()
        lootWindow:raise()
        lootWindow:focus()
        send('lootstash')
    end
end

function lootStashOnGameStart()
    if lootWindow then
        lootWindow:destroy()
    end
    lootWindow = g_ui.createWidget('DboLootWindow', modules.game_interface.getRootPanel())
    lootWindow:getChildById('windowTitle'):setText('Loot Stash')
    lootWindow:hide()
    lootWindow:setPosition({ x = 20, y = 140 })
    lootWindow:getChildById('stash').onClick = function() send('ls_stash') end
    lootWindow:getChildById('collect').onClick = function() send('ls_collect') end
    lootWindow:getChildById('tabLoot').onClick = function() setTab('loot') end
    lootWindow:getChildById('tabDepot').onClick = function() setTab('depot') end
    tab = 'loot'
    data = { loot = {}, depot = {}, nearDepot = false }
end

function lootStashOnGameEnd()
    if lootWindow then
        lootWindow:destroy()
        lootWindow = nil
    end
end

-- opening a depot locker also shows the Depot Stash tab
local function onContainerOpen(container)
    if not lootWindow or not container:getName() or container:getName():lower() ~= 'locker' then
        return
    end
    lootWindow:show()
    lootWindow:raise()
    tab = 'depot'
    refresh()
    send('lootstash')
end

function lootStashInit()
    g_ui.importStyle('lootstash')
    connect(Container, { onOpen = onContainerOpen })
    on('lootstash', function(d)
        data = d
        refresh()
        if hudSetLootBadge then
            hudSetLootBadge(#(d.loot or {}))
        end
    end)
    -- new loot: refresh the open window (cheap) or just the badge
    local pending
    on('lootstash_add', function()
        if pending then
            return
        end
        pending = scheduleEvent(function()
            pending = nil
            send('lootstash')
        end, 700)
    end)
end

function lootStashTerminate()
    disconnect(Container, { onOpen = onContainerOpen })
    lootStashOnGameEnd()
end
