local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")

local espEnabled = true
local espObjects = {}
local uiActive = true
local lastRefresh = tick()
local myName = "hk_c002" -- 排除你自己

-- --- 1. UI 構建 ---
local screenGui = Instance.new("ScreenGui", lp:WaitForChild("PlayerGui"))
screenGui.Name = "Player_Model_Tracker"
screenGui.ResetOnSpawn = false

local main = Instance.new("Frame", screenGui)
main.Size = UDim2.new(0, 180, 0, 100)
main.Position = UDim2.new(0.05, 0, 0.1, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
main.BorderSizePixel = 0
main.Active = true
Instance.new("UICorner", main)

-- 標題列
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "PLAYER MODEL ESP"
title.TextColor3 = Color3.fromRGB(255, 200, 50)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 14
Instance.new("UICorner", title)

-- 拖動
local dragging, dragStart, startPos
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = main.Position end
end)
uis.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
uis.InputEnded:Connect(function(input) dragging = false end)

local toggleBtn = Instance.new("TextButton", main)
toggleBtn.Size = UDim2.new(0.9, 0, 0, 40)
toggleBtn.Position = UDim2.new(0.05, 0, 0.45, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
toggleBtn.Text = "ESP: ON"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.SourceSansBold
Instance.new("UICorner", toggleBtn)

-- --- 2. ESP 核心邏輯 ---
local function UpdatePlayerESP()
    -- 每 5 秒強制重新加載
    if tick() - lastRefresh >= 5 then
        for _, e in pairs(espObjects) do if e.Gui then e.Gui:Destroy() end end
        espObjects = {}
        lastRefresh = tick()
    end

    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    
    -- 遍歷 Workspace 尋找可能是玩家的 Model
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Model") and v.Name ~= myName and Players:FindFirstChild(v.Name) then
            if not espObjects[v] then
                local bg = Instance.new("BillboardGui", v)
                bg.AlwaysOnTop = true
                bg.Size = UDim2.new(0, 100, 0, 20)
                bg.StudsOffset = Vector3.new(0, 4, 0)
                
                local lb = Instance.new("TextLabel", bg)
                lb.Size = UDim2.new(1, 0, 1, 0)
                lb.BackgroundTransparency = 1
                lb.TextColor3 = Color3.new(1, 0.3, 0.3) -- 玩家用紅色區分
                lb.Font = Enum.Font.SourceSansBold
                lb.TextSize = 13
                lb.TextStrokeTransparency = 0
                
                espObjects[v] = {Label = lb, Gui = bg}
            end
            
            local targetPart = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChildWhichIsA("BasePart")
            if targetPart and hrp then
                local dist = math.floor((hrp.Position - targetPart.Position).Magnitude)
                espObjects[v].Label.Text = "[PLAYER] " .. v.Name .. "\n" .. dist .. "m"
                espObjects[v].Label.Visible = espEnabled
            end
        end
    end

    -- 清理
    for o, e in pairs(espObjects) do 
        if not o.Parent then 
            if e.Gui then e.Gui:Destroy() end 
            espObjects[o] = nil 
        end 
    end
end

-- --- 3. 運行 ---
toggleBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    toggleBtn.Text = espEnabled and "ESP: ON" or "ESP: OFF"
    toggleBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(40, 100, 60) or Color3.fromRGB(60, 40, 40)
end)

task.spawn(function()
    while uiActive do
        UpdatePlayerESP()
        task.wait(0.2)
    end
end)
