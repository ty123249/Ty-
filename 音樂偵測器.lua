local MarketplaceService = game:GetService("MarketplaceService")
local CoreGui = game:GetService("CoreGui")
local player = game:GetService("Players").LocalPlayer

-- --- UI 建立 ---
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Music_History_Privacy_Tracker"
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = player:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 350, 0, 400) -- 稍微加寬一點點
main.Position = UDim2.new(0.65, 0, 0.2, 0)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
main.BorderSizePixel = 0
main.Active = true; main.Draggable = true; main.Parent = screenGui
Instance.new("UICorner", main)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
title.Text = "📜 音樂偵測歷史 (含權限檢查)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold; title.TextSize = 16; title.Parent = main
Instance.new("UICorner", title)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(0.94, 0, 0.85, 0)
scroll.Position = UDim2.new(0.03, 0, 0.12, 0)
scroll.BackgroundTransparency = 1
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 4; scroll.Parent = main

local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local previewSound = Instance.new("Sound", main)
local historyCount = 0

-- --- 檢查音樂權限的功能 ---
local function getPrivacyStatus(id)
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(tonumber(id))
    end)
    
    if success and info then
        -- Roblox 的音樂如果公開，通常 CanEagerlyValidate 為 true 或資訊完整
        -- 這裡最準確的判斷是看它是否允許在當前遊戲使用（雖然這不代表絕對公開）
        if info.IsPublicDomain then
            return "🔓 公開", Color3.fromRGB(0, 255, 100)
        else
            return "🔒 私人/限區域", Color3.fromRGB(255, 100, 100)
        end
    end
    return "❓ 狀態未知", Color3.fromRGB(200, 200, 200)
end

-- --- 建立列表項目 ---
local function createEntry(soundName, id)
    historyCount = historyCount + 1
    
    local frame = Instance.new("Frame")
    frame.Name = id 
    frame.LayoutOrder = historyCount
    frame.Size = UDim2.new(1, -10, 0, 65) -- 高度稍微增加
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.Parent = scroll
    Instance.new("UICorner", frame)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(0.6, 0, 0.6, 0)
    info.Position = UDim2.new(0.03, 0, 0.1, 0)
    info.Text = "🔊 " .. soundName .. "\nID: " .. id
    info.TextColor3 = Color3.new(1, 1, 1)
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.BackgroundTransparency = 1; info.Font = Enum.Font.SourceSansBold; info.TextSize = 14
    info.Parent = frame

    -- 權限標籤
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    statusLabel.Position = UDim2.new(0.03, 0, 0.65, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Font = Enum.Font.SourceSansItalic; statusLabel.TextSize = 12
    statusLabel.Parent = frame
    
    -- 異步獲取權限狀態，避免 UI 卡死
    task.spawn(function()
        local text, color = getPrivacyStatus(id)
        statusLabel.Text = text
        statusLabel.TextColor3 = color
    end)

    -- 按鈕部分 (試聽與複製)
    local playBtn = Instance.new("TextButton")
    playBtn.Size = UDim2.new(0, 45, 0, 28)
    playBtn.Position = UDim2.new(0.65, 0, 0.3, 0)
    playBtn.Text = "▶"; playBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    playBtn.TextColor3 = Color3.new(1, 1, 1); playBtn.Parent = frame
    Instance.new("UICorner", playBtn)

    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 45, 0, 28)
    copyBtn.Position = UDim2.new(0.82, 0, 0.3, 0)
    copyBtn.Text = "📋"; copyBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 150)
    copyBtn.TextColor3 = Color3.new(1, 1, 1); copyBtn.Parent = frame
    Instance.new("UICorner", copyBtn)

    playBtn.MouseButton1Click:Connect(function()
        if previewSound.SoundId == "rbxassetid://" .. id and previewSound.IsPlaying then
            previewSound:Stop(); playBtn.Text = "▶"
        else
            previewSound:Stop(); previewSound.SoundId = "rbxassetid://" .. id
            previewSound:Play(); playBtn.Text = "⏹"
        end
    end)

    copyBtn.MouseButton1Click:Connect(function()
        setclipboard(id)
        copyBtn.Text = "✔"; task.wait(0.5); copyBtn.Text = "📋"
    end)
end

-- --- 刷新邏輯 ---
local function refreshList()
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Sound") and obj.IsPlaying and obj.SoundId ~= "" then
            local id = obj.SoundId:match("%d+")
            if id and not scroll:FindFirstChild(id) then
                if obj.TimeLength > 5 or obj.Looped or obj.Volume > 0.05 then
                    createEntry(obj.Name, id)
                end
            end
        end
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
end

task.spawn(function()
    while task.wait(3) do pcall(refreshList) end
end)

local close = Instance.new("TextButton", main)
close.Size = UDim2.new(0, 25, 0, 25); close.Position = UDim2.new(1, -30, 0, 5)
close.Text = "×"; close.BackgroundColor3 = Color3.new(0.6, 0, 0); close.TextColor3 = Color3.new(1, 1, 1)
close.MouseButton1Click:Connect(function() screenGui:Destroy() end)
Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)
