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
    local char = part.Parent
    while char and not char:FindFirstChildOfClass("Humanoid") do
        char = char.Parent
    end
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getHitPart(character)
    local want = flags()["SilentHitPart"] or "Head"
    if want == "Random" then
        local pool = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
        local pick = pool[math.random(#pool)]
        return character:FindFirstChild(pick) or character:FindFirstChild("HumanoidRootPart")
    end
    local part = character:FindFirstChild(want)
    if part then return part end
    if want == "Torso" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    end
    return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
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
    -- Don't clear cache at start - only update when we find a new target
    if not flags()["SilentAim"] or not Camera then return end

    local mouse = UserInputService:GetMouseLocation()
    local bestDist = flags()["SilentFOV"] or 150
    local bestPart = nil
    local maxDist = flags()["MaxAimDist"] or 1000

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not isSameTeam(player) then
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local part = getHitPart(char)
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if part and root then
                        local dist = (root.Position - Camera.CFrame.Position).Magnitude
                        if dist <= maxDist then
                            local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                                if d < bestDist and visibleToCamera(part, char) then
                                    bestDist = d
                                    bestPart = part
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Only update cache if we found a valid target
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

-- Current Target Display
local targetLabel = Instance.new("TextLabel")
targetLabel.Name = "TargetLabel"
targetLabel.Size = UDim2.fromOffset(200, 30)
targetLabel.Position = UDim2.fromOffset(10, 10)
targetLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
targetLabel.BackgroundTransparency = 0.3
targetLabel.BorderSizePixel = 0
targetLabel.Font = Enum.Font.GothamMedium
targetLabel.TextSize = 14
targetLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Text = "Target: None"
targetLabel.Parent = fovScreenGui

local targetCorner = Instance.new("UICorner")
targetCorner.CornerRadius = UDim.new(0, 4)
targetCorner.Parent = targetLabel

-- Aim Details Display
local aimDetailsLabel = Instance.new("TextLabel")
aimDetailsLabel.Name = "AimDetailsLabel"
aimDetailsLabel.Size = UDim2.fromOffset(300, 50)
aimDetailsLabel.Position = UDim2.fromOffset(10, 45)
aimDetailsLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
aimDetailsLabel.BackgroundTransparency = 0.3
aimDetailsLabel.BorderSizePixel = 0
aimDetailsLabel.Font = Enum.Font.Code
aimDetailsLabel.TextSize = 12
aimDetailsLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
aimDetailsLabel.TextXAlignment = Enum.TextXAlignment.Left
aimDetailsLabel.TextYAlignment = Enum.TextYAlignment.Top
aimDetailsLabel.Text = "Aim Position: N/A\nTarget Part: N/A"
aimDetailsLabel.Parent = fovScreenGui

local aimDetailsCorner = Instance.new("UICorner")
aimDetailsCorner.CornerRadius = UDim.new(0, 4)
aimDetailsCorner.Parent = aimDetailsLabel

local fovConn = RunService.RenderStepped:Connect(function()
    updateTarget()
    
    -- Update target label
    if cachedTargetPart and isValidTarget(cachedTargetPart) then
        local targetChar = cachedTargetPart.Parent
        while targetChar and not targetChar:FindFirstChildOfClass("Humanoid") do
            targetChar = targetChar.Parent
        end
        if targetChar then
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character == targetChar then
                    local dist = (cachedTargetPart.Position - Camera.CFrame.Position).Magnitude
                    targetLabel.Text = "Target: " .. player.DisplayName .. " [" .. math.floor(dist) .. "m]"
                    break
                end
            end
            
            -- Update aim details
            local aimPos = cachedTargetPart.Position
            local partName = cachedTargetPart.Name
            local parentName = targetChar.Name
            aimDetailsLabel.Text = string.format(
                "Aim Position: %.1f, %.1f, %.1f\nTarget Part: %s (%s)",
                aimPos.X, aimPos.Y, aimPos.Z,
                partName, parentName
            )
        end
    else
        targetLabel.Text = "Target: None"
        aimDetailsLabel.Text = "Aim Position: N/A\nTarget Part: N/A"
    end
    
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

-- Function Hook for Silent Aim - Intercepts targeting system
if not getgenv()._SilentAimHooked then
    getgenv()._SilentAimHooked = true

    local function hookTargetingSystem()
        local ok, CameraController = pcall(function()
            return require(game:GetService("ReplicatedStorage").Client.CameraController)
        end)
        
        if not ok or not CameraController or not CameraController.GetTargetingFn then
            return
        end

        local originalGetTargetingFn = CameraController.GetTargetingFn
        local originalGetTargeting = originalGetTargetingFn()

        if not hookfunction or not originalGetTargeting then
            return
        end

        -- Hook the targeting function to return silent aim target
        -- First, let's log what GetTargeting returns to understand the structure
        local original
        original = hookfunction(originalGetTargeting, newcclosure(function(...)
            local results = {original(...)}
            
            -- Debug: Log the structure on first call
            if not getgenv()._TargetingDebugLogged then
                getgenv()._TargetingDebugLogged = true
                print("=== GetTargeting() Return Values ===")
                for i, v in ipairs(results) do
                    print(string.format("[%d] = %s (type: %s)", i, tostring(v), typeof(v)))
                end
                print("=====================================")
            end
            
            -- Validate that cached target is still alive before using it
            if flags()["SilentAim"] and cachedTargetPart and isValidTarget(cachedTargetPart) then
                -- Try replacing different indices to find which one is the target
                results[2] = cachedTargetPart
                -- Also try index 1 just in case
                if results[1] and typeof(results[1]) == "Instance" then
                    -- Don't overwrite if index 1 is already the target
                end
            else
                -- Clear cache if target is no longer valid
                cachedTargetPart = nil
                cachedTargetPos = nil
            end
            return unpack(results)
        end))
    end

    task.delay(0.5, hookTargetingSystem)
end

------------------------------------------------------------------
-- NO RECOIL
------------------------------------------------------------------
if not getgenv()._NoRecoilHooked then
    getgenv()._NoRecoilHooked = true
    
    task.delay(0.5, function()
        if filtergc then
            local RecoilConnection = filtergc("function", { Constants = { Enum.EasingDirection.Out, Enum.EasingDirection.InOut, "fromOrientation" } }, true)
            if RecoilConnection and hookfunction then
                hookfunction(RecoilConnection, function() return end)
            end
        end
    end)
end





------------------------------------------------------------------
-- AUTO SHOOT
------------------------------------------------------------------
if not getgenv()._AutoShootHooked then
    getgenv()._AutoShootHooked = true
    
    local lastShotTime = 0
    
    local autoShootConn = RunService.RenderStepped:Connect(function()
        if flags()["AutoShoot"] and cachedTargetPart and isValidTarget(cachedTargetPart) then
            local delay = flags()["AutoShootDelay"] or 1
            local currentTime = tick()
            
            if currentTime - lastShotTime >= delay then
                local mousePos = GetMouse()
                
                -- Quick scope: right click first if enabled
                if flags()["QuickScope"] then
                    VirtualUser:Button2Down(mousePos, Camera.CFrame)
                    task.wait(0.02)
                    VirtualUser:Button2Up(mousePos, Camera.CFrame)
                    task.wait(0.05)
                end
                
                -- Left click to shoot
                VirtualUser:Button1Down(mousePos, Camera.CFrame)
                task.wait(0.02)
                VirtualUser:Button1Up(mousePos, Camera.CFrame)
                lastShotTime = currentTime
            end
        end
    end)
    track(autoShootConn)
end




------------------------------------------------------------------
-- GUN MODS & AUTO SHOOT
------------------------------------------------------------------
local function scanTool(tool)
    if not tool:IsA("Tool") then return end
    
    -- 1. Modify attributes safely respecting original types
    for _, attr in ipairs({"Recoil", "Spread", "RecoilPitch", "RecoilYaw", "Accuracy"}) do
        local val = tool:GetAttribute(attr)
        if val ~= nil then
            if typeof(val) == "number" then
                if attr:find("Recoil") then
                    if flags()["NoRecoil"] then tool:SetAttribute(attr, 0) end

                elseif attr:find("Spread") or attr:find("Accuracy") then
                    tool:SetAttribute(attr, 0)
                end
            elseif typeof(val) == "boolean" then
                if attr:find("Recoil") then
                    if flags()["NoRecoil"] then tool:SetAttribute(attr, false) end

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
-- MOVEMENT HACKS (BHOP)
------------------------------------------------------------------
if not getgenv()._BHopInitialized then
    getgenv()._BHopInitialized = true
    
    local bhopState = {
        lastJumpTime = 0,
        velocity = Vector3.zero,
        isGrounded = false,
    }
    
    local function isPlayerGrounded(hrp, char)
        local rayOrigin = hrp.Position
        local rayDir = Vector3.new(0, -5, 0)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char}
        local rayResult = workspace:Raycast(rayOrigin, rayDir, rayParams)
        return rayResult ~= nil
    end
    
    -- Handle jump input
    track(UserInputService.JumpRequest:Connect(function()
        if flags()["BHopEnabled"] then
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and isPlayerGrounded(hrp, char) then
                    local jumpPower = flags()["BHopJumpPower"] or 30
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        hrp.AssemblyLinearVelocity.X,
                        jumpPower,
                        hrp.AssemblyLinearVelocity.Z
                    )
                end
            end
        end
    end))
    
    -- Main BHop movement loop
    local bhopConn = RunService.RenderStepped:Connect(function()
        if not flags()["BHopEnabled"] then
            return
        end
        
        local char = LocalPlayer.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        
        -- Get settings
        local runSpeed = flags()["BHopSpeed"] or 32
        local airAccel = flags()["BHopAirAccel"] or 52
        local groundAccel = 14
        
        -- Check if grounded
        bhopState.isGrounded = isPlayerGrounded(hrp, char)
        
        -- Get movement input
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + hrp.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - hrp.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - hrp.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + hrp.CFrame.RightVector
        end
        
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end
        
        -- Get current velocity
        local currentVel = hrp.AssemblyLinearVelocity
        local flatVel = Vector3.new(currentVel.X, 0, currentVel.Z)
        
        -- Apply acceleration
        local accel = bhopState.isGrounded and groundAccel or airAccel
        local wishDir = Vector3.new(moveDir.X, 0, moveDir.Z)
        
        if wishDir.Magnitude > 0 then
            wishDir = wishDir.Unit
            local currentSpeed = flatVel:Dot(wishDir)
            local speedToAdd = math.max(0, runSpeed - currentSpeed)
            flatVel = flatVel + wishDir * math.min(accel * 0.016, speedToAdd)
        end
        
        -- Cap speed
        local flatMag = flatVel.Magnitude
        if flatMag > runSpeed then
            flatVel = flatVel.Unit * runSpeed
        end
        
        -- Apply friction when idle and grounded
        if bhopState.isGrounded and moveDir.Magnitude == 0 then
            flatVel = flatVel * 0.85
        end
        
        -- Update velocity
        hrp.AssemblyLinearVelocity = Vector3.new(flatVel.X, currentVel.Y, flatVel.Z)
    end)
    track(bhopConn)
end




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
