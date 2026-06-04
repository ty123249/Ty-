-- --- PlaceId 驗證 (非指定地圖直接結束) ---
if game.PlaceId ~= 12575645876 then 
    return 
end

local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local rs = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- --- 跨腳本記憶狀態恢復系統 ---
if not shared.OmniSettings then
    shared.OmniSettings = {
        autoKnife = false,
        autoGun = false,
        killActive = false,
        espEnabled = true,
        autoHealEnabled = false,
        removeFog = false,
        harvestRange = 100
    }
end

-- 從共享環境中還原開關狀態
local autoKnife = shared.OmniSettings.autoKnife
local autoGun = shared.OmniSettings.autoGun
local killActive = shared.OmniSettings.killActive
local espEnabled = shared.OmniSettings.espEnabled
local autoHealEnabled = shared.OmniSettings.autoHealEnabled
local removeFog = shared.OmniSettings.removeFog
local harvestRange = shared.OmniSettings.harvestRange

local animalEspObjects = {}    
local playerEspObjects = {}    
local myName = "hk_c002"       
local uiActive = true
local isMinimized = false
local isProcessing = false     

-- --- 遠端與物件預載 ---
local stuff = rs:WaitForChild("Stuff", 5)
local bullets = stuff and stuff:WaitForChild("Bullets", 5)
local normalBullet = bullets and bullets:WaitForChild("NormalBullet", 5)

local events = rs:WaitForChild("Events", 5)
local pEvents = events and events:WaitForChild("Player", 5)
local EquipRemote = pEvents and pEvents:WaitForChild("Equip", 5)
local SetValueRemote = pEvents and pEvents:WaitForChild("SetItemObjValue", 5)

-- --- 1. UI 系統主框架 ---
local oldGui = lp:WaitForChild("PlayerGui"):FindFirstChild("OmniHarvester_V8_MaxBurst")
if oldGui then oldGui:Destroy() end 

local screenGui = Instance.new("ScreenGui", lp.PlayerGui)
screenGui.Name = "OmniHarvester_V8_MaxBurst"
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 220, 0, 430) 
mainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.Active = true
mainFrame.ClipsDescendants = true
Instance.new("UICorner", mainFrame)

local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size = UDim2.new(1, 0, 0, 35); titleLabel.Text = "狩獵全能 (動態重載版)"; titleLabel.TextColor3 = Color3.fromRGB(255, 200, 50); titleLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35); titleLabel.Font = Enum.Font.SourceSansBold; titleLabel.TextSize = 16

local dragging, dragStart, startPos
mainFrame.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = input.Position; startPos = mainFrame.Position end end)
uis.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local delta = input.Position - dragStart; mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
uis.InputEnded:Connect(function(input) dragging = false end)

local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1, 0, 1, -40); contentFrame.Position = UDim2.new(0, 0, 0, 40); contentFrame.BackgroundTransparency = 1

local minBtn = Instance.new("TextButton", mainFrame)
minBtn.Size = UDim2.new(0, 25, 0, 25); minBtn.Position = UDim2.new(1, -60, 0, 5); minBtn.Text = "-"; minBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60); minBtn.TextColor3 = Color3.new(1, 1, 1); minBtn.ZIndex = 10; Instance.new("UICorner", minBtn)

local closeBtn = Instance.new("TextButton", mainFrame)
closeBtn.Size = UDim2.new(0, 25, 0, 25); closeBtn.Position = UDim2.new(1, -30, 0, 5); closeBtn.Text = "X"; closeBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40); closeBtn.TextColor3 = Color3.new(1, 1, 1); closeBtn.ZIndex = 10; Instance.new("UICorner", closeBtn)

-- 清理舊資源函數
local function CleanUpScript()
    uiActive = false
    autoKnife = false
    autoGun = false
    killActive = false
    espEnabled = false
    autoHealEnabled = false
    
    for _, e in pairs(animalEspObjects) do if e.Gui then e.Gui:Destroy() end end
    for _, e in pairs(playerEspObjects) do if e.Gui then e.Gui:Destroy() end end
    
    Lighting.FogEnd = 1500
    local oldAtm = rs:FindFirstChildOfClass("Atmosphere")
    if oldAtm then oldAtm.Parent = Lighting end
    screenGui:Destroy()
end

closeBtn.MouseButton1Click:Connect(CleanUpScript)

minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    ts:Create(mainFrame, TweenInfo.new(0.3), {Size = isMinimized and UDim2.new(0, 220, 0, 35) or UDim2.new(0, 220, 0, 430)}):Play()
    contentFrame.Visible = not isMinimized
    minBtn.Text = isMinimized and "+" or "-"
end)

-- --- 2. 按鈕與控制項建立 ---
local function createBtn(text, pos, color)
    local btn = Instance.new("TextButton", contentFrame); btn.Size = UDim2.new(0.9, 0, 0, 32); btn.Position = pos; btn.BackgroundColor3 = color; btn.TextColor3 = Color3.new(1, 1, 1); btn.Font = Enum.Font.SourceSansBold; btn.TextSize = 14; btn.Text = text; Instance.new("UICorner", btn); return btn
end

local knifeBtn = createBtn("自動砍殺", UDim2.new(0.05, 0, 0.01, 0), Color3.new())
local gunBtn = createBtn("自動連發", UDim2.new(0.05, 0, 0.10, 0), Color3.new())
local killBtn = createBtn("玩家殺戮", UDim2.new(0.05, 0, 0.19, 0), Color3.new()) 
local espBtn = createBtn("全景 ESP", UDim2.new(0.05, 0, 0.28, 0), Color3.new())   
local healBtn = createBtn("醫療", UDim2.new(0.05, 0, 0.37, 0), Color3.new())
local fogBtn = createBtn("移除霧氣", UDim2.new(0.05, 0, 0.46, 0), Color3.new())

-- 【設定：重新讀取 GitHub 最新代碼的按鈕】
local rebootBtn = createBtn("⚡ 雲端重載腳本 (0.5s)", UDim2.new(0.05, 0, 0.55, 0), Color3.fromRGB(35, 105, 190))

local rangeLabel = Instance.new("TextLabel", contentFrame); rangeLabel.Size = UDim2.new(0.4, 0, 0, 25); rangeLabel.Position = UDim2.new(0.05, 0, 0.66, 0); rangeLabel.Text = "作戰範圍:"; rangeLabel.TextColor3 = Color3.new(1, 1, 1); rangeLabel.BackgroundTransparency = 1; rangeLabel.TextXAlignment = Enum.TextXAlignment.Left
local rangeInput = Instance.new("TextBox", contentFrame); rangeInput.Size = UDim2.new(0.45, 0, 0, 25); rangeInput.Position = UDim2.new(0.5, 0, 0.66, 0); rangeInput.BackgroundColor3 = Color3.fromRGB(40, 40, 45); rangeInput.Text = tostring(harvestRange); rangeInput.TextColor3 = Color3.new(0, 1, 1); Instance.new("UICorner", rangeInput)

-- 視覺面板同步刷新
local function RefreshVisuals()
    knifeBtn.Text = autoKnife and "自動砍殺：ON" or "自動砍殺：OFF"
    knifeBtn.BackgroundColor3 = autoKnife and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(60, 30, 30)
    
    gunBtn.Text = autoGun and "自動連發：ON" or "自動連發：OFF"
    gunBtn.BackgroundColor3 = autoGun and Color3.fromRGB(50, 80, 150) or Color3.fromRGB(30, 40, 60)
    
    killBtn.Text = killActive and "玩家殺戮：ON" or "玩家殺戮：OFF"
    killBtn.BackgroundColor3 = killActive and Color3.fromRGB(200, 0, 0) or Color3.fromRGB(80, 10, 10)
    
    espBtn.Text = espEnabled and "全景 ESP：ON" or "全景 ESP：OFF"
    espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(30, 60, 40) or Color3.fromRGB(60, 40, 40)
    
    healBtn.Text = autoHealEnabled and "醫療：ON" or "醫療：OFF"
    healBtn.BackgroundColor3 = autoHealEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(120, 0, 0)
    
    fogBtn.Text = removeFog and "移除霧氣：ON" or "移除霧氣：OFF"
    fogBtn.BackgroundColor3 = removeFog and Color3.fromRGB(140, 140, 30) or Color3.fromRGB(50, 50, 50)
    
    if removeFog then
        Lighting.FogEnd = 1e6
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then atm.Parent = rs end
    else
        Lighting.FogEnd = 1500
        local oldAtm = rs:FindFirstChildOfClass("Atmosphere")
        if oldAtm then oldAtm.Parent = Lighting end
    end
end
RefreshVisuals()

-- --- 3. 核心功能處理函數 ---
local function UpdateMergedESP(hrp)
    if not espEnabled then return end
    
    local anims = workspace:FindFirstChild("Living") and workspace.Living:FindFirstChild("Animals")
    if anims then
        for _, v in ipairs(anims:GetChildren()) do
            if not animalEspObjects[v] then
                local bg = Instance.new("BillboardGui", v); bg.AlwaysOnTop = true; bg.Size = UDim2.new(0, 80, 0, 20); bg.StudsOffset = Vector3.new(0, 3, 0)
                local lb = Instance.new("TextLabel", bg); lb.Size = UDim2.new(1, 0, 1, 0); lb.BackgroundTransparency = 1; lb.Font = Enum.Font.SourceSansBold; lb.TextSize = 11; lb.TextStrokeTransparency = 0.5; animalEspObjects[v] = {Label = lb, Gui = bg}
            end
            local root = v:FindFirstChildWhichIsA("BasePart", true)
            if root and root.Parent then
                local dist = (hrp.Position - root.Position).Magnitude
                animalEspObjects[v].Label.Text = v.Name .. "\n" .. math.floor(dist) .. "m"
                animalEspObjects[v].Label.TextColor3 = (dist <= harvestRange) and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
                animalEspObjects[v].Label.Visible = true
            else
                animalEspObjects[v].Label.Visible = false
            end
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local char = p.Character
            if not playerEspObjects[char] then
                local bg = Instance.new("BillboardGui", char); bg.AlwaysOnTop = true; bg.Size = UDim2.new(0, 120, 0, 20); bg.StudsOffset = Vector3.new(0, 4, 0)
                local lb = Instance.new("TextLabel", bg); lb.Size = UDim2.new(1, 0, 1, 0); lb.BackgroundTransparency = 1; lb.Font = Enum.Font.SourceSansBold; lb.TextSize = 13; lb.TextStrokeTransparency = 0
                playerEspObjects[char] = {Label = lb, Gui = bg, Player = p}
            end
            
            local targetPart = char:FindFirstChild("HumanoidRootPart")
            if targetPart and targetPart.Parent then
                local dist = math.floor((hrp.Position - targetPart.Position).Magnitude)
                local currentZone = char:GetAttribute("Zone") or (char:FindFirstChild("Zone") and char.Zone.Value)
                local isSafe = (currentZone == "SafeZone")
                
                playerEspObjects[char].Label.Text = (isSafe and "[SAFE] " or "") .. p.Name .. "\n" .. dist .. "m"
                
                if isSafe then
                    playerEspObjects[char].Label.TextColor3 = Color3.new(0, 1, 1)
                else
                    playerEspObjects[char].Label.TextColor3 = (dist <= harvestRange) and Color3.new(1, 0, 0) or Color3.new(1, 0.3, 0.3)
                end
                playerEspObjects[char].Label.Visible = true
            else
                playerEspObjects[char].Label.Visible = false
            end
        end
    end
    
    for o, e in pairs(animalEspObjects) do if not o or not o.Parent then if e.Gui then e.Gui:Destroy() end animalEspObjects[o] = nil end end
    for o, e in pairs(playerEspObjects) do if not o or not o.Parent then if e.Gui then e.Gui:Destroy() end playerEspObjects[o] = nil end end
end

local function doOverdriveHeal()
    isProcessing = true
    local hb5 = lp:FindFirstChild("HotBar") and lp.HotBar:FindFirstChild("5")
    local inv1 = lp:FindFirstChild("Inventory") and lp.Inventory:FindFirstChild("1")
    local char = lp.Character

    if hb5 and inv1 and SetValueRemote then pcall(function() SetValueRemote:InvokeServer(hb5, inv1) end) end
    if hb5 and EquipRemote then pcall(function() EquipRemote:InvokeServer(hb5) end) end
    
    task.spawn(function()
        if char then
            for i = 1, 3 do
                local medkit = char:FindFirstChild("Medkit")
                if medkit then
                    local heal = medkit:FindFirstChild("Scripts") and medkit.Scripts.System:FindFirstChild("Binds") and medkit.Scripts.System.Binds:FindFirstChild("Heal") and medkit.Scripts.System.Binds.Heal:FindFirstChild("Heal")
                    if heal then pcall(function() heal:InvokeServer() end) end
                    break
                end
                task.wait(0.01)
            end
        end
        isProcessing = false
    end)
end

-- --- 4. 核心工作主循環群 ---
task.spawn(function()
    while uiActive do
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local anims = workspace:FindFirstChild("Living") and workspace.Living:FindFirstChild("Animals")
        
        if hrp then
            if autoKnife and anims then
                local knife = char:FindFirstChild("HuntingKnife") or lp.Backpack:FindFirstChild("HuntingKnife")
                local kRemote = knife and knife:FindFirstChild("Scripts") and knife.Scripts.System:FindFirstChild("Hit")
                if kRemote then
                    for _, a in ipairs(anims:GetChildren()) do
                        pcall(function()
                            local root = a:FindFirstChildWhichIsA("BasePart", true)
                            local hum = a:FindFirstChild("Humanoid")
                            if root and hum and hum.Health > 0 and (root.Position - hrp.Position).Magnitude <= harvestRange then
                                kRemote:FireServer(hum, "LightAttack2", root.CFrame)
                            end
                        end)
                    end
                end
            end
            
            if (autoGun or killActive) and normalBullet then
                local weapon = char:FindFirstChild("M82") or char:FindFirstChild("CrocodileHunter")
                local hitRemote = weapon and weapon:FindFirstChild("Scripts") and weapon.Scripts:FindFirstChild("System") and weapon.Scripts.System:FindFirstChild("Hit")
                if weapon and not hitRemote then
                    for _, v in ipairs(weapon:GetDescendants()) do if v.Name == "Hit" and v:IsA("RemoteEvent") then hitRemote = v; break end end
                end
                
                if hitRemote then
                    if killActive then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= lp then
                                pcall(function()
                                    local targetHrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                                    local targetHum = p.Character and p.Character:FindFirstChild("Humanoid")
                                    local targetZone = p.Character and (p.Character:GetAttribute("Zone") or (p.Character:FindFirstChild("Zone") and p.Character.Zone.Value))
                                    
                                    if targetHrp and targetHum and targetHum.Health > 0 and targetZone ~= "SafeZone" then
                                        if (targetHrp.Position - hrp.Position).Magnitude <= harvestRange then
                                            hitRemote:FireServer({ DistanceMade = Vector3.zero, StartPosition = hrp.Position, HitMaterial = Enum.Material.SmoothPlastic, Ray = nil, ShootDirection = (targetHrp.Position - hrp.Position).Unit, HitPos = targetHrp.Position, RayHit = targetHrp, HitPart = targetHum, Bullet = normalBullet })
                                        end
                                    end
                                end)
                            end
                        end
                    end
                    
                    if autoGun and anims then
                        for _, a in ipairs(anims:GetChildren()) do
                            pcall(function()
                                local hum = a:FindFirstChild("Humanoid")
                                local target = a:FindFirstChildWhichIsA("BasePart", true)
                                if hum and hum.Health > 0 and target and (target.Position - hrp.Position).Magnitude <= harvestRange then
                                    hitRemote:FireServer({ DistanceMade = Vector3.zero, StartPosition = hrp.Position, HitMaterial = Enum.Material.Leather, Ray = nil, ShootDirection = (target.Position - hrp.Position).Unit, HitPos = target.Position, RayHit = target, HitPart = hum, Bullet = normalBullet })
                                end
                            end)
                        end
                    end
                end
            end
        end
        task.wait(0.05)
    end
end)

RunService.RenderStepped:Connect(function()
    if uiActive and espEnabled then
        local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if hrp then pcall(function() UpdateMergedESP(hrp) end) end
    end
end)

RunService.Heartbeat:Connect(function()
    if uiActive and autoHealEnabled and not isProcessing then
        local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 and hum.Health < 99 then doOverdriveHeal() end
    end
end)

-- --- 5. 交互綁定與記憶更新 ---
knifeBtn.MouseButton1Click:Connect(function() autoKnife = not autoKnife; shared.OmniSettings.autoKnife = autoKnife; RefreshVisuals() end)
gunBtn.MouseButton1Click:Connect(function() autoGun = not autoGun; shared.OmniSettings.autoGun = autoGun; RefreshVisuals() end)
killBtn.MouseButton1Click:Connect(function() killActive = not killActive; shared.OmniSettings.killActive = killActive; RefreshVisuals() end)
healBtn.MouseButton1Click:Connect(function() autoHealEnabled = not autoHealEnabled; shared.OmniSettings.autoHealEnabled = autoHealEnabled; RefreshVisuals() end)

espBtn.MouseButton1Click:Connect(function() 
    espEnabled = not espEnabled; shared.OmniSettings.espEnabled = espEnabled; RefreshVisuals()
    if not espEnabled then
        for _, e in pairs(animalEspObjects) do if e.Gui then e.Gui.TextLabel.Visible = false end end
        for _, e in pairs(playerEspObjects) do if e.Gui then e.Gui.TextLabel.Visible = false end end
    end
end)

fogBtn.MouseButton1Click:Connect(function() removeFog = not removeFog; shared.OmniSettings.removeFog = removeFog; RefreshVisuals() end)

rangeInput.FocusLost:Connect(function() 
    harvestRange = tonumber(rangeInput.Text) or 100; shared.OmniSettings.harvestRange = harvestRange; rangeInput.Text = tostring(harvestRange)
end)

-- 【執行 0.5 秒動態雲端載入】
rebootBtn.MouseButton1Click:Connect(function()
    -- 1. 保存當前開關狀態
    shared.OmniSettings = {
        autoKnife = autoKnife,
        autoGun = autoGun,
        killActive = killActive,
        espEnabled = espEnabled,
        autoHealEnabled = autoHealEnabled,
        removeFog = removeFog,
        harvestRange = harvestRange
    }
    
    -- 2. 徹底清空並關閉現行腳本物件與背景執行緒
    CleanUpScript()
    
    -- 3. 精準延遲 0.5 秒後，從你的 GitHub 網址拉取最新代碼執行
    task.wait(0.5)
    
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/ty123249/Ty-/refs/heads/main/%E7%8B%A9%E7%8D%B5%E5%85%A8%E8%83%BD(foresto).lua"))()
    end)
end)
