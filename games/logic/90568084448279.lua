--[[
    $$ banknote $$ - Sniper Arena Logic (PlaceId: 90568084448279)
    Implements Silent Aim, Gun Mods, ESP, Movement, and World Exploits.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")

local function flags()
    if not getgenv().BanknoteFlags then
        getgenv().BanknoteFlags = {}
    end
    return getgenv().BanknoteFlags
end

local connections = {}
local function track(conn)
    table.insert(connections, conn)
    return conn
end

local function GetMouse()
    return UserInputService:GetMouseLocation()
end

------------------------------------------------------------------
-- SILENT AIM & FOV (Camera Hook-based)
------------------------------------------------------------------
local cachedTargetPos = nil
local cachedTargetPart = nil

local function isValidTarget(part)
    if not part or not part.Parent then return false end
    
    -- Try to find the character (could be anywhere in hierarchy)
    local char = part.Parent
    local maxLevels = 5
    while char and maxLevels > 0 do
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            return hum.Health > 0 and char:FindFirstChildOfClass("Humanoid") ~= nil
        end
        char = char.Parent
        maxLevels = maxLevels - 1
    end
    
    return false
end

local function getHitPart(character)
    local want = flags()["SilentHitPart"] or "Head"
    
    -- Try the requested part first
    if want == "Head" then
        return character:FindFirstChild("Head") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
    elseif want == "Torso" or want == "UpperTorso" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    elseif want == "LowerTorso" then
        return character:FindFirstChild("LowerTorso") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
    elseif want == "Random" then
        local pool = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
        for i = 1, #pool do
            local idx = math.random(1, #pool)
            local p = character:FindFirstChild(pool[idx])
            if p then return p end
        end
        return character:FindFirstChild("HumanoidRootPart")
    end
    
    -- Fallback: try any humanoid body part
    local part = character:FindFirstChild(want)
    if part then return part end
    
    -- Final fallback
    return character:FindFirstChild("Head") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
end

local function isSameTeam(player)
    if not flags()["TeamCheck"] then return false end
    local lt, pt = LocalPlayer.Team, player.Team
    if not lt or not pt then return false end
    return lt == pt
end

local function visibleToCamera(part, character)
    if not flags()["WallCheck"] then return true end
    local cam = workspace.CurrentCamera
    if not cam then return true end
    local origin = cam.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { character }
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    pcall(function() params.RespectCanCollide = true end)
    local hit = workspace:Raycast(origin, dir, params)
    if not hit then return true end
    return hit.Instance:IsDescendantOf(character)
end

local function updateTarget()
    Camera = workspace.CurrentCamera
    if not flags()["SilentAim"] or not Camera then return end

    local mouse = UserInputService:GetMouseLocation()
    local fovRadius = flags()["SilentFOV"] or 150
    local maxDist = flags()["MaxAimDist"] or 1000
    
    -- Raycast from camera through mouse position
    local screenSize = Camera.ViewportSize
    local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)
    local rayOrigin = unitRay.Origin
    local rayDirection = unitRay.Direction * maxDist

    -- Find closest player within FOV
    local bestPart = nil
    local bestDist = fovRadius

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not isSameTeam(player) then
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local part = getHitPart(char)
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if part and root then
                        -- Check if part is within distance
                        local dist = (root.Position - rayOrigin).Magnitude
                        if dist <= maxDist then
                            -- Convert part position to screen space and check FOV
                            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - mouse).Magnitude
                                -- Check if within FOV and visible
                                if mouseDist < bestDist and visibleToCamera(part, char) then
                                    bestDist = mouseDist
                                    bestPart = part
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Update cache with closest target found
    if bestPart then
        local hitChance = flags()["SilentHitChance"] or 100
        if hitChance >= 100 or math.random(1, 100) <= hitChance then
            cachedTargetPart = bestPart
            cachedTargetPos = bestPart.Position
        end
    else
        -- Clear cache if no valid target in FOV
        cachedTargetPart = nil
        cachedTargetPos = nil
    end
end

-- FOV Circle ScreenGui Setup
local guiParent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
local fovScreenGui = Instance.new("ScreenGui")
fovScreenGui.Name = "BanknoteFOV"
fovScreenGui.ResetOnSpawn = false
fovScreenGui.IgnoreGuiInset = true
fovScreenGui.DisplayOrder = 999999
fovScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
fovScreenGui.Parent = guiParent

local fovCircle = Instance.new("Frame")
fovCircle.Size = UDim2.fromOffset(300, 300)
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0
fovCircle.Visible = false
fovCircle.Parent = fovScreenGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Thickness = 2
fovStroke.Parent = fovCircle

local fovConn = RunService.RenderStepped:Connect(function()
    updateTarget()
    local f = flags()
    if f["ShowFOVCircle"] == true and f["SilentAim"] == true then
        local radius = f["SilentFOV"] or 150
        fovCircle.Size = UDim2.fromOffset(radius * 2, radius * 2)
        fovStroke.Color = f["FOVCircleColor"] or Color3.fromRGB(255, 255, 255)
        local mp = GetMouse()
        fovCircle.Position = UDim2.fromOffset(mp.X, mp.Y)
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end
end)
track(fovConn)

-- Hook GetTargeting directly to apply silent aim to return values
if not getgenv()._SilentAimHooked then
    getgenv()._SilentAimHooked = true

    task.delay(1, function()
        local ok, CameraController = pcall(function()
            return require(game:GetService("ReplicatedStorage").Client.CameraController)
        end)
        
        if not ok or not CameraController then return end

        -- Try to find and hook GetTargeting directly
        if CameraController.GetTargetingFn and hookfunction then
            local originalGetTargeting = CameraController.GetTargetingFn
            
            CameraController.GetTargetingFn = hookfunction(originalGetTargeting, newcclosure(function(...)
                local results = {originalGetTargeting(...)}
                
                -- Apply silent aim: replace target part (usually at index 2)
                if flags()["SilentAim"] and cachedTargetPart and isValidTarget(cachedTargetPart) then
                    -- Try index 2 first (most common for target part)
                    if results[2] then
                        results[2] = cachedTargetPart
                    -- Try index 1 if 2 doesn't exist
                    elseif results[1] then
                        results[1] = cachedTargetPart
                    end
                end
                
                return unpack(results)
            end))
        end
    end)
end





------------------------------------------------------------------
-- GUN MODS & AUTO SHOOT
------------------------------------------------------------------
local function scanTool(tool)
    if not tool:IsA("Tool") then return end
    
    -- 1. Modify attributes safely respecting original types
    for _, attr in ipairs({"Recoil", "Sway", "Spread", "RecoilPitch", "RecoilYaw", "SwayX", "SwayY", "Accuracy", "ReloadSpeed", "ReloadTime"}) do
        local val = tool:GetAttribute(attr)
        if val ~= nil then
            if typeof(val) == "number" then
                if attr:find("Reload") then
                    if flags()["InstantReload"] then tool:SetAttribute(attr, 0.05) end
                elseif attr:find("Recoil") then
                    if flags()["NoRecoil"] then tool:SetAttribute(attr, 0) end
                elseif attr:find("Sway") then
                    if flags()["NoSway"] then tool:SetAttribute(attr, 0) end
                elseif attr:find("Spread") or attr:find("Accuracy") then
                    tool:SetAttribute(attr, 0)
                end
            elseif typeof(val) == "boolean" then
                if attr:find("Recoil") then
                    if flags()["NoRecoil"] then tool:SetAttribute(attr, false) end
                elseif attr:find("Sway") then
                    if flags()["NoSway"] then tool:SetAttribute(attr, false) end
                elseif attr:find("Spread") or attr:find("Accuracy") then
                    tool:SetAttribute(attr, false)
                end
            end
        end
    end
    
    -- 2. Modify values inside configuration folders
    local config = tool:FindFirstChild("Configuration") or tool:FindFirstChild("Config") or tool:FindFirstChild("Settings")
    if config then
        for _, val in ipairs(config:GetChildren()) do
            if val:IsA("NumberValue") or val:IsA("IntValue") then
                local name = val.Name
                if (name:find("Recoil") or name:find("Kick") or name:find("Shake")) and flags()["NoRecoil"] then
                    val.Value = 0
                elseif (name:find("Sway") or name:find("Bob")) and flags()["NoSway"] then
                    val.Value = 0
                elseif (name:find("Reload") or name:find("Delay")) and flags()["InstantReload"] then
                    val.Value = 0.01
                elseif name:find("Spread") or name:find("Accuracy") then
                    val.Value = 0
                end
            end
        end
    end
    
    -- 3. Modify local script environments if getsenv is available
    if getsenv then
        for _, scr in ipairs(tool:GetDescendants()) do
            if scr:IsA("LocalScript") then
                task.spawn(function()
                    local env = getsenv(scr)
                    if env then
                        for k, v in pairs(env) do
                            if type(v) == "number" then
                                if (k:lower():find("recoil") or k:lower():find("kick")) and flags()["NoRecoil"] then
                                    env[k] = 0
                                elseif (k:lower():find("sway") or k:lower():find("bob")) and flags()["NoSway"] then
                                    env[k] = 0
                                elseif (k:lower():find("reload") or k:lower():find("cooldown") or k:lower():find("firerate") or k:lower():find("delay")) and flags()["InstantReload"] then
                                    env[k] = 0.05
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
end

local function setupCharacter(char)
    local function childAdded(child)
        if child:IsA("Tool") then
            scanTool(child)
        end
    end
    char.ChildAdded:Connect(childAdded)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            scanTool(child)
        end
    end
end
track(LocalPlayer.CharacterAdded:Connect(setupCharacter))
if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end

-- Continuous Tool Scan Loop
task.spawn(function()
    while task.wait(0.5) do
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            scanTool(tool)
        end
    end
end)

------------------------------------------------------------------
-- MOVEMENT HACKS
------------------------------------------------------------------
local function hookHumanoid(hum)
    if not hum then return end
    local conn = RunService.Heartbeat:Connect(function()
        if not hum or not hum.Parent then return end
        if flags()["SpeedHack"] then
            hum.WalkSpeed = flags()["SpeedValue"] or 50
        end
        if flags()["JumpHack"] then
            hum.UseJumpPower = true
            hum.JumpPower = flags()["JumpPower"] or 50
        end
    end)
    track(conn)
end
track(LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then hookHumanoid(hum) end
end))
if LocalPlayer.Character then
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hookHumanoid(hum) end
end

-- Infinite Jump
local jumpConn = UserInputService.JumpRequest:Connect(function()
    if flags()["InfJump"] then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)
track(jumpConn)

-- Fly
local flying = false
local bodyGyro, bodyVelocity
local function startFlying()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.P = 9e4
    bodyGyro.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.cframe = root.CFrame
    bodyGyro.Parent = root
    
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.velocity = Vector3.new(0, 0.1, 0)
    bodyVelocity.maxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVelocity.Parent = root
    
    flying = true
end

local function stopFlying()
    flying = false
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
end

local flyConn = RunService.RenderStepped:Connect(function()
    if flags()["FlyEnabled"] then
        if not flying then startFlying() end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if root and bodyVelocity and bodyGyro then
            local cameraCFrame = Camera.CFrame
            local moveDirection = Vector3.new(0,0,0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDirection = moveDirection + cameraCFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDirection = moveDirection - cameraCFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDirection = moveDirection - cameraCFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDirection = moveDirection + cameraCFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDirection = moveDirection + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDirection = moveDirection - Vector3.new(0, 1, 0)
            end
            
            local speed = flags()["FlySpeed"] or 50
            bodyVelocity.velocity = moveDirection.Unit * speed
            bodyGyro.cframe = cameraCFrame
            
            if hum then hum.PlatformStand = true end
        end
    else
        if flying then
            stopFlying()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end
end)
track(flyConn)

-- No Clip
local noclipConn = RunService.Stepped:Connect(function()
    if flags()["NoClip"] then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)
track(noclipConn)

------------------------------------------------------------------
-- VISUALS: ESP, CHAMS, TRACERS
------------------------------------------------------------------
local espObjects = {}
local tracers = {}

local function createESP(player)
    if player == LocalPlayer then return end
    
    local function setupESP(char)
        if not char then return end
        local root = char:WaitForChild("HumanoidRootPart", 5)
        local hum = char:WaitForChild("Humanoid", 5)
        if not root or not hum then return end
        
        -- Delete any old BillboardGuis/Highlights
        local old = char:FindFirstChild("BanknoteESP")
        if old then old:Destroy() end
        local oldHighlight = char:FindFirstChild("BanknoteHighlight")
        if oldHighlight then oldHighlight:Destroy() end

        -- 1. BillboardGui
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "BanknoteESP"
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.new(4, 0, 5.5, 0)
        billboard.Adornee = root
        billboard.ResetOnSpawn = false
        billboard.Parent = char

        -- Box Frame
        local box = Instance.new("Frame")
        box.Name = "Box"
        box.Size = UDim2.new(1, 0, 1, 0)
        box.BackgroundTransparency = 1
        box.BorderSizePixel = 0
        box.Parent = billboard
        
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.5
        stroke.Color = flags()["ESPColor"] or Color3.fromRGB(255, 0, 0)
        stroke.Parent = box

        -- Name TextLabel
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, 0, 0, 15)
        nameLabel.Position = UDim2.new(0, 0, 0, -18)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.Code
        nameLabel.TextSize = 13
        nameLabel.TextColor3 = flags()["ESPColor"] or Color3.fromRGB(255, 0, 0)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Center
        nameLabel.Parent = billboard

        local nameStroke = Instance.new("UIStroke")
        nameStroke.Thickness = 1
        nameStroke.Color = Color3.new(0,0,0)
        nameStroke.Parent = nameLabel

        -- Health Bar Background
        local healthBg = Instance.new("Frame")
        healthBg.Name = "HealthBg"
        healthBg.Size = UDim2.new(0.08, 0, 1, 0)
        healthBg.Position = UDim2.new(-0.12, 0, 0, 0)
        healthBg.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
        healthBg.BorderSizePixel = 0
        healthBg.Parent = billboard

        local healthBar = Instance.new("Frame")
        healthBar.Name = "HealthBar"
        healthBar.Size = UDim2.new(1, 0, 1, 0)
        healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        healthBar.BorderSizePixel = 0
        healthBar.Parent = healthBg

        -- 2. Highlight for Chams
        local highlight = Instance.new("Highlight")
        highlight.Name = "BanknoteHighlight"
        highlight.Adornee = char
        highlight.FillColor = flags()["ChamsColor"] or Color3.fromRGB(128, 0, 255)
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = char

        espObjects[player] = {
            Billboard = billboard,
            Box = box,
            Stroke = stroke,
            NameLabel = nameLabel,
            HealthBar = healthBar,
            Highlight = highlight
        }
    end

    local charAddedConn = player.CharacterAdded:Connect(setupESP)
    track(charAddedConn)
    if player.Character then setupESP(player.Character) end
end

local function removeESP(player)
    local esp = espObjects[player]
    if esp then
        if esp.Billboard then pcall(function() esp.Billboard:Destroy() end) end
        if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
        espObjects[player] = nil
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    createESP(player)
end
track(Players.PlayerAdded:Connect(createESP))
track(Players.PlayerRemoving:Connect(removeESP))

-- Tracers Setup
local function addTracer(player)
    if player == LocalPlayer then return end
    if not Drawing then return end
    
    local line = Drawing.new("Line")
    line.Thickness = 1.5
    line.Transparency = 1
    line.Visible = false
    tracers[player] = line
end

local function removeTracer(player)
    local line = tracers[player]
    if line then
        pcall(function() line:Destroy() end)
        tracers[player] = nil
    end
end

if Drawing then
    for _, player in ipairs(Players:GetPlayers()) do
        addTracer(player)
    end
    track(Players.PlayerAdded:Connect(addTracer))
    track(Players.PlayerRemoving:Connect(removeTracer))
end

-- ESP Rendering loop
local espRenderConn = RunService.RenderStepped:Connect(function()
    local espEnabled = flags()["PlayerESP"] or false
    local boxEnabled = flags()["BoxESP"] or false
    local nameEnabled = flags()["NameESP"] or false
    local healthEnabled = flags()["HealthBar"] or false
    local chamsEnabled = flags()["Chams"] or false
    local tracersEnabled = flags()["Tracers"] or false
    local tracerOrigin = flags()["TracerOrigin"] or "Bottom"
    local espColor = flags()["ESPColor"] or Color3.fromRGB(255, 0, 0)
    local chamsColor = flags()["ChamsColor"] or Color3.fromRGB(128, 0, 255)

    -- Update Billboards & Highlights
    for player, esp in pairs(espObjects) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if char and root and hum and hum.Health > 0 then
            local dist = math.floor((root.Position - Camera.CFrame.Position).Magnitude)
            
            if esp.Billboard then esp.Billboard.Enabled = espEnabled end
            if esp.Box then esp.Box.Visible = boxEnabled end
            if esp.NameLabel then esp.NameLabel.Visible = nameEnabled end
            if esp.HealthBar and esp.HealthBar.Parent then esp.HealthBar.Parent.Visible = healthEnabled end
            if esp.Highlight then esp.Highlight.Enabled = chamsEnabled end

            if espEnabled then
                if esp.Stroke then esp.Stroke.Color = espColor end
                if esp.NameLabel then
                    esp.NameLabel.TextColor3 = espColor
                    esp.NameLabel.Text = player.DisplayName .. " [" .. tostring(dist) .. "m]"
                end

                if esp.HealthBar then
                    local hpPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    esp.HealthBar.Size = UDim2.new(1, 0, hpPercent, 0)
                    esp.HealthBar.Position = UDim2.new(0, 0, 1 - hpPercent, 0)
                    esp.HealthBar.BackgroundColor3 = Color3.fromRGB(255 * (1 - hpPercent), 255 * hpPercent, 0)
                end
            end

            if chamsEnabled and esp.Highlight then
                esp.Highlight.FillColor = chamsColor
            end
        else
            if esp.Billboard then esp.Billboard.Enabled = false end
            if esp.Highlight then esp.Highlight.Enabled = false end
        end
    end

    -- Update Tracers (if Drawing supported)
    for player, line in pairs(tracers) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        local drawn = false
        if tracersEnabled and char and root and hum and hum.Health > 0 then
            local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen then
                local startPoint = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                if tracerOrigin == "Center" then
                    startPoint = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                elseif tracerOrigin == "Mouse" then
                    startPoint = GetMouse()
                end

                line.From = startPoint
                line.To = Vector2.new(screenPos.X, screenPos.Y)
                line.Color = espColor
                line.Visible = true
                drawn = true
            end
        end

        if not drawn then
            line.Visible = false
        end
    end
end)
track(espRenderConn)

------------------------------------------------------------------
-- WORLD MODS: FULLBRIGHT / NO FOG / FOV
------------------------------------------------------------------
local originalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd
}

local worldRenderConn = RunService.RenderStepped:Connect(function()
    if flags()["Fullbright"] then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.Brightness = originalLighting.Brightness
        Lighting.GlobalShadows = originalLighting.GlobalShadows
    end
    
    if flags()["NoFog"] then
        Lighting.FogStart = 999999
        Lighting.FogEnd = 999999
    else
        Lighting.FogStart = originalLighting.FogStart
        Lighting.FogEnd = originalLighting.FogEnd
    end
    
    if flags()["FOV"] then
        Camera.FieldOfView = flags()["FOV"]
    end
end)
track(worldRenderConn)

------------------------------------------------------------------
-- EXPLOIT UTILITIES & GLOBAL CALLS
------------------------------------------------------------------
-- Anti AFK
track(LocalPlayer.Idled:Connect(function()
    if flags()["AntiAFK"] then
        VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
        task.wait(0.5)
        VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
    end
end))

-- Spectating
local spectatingConnection
local function stopSpectating()
    if spectatingConnection then
        spectatingConnection:Disconnect()
        spectatingConnection = nil
    end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then Camera.CameraSubject = hum end
end

local function spectatePlayer(name)
    stopSpectating()
    if name == "" then return end
    
    local target = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(name:lower()) or p.DisplayName:lower():find(name:lower()) then
            target = p
            break
        end
    end
    
    if target and target.Character then
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            Camera.CameraSubject = hum
            spectatingConnection = target.CharacterAdded:Connect(function(char)
                local newHum = char:WaitForChild("Humanoid", 5)
                if newHum then Camera.CameraSubject = newHum end
            end)
            track(spectatingConnection)
        end
    end
end

-- Wire globals for UI config callbacks
getgenv().SniperArena_TpToPlayer = function(name)
    if name == "" then return end
    local target = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if p.Name:lower():find(name:lower()) or p.DisplayName:lower():find(name:lower()) then
            target = p
            break
        end
    end
    if target and target.Character then
        local root = target.Character:FindFirstChild("HumanoidRootPart")
        local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and localRoot then
            localRoot.CFrame = root.CFrame * CFrame.new(0, 0, 3)
        end
    end
end

getgenv().SniperArena_SpectatePlayer = function(name)
    spectatePlayer(name)
end

getgenv().SniperArena_StopSpectating = function()
    stopSpectating()
end

getgenv().SniperArena_Rejoin = function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

getgenv().SniperArena_ServerHop = function()
    local x = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    for _, s in ipairs(x.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
            break
        end
    end
end

print("[$$ banknote $$] Sniper Arena loaded")
