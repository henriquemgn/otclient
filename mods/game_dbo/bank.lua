-- =============================================================================
-- DBO - bank window (click the HUD balance) + amount dialog used by the stash
-- =============================================================================

local bankWindow
local amountWindow

local function parseAmount(text)
    text = tostring(text or ''):lower():gsub('[%s%.,]', '')
    local n, suffix = text:match('^(%d+)(k*)$')
    n = tonumber(n)
    if not n then
        return nil
    end
    return n * (1000 ^ #suffix) -- 10k = 10000, 2kk = 2000000
end

local function refreshBank(data)
    if not bankWindow then
        return
    end
    bankWindow:getChildById('balance'):setText(formatNumber(data.value or state.bank or 0) .. ' zeni')
    if data.money then
        bankWindow:getChildById('carried'):setText('Na mochila: ' .. formatNumber(data.money) .. ' zeni')
    end
end

function toggleBank()
    if not bankWindow then
        return
    end
    if bankWindow:isVisible() then
        bankWindow:hide()
        return
    end
    bankWindow:show()
    bankWindow:raise()
    bankWindow:focus()
    bankWindow:getChildById('amount'):focus()
    send('bank')
end

-- generic "how many?" dialog: askAmount('Retirar quantos?', 100, function(n) ... end)
function askAmount(label, default, callback)
    if amountWindow then
        amountWindow:destroy()
    end
    amountWindow = g_ui.createWidget('DboAmountWindow', modules.game_interface.getRootPanel())
    amountWindow:getChildById('windowTitle'):setText('Quantidade')
    amountWindow:getChildById('label'):setText(label)
    local field = amountWindow:getChildById('amount')
    field:setText(tostring(default or ''))
    field:focus()
    field:selectAll()
    local function confirm()
        local n = parseAmount(field:getText())
        amountWindow:destroy()
        amountWindow = nil
        if n and n > 0 then
            callback(n)
        end
    end
    amountWindow:getChildById('ok').onClick = confirm
    field.onEnter = confirm
    amountWindow.onEnter = confirm
    amountWindow:centerIn('parent')
    amountWindow:raise()
end

function bankOnGameStart()
    if bankWindow then
        bankWindow:destroy()
    end
    bankWindow = g_ui.createWidget('DboBankWindow', modules.game_interface.getRootPanel())
    bankWindow:getChildById('windowTitle'):setText('Banco')
    bankWindow:hide()
    bankWindow:centerIn('parent')
    local amount = bankWindow:getChildById('amount')
    bankWindow:getChildById('deposit').onClick = function()
        local n = parseAmount(amount:getText())
        if n then send('bank_deposit', { amount = n }) end
    end
    bankWindow:getChildById('depositAll').onClick = function() send('bank_deposit', { all = true }) end
    bankWindow:getChildById('withdraw').onClick = function()
        local n = parseAmount(amount:getText())
        if n then send('bank_withdraw', { amount = n }) end
    end
    bankWindow:getChildById('transfer').onClick = function()
        local n = parseAmount(amount:getText())
        local name = bankWindow:getChildById('target'):getText()
        if n and name ~= '' then send('bank_transfer', { amount = n, name = name }) end
    end
end

function bankOnGameEnd()
    for _, w in ipairs({ bankWindow, amountWindow }) do
        if w then
            w:destroy()
        end
    end
    bankWindow, amountWindow = nil, nil
end

function bankInit()
    g_ui.importStyle('bank')
    on('bank', function(data)
        if data.open then
            refreshBank(data)
        else
            refreshBank(data)
        end
    end)
end

function bankTerminate()
    bankOnGameEnd()
end
