local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

-- 遠端路徑預載 (加速訪問)
local Events = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Player")
local EquipRemote = Events:WaitForChild("Equip")
local SetValueRemote = Events:WaitForChild("SetItemObjValue")

local autoHealEnabled = false
local isProcessing = false

-- --- UI 建立與現代拖動 (修復版) ---
local screenGui = Instance.new("ScreenGui", Player:WaitForChild("PlayerGui"))
screenGui.Name = "Overdrive_V10"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 200, 0, 110)
frame.Position = UDim2.new(0.1, 0, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
frame.Active = true
Instance.new("UICorner", frame)

-- 拖動邏輯
local dragging, dragInput, dragStart, startPos
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

local healBtn = createBtn("0.02s 極限醫療: OFF", UDim2.new(0, 10, 0, 10), Color3.fromRGB(100, 0, 0))
local fogBtn = createBtn("NoFog: OFF", UDim2.new(0, 10, 0, 60), Color3.fromRGB(40, 40, 40))

-- --- 0.02s 核心邏輯 ---
local function instantHeal()
    isProcessing = true
    
    local hb5 = Player.HotBar:FindFirstChild("5")
    local inv1 = Player.Inventory:FindFirstChild("1")
    local char = Player.Character

    -- 1. 同步噴射：補充與裝備 (不使用 task.spawn 以免產生微小延遲排隊)
    if hb5 and inv1 then SetValueRemote:InvokeServer(hb5, inv1) end
    if hb5 then EquipRemote:InvokeServer(hb5) end

    -- 2. 暴力偵測治療：在下一個微幀內連續噴射 5 次
    -- 這裡使用 RenderStepped 的連發來抵消伺服器同步延遲
    local burstCount = 0
    local burstConn
    burstConn = RunService.RenderStepped:Connect(function()
        burstCount = burstCount + 1
        local medkit = char and char:FindFirstChild("Medkit")
        if medkit then
            local heal = medkit.Scripts.System.Binds.Heal.Heal
            heal:InvokeServer()
            burstConn:Disconnect() -- 命中後立刻停止噴射
        end
        if burstCount > 10 then burstConn:Disconnect() end -- 超過 10 幀未命中則放棄
    end)

    -- 0.08 秒後解鎖，允許極速連續觸發
    task.delay(0.08, function() isProcessing = false end)
end

-- --- 每幀偵測 (最高優先級) ---
RunService.RenderStepped:Connect(function()
    if autoHealEnabled and not isProcessing then
        local hum = Player.Character and Player.Character:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 and hum.Health < 99 then
            instantHeal()
        end
    end
end)

-- --- 按鈕交互 ---
healBtn.MouseButton1Click:Connect(function()
    autoHealEnabled = not autoHealEnabled
    healBtn.Text = autoHealEnabled and "0.02s 極限醫療: ON" or "0.02s 極限醫療: OFF"
    healBtn.BackgroundColor3 = autoHealEnabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 0, 0)
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
