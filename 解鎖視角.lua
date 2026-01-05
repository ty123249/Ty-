local Players = game:GetService("Players")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- 設定參數（可自行調整）
local MIN_ZOOM = 0
local MAX_ZOOM = 100

-- 套用視角限制與鏡頭設定
local function applyCameraSettings()
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    -- 設定鏡頭偏移與視角模式
    humanoid.CameraOffset = Vector3.new(0, 0, 0)
    player.CameraMode = Enum.CameraMode.Classic
    player.CameraMinZoomDistance = MIN_ZOOM
    player.CameraMaxZoomDistance = MAX_ZOOM
    camera.CameraSubject = humanoid
end

-- 當角色刷新時重新套用
player.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid")
    applyCameraSettings()
end)

-- 初始化立即套用
pcall(applyCameraSettings)

-- 防止被遊戲強制改回來（重複設回）
player:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(function()
    if player.CameraMinZoomDistance ~= MIN_ZOOM then
        player.CameraMinZoomDistance = MIN_ZOOM
    end
end)

player:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function()
    if player.CameraMaxZoomDistance ~= MAX_ZOOM then
        player.CameraMaxZoomDistance = MAX_ZOOM
    end
end)

player:GetPropertyChangedSignal("CameraMode"):Connect(function()
    if player.CameraMode ~= Enum.CameraMode.Classic then
        player.CameraMode = Enum.CameraMode.Classic
    end
end)
