-- National Disaster Survival - Disaster Predictor
-- Repo: https://github.com/
-- Only works for player: 7536106759

local ALLOWED = 7536106759

local Players = game:GetService('Players')
local lp = Players.LocalPlayer
if not lp then lp = Players.PlayerAdded:Wait() end
if lp.UserId ~= ALLOWED then return end

-- Services
local RS = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local CoreGui = game:GetService('CoreGui')

-- Remove existing UI
pcall(function() CoreGui:FindFirstChild('NDSPredictor'):Destroy() end)

-- Create ScreenGui
local gui = Instance.new('ScreenGui')
gui.Name = 'NDSPredictor'
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = CoreGui

-- Main Frame
local frame = Instance.new('Frame')
frame.Name = 'Main'
frame.Size = UDim2.new(0, 280, 0, 120)
frame.Position = UDim2.new(0.5, -140, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local stroke = Instance.new('UIStroke')
stroke.Color = Color3.fromRGB(80, 120, 255)
stroke.Thickness = 1.5
stroke.Parent = frame

-- Title
local title = Instance.new('TextLabel')
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = '⚡ Disaster Predictor'
title.TextColor3 = Color3.fromRGB(120, 160, 255)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.Parent = frame

-- Disaster label
local disLabel = Instance.new('TextLabel')
disLabel.Size = UDim2.new(1, -20, 0, 40)
disLabel.Position = UDim2.new(0, 10, 0, 30)
disLabel.BackgroundTransparency = 1
disLabel.Text = '🔍 جاري البحث...'
disLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
disLabel.TextSize = 18
disLabel.Font = Enum.Font.GothamBold
disLabel.TextXAlignment = Enum.TextXAlignment.Center
disLabel.Parent = frame

-- Timer label
local timerLabel = Instance.new('TextLabel')
timerLabel.Size = UDim2.new(1, 0, 0, 24)
timerLabel.Position = UDim2.new(0, 0, 0, 72)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ''
timerLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
timerLabel.TextSize = 12
timerLabel.Font = Enum.Font.Gotham
timerLabel.Parent = frame

-- Status dot
local dot = Instance.new('Frame')
dot.Size = UDim2.new(0, 8, 0, 8)
dot.Position = UDim2.new(0, 10, 0, 11)
dot.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
dot.BorderSizePixel = 0
dot.Parent = frame
local dotCorner = Instance.new('UICorner')
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot

-- Close button
local closeBtn = Instance.new('TextButton')
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -28, 0, 4)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = '✕'
closeBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.Gotham
closeBtn.Parent = frame
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Disaster configs
local DISASTERS = {
    { name = 'صاعقة برق', emoji = '⚡', color = Color3.fromRGB(255, 230, 50), hint = 'Lightning' },
    { name = 'إعصار', emoji = '🌀', color = Color3.fromRGB(100, 200, 255), hint = 'Tornado' },
    { name = 'فيضان', emoji = '🌊', color = Color3.fromRGB(50, 100, 255), hint = 'Flood' },
    { name = 'زلزال', emoji = '🏚', color = Color3.fromRGB(180, 120, 60), hint = 'Earthquake' },
    { name = 'أعاصير نارية', emoji = '🌋', color = Color3.fromRGB(255, 80, 30), hint = 'FireTornado' },
    { name = 'قنبلة نووية', emoji = '☢️', color = Color3.fromRGB(200, 255, 80), hint = 'Nuke' },
    { name = 'نيزك', emoji = '☄️', color = Color3.fromRGB(255, 150, 80), hint = 'Meteor' },
    { name = 'ثلج', emoji = '❄️', color = Color3.fromRGB(180, 230, 255), hint = 'Blizzard' },
    { name = 'حريق', emoji = '🔥', color = Color3.fromRGB(255, 60, 20), hint = 'Fire' },
    { name = 'عاصفة رملية', emoji = '🏜', color = Color3.fromRGB(220, 180, 100), hint = 'Sandstorm' },
}

local function findDisasterByKeyword(text)
    local lower = text:lower()
    for _, d in ipairs(DISASTERS) do
        if lower:find(d.hint:lower()) then return d end
    end
    return nil
end

local function pulseColor(color)
    local tween1 = TweenService:Create(stroke,
        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Color = color }
    )
    tween1:Play()
end

local function showDisaster(d)
    disLabel.Text = d.emoji .. ' ' .. d.name
    disLabel.TextColor3 = d.color
    stroke.Color = d.color
    pulseColor(d.color)
end

-- Scanning logic
local lastDisaster = nil
local scanInterval = 0
local foundAt = 0

local function scan()
    -- Look for disaster name in workspace descendants
    local found = nil

    -- Method 1: Check workspace for disaster-related objects
    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = obj.Name
        local d = findDisasterByKeyword(n)
        if d then found = d break end
    end

    -- Method 2: Check ReplicatedStorage
    if not found then
        local ok, rs = pcall(function() return game:GetService('ReplicatedStorage') end)
        if ok and rs then
            for _, obj in ipairs(rs:GetDescendants()) do
                local d = findDisasterByKeyword(obj.Name)
                if d then found = d break end
            end
        end
    end

    -- Method 3: Look for any RemoteEvent/Value with disaster name
    if not found then
        for _, svc in ipairs({workspace, game:GetService('ReplicatedStorage')}) do
            local ok2, children = pcall(function() return svc:GetChildren() end)
            if ok2 then
                for _, c in ipairs(children) do
                    local d = findDisasterByKeyword(c.Name)
                    if d then found = d break end
                end
            end
            if found then break end
        end
    end

    if found and found ~= lastDisaster then
        lastDisaster = found
        foundAt = tick()
        showDisaster(found)
        dot.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
    elseif not found then
        if tick() - foundAt > 8 then
            lastDisaster = nil
            disLabel.Text = '🔍 في انتظار الكارثة...'
            disLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            stroke.Color = Color3.fromRGB(80, 120, 255)
        end
        dot.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    end
end

-- Timer update
RS.Heartbeat:Connect(function()
    scanInterval = scanInterval + 1
    if scanInterval >= 30 then
        scanInterval = 0
        pcall(scan)
    end
    if lastDisaster then
        local elapsed = math.floor(tick() - foundAt)
        timerLabel.Text = '⏱ منذ ' .. elapsed .. ' ثانية'
    else
        timerLabel.Text = 'يفحص كل ثانية...'
    end
end)

-- Initial scan
pcall(scan)
print('[NDSPredictor] UI loaded!')
