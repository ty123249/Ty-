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

-- --- 全局變數控制 ---
local autoKnife = false
local autoGun = false
local killActive = false       
local espEnabled = true        
local autoHealEnabled = false  
local isProcessing = false     

local harvestRange = 100       -- 目標範圍
local killRange = 300          -- 玩家殺戮範圍
local animalEspObjects = {}    
local playerEspObjects = {}    
local lastRefresh = tick()
local myName = "hk_c002"       

local uiActive = true
local isMinimized = false

-- --- 遠端與物件預載 (防卡死優化) ---
local stuff = rs:WaitForChild("Stuff", 5)
local bullets = stuff and stuff:WaitForChild("Bullets", 5)
local normalBullet = bullets and bullets:WaitForChild("NormalBullet", 5)

local events = rs:WaitForChild("Events", 5)
local pEvents = events and events:WaitForChild("Player", 5)
local EquipRemote = pEvents and pEvents:WaitForChild("Equip", 5)
local SetValueRemote = pEvents and pEvents:WaitForChild("SetItemObjValue", 5)

-- --- 1. UI 系統主框架 ---
local screenGui = Instance.new("ScreenGui", lp:WaitForChild("PlayerGui"))
screenGui.Name = "OmniHarvester_V8"
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 220, 0, 390) 
mainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.Active = true
mainFrame.ClipsDescendants = true
Instance.new("UICorner", mainFrame)

-- 頂部標題
local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size = UDim2.new(1, 0, 0, 35)
titleLabel.Text = "狩獵全能"
titleLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
titleLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 16

-- 現代拖動邏輯
local dragging, dragStart, startPos
mainFrame.InputBegan:Connect(function(input) 
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
        dragging = true; dragStart = input.Position; startPos = mainFrame.Position 
    end 
end)
uis.InputChanged:Connect(function(input) 
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then 
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) 
    end 
end)
uis.InputEnded:Connect(function(input) dragging = false end)

-- 內容容器
local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1, 0, 1, -40)
contentFrame.Position = UDim2.new(0, 0, 0, 40)
contentFrame.BackgroundTransparency = 1

-- 最小化按鈕
local minBtn = Instance.new("TextButton", mainFrame)
minBtn.Size = UDim2.new(0, 25, 0, 25); minBtn.Position = UDim2.new(1, -60, 0, 5); minBtn.Text = "-"; minBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60); minBtn.TextColor3 = Color3.new(1, 1, 1); minBtn.ZIndex = 10
Instance.new("UICorner", minBtn)

-- 關閉按鈕 (內置完全關閉所有功能邏輯)
local closeBtn = Instance.new("TextButton", mainFrame)
closeBtn.Size = UDim2.new(0, 25, 0, 25); closeBtn.Position = UDim2.new(1, -30, 0, 5); closeBtn.Text = "X"; closeBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40); closeBtn.TextColor3 = Color3.new(1, 1, 1); closeBtn.ZIndex = 10
Instance.new("UICorner", closeBtn)

closeBtn.MouseButton1Click:Connect(function() 
    uiActive = false
    -- 關閉時所有功能重置為 false
    autoKnife = false
    autoGun = false
    killActive = false
    espEnabled = false
    autoHealEnabled = false
    
    -- 清除所有 ESP 顯示
    for _, e in pairs(animalEspObjects) do if e.Gui then e.Gui:Destroy() end end
    for _, e in pairs(playerEspObjects) do if e.Gui then e.Gui:Destroy() end end
    
    -- 還原霧氣
    Lighting.FogEnd = 1500
    local oldAtm = rs:FindFirstChildOfClass("Atmosphere")
    if oldAtm then oldAtm.Parent = Lighting end
    
    screenGui:Destroy() 
end)

minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    ts:Create(mainFrame, TweenInfo.new(0.3), {Size = isMinimized and UDim2.new(0, 220, 0, 35) or UDim2.new(0, 220, 0, 390)}):Play()
    contentFrame.Visible = not isMinimized
    minBtn.Text = isMinimized and "+" or "-"
end)

-- --- 2. 獨立按鈕與輸入框建立 ---
local function createBtn(text, pos, color)
    local btn = Instance.new("TextButton", contentFrame); btn.Size = UDim2.new(0.9, 0, 0, 35); btn.Position = pos; btn.BackgroundColor3 = color; btn.TextColor3 = Color3.new(1, 1, 1); btn.Font = Enum.Font.SourceSansBold; btn.TextSize = 14; btn.Text = text; Instance.new("UICorner", btn); return btn
end

local knifeBtn = createBtn("自動砍殺：OFF", UDim2.new(0.05, 0, 0.02, 0), Color3.fromRGB(60, 30, 30))
local gunBtn = createBtn("自動連發：OFF", UDim2.new(0.05, 0, 0.13, 0), Color3.fromRGB(30, 40, 60))
local killBtn = createBtn("玩家殺戮：OFF", UDim2.new(0.05, 0, 0.24, 0), Color3.fromRGB(80, 10, 10)) 
local espBtn = createBtn("全景 ESP：ON", UDim2.new(0.05, 0, 0.35, 0), Color3.fromRGB(30, 60, 40))   
local healBtn = createBtn("醫療：OFF", UDim2.new(0.05, 0, 0.46, 0), Color3.fromRGB(120, 0, 0))
local fogBtn = createBtn("移除霧氣：OFF", UDim2.new(0.05, 0, 0.57, 0), Color3.fromRGB(50, 50, 50))

-- 範圍設定輸入區
local rangeLabel = Instance.new("TextLabel", contentFrame)
rangeLabel.Size = UDim2.new(0.4, 0, 0, 25); rangeLabel.Position = UDim2.new(0.05, 0, 0.70, 0); rangeLabel.Text = "目標範圍:"; rangeLabel.TextColor3 = Color3.new(1, 1, 1); rangeLabel.BackgroundTransparency = 1; rangeLabel.TextXAlignment = Enum.TextXAlignment.Left

local rangeInput = Instance.new("TextBox", contentFrame); rangeInput.Size = UDim2.new(0.45, 0, 0, 25); rangeInput.Position = UDim2.new(0.5, 0, 0.70, 0); rangeInput.BackgroundColor3 = Color3.fromRGB(40, 40, 45); rangeInput.Text = tostring(harvestRange); rangeInput.TextColor3 = Color3.new(0, 1, 1); Instance.new("UICorner", rangeInput)

-- 底部標題修改
local statusLabel = Instance.new("TextLabel", contentFrame); statusLabel.Size = UDim2.new(1, 0, 0, 30); statusLabel.Position = UDim2.new(0, 0, 0.81, 0); statusLabel.Text = "狩獵全能已就緒"; statusLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7); statusLabel.BackgroundTransparency = 1

-- --- 3. 核心功能處理函數 ---

-- 合併 ESP 處理常式
local function UpdateMergedESP(hrp)
    if not espEnabled then return end
    
    -- 動物 ESP
    local anims = workspace:FindFirstChild("Living") and workspace.Living:FindFirstChild("Animals")
    if anims then
        for _, v in pairs(anims:GetChildren()) do
            if not animalEspObjects[v] then
                local bg = Instance.new("BillboardGui", v); bg.AlwaysOnTop = true; bg.Size = UDim2.new(0, 80, 0, 20); bg.StudsOffset = Vector3.new(0, 3, 0)
                local lb = Instance.new("TextLabel", bg); lb.Size = UDim2.new(1, 0, 1, 0); lb.BackgroundTransparency = 1; lb.Font = Enum.Font.SourceSansBold; lb.TextSize = 11; lb.TextStrokeTransparency = 0.5; animalEspObjects[v] = {Label = lb, Gui = bg}
            end
            local root = v:FindFirstChildWhichIsA("BasePart", true)
            if root then
                local dist = (hrp.Position - root.Position).Magnitude
                animalEspObjects[v].Label.Text = v.Name .. "\n" .. math.floor(dist) .. "m"
                animalEspObjects[v].Label.TextColor3 = (dist <= harvestRange) and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
                animalEspObjects[v].Label.Visible = true
            end
        end
    end
    for o, e in pairs(animalEspObjects) do if not o.Parent then if e.Gui then e.Gui:Destroy() end animalEspObjects[o] = nil end end

    -- 玩家 ESP
    if tick() - lastRefresh >= 5 then
        for _, e in pairs(playerEspObjects) do if e.Gui then e.Gui:Destroy() end end
        playerEspObjects = {}
        lastRefresh = tick()
    end
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Model") and v.Name ~= myName and Players:FindFirstChild(v.Name) then
            if not playerEspObjects[v] then
                local bg = Instance.new("BillboardGui", v); bg.AlwaysOnTop = true; bg.Size = UDim2.new(0, 100, 0, 20); bg.StudsOffset = Vector3.new(0, 4, 0)
                local lb = Instance.new("TextLabel", bg); lb.Size = UDim2.new(1, 0, 1, 0); lb.BackgroundTransparency = 1; lb.TextColor3 = Color3.new(1, 0.3, 0.3); lb.Font = Enum.Font.SourceSansBold; lb.TextSize = 13; lb.TextStrokeTransparency = 0
                playerEspObjects[v] = {Label = lb, Gui = bg}
            end
            local targetPart = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChildWhichIsA("BasePart")
            if targetPart then
                local dist = math.floor((hrp.Position - targetPart.Position).Magnitude)
                playerEspObjects[v].Label.Text = "[PLAYER] " .. v.Name .. "\n" .. dist .. "m"
                playerEspObjects[v].Label.Visible = true
            end
        end
    end
    for o, e in pairs(playerEspObjects) do if not o.Parent then if e.Gui then e.Gui:Destroy() end playerEspObjects[o] = nil end end
end

-- 醫療觸發
local function doOverdriveHeal()
    isProcessing = true
    local hb5 = lp:FindFirstChild("HotBar") and lp.HotBar:FindFirstChild("5")
    local inv1 = lp:FindFirstChild("Inventory") and lp.Inventory:FindFirstChild("1")
    local char = lp.Character

    task.spawn(function() if hb5 and inv1 and SetValueRemote then SetValueRemote:InvokeServer(hb5, inv1) end end)
    task.spawn(function() if hb5 and EquipRemote then EquipRemote:InvokeServer(hb5) end end)
    task.spawn(function()
        if char then
            for i = 1, 3 do
                local medkit = char:FindFirstChild("Medkit")
                if medkit then
                    local heal = medkit:FindFirstChild("Scripts") and medkit.Scripts:FindFirstChild("System") and medkit.Scripts.System:FindFirstChild("Binds") and medkit.Scripts.System.Binds:FindFirstChild("Heal") and medkit.Scripts.System.Binds.Heal:FindFirstChild("Heal")
                    if heal then heal:InvokeServer() end
                    break
                end
                RunService.RenderStepped:Wait()
            end
        end
    end)
    task.delay(0.1, function() isProcessing = false end)
end

-- --- 4. 核心工作主循環群 ---

task.spawn(function()
    while uiActive do
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local anims = workspace:FindFirstChild("Living") and workspace.Living:FindFirstChild("Animals")
        
        if hrp then
            -- 動物自動砍殺
            if autoKnife and anims then
                local knife = char:FindFirstChild("HuntingKnife") or lp.Backpack:FindFirstChild("HuntingKnife")
                local kRemote = knife and knife:FindFirstChild("Scripts") and knife.Scripts.System:FindFirstChild("Hit")
                if kRemote then
                    for _, a in pairs(anims:GetChildren()) do
                        local root = a:FindFirstChildWhichIsA("BasePart", true)
                        if root and (root.Position - hrp.Position).Magnitude <= harvestRange then
                            for _, part in pairs(a:GetChildren()) do
                                if part.Name:sub(1, 5) == "Limb_" then kRemote:FireServer(part, "LightAttack2", part.CFrame) end
                            end
                            local hum = a:FindFirstChild("Humanoid")
                            if hum then kRemote:FireServer(hum, "LightAttack2", root.CFrame) end
                        end
                    end
                end
            end
            
            -- 動物自動槍擊
            if autoGun and anims and normalBullet then
                local gun = char:FindFirstChild("CrocodileHunter") or char:FindFirstChild("M82")
                local gRemote = gun and gun:FindFirstChild("Scripts") and gun.Scripts.System:FindFirstChild("Hit")
                if gRemote then
                    for _, a in pairs(anims:GetChildren()) do
                        local hum = a:FindFirstChild("Humanoid")
                        local target = a:FindFirstChildWhichIsA("BasePart", true)
                        if hum and hum.Health > 0 and target and (target.Position - hrp.Position).Magnitude <= harvestRange then
                            gRemote:FireServer({
                                DistanceMade = Vector3.zero,
                                StartPosition = hrp.Position,
                                HitMaterial = Enum.Material.Leather,
                                Ray = nil,
                                ShootDirection = (target.Position - hrp.Position).Unit,
                                HitPos = target.Position,
                                RayHit = target,
                                HitPart = hum,
                                Bullet = normalBullet
                            })
                        end
                    end
                end
            end

            -- 玩家殺戮
            if killActive and normalBullet then
                local hitRemote = nil
                local weapon = char:FindFirstChild("CrocodileHunter")
                if weapon then
                    hitRemote = weapon:FindFirstChild("Scripts") and weapon.Scripts:FindFirstChild("System") and weapon.Scripts.System:FindFirstChild("Hit")
                end
                if not hitRemote then
                    for _, v in pairs(char:GetDescendants()) do
                        if v.Name == "Hit" and v:IsA("RemoteEvent") then hitRemote = v; break end
                    end
                end
                if hitRemote then
                    for _, p in pairs(Players:GetPlayers()) do
                        if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                            local targetHrp = p.Character.HumanoidRootPart
                            local targetHum = p.Character:FindFirstChild("Humanoid")
                            local dist = (targetHrp.Position - hrp.Position).Magnitude
                            if targetHum and targetHum.Health > 0 and dist <= killRange then
                                hitRemote:FireServer({
                                    DistanceMade = Vector3.zero,
                                    StartPosition = hrp.Position,
                                    HitMaterial = Enum.Material.SmoothPlastic,
                                    Ray = nil,
                                    ShootDirection = (targetHrp.Position - hrp.Position).Unit,
                                    HitPos = targetHrp.Position,
                                    RayHit = targetHrp,
                                    HitPart = targetHum,
                                    Bullet = normalBullet
                                })
                            end
                        end
                    end
                end
            end

            -- 更新合併 ESP
            UpdateMergedESP(hrp)
        end
        task.wait(0.05)
    end
end)

-- 醫療偵測循環
RunService.Heartbeat:Connect(function()
    if uiActive and autoHealEnabled and not isProcessing then
        local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 and hum.Health < 99 then
            doOverdriveHeal()
        end
    end
end)


-- --- 5. 按鈕點擊交互綁定 ---
knifeBtn.MouseButton1Click:Connect(function() 
    autoKnife = not autoKnife 
    knifeBtn.Text = autoKnife and "自動砍殺：ON" or "自動砍殺：OFF"
    knifeBtn.BackgroundColor3 = autoKnife and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(60, 30, 30) 
end)

gunBtn.MouseButton1Click:Connect(function() 
    autoGun = not autoGun 
    gunBtn.Text = autoGun and "自動連發：ON" or "自動連發：OFF"
    gunBtn.BackgroundColor3 = autoGun and Color3.fromRGB(50, 80, 150) or Color3.fromRGB(30, 40, 60) 
end)

killBtn.MouseButton1Click:Connect(function()
    killActive = not killActive
    killBtn.Text = killActive and "玩家殺戮：ON" or "玩家殺戮：OFF"
    killBtn.BackgroundColor3 = killActive and Color3.fromRGB(200, 0, 0) or Color3.fromRGB(80, 10, 10)
end)

espBtn.MouseButton1Click:Connect(function() 
    espEnabled = not espEnabled 
    espBtn.Text = espEnabled and "全景 ESP：ON" or "全景 ESP：OFF" 
    espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(30, 60, 40) or Color3.fromRGB(60, 40, 40)
    
    -- 關閉時清空畫面標籤
    if not espEnabled then
        for _, e in pairs(animalEspObjects) do if e.Gui then e.Gui.TextLabel.Visible = false end end
        for _, e in pairs(playerEspObjects) do if e.Gui then e.Gui.TextLabel.Visible = false end end
    end
end)

healBtn.MouseButton1Click:Connect(function()
    autoHealEnabled = not autoHealEnabled
    healBtn.Text = autoHealEnabled and "醫療：ON" or "醫療：OFF"
    healBtn.BackgroundColor3 = autoHealEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(120, 0, 0)
end)

fogBtn.MouseButton1Click:Connect(function()
    if fogBtn.Text == "移除霧氣：OFF" then
        fogBtn.Text = "移除霧氣：ON"
        Lighting.FogEnd = 1e6
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then atm.Parent = rs end
    else
        fogBtn.Text = "移除霧氣：OFF"
        Lighting.FogEnd = 1500
        local oldAtm = rs:FindFirstChildOfClass("Atmosphere")
        if oldAtm then oldAtm.Parent = Lighting end
    end
end)

rangeInput.FocusLost:Connect(function() 
    harvestRange = tonumber(rangeInput.Text) or 100 
    rangeInput.Text = tostring(harvestRange)
end)
