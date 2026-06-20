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
-- SILENT AIM & FOV
------------------------------------------------------------------
local function isVisible(part, targetCharacter)
    local wallCheck = flags()["WallCheck"]
    if not wallCheck then return true end
    
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin).Unit * 1000
    local ray = Ray.new(origin, dir)
    local hit, pos = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, targetCharacter})
    return hit == nil or hit:IsDescendantOf(targetCharacter)
end

local function getTarget()
    local silentAim = flags()["SilentAim"]
    if not silentAim then return nil end

    local hitPart = flags()["SilentHitPart"] or "Head"
    local fov = flags()["SilentFOV"] or 150
    local targetPriority = flags()["AimTarget"] or "Closest to Cursor"
    local maxDist = flags()["MaxAimDist"] or 1000

    local closest = nil
    local closestVal = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        if flags()["TeamCheck"] and player.Team and LocalPlayer.Team then
            if player.Team == LocalPlayer.Team then continue end
        end

        local char = player.Character
        if not char then continue end
        
        local part = char:FindFirstChild(hitPart)
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not part or not root or not hum or hum.Health <= 0 then continue end

        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        if dist > maxDist then continue end

        if not isVisible(part, char) then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local screenPos2D = Vector2.new(screenPos.X, screenPos.Y)
        local mousePos = GetMouse()
        local mouseDist = (screenPos2D - mousePos).Magnitude

        if mouseDist > fov then continue end

        if targetPriority == "Closest to Cursor" then
            if mouseDist < closestVal then
                closestVal = mouseDist
                closest = part
            end
        elseif targetPriority == "Closest Distance" then
            if dist < closestVal then
                closestVal = dist
                closest = part
            end
        elseif targetPriority == "Lowest Health" then
            if hum.Health < closestVal then
                closestVal = hum.Health
                closest = part
            end
        elseif targetPriority == "Random" then
            return part
        end
    end

    return closest
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
    local f = flags()
    if f["ShowFOVCircle"] == true then
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

-- Metatable __namecall Hook for Silent Aim
local function getCallingScriptName()
    if getcallingscript then
        local scriptObj = getcallingscript()
        if scriptObj then
            return scriptObj.Name:lower()
        end
    end
    return ""
end

local function isCameraRay()
    local name = getCallingScriptName()
    return name:find("camera") or name:find("popper") or name:find("zoom") or name:find("bubble")
end

local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    -- ClientReplicateCFrame buffer spoof: redirect replicated gun CFrame to target
    if method == "FireServer" and not checkcaller() and flags()["SilentAim"] then
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local remote = ReplicatedStorage:FindFirstChild("ClientReplicateCFrame")
        if remote and self == remote then
            local args = {...}
            local raw = args[1]
            local buf = nil

            -- Roblox serialises buffers natively over remotes — handle both cases
            if typeof(raw) == "buffer" and buffer.len(raw) == 24 then
                -- Modify in-place; the same buffer object is passed back so the
                -- server-side deserialiser receives the correct type
                buf = raw
            elseif typeof(raw) == "string" and #raw == 24 then
                -- Fallback: game sent a raw binary string — decode, patch, re-encode
                buf = buffer.fromstring(raw)
            end

            if buf then
                local target = getTarget()
                if target and math.random(1, 100) <= (flags()["SilentHitChance"] or 100) then
                    local targetCF = target.CFrame
                    local pos     = targetCF.Position
                    -- Layout (6 × f32, 24 bytes):
                    --   [0]  metadata / sequence  → keep original
                    --   [4]  X position
                    --   [8]  Y position
                    --   [12] Z position
                    --   [16] LookVector.X
                    --   [20] LookVector.Z
                    buffer.writef32(buf, 4,  pos.X)
                    buffer.writef32(buf, 8,  pos.Y)
                    buffer.writef32(buf, 12, pos.Z)
                    buffer.writef32(buf, 16, targetCF.LookVector.X)
                    buffer.writef32(buf, 20, targetCF.LookVector.Z)

                    -- Replace arg only when we had to create a new buffer from a string
                    if typeof(raw) == "string" then
                        args[1] = buffer.tostring(buf)
                    end
                    -- (buffer case: buf IS args[1], already mutated in-place)

                    setnamecallmethod("FireServer")
                    return OldNamecall(self, table.unpack(args))
                end
            end
        end
    end

    return OldNamecall(self, ...)
end))



------------------------------------------------------------------
-- GUN MODS & AUTO SHOOT
------------------------------------------------------------------
local function scanTool(tool)
    if not tool:IsA("Tool") then return end
    
    -- 1. Modify attributes
    for _, attr in ipairs({"Recoil", "Sway", "Spread", "RecoilPitch", "RecoilYaw", "SwayX", "SwayY", "Accuracy", "ReloadSpeed", "ReloadTime"}) do
        if tool:GetAttribute(attr) ~= nil then
            if attr:find("Reload") then
                if flags()["InstantReload"] then tool:SetAttribute(attr, 0.05) end
            elseif attr:find("Recoil") then
                if flags()["NoRecoil"] then tool:SetAttribute(attr, 0) end
            elseif attr:find("Sway") then
                if flags()["NoSway"] then tool:SetAttribute(attr, 0) end
            elseif attr:find("Spread") or attr:find("Accuracy") then
                tool:SetAttribute(attr, 0)
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

-- Auto Shoot Loop
task.spawn(function()
    while task.wait(0.1) do
        if flags()["AutoShoot"] then
            local target = getTarget()
            if target then
                if mouse1press and mouse1release then
                    mouse1press()
                    task.wait(0.05)
                    mouse1release()
                else
                    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool then
                        tool:Activate()
                    end
                end
                task.wait(0.15)
            end
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
