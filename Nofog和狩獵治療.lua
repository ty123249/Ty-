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

-- --- UI 建立與修復拖動 ---
local screenGui = Instance.new("ScreenGui", Player:WaitForChild("PlayerGui"))
screenGui.Name = "Overdrive_Fixed_V9"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 200, 0, 110)
frame.Position = UDim2.new(0.1, 0, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BorderSizePixel = 0
frame.Active = true -- 必須開啟才能接收輸入
Instance.new("UICorner", frame)

-- --- 現代拖動邏輯 (取代失效的 .Draggable) ---
local dragging, dragInput, dragStart, startPos
local function update(input)
	local delta = input.Position - dragStart
	frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

frame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

frame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		update(input)
	end
end)

-- --- 按鈕創建函數 ---
local function createBtn(text, pos, color)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(0, 180, 0, 40)
    b.Position = pos
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.BorderSizePixel = 0
    Instance.new("UICorner", b)
    return b
end

local healBtn = createBtn("極限醫療: OFF", UDim2.new(0, 10, 0, 10), Color3.fromRGB(120, 0, 0))
local fogBtn = createBtn("NoFog: OFF", UDim2.new(0, 10, 0, 60), Color3.fromRGB(50, 50, 50))

-- --- 極速治療核心 ---
local function doOverdriveHeal()
    isProcessing = true
    
    local hb5 = Player.HotBar:FindFirstChild("5")
    local inv1 = Player.Inventory:FindFirstChild("1")
    local char = Player.Character

    -- 並行噴射封包 (0.05s 內完成)
    task.spawn(function()
        if hb5 and inv1 then SetValueRemote:InvokeServer(hb5, inv1) end
    end)

    task.spawn(function()
        if hb5 then EquipRemote:InvokeServer(hb5) end
    end)

    task.spawn(function()
        if char then
            -- 連續噴射 3 次治療請求，確保在裝備成功的瞬間命中
            for i = 1, 3 do
                local medkit = char:FindFirstChild("Medkit")
                if medkit then
                    local heal = medkit.Scripts.System.Binds.Heal.Heal
                    heal:InvokeServer()
                    break
                end
                RunService.RenderStepped:Wait() -- 等待極短的渲染幀
            end
        end
    end)

    task.delay(0.1, function() isProcessing = false end)
end

-- --- 偵測循環 ---
RunService.Heartbeat:Connect(function()
    if autoHealEnabled and not isProcessing then
        local hum = Player.Character and Player.Character:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 and hum.Health < 99 then
            doOverdriveHeal()
        end
    end
end)

-- --- 按鈕交互 ---
healBtn.MouseButton1Click:Connect(function()
    autoHealEnabled = not autoHealEnabled
    healBtn.Text = autoHealEnabled and "極限醫療: ON" or "極限醫療: OFF"
    healBtn.BackgroundColor3 = autoHealEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(120, 0, 0)
end)

fogBtn.MouseButton1Click:Connect(function()
    if fogBtn.Text == "NoFog: OFF" then
        fogBtn.Text = "NoFog: ON"
        Lighting.FogEnd = 1e6
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then atm.Parent = ReplicatedStorage end
    else
        fogBtn.Text = "NoFog: OFF"
        Lighting.FogEnd = 1500
        local oldAtm = ReplicatedStorage:FindFirstChildOfClass("Atmosphere")
        if oldAtm then oldAtm.Parent = Lighting end
    end
end)
