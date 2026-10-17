-- =============================================================================
-- DBO windows: first class pick, class panel (switch/stars), wishes (gacha),
-- forge, dungeons and linked tasks
-- =============================================================================

local pickWindow, classWindow, wishWindow, forgeWindow, dungeonWindow, taskWindow
local currentTaskRoom = 1
local taskData = { tasks = {}, rooms = {} }

local function root()
    return modules.game_interface.getRootPanel() or rootWidget
end

local function createWindow(style, title)
    local w = g_ui.createWidget(style, root())
    w:getChildById('windowTitle'):setText(title)
    w:hide()
    w.onEscape = function(self) self:hide() end
    return w
end

local function showWindow(w)
    w:show()
    w:raise()
    w:focus()
    if not w.placed then
        w.placed = true
        local parent = w:getParent()
        w:setPosition({ x = math.floor((parent:getWidth() - w:getWidth()) / 2), y = math.max(20, math.floor((parent:getHeight() - w:getHeight()) / 2) - 60) })
    end
end

local function toggle(w, onOpen)
    if w:isVisible() then
        w:hide()
    else
        showWindow(w)
        if onOpen then onOpen() end
    end
end

local function setProgress(bar, value, max, text)
    local fill = bar:getChildById('fill')
    local pct = max > 0 and math.min(1, value / max) or 1
    fill:setWidth(math.floor((bar:getWidth() - 2) * pct))
    bar:getChildById('text'):setText(text or string.format('%d/%d', value, max))
end

-- ---------------------------------------------------------------- first pick
local function showPick(classes)
    if not pickWindow then
        pickWindow = createWindow('DboPickWindow', 'Escolha seu Personagem')
        pickWindow:getChildById('closeButton'):hide()
        pickWindow.onEscape = function() end
    end
    local cards = pickWindow:getChildById('cards')
    cards:destroyChildren()
    for _, c in ipairs(classes) do
        if c.starter ~= false then
        local card = g_ui.createWidget('DboPickCard', cards)
        card:getChildById('outfit'):setOutfit({ type = c.forms[1].look })
        card:getChildById('name'):setText(c.name)
        card:getChildById('role'):setText(c.role)
        card:getChildById('description'):setText(c.description)
        card:getChildById('choose').onClick = function()
            send('pick', { id = c.id })
            pickWindow:hide()
        end
        end
    end
    showWindow(pickWindow)
end

-- ---------------------------------------------------------------- class panel
local selectedClass

local function portraitPath(c, kind)
    return '/images/dbo/portraits/' .. (c.key or 'goku') .. (kind or '')
end

local function showClassDetails(c)
    local left = classWindow:getChildById('left')
    selectedClass = c.id
    left:getChildById('portrait'):setImageSource(portraitPath(c))
    left:getChildById('portrait'):setOpacity(c.unlocked and 1 or 0.45)
    left:getChildById('outfit'):setOutfit({ type = c.look })
    left:getChildById('name'):setText(c.unlocked and string.format('%s  Nv %d', c.name, c.level or 1) or c.name)
    left:getChildById('role'):setText(c.role)
    local starBonus = state.config.starBonus and state.config.starBonus[c.stars > 0 and c.stars or 1] or 0
    local form = c.forms[c.form]
    local lines = { c.description or '' }
    if c.unlocked then
        lines[#lines + 1] = string.format('Forma: %s   |   Estrelas: +%d%% dano e vida', form and form.name or '-', math.floor(starBonus * 100 + 0.5))
        local nextForm = c.forms[(c.bestForm or 1) + 1]
        if nextForm then
            lines[#lines + 1] = string.format('Proxima transformacao: %s (nivel %d)', nextForm.name, nextForm.level)
        end
        if c.id == state.active and state.stats then
            lines[#lines + 1] = string.format('Dano %d%%  Vida %d%%  Dano recebido %d%%', state.stats.damage or 100, state.stats.health or 100, state.stats.taken or 100)
        end
    else
        lines[#lines + 1] = 'Bloqueado: consiga fragmentos nos Desejos.'
    end
    left:getChildById('stats'):setText(table.concat(lines, '\n'))

    local stars = left:getChildById('bigStars')
    stars:destroyChildren()
    for k = 1, 5 do
        local w = g_ui.createWidget('UIWidget', stars)
        w:setSize({ width = 24, height = 24 })
        w:setImageSource(k <= c.stars and '/images/dbo/star' or '/images/dbo/star_empty')
    end

    local frag, use, star = left:getChildById('fragments'), left:getChildById('use'), left:getChildById('star')
    if c.unlocked then
        if c.stars >= 5 then
            setProgress(frag, 1, 1, string.format('%d fragmentos - MAX', c.fragments))
            star:setEnabled(false)
            star:setText('MAX')
        else
            setProgress(frag, c.fragments, c.nextCost, string.format('%d/%d fragmentos', c.fragments, c.nextCost))
            star:setText('Evoluir')
            star:setEnabled(c.fragments >= c.nextCost)
        end
        use:setEnabled(c.id ~= state.active)
        use:setText(c.id == state.active and 'Em uso' or 'Usar')
    else
        setProgress(frag, c.fragments, c.nextCost, string.format('%d/%d para desbloquear', c.fragments, c.nextCost))
        use:setEnabled(false)
        use:setText('Bloqueado')
        star:setText('Liberar')
        star:setEnabled(c.fragments >= c.nextCost)
    end
    use.onClick = function() send('switch', { id = c.id }) end
    star.onClick = function() send('star', { id = c.id }) end

    for _, card in ipairs(classWindow:getChildById('grid'):getChildren()) do
        card:getChildById('selection'):setVisible(card.classId == c.id)
    end
end

local function refreshClassWindow()
    if not classWindow or not classWindow:isVisible() then
        return
    end
    local grid = classWindow:getChildById('grid')
    grid:destroyChildren()
    local selected
    -- unlocked first (highest level), then locked
    local list = {}
    for _, c in ipairs(state.classes) do
        list[#list + 1] = c
    end
    table.sort(list, function(a, b)
        if a.unlocked ~= b.unlocked then
            return a.unlocked
        end
        if (a.level or 1) ~= (b.level or 1) then
            return (a.level or 1) > (b.level or 1)
        end
        return a.id < b.id
    end)
    for _, c in ipairs(list) do
        local card = g_ui.createWidget('DboClassCard', grid)
        card.classId = c.id
        card:getChildById('portrait'):setImageSource(portraitPath(c, c.unlocked and '_thumb' or '_locked'))
        card:getChildById('name'):setText(c.name)
        local badge = card:getChildById('badge')
        badge:setVisible(c.unlocked)
        badge:getChildById('level'):setText(tostring(c.level or 1))
        setStars(card:getChildById('stars'), c.stars)
        card:getChildById('stars'):setVisible(c.unlocked)
        card:getChildById('active'):setVisible(c.id == state.active)
        card:setTooltip(c.unlocked and string.format('%s - nivel %d\nDuplo clique: usar', c.name, c.level or 1)
            or string.format('%s - %d/%d fragmentos', c.name, c.fragments, c.nextCost))
        card.onClick = function() showClassDetails(c) end
        card.onDoubleClick = function()
            if c.unlocked and c.id ~= state.active then
                send('switch', { id = c.id })
            end
        end
        if c.id == (selectedClass or state.active) then
            selected = c
        end
    end
    if selected or list[1] then
        showClassDetails(selected or list[1])
    end
end

function toggleClassPanel()
    -- fragments are items now (trade/pick up): ask for fresh counts
    toggle(classWindow, function() send('state') refreshClassWindow() end)
end

-- ---------------------------------------------------------------- wishes
local function refreshWish()
    if not wishWindow then
        return
    end
    local cfg = state.config
    wishWindow:getChildById('spheres'):setText(string.format('Esferas do Dragao: %d', state.spheres or 0))
    wishWindow:getChildById('coins'):setText(string.format('Coins: %s', formatNumber(state.coins)))
    local rare = cfg.rewards and cfg.rewards[2]
    wishWindow:getChildById('odds'):setText(string.format('Cada desejo: 20 fragmentos (%d%%) ou 100 fragmentos (%d%%)\nde um personagem aleatorio.',
        cfg.rewards and cfg.rewards[1].chance or 85, rare and rare.chance or 15))
    local price = cfg.spherePrice or 100
    local bundle = cfg.bundle or { amount = 10, price = 900 }
    local b1, b10 = wishWindow:getChildById('buy1'), wishWindow:getChildById('buy10')
    b1:setText(string.format('Comprar 1 (%d coins)', price))
    b10:setText(string.format('Comprar %d (%d coins)', bundle.amount, bundle.price))
    b1:setEnabled(state.coins >= price)
    b10:setEnabled(state.coins >= bundle.price)
    wishWindow:getChildById('wish1'):setEnabled((state.spheres or 0) >= 1)
    wishWindow:getChildById('wish10'):setEnabled((state.spheres or 0) >= 10)
end

local function showWishResults(results)
    local panel = wishWindow:getChildById('results')
    panel:destroyChildren()
    for i, r in ipairs(results) do
        local card = g_ui.createWidget('DboWishResult', panel)
        card:getChildById('outfit'):setOutfit({ type = r.look })
        card:getChildById('name'):setText(r.name)
        card:getChildById('amount'):setText('+' .. r.fragments .. ' fragmentos')
        if r.rare then
            card:setBorderColor('#ffd040')
            card:setBorderWidth(2)
            card:setBackgroundColor('#4a3008dd')
            card:getChildById('amount'):setColor('#ffd040')
        end
        -- reveal one by one
        card:setOpacity(0)
        scheduleEvent(function()
            if not card:isDestroyed() then
                card:setOpacity(1)
            end
        end, 150 * i)
    end
end

function toggleWish()
    toggle(wishWindow, refreshWish)
end

-- ---------------------------------------------------------------- forge
local function fillForge(data)
    if not forgeWindow then
        return
    end
    local b = data.bonus or {}
    forgeWindow:getChildById('info'):setText(string.format(
        'Aprimore armas e equipamentos ate o Tier %d. Arma: +%.0f%% dano por tier. Equipamento: +%.1f%% vida e -%.1f%% dano recebido por tier. Set completo (cabeca, armadura, calca e botas) Tier %d: +%.0f%% dano e +%.0f%% vida.%s',
        data.maxTier or 10, b.weapon or 0, b.health or 0, b.reduction or 0, data.maxTier or 10, b.setDamage or 0, b.setHealth or 0,
        data.fullSet and '  [SET COMPLETO ATIVO]' or ''))
    local list = forgeWindow:getChildById('list')
    list:destroyChildren()
    if #(data.items or {}) == 0 then
        local l = g_ui.createWidget('DboLabel', list)
        l:setText('Equipe armas ou equipamentos para forjar.')
    end
    for _, it in ipairs(data.items or {}) do
        local row = g_ui.createWidget('DboForgeRow', list)
        row:getChildById('item'):setItemId(it.clientId)
        row:getChildById('name'):setText(it.name)
        row:getChildById('slot'):setText('(' .. it.slotName .. ')')
        setProgress(row:getChildById('tier'), it.tier, data.maxTier, string.format('Tier %d/%d', it.tier, data.maxTier))
        local up = row:getChildById('upgrade')
        if it.maxed then
            row:getChildById('cost'):setText('Tier maximo!')
            up:setEnabled(false)
        else
            row:getChildById('cost'):setText(string.format('%d Ki Shards + %s zeni - %d%%', it.shards, formatNumber(it.gold), it.chance))
            up:setEnabled((data.shards or 0) >= it.shards and (data.gold or 0) >= it.gold)
        end
        up.onClick = function() send('forge_up', { slot = it.slot }) end
    end
    forgeWindow:getChildById('footer'):getChildById('shards'):setText(string.format('Ki Shards: %d', data.shards or 0))
    forgeWindow:getChildById('footer'):getChildById('gold'):setText(string.format('Zeni (mochila + banco): %s', formatNumber(data.gold or 0)))
end

function toggleForge()
    toggle(forgeWindow, function() send('forge') end)
end

-- ---------------------------------------------------------------- dungeons
local function fillDungeons(data)
    if not dungeonWindow then
        return
    end
    dungeonWindow:getChildById('info'):setText(string.format(
        'Ate %d jogadores (o lider da party inicia). Ondas + chefe em %d minutos. Apos o nivel 400 as dungeons sao a principal fonte de experiencia. Esfera do Dragao: somente no modo Hard nivel 400+.',
        data.maxPlayers or 4, math.floor((data.timeLimit or 900) / 60)))
    local list = dungeonWindow:getChildById('list')
    list:destroyChildren()
    local player = g_game.getLocalPlayer()
    local level = player and player:getLevel() or 1
    for _, d in ipairs(data.dungeons or {}) do
        local row = g_ui.createWidget('DboDungeonRow', list)
        row:getChildById('outfit'):setOutfit({ type = d.look })
        row:getChildById('name'):setText(d.name)
        row:getChildById('boss'):setText(string.format('%d ondas + chefe: %s', d.waves, d.boss))
        for i, key in ipairs({ 'normal', 'hard' }) do
            local m = d.modes[i]
            local info = string.format('%s (nv %d): %d%% exp do nivel, %s zeni, %d Ki Shards%s',
                m.name, m.level, m.exp, formatNumber(m.gold), m.shards, m.sphere and ', chance de ESFERA DO DRAGAO' or '')
            row:getChildById(key .. 'Info'):setText(info)
            local btn = row:getChildById(key)
            if m.cooldown > 0 then
                btn:setText(m.name .. ' ' .. formatTime(m.cooldown))
                btn:setEnabled(false)
            else
                btn:setText('Entrar ' .. m.name)
                btn:setEnabled(level >= m.level)
            end
            btn.onClick = function()
                send('dungeon_start', { id = d.id, mode = m.id })
                dungeonWindow:hide()
            end
        end
    end
end

function toggleDungeons()
    toggle(dungeonWindow, function() send('dungeons') end)
end

-- ---------------------------------------------------------------- tasks
local function fillTasks()
    if not taskWindow then
        return
    end
    local tabs = taskWindow:getChildById('tabs')
    tabs:destroyChildren()
    for i, name in ipairs(taskData.rooms or {}) do
        local tab = g_ui.createWidget('DboTabButton', tabs)
        tab:setText(name:gsub('Sala ', ''))
        tab:setTooltip(name)
        tab:setOn(i == currentTaskRoom)
        tab.onClick = function()
            currentTaskRoom = i
            fillTasks()
        end
    end
    local list = taskWindow:getChildById('list')
    list:destroyChildren()
    local player = g_game.getLocalPlayer()
    local level = player and player:getLevel() or 1
    for _, t in ipairs(taskData.tasks or {}) do
        if t.tier == currentTaskRoom then
            local row = g_ui.createWidget('DboTaskRow', list)
            row:getChildById('outfit'):setOutfit({ type = t.look })
            row:getChildById('name'):setText(t.monster)
            local status
            if t.active then
                status = string.format('Em andamento: %d/%d', t.progress, t.kills)
            elseif not t.unlocked then
                status = 'Bloqueada - complete a task anterior'
            else
                status = string.format('Derrote %d - nivel %d%s', t.kills, t.level, t.done > 0 and (' - concluida ' .. t.done .. 'x') or '')
            end
            row:getChildById('info'):setText(status)
            local r = t.rewards
            local rewardText = string.format('%s exp, %s zeni%s%s', formatNumber(r.exp), formatNumber(r.gold),
                r.shards > 0 and (', ' .. r.shards .. ' Ki Shards') or '', r.senzu > 0 and (', ' .. r.senzu .. ' Senzu') or '') .. (r.item and (', ' .. r.item) or '')
            local rewards = row:getChildById('rewards')
            rewards:setText((r.first and 'Primeira vez: ' or 'Repeticao: ') .. rewardText)
            rewards:setColor(r.first and '#8fe08f' or '#ff8a7a')
            local action = row:getChildById('action')
            if t.active then
                action:setText(t.progress >= t.kills and 'Entregar' or 'Ver')
                action:setEnabled(t.progress >= t.kills)
            else
                action:setText('Iniciar')
                action:setEnabled(t.unlocked and level >= t.level and (taskData.active or 0) == 0)
            end
            if not t.unlocked then
                row:setOpacity(0.55)
            end
            action.onClick = function() send('task_start', { id = t.id }) end
        end
    end
end

function toggleTasks()
    toggle(taskWindow, function() send('tasks') end)
end

-- ---------------------------------------------------------------- lifecycle
function windowsInit()
    g_ui.importStyle('windows')

    on('pick_class', function(data) showPick(data.classes) end)
    on('state', function()
        if pickWindow and state.active and state.active > 0 then
            pickWindow:hide()
        end
        refreshClassWindow()
        refreshWish()
    end)
    on('wish', function(data)
        if not wishWindow:isVisible() then
            showWindow(wishWindow)
        end
        showWishResults(data.results or {})
    end)
    on('forge', fillForge)
    on('dungeons', fillDungeons)
    on('tasks', function(data)
        taskData = data
        if data.active and data.active > 0 then
            for _, t in ipairs(data.tasks) do
                if t.id == data.active then
                    currentTaskRoom = t.tier
                end
            end
        end
        fillTasks()
    end)
    on('task_open', function(data)
        for _, t in ipairs(taskData.tasks or {}) do
            if t.id == data.id then
                currentTaskRoom = t.tier
            end
        end
        showWindow(taskWindow)
        fillTasks()
    end)
end

function windowsCreate()
    classWindow = createWindow('DboClassWindow', 'Personagens')
    wishWindow = createWindow('DboWishWindow', 'Desejos - Shenlong')
    forgeWindow = createWindow('DboForgeWindow', 'Forja')
    dungeonWindow = createWindow('DboDungeonWindow', 'Dungeons')
    taskWindow = createWindow('DboTaskWindow', 'Salao das Linked Tasks')
    wishWindow:getChildById('buy1').onClick = function() send('buy_sphere', { bundle = false }) end
    wishWindow:getChildById('buy10').onClick = function() send('buy_sphere', { bundle = true }) end
    wishWindow:getChildById('wish1').onClick = function() send('wish', { times = 1 }) end
    wishWindow:getChildById('wish10').onClick = function() send('wish', { times = 10 }) end
    taskWindow:getChildById('footer'):getChildById('clear').onClick = function() send('task_clear') end
end

function windowsDestroy()
    for _, w in ipairs({ pickWindow, classWindow, wishWindow, forgeWindow, dungeonWindow, taskWindow }) do
        if w then
            w:destroy()
        end
    end
    pickWindow, classWindow, wishWindow, forgeWindow, dungeonWindow, taskWindow = nil, nil, nil, nil, nil, nil
end

function windowsOnGameEnd()
    windowsDestroy()
end

function windowsTerminate()
    windowsDestroy()
end
