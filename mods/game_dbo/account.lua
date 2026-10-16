-- =============================================================================
-- DBO in-client account registration (TFS 1.6 HTTP service: type=createaccount)
-- =============================================================================

local accountWindow = nil

local function loginUrl()
    if Servers_init then
        for url, _ in pairs(Servers_init) do
            if url:find('^https?://') then
                return url
            end
        end
    end
    return 'http://127.0.0.1:8080/'
end

local function setStatus(text, color)
    local label = accountWindow:getChildById('status')
    label:setText(text)
    label:setColor(color or '#ffe9b0')
end

local function submit()
    local email = accountWindow:getChildById('email'):getText()
    local password = accountWindow:getChildById('password'):getText()
    local repeatPass = accountWindow:getChildById('repeatPassword'):getText()
    local name = accountWindow:getChildById('name'):getText()
    if password ~= repeatPass then
        return setStatus('As senhas nao conferem.', '#ff8a7a')
    end
    setStatus('Criando conta...')
    HTTP.postJSON(loginUrl(), { type = 'createaccount', email = email, password = password, name = name }, function(data, err)
        if not accountWindow then
            return
        end
        if err then
            return setStatus('Erro de conexao: ' .. tostring(err), '#ff8a7a')
        end
        if type(data) == 'table' and data.success then
            setStatus('Conta criada! Faca login com seu e-mail e senha.', '#8fe08f')
            if EnterGame and EnterGame.setAccountName then
                EnterGame.setAccountName(email)
                EnterGame.setPassword(password)
            end
            scheduleEvent(function()
                if accountWindow then
                    accountWindow:hide()
                end
            end, 1500)
        else
            setStatus(type(data) == 'table' and (data.errorMessage or 'Erro') or 'Erro', '#ff8a7a')
        end
    end)
end

function openCreateAccount()
    if not accountWindow then
        accountWindow = g_ui.createWidget('DboAccountWindow', rootWidget)
        accountWindow:getChildById('windowTitle'):setText('Criar Conta')
        accountWindow:getChildById('create').onClick = submit
        accountWindow.onEnter = submit
    end
    setStatus('Seu personagem sera escolhido ao entrar no jogo.')
    accountWindow:show()
    accountWindow:raise()
    accountWindow:focus()
    accountWindow:getChildById('email'):focus()
end

function accountTerminate()
    if accountWindow then
        accountWindow:destroy()
        accountWindow = nil
    end
end
