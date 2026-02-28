local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- --- 建立私有音軌 ---
local musicFolder = player:FindFirstChild("PrivateMusicSystem") or Instance.new("Folder", player)
musicFolder.Name = "PrivateMusicSystem"

local sound = musicFolder:FindFirstChild("PrivateTrack") or Instance.new("Sound", musicFolder)
sound.Name = "PrivateTrack"
sound.Volume = 0.5
sound.Looped = true

-- --- UI 建立 ---
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PrivatePlayer_V3"
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = player:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 280, 0, 160)
main.Position = UDim2.new(0.05, 0, 0.7, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
main.BorderSizePixel = 2
main.BorderColor3 = Color3.fromRGB(0, 200, 255)
main.Active = true
main.Draggable = true
main.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 25)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
title.Text = " 🎧 個人音樂播放器 (私人)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 14
title.Parent = main

-- ID 輸入框
local idInput = Instance.new("TextBox")
idInput.Size = UDim2.new(0.9, 0, 0, 30)
idInput.Position = UDim2.new(0.05, 0, 0.25, 0)
idInput.PlaceholderText = "在此貼上音樂 ID..."
idInput.Text = ""
idInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
idInput.TextColor3 = Color3.new(0, 255, 150)
idInput.Font = Enum.Font.Code
idInput.Parent = main

-- 播放按鈕
local playBtn = Instance.new("TextButton")
playBtn.Size = UDim2.new(0.43, 0, 0, 35)
playBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
playBtn.Text = "▶ PLAY"
playBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
playBtn.TextColor3 = Color3.new(1, 1, 1)
playBtn.Font = Enum.Font.SourceSansBold
playBtn.Parent = main

-- 停止按鈕
local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0.43, 0, 0, 35)
stopBtn.Position = UDim2.new(0.52, 0, 0.5, 0)
stopBtn.Text = "■ STOP"
stopBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
stopBtn.TextColor3 = Color3.new(1, 1, 1)
stopBtn.Font = Enum.Font.SourceSansBold
stopBtn.Parent = main

-- 音量控制
local volLabel = Instance.new("TextLabel")
volLabel.Size = UDim2.new(0.3, 0, 0, 20)
volLabel.Position = UDim2.new(0.05, 0, 0.8, 0)
volLabel.Text = "音量: 50%"
volLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
volLabel.BackgroundTransparency = 1
volLabel.TextSize = 12
volLabel.Parent = main

local volUp = Instance.new("TextButton")
volUp.Size = UDim2.new(0, 20, 0, 20); volUp.Position = UDim2.new(0.35, 0, 0.8, 0)
volUp.Text = "+"; volUp.BackgroundColor3 = Color3.fromRGB(60, 60, 60); volUp.TextColor3 = Color3.new(1, 1, 1); volUp.Parent = main

local volDown = Instance.new("TextButton")
volDown.Size = UDim2.new(0, 20, 0, 20); volDown.Position = UDim2.new(0.45, 0, 0.8, 0)
volDown.Text = "-"; volDown.BackgroundColor3 = Color3.fromRGB(60, 60, 60); volDown.TextColor3 = Color3.new(1, 1, 1); volDown.Parent = main

-- 循環開關
local loopBtn = Instance.new("TextButton")
loopBtn.Size = UDim2.new(0, 80, 0, 20)
loopBtn.Position = UDim2.new(0.65, 0, 0.8, 0)
loopBtn.Text = "循環: 開"
loopBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 150)
loopBtn.TextColor3 = Color3.new(1, 1, 1)
loopBtn.TextSize = 12
loopBtn.Parent = main

-- --- 功能邏輯 ---

playBtn.MouseButton1Click:Connect(function()
    local id = idInput.Text:match("%d+")
    if id then
        sound:Stop()
        sound.SoundId = "rbxassetid://" .. id
        sound:Play()
        print("正在播放私人音樂 ID: " .. id)
    end
end)

stopBtn.MouseButton1Click:Connect(function()
    sound:Stop()
end)

volUp.MouseButton1Click:Connect(function()
    sound.Volume = math.min(sound.Volume + 0.1, 2)
    volLabel.Text = "音量: " .. math.floor(sound.Volume * 100) .. "%"
end)

volDown.MouseButton1Click:Connect(function()
    sound.Volume = math.max(sound.Volume - 0.1, 0)
    volLabel.Text = "音量: " .. math.floor(sound.Volume * 100) .. "%"
end)

loopBtn.MouseButton1Click:Connect(function()
    sound.Looped = not sound.Looped
    loopBtn.Text = "循環: " .. (sound.Looped and "開" or "關")
    loopBtn.BackgroundColor3 = sound.Looped and Color3.fromRGB(0, 100, 150) or Color3.fromRGB(80, 80, 80)
end)

-- 關閉 UI 功能
local close = Instance.new("TextButton", main)
close.Size = UDim2.new(0, 20, 0, 20); close.Position = UDim2.new(1, -22, 0, 2)
close.Text = "×"; close.BackgroundColor3 = Color3.new(0.6, 0, 0); close.TextColor3 = Color3.new(1, 1, 1)
close.MouseButton1Click:Connect(function() screenGui:Destroy() end)

