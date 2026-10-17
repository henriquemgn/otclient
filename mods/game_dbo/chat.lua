-- =============================================================================
-- DBO - chat restyle (dark frame, red tabs, "<  >  x  +" buttons)
-- =============================================================================

local function squareButton(w, text)
    if not w then
        return
    end
    w:setImageSource('')
    w:setIcon('')
    w:setText(text)
    w:setFont('verdana-11px-rounded')
    w:setColor('#e8d8b8')
    w:setBackgroundColor('#1c120e')
    w:setBorderWidth(1)
    w:setBorderColor('#6b4a1e')
    w:setSize({ width = 18, height = 18 })
end

function styleChat()
    local console = modules.game_console
    local panel = console and console.consolePanel
    if not panel then
        return
    end
    -- outer frame
    panel:setImageSource('/images/dbo/panel')
    panel:setImageBorder(10)
    for _, child in ipairs(panel:getChildren()) do
        local src = child:getImageSource() or ''
        if src:find('2pixel') then
            child:setImageSource('')
        end
    end
    local buffer = panel:recursiveGetChildById('panel')
    if buffer then
        buffer:setImageSource('')
        buffer:setBackgroundColor('#0a0605d0')
    end
    squareButton(panel:getChildById('prevChannelButton'), '<')
    squareButton(panel:getChildById('nextChannelButton'), '>')
    squareButton(panel:getChildById('closeChannelButton'), 'x')
    squareButton(panel:getChildById('channelsButton'), '+')
    local next = panel:getChildById('nextChannelButton')
    if next then
        -- keep it visible (the original style hides it when disabled)
        next:setWidth(18)
    end
    for _, id in ipairs({ 'ignoreButton', 'exivaOption', 'readOnlyButton', 'sayModeButton', 'toggleChat', 'extendedViewDraggable', 'extendedViewHide' }) do
        local w = panel:getChildById(id)
        if w then
            w:hide()
            w:setWidth(0)
        end
    end
    local edit = panel:getChildById('consoleTextEdit')
    if edit then
        edit:setImageSource('')
        edit:setBackgroundColor('#0a0606e0')
        edit:setBorderWidth(1)
        edit:setBorderColor('#a8772c')
        edit:setColor('#f2e2c0')
        if edit.setPlaceholder then
            edit:setPlaceholder('Enter to send, Esc to close')
        end
        if edit.setPlaceholderColor then
            edit:setPlaceholderColor('#8a7a60')
        end
        edit:breakAnchors()
        edit:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        edit:addAnchor(AnchorRight, 'parent', AnchorRight)
        edit:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        edit:setMarginLeft(8)
        edit:setMarginRight(8)
        edit:setMarginBottom(8)
        edit:setHeight(20)
    end
    -- existing tabs (created before the style override)
    local tabBar = panel:getChildById('consoleTabBar')
    if tabBar and tabBar.tabs then
        for _, tab in ipairs(tabBar.tabs) do
            tab:setImageSource('')
            tab:setBackgroundColor(tab:isChecked() and '#7a1a10' or '#1c120e')
            tab:setBorderWidth(1)
            tab:setBorderColor(tab:isChecked() and '#c0402a' or '#3a2618')
            local tp = tab.tabPanel
            local buf = tp and tp:getChildById('consoleBuffer')
            if buf then
                buf:setImageSource('')
                buf:setBackgroundColor('#0a0605d0')
            end
        end
    end
end

function chatInit()
    g_ui.importStyle('chat')
end
