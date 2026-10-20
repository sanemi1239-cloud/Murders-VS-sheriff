-- ╔══════════════════════════════════════════════════════╗
-- ║        MSVD CHEAT | AimBot + ESP | Space Cheat      ║
-- ║     Для Delta Executor | by SpaceCheat              ║
-- ╚══════════════════════════════════════════════════════╝

-- ══════════════ СЕРВИСЫ ══════════════
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local Camera        = workspace.CurrentCamera

local LocalPlayer   = Players.LocalPlayer
local Mouse         = LocalPlayer:GetMouse()

-- ══════════════ НАСТРОЙКИ (ИЗМЕНЯЙ ЗДЕСЬ) ══════════════
local Config = {
    -- AimBot
    Aimbot = {
        Enabled    = false,
        Key        = Enum.KeyCode.Q,      -- Клавиша активации аима (или зажим)
        HoldMode   = true,               -- true = держи клавишу, false = переключатель
        Smoothness = 0.15,               -- Плавность: 0.01 (мгновенно) → 1.0 (медленно)
        FOV        = 150,                -- Радиус захвата цели (пиксели)
        ShowFOV    = true,               -- Показывать круг FOV
        TargetPart = "Head",             -- "Head" / "HumanoidRootPart" / "Torso"
        TeamCheck  = true,               -- Не целиться в союзников
        WallCheck  = false,              -- Проверять стены (false = сквозь стены)
        FOVColor   = Color3.fromRGB(255, 50, 50),
    },
    -- ESP
    ESP = {
        Enabled    = false,
        ShowBox    = true,               -- 2D рамка вокруг игрока
        ShowName   = true,               -- Имя над игроком
        ShowDist   = true,               -- Расстояние
        ShowHealth = true,               -- Полоска HP
        MaxDist    = 1000,               -- Максимальная дистанция ESP
        BoxColor        = Color3.fromRGB(255, 50, 50),
        NameColor       = Color3.fromRGB(255, 255, 255),
        HealthColor     = Color3.fromRGB(50, 255, 80),
        HealthBgColor   = Color3.fromRGB(60, 60, 60),
        DistColor       = Color3.fromRGB(200, 200, 200),
        FriendColor     = Color3.fromRGB(50, 150, 255),  -- Цвет для союзников
        TeamColored     = true,          -- Разные цвета для команд
    },
    -- UI
    UI = {
        AccentColor = Color3.fromRGB(220, 50, 50),
        BgColor     = Color3.fromRGB(18, 18, 22),
        PanelColor  = Color3.fromRGB(26, 26, 32),
        TextColor   = Color3.fromRGB(235, 235, 235),
        Font        = Enum.Font.GothamBold,
    },
}

-- ══════════════ UTILITY ══════════════
local function getTeam(player)
    return player.Team
end

local function isAlly(player)
    if not Config.Aimbot.TeamCheck then return false end
    return getTeam(player) == getTeam(LocalPlayer)
end

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function worldToScreen(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function getCharPart(player, partName)
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild(partName)
end

-- ══════════════ FOV CIRCLE ══════════════
local fovCircle = Drawing.new("Circle")
fovCircle.Visible   = false
fovCircle.Thickness = 1.5
fovCircle.Radius    = Config.Aimbot.FOV
fovCircle.Filled    = false
fovCircle.Color     = Config.Aimbot.FOVColor
fovCircle.Transparency = 1

local function updateFOV()
    fovCircle.Radius  = Config.Aimbot.FOV
    fovCircle.Color   = Config.Aimbot.FOVColor
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Visible  = Config.Aimbot.Enabled and Config.Aimbot.ShowFOV
end

-- ══════════════ AIMBOT ══════════════
local function getBestTarget()
    local center   = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local bestDist = Config.Aimbot.FOV
    local bestPos  = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not isAlive(player) then continue end
        if isAlly(player) then continue end

        local part = getCharPart(player, Config.Aimbot.TargetPart)
        if not part then continue end

        if Config.Aimbot.WallCheck then
            local ray = Ray.new(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 5000)
            local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, workspace.Terrain})
            if hit and hit:IsDescendantOf(workspace) and not hit:IsDescendantOf(player.Character) then
                continue
            end
        end

        local screenPos, onScreen = worldToScreen(part.Position)
        if not onScreen then continue end

        local dist = (screenPos - center).Magnitude
        if dist < bestDist then
            bestDist = dist
            bestPos  = part.Position
        end
    end
    return bestPos
end

local aimbotActive = false

local function runAimbot()
    if not Config.Aimbot.Enabled then return end
    local holding = Config.Aimbot.HoldMode
        and UserInputService:IsKeyDown(Config.Aimbot.Key)
        or aimbotActive

    if not holding then return end

    local targetPos = getBestTarget()
    if not targetPos then return end

    local currentCF  = Camera.CFrame
    local targetCF   = CFrame.new(currentCF.Position, targetPos)
    Camera.CFrame    = currentCF:Lerp(targetCF, Config.Aimbot.Smoothness)
end

-- ══════════════ ESP DRAWINGS ══════════════
local espObjects = {}

local function createESPForPlayer(player)
    if player == LocalPlayer then return end
    local drawings = {}

    -- Box (4 lines)
    drawings.boxLines = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness  = 1.5
        l.Color      = Config.ESP.BoxColor
        l.Visible    = false
        l.Transparency = 1
        drawings.boxLines[i] = l
    end

    -- Name
    drawings.name = Drawing.new("Text")
    drawings.name.Size     = 13
    drawings.name.Center   = true
    drawings.name.Outline  = true
    drawings.name.Color    = Config.ESP.NameColor
    drawings.name.Visible  = false

    -- Distance
    drawings.dist = Drawing.new("Text")
    drawings.dist.Size     = 11
    drawings.dist.Center   = true
    drawings.dist.Outline  = true
    drawings.dist.Color    = Config.ESP.DistColor
    drawings.dist.Visible  = false

    -- Health bar background
    drawings.healthBg = Drawing.new("Square")
    drawings.healthBg.Filled      = true
    drawings.healthBg.Color       = Config.ESP.HealthBgColor
    drawings.healthBg.Transparency = 1
    drawings.healthBg.Visible     = false

    -- Health bar
    drawings.health = Drawing.new("Square")
    drawings.health.Filled        = true
    drawings.health.Color         = Config.ESP.HealthColor
    drawings.health.Transparency  = 1
    drawings.health.Visible       = false

    espObjects[player] = drawings
end

local function removeESPForPlayer(player)
    local d = espObjects[player]
    if not d then return end
    for _, l in ipairs(d.boxLines or {}) do l:Remove() end
    if d.name    then d.name:Remove()    end
    if d.dist    then d.dist:Remove()    end
    if d.healthBg then d.healthBg:Remove() end
    if d.health  then d.health:Remove()  end
    espObjects[player] = nil
end

local function getBoxCorners(character)
    local parts   = {"Head","HumanoidRootPart","LeftLowerArm","RightLowerArm","LeftLowerLeg","RightLowerLeg"}
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local anyOnScreen = false

    for _, pName in ipairs(parts) do
        local part = character:FindFirstChild(pName)
        if part then
            local sp, onScreen = worldToScreen(part.Position)
            if onScreen then
                anyOnScreen = true
                minX = math.min(minX, sp.X)
                minY = math.min(minY, sp.Y)
                maxX = math.max(maxX, sp.X)
                maxY = math.max(maxY, sp.Y)
            end
        end
    end

    if not anyOnScreen then return nil end
    local pad = 6
    return Vector2.new(minX - pad, minY - pad), Vector2.new(maxX + pad, maxY + pad)
end

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local d = espObjects[player]
        if not d then continue end

        local char = player.Character
        local hum  = char and char:FindFirstChild("Humanoid")

        if not Config.ESP.Enabled or not char or not hum or hum.Health <= 0 then
            for _, l in ipairs(d.boxLines) do l.Visible = false end
            d.name.Visible    = false
            d.dist.Visible    = false
            d.health.Visible  = false
            d.healthBg.Visible = false
            continue
        end

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        local screenPos, onScreen, depth = worldToScreen(root.Position)
        local dist3D = (root.Position - Camera.CFrame.Position).Magnitude

        if not onScreen or dist3D > Config.ESP.MaxDist then
            for _, l in ipairs(d.boxLines) do l.Visible = false end
            d.name.Visible    = false
            d.dist.Visible    = false
            d.health.Visible  = false
            d.healthBg.Visible = false
            continue
        end

        -- Color по команде
        local boxColor = Config.ESP.BoxColor
        if Config.ESP.TeamColored and isAlly(player) then
            boxColor = Config.ESP.FriendColor
        end

        -- Box
        if Config.ESP.ShowBox then
            local topLeft, bottomRight = getBoxCorners(char)
            if topLeft then
                local tl = topLeft
                local br = bottomRight
                local tr = Vector2.new(br.X, tl.Y)
                local bl = Vector2.new(tl.X, br.Y)
                local corners = {tl, tr, br, bl}
                for i = 1, 4 do
                    local l = d.boxLines[i]
                    l.From    = corners[i]
                    l.To      = corners[(i % 4) + 1]
                    l.Color   = boxColor
                    l.Visible = true
                end

                -- Health bar
                if Config.ESP.ShowHealth then
                    local barW   = 4
                    local barX   = tl.X - barW - 3
                    local barH   = br.Y - tl.Y
                    local hpPct  = hum.Health / hum.MaxHealth
                    d.healthBg.Size     = Vector2.new(barW, barH)
                    d.healthBg.Position = Vector2.new(barX, tl.Y)
                    d.healthBg.Visible  = true
                    d.health.Size       = Vector2.new(barW, barH * hpPct)
                    d.health.Position   = Vector2.new(barX, tl.Y + barH * (1 - hpPct))
                    d.health.Color      = Color3.fromRGB(
                        math.floor(255 * (1 - hpPct)),
                        math.floor(255 * hpPct), 0)
                    d.health.Visible    = true
                end

                -- Name
                if Config.ESP.ShowName then
                    d.name.Text     = player.Name
                    d.name.Position = Vector2.new((tl.X + br.X) / 2, tl.Y - 16)
                    d.name.Color    = boxColor
                    d.name.Visible  = true
                end

                -- Distance
                if Config.ESP.ShowDist then
                    d.dist.Text     = string.format("[%d]", math.floor(dist3D))
                    d.dist.Position = Vector2.new((tl.X + br.X) / 2, br.Y + 3)
                    d.dist.Visible  = true
                end
            else
                for _, l in ipairs(d.boxLines) do l.Visible = false end
                d.name.Visible    = false
                d.dist.Visible    = false
                d.health.Visible  = false
                d.healthBg.Visible = false
            end
        end
    end
end

-- ══════════════ ИНИЦИАЛИЗАЦИЯ ESP ══════════════
for _, p in ipairs(Players:GetPlayers()) do
    createESPForPlayer(p)
end
Players.PlayerAdded:Connect(createESPForPlayer)
Players.PlayerRemoving:Connect(removeESPForPlayer)

-- ══════════════ ПЕРЕКЛЮЧЕНИЕ АИМБОТА (не-hold режим) ══════════════
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Config.Aimbot.Key and not Config.Aimbot.HoldMode then
        aimbotActive = not aimbotActive
    end
end)

-- ══════════════ GUI — SPACE CHEAT ══════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name              = "SpaceCheatGUI"
ScreenGui.ResetOnSpawn      = false
ScreenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset    = true

-- Попытка добавить через CoreGui (Delta поддерживает)
local success = pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui")
end)
if not success then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Перетаскиваемый чёрный круг
local BubbleFrame = Instance.new("Frame")
BubbleFrame.Name            = "Bubble"
BubbleFrame.Size            = UDim2.new(0, 54, 0, 54)
BubbleFrame.Position        = UDim2.new(0, 40, 0.5, -27)
BubbleFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
BubbleFrame.BorderSizePixel = 0
BubbleFrame.ZIndex          = 10
BubbleFrame.Parent          = ScreenGui

local BubbleCorner = Instance.new("UICorner")
BubbleCorner.CornerRadius   = UDim.new(1, 0)
BubbleCorner.Parent         = BubbleFrame

local BubbleStroke = Instance.new("UIStroke")
BubbleStroke.Color          = Config.UI.AccentColor
BubbleStroke.Thickness      = 2
BubbleStroke.Parent         = BubbleFrame

local BubbleLabel = Instance.new("TextLabel")
BubbleLabel.Size            = UDim2.new(1, 0, 1, 0)
BubbleLabel.BackgroundTransparency = 1
BubbleLabel.Text            = "⚡"
BubbleLabel.TextSize        = 22
BubbleLabel.Font            = Config.UI.Font
BubbleLabel.TextColor3      = Config.UI.AccentColor
BubbleLabel.ZIndex          = 11
BubbleLabel.Parent          = BubbleFrame

-- Главное окно чита
local MainFrame = Instance.new("Frame")
MainFrame.Name              = "MainPanel"
MainFrame.Size              = UDim2.new(0, 340, 0, 420)
MainFrame.Position          = UDim2.new(0, 110, 0.5, -210)
MainFrame.BackgroundColor3  = Config.UI.BgColor
MainFrame.BorderSizePixel   = 0
MainFrame.Visible           = false
MainFrame.ZIndex            = 10
MainFrame.Parent            = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius     = UDim.new(0, 12)
MainCorner.Parent           = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color            = Config.UI.AccentColor
MainStroke.Thickness        = 1.5
MainStroke.Parent           = MainFrame

-- Заголовок
local TitleBar = Instance.new("Frame")
TitleBar.Size               = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3   = Config.UI.PanelColor
TitleBar.BorderSizePixel    = 0
TitleBar.ZIndex             = 11
TitleBar.Parent             = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius    = UDim.new(0, 12)
TitleCorner.Parent          = TitleBar

-- фикс нижних углов у заголовка
local TitleFix = Instance.new("Frame")
TitleFix.Size               = UDim2.new(1, 0, 0.5, 0)
TitleFix.Position           = UDim2.new(0, 0, 0.5, 0)
TitleFix.BackgroundColor3   = Config.UI.PanelColor
TitleFix.BorderSizePixel    = 0
TitleFix.ZIndex             = 11
TitleFix.Parent             = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size             = UDim2.new(1, -50, 1, 0)
TitleLabel.Position         = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text             = "⚡  SPACE CHEAT  |  MSVD"
TitleLabel.TextSize         = 15
TitleLabel.Font             = Config.UI.Font
TitleLabel.TextColor3       = Config.UI.AccentColor
TitleLabel.TextXAlignment   = Enum.TextXAlignment.Left
TitleLabel.ZIndex           = 12
TitleLabel.Parent           = TitleBar

-- Кнопка закрытия (крестик → возвращает к кругу)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size               = UDim2.new(0, 32, 0, 32)
CloseBtn.Position           = UDim2.new(1, -40, 0, 6)
CloseBtn.BackgroundColor3   = Color3.fromRGB(200, 40, 40)
CloseBtn.Text               = "✕"
CloseBtn.TextSize           = 14
CloseBtn.Font               = Config.UI.Font
CloseBtn.TextColor3         = Color3.fromRGB(255, 255, 255)
CloseBtn.ZIndex             = 13
CloseBtn.Parent             = TitleBar

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 6)
CloseBtnCorner.Parent       = CloseBtn

-- Контейнер для кнопок настроек
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size            = UDim2.new(1, -16, 1, -54)
ScrollFrame.Position        = UDim2.new(0, 8, 0, 52)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 3
ScrollFrame.ScrollBarImageColor3 = Config.UI.AccentColor
ScrollFrame.ZIndex          = 11
ScrollFrame.Parent          = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding          = UDim.new(0, 6)
ListLayout.SortOrder        = Enum.SortOrder.LayoutOrder
ListLayout.Parent           = ScrollFrame

-- ══════════ HELPER: Создать секцию ══════════
local function makeSection(title, order)
    local sec = Instance.new("Frame")
    sec.Size                = UDim2.new(1, -8, 0, 26)
    sec.BackgroundTransparency = 1
    sec.LayoutOrder         = order
    sec.ZIndex              = 12
    sec.Parent              = ScrollFrame

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = "— " .. title .. " —"
    lbl.TextSize            = 12
    lbl.Font                = Config.UI.Font
    lbl.TextColor3          = Config.UI.AccentColor
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.ZIndex              = 12
    lbl.Parent              = sec
    return sec
end

-- ══════════ HELPER: Кнопка-переключатель ══════════
local function makeToggle(labelText, configTable, configKey, order, callback)
    local row = Instance.new("Frame")
    row.Size                = UDim2.new(1, -8, 0, 38)
    row.BackgroundColor3    = Config.UI.PanelColor
    row.BorderSizePixel     = 0
    row.LayoutOrder         = order
    row.ZIndex              = 12
    row.Parent              = ScrollFrame

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius  = UDim.new(0, 8)
    rowCorner.Parent        = row

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, -60, 1, 0)
    lbl.Position            = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = labelText
    lbl.TextSize            = 13
    lbl.Font                = Config.UI.Font
    lbl.TextColor3          = Config.UI.TextColor
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.ZIndex              = 13
    lbl.Parent              = row

    local toggleBg = Instance.new("Frame")
    toggleBg.Size           = UDim2.new(0, 42, 0, 22)
    toggleBg.Position       = UDim2.new(1, -52, 0.5, -11)
    toggleBg.BackgroundColor3 = configTable[configKey]
        and Config.UI.AccentColor or Color3.fromRGB(55, 55, 65)
    toggleBg.BorderSizePixel = 0
    toggleBg.ZIndex         = 13
    toggleBg.Parent         = row

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius    = UDim.new(1, 0)
    tCorner.Parent          = toggleBg

    local knob = Instance.new("Frame")
    knob.Size               = UDim2.new(0, 16, 0, 16)
    knob.Position           = configTable[configKey]
        and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3   = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel    = 0
    knob.ZIndex             = 14
    knob.Parent             = toggleBg

    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius    = UDim.new(1, 0)
    kCorner.Parent          = knob

    local btn = Instance.new("TextButton")
    btn.Size                = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                = ""
    btn.ZIndex              = 15
    btn.Parent              = row

    btn.MouseButton1Click:Connect(function()
        configTable[configKey] = not configTable[configKey]
        local on = configTable[configKey]
        TweenService:Create(toggleBg, TweenInfo.new(0.2), {
            BackgroundColor3 = on and Config.UI.AccentColor or Color3.fromRGB(55, 55, 65)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {
            Position = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
        if callback then callback(on) end
    end)

    return row
end

-- ══════════ HELPER: Слайдер ══════════
local function makeSlider(labelText, configTable, configKey, minV, maxV, order, callback)
    local row = Instance.new("Frame")
    row.Size                = UDim2.new(1, -8, 0, 52)
    row.BackgroundColor3    = Config.UI.PanelColor
    row.BorderSizePixel     = 0
    row.LayoutOrder         = order
    row.ZIndex              = 12
    row.Parent              = ScrollFrame

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius  = UDim.new(0, 8)
    rowCorner.Parent        = row

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(0.7, 0, 0, 22)
    lbl.Position            = UDim2.new(0, 12, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text                = labelText
    lbl.TextSize            = 12
    lbl.Font                = Config.UI.Font
    lbl.TextColor3          = Config.UI.TextColor
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.ZIndex              = 13
    lbl.Parent              = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Size             = UDim2.new(0.3, -12, 0, 22)
    valLbl.Position         = UDim2.new(0.7, 0, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text             = tostring(configTable[configKey])
    valLbl.TextSize         = 12
    valLbl.Font             = Config.UI.Font
    valLbl.TextColor3       = Config.UI.AccentColor
    valLbl.TextXAlignment   = Enum.TextXAlignment.Right
    valLbl.ZIndex           = 13
    valLbl.Parent           = row

    local track = Instance.new("Frame")
    track.Size              = UDim2.new(1, -24, 0, 6)
    track.Position          = UDim2.new(0, 12, 0, 32)
    track.BackgroundColor3  = Color3.fromRGB(45, 45, 55)
    track.BorderSizePixel   = 0
    track.ZIndex            = 13
    track.Parent            = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent      = track

    local fill = Instance.new("Frame")
    local pct  = (configTable[configKey] - minV) / (maxV - minV)
    fill.Size               = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3   = Config.UI.AccentColor
    fill.BorderSizePixel    = 0
    fill.ZIndex             = 14
    fill.Parent             = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent       = fill

    local dragging = false
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local absPos  = track.AbsolutePosition
            local absSize = track.AbsoluteSize
            local relX    = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)
            local val
            if configKey == "Smoothness" then
                val = math.floor(relX * (maxV - minV) * 100 + minV * 100) / 100
            else
                val = math.floor(relX * (maxV - minV) + minV)
            end
            configTable[configKey] = val
            fill.Size     = UDim2.new(relX, 0, 1, 0)
            valLbl.Text   = tostring(val)
            if callback then callback(val) end
        end
    end)
    return row
end

-- ══════════════ СТРОИМ МЕНЮ ══════════════
makeSection("AIMBOT", 1)
makeToggle("AimBot Включён",   Config.Aimbot, "Enabled",  2, function(v) updateFOV() end)
makeToggle("Режим удержания",  Config.Aimbot, "HoldMode", 3)
makeToggle("Показать FOV",     Config.Aimbot, "ShowFOV",  4, function() updateFOV() end)
makeToggle("Проверка команды", Config.Aimbot, "TeamCheck",5)
makeToggle("Проверка стен",    Config.Aimbot, "WallCheck",6)
makeSlider("Плавность аима",   Config.Aimbot, "Smoothness", 0.01, 1.0, 7)
makeSlider("Радиус FOV",       Config.Aimbot, "FOV",        50,   500, 8, function() updateFOV() end)

makeSection("ESP", 9)
makeToggle("ESP Включён",      Config.ESP, "Enabled",    10)
makeToggle("2D Рамка",         Config.ESP, "ShowBox",    11)
makeToggle("Имена",            Config.ESP, "ShowName",   12)
makeToggle("Расстояние",       Config.ESP, "ShowDist",   13)
makeToggle("Здоровье",         Config.ESP, "ShowHealth", 14)
makeToggle("Цвет по команде",  Config.ESP, "TeamColored",15)
makeSlider("Макс. дистанция",  Config.ESP, "MaxDist",    100, 2000, 16)

-- Авторасчёт высоты ScrollFrame
ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 12)
end)

-- ══════════════ ЛОГИКА ОТКРЫТИЯ/ЗАКРЫТИЯ ══════════════
local menuOpen = false

local function openMenu()
    menuOpen         = true
    BubbleFrame.Visible = false
    MainFrame.Visible   = true
    MainFrame.Size      = UDim2.new(0, 0, 0, 0)
    MainFrame.Position  = UDim2.new(0, 110, 0.5, 0)
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size     = UDim2.new(0, 340, 0, 420),
        Position = UDim2.new(0, 110, 0.5, -210),
    }):Play()
end

local function closeMenu()
    menuOpen = false
    TweenService:Create(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size     = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0, 110, 0.5, 0),
    }):Play()
    task.delay(0.2, function()
        MainFrame.Visible   = false
        BubbleFrame.Visible = true
    end)
end

BubbleFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        openMenu()
    end
end)
CloseBtn.MouseButton1Click:Connect(closeMenu)

-- ══════════════ ПЕРЕТАСКИВАНИЕ КРУГА ══════════════
do
    local dragging, dragStart, startPos
    BubbleFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = BubbleFrame.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            BubbleFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ══════════════ ПЕРЕТАСКИВАНИЕ ГЛАВНОГО ОКНА ══════════════
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = MainFrame.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ══════════════ MAIN LOOP ══════════════
RunService.RenderStepped:Connect(function()
    updateFOV()
    runAimbot()
    updateESP()
end)

print("[SpaceCheat] Загружен! Нажми на ⚡ круг слева чтобы открыть меню.")
