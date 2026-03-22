local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Player = Players.LocalPlayer

-- 遠端路徑簡化
local Events = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Player")
local EquipRemote = Events:WaitForChild("Equip")
local SetValueRemote = Events:WaitForChild("SetItemObjValue")

local autoHealEnabled = false
local isProcessing = false

-- --- UI 建立 ---
local screenGui = Instance.new("ScreenGui", Player:WaitForChild("PlayerGui"))
screenGui.Name = "FastHeal_V7"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 200, 0, 110)
frame.Position = UDim2.new(0.1, 0, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame)

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

local healBtn = createBtn("自動治療: OFF", UDim2.new(0, 10, 0, 10), Color3.fromRGB(150, 0, 0))
local fogBtn = createBtn("NoFog: OFF", UDim2.new(0, 10, 0, 60), Color3.fromRGB(60, 60, 60))

-- --- 核心：完全模仿你提供的原始代碼 ---
local function doHeal()
    if isProcessing then return end
    isProcessing = true

    -- 1. 補充 (使用你提供的第 1 格到熱鍵 5 的邏輯)
    local hb5 = Player.HotBar:FindFirstChild("5")
    local inv1 = Player.Inventory:FindFirstChild("1")
    
    if hb5 and inv1 then
        -- 這裡直接 unpack 確保格式正確
        local stockArgs = { hb5, inv1 }
        SetValueRemote:InvokeServer(unpack(stockArgs))
    end

    -- 2. 裝備
    if hb5 then
        EquipRemote:InvokeServer(hb5)
    end

    -- 3. 治療 (直接調用你提供的精確路徑，不加 WaitForChild 減速)
    task.spawn(function()
        local char = Player.Character
        if char and char:FindFirstChild("Medkit") then
            local heal = char.Medkit.Scripts.System.Binds.Heal.Heal
            heal:InvokeServer()
        end
    end)

    -- 4. 再次裝備 (快速刷回)
    task.wait(0.05)
    if hb5 then
        EquipRemote:InvokeServer(hb5)
    end

    task.wait(0.2) -- 整體冷卻
    isProcessing = false
end

-- --- 極速偵測循環 ---
task.spawn(function()
    while true do
        -- 降低等待時間到 0.05，達成幾乎瞬發偵測
        task.wait(0.05)
        if autoHealEnabled and not isProcessing then
            local char = Player.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 and hum.Health < 99 then
                doHeal()
            end
        end
    end
end)

-- --- 按鈕功能 ---
healBtn.MouseButton1Click:Connect(function()
    autoHealEnabled = not autoHealEnabled
    healBtn.Text = autoHealEnabled and "自動治療: ON" or "自動治療: OFF"
    healBtn.BackgroundColor3 = autoHealEnabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
end)

fogBtn.MouseButton1Click:Connect(function()
    if fogBtn.Text == "NoFog: OFF" then
        fogBtn.Text = "NoFog: ON"
        Lighting.FogEnd = 100000
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then atm.Parent = ReplicatedStorage end
    else
        fogBtn.Text = "NoFog: OFF"
        Lighting.FogEnd = 1500
        local oldAtm = ReplicatedStorage:FindFirstChildOfClass("Atmosphere")
        if oldAtm then oldAtm.Parent = Lighting end
    end
end)

