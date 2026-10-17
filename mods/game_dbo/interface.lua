-- =============================================================================
-- DBO clean interface: full-screen game map (no grey Tibia side bars),
-- floating transparent panels, chat in the bottom-left corner and the DBO HUD
-- instead of the Tibia stats bars / action bars.
-- =============================================================================

local function gi()
    return modules.game_interface
end

local function hide(widget)
    if widget then
        widget:setVisible(false)
        widget:setOn(false)
    end
end

local function applyCleanLayout()
    local iface = gi()
    if not iface or not g_game.isOnline() then
        return
    end
    -- extended view: map fills the whole window, panels become transparent overlays
    if iface.setupViewMode then
        iface.setupViewMode(2)
    end

    -- Tibia stats bars and action bars are replaced by the DBO HUD
    for _, getter in ipairs({ 'getGameTopStatsBar', 'getGameBottomStatsBar', 'getBottomActionPanel', 'getLeftActionPanel',
        'getRightActionPanel', 'getBottomLockPanel', 'getRightLockPanel', 'getLeftLockPanel' }) do
        if iface[getter] then
            local w = iface[getter]()
            if w then
                w:setVisible(false)
                if getter:find('ActionPanel') then
                    w:setWidth(0)
                end
            end
        end
    end
    local rootPanel = iface.getRootPanel()
    for _, id in ipairs({ 'gameBottomCooldownPanel', 'leftIncreaseSidePanels', 'leftDecreaseSidePanels', 'rightIncreaseSidePanels',
        'rightDecreaseSidePanels', 'bottomSplitter', 'gameSelectLeftColumn', 'gameSelectRightColumn', 'gameSelectRightExtraColumn', 'gameSelectLeftExtraColumn',
        'gameLeftActionPanel', 'gameRightActionPanel', 'gameBottomActionPanel', 'lockPanel' }) do
        local w = rootPanel:recursiveGetChildById(id)
        if w then
            w:setVisible(false)
        end
    end

    -- left columns are never used
    hide(iface.getLeftPanel())
    hide(iface.getLeftExtraPanel())
    hide(iface.getRightExtraPanel())

    -- map without the padded frame, filling the whole screen
    local map = iface.getMapPanel()
    if map then
        map:setKeepAspectRatio(false)
        if map.setDrawLights then map:setDrawLights(false) end
        map:setImageSource('')
        map:setPadding(0)
        map:setMarginBottom(0)
        map:setMarginTop(0)
    end

    -- chat: small transparent window in the bottom-left corner
    local bottom = iface.getBottomPanel()
    if bottom then
        bottom:breakAnchors()
        bottom:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        bottom:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        bottom:setWidth(math.min(380, math.floor(rootPanel:getWidth() * 0.24)))
        bottom:setHeight(170)
        bottom:setMarginLeft(4)
        bottom:setMarginBottom(4)
        bottom:setImageColor('#ffffff40')
    end

    -- gentle transparency on the right column (inventory, minimap, battle, backpacks)
    local right = iface.getRightPanel()
    if right then
        right:setImageColor('alpha')
    end
    local mainRight = iface.getMainRightPanel and iface.getMainRightPanel()
    if mainRight then
        mainRight:setImageColor('alpha')
    end

    -- top menu floats over the map (transparent) instead of taking a row
    local topMenu = modules.client_topmenu and modules.client_topmenu.getTopMenu and modules.client_topmenu.getTopMenu()
    if topMenu then
        topMenu:setImageColor('alpha')
        topMenu:setBackgroundColor('#00000000')
        rootPanel:breakAnchors()
        rootPanel:fill('parent')
        topMenu:raise()
        if right then
            right:setMarginTop(30)
        end
        if mainRight then
            mainRight:setMarginTop(30)
        end
    end

    if map then
        map:setZoom(13) -- 13 tiles tall, width follows the window aspect (server sends 26x18)
    end

    if modules.client_background and modules.client_background.hide then
        modules.client_background.hide()
    end
    -- spell group cooldown icons (the DBO HUD shows its own cooldowns)
    local cd = modules.game_cooldown and modules.game_cooldown.cooldownWindow
    if cd then
        cd:setVisible(false)
        cd:setHeight(0)
    end
    if styleChat then
        styleChat()
    end
    if hud then
        hud:raise()
    end
end

function interfaceOnGameStart()
    -- the interface builds its panels asynchronously: apply twice
    scheduleEvent(applyCleanLayout, 50)
    scheduleEvent(applyCleanLayout, 800)
end

function reapplyLayout()
    applyCleanLayout()
end
