local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- --- 建立私有音軌 ---
local musicFolder = player:FindFirstChild("PrivateMusicSystem") or Instance.new("Folder", player)
musicFolder.Name = "PrivateMusicSystem"

local sound = musicFolder:FindFirstChild("PrivateTrack") or Instance.new("Sound", musicFolder)
sound.Name = "PrivateTrack"
sound.Volume = 0.5
sound.Looped = true

-- --- UI 建立 (延用你的設定並優化) ---
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PrivatePlayer_V4"
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = player:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 280, 0, 180) -- 高度稍微增加
main.Position = UDim2.new(0.05, 0, 0.7, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
main.BorderSizePixel = 0; main.Active = true; main.Draggable = true; main.Parent = screenGui
Instance.new("UICorner", main)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
title.Text = " 🎧 私人播放器 (授權偵測版)"
title.TextColor3 = Color3.new(1, 1, 1); title.Font = Enum.Font.SourceSansBold; title.Parent = main
Instance.new("UICorner", title)

local idInput = Instance.new("TextBox")
idInput.Size = UDim2.new(0.9, 0, 0, 30); idInput.Position = UDim2.new(0.05, 0, 0.22, 0)
idInput.PlaceholderText = "貼上 ID..."; idInput.Text = ""
idInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40); idInput.TextColor3 = Color3.new(0, 255, 150); idInput.Parent = main

-- 狀態顯示標籤 (新加入)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0, 20); statusLabel.Position = UDim2.new(0.05, 0, 0.4, 0)
statusLabel.Text = "等待輸入..."; statusLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)
statusLabel.BackgroundTransparency = 1; statusLabel.TextSize = 12; statusLabel.Parent = main

local playBtn = Instance.new("TextButton")
playBtn.Size = UDim2.new(0.43, 0, 0, 35); playBtn.Position = UDim2.new(0.05, 0, 0.55, 0)
playBtn.Text = "▶ 播放"; playBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0); playBtn.TextColor3 = Color3.new(1, 1, 1); playBtn.Parent = main
Instance.new("UICorner", playBtn)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0.43, 0, 0, 35); stopBtn.Position = UDim2.new(0.52, 0, 0.55, 0)
stopBtn.Text = "■ 停止"; stopBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 0); stopBtn.TextColor3 = Color3.new(1, 1, 1); stopBtn.Parent = main
Instance.new("UICorner", stopBtn)

-- --- 核心播放邏輯 ---

local function checkAndPlay()
    local id = idInput.Text:match("%d+")
    if not id then 
        statusLabel.Text = "❌ 無效的 ID"
        return 
    end

    statusLabel.Text = "🔍 正在檢查權限..."
    statusLabel.TextColor3 = Color3.new(1, 1, 1)

    -- 檢查資產資訊
    task.spawn(function()
        local success, info = pcall(function()
            return MarketplaceService:GetProductInfo(tonumber(id))
        end)

        if success and info then
            sound:Stop()
            sound.SoundId = "rbxassetid://" .. id
            sound:Play()

            -- 檢查是否真的發出聲音 (處理私人音訊無法加載的情況)
            task.wait(0.5)
            if sound.IsLoaded or sound.TimeLength > 0 then
                statusLabel.Text = "✅ 正在播放: " .. info.Name
                statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            else
                statusLabel.Text = "🔒 失敗: 此音訊為私人或不支援"
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
        else
            statusLabel.Text = "⚠️ 無法讀取資訊 (可能是私人 ID)"
            statusLabel.TextColor3 = Color3.fromRGB(255, 150, 0)
            -- 嘗試硬切播放
            sound.SoundId = "rbxassetid://" .. id
            sound:Play()
        end
    end)
end

playBtn.MouseButton1Click:Connect(checkAndPlay)
stopBtn.MouseButton1Click:Connect(function() sound:Stop(); statusLabel.Text = "已停止" end)

-- 音量與循環按鈕邏輯 (保持不變)
-- ... (此處省略你原本的 VolUp/VolDown/Loop 邏輯以保持精簡)
