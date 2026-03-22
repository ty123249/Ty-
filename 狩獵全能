local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local rs = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")

local autoKnife = false
local autoGun = false
local espEnabled = true
local harvestRange = 35
local espObjects = {}
local uiActive = true
local isMinimized = false

-- --- 1. UI 系統框架 ---
local screenGui = Instance.new("ScreenGui", lp:WaitForChild("PlayerGui"))
screenGui.Name = "Harvester_V32_8_Stable"
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 210, 0, 310)
mainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.Active = true
mainFrame.ClipsDescendants = true
Instance.new("UICorner", mainFrame)

-- 拖動邏輯
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
contentFrame.Size = UDim2.new(1, 0, 1, -35)
contentFrame.Position = UDim2.new(0, 0, 0, 35)
contentFrame.BackgroundTransparency = 1

-- 最小化與關閉按鈕
local minBtn = Instance.new("TextButton", mainFrame)
minBtn.Size = UDim2.new(0, 25, 0, 25); minBtn.Position = UDim2.new(1, -60, 0, 5); minBtn.Text = "-"; minBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60); minBtn.TextColor3 = Color3.new(1, 1, 1); minBtn.ZIndex = 10
Instance.new("UICorner", minBtn)

local closeBtn = Instance.new("TextButton", mainFrame)
closeBtn.Size = UDim2.new(0, 25, 0, 25); closeBtn.Position = UDim2.new(1, -30, 0, 5); closeBtn.Text = "X"; closeBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40); closeBtn.TextColor3 = Color3.new(1, 1, 1); closeBtn.ZIndex = 10
Instance.new("UICorner", closeBtn)

closeBtn.MouseButton1Click:Connect(function() uiActive = false; screenGui:Destroy() end)
minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    ts:Create(mainFrame, TweenInfo.new(0.3), {Size = isMinimized and UDim2.new(0, 210, 0, 35) or UDim2.new(0, 210, 0, 310)}):Play()
    contentFrame.Visible = not isMinimized
    minBtn.Text = isMinimized and "+" or "-"
end)

-- --- 功能按鈕 ---
local function createBtn(text, pos, color)
    local btn = Instance.new("TextButton", contentFrame); btn.Size = UDim2.new(0.9, 0, 0, 35); btn.Position = pos; btn.BackgroundColor3 = color; btn.TextColor3 = Color3.new(1, 1, 1); btn.Text = text; Instance.new("UICorner", btn); return btn
end

local knifeBtn = createBtn("自動砍殺 (Light)：OFF", UDim2.new(0.05, 0, 0.05, 0), Color3.fromRGB(60, 30, 30))
local gunBtn = createBtn("自動連發 (槍)：OFF", UDim2.new(0.05, 0, 0.2, 0), Color3.fromRGB(30, 40, 60))
local espBtn = createBtn("全景 ESP：ON", UDim2.new(0.05, 0, 0.35, 0), Color3.fromRGB(30, 60, 40))
local skinBtn = createBtn("快速剝皮 (刀)", UDim2.new(0.05, 0, 0.5, 0), Color3.fromRGB(80, 40, 90))

local rangeInput = Instance.new("TextBox", contentFrame); rangeInput.Size = UDim2.new(0.45, 0, 0, 25); rangeInput.Position = UDim2.new(0.5, 0, 0.65, 0); rangeInput.BackgroundColor3 = Color3.fromRGB(40, 40, 45); rangeInput.Text = "35"; rangeInput.TextColor3 = Color3.new(0, 1, 1); Instance.new("UICorner", rangeInput)
local statusLabel = Instance.new("TextLabel", contentFrame); statusLabel.Size = UDim2.new(1, 0, 0, 30); statusLabel.Position = UDim2.new(0, 0, 0.8, 0); statusLabel.Text = "穩定版就緒"; statusLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7); statusLabel.BackgroundTransparency = 1

-- --- 2. ESP 邏輯 ---
local function UpdateESP()
    local anims = workspace:FindFirstChild("Living") and workspace.Living:FindFirstChild("Animals")
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not anims or not hrp then return end
    for _, v in pairs(anims:GetChildren()) do
        if not espObjects[v] then
            local bg = Instance.new("BillboardGui", v); bg.AlwaysOnTop = true; bg.Size = UDim2.new(0, 80, 0, 20); bg.StudsOffset = Vector3.new(0, 3, 0)
            local lb = Instance.new("TextLabel", bg); lb.Size = UDim2.new(1, 0, 1, 0); lb.BackgroundTransparency = 1; lb.Font = Enum.Font.SourceSansBold; lb.TextSize = 11; lb.TextStrokeTransparency = 0.5; espObjects[v] = {Label = lb, Gui = bg}
        end
        local root = v:FindFirstChildWhichIsA("BasePart", true)
        if root then
            local dist = (hrp.Position - root.Position).Magnitude
            espObjects[v].Label.Text = v.Name .. "\n" .. math.floor(dist) .. "m"
            espObjects[v].Label.TextColor3 = (dist <= harvestRange) and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
            espObjects[v].Label.Visible = espEnabled
        end
    end
    for o, e in pairs(espObjects) do if not o.Parent then if e.Gui then e.Gui:Destroy() end espObjects[o] = nil end end
end

-- --- 3. 核心循環 ---
task.spawn(function()
    while uiActive do
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local anims = workspace:FindFirstChild("Living") and workspace.Living:FindFirstChild("Animals")
        
        if hrp and anims then
            -- 刀的邏輯：改回 LightAttack2
            if autoKnife then
                local knife = char:FindFirstChild("HuntingKnife") or lp.Backpack:FindFirstChild("HuntingKnife")
                local kRemote = knife and knife:FindFirstChild("Scripts") and knife.Scripts.System:FindFirstChild("Hit")
                if kRemote then
                    for _, a in pairs(anims:GetChildren()) do
                        local root = a:FindFirstChildWhichIsA("BasePart", true)
                        if root and (root.Position - hrp.Position).Magnitude <= harvestRange then
                            for _, part in pairs(a:GetChildren()) do
                                if part.Name:sub(1, 5) == "Limb_" then 
                                    kRemote:FireServer(part, "LightAttack2", part.CFrame) 
                                end
                            end
                            local hum = a:FindFirstChild("Humanoid")
                            if hum then kRemote:FireServer(hum, "LightAttack2", root.CFrame) end
                        end
                    end
                end
            end
            
            -- 槍的邏輯：保持暴力 Table
            if autoGun then
                local gun = char:FindFirstChild("CrocodileHunter") or char:FindFirstChild("NightFall")
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
                                Bullet = rs:WaitForChild("Stuff"):WaitForChild("Bullets"):WaitForChild("NormalBullet")
                            })
                        end
                    end
                end
            end
        end
        UpdateESP()
        task.wait(0.1)
    end
end)

knifeBtn.MouseButton1Click:Connect(function() autoKnife = not autoKnife; knifeBtn.Text = autoKnife and "自動砍殺：ON" or "自動砍殺：OFF"; knifeBtn.BackgroundColor3 = autoKnife and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(60, 30, 30) end)
gunBtn.MouseButton1Click:Connect(function() autoGun = not autoGun; gunBtn.Text = autoGun and "自動連發：ON" or "自動連發：OFF"; gunBtn.BackgroundColor3 = autoGun and Color3.fromRGB(50, 80, 150) or Color3.fromRGB(30, 40, 60) end)
espBtn.MouseButton1Click:Connect(function() espEnabled = not espEnabled; espBtn.Text = espEnabled and "全景 ESP：ON" or "全景 ESP：OFF" end)
rangeInput.FocusLost:Connect(function() harvestRange = tonumber(rangeInput.Text) or 35 end)

skinBtn.MouseButton1Click:Connect(function()
    local knife = lp.Character:FindFirstChild("HuntingKnife") or lp.Backpack:FindFirstChild("HuntingKnife")
    local sRemote = knife and knife.Scripts.System:FindFirstChild("Skin")
    if sRemote then
        for _, a in pairs(workspace.Living.Animals:GetChildren()) do
            local torso = a:FindFirstChild("Model") and a.Model:FindFirstChild("Torso") and a.Model.Torso:FindFirstChild("Part")
            if torso and (torso.Position - lp.Character.HumanoidRootPart.Position).Magnitude <= harvestRange then
                statusLabel.Text = "✨ 剝皮中..."; for i = 1, 10 do sRemote:FireServer(a, torso, torso.CFrame); task.wait(0.05) end
                statusLabel.Text = "✅ DONE"; return
            end
        end
    end
end)
