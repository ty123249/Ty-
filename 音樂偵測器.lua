local CoreGui = game:GetService("CoreGui")
local player = game:GetService("Players").LocalPlayer

-- --- UI 建立 ---
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Music_History_Tracker"
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = player:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 320, 0, 380)
main.Position = UDim2.new(0.7, 0, 0.2, 0)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
main.BorderSizePixel = 0
main.Active = true; main.Draggable = true; main.Parent = screenGui
Instance.new("UICorner", main)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
title.Text = "📜 音樂偵測歷史清單"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold; title.TextSize = 16; title.Parent = main
Instance.new("UICorner", title)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(0.94, 0, 0.82, 0)
scroll.Position = UDim2.new(0.03, 0, 0.13, 0)
scroll.BackgroundTransparency = 1
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 4; scroll.Parent = main

local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder -- 改用插入順序排序，最新的在最下面

local previewSound = Instance.new("Sound", main)
local historyCount = 0 -- 用來記錄順序

-- --- 建立列表項目 ---
local function createEntry(soundName, id)
    historyCount = historyCount + 1
    
    local frame = Instance.new("Frame")
    frame.Name = id 
    frame.LayoutOrder = historyCount -- 確保新加入的排在後面
    frame.Size = UDim2.new(1, -10, 0, 55)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.Parent = scroll
    Instance.new("UICorner", frame)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(0.6, 0, 1, 0)
    info.Position = UDim2.new(0.03, 0, 0, 0)
    info.Text = "🔊 " .. soundName .. "\nID: " .. id
    info.TextColor3 = Color3.new(1, 1, 1)
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.BackgroundTransparency = 1; info.Font = Enum.Font.SourceSans; info.TextSize = 13
    info.Parent = frame

    local playBtn = Instance.new("TextButton")
    playBtn.Size = UDim2.new(0, 45, 0, 30)
    playBtn.Position = UDim2.new(0.65, 0, 0.2, 0)
    playBtn.Text = "▶ 試聽"
    playBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    playBtn.TextColor3 = Color3.new(1, 1, 1); playBtn.Font = Enum.Font.SourceSansBold
    playBtn.Parent = frame
    Instance.new("UICorner", playBtn)

    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 45, 0, 30)
    copyBtn.Position = UDim2.new(0.82, 0, 0.2, 0)
    copyBtn.Text = "📋 複製"
    copyBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 150)
    copyBtn.TextColor3 = Color3.new(1, 1, 1); copyBtn.Font = Enum.Font.SourceSansBold
    copyBtn.Parent = frame
    Instance.new("UICorner", copyBtn)

    playBtn.MouseButton1Click:Connect(function()
        if previewSound.SoundId == "rbxassetid://" .. id and previewSound.IsPlaying then
            previewSound:Stop()
            playBtn.Text = "▶ 試聽"
        else
            previewSound:Stop()
            previewSound.SoundId = "rbxassetid://" .. id
            previewSound:Play()
            playBtn.Text = "⏹ 停止"
        end
    end)

    copyBtn.MouseButton1Click:Connect(function()
        setclipboard(id)
        copyBtn.Text = "✔ OK"
        task.wait(1)
        copyBtn.Text = "📋 複製"
    end)
end

-- --- 刷新邏輯 (只增不減) ---
local function refreshList()
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Sound") and obj.IsPlaying and obj.SoundId ~= "" then
            local id = obj.SoundId:match("%d+")
            if id and not scroll:FindFirstChild(id) then -- 如果這個 ID 從未出現過
                -- 基本過濾，避免短音效污染歷史清單
                if obj.TimeLength > 5 or obj.Looped or obj.Volume > 0.05 then
                    createEntry(obj.Name, id)
                end
            end
        end
    end
    
    scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
end

-- 保持掃描，發現新音樂就加入清單
task.spawn(function()
    while task.wait(3) do
        pcall(refreshList)
    end
end)

-- 關閉
local close = Instance.new("TextButton", main)
close.Size = UDim2.new(0, 25, 0, 25); close.Position = UDim2.new(1, -30, 0, 5)
close.Text = "×"; close.BackgroundColor3 = Color3.new(0.6, 0, 0); close.TextColor3 = Color3.new(1, 1, 1)
close.MouseButton1Click:Connect(function() screenGui:Destroy() end)
Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)

