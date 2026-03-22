local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

-- 遠端路徑預載
local Events = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Player")
local EquipRemote = Events:WaitForChild("Equip")
local SetValueRemote = Events:WaitForChild("SetItemObjValue")

local autoHealEnabled = false
local isProcessing = false
local lastHealth = 100 -- 用於對比血量差

-- --- UI 建立與現代拖動 ---
local screenGui = Instance.new("ScreenGui", Player:WaitForChild("PlayerGui"))
screenGui.Name = "Quantum_Heal_V11"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 200, 0, 110)
frame.Position = UDim2.new(0.1, 0, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
frame.Active = true
Instance.new("UICorner", frame)

-- 拖動修復
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = frame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

local function createBtn(text, pos, color)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(0, 180, 0, 40)
    b.Position = pos
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b)
    return b
end

local healBtn = createBtn("量子偵測醫療: OFF", UDim2.new(0, 10, 0, 10), Color3.fromRGB(80, 0, 0))
local fogBtn = createBtn("NoFog: OFF", UDim2.new(0, 10, 0, 60), Color3.fromRGB(30, 30, 30))

-- --- 核心：極速醫療執行 ---
local function quantumHeal()
    isProcessing = true
    
    local hb5 = Player.HotBar:FindFirstChild("5")
    local inv1 = Player.Inventory:FindFirstChild("1")
    local char = Player.Character

    -- 【瞬發發包】補充與裝備直接連發，不加任何 task.wait
    if hb5 and inv1 then SetValueRemote:InvokeServer(hb5, inv1) end
    if hb5 then EquipRemote:InvokeServer(hb5) end

    -- 【瞬發連彈】在接下來的 0.05 秒內，每幀暴力嘗試治療
    local connection
    local t = 0
    connection = RunService.RenderStepped:Connect(function(dt)
        t = t + dt
        local medkit = char and char:FindFirstChild("Medkit")
        if medkit then
            local heal = medkit.Scripts.System.Binds.Heal.Heal
            heal:InvokeServer()
            connection:Disconnect() -- 成功則停
        end
        if t > 0.1 then connection:Disconnect() end -- 超時停
    end)

    task.delay(0.05, function() isProcessing = false end) -- 極速冷卻解除
end

-- --- 偵測瓶頸突破：Stepped 物理幀監控 ---
-- Stepped 比 RenderStepped 更接近物理數值更新點
RunService.Stepped:Connect(function()
    if not autoHealEnabled or isProcessing then return end
    
    local char = Player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    
    if hum then
        local currentHealth = hum.Health
        -- 核心邏輯：如果血量小於 99 或 血量正在下降（被攻擊瞬間）
        if currentHealth < 99 or currentHealth < lastHealth then
            quantumHeal()
        end
        lastHealth = currentHealth
    end
end)

-- --- UI 按鈕控制 ---
healBtn.MouseButton1Click:Connect(function()
    autoHealEnabled = not autoHealEnabled
    healBtn.Text = autoHealEnabled and "量子偵測: ON" or "量子偵測: OFF"
    healBtn.BackgroundColor3 = autoHealEnabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(80, 0, 0)
end)

fogBtn.MouseButton1Click:Connect(function()
    if fogBtn.Text == "NoFog: OFF" then
        fogBtn.Text = "NoFog: ON"; Lighting.FogEnd = 1e6
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then atm.Parent = ReplicatedStorage end
    else
        fogBtn.Text = "NoFog: OFF"; Lighting.FogEnd = 1500
        local oldAtm = ReplicatedStorage:FindFirstChildOfClass("Atmosphere")
        if oldAtm then oldAtm.Parent = Lighting end
    end
end)
