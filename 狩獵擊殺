local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local rs = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")

local killActive = false
local uiActive = true
local killRange = 300 -- 槍械預設最大距離

-- --- 1. UI 構建 ---
local screenGui = Instance.new("ScreenGui", lp:WaitForChild("PlayerGui"))
screenGui.Name = "Executioner_V5"
screenGui.ResetOnSpawn = false

local main = Instance.new("Frame", screenGui)
main.Size = UDim2.new(0, 180, 0, 120)
main.Position = UDim2.new(0.85, 0, 0.5, 0)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
main.BorderSizePixel = 0
main.Active = true
Instance.new("UICorner", main)

-- 拖動邏輯
local dragging, dragStart, startPos
main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = main.Position end
end)
uis.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
uis.InputEnded:Connect(function(input) dragging = false end)

-- 開關按鈕
local toggleBtn = Instance.new("TextButton", main)
toggleBtn.Size = UDim2.new(0.9, 0, 0, 50)
toggleBtn.Position = UDim2.new(0.05, 0, 0.1, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
toggleBtn.Text = "殺戮: OFF"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 18
Instance.new("UICorner", toggleBtn)

-- 關閉 UI 按鈕
local closeBtn = Instance.new("TextButton", main)
closeBtn.Size = UDim2.new(0.9, 0, 0, 30)
closeBtn.Position = UDim2.new(0.05, 0, 0.6, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
closeBtn.Text = "完全關閉腳本"
closeBtn.TextColor3 = Color3.new(0.7, 0.7, 0.7)
closeBtn.Font = Enum.Font.SourceSans
closeBtn.TextSize = 12
Instance.new("UICorner", closeBtn)

-- --- 2. 邏輯實作 ---

-- 點擊切換
toggleBtn.MouseButton1Click:Connect(function()
    killActive = not killActive
    toggleBtn.Text = killActive and "殺戮: ON" or "殺戮: OFF"
    toggleBtn.BackgroundColor3 = killActive and Color3.fromRGB(200, 0, 0) or Color3.fromRGB(50, 0, 0)
end)

-- 點擊關閉
closeBtn.MouseButton1Click:Connect(function()
    uiActive = false
    screenGui:Destroy()
end)

-- 核心殺戮循環
task.spawn(function()
    while uiActive do
        if killActive then
            -- 暴力搜尋 CrocodileHunter 的 Hit 遠端 (無視非原生物品欄)
            local hitRemote = nil
            local weapon = lp.Character:FindFirstChild("CrocodileHunter")
            if weapon then
                hitRemote = weapon:FindFirstChild("Scripts") and weapon.Scripts:FindFirstChild("System") and weapon.Scripts.System:FindFirstChild("Hit")
            end
            
            -- 如果沒找到，擴大範圍搜尋角色內所有 Hit 遠端
            if not hitRemote then
                for _, v in pairs(lp.Character:GetDescendants()) do
                    if v.Name == "Hit" and v:IsA("RemoteEvent") then hitRemote = v; break end
                end
            end

            if hitRemote and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                local myPos = lp.Character.HumanoidRootPart.Position
                
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local targetHrp = p.Character.HumanoidRootPart
                        local targetHum = p.Character:FindFirstChild("Humanoid")
                        
                        local dist = (targetHrp.Position - myPos).Magnitude
                        if targetHum and targetHum.Health > 0 and dist <= killRange then
                            -- 使用你分析出的暴力參數 (第一段：打人專用)
                            local args = {
                                {
                                    DistanceMade = Vector3.new(0,0,0), -- 暴力 zero 距離
                                    StartPosition = myPos,
                                    HitMaterial = Enum.Material.SmoothPlastic,
                                    Ray = nil,
                                    ShootDirection = (targetHrp.Position - myPos).Unit,
                                    HitPos = targetHrp.Position,
                                    RayHit = targetHrp,
                                    HitPart = targetHum, -- 關鍵：直接指向 Humanoid 造成扣血
                                    Bullet = rs:WaitForChild("Stuff"):WaitForChild("Bullets"):WaitForChild("NormalBullet")
                                }
                            }
                            hitRemote:FireServer(unpack(args))
                        end
                    end
                end
            end
        end
        task.wait(0.05) -- 極速掃描發送
    end
end)
